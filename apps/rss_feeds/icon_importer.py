import urllib2
import lxml.html
import scipy
import scipy.misc
import scipy.cluster
from StringIO import StringIO
from PIL import ImageFile
import ImageChops, Image
from django.conf import settings

class BadImage(Exception): pass

class IconImporter(object):
    
    def __init__(self, feed, force=False):
        self.feed = feed
        self.force = force
    
    def save(self):
        if not self.force and self.feed.icon.not_found:
            print 'Not found, skipping...'
            return
        image, icon_url = self.fetch(force=self.force)

        if image:
            image     = self.normalize_image(image)
            color     = self.determine_dominant_color_in_image(image)
            image_str = self.string_from_image(image)

            self.feed.icon.data      = image_str
            self.feed.icon.icon_url  = icon_url
            self.feed.icon.color     = color
            self.feed.icon.not_found = False
        else:
            self.feed.icon.not_found = True
            
        self.feed.icon.save()
        return not self.feed.icon.not_found
       
    def fetch(self, path='favicon.ico', force=False):
        HEADERS = {
            'User-Agent': 'NewsBlur Favicon Fetcher - http://www.newsblur.com',
            'Connection': 'close',
        }
        image = None
        url = None

        if not force:
            url = self.feed.icon.icon_url
        if not url:
            url = self.feed.feed_link

        if not url.endswith('/') and not url.endswith('favicon.ico'):
            url += '/favicon.ico'
        if url.endswith('/'):
            url += 'favicon.ico'

        def request_image(url):
            print 'Requesting: %s' % url
            request = urllib2.Request(url, headers=HEADERS)
            icon = urllib2.urlopen(request)
            parser = ImageFile.Parser()
            s = icon.read()
            if s:
                parser.feed(s)
            try:
                image = parser.close()
                return image
            except IOError:
                raise BadImage
        
        try:
            image = request_image(url)
        except (urllib2.HTTPError, urllib2.URLError, BadImage):
            request = urllib2.Request(self.feed.feed_link, headers=HEADERS)
            try:
                # 2048 bytes should be enough for most of websites
                content = urllib2.urlopen(request).read(2048) 
            except(urllib2.HTTPError, urllib2.URLError):
                return None, None
            icon_path = lxml.html.fromstring(content).xpath(
                '//link[@rel="icon" or @rel="shortcut icon"]/@href'
            )
            if icon_path:
                if str(icon_path[0]).startswith('http'):
                    url = icon_path[0]
                else:
                    url = self.feed.feed_link + icon_path[0]
                try:
                    image = request_image(url)
                except(urllib2.HTTPError, urllib2.URLError, BadImage):
                    return None, None
        print 'Found: %s - %s' % (url, image)
        return image, url
    
    def normalize_image(self, image):
        image = image.resize((16, 16), Image.ANTIALIAS)
        if image.mode != 'RGBA':
            image = image.convert('RGBA')
        # mask = Image.open(settings.IMAGE_MASK)
        print image
        print image.mode
        print image.size
        # mask = mask.convert('L')
        # print mask
        # image.paste(Image.new('RGBA', image.size, '#FFFFFF'), (0, 0), ImageChops.invert(mask))
        # image.putalpha(mask)
        
        return image

    def determine_dominant_color_in_image(self, image):
        NUM_CLUSTERS = 5

        # if image.mode == 'P':
        #     image.putalpha(0)
            
        ar = scipy.misc.fromimage(image)
        shape = ar.shape
        if len(shape) > 2:
            ar = ar.reshape(scipy.product(shape[:2]), shape[2])

        codes, dist = scipy.cluster.vq.kmeans(ar, NUM_CLUSTERS)
        colors = [''.join(chr(c) for c in code).encode('hex') for code in codes]
    
        vecs, dist = scipy.cluster.vq.vq(ar, codes)         # assign codes
        counts, bins = scipy.histogram(vecs, len(codes))    # count occurrences
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
        print contents.encode('base64')
        return contents.encode('base64')
    