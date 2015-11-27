import requests
import zlib
from requests.packages.urllib3.exceptions import LocationParseError
from socket import error as SocketError
from mongoengine.queryset import NotUniqueError
from vendor.readability import readability
from utils import log as logging
from utils.feed_functions import timelimit, TimeoutError
from OpenSSL.SSL import Error as OpenSSLError
from pyasn1.error import PyAsn1Error

BROKEN_URLS = [
    "gamespot.com",
]


class TextImporter:

    def __init__(self, story=None, feed=None, story_url=None, request=None, debug=False):
        self.story = story
        self.story_url = story_url
        self.feed = feed
        self.request = request
        self.debug = debug

    @property
    def headers(self):
        return {
            'User-Agent': 'NewsBlur Content Fetcher - %s subscriber%s - %s '
                          '(Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_1) '
                          'AppleWebKit/534.48.3 (KHTML, like Gecko) Version/5.1 '
                          'Safari/534.48.3)' % (
                              self.feed.num_subscribers,
                              's' if self.feed.num_subscribers != 1 else '',
                              self.feed.permalink,
                          ),
        }

    def fetch(self, skip_save=False, return_document=False):
        if self.story_url and any(broken_url in self.story_url for broken_url in BROKEN_URLS):
            logging.user(self.request, "~SN~FRFailed~FY to fetch ~FGoriginal text~FY: banned")
            return

        try:
            resp = self.fetch_request()
        except TimeoutError:
            logging.user(self.request, "~SN~FRFailed~FY to fetch ~FGoriginal text~FY: timed out")
            resp = None
        except requests.exceptions.TooManyRedirects:
            logging.user(self.request, "~SN~FRFailed~FY to fetch ~FGoriginal text~FY: too many redirects")
            resp = None

        if not resp:
            return

        try:
            text = resp.text
        except (LookupError, TypeError):
            text = resp.content

        charset_declared = 'charset' in resp.headers.get('content-type', "")
        if resp.encoding and resp.encoding != 'utf-8' and not charset_declared:
            try:
                text = text.encode(resp.encoding)
            except (LookupError, UnicodeEncodeError):
                pass
        original_text_doc = readability.Document(text, url=resp.url,
                                                 debug=self.debug,
                                                 positive_keywords=["postContent", "postField"])
        try:
            content = original_text_doc.summary(html_partial=True)
        except readability.Unparseable:
            return

        try:
            title = original_text_doc.title()
        except TypeError:
            title = ""
        url = resp.url

        if content:
            if self.story and not skip_save:
                self.story.original_text_z = zlib.compress(content)
                try:
                    self.story.save()
                except NotUniqueError:
                    pass
            logging.user(self.request, ("~SN~FYFetched ~FGoriginal text~FY: now ~SB%s bytes~SN vs. was ~SB%s bytes" % (
                len(unicode(content)),
                self.story and self.story.story_content_z and len(zlib.decompress(self.story.story_content_z))
            )), warn_color=False)
        else:
            logging.user(self.request, ("~SN~FRFailed~FY to fetch ~FGoriginal text~FY: was ~SB%s bytes" % (
                self.story and self.story.story_content_z and len(zlib.decompress(self.story.story_content_z))
            )), warn_color=False)

        if return_document:
            return dict(content=content, title=title, url=url, doc=original_text_doc)

        return content

    @timelimit(10)
    def fetch_request(self):
        url = self.story_url
        if self.story and not url:
            url = self.story.story_permalink
        try:
            r = requests.get(url, headers=self.headers, verify=False)
            r.connection.close()
        except (AttributeError, SocketError, requests.ConnectionError,
                requests.models.MissingSchema, requests.sessions.InvalidSchema,
                LocationParseError, OpenSSLError, PyAsn1Error), e:
            logging.user(self.request, "~SN~FRFailed~FY to fetch ~FGoriginal text~FY: %s" % e)
            return
        return r
