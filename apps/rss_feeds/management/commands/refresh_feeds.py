from django.core.management.base import BaseCommand
from django.core.handlers.wsgi import WSGIHandler
from apps.rss_feeds.models import Feed, Story
from django.core.cache import cache
from apps.reader.models import UserSubscription, UserSubscriptionFolders, UserStory
from optparse import OptionParser, make_option
from apps.rss_feeds.importer import PageImporter
from utils import feedparser, threadpool
import os
import sys
import time
import logging
import errno
import datetime
import threading
import traceback
import socket

threadpool = None

# Refresh feed code adapted from Feedjack.
# http://feedjack.googlecode.com

VERSION = '0.2'
URL = 'http://www.newsblur.com/'
USER_AGENT = 'NewsBlur %s - %s' % (VERSION, URL)
SLOWFEED_WARNING = 10
ENTRY_NEW, ENTRY_UPDATED, ENTRY_SAME, ENTRY_ERR = range(4)
FEED_OK, FEED_SAME, FEED_ERRPARSE, FEED_ERRHTTP, FEED_ERREXC = range(5)

def prints(tstr):
    """ lovely unicode
    """
    sys.stdout.write('%s\n' % (tstr.encode(sys.getdefaultencoding(),
                         'replace')))
    sys.stdout.flush()
    
def mtime(ttime):
    """ datetime auxiliar function.
    """
    return datetime.datetime.fromtimestamp(time.mktime(ttime))

class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        make_option("-f", "--feed", default=None),
        make_option("-d", "--daemon", dest="daemonize", action="store_true"),
        make_option('-t', '--timeout', type='int', default=10,
            help='Wait timeout in seconds when connecting to feeds.'),
        make_option('-V', '--verbose', action='store_true',
            dest='verbose', default=False, help='Verbose output.'),
        make_option('-w', '--workerthreads', type='int', default=4,
            help='Worker threads that will fetch feeds in parallel.'),
    )

    def handle(self, *args, **options):
        if options['daemonize']:
            daemonize()
        
        # settting socket timeout (default= 10 seconds)
        socket.setdefaulttimeout(options['timeout'])
        
        disp = Dispatcher(options, options['workerthreads'])        
        
        feeds = Feed.objects.all()
        for feed in feeds:
            disp.add_job(feed)
        
        disp.poll()
        


class FetchFeed:
    def __init__(self, feed, options):
        self.feed = feed
        self.options = options
        self.fpf = None

    def fetch(self):
        """ Downloads and parses a feed.
        """

        logging.debug(u'[%d] Fetching %s' % (self.feed.id,
                                             self.feed.feed_title))

        # we check the etag and the modified time to save bandwith and
        # avoid bans
        try:
            self.fpf = feedparser.parse(self.feed.feed_address,
                                        agent=USER_AGENT,
                                        etag=self.feed.etag)
        except:
            logging.error('! ERROR: feed cannot be parsed')
            return FEED_ERRPARSE
        
        return self.fpf

class FetchPage:
    def __init__(self, feed, options):
        self.feed = feed
        self.options = options
        
    def fetch(self):
        logging.debug(u'[%d] Fetching page from %s' % (self.feed.id,
                                                       self.feed.feed_title))
                                                       
        page_importer = PageImporter(self.feed.feed_link, self.feed)
        self.feed.page = page_importer.fetch_page()
        
        self.feed.save()
        
class ProcessFeed:
    def __init__(self, feed, fpf, options):
        self.feed = feed
        self.options = options
        self.fpf = fpf

    def process(self):
        """ Downloads and parses a feed.
        """

        ret_values = {
            ENTRY_NEW:0,
            ENTRY_UPDATED:0,
            ENTRY_SAME:0,
            ENTRY_ERR:0}

        logging.debug(u'[%d] Processing %s' % (self.feed.id,
                                             self.feed.feed_title))
        
        if hasattr(self.fpf, 'status'):
            if self.options['verbose']:
                logging.debug(u'[%d] HTTP status %d: %s' % (self.feed.id,
                                                     self.fpf.status,
                                                     self.feed.feed_address))
            if self.fpf.status == 304:
                # this means the feed has not changed
                if self.options['verbose']:
                    logging.debug('[%d] Feed has not changed since ' \
                           'last check: %s' % (self.feed.id,
                                               self.feed.feed_address))
                return FEED_SAME, ret_values

            if self.fpf.status >= 400:
                # http error, ignore
                logging.error('[%d] !HTTP_ERROR! %d: %s' % (self.feed.id,
                                                     self.fpf.status,
                                                     self.feed.feed_address))
                return FEED_ERRHTTP, ret_values

        if hasattr(self.fpf, 'bozo') and self.fpf.bozo:
            logging.debug('[%d] !BOZO! Feed is not well formed: %s' % (
                self.feed.id, self.feed.feed_address))

        # the feed has changed (or it is the first time we parse it)
        # saving the etag and last_modified fields
        self.feed.etag = self.fpf.get('etag', '')
        # some times this is None (it never should) *sigh*
        if self.feed.etag is None:
            self.feed.etag = ''

        try:
            self.feed.last_modified = mtime(self.fpf.modified)
        except:
            pass
        
        self.feed.feed_title = self.fpf.feed.get('title', '')[0:254]
        self.feed.feed_tagline = self.fpf.feed.get('tagline', '')
        self.feed.feed_link = self.fpf.feed.get('link', '')
        self.feed.last_update = datetime.datetime.now()

        if False and self.options['verbose']:
            logging.debug(u'[%d] Feed info for: %s\n' \
                   u'  title %s\n' \
                   u'  tagline %s\n' \
                   u'  link %s\n' \
                   u'  last_checked %s' % (
                self.feed.id, self.feed.feed_address, self.feed.feed_title,
                self.feed.feed_tagline, self.feed.feed_link, self.feed.last_update))


        guids = []
        for entry in self.fpf.entries:
            if entry.get('id', ''):
                guids.append(entry.get('id', ''))
            elif entry.title:
                guids.append(entry.title)
            elif entry.link:
                guids.append(entry.link)
                
        
        self.feed.save()

        # Compare new stories to existing stories, adding and updating
        try:
            num_entries = len(self.fpf.entries)
            existing_stories = Story.objects.filter(
                story_feed=self.feed
            ).order_by('-story_date').values()[:num_entries]
        
            ret_values = self.feed.add_update_stories(self.fpf.entries, existing_stories)
        except:
            (etype, eobj, etb) = sys.exc_info()
            print '[%d] ! -------------------------' % (self.feed.id,)
            print traceback.format_exception(etype, eobj, etb)
            traceback.print_exception(etype, eobj, etb)
            print '[%d] ! -------------------------' % (self.feed.id,)
        
        return FEED_OK, ret_values


class Dispatcher:
    def __init__(self, options, num_threads):
        self.options = options
        self.entry_stats = {
            ENTRY_NEW:0,
            ENTRY_UPDATED:0,
            ENTRY_SAME:0,
            ENTRY_ERR:0}
        self.feed_stats = {
            FEED_OK:0,
            FEED_SAME:0,
            FEED_ERRPARSE:0,
            FEED_ERRHTTP:0,
            FEED_ERREXC:0}
        self.entry_trans = {
            ENTRY_NEW:'new',
            ENTRY_UPDATED:'updated',
            ENTRY_SAME:'same',
            ENTRY_ERR:'error'}
        self.feed_trans = {
            FEED_OK:'ok',
            FEED_SAME:'unchanged',
            FEED_ERRPARSE:'cant_parse',
            FEED_ERRHTTP:'http_error',
            FEED_ERREXC:'exception'}
        self.entry_keys = sorted(self.entry_trans.keys())
        self.feed_keys = sorted(self.feed_trans.keys())
        if threadpool:
            self.tpool = threadpool.ThreadPool(num_threads)
        else:
            self.tpool = None
        self.time_start = datetime.datetime.now()


    def process_feed_wrapper(self, feed):
        """ wrapper for ProcessFeed
        """
        start_time = datetime.datetime.now()
        try:
            ffeed = FetchFeed(feed, self.options)
            fetched_feed = ffeed.fetch()
            
            pfeed = ProcessFeed(feed, fetched_feed, self.options)
            ret_feed, ret_entries = pfeed.process()
            
            fpage = FetchPage(feed, self.options)
            fpage.fetch()
            
            del ffeed
            del pfeed
            del fpage
        except:
            (etype, eobj, etb) = sys.exc_info()
            print '[%d] ! -------------------------' % (feed.id,)
            print traceback.format_exception(etype, eobj, etb)
            traceback.print_exception(etype, eobj, etb)
            print '[%d] ! -------------------------' % (feed.id,)
            ret_feed = FEED_ERREXC
            ret_entries = {}

        delta = datetime.datetime.now() - start_time
        if delta.seconds > SLOWFEED_WARNING:
            comment = u' (SLOW FEED!)'
        else:
            comment = u''
        logging.debug(u'[%d] Processed %s in %s [%s] [%s]%s' % (
            feed.id, feed.feed_title, unicode(delta),
            self.feed_trans[ret_feed],
            u' '.join(u'%s=%d' % (self.entry_trans[key],
                      ret_entries[key]) for key in self.entry_keys),
            comment))

        self.feed_stats[ret_feed] += 1
        for key, val in ret_entries.items():
            self.entry_stats[key] += val

        return ret_feed, ret_entries


    def add_job(self, feed):
        """ adds a feed processing job to the pool
        """
        if self.tpool:
            req = threadpool.WorkRequest(self.process_feed_wrapper,
                (feed,))
            self.tpool.putRequest(req)
        else:
            # no threadpool module, just run the job
            self.process_feed_wrapper(feed)
            
    def poll(self):
        """ polls the active threads
        """
        if not self.tpool:
            # no thread pool, nothing to poll
            return
        while True:
            try:
                time.sleep(0.2)
                self.tpool.poll()
            except KeyboardInterrupt:
                logging.debug('! Cancelled by user')
                break
            except threadpool.NoResultsPending:
                logging.info(u'* DONE in %s\n* Feeds: %s\n* Entries: %s' % (
                    unicode(datetime.datetime.now() - self.time_start),
                    u' '.join(u'%s=%d' % (self.feed_trans[key],
                              self.feed_stats[key])
                              for key in self.feed_keys),
                    u' '.join(u'%s=%d' % (self.entry_trans[key],
                              self.entry_stats[key])
                              for key in self.entry_keys)
                    ))
                break
            except Exception:
                logging.error(u'I DONT KNOW')
                
class FeedFetcher(threading.Thread):

    def __init__(self, feed):
        threading.Thread.__init__(self)
        self.feed = feed
        
    def run(self):
        print self.feed
        self.feed.update(True)
        usersubs = UserSubscription.objects.filter(
            feed=self.feed.id
        )
        for us in usersubs:
            us.count_unread()
            cache.delete('usersub:%s' % us.user_id)
        
def daemonize():
    """
    Detach from the terminal and continue as a daemon.
    """
    # swiped from twisted/scripts/twistd.py
    # See http://www.erlenstar.demon.co.uk/unix/faq_toc.html#TOC16
    if os.fork():   # launch child and...
        os._exit(0) # kill off parent
    os.setsid()
    if os.fork():   # launch child and...
        os._exit(0) # kill off parent again.
    os.umask(077)
    null = os.open("/dev/null", os.O_RDWR)
    for i in range(3):
        try:
            os.dup2(null, i)
        except OSError, e:
            if e.errno != errno.EBADF:
                raise
    os.close(null)