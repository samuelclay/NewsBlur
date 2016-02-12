import requests
import re
import urlparse
import traceback
import feedparser
import time
import urllib2
import httplib
import zlib
from mongoengine.queryset import NotUniqueError
from socket import error as SocketError
from boto.s3.key import Key
from django.conf import settings
from django.utils.text import compress_string
from utils import log as logging
from apps.rss_feeds.models import MFeedPage
from utils.feed_functions import timelimit, TimeoutError
from OpenSSL.SSL import Error as OpenSSLError
from pyasn1.error import PyAsn1Error
# from utils.feed_functions import mail_feed_error_to_admin

BROKEN_PAGES = [
    'tag:', 
    'info:', 
    'uuid:', 
    'urn:', 
    '[]',
]

# Also change in reader_utils.js.
BROKEN_PAGE_URLS = [
    'nytimes.com',
    'github.com',
    'washingtonpost.com',
    'stackoverflow.com',
    'stackexchange.com',
    'twitter.com',
    'rankexploits',
    'gamespot.com',
]

class PageImporter(object):
    
    def __init__(self, feed, story=None, request=None):
        self.feed = feed
        self.story = story
        self.request = request
        
    @property
    def headers(self):
        return {
            'User-Agent': 'NewsBlur Page Fetcher - %s subscriber%s - %s '
                          '(Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_1) '
                          'AppleWebKit/534.48.3 (KHTML, like Gecko) Version/5.1 '
                          'Safari/534.48.3)' % (
                self.feed.num_subscribers,
                's' if self.feed.num_subscribers != 1 else '',
                self.feed.permalink,
            ),
        }
    
    def fetch_page(self, urllib_fallback=False, requests_exception=None):
        try:
            self.fetch_page_timeout(urllib_fallback=urllib_fallback, requests_exception=requests_exception)
        except TimeoutError:
            logging.user(self.request, '   ***> [%-30s] ~FBPage fetch ~SN~FRfailed~FB due to timeout' % (self.feed))
            
    @timelimit(10)
    def fetch_page_timeout(self, urllib_fallback=False, requests_exception=None):
        html = None
        feed_link = self.feed.feed_link
        if not feed_link:
            self.save_no_page()
            return

        if feed_link.startswith('www'):
            self.feed.feed_link = 'http://' + feed_link
        try:
            if any(feed_link.startswith(s) for s in BROKEN_PAGES):
                self.save_no_page()
                return
            elif any(s in feed_link.lower() for s in BROKEN_PAGE_URLS):
                self.save_no_page()
                return
            elif feed_link.startswith('http'):
                if urllib_fallback:
                    request = urllib2.Request(feed_link, headers=self.headers)
                    response = urllib2.urlopen(request)
                    time.sleep(0.01) # Grrr, GIL.
                    data = response.read()
                else:
                    try:
                        response = requests.get(feed_link, headers=self.headers)
                        response.connection.close()
                    except requests.exceptions.TooManyRedirects:
                        response = requests.get(feed_link)
                    except (AttributeError, SocketError, OpenSSLError, PyAsn1Error, TypeError), e:
                        logging.debug('   ***> [%-30s] Page fetch failed using requests: %s' % (self.feed, e))
                        self.save_no_page()
                        return
                    # try:
                    data = response.content
                    # except (LookupError, TypeError):
                    #     data = response.content

                    # if response.encoding and response.encoding != 'utf-8':
                    #     try:
                    #         data = data.encode(response.encoding)
                    #     except LookupError:
                    #         pass
            else:
                try:
                    data = open(feed_link, 'r').read()
                except IOError:
                    self.feed.feed_link = 'http://' + feed_link
                    self.fetch_page(urllib_fallback=True)
                    return
            if data:
                html = self.rewrite_page(data)
                self.save_page(html)
            else:
                self.save_no_page()
                return
        except (ValueError, urllib2.URLError, httplib.BadStatusLine, httplib.InvalidURL,
                requests.exceptions.ConnectionError), e:
            self.feed.save_page_history(401, "Bad URL", e)
            fp = feedparser.parse(self.feed.feed_address)
            feed_link = fp.feed.get('link', "")
            self.feed.save()
        except (urllib2.HTTPError), e:
            self.feed.save_page_history(e.code, e.msg, e.fp.read())
        except (httplib.IncompleteRead), e:
            self.feed.save_page_history(500, "IncompleteRead", e)
        except (requests.exceptions.RequestException, 
                requests.packages.urllib3.exceptions.HTTPError), e:
            logging.debug('   ***> [%-30s] Page fetch failed using requests: %s' % (self.feed, e))
            # mail_feed_error_to_admin(self.feed, e, local_vars=locals())
            return self.fetch_page(urllib_fallback=True, requests_exception=e)
        except Exception, e:
            logging.debug('[%d] ! -------------------------' % (self.feed.id,))
            tb = traceback.format_exc()
            logging.debug(tb)
            logging.debug('[%d] ! -------------------------' % (self.feed.id,))
            self.feed.save_page_history(500, "Error", tb)
            # mail_feed_error_to_admin(self.feed, e, local_vars=locals())
            if (not settings.DEBUG and hasattr(settings, 'RAVEN_CLIENT') and
                settings.RAVEN_CLIENT):
                settings.RAVEN_CLIENT.captureException()
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
            
        if any(story_permalink.startswith(s) for s in BROKEN_PAGES):
            return
        if any(s in story_permalink.lower() for s in BROKEN_PAGE_URLS):
            return
        if not story_permalink.startswith('http'): 
            return

        try:
            response = requests.get(story_permalink, headers=self.headers)
            response.connection.close()
        except requests.exceptions.TooManyRedirects:
            response = requests.get(story_permalink)
        except (AttributeError, SocketError, OpenSSLError, PyAsn1Error, requests.exceptions.ConnectionError), e:
            logging.debug('   ***> [%-30s] Original story fetch failed using requests: %s' % (self.feed, e))
            return
        try:
            data = response.text
        except (LookupError, TypeError):
            data = response.content

        if response.encoding and response.encoding != 'utf-8':
            try:
                data = data.encode(response.encoding)
            except LookupError:
                pass

        if data:
            html = self.rewrite_page(data)
            self.save_story(html)
        
        return html
    
    def save_story(self, html):
        self.story.original_page_z = zlib.compress(html)
        try:
            self.story.save()
        except NotUniqueError:
            pass

        
    def save_no_page(self):
        logging.debug('   ---> [%-30s] ~FYNo original page: %s' % (self.feed, self.feed.feed_link))
        self.feed.has_page = False
        self.feed.save()
        self.feed.save_page_history(404, "Feed has no original page.")

    def rewrite_page(self, response):
        BASE_RE = re.compile(r'<head(.*?\>)', re.I)
        base_code = u'<base href="%s" />' % (self.feed.feed_link,)
        try:
            html = BASE_RE.sub(r'<head\1 '+base_code, response)
        except:
            response = response.decode('latin1').encode('utf-8')
            html = BASE_RE.sub(r'<head\1 '+base_code, response)
        
        if '<base href' not in html:
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
            parsed = urlparse.urlparse(url)
            if parsed.scheme == parsed.netloc == '': #relative to domain
                url = urlparse.urljoin(self.feed.feed_link, url)
                ret.append(document[last_end:match.start(2)])
                ret.append('"%s"' % (url,))
                last_end = match.end(2)
        ret.append(document[last_end:])
        
        return ''.join(ret)
        
    def save_page(self, html):
        saved = False
        
        if not html or len(html) < 100:
            return
        
        if settings.BACKED_BY_AWS.get('pages_on_node'):
            saved = self.save_page_node(html)
            if saved and self.feed.s3_page and settings.BACKED_BY_AWS.get('pages_on_s3'):
                self.delete_page_s3()
            
        if settings.BACKED_BY_AWS.get('pages_on_s3') and not saved:
            saved = self.save_page_s3(html)
            
        if not saved:
            try:
                feed_page = MFeedPage.objects.get(feed_id=self.feed.pk)
                # feed_page.page_data = html.encode('utf-8')
                if feed_page.page() == html:
                    logging.debug('   ---> [%-30s] ~FYNo change in page data: %s' % (self.feed.title[:30], self.feed.feed_link))
                else:
                    feed_page.page_data = html
                    feed_page.save()
            except MFeedPage.DoesNotExist:
                feed_page = MFeedPage.objects.create(feed_id=self.feed.pk, page_data=html)
            return feed_page
    
    def save_page_node(self, html):
        url = "http://%s/original_page/%s" % (
            settings.ORIGINAL_PAGE_SERVER,
            self.feed.pk,
        )
        response = requests.post(url, files={
            'original_page': compress_string(html),
        })
        if response.status_code == 200:
            return True
    
    def save_page_s3(self, html):
        k = Key(settings.S3_PAGES_BUCKET)
        k.key = self.feed.s3_pages_key
        k.set_metadata('Content-Encoding', 'gzip')
        k.set_metadata('Content-Type', 'text/html')
        k.set_metadata('Access-Control-Allow-Origin', '*')
        k.set_contents_from_string(compress_string(html))
        k.set_acl('public-read')
        
        try:
            feed_page = MFeedPage.objects.get(feed_id=self.feed.pk)
            feed_page.delete()
            logging.debug('   ---> [%-30s] ~FYTransfering page data to S3...' % (self.feed))
        except MFeedPage.DoesNotExist:
            pass
            
        if not self.feed.s3_page:
            self.feed.s3_page = True
            self.feed.save()
        
        return True
    
    def delete_page_s3(self):
        k = Key(settings.S3_PAGES_BUCKET)
        k.key = self.feed.s3_pages_key
        k.delete()
        
        self.feed.s3_page = False
        self.feed.save()
