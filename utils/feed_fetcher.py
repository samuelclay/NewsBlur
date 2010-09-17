from apps.rss_feeds.models import FeedUpdateHistory
# from apps.rss_feeds.models import FeedXML
from django.core.cache import cache
from django.conf import settings
from apps.reader.models import UserSubscription
from apps.rss_feeds.importer import PageImporter
from utils import feedparser
from django.db import IntegrityError
from utils.story_functions import pre_process_story
from utils import log as logging
import sys
import time
import datetime
import traceback
import multiprocessing
import urllib2
import xml.sax
import socket
import mongoengine

# Refresh feed code adapted from Feedjack.
# http://feedjack.googlecode.com

VERSION = '0.9'
URL = 'http://www.newsblur.com/'
USER_AGENT = 'NewsBlur Fetcher %s - %s' % (VERSION, URL)
SLOWFEED_WARNING = 10
ENTRY_NEW, ENTRY_UPDATED, ENTRY_SAME, ENTRY_ERR = range(4)
FEED_OK, FEED_SAME, FEED_ERRPARSE, FEED_ERRHTTP, FEED_ERREXC = range(5)

def mtime(ttime):
    """ datetime auxiliar function.
    """
    return datetime.datetime.fromtimestamp(time.mktime(ttime))
    
import threading
class TimeoutError(Exception): pass
def timelimit(timeout):
    """borrowed from web.py"""
    def _1(function):
        def _2(*args, **kw):
            class Dispatch(threading.Thread):
                def __init__(self):
                    threading.Thread.__init__(self)
                    self.result = None
                    self.error = None
                    
                    self.setDaemon(True)
                    self.start()

                def run(self):
                    try:
                        self.result = function(*args, **kw)
                    except:
                        self.error = sys.exc_info()

            c = Dispatch()
            c.join(timeout)
            if c.isAlive():
                raise TimeoutError, 'took too long'
            if c.error:
                raise c.error[0], c.error[1]
            return c.result
        return _2
    return _1
    
class FetchFeed:
    def __init__(self, feed, options):
        self.feed = feed
        self.options = options
        self.fpf = None
    
    @timelimit(20)
    def fetch(self):
        """ Downloads and parses a feed.
        """
        socket.setdefaulttimeout(30)
        identity = self.get_identity()
        log_msg = u'%2s ---> [%-30s] Fetching feed (%d)' % (identity,
                                                 unicode(self.feed)[:30],
                                                 self.feed.id)
        logging.debug(log_msg)
                                                 
        # Check if feed still needs to be updated
        # feed = Feed.objects.get(pk=self.feed.pk)
        # if feed.next_scheduled_update > datetime.datetime.now() and not self.options.get('force'):
        #     log_msg = u'        ---> Already fetched %s (%d)' % (self.feed.feed_title,
        #                                                          self.feed.id)
        #     logging.debug(log_msg)
        #     feed.save_feed_history(303, "Already fetched")
        #     return FEED_SAME, None
        # else:
        self.feed.set_next_scheduled_update()
            
        etag=self.feed.etag
        modified = self.feed.last_modified.utctimetuple()[:7] if self.feed.last_modified else None
        
        if self.options.get('force'):
            modified = None
            etag = None
            
        self.fpf = feedparser.parse(self.feed.feed_address,
                                    agent=USER_AGENT,
                                    etag=etag,
                                    modified=modified)
        
        return FEED_OK, self.fpf
        
    def get_identity(self):
        identity = "X"

        current_process = multiprocessing.current_process()
        if current_process._identity:
            identity = current_process._identity[0]

        return identity
        
class ProcessFeed:
    def __init__(self, feed, fpf, db, options):
        self.feed = feed
        self.options = options
        self.fpf = fpf
        self.lock = multiprocessing.Lock()
        self.db = db
        self.entry_trans = {
            ENTRY_NEW:'new',
            ENTRY_UPDATED:'updated',
            ENTRY_SAME:'same',
            ENTRY_ERR:'error'}
        self.entry_keys = sorted(self.entry_trans.keys())

    def process(self):
        """ Downloads and parses a feed.
        """

        ret_values = {
            ENTRY_NEW:0,
            ENTRY_UPDATED:0,
            ENTRY_SAME:0,
            ENTRY_ERR:0}

        # logging.debug(u' ---> [%d] Processing %s' % (self.feed.id, self.feed.feed_title))
            
        if hasattr(self.fpf, 'status'):
            if self.options['verbose']:
                logging.debug(u'   ---> [%-30s] Fetched feed, HTTP status %d: %s (bozo: %s)' % (unicode(self.feed)[:30],
                                                     self.fpf.status,
                                                     self.feed.feed_address,
                                                     self.fpf.bozo))
                if self.fpf.bozo and self.fpf.status != 304:
                    logging.debug(u'   ---> [%-30s] BOZO exception: %s' % (
                                  unicode(self.feed)[:30],
                                  self.fpf.bozo_exception,))
            if self.fpf.status == 304:
                self.feed.save()
                self.feed.save_feed_history(304, "Not modified")
                return FEED_SAME, ret_values

            if self.fpf.status >= 400:
                self.feed.save()
                self.feed.save_feed_history(self.fpf.status, "HTTP Error")
                return FEED_ERRHTTP, ret_values
                                    
        if self.fpf.bozo and isinstance(self.fpf.bozo_exception, feedparser.NonXMLContentType):
            if not self.fpf.entries:
                logging.debug("   ---> [%-30s] Feed is Non-XML. Checking address..." % unicode(self.feed)[:30])
                fixed_feed = self.feed.check_feed_address_for_feed_link()
                if not fixed_feed:
                    self.feed.save_feed_history(502, 'Non-xml feed', self.fpf.bozo_exception)
                return FEED_ERRPARSE, ret_values
        elif self.fpf.bozo and isinstance(self.fpf.bozo_exception, xml.sax._exceptions.SAXException):
            logging.debug("   ---> [%-30s] Feed is Bad XML (SAX). Checking address..." % unicode(self.feed)[:30])
            if not self.fpf.entries:
                fixed_feed = self.feed.check_feed_address_for_feed_link()
                if not fixed_feed:
                    self.feed.save_feed_history(503, 'SAX Exception', self.fpf.bozo_exception)
                return FEED_ERRPARSE, ret_values
                
        # the feed has changed (or it is the first time we parse it)
        # saving the etag and last_modified fields
        self.feed.etag = self.fpf.get('etag')
        if self.feed.etag:
            self.feed.etag = self.feed.etag[:255]
        # some times this is None (it never should) *sigh*
        if self.feed.etag is None:
            self.feed.etag = ''

        try:
            self.feed.last_modified = mtime(self.fpf.modified)
        except:
            pass
        
        self.feed.feed_title = self.fpf.feed.get('title', self.feed.feed_title)
        self.feed.feed_tagline = self.fpf.feed.get('tagline', self.feed.feed_tagline)
        self.feed.feed_link = self.fpf.feed.get('link', self.feed.feed_link)
        self.feed.last_update = datetime.datetime.now()
        
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
        start_date = datetime.datetime.now()
        end_date = datetime.datetime.now()
        story_guids = []
        for entry in self.fpf.entries:
            story = pre_process_story(entry)
            if story.get('published') < start_date:
                start_date = story.get('published')
            if story.get('published') > end_date:
                end_date = story.get('published')
            story_guids.append(story.get('guid') or story.get('link'))
        existing_stories = self.db.stories.find({
            'story_feed_id': self.feed.pk, 
            '$or': [
                {
                    'story_date': {'$gte': start_date},
                    'story_date': {'$lte': end_date}
                },
                {
                    'story_guid': {'$in': story_guids}
                }
            ]
        })
        # MStory.objects(
        #     (Q(story_date__gte=start_date) & Q(story_date__lte=end_date))
        #     | (Q(story_guid__in=story_guids)),
        #     story_feed=self.feed
        # ).order_by('-story_date')
        ret_values = self.feed.add_update_stories(self.fpf.entries, existing_stories, self.db)
        
        logging.debug(u'   ---> [%-30s] Parsed Feed: %s' % (
                      unicode(self.feed)[:30], 
                      u' '.join(u'%s=%d' % (self.entry_trans[key],
                              ret_values[key]) for key in self.entry_keys),))
        self.feed.update_all_statistics(lock=self.lock)
        self.feed.save_feed_history(200, "OK")
        
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
        self.feed_trans = {
            FEED_OK:'ok',
            FEED_SAME:'unchanged',
            FEED_ERRPARSE:'cant_parse',
            FEED_ERRHTTP:'http_error',
            FEED_ERREXC:'exception'}
        self.feed_keys = sorted(self.feed_trans.keys())
        self.num_threads = num_threads
        self.time_start = datetime.datetime.now()
        self.workers = []

    def process_feed_wrapper(self, feed_queue):
        """ wrapper for ProcessFeed
        """
        if not self.options['single_threaded']:
            # Close the DB so the connection can be re-opened on a per-process basis
            from django.db import connection
            connection.close()
        delta = None
        
        MONGO_DB = settings.MONGO_DB
        db = mongoengine.connection.connect(db=MONGO_DB['NAME'], host=MONGO_DB['HOST'], port=MONGO_DB['PORT'])
        
        current_process = multiprocessing.current_process()
        
        identity = "X"
        if current_process._identity:
            identity = current_process._identity[0]
        for feed in feed_queue:
            ret_entries = {
                ENTRY_NEW: 0,
                ENTRY_UPDATED: 0,
                ENTRY_SAME: 0,
                ENTRY_ERR: 0
            }
            start_time = datetime.datetime.now()
                    
            ### Uncomment to test feed fetcher
            # from random import randint
            # if randint(0,10) < 10:
            #     continue
            
            try:
                ffeed = FetchFeed(feed, self.options)
                ret_feed, fetched_feed = ffeed.fetch()
                
                if ((fetched_feed and ret_feed == FEED_OK) or self.options['force']):
                    pfeed = ProcessFeed(feed, fetched_feed, db, self.options)
                    ret_feed, ret_entries = pfeed.process()

                    if ret_entries.get(ENTRY_NEW) or self.options['force']:
                        user_subs = UserSubscription.objects.filter(feed=feed)
                        logging.debug(u'   ---> [%-30s] Computing scores for all feed subscribers: %s subscribers' % (unicode(feed)[:30], user_subs.count()))
                        for sub in user_subs:
                            cache.delete('usersub:%s' % sub.user_id)
                            silent = False if self.options['verbose'] >= 2 else True
                            sub.calculate_feed_scores(silent=silent)
                    cache.delete('feed_stories:%s-%s-%s' % (feed.id, 0, 25))
                    # if ret_entries.get(ENTRY_NEW) or ret_entries.get(ENTRY_UPDATED) or self.options['force']:
                    #     feed.get_stories(force=True)
            except KeyboardInterrupt:
                break
            except urllib2.HTTPError, e:
                feed.save_feed_history(e.code, e.msg, e.fp.read())
                fetched_feed = None
            except Exception, e:
                logging.debug('[%d] ! -------------------------' % (feed.id,))
                tb = traceback.format_exc()
                logging.debug(tb)
                logging.debug('[%d] ! -------------------------' % (feed.id,))
                ret_feed = FEED_ERREXC 
                feed.save_feed_history(500, "Error", tb)
                fetched_feed = None
                
            if ((self.options['force']) or 
                (fetched_feed and
                 feed.feed_link and
                 (ret_feed == FEED_OK or
                  (ret_feed == FEED_SAME and feed.stories_last_month > 10)))):
                  
                logging.debug(u'   ---> [%-30s] Fetching page' % (unicode(feed)[:30]))
                page_importer = PageImporter(feed.feed_link, feed)
                page_importer.fetch_page()

            delta = datetime.datetime.now() - start_time
            
            feed.last_load_time = max(1, delta.seconds)
            feed.fetched_once = True
            try:
                feed.save()
            except IntegrityError:
                logging.debug("   ---> [%-30s] IntegrityError on feed: %s" % (unicode(feed)[:30], feed.feed_address,))
            
            done_msg = (u'%2s ---> [%-30s] Processed in %s [%s]' % (
                identity, feed.feed_title[:30], unicode(delta),
                self.feed_trans[ret_feed],))
            logging.debug(done_msg)
            
            self.feed_stats[ret_feed] += 1
            for key, val in ret_entries.items():
                self.entry_stats[key] += val
        
        time_taken = datetime.datetime.now() - self.time_start
        history = FeedUpdateHistory(
            number_of_feeds=len(feed_queue),
            seconds_taken=time_taken.seconds
        )
        history.save()
        if not self.options['single_threaded']:
            logging.debug("---> DONE WITH PROCESS: %s" % current_process.name)
            sys.exit()

    def add_jobs(self, feeds_queue, feeds_count=1):
        """ adds a feed processing job to the pool
        """
        self.feeds_queue = feeds_queue
        self.feeds_count = feeds_count
            
    def run_jobs(self):
        if self.options['single_threaded']:
            self.process_feed_wrapper(self.feeds_queue[0])
        else:
            for i in range(self.num_threads):
                feed_queue = self.feeds_queue[i]
                self.workers.append(multiprocessing.Process(target=self.process_feed_wrapper,
                                                            args=(feed_queue,)))
                # worker.setName("Thread #%s" % (i+1))
                # worker.setDaemon(True)
            for i in range(self.num_threads):
                self.workers[i].start()
            
    def poll(self):
        """ polls the active threads
        """
        if not self.options['single_threaded']:
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
            logging.debug(done)
            return

                