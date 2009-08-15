import urllib2
import logging
import re

class PageImporter(object):
    
    def __init__(self, url, feed):
        self.url = url
        self.feed = feed
    
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
        head = response.find('<head>') + 6
        base_code = u'<base href="%s" />' % (self.feed.feed_link,)
        try:
            html = u''.join([response[:head], base_code, response[head:]])
        except:
            response = response.decode('latin1').encode('utf-8')
            html = u''.join([response[:head], base_code, response[head:]])
        
        return html
        
    def save_page(self, html):
        self.feed.page_data = html
        self.feed.save()