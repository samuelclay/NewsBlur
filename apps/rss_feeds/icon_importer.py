import urllib.request
import urllib.error
import urllib.parse
import lxml.html
import numpy
import scipy
import scipy.misc
import scipy.cluster
import struct
import operator
import gzip
import datetime
import requests
import base64
import http.client
from PIL import BmpImagePlugin, PngImagePlugin, Image
from socket import error as SocketError
import boto3
from io import BytesIO
from django.conf import settings
from django.http import HttpResponse
from django.contrib.sites.models import Site
from apps.rss_feeds.models import MFeedPage, MFeedIcon
from utils.facebook_fetcher import FacebookFetcher
from utils import log as logging
from utils.feed_functions import timelimit, TimeoutError
from OpenSSL.SSL import Error as OpenSSLError, SESS_CACHE_NO_INTERNAL_STORE
from pyasn1.error import PyAsn1Error
from requests.packages.urllib3.exceptions import LocationParseError


class IconImporter(object):

    def __init__(self, feed, page_data=None, force=False):
        self.feed = feed
        self.force = force
        self.page_data = page_data
        self.feed_icon = MFeedIcon.get_feed(feed_id=self.feed.pk)

    def save(self):
        if not self.force and self.feed.favicon_not_found:
            # print 'Not found, skipping...'
            return
        if (
                not self.force
                and not self.feed.favicon_not_found
                and self.feed_icon.icon_url
                and self.feed.s3_icon
        ):
            # print 'Found, but skipping...'
            return
        if 'facebook.com' in self.feed.feed_address:
            image, image_file, icon_url = self.fetch_facebook_image()
        else:
            image, image_file, icon_url = self.fetch_image_from_page_data()
        if not image:
            image, image_file, icon_url = self.fetch_image_from_path(force=self.force)
        
        if not image:
            self.feed_icon.not_found = True
            self.feed_icon.save()
            self.feed.favicon_not_found = True
            self.feed.save()
            return False
        
        image = self.normalize_image(image)
        try:
            color = self.determine_dominant_color_in_image(image)
        except (IndexError, ValueError, MemoryError):
            logging.debug("   ---> [%-30s] ~SN~FRFailed to measure icon" % self.feed.log_title[:30])
            return
        try:
            image_str = self.string_from_image(image)
        except TypeError:
            return

        if len(image_str) > 500000:
            image = None
        if (image and
            (self.force or
                self.feed_icon.data != image_str or
                self.feed_icon.icon_url != icon_url or
                self.feed_icon.not_found or
                (settings.BACKED_BY_AWS.get('icons_on_s3') and not self.feed.s3_icon))):
            logging.debug("   ---> [%-30s] ~SN~FBIcon difference:~FY color:%s (%s/%s) data:%s url:%s notfound:%s no-s3:%s" % (
                self.feed.log_title[:30],
                self.feed_icon.color != color, self.feed_icon.color, color,
                self.feed_icon.data != image_str,
                self.feed_icon.icon_url != icon_url,
                self.feed_icon.not_found,
                settings.BACKED_BY_AWS.get('icons_on_s3') and not self.feed.s3_icon))
            self.feed_icon.data = image_str
            self.feed_icon.icon_url = icon_url
            self.feed_icon.color = color
            self.feed_icon.not_found = False
            self.feed_icon.save()
            if settings.BACKED_BY_AWS.get('icons_on_s3'):
                self.save_to_s3(image_str)
        if self.feed.favicon_color != color:
            self.feed.favicon_color = color
            self.feed.favicon_not_found = False
            self.feed.save(update_fields=['favicon_color', 'favicon_not_found'])
            
        return not self.feed.favicon_not_found

    def save_to_s3(self, image_str):
        expires = datetime.datetime.now() + datetime.timedelta(days=60)
        expires = expires.strftime("%a, %d %b %Y %H:%M:%S GMT")
        base64.b64decode(image_str)
        settings.S3_CONN.Object(settings.S3_ICONS_BUCKET_NAME, 
                                self.feed.s3_icons_key).put(Body=base64.b64decode(image_str), 
                                                            ContentType='image/png',
                                                            Expires=expires,
                                                            ACL='public-read'
                                                            )

        self.feed.s3_icon = True
        self.feed.save()

    def load_icon(self, image_file, index=None):
        '''
        DEPRECATED

        Load Windows ICO image.

        See http://en.wikipedia.org/w/index.php?oldid=264332061 for file format
        description.

        Cribbed and modified from http://djangosnippets.org/snippets/1287/
        '''
        try:
            image_file.seek(0)
            header = struct.unpack('<3H', image_file.read(6))
        except Exception:
            return

        # Check magic
        if header[:2] != (0, 1):
            return

        # Collect icon directories
        directories = []
        for i in range(header[2]):
            directory = list(struct.unpack('<4B2H2I', image_file.read(16)))
            for j in range(3):
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
            try:
                image = BmpImagePlugin.DibImageFile(image_file)
            except IOError:
                return
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
                mask = Image.frombytes('1', image.size, string, 'raw',
                                       ('1;I', stride, -1))

                image = image.convert('RGBA')
                image.putalpha(mask)

        return image

    def fetch_image_from_page_data(self):
        image = None
        image_file = None
        content = None
        if self.page_data:
            content = self.page_data
        elif settings.BACKED_BY_AWS.get('pages_on_node'):
            domain = Site.objects.get_current().domain
            url = "https://%s/original_page/%s" % (
                domain,
                self.feed.pk,
            )
            try:
                page_response = requests.get(url)
                if page_response.status_code == 200:
                    content = page_response.content
            except requests.ConnectionError:
                pass
        elif settings.BACKED_BY_AWS.get('pages_on_s3') and self.feed.s3_page:
            key = settings.S3_CONN.Bucket(settings.S3_PAGES_BUCKET_NAME).Object(key=self.feed.s3_pages_key)
            compressed_content = key.get()["Body"].read()
            stream = BytesIO(compressed_content)
            gz = gzip.GzipFile(fileobj=stream)
            try:
                content = gz.read()
            except IOError:
                pass
        else:
            content = MFeedPage.get_data(feed_id=self.feed.pk)
        url = self._url_from_html(content)
        if not url:
            try:
                content = requests.get(self.cleaned_feed_link, timeout=10).content
                url = self._url_from_html(content)
            except (AttributeError, SocketError, requests.ConnectionError,
                    requests.models.MissingSchema, requests.sessions.InvalidSchema,
                    requests.sessions.TooManyRedirects,
                    requests.models.InvalidURL,
                    requests.models.ChunkedEncodingError,
                    requests.models.ContentDecodingError,
                    http.client.IncompleteRead,
                    requests.adapters.ReadTimeout,
                    LocationParseError, OpenSSLError, PyAsn1Error,
                    ValueError) as e:
                logging.debug(" ---> ~SN~FRFailed~FY to fetch ~FGfeed icon~FY: %s" % e)
        if url:
            image, image_file = self.get_image_from_url(url)
        return image, image_file, url
    
    @property
    def cleaned_feed_link(self):
        if self.feed.feed_link.startswith('http'):
            return self.feed.feed_link
        return 'http://' + self.feed.feed_link
    
    def fetch_image_from_path(self, path='favicon.ico', force=False):
        image = None
        url = None

        if not force:
            url = self.feed_icon.icon_url
        if not url and self.feed.feed_link and len(self.feed.feed_link) > 6:
            try:
                url = urllib.parse.urljoin(self.feed.feed_link, 'favicon.ico')
            except ValueError:
                url = None
        if not url:
            return None, None, None

        image, image_file = self.get_image_from_url(url)
        if not image:
            url = urllib.parse.urljoin(self.feed.feed_link, '/favicon.ico')
            image, image_file = self.get_image_from_url(url)
        # print 'Found: %s - %s' % (url, image)
        return image, image_file, url
    
    def fetch_facebook_image(self):
        facebook_fetcher = FacebookFetcher(self.feed)
        url = facebook_fetcher.favicon_url()
        image, image_file = self.get_image_from_url(url)
        if not image:
            url = urllib.parse.urljoin(self.feed.feed_link, '/favicon.ico')
            image, image_file = self.get_image_from_url(url)
        # print 'Found: %s - %s' % (url, image)
        return image, image_file, url
        
    def get_image_from_url(self, url):
        # print 'Requesting: %s' % url
        if not url:
            return None, None

        @timelimit(30)
        def _1(url):
            headers = {
                'User-Agent': 'NewsBlur Favicon Fetcher - %s subscriber%s - %s %s' %
                              (
                                  self.feed.num_subscribers,
                                  's' if self.feed.num_subscribers != 1 else '',
                                  self.feed.permalink,
                                  self.feed.fake_user_agent,
                              ),
                'Connection': 'close',
                'Accept': 'image/png,image/x-icon,image/*;q=0.9,*/*;q=0.8'
            }
            try:
                request = urllib.request.Request(url, headers=headers)
                icon = urllib.request.urlopen(request).read()
            except Exception:
                return None
            return icon
        try:
            icon = _1(url)
        except TimeoutError:
            return None, None

        try:
            icon_file = BytesIO(icon)
            image = Image.open(icon_file)
        except (IOError, ValueError):
            return None, None

        return image, icon_file

    def _url_from_html(self, content):
        url = None
        if not content:
            return url
        try:
            if isinstance(content, str):
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
                url = urllib.parse.urljoin(self.feed.feed_link, icon_path[0])
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
        if image.mode == '1':
            image.convert('L')
        ar = numpy.array(image)
        # ar = scipy.misc.fromimage(image)
        shape = ar.shape

        # Reshape array of values to merge color bands. [[R], [G], [B], [A]] => [R, G, B, A]
        if len(shape) > 2:
            ar = ar.reshape(scipy.product(shape[:2]), shape[2])
            
        # Get NUM_CLUSTERS worth of centroids.
        ar = ar.astype(numpy.float)
        codes, _ = scipy.cluster.vq.kmeans(ar, NUM_CLUSTERS)

        # Pare centroids, removing blacks and whites and shades of really dark and really light.
        original_codes = codes
        for low, hi in [(60, 200), (35, 230), (10, 250)]:
            codes = scipy.array([code for code in codes
                                 if not ((code[0] < low and code[1] < low and code[2] < low) or
                                         (code[0] > hi and code[1] > hi and code[2] > hi))])
            if not len(codes):
                codes = original_codes
            else:
                break

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
        peak = codes.astype(int)[index_max]
        color = "{:02x}{:02x}{:02x}".format(peak[0], peak[1], peak[2])
        color = self.feed.adjust_color(color[:6], 21)

        return color

    def string_from_image(self, image):
        output = BytesIO()
        image.save(output, 'png', quality=95)
        contents = output.getvalue()
        output.close()
        return base64.b64encode(contents).decode()
