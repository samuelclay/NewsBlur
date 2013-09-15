import requests
import zlib
from django.conf import settings
from socket import error as SocketError
from mongoengine.queryset import NotUniqueError
from vendor.readability import readability
from utils import log as logging
from utils.feed_functions import timelimit, TimeoutError

class TextImporter:
    
    def __init__(self, story, feed, request=None):
        self.story = story
        self.feed = feed
        self.request = request
    
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
            'Connection': 'close',
        }
    
    def fetch(self, skip_save=False):
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

        if resp.encoding and resp.encoding != 'utf-8':
            try:
                text = text.encode(resp.encoding)
            except (LookupError, UnicodeEncodeError):
                pass
        original_text_doc = readability.Document(text, url=resp.url, debug=settings.DEBUG)
        try:
            content = original_text_doc.summary(html_partial=True)
        except readability.Unparseable:
            return
        
        if content:
            if not skip_save:
                self.story.original_text_z = zlib.compress(content)
                try:
                    self.story.save()
                except NotUniqueError:
                    pass
            logging.user(self.request, ("~SN~FYFetched ~FGoriginal text~FY: now ~SB%s bytes~SN vs. was ~SB%s bytes" % (
                len(unicode(content)),
                self.story.story_content_z and len(zlib.decompress(self.story.story_content_z))
            )), warn_color=False)
        else:
            logging.user(self.request, ("~SN~FRFailed~FY to fetch ~FGoriginal text~FY: was ~SB%s bytes" % (
                self.story.story_content_z and len(zlib.decompress(self.story.story_content_z))
            )), warn_color=False)
        
        return content
    
    @timelimit(10)
    def fetch_request(self):
        try:
            r = requests.get(self.story.story_permalink, headers=self.headers, verify=False)
        except (AttributeError, SocketError, requests.ConnectionError, 
                requests.models.MissingSchema, requests.sessions.InvalidSchema), e:
            logging.user(self.request, "~SN~FRFailed~FY to fetch ~FGoriginal text~FY: %s" % e)
            return
        return r
