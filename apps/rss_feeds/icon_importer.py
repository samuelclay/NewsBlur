import urllib2
import lxml.html
import scipy
import scipy.misc
import scipy.cluster
import Image
import urlparse
import operator
import struct
from StringIO import StringIO
from apps.rss_feeds.models import MFeedPage
from PIL import BmpImagePlugin, PngImagePlugin, ImageFile

HEADERS = {
    'User-Agent': 'NewsBlur Favicon Fetcher - http://www.newsblur.com',
    'Connection': 'close',
}

class IconImporter(object):
    
    def __init__(self, feed, force=False):
        self.feed = feed
        self.force = force
    
    def save(self):
        if not self.force and self.feed.icon.not_found:
            print 'Not found, skipping...'
            return
        image, icon_url = self.fetch_image_from_page_data()
        if not image:
            image, icon_url = self.fetch(force=self.force)

        if image:
            image     = self.normalize_image(image)
            color     = self.determine_dominant_color_in_image(image)
            image_str = self.string_from_image(image)

            self.feed.icon.save()
            self.feed.icon.data      = image_str
            self.feed.icon.icon_url  = icon_url
            self.feed.icon.color     = color
            self.feed.icon.not_found = False
        else:
            self.feed.icon.save()
            self.feed.icon.not_found = True
            
        self.feed.icon.save()
        return not self.feed.icon.not_found
     
    def fetch_image_from_page_data(self):
        image = None
        content = MFeedPage.get_data(feed_id=self.feed.pk)
        url = self._url_from_html(content)
        if url:
            image = self.get_image_from_url(url)
        return image, url

    def fetch(self, path='favicon.ico', force=False):
        image = None
        url = None

        if not force:
            url = self.feed.icon.icon_url
        if not url:
            url = urlparse.urljoin(self.feed.feed_link, 'favicon.ico')

        image = self.get_image_from_url(url)
        if not image:
            url = urlparse.urljoin(self.feed.feed_link, '/favicon.ico')
            image = self.get_image_from_url(url)
            if not image:
                request = urllib2.Request(self.feed.feed_link, headers=HEADERS)
                try:
                    # 2048 bytes should be enough for most of websites
                    content = urllib2.urlopen(request).read(2048) 
                except(urllib2.HTTPError, urllib2.URLError):
                    return None, None
                url = self._url_from_html(content)
                if url:
                    try:
                        image = self.get_image_from_url(url)
                    except(urllib2.HTTPError, urllib2.URLError):
                        return None, None
        print 'Found: %s - %s' % (url, image)
        return image, url
    
    def get_image_from_url(self, url):
        print 'Requesting: %s' % url
        try:
            request = urllib2.Request(url, headers=HEADERS)
            icon = urllib2.urlopen(request)
        except (urllib2.HTTPError, urllib2.URLError), e:
            return None
        parser = ImageFile.Parser()
        s = icon.read()
        if s:
            parser.feed(s)
        try:
            image = parser.close()
            return image
        except IOError, e:
            return None
    
    def _url_from_html(self, content):
        url = None
        icon_path = lxml.html.fromstring(content).xpath(
            '//link[@rel="icon" or @rel="shortcut icon"]/@href'
        )
        if icon_path:
            if str(icon_path[0]).startswith('http'):
                url = icon_path[0]
            else:
                url = urlparse.urljoin(self.feed.feed_link, icon_path[0])
        return url
        
    def normalize_image(self, image):
        print image.size
        # if image.size != (16, 16):
        #     image = image.resize((16, 16), Image.BICUBIC)
        print image
        if image.mode != 'RGBA':
            image = image.convert('RGBA')
        
        return image

    def determine_dominant_color_in_image(self, image):
        NUM_CLUSTERS = 5
            
        ar = scipy.misc.fromimage(image)
        shape = ar.shape
        if len(shape) > 2:
            ar = ar.reshape(scipy.product(shape[:2]), shape[2])

        codes, _ = scipy.cluster.vq.kmeans(ar, NUM_CLUSTERS)
        print "Before: %s" % codes
        original_codes = codes
        for low, hi in [(60, 200), (35, 230), (10, 250)]:
            codes = scipy.array([code for code in codes 
                                 if not ((code[0] < low and code[1] < low and code[2] < low) or
                                         (code[0] > hi and code[1] > hi and code[2] > hi))])
            if not len(codes): codes = original_codes
            else: break
        print "After: %s" % codes
        colors = [''.join(chr(c) for c in code).encode('hex') for code in codes]
    
        vecs, _ = scipy.cluster.vq.vq(ar, codes)         # assign codes
        counts, bins = scipy.histogram(vecs, len(codes))    # count occurrences
        print counts
        total = scipy.sum(counts)
        print dict(zip(colors, [count/float(total) for count in counts]))
        index_max = scipy.argmax(counts)                    # find most frequent
        peak = codes[index_max]
        color = ''.join(chr(c) for c in peak).encode('hex')
        print 'most frequent is %s (#%s)' % (peak, color)
        
        return color[:6]

    def string_from_image(self, image):
        output = StringIO()
        image.save(output, 'png', quality=95)
        contents = output.getvalue()
        output.close()
        return contents.encode('base64')
    