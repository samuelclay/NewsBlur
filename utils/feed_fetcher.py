from apps.rss_feeds.models import Story
from django.core.cache import cache
from apps.reader.models import UserSubscription, UserSubscriptionFolders, UserStory
from apps.rss_feeds.importer import PageImporter
from utils import feedparser, threadpool
from django.db import transaction
from utils.dateutil.parser import parse as dateutil_parse
from utils.story_functions import pre_process_story
import sys
import time
import logging
import datetime
# import threading
import traceback
import multiprocessing
import Queue

threadpool = None

# Refresh feed code adapted from Feedjack.
# http://feedjack.googlecode.com

VERSION = '0.8'
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
    
class FetchFeed:
    def __init__(self, feed, options):
        self.feed = feed
        self.options = options
        self.fpf = None

    def fetch(self):
        """ Downloads and parses a feed.
        """

        current_process = multiprocessing.current_process()
        log_msg = u'[%d-%s] Fetching %s' % (self.feed.id, current_process.name,
                                             self.feed.feed_title)
        logging.info(log_msg)
        print(log_msg)
        
        # we check the etag and the modified time to save bandwith and avoid bans
        try:
            self.fpf = feedparser.parse(self.feed.feed_address,
                                        agent=USER_AGENT,
                                        etag=self.feed.etag)
        except Exception, e:
            log_msg = '! ERROR: feed cannot be parsed: %s' % e
            logging.error(log_msg)
            print(log_msg)
            
            return FEED_ERRPARSE
        
        return self.fpf

class FetchPage:
    def __init__(self, feed, options):
        self.feed = feed
        self.options = options

    @transaction.autocommit
    def fetch(self):
        logging.debug(u'[%d] Fetching page from %s' % (self.feed.id,
                                                       self.feed.feed_title))
        if self.feed.feed_link:
            page_importer = PageImporter(self.feed.feed_link, self.feed)
            self.feed.page = page_importer.fetch_page()
        
            self.feed.save()
        
class ProcessFeed:
    def __init__(self, feed, fpf, options):
        self.feed = feed
        self.options = options
        self.fpf = fpf
        self.lock = multiprocessing.Lock()

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
                
        self.lock.acquire()
        try:
            self.feed.save()
        finally:
            self.lock.release()


        # Compare new stories to existing stories, adding and updating
        num_entries = len(self.fpf.entries)
        start_date = datetime.datetime.now()
        end_date = datetime.datetime.now()
        for entry in self.fpf.entries:
            story = pre_process_story(entry)
            if story.get('published') < start_date or not start_date:
                start_date = story.get('published')
            if story.get('published') > end_date or not end_date:
                end_date = story.get('published')
        existing_stories = Story.objects.filter(
            story_feed=self.feed,
            story_date__gte=start_date,
            story_date__lte=end_date,
        ).order_by('-story_date')[:100].values()
        ret_values = self.feed.add_update_stories(self.fpf.entries, existing_stories)
        
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
        self.num_threads = num_threads
        if threadpool:
            self.tpool = threadpool.ThreadPool(num_threads)
        else:
            self.tpool = None
        self.time_start = datetime.datetime.now()
        self.workers = []


    def process_feed_wrapper(self, feed_queue):
        """ wrapper for ProcessFeed
        """
        # Close the DB so the connection can be re-opened on a per-process basis
        from django.db import connection
        connection.close()
        
        current_process = multiprocessing.current_process()
        # print feed_queue
        for feed in feed_queue:
            # print "Process Feed: [%s] %s" % (current_process.name, feed)
                
            start_time = datetime.datetime.now()
        
            ### Uncomment to test feed fetcher
            # from random import randint
            # if randint(0,10) < 10:
            #     continue
        
            try:
                ffeed = FetchFeed(feed, self.options)
                fetched_feed = ffeed.fetch()
                
                pfeed = ProcessFeed(feed, fetched_feed, self.options)
                ret_feed, ret_entries = pfeed.process()
                
                fpage = FetchPage(feed, self.options)
                fpage.fetch()
                
                if ENTRY_NEW in ret_entries and ret_entries[ENTRY_NEW]:
                    user_subs = UserSubscription.objects.filter(feed=feed)
                    for sub in user_subs:
                        logging.info('Deleteing user sub cache: %s' % sub.user_id)
                        cache.delete('usersub:%s' % sub.user_id)
                        sub.calculate_feed_scores()
            except:
                (etype, eobj, etb) = sys.exc_info()
                print '[%d] ! -------------------------' % (feed.id,)
                # print traceback.format_exception(etype, eobj, etb)
                traceback.print_exception(etype, eobj, etb)
                print '[%d] ! -------------------------' % (feed.id,)
                ret_feed = FEED_ERREXC
                ret_entries = {}
            finally:
                del ffeed
                del pfeed
                del fpage
                if ENTRY_NEW in ret_entries and ret_entries[ENTRY_NEW]:
                    del user_subs

            delta = datetime.datetime.now() - start_time
            if delta.seconds > SLOWFEED_WARNING:
                comment = u' (SLOW FEED!)'
            else:
                comment = u''
            done = (u'[%d-%s] Processed %s in %s [%s] [%s]%s' % (
                feed.id, current_process.name, feed.feed_title, unicode(delta),
                self.feed_trans[ret_feed],
                u' '.join(u'%s=%d' % (self.entry_trans[key],
                          ret_entries[key]) for key in self.entry_keys),
                comment))
            logging.debug(done)
            print(done)
            self.feed_stats[ret_feed] += 1
            for key, val in ret_entries.items():
                self.entry_stats[key] += val
        print "DONE WITH PROCESS: %s" % current_process.name
        sys.exit()

    def add_jobs(self, feeds_queue):
        """ adds a feed processing job to the pool
        """
        if self.tpool:
            req = threadpool.WorkRequest(self.process_feed_wrapper)
            self.tpool.putRequest(req)
        else:
            # no threadpool module, just run the job
            self.feeds_queue = feeds_queue
            # self.process_feed_wrapper(feed)
            
    def run_jobs(self):
        for i in range(self.num_threads):
            feed_queue = self.feeds_queue[i]
            self.workers.append(multiprocessing.Process(target=self.process_feed_wrapper, args=(feed_queue,)))
            # worker.setName("Thread #%s" % (i+1))
            # worker.setDaemon(True)
        for i in range(self.num_threads):
            self.workers[i].start()
            
    def poll(self):
        """ polls the active threads
        """
        if not self.tpool:
            for i in range(self.num_threads):
                self.workers[i].join()
            done = (u'* DONE in %s\n* Feeds: %s\n* Entries: %s' % (
                    unicode(datetime.datetime.now() - self.time_start),
                    u' '.join(u'%s=%d' % (self.feed_trans[key],
                              self.feed_stats[key])
                              for key in self.feed_keys),
                    u' '.join(u'%s=%d' % (self.entry_trans[key],
                              self.entry_stats[key])
                              for key in self.entry_keys)
                    ))
            print done
            logging.info(done)
            return
        while True:
            try:
                time.sleep(0.2)
                self.tpool.poll()
            except KeyboardInterrupt:
                logging.debug('! Cancelled by user')
                break
            except threadpool.NoResultsPending:
                done = (u'* DONE in %s\n* Feeds: %s\n* Entries: %s' % (
                    unicode(datetime.datetime.now() - self.time_start),
                    u' '.join(u'%s=%d' % (self.feed_trans[key],
                              self.feed_stats[key])
                              for key in self.feed_keys),
                    u' '.join(u'%s=%d' % (self.entry_trans[key],
                              self.entry_stats[key])
                              for key in self.entry_keys)
                    ))
                print done
                logging.info(done)
                break
            except Exception, e:
                print(u'I DONT KNOW: %s - %s' % (e, locals()))
            except:
                print(u'I REALLY DONT KNOW: %s - %s' % (e, locals()))
                