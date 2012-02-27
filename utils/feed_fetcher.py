import time
import datetime
import traceback
import multiprocessing
import urllib2
import xml.sax
import redis
import random
from django.core.cache import cache
from django.conf import settings
from django.db import IntegrityError
from apps.reader.models import UserSubscription, MUserStory
from apps.rss_feeds.models import Feed, MStory
from apps.rss_feeds.page_importer import PageImporter
from apps.rss_feeds.icon_importer import IconImporter
from utils import feedparser
from utils.story_functions import pre_process_story
from utils import log as logging
from utils.feed_functions import timelimit, TimeoutError, mail_feed_error_to_admin, utf8encode

# Refresh feed code adapted from Feedjack.
# http://feedjack.googlecode.com

ENTRY_NEW, ENTRY_UPDATED, ENTRY_SAME, ENTRY_ERR = range(4)
FEED_OK, FEED_SAME, FEED_ERRPARSE, FEED_ERRHTTP, FEED_ERREXC = range(5)

def mtime(ttime):
    """ datetime auxiliar function.
    """
    return datetime.datetime.fromtimestamp(time.mktime(ttime))
    
    
class FetchFeed:
    def __init__(self, feed_id, options):
        self.feed = Feed.objects.get(pk=feed_id)
        self.options = options
        self.fpf = None
    
    @timelimit(20)
    def fetch(self):
        """ 
        Uses feedparser to download the feed. Will be parsed later.
        """
        identity = self.get_identity()
        log_msg = u'%2s ---> [%-30s] ~FYFetching feed (~FB%d~FY), last update: %s' % (identity,
                                                            unicode(self.feed)[:30],
                                                            self.feed.id,
                                                            datetime.datetime.now() - self.feed.last_update)
        logging.debug(log_msg)
                                                 
        etag=self.feed.etag
        modified = self.feed.last_modified.utctimetuple()[:7] if self.feed.last_modified else None
        
        if self.options.get('force') or not self.feed.fetched_once or not self.feed.known_good:
            modified = None
            etag = None
            
        USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_1) AppleWebKit/534.48.3 (KHTML, like Gecko) Version/5.1 Safari/534.48.3 (NewsBlur Feed Fetcher - %s subscriber%s - %s)' % (
            self.feed.num_subscribers,
            's' if self.feed.num_subscribers != 1 else '',
            settings.NEWSBLUR_URL
        )

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
    def __init__(self, feed_id, fpf, options):
        self.feed_id = feed_id
        self.options = options
        self.fpf = fpf
        self.entry_trans = {
            ENTRY_NEW:'new',
            ENTRY_UPDATED:'updated',
            ENTRY_SAME:'same',
            ENTRY_ERR:'error'}
        self.entry_keys = sorted(self.entry_trans.keys())
    
    def refresh_feed(self):
        self.feed = Feed.objects.using('default').get(pk=self.feed_id) 
        
    def process(self):
        """ Downloads and parses a feed.
        """
        self.refresh_feed()
        
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
                    logging.debug(u'   ---> [%-30s] BOZO exception: %s (%s entries)' % (
                                  unicode(self.feed)[:30],
                                  self.fpf.bozo_exception,
                                  len(self.fpf.entries)))
            if self.fpf.status == 304:
                self.feed.save()
                self.feed.save_feed_history(304, "Not modified")
                return FEED_SAME, ret_values
            
            if self.fpf.status in (302, 301):
                if not self.fpf.href.endswith('feedburner.com/atom.xml'):
                    self.feed.feed_address = self.fpf.href
                if not self.feed.known_good:
                    self.feed.fetched_once = True
                    logging.debug("   ---> [%-30s] Feed is %s'ing. Refetching..." % (unicode(self.feed)[:30], self.fpf.status))
                    self.feed.schedule_feed_fetch_immediately()
                if not self.fpf.entries:
                    self.feed.save()
                    self.feed.save_feed_history(self.fpf.status, "HTTP Redirect")
                    return FEED_ERRHTTP, ret_values
            if self.fpf.status >= 400:
                logging.debug("   ---> [%-30s] HTTP Status code: %s.%s Checking address..." % (unicode(self.feed)[:30], self.fpf.status, ' Not' if self.feed.known_good else ''))
                fixed_feed = None
                if not self.feed.known_good:
                    fixed_feed = self.feed.check_feed_link_for_feed_address()
                if not fixed_feed:
                    self.feed.save_feed_history(self.fpf.status, "HTTP Error")
                self.feed.save()
                return FEED_ERRHTTP, ret_values
                                    
        if self.fpf.bozo and isinstance(self.fpf.bozo_exception, feedparser.NonXMLContentType):
            logging.debug("   ---> [%-30s] Feed is Non-XML. %s entries.%s Checking address..." % (unicode(self.feed)[:30], len(self.fpf.entries), ' Not' if self.feed.known_good and self.fpf.entries else ''))
            if not self.fpf.entries:
                fixed_feed = None
                if not self.feed.known_good:
                    fixed_feed = self.feed.check_feed_link_for_feed_address()
                if not fixed_feed:
                    self.feed.save_feed_history(502, 'Non-xml feed', self.fpf.bozo_exception)
                self.feed.save()
                return FEED_ERRPARSE, ret_values
        elif self.fpf.bozo and isinstance(self.fpf.bozo_exception, xml.sax._exceptions.SAXException):
            logging.debug("   ---> [%-30s] Feed has SAX/XML parsing issues. %s entries.%s Checking address..." % (unicode(self.feed)[:30], len(self.fpf.entries), ' Not' if self.fpf.entries else ''))
            if not self.fpf.entries:
                fixed_feed = None
                if not self.feed.known_good:
                    fixed_feed = self.feed.check_feed_link_for_feed_address()
                if not fixed_feed:
                    self.feed.save_feed_history(503, 'SAX Exception', self.fpf.bozo_exception)
                self.feed.save()
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
        
        self.fpf.entries = self.fpf.entries[:50]
        
        self.feed.feed_title = self.fpf.feed.get('title', self.feed.feed_title)
        tagline = self.fpf.feed.get('tagline', self.feed.data.feed_tagline)
        if tagline:
            self.feed.data.feed_tagline = utf8encode(tagline)
            self.feed.data.save()
        if not self.feed.feed_link_locked:
            self.feed.feed_link = self.fpf.feed.get('link') or self.fpf.feed.get('id') or self.feed.feed_link
        
        guids = []
        for entry in self.fpf.entries:
            if entry.get('id', ''):
                guids.append(entry.get('id', ''))
            elif entry.get('link'):
                guids.append(entry.link)
            elif entry.get('title'):
                guids.append(entry.title)
        self.feed.save()

        # Compare new stories to existing stories, adding and updating
        start_date = datetime.datetime.utcnow()
        # end_date = datetime.datetime.utcnow()
        story_guids = []
        for entry in self.fpf.entries:
            story = pre_process_story(entry)
            if story.get('published') < start_date:
                start_date = story.get('published')
            # if story.get('published') > end_date:
            #     end_date = story.get('published')
            story_guids.append(story.get('guid') or story.get('link'))
        
        existing_stories = list(MStory.objects(
            # story_guid__in=story_guids,
            story_date__gte=start_date,
            story_feed_id=self.feed_id
        ).limit(len(story_guids)))
        
        # MStory.objects(
        #     (Q(story_date__gte=start_date) & Q(story_date__lte=end_date))
        #     | (Q(story_guid__in=story_guids)),
        #     story_feed=self.feed
        # ).order_by('-story_date')
        ret_values = self.feed.add_update_stories(self.fpf.entries, existing_stories, verbose=self.options['verbose'])
        
        logging.debug(u'   ---> [%-30s] ~FYParsed Feed: new=~FG~SB%s~SN~FY up=~FY~SB%s~SN same=~FY%s err=~FR~SB%s' % (
                      unicode(self.feed)[:30], 
                      ret_values[ENTRY_NEW], ret_values[ENTRY_UPDATED], ret_values[ENTRY_SAME], ret_values[ENTRY_ERR]))
        self.feed.update_all_statistics(full=bool(ret_values[ENTRY_NEW]))
        self.feed.trim_feed()
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
        self.time_start = datetime.datetime.utcnow()
        self.workers = []

    def refresh_feed(self, feed_id):
        """Update feed, since it may have changed"""
        return Feed.objects.using('default').get(pk=feed_id)
        
    def process_feed_wrapper(self, feed_queue):
        delta = None
        current_process = multiprocessing.current_process()
        identity = "X"
        if current_process._identity:
            identity = current_process._identity[0]
            
        for feed_id in feed_queue:
            ret_entries = {
                ENTRY_NEW: 0,
                ENTRY_UPDATED: 0,
                ENTRY_SAME: 0,
                ENTRY_ERR: 0
            }
            start_time = time.time()
            ret_feed = FEED_ERREXC
            try:
                feed = self.refresh_feed(feed_id)
                
                skip = False
                if self.options.get('fake'):
                    skip = True
                    weight = "-"
                elif self.options.get('quick'):
                    weight = feed.stories_last_month * feed.num_subscribers
                    random_weight = random.randint(1, max(weight, 1))
                    quick = float(self.options['quick'])
                    rand = random.random()
                    if random_weight < 100 and rand < quick:
                        skip = True
                if skip:
                    logging.debug('   ---> [%-30s] ~BGFaking fetch, skipping (%s/month, %s subs)...' % (
                        unicode(feed)[:30],
                        weight,
                        feed.num_subscribers))
                    continue
                
                ffeed = FetchFeed(feed_id, self.options)
                ret_feed, fetched_feed = ffeed.fetch()
                
                if ((fetched_feed and ret_feed == FEED_OK) or self.options['force']):
                    pfeed = ProcessFeed(feed_id, fetched_feed, self.options)
                    ret_feed, ret_entries = pfeed.process()
                    
                    feed = self.refresh_feed(feed_id)
                    
                    if ret_entries.get(ENTRY_NEW) or self.options['force']:
                        if not feed.known_good:
                            feed.known_good = True
                            feed.save()
                        MUserStory.delete_old_stories(feed_id=feed.pk)
                        try:
                            self.count_unreads_for_subscribers(feed)
                        except TimeoutError:
                            logging.debug('   ---> [%-30s] Unread count took too long...' % (unicode(feed)[:30],))
                    cache.delete('feed_stories:%s-%s-%s' % (feed.id, 0, 25))
                    # if ret_entries.get(ENTRY_NEW) or ret_entries.get(ENTRY_UPDATED) or self.options['force']:
                    #     feed.get_stories(force=True)
            except KeyboardInterrupt:
                break
            except urllib2.HTTPError, e:
                feed.save_feed_history(e.code, e.msg, e.fp.read())
                fetched_feed = None
            except Feed.DoesNotExist, e:
                logging.debug('   ---> [%-30s] Feed is now gone...' % (unicode(feed_id)[:30]))
                continue
            except TimeoutError, e:
                logging.debug('   ---> [%-30s] Feed fetch timed out...' % (unicode(feed)[:30]))
                feed.save_feed_history(505, 'Timeout', '')
                fetched_feed = None
            except Exception, e:
                logging.debug('[%d] ! -------------------------' % (feed_id,))
                tb = traceback.format_exc()
                logging.error(tb)
                logging.debug('[%d] ! -------------------------' % (feed_id,))
                ret_feed = FEED_ERREXC 
                feed = self.refresh_feed(feed_id)
                feed.save_feed_history(500, "Error", tb)
                fetched_feed = None
                mail_feed_error_to_admin(feed, e)
            
            feed = self.refresh_feed(feed_id)
            if ((self.options['force']) or 
                (fetched_feed and
                 feed.feed_link and
                 feed.has_page and
                 (ret_feed == FEED_OK or
                  (ret_feed == FEED_SAME and feed.stories_last_month > 10)))):
                  
                logging.debug(u'   ---> [%-30s] ~FYFetching page: %s' % (unicode(feed)[:30], feed.feed_link))
                page_importer = PageImporter(feed)
                try:
                    page_importer.fetch_page()
                except TimeoutError, e:
                    logging.debug('   ---> [%-30s] ~FRPage fetch timed out...' % (unicode(feed)[:30]))
                    feed.save_page_history(555, 'Timeout', '')
                except Exception, e:
                    logging.debug('[%d] ! -------------------------' % (feed_id,))
                    tb = traceback.format_exc()
                    logging.error(tb)
                    logging.debug('[%d] ! -------------------------' % (feed_id,))
                    feed.save_page_history(550, "Page Error", tb)
                    fetched_feed = None
                    mail_feed_error_to_admin(feed, e)
                    
                logging.debug(u'   ---> [%-30s] ~FYFetching icon: %s' % (unicode(feed)[:30], feed.feed_link))
                icon_importer = IconImporter(feed, force=self.options['force'])
                try:
                    icon_importer.save()
                except TimeoutError, e:
                    logging.debug('   ---> [%-30s] ~FRIcon fetch timed out...' % (unicode(feed)[:30]))
                    feed.save_page_history(556, 'Timeout', '')
                except Exception, e:
                    logging.debug('[%d] ! -------------------------' % (feed_id,))
                    tb = traceback.format_exc()
                    logging.error(tb)
                    logging.debug('[%d] ! -------------------------' % (feed_id,))
                    # feed.save_feed_history(560, "Icon Error", tb)
                    mail_feed_error_to_admin(feed, e)
            else:
                logging.debug(u'   ---> [%-30s] ~FBSkipping page fetch: (%s on %s stories) %s' % (unicode(feed)[:30], self.feed_trans[ret_feed], feed.stories_last_month, '' if feed.has_page else ' [HAS NO PAGE]'))
            
            feed = self.refresh_feed(feed_id)
            delta = time.time() - start_time
            
            feed.last_load_time = round(delta)
            feed.fetched_once = True
            try:
                feed.save()
            except IntegrityError:
                logging.debug("   ---> [%-30s] ~FRIntegrityError on feed: %s" % (unicode(feed)[:30], feed.feed_address,))
            
            if ret_entries[ENTRY_NEW]:
                self.publish_to_subscribers(feed)
                
            done_msg = (u'%2s ---> [%-30s] ~FYProcessed in ~FG~SB%.4ss~FY~SN (~FB%s~FY) [%s]' % (
                identity, feed.feed_title[:30], delta,
                feed.pk, self.feed_trans[ret_feed],))
            logging.debug(done_msg)
            
            self.feed_stats[ret_feed] += 1
            for key, val in ret_entries.items():
                self.entry_stats[key] += val
        
        # time_taken = datetime.datetime.utcnow() - self.time_start
    
    def publish_to_subscribers(self, feed):
        try:
            r = redis.Redis(connection_pool=settings.REDIS_POOL)
            listeners_count = r.publish(str(feed.pk), 'story:new')
            if listeners_count:
                logging.debug("   ---> [%-30s] Published to %s subscribers" % (unicode(feed)[:30], listeners_count))
        except redis.ConnectionError:
            logging.debug("   ***> [%-30s] ~FRRedis is unavailable for real-time." % (unicode(feed)[:30],))
        
    @timelimit(20)
    def count_unreads_for_subscribers(self, feed):
        UNREAD_CUTOFF = datetime.datetime.utcnow() - datetime.timedelta(days=settings.DAYS_OF_UNREAD)
        user_subs = UserSubscription.objects.filter(feed=feed, 
                                                    active=True,
                                                    user__profile__last_seen_on__gte=UNREAD_CUTOFF)\
                                            .order_by('-last_read_date')
        logging.debug(u'   ---> [%-30s] Computing scores: %s (%s/%s/%s) subscribers' % (
                      unicode(feed)[:30], user_subs.count(),
                      feed.num_subscribers, feed.active_subscribers, feed.premium_subscribers))
        
        stories_db = MStory.objects(story_feed_id=feed.pk,
                                    story_date__gte=UNREAD_CUTOFF)
        for sub in user_subs:
            cache.delete('usersub:%s' % sub.user_id)
            sub.needs_unread_recalc = True
            sub.save()
            
        if self.options['compute_scores']:
            for sub in user_subs:
                silent = False if self.options['verbose'] >= 2 else True
                sub.calculate_feed_scores(silent=silent, stories_db=stories_db)
            
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
            for i in range(self.num_threads):
                self.workers[i].start()

                