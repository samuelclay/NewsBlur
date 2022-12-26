import requests
import urllib3
import zlib
from vendor import readability
from simplejson.decoder import JSONDecodeError
from requests.packages.urllib3.exceptions import LocationParseError
from socket import error as SocketError
from mongoengine.queryset import NotUniqueError
from lxml.etree import ParserError
from vendor.readability.readability import Unparseable
from utils import log as logging
from utils.feed_functions import timelimit, TimeoutError
from OpenSSL.SSL import Error as OpenSSLError
from pyasn1.error import PyAsn1Error
from django.utils.encoding import smart_str
from django.conf import settings
from django.utils.encoding import smart_bytes
from django.contrib.sites.models import Site
from bs4 import BeautifulSoup
from urllib.parse import urljoin
 
BROKEN_URLS = [
    "gamespot.com",
    'thedailyskip.com',
]


class TextImporter:

    def __init__(self, story=None, feed=None, story_url=None, request=None, debug=False):
        self.story = story
        self.story_url = story_url
        if self.story and not self.story_url:
            self.story_url = self.story.story_permalink
        self.feed = feed
        self.request = request
        self.debug = debug

    @property
    def headers(self):
        num_subscribers = getattr(self.feed, 'num_subscribers', 0)
        return {
            'User-Agent': 'NewsBlur Content Fetcher - %s subscriber%s - %s %s' % (
                              num_subscribers,
                              's' if num_subscribers != 1 else '',
                              getattr(self.feed, 'permalink', ''),
                              getattr(self.feed, 'fake_user_agent', ''),
                          ),
        }

    def fetch(self, skip_save=False, return_document=False, use_mercury=True):
        if self.story_url and any(broken_url in self.story_url for broken_url in BROKEN_URLS):
            logging.user(self.request, "~SN~FRFailed~FY to fetch ~FGoriginal text~FY: banned")
            return
        
        if use_mercury:
            results = self.fetch_mercury(skip_save=skip_save, return_document=return_document)
        
        if not use_mercury or not results:
            logging.user(self.request, "~SN~FRFailed~FY to fetch ~FGoriginal text~FY with Mercury, trying readability...", warn_color=False)

            results = self.fetch_manually(skip_save=skip_save, return_document=return_document)
        
        return results
    
    def fetch_mercury(self, skip_save=False, return_document=False):
        try:
            resp = self.fetch_request(use_mercury=True)
        except TimeoutError:
            logging.user(self.request, "~SN~FRFailed~FY to fetch ~FGoriginal text~FY: timed out")
            resp = None
        except requests.exceptions.TooManyRedirects:
            logging.user(self.request, "~SN~FRFailed~FY to fetch ~FGoriginal text~FY: too many redirects")
            resp = None
        
        if not resp:
            return
        
        try:
            doc = resp.json()
        except JSONDecodeError:
            doc = None
        if not doc or doc.get('error', False):
            logging.user(self.request, "~SN~FRFailed~FY to fetch ~FGoriginal text~FY: %s" % (doc and doc.get('messages', None) or "[unknown mercury error]"))
            return
        
        text = doc['content']
        title = doc['title']
        url = doc['url']
        image = doc['lead_image_url']
        
        if image and ('http://' in image[1:] or 'https://' in image[1:]):
            logging.user(self.request, "~SN~FRRemoving broken image from text: %s" % image)
            image = None
        
        return self.process_content(text, title, url, image, skip_save=skip_save, return_document=return_document)
        
    def fetch_manually(self, skip_save=False, return_document=False):
        try:
            resp = self.fetch_request(use_mercury=False)
        except TimeoutError:
            logging.user(self.request, "~SN~FRFailed~FY to fetch ~FGoriginal text~FY: timed out")
            resp = None
        except requests.exceptions.TooManyRedirects:
            logging.user(self.request, "~SN~FRFailed~FY to fetch ~FGoriginal text~FY: too many redirects")
            resp = None

        if not resp:
            return

        @timelimit(5)
        def extract_text(resp):
            try:
                text = resp.text
            except (LookupError, TypeError):
                text = resp.content
            return text
        try:
            text = extract_text(resp)
        except TimeoutError:
            logging.user(self.request, "~SN~FRFailed~FY to fetch ~FGoriginal text~FY: timed out on resp.text")
            return
        
        # if self.debug:
        #     logging.user(self.request, "~FBOriginal text's website: %s" % text)
        
        # if resp.encoding and resp.encoding != 'utf-8':
        #     try:
        #         text = text.encode(resp.encoding)
        #     except (LookupError, UnicodeEncodeError):
        #         pass

        if text:
            text = text.replace("\xc2\xa0", " ") # Non-breaking space, is mangled when encoding is not utf-8
            text = text.replace("\\u00a0", " ") # Non-breaking space, is mangled when encoding is not utf-8

        original_text_doc = readability.Document(text, url=resp.url,
                                                 positive_keywords="post, entry, postProp, article, postContent, postField")
        try:
            content = original_text_doc.summary(html_partial=True)
        except (ParserError, Unparseable) as e:
            logging.user(self.request, "~SN~FRFailed~FY to fetch ~FGoriginal text~FY: %s" % e)
            return

        try:
            title = original_text_doc.title()
        except TypeError:
            title = ""

        url = resp.url
        
        return self.process_content(content, title, url, image=None, skip_save=skip_save, return_document=return_document,
                                    original_text_doc=original_text_doc)
        
    def process_content(self, content, title, url, image, skip_save=False, return_document=False, original_text_doc=None):
        original_story_content = self.story and self.story.story_content_z and zlib.decompress(self.story.story_content_z)
        if not original_story_content:
            original_story_content = ""
        story_image_urls = self.story and self.story.image_urls
        if not story_image_urls:
            story_image_urls = []
        
        content = self.add_hero_image(content, story_image_urls)
        if content:
            content = self.rewrite_content(content)

        full_content_is_longer = False
        if self.feed and self.feed.is_newsletter:
            full_content_is_longer = True
        elif len(content) > len(original_story_content):
            full_content_is_longer = True
        
        if content and full_content_is_longer:
            if self.story and not skip_save:
                self.story.original_text_z = zlib.compress(smart_bytes(content))
                try:
                    self.story.save()
                except NotUniqueError as e:
                    logging.user(self.request, ("~SN~FYFetched ~FGoriginal text~FY: %s" % (e)), warn_color=False)
                    pass
            logging.user(self.request, ("~SN~FYFetched ~FGoriginal text~FY: now ~SB%s bytes~SN vs. was ~SB%s bytes" % (
                len(content),
                len(original_story_content)
            )), warn_color=False)
        else:
            logging.user(self.request, ("~SN~FRFailed~FY to fetch ~FGoriginal text~FY: was ~SB%s bytes" % (
                len(original_story_content)
            )), warn_color=False)
            return
        
        if return_document:
            return dict(content=content, title=title, url=url, doc=original_text_doc, image=image)

        return content

    def add_hero_image(self, content, image_urls):
        # Need to have images in the original story to add to the text that may not have any images
        if not len(image_urls): 
            return content
        
        content_soup = BeautifulSoup(content, features="lxml")

        content_imgs = content_soup.findAll('img')
        for img in content_imgs:
            # Since NewsBlur proxies all http images over https, the url can change, so acknowledge urls
            # that are https on the original text but http on the feed
            if not img.get('src'): continue
            if img.get('src') in image_urls:
                image_urls.remove(img.get('src'))
            elif img.get('src').replace('https:', 'http:') in image_urls:
                image_urls.remove(img.get('src').replace('https:', 'http:'))
        
        if len(image_urls):
            image_content = f'<img src="{image_urls[0]}">'
            content = f"{image_content}\n {content}"

        return content

    def rewrite_content(self, content):
        soup = BeautifulSoup(content, features="lxml")
        
        for noscript in soup.findAll('noscript'):
            if len(noscript.contents) > 0:
                noscript.replaceWith(noscript.contents[0])
        
        content = str(soup)
        
        images = set([img.attrs['src'] for img in soup.findAll('img') if 'src' in img.attrs])
        for image_url in images:
            abs_image_url = urljoin(self.story_url, image_url)
            content = content.replace(image_url, abs_image_url)
        
        return content
    
    @timelimit(10)
    def fetch_request(self, use_mercury=True):
        headers = self.headers
        url = self.story_url
        
        if use_mercury:
            mercury_api_key = getattr(settings, 'MERCURY_PARSER_API_KEY', 'abc123')
            headers["content-type"] = "application/json"
            headers["x-api-key"] = mercury_api_key
            domain = Site.objects.get_current().domain
            protocol = "https"
            if settings.DOCKERBUILD:
                domain = 'haproxy'
                protocol = "http"
            url = f"{protocol}://{domain}/rss_feeds/original_text_fetcher?url={url}"
            
        try:
            r = requests.get(url, headers=headers, timeout=15)
            r.connection.close()
        except (AttributeError, SocketError, requests.ConnectionError,
                requests.models.MissingSchema, requests.sessions.InvalidSchema,
                requests.sessions.TooManyRedirects,
                requests.models.InvalidURL,
                requests.models.ChunkedEncodingError,
                requests.models.ContentDecodingError,
                requests.adapters.ReadTimeout,
                urllib3.exceptions.LocationValueError,
                LocationParseError, OpenSSLError, PyAsn1Error) as e:
            logging.user(self.request, "~SN~FRFailed~FY to fetch ~FGoriginal text~FY: %s" % e)
            return
        return r
