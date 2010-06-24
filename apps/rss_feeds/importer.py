import urllib2
import logging
import re
import urlparse
import multiprocessing

class PageImporter(object):
    
    def __init__(self, url, feed):
        self.url = url
        self.feed = feed
        self.lock = multiprocessing.Lock()
    
    def fetch_page(self):
        request = urllib2.Request(self.url)
        
        try:
            response = urllib2.urlopen(request)
        except urllib2.HTTPError, e:
            logging.error('The server couldn\'t fulfill the request. Error: %s' % e.code)
        except urllib2.URLError, e:
            logging.error('Failed to reach server. Reason: %s' % e.reason)
        else:
            data = response.read()
            html = data
            html = self.rewrite_page(html)
            self.save_page(html)
    
    def rewrite_page(self, response):
        BASE_RE = re.compile(r'<head(.*?\>)', re.I)
        base_code = u'<base href="%s" />' % (self.feed.feed_link,)
        try:
            html = BASE_RE.sub(r'<head\1 '+base_code, response)
        except:
            response = response.decode('latin1').encode('utf-8')
            html = BASE_RE.sub(r'<head\1 '+base_code, response)
        
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
        self.feed.page_data = html
        self.lock.acquire()
        try:
            self.feed.save()
        finally:
            self.lock.release()
