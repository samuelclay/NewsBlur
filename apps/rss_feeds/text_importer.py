import requests
import zlib
from django.conf import settings
from vendor.readability import readability
from utils import log as logging


class TextImporter:
    
    def __init__(self, story, request=None):
        self.story = story
        self.request = request
    
    @property
    def headers(self):
        return {
            'User-Agent': 'NewsBlur Content Fetcher - %s '
                          '(Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_1) '
                          'AppleWebKit/534.48.3 (KHTML, like Gecko) Version/5.1 '
                          'Safari/534.48.3)' % (
                settings.NEWSBLUR_URL
            ),
            'Connection': 'close',
        }
    
    def fetch(self):
        html = requests.get(self.story.story_permalink, headers=self.headers)
        original_text_doc = readability.Document(html.text, url=html.url, debug=settings.DEBUG)
        content = original_text_doc.summary(html_partial=True)
        if content:
            self.story.original_text_z = zlib.compress(content)
            self.story.save()
            logging.user(self.request, "~SN~FYFetched ~FGoriginal text~FY: now ~SB%s bytes~SN vs. was ~SB%s bytes" % (
                len(unicode(content)),
                len(zlib.decompress(self.story.story_content_z))
            ))
        else:
            logging.user(self.request, "~SN~FRFailed~FY to fetch ~FGoriginal text~FY: was ~SB%s bytes" % (
                len(zlib.decompress(self.story.story_content_z))
            ))
        
        return content