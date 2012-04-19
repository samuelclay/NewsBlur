import requests
import re
import urlparse
import traceback
import feedparser
import time
import urllib2
import httplib
from django.conf import settings
from utils import log as logging
from apps.rss_feeds.models import MFeedPage
from utils.feed_functions import timelimit, mail_feed_error_to_admin

BROKEN_PAGES = [
    'tag:', 
    'info:', 
    'uuid:', 
    'urn:', 
    '[]',
]

class PageImporter(object):
    
    def __init__(self, feed):
        self.feed = feed
        
    @property
    def headers(self):
        s = requests.session()
        s.config['keep_alive'] = False
        return {
            'User-Agent': 'NewsBlur Page Fetcher (%s subscriber%s) - %s '
                          '(Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_1) '
                          'AppleWebKit/534.48.3 (KHTML, like Gecko) Version/5.1 '
                          'Safari/534.48.3)' % (
                self.feed.num_subscribers,
                's' if self.feed.num_subscribers != 1 else '',
                settings.NEWSBLUR_URL
            ),
            'Connection': 'close',
        }
    
    @timelimit(15)
    def fetch_page(self, urllib_fallback=False, requests_exception=None):
        feed_link = self.feed.feed_link
        if not feed_link:
            self.save_no_page()
            return
        
        try:
            if feed_link.startswith('www'):
                self.feed.feed_link = 'http://' + feed_link
            if feed_link.startswith('http'):
                if urllib_fallback:
                    request = urllib2.Request(feed_link, headers=self.headers)
                    response = urllib2.urlopen(request)
                    time.sleep(0.01) # Grrr, GIL.
                    data = response.read()
                else:
                    response = requests.get(feed_link, headers=self.headers)
                    try:
                        data = response.text
                    except LookupError:
                        data = response.content
            elif any(feed_link.startswith(s) for s in BROKEN_PAGES):
                self.save_no_page()
                return
            else:
                try:
                    data = open(feed_link, 'r').read()
                except IOError:
                    self.feed.feed_link = 'http://' + feed_link
                    self.fetch_page(urllib_fallback=True)
                    return
            if data:
                html = self.rewrite_page(data)
                self.save_page(html)
            else:
                self.save_no_page()
                return
        except (ValueError, urllib2.URLError, httplib.BadStatusLine, httplib.InvalidURL,
                requests.exceptions.ConnectionError), e:
            self.feed.save_page_history(401, "Bad URL", e)
            fp = feedparser.parse(self.feed.feed_address)
            feed_link = fp.feed.get('link', "")
            self.feed.save()
        except (urllib2.HTTPError), e:
            self.feed.save_page_history(e.code, e.msg, e.fp.read())
        except (httplib.IncompleteRead), e:
            self.feed.save_page_history(500, "IncompleteRead", e)
        except (requests.exceptions.RequestException, 
                requests.packages.urllib3.exceptions.HTTPError), e:
            logging.debug('   ***> [%-30s] Page fetch failed using requests: %s' % (self.feed, e))
            mail_feed_error_to_admin(self.feed, e, local_vars=locals())
            return self.fetch_page(urllib_fallback=True, requests_exception=e)
        except Exception, e:
            logging.debug('[%d] ! -------------------------' % (self.feed.id,))
            tb = traceback.format_exc()
            logging.debug(tb)
            logging.debug('[%d] ! -------------------------' % (self.feed.id,))
            self.feed.save_page_history(500, "Error", tb)
            mail_feed_error_to_admin(self.feed, e, local_vars=locals())
            if not urllib_fallback:
                self.fetch_page(urllib_fallback=True)
        else:
            self.feed.save_page_history(200, "OK")

    def save_no_page(self):
        self.feed.has_page = False
        self.feed.save()
        self.feed.save_page_history(404, "Feed has no original page.")

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
