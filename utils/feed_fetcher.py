
import socket
socket.setdefaulttimeout(2)

from apps.rss_feeds.models import Feed, Story, FeedUpdateHistory
from django.core.cache import cache
from apps.reader.models import UserSubscription
from apps.rss_feeds.importer import PageImporter
from utils import feedparser
from django.db.models import Q
from utils.story_functions import pre_process_story
import sys
import time
import logging
import datetime
import traceback
import multiprocessing
import urllib2

# Refresh feed code adapted from Feedjack.
# http://feedjack.googlecode.com

VERSION = '0.9'
URL = 'http://www.newsblur.com/'
USER_AGENT = 'NewsBlur %s - %s' % (VERSION, URL)
SLOWFEED_WARNING = 10
ENTRY_NEW, ENTRY_UPDATED, ENTRY_SAME, ENTRY_ERR = range(4)
FEED_OK, FEED_SAME, FEED_ERRPARSE, FEED_ERRHTTP, FEED_ERREXC = range(5)

socket.setdefaulttimeout(30)

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
        identity = "X"
        if current_process._identity:
            identity = current_process._identity[0]
        log_msg = u'%2s ---> Fetching %s (%d)' % (identity,
                                                 self.feed.feed_title,
                                                 self.feed.id)
        logging.info(log_msg)
        print(log_msg)
                                                 
        # Check if feed still needs to be updated
        feed = Feed.objects.get(pk=self.feed.pk)
        if feed.last_update > datetime.datetime.now() and not self.options.get('force'):
            log_msg = u'        ---> Already fetched %s (%d)' % (self.feed.feed_title,
                                                                 self.feed.id)
            logging.info(log_msg)
            print(log_msg)
            feed.save_history(201, "Already fetched")
            return FEED_SAME, None
        
        modified = self.feed.last_modified.utctimetuple()[:7] if self.feed.last_modified else None
        self.fpf = feedparser.parse(self.feed.feed_address,
                                    agent=USER_AGENT,
                                    etag=self.feed.etag,
                                    modified=modified)
        
        return FEED_OK, self.fpf
    
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
                self.feed.save()
                self.feed.save_history(304, "Not modified")
                return FEED_SAME, ret_values

            if self.fpf.status >= 400:
                # http error, ignore
                logging.error('[%d] !HTTP_ERROR! %d: %s' % (self.feed.id,
                                                     self.fpf.status,
                                                     self.feed.feed_address))
                self.feed.save()
                self.feed.save_history(self.fpf.status, "HTTP Error")
                return FEED_ERRHTTP, ret_values

        if hasattr(self.fpf, 'bozo') and self.fpf.bozo:
            logging.debug('[%d] !BOZO! Feed is not well formed: %s' % (
                self.feed.id, self.feed.feed_address))

        # the feed has changed (or it is the first time we parse it)
        # saving the etag and last_modified fields
        self.feed.etag = self.fpf.get('etag')
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
        # print 'Story GUIDs: %s' % story_guids
        # print 'Story start/end: %s %s' % (start_date, end_date)
        existing_stories = Story.objects.filter(
            (Q(story_date__gte=start_date) & Q(story_date__lte=end_date))
            | (Q(story_guid__in=story_guids)),
            story_feed=self.feed
        ).order_by('-story_date')
        # print 'Existing stories: %s' % existing_stories.count()
        ret_values = self.feed.add_update_stories(self.fpf.entries, existing_stories)
            
        self.feed.count_subscribers(lock=self.lock)
        self.feed.count_stories_per_month(lock=self.lock)
        self.feed.save_popular_authors(lock=self.lock)
        self.feed.save_popular_tags(lock=self.lock)

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
        self.time_start = datetime.datetime.now()
        self.workers = []


    def process_feed_wrapper(self, feed_queue):
        """ wrapper for ProcessFeed
        """
        # Close the DB so the connection can be re-opened on a per-process basis
        from django.db import connection
        connection.close()
        
        current_process = multiprocessing.current_process()
        lock = multiprocessing.Lock()
        
        identity = "X"
        if current_process._identity:
            identity = current_process._identity[0]
        for feed in feed_queue:
            # print "Process Feed: [%s] %s" % (current_process.name, feed)
            ret_entries = {
                ENTRY_NEW: 0,
                ENTRY_UPDATED: 0,
                ENTRY_SAME: 0,
                ENTRY_ERR: 0
            }
            start_time = datetime.datetime.now()
        
            feed.set_next_scheduled_update(lock=lock)
            
            ### Uncomment to test feed fetcher
            # from random import randint
            # if randint(0,10) < 10:
            #     continue
            
            try:
                ffeed = FetchFeed(feed, self.options)
                ret_feed, fetched_feed = ffeed.fetch()

                if fetched_feed and ret_feed == FEED_OK:
                    pfeed = ProcessFeed(feed, fetched_feed, self.options)
                    ret_feed, ret_entries = pfeed.process()
                
                    if ret_entries.get(ENTRY_NEW):
                        user_subs = UserSubscription.objects.filter(feed=feed)
                        for sub in user_subs:
                            logging.info('Deleting user sub cache: %s' % sub.user_id)
                            cache.delete('usersub:%s' % sub.user_id)
                            sub.calculate_feed_scores()
                    if ret_entries.get(ENTRY_NEW) or ret_entries.get(ENTRY_UPDATED):
                        feed.get_stories(force=True)
                
                if (fetched_feed and
                    feed.feed_link and
                    (ret_feed == FEED_OK or
                     (ret_feed == FEED_SAME and feed.stories_per_month > 10))):
                    page_importer = PageImporter(feed.feed_link, feed)
                    page_importer.fetch_page()
            except KeyboardInterrupt:
                break
            except urllib2.HTTPError, e:
                print "HTTP Error: %s" % e
                feed.save_history(e.code, e.msg, e.fp.read())
            except Exception, e:
                print '[%d] ! -------------------------' % (feed.id,)
                tb = traceback.format_exc()
                print tb
                print '[%d] ! -------------------------' % (feed.id,)
                ret_feed = FEED_ERREXC 
                feed.save_history(500, "Error", tb)

            delta = datetime.datetime.now() - start_time
            if delta.seconds > SLOWFEED_WARNING:
                comment = u' (SLOW FEED!)'
            else:
                comment = u''
            
            feed.last_load_time = max(1, delta.seconds)
            feed.save()
            
            done_msg = (u'%2s ---> Processed %s (%d) in %s\n        ---> [%s] [%s]%s' % (
                identity, feed.feed_title, feed.id, unicode(delta),
                u' '.join(u'%s=%d' % (self.entry_trans[key],
                          ret_entries[key]) for key in self.entry_keys),
                self.feed_trans[ret_feed],
                comment))
            logging.debug(done_msg)
            print(done_msg)
            
            self.feed_stats[ret_feed] += 1
            for key, val in ret_entries.items():
                self.entry_stats[key] += val
        if not self.options['single_threaded']:
            print "---> DONE WITH PROCESS: %s" % current_process.name
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
            print done
            time_taken = datetime.datetime.now() - self.time_start
            history = FeedUpdateHistory(
                number_of_feeds=self.feeds_count,
                seconds_taken=time_taken.seconds
            )
            history.save()
            logging.info(done)
            return

                