import urllib2, httplib
import re
import urlparse
import traceback
import feedparser
import time
from utils import log as logging
from apps.rss_feeds.models import MFeedPage
from utils.feed_functions import timelimit, mail_feed_error_to_admin

HEADERS = {
    'User-Agent': 'NewsBlur Page Fetcher - http://www.newsblur.com',
    'Connection': 'close',
}

class PageImporter(object):
    
    def __init__(self, url, feed):
        self.url = url
        self.feed = feed
    
    @timelimit(15)
    def fetch_page(self):
        if not self.url:
            return
        
        try:
            request = urllib2.Request(self.url, headers=HEADERS)
            response = urllib2.urlopen(request)
            time.sleep(0.01) # Grrr, GIL.
            data = response.read()
            html = self.rewrite_page(data)
            self.save_page(html)
        except (ValueError, urllib2.URLError, httplib.BadStatusLine, httplib.InvalidURL), e:
            self.feed.save_page_history(401, "Bad URL", e)
            fp = feedparser.parse(self.feed.feed_address)
            self.feed.feed_link = fp.feed.get('link', "")
            self.feed.save()
        except (urllib2.HTTPError), e:
            self.feed.save_page_history(e.code, e.msg, e.fp.read())
            return
        except (httplib.IncompleteRead), e:
            self.feed.save_page_history(500, "IncompleteRead", e)
            return
        except Exception, e:
            logging.debug('[%d] ! -------------------------' % (self.feed.id,))
            tb = traceback.format_exc()
            logging.debug(tb)
            logging.debug('[%d] ! -------------------------' % (self.feed.id,))
            self.feed.save_page_history(500, "Error", tb)
            mail_feed_error_to_admin(self.feed, e)
            return
        
        self.feed.save_page_history(200, "OK")
    
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
        if html and len(html) > 100:
            feed_page, _ = MFeedPage.objects.get_or_create(feed_id=self.feed.pk)
            feed_page.page_data = html
            feed_page.save()
