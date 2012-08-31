import urllib2
import lxml.html
import scipy
import scipy.misc
import scipy.cluster
import urlparse
import struct
import operator
import BmpImagePlugin, PngImagePlugin, Image
from StringIO import StringIO
from apps.rss_feeds.models import MFeedPage, MFeedIcon
from utils.feed_functions import timelimit, TimeoutError

HEADERS = {
    'User-Agent': 'NewsBlur Favicon Fetcher - http://www.newsblur.com',
    'Connection': 'close',
}

class IconImporter(object):
    
    def __init__(self, feed, page_data=None, force=False):
        self.feed = feed
        self.force = force
        self.page_data = page_data
        self.feed_icon, _ = MFeedIcon.objects.get_or_create(feed_id=self.feed.pk)
    
    def save(self):
        if not self.force and self.feed.favicon_not_found:
            # print 'Not found, skipping...'
            return
        if not self.force and not self.feed.favicon_not_found and self.feed_icon.icon_url:
            # print 'Found, but skipping...'
            return
        image, image_file, icon_url = self.fetch_image_from_page_data()
        if not image:
            image, image_file, icon_url = self.fetch_image_from_path(force=self.force)

        if image:
            try:
                ico_image = self.load_icon(image_file)
                if ico_image: image = ico_image
            except ValueError:
                # print "Bad .ICO"
                pass
            image     = self.normalize_image(image)
            color     = self.determine_dominant_color_in_image(image)
            image_str = self.string_from_image(image)

            if (self.feed_icon.color != color or 
                self.feed_icon.data != image_str or 
                self.feed_icon.icon_url != icon_url or
                self.feed_icon.not_found):
                self.feed_icon.data      = image_str
                self.feed_icon.icon_url  = icon_url
                self.feed_icon.color     = color
                self.feed_icon.not_found = False
                self.feed_icon.save()
            self.feed.favicon_color     = color
            self.feed.favicon_not_found = False
        else:
            self.feed_icon.not_found = True
            self.feed.favicon_not_found = True
            
        self.feed.save()
        return not self.feed.favicon_not_found
     
    def load_icon(self, image_file, index=None):
        '''
        Load Windows ICO image.

        See http://en.wikipedia.org/w/index.php?oldid=264332061 for file format
        description.
        
        Cribbed and modified from http://djangosnippets.org/snippets/1287/
        '''
        try:
            image_file.seek(0)
            header = struct.unpack('<3H', image_file.read(6))
        except Exception, e:
            return

        # Check magic
        if header[:2] != (0, 1):
            return

        # Collect icon directories
        directories = []
        for i in xrange(header[2]):
            directory = list(struct.unpack('<4B2H2I', image_file.read(16)))
            for j in xrange(3):
                if not directory[j]:
                    directory[j] = 256

            directories.append(directory)

        if index is None:
            # Select best icon
            directory = max(directories, key=operator.itemgetter(slice(0, 3)))
        else:
            directory = directories[index]

        # Seek to the bitmap data
        image_file.seek(directory[7])

        prefix = image_file.read(16)
        image_file.seek(-16, 1)

        if PngImagePlugin._accept(prefix):
            # Windows Vista icon with PNG inside
            try:
                image = PngImagePlugin.PngImageFile(image_file)
            except IOError:
                return
        else:
            # Load XOR bitmap
            image = BmpImagePlugin.DibImageFile(image_file)
            if image.mode == 'RGBA':
                # Windows XP 32-bit color depth icon without AND bitmap
                pass
            else:
                # Patch up the bitmap height
                image.size = image.size[0], image.size[1] >> 1
                d, e, o, a = image.tile[0]
                image.tile[0] = d, (0, 0) + image.size, o, a

                # Calculate AND bitmap dimensions. See
                # http://en.wikipedia.org/w/index.php?oldid=264236948#Pixel_storage
                # for description
                offset = o + a[1] * image.size[1]
                stride = ((image.size[0] + 31) >> 5) << 2
                size = stride * image.size[1]

                # Load AND bitmap
                image_file.seek(offset)
                string = image_file.read(size)
                mask = Image.fromstring('1', image.size, string, 'raw',
                                        ('1;I', stride, -1))

                image = image.convert('RGBA')
                image.putalpha(mask)

        return image
        
    def fetch_image_from_page_data(self):
        image = None
        image_file = None
        if self.page_data:
            content = self.page_data
        else:
            content = MFeedPage.get_data(feed_id=self.feed.pk)
        url = self._url_from_html(content)
        if url:
            image, image_file = self.get_image_from_url(url)
        return image, image_file, url

    def fetch_image_from_path(self, path='favicon.ico', force=False):
        image = None
        url = None

        if not force:
            url = self.feed_icon.icon_url
        if not url and self.feed.feed_link and len(self.feed.feed_link) > 6:
            url = urlparse.urljoin(self.feed.feed_link, 'favicon.ico')
        if not url: return None, None, None

        image, image_file = self.get_image_from_url(url)
        if not image:
            url = urlparse.urljoin(self.feed.feed_link, '/favicon.ico')
            image, image_file = self.get_image_from_url(url)
        # print 'Found: %s - %s' % (url, image)
        return image, image_file, url
    
    def get_image_from_url(self, url):
        # print 'Requesting: %s' % url
        @timelimit(30)
        def _1(url):
            try:
                request = urllib2.Request(url, headers=HEADERS)
                icon = urllib2.urlopen(request).read()
            except Exception:
                return None
            return icon
        try:
            icon = _1(url)
        except TimeoutError:
            return None, None
        
        try:
            icon_file = StringIO(icon)
            image = Image.open(icon_file)
        except (IOError, ValueError):
            return None, None
            
        return image, icon_file
    
    def _url_from_html(self, content):
        url = None
        if not content: return url
        try:
            if isinstance(content, unicode):
                content = content.encode('utf-8')
            icon_path = lxml.html.fromstring(content).xpath(
                '//link[@rel="icon" or @rel="shortcut icon"]/@href'
            )
        except (lxml.etree.ParserError, TypeError):
            return url
            
        if icon_path:
            if str(icon_path[0]).startswith('http'):
                url = icon_path[0]
            else:
                url = urlparse.urljoin(self.feed.feed_link, icon_path[0])
        return url
        
    def normalize_image(self, image):
        # if image.size != (16, 16):
        #     image = image.resize((16, 16), Image.BICUBIC)
        if image.mode != 'RGBA':
            try:
                image = image.convert('RGBA')
            except IOError:
                pass
        
        return image

    def determine_dominant_color_in_image(self, image):
        NUM_CLUSTERS = 5
        
        # Convert image into array of values for each point.
        ar = scipy.misc.fromimage(image)
        shape = ar.shape
        
        # Reshape array of values to merge color bands. [[R], [G], [B], [A]] => [R, G, B, A]
        if len(shape) > 2:
            ar = ar.reshape(scipy.product(shape[:2]), shape[2])
            
        # Get NUM_CLUSTERS worth of centroids.
        codes, _ = scipy.cluster.vq.kmeans(ar, NUM_CLUSTERS)
        
        # Pare centroids, removing blacks and whites and shades of really dark and really light.
        original_codes = codes
        for low, hi in [(60, 200), (35, 230), (10, 250)]:
            codes = scipy.array([code for code in codes 
                                 if not ((code[0] < low and code[1] < low and code[2] < low) or
                                         (code[0] > hi and code[1] > hi and code[2] > hi))])
            if not len(codes): codes = original_codes
            else: break
    
        # Assign codes (vector quantization). Each vector is compared to the centroids
        # and assigned the nearest one.
        vecs, _ = scipy.cluster.vq.vq(ar, codes)
        
        # Count occurences of each clustered vector.
        counts, bins = scipy.histogram(vecs, len(codes))

        # Show colors for each code in its hex value.
        # colors = [''.join(chr(c) for c in code).encode('hex') for code in codes]
        # total = scipy.sum(counts)
        # print dict(zip(colors, [count/float(total) for count in counts]))
        
        # Find the most frequent color, based on the counts.
        index_max = scipy.argmax(counts)
        peak = codes[index_max]
        color = ''.join(chr(c) for c in peak).encode('hex')
        
        return color[:6]

    def string_from_image(self, image):
        output = StringIO()
        image.save(output, 'png', quality=95)
        contents = output.getvalue()
        output.close()
        return contents.encode('base64')
    