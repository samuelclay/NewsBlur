import urllib2
import lxml.html
import scipy
import scipy.misc
import scipy.cluster
import StringIO
from PIL import ImageFile

class IconImporter(object):
    
    def __init__(self, feed):
        self.feed = feed
    
    def save(self):
        image, icon_url = self.fetch()
        if not image: return
        color = self.determine_dominant_color_in_image(image)
        image_str = self.string_from_image(image)
        self.feed.icon.data = image_str
        self.feed.icon.icon_url = icon_url
        self.feed.icon.color = color
        self.feed.icon.save()
       
    def fetch(self, path='favicon.ico'):
        HEADERS = {
            'User-Agent': 'NewsBlur Favicon Fetcher - http://www.newsblur.com',
            'Connection': 'close',
        }
        image = None
        url = self.feed.icon.icon_url
        
        if not url:
            url = self.feed.feed_link

        if not url.endswith('/') and not url.endswith('favicon.ico'):
            url += '/favicon.ico'
        if url.endswith('/'):
            url += 'favicon.ico'

        def request_image(request):
            icon = urllib2.urlopen(request)
            parser = ImageFile.Parser()
            while True:
                s = icon.read(1024)
                if not s:
                    break
                parser.feed(s)
            image = parser.close()
            return image
        
        request = urllib2.Request(url, headers=HEADERS)
        try:
            image = request_image(request)
        except(urllib2.HTTPError, urllib2.URLError):
            request = urllib2.Request(self.feed.feed_link, headers=HEADERS)
            try:
                # 2048 bytes should be enough for most of websites
                content = urllib2.urlopen(request).read(2048) 
            except(urllib2.HTTPError, urllib2.URLError):
                return
            icon_path = lxml.html.fromstring(content).xpath(
                '//link[@rel="icon" or @rel="shortcut icon"]/@href'
            )
            if icon_path:
                url = self.feed.feed_link + icon_path[0]
                request = urllib2.Request(url, headers=HEADERS)
                try:
                    image = request_image(request)
                except(urllib2.HTTPError, urllib2.URLError):
                    return
    
        image = image.resize((16, 16))
    
        return image, url

    def determine_dominant_color_in_image(self, image):
        NUM_CLUSTERS = 5

        if image.mode == 'P':
            image.putalpha(0)
            
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
        
        return color

    def string_from_image(self, image):
        output = StringIO.StringIO()
        image.save(output, format="PNG")
        contents = output.getvalue()
        output.close()
        print contents.encode('base64')
        return contents.encode('base64')
    