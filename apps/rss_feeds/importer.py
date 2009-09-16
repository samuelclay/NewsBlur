import urllib2
import logging
import re
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
        base_code = u'<base href="%s" />' % (self.feed.feed_link,)
        try:
            html = re.sub(r'<head(.*?\>)', r'<head\1 '+base_code, response)
        except:
            response = response.decode('latin1').encode('utf-8')
            html = re.sub(r'<head(.*?\>)', r'<head\1 '+base_code, response)
        
        return html
        
    def save_page(self, html):
        self.feed.page_data = html
        # self.lock.acquire()
        # try:
        self.feed.save()
        # finally:
        #     self.lock.release()
