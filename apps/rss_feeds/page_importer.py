import http.client
import re
import time
import traceback
import urllib.error
import urllib.parse
import urllib.request
import zlib
from socket import error as SocketError

import feedparser
import requests
from django.conf import settings
from django.contrib.sites.models import Site
from django.utils.encoding import smart_bytes
from django.utils.text import compress_string as compress_string_with_gzip
from mongoengine.queryset import NotUniqueError
from OpenSSL.SSL import Error as OpenSSLError
from pyasn1.error import PyAsn1Error
from sentry_sdk import capture_exception, flush

from apps.rss_feeds.models import MFeedPage
from utils import log as logging
from utils.feed_functions import TimeoutError, timelimit

# from utils.feed_functions import mail_feed_error_to_admin

BROKEN_PAGES = [
    "tag:",
    "info:",
    "uuid:",
    "urn:",
    "[]",
]

# Also change in reader_utils.js.
BROKEN_PAGE_URLS = [
    "nytimes.com",
    "github.com",
    "washingtonpost.com",
    "stackoverflow.com",
    "stackexchange.com",
    "twitter.com",
    "rankexploits",
    "gamespot.com",
    "espn.com",
    "royalroad.com",
]


class PageImporter(object):
    def __init__(self, feed, story=None, request=None):
        self.feed = feed
        self.story = story
        self.request = request

    @property
    def headers(self):
        return {
            "User-Agent": "NewsBlur Page Fetcher - %s subscriber%s - %s %s"
            % (
                self.feed.num_subscribers,
                "s" if self.feed.num_subscribers != 1 else "",
                self.feed.permalink,
                self.feed.fake_user_agent,
            ),
        }

    def fetch_page(self, urllib_fallback=False, requests_exception=None):
        try:
            self.fetch_page_timeout(urllib_fallback=urllib_fallback, requests_exception=requests_exception)
        except TimeoutError:
            logging.user(
                self.request,
                "   ***> [%-30s] ~FBPage fetch ~SN~FRfailed~FB due to timeout" % (self.feed.log_title[:30]),
            )

    @timelimit(10)
    def fetch_page_timeout(self, urllib_fallback=False, requests_exception=None):
        html = None
        feed_link = self.feed.feed_link
        if not feed_link:
            self.save_no_page(reason="No feed link")
            return

        if feed_link.startswith("www"):
            self.feed.feed_link = "http://" + feed_link
        try:
            if any(feed_link.startswith(s) for s in BROKEN_PAGES):
                self.save_no_page(reason="Broken page")
                return
            elif any(s in feed_link.lower() for s in BROKEN_PAGE_URLS):
                self.save_no_page(reason="Banned")
                return
            elif feed_link.startswith("http"):
                if urllib_fallback:
                    request = urllib.request.Request(feed_link, headers=self.headers)
                    response = urllib.request.urlopen(request)
                    time.sleep(0.01)  # Grrr, GIL.
                    data = response.read().decode(response.headers.get_content_charset() or "utf-8")
                else:
                    try:
                        response = requests.get(feed_link, headers=self.headers, timeout=10)
                        response.connection.close()
                    except requests.exceptions.TooManyRedirects:
                        response = requests.get(feed_link, timeout=10)
                    except (
                        AttributeError,
                        SocketError,
                        OpenSSLError,
                        PyAsn1Error,
                        TypeError,
                        requests.adapters.ReadTimeout,
                    ) as e:
                        logging.debug(
                            "   ***> [%-30s] Page fetch failed using requests: %s"
                            % (self.feed.log_title[:30], e)
                        )
                        self.save_no_page(reason="Page fetch failed")
                        return
                    data = response.text
                    if response.encoding and response.encoding.lower() != "utf-8":
                        logging.debug(f" -> ~FBEncoding is {response.encoding}, re-encoding...")
                        try:
                            data = data.encode("utf-8").decode("utf-8")
                        except (LookupError, UnicodeEncodeError):
                            logging.debug(f" -> ~FRRe-encoding failed!")
                            pass
            else:
                try:
                    data = open(feed_link, "r").read()
                except IOError:
                    self.feed.feed_link = "http://" + feed_link
                    self.fetch_page(urllib_fallback=True)
                    return
            if data:
                html = self.rewrite_page(data)
                if html:
                    self.save_page(html)
                else:
                    self.save_no_page(reason="No HTML found")
                    return
            else:
                self.save_no_page(reason="No data found")
                return
        except (
            ValueError,
            urllib.error.URLError,
            http.client.BadStatusLine,
            http.client.InvalidURL,
            requests.exceptions.ConnectionError,
        ) as e:
            logging.debug("   ***> [%-30s] Page fetch failed: %s" % (self.feed.log_title[:30], e))
            self.feed.save_page_history(401, "Bad URL", e)
            try:
                fp = feedparser.parse(self.feed.feed_address)
            except (urllib.error.HTTPError, urllib.error.URLError) as e:
                return html
            feed_link = fp.feed.get("link", "")
            self.feed.save()
        except http.client.IncompleteRead as e:
            logging.debug("   ***> [%-30s] Page fetch failed: %s" % (self.feed.log_title[:30], e))
            self.feed.save_page_history(500, "IncompleteRead", e)
        except (requests.exceptions.RequestException, requests.packages.urllib3.exceptions.HTTPError) as e:
            logging.debug(
                "   ***> [%-30s] Page fetch failed using requests: %s" % (self.feed.log_title[:30], e)
            )
            # mail_feed_error_to_admin(self.feed, e, local_vars=locals())
            return self.fetch_page(urllib_fallback=True, requests_exception=e)
        except Exception as e:
            logging.debug("[%d] ! -------------------------" % (self.feed.id,))
            tb = traceback.format_exc()
            logging.debug(tb)
            logging.debug("[%d] ! -------------------------" % (self.feed.id,))
            self.feed.save_page_history(500, "Error", tb)
            # mail_feed_error_to_admin(self.feed, e, local_vars=locals())
            if not settings.DEBUG and hasattr(settings, "SENTRY_DSN") and settings.SENTRY_DSN:
                capture_exception(e)
                flush()
            if not urllib_fallback:
                self.fetch_page(urllib_fallback=True)
        else:
            self.feed.save_page_history(200, "OK")

        return html

    def fetch_story(self):
        html = None
        try:
            html = self._fetch_story()
        except TimeoutError:
            logging.user(self.request, "~SN~FRFailed~FY to fetch ~FGoriginal story~FY: timed out")
        except requests.exceptions.TooManyRedirects:
            logging.user(self.request, "~SN~FRFailed~FY to fetch ~FGoriginal story~FY: too many redirects")

        return html

    @timelimit(10)
    def _fetch_story(self):
        html = None
        story_permalink = self.story.story_permalink

        if not self.feed:
            return
        if any(story_permalink.startswith(s) for s in BROKEN_PAGES):
            return
        if any(s in story_permalink.lower() for s in BROKEN_PAGE_URLS):
            return
        if not story_permalink.startswith("http"):
            return

        try:
            response = requests.get(story_permalink, headers=self.headers, timeout=10)
            response.connection.close()
        except (
            AttributeError,
            SocketError,
            OpenSSLError,
            PyAsn1Error,
            requests.exceptions.ConnectionError,
            requests.exceptions.TooManyRedirects,
            requests.adapters.ReadTimeout,
        ) as e:
            try:
                response = requests.get(story_permalink, timeout=10)
            except (
                AttributeError,
                SocketError,
                OpenSSLError,
                PyAsn1Error,
                requests.exceptions.ConnectionError,
                requests.exceptions.TooManyRedirects,
                requests.adapters.ReadTimeout,
            ) as e:
                logging.debug(
                    "   ***> [%-30s] Original story fetch failed using requests: %s"
                    % (self.feed.log_title[:30], e)
                )
                return
        # try:
        data = response.text
        # except (LookupError, TypeError):
        #     data = response.content
        # import pdb; pdb.set_trace()

        if response.encoding and response.encoding.lower() != "utf-8":
            logging.debug(f" -> ~FBEncoding is {response.encoding}, re-encoding...")
            try:
                data = data.encode("utf-8").decode("utf-8")
            except (LookupError, UnicodeEncodeError):
                logging.debug(f" -> ~FRRe-encoding failed!")
                pass

        if data:
            data = data.replace("\xc2\xa0", " ")  # Non-breaking space, is mangled when encoding is not utf-8
            data = data.replace("\\u00a0", " ")  # Non-breaking space, is mangled when encoding is not utf-8
            html = self.rewrite_page(data)
            if not html:
                return
            self.save_story(html)

        return html

    def save_story(self, html):
        self.story.original_page_z = zlib.compress(smart_bytes(html))
        try:
            self.story.save()
        except NotUniqueError:
            pass

    def save_no_page(self, reason=None):
        logging.debug(
            "   ---> [%-30s] ~FYNo original page: %s / %s"
            % (self.feed.log_title[:30], reason, self.feed.feed_link)
        )
        self.feed.has_page = False
        self.feed.save()
        self.feed.save_page_history(404, f"Feed has no original page: {reason}")

    def rewrite_page(self, response):
        BASE_RE = re.compile(r"<head(.*?)>", re.I)
        base_code = '<base href="%s" />' % (self.feed.feed_link,)

        html = BASE_RE.sub("<head\1> " + base_code, response)

        if "<base href" not in html:
            html = "%s %s" % (base_code, html)

        # html = self.fix_urls(html)

        return html.strip()

    def fix_urls(self, document):
        # BEWARE: This will rewrite URLs inside of <script> tags. You know, like
        # Google Analytics. Ugh.

        FIND_RE = re.compile(r'\b(href|src)\s*=\s*("[^"]*"|\'[^\']*\'|[^"\'<>=\s]+)')
        ret = []
        last_end = 0

        for match in FIND_RE.finditer(document):
            url = match.group(2)
            if url[0] in "\"'":
                url = url.strip(url[0])
            parsed = urllib.parse.urlparse(url)
            if parsed.scheme == parsed.netloc == "":  # relative to domain
                url = urllib.parse.urljoin(self.feed.feed_link, url)
                ret.append(document[last_end : match.start(2)])
                ret.append('"%s"' % (url,))
                last_end = match.end(2)
        ret.append(document[last_end:])

        return "".join(ret)

    def save_page(self, html):
        saved = False

        if not html or len(html) < 100:
            return

        if settings.BACKED_BY_AWS.get("pages_on_node"):
            saved = self.save_page_node(html)
            if saved and self.feed.s3_page and settings.BACKED_BY_AWS.get("pages_on_s3"):
                self.delete_page_s3()

        if settings.BACKED_BY_AWS.get("pages_on_s3") and not saved:
            saved = self.save_page_s3(html)

        if not saved:
            try:
                feed_page = MFeedPage.objects.get(feed_id=self.feed.pk)
                # feed_page.page_data = html.encode('utf-8')
                if feed_page.page() == html:
                    logging.debug(
                        "   ---> [%-30s] ~FYNo change in page data: %s"
                        % (self.feed.log_title[:30], self.feed.feed_link)
                    )
                else:
                    # logging.debug('   ---> [%-30s] ~FYChange in page data: %s (%s/%s %s/%s)' % (self.feed.log_title[:30], self.feed.feed_link, type(html), type(feed_page.page()), len(html), len(feed_page.page())))
                    feed_page.page_data = zlib.compress(smart_bytes(html))
                    feed_page.save()
            except MFeedPage.DoesNotExist:
                feed_page = MFeedPage.objects.create(
                    feed_id=self.feed.pk, page_data=zlib.compress(smart_bytes(html))
                )
            return feed_page

    def save_page_node(self, html):
        domain = "node-page.service.consul:8008"
        if settings.DOCKERBUILD:
            domain = "node:8008"
        url = "http://%s/original_page/%s" % (
            domain,
            self.feed.pk,
        )
        compressed_html = zlib.compress(smart_bytes(html))
        response = requests.post(
            url,
            files={
                "original_page": compressed_html,
                # 'original_page': html,
            },
        )
        if response.status_code == 200:
            return True
        else:
            logging.debug(
                "   ---> [%-30s] ~FRFailed to save page to node: %s (%s bytes)"
                % (self.feed.log_title[:30], response.status_code, len(compressed_html))
            )

    def save_page_s3(self, html):
        s3_object = settings.S3_CONN.Object(settings.S3_PAGES_BUCKET_NAME, self.feed.s3_pages_key)
        s3_object.put(
            Body=compress_string_with_gzip(html.encode("utf-8")),
            ContentType="text/html",
            ContentEncoding="gzip",
            Expires=expires,
            ACL="public-read",
        )

        try:
            feed_page = MFeedPage.objects.get(feed_id=self.feed.pk)
            feed_page.delete()
            logging.debug("   ---> [%-30s] ~FYTransfering page data to S3..." % (self.feed.log_title[:30]))
        except MFeedPage.DoesNotExist:
            pass

        if not self.feed.s3_page:
            self.feed.s3_page = True
            self.feed.save()

        return True

    def delete_page_s3(self):
        k = settings.S3_CONN.Bucket(settings.S3_PAGES_BUCKET_NAME).Object(key=self.feed.s3_pages_key)
        k.delete()

        self.feed.s3_page = False
        self.feed.save()
