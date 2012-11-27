import difflib
import datetime
import time
import random
import re
import math
import mongoengine as mongo
import zlib
import hashlib
import redis
from collections import defaultdict
from operator import itemgetter
# from nltk.collocations import TrigramCollocationFinder, BigramCollocationFinder, TrigramAssocMeasures, BigramAssocMeasures
from django.db import models
from django.db import IntegrityError
from django.conf import settings
from django.db.models.query import QuerySet
from django.core.urlresolvers import reverse
from django.contrib.sites.models import Site
from mongoengine.queryset import OperationError
from mongoengine.base import ValidationError
from apps.rss_feeds.tasks import UpdateFeeds, PushFeeds
from utils import json_functions as json
from utils import feedfinder, feedparser
from utils import urlnorm
from utils import log as logging
from utils.fields import AutoOneToOneField
from utils.feed_functions import levenshtein_distance
from utils.feed_functions import timelimit, TimeoutError
from utils.feed_functions import relative_timesince
from utils.feed_functions import seconds_timesince
from utils.story_functions import strip_tags, htmldiff, strip_comments

ENTRY_NEW, ENTRY_UPDATED, ENTRY_SAME, ENTRY_ERR = range(4)


class Feed(models.Model):
    feed_address = models.URLField(max_length=255, db_index=True)
    feed_address_locked = models.NullBooleanField(default=False, blank=True, null=True)
    feed_link = models.URLField(max_length=1000, default="", blank=True, null=True)
    feed_link_locked = models.BooleanField(default=False)
    hash_address_and_link = models.CharField(max_length=64, unique=True, db_index=True)
    feed_title = models.CharField(max_length=255, default="[Untitled]", blank=True, null=True)
    is_push = models.NullBooleanField(default=False, blank=True, null=True)
    active = models.BooleanField(default=True, db_index=True)
    num_subscribers = models.IntegerField(default=-1)
    active_subscribers = models.IntegerField(default=-1, db_index=True)
    premium_subscribers = models.IntegerField(default=-1)
    active_premium_subscribers = models.IntegerField(default=-1, db_index=True)
    branch_from_feed = models.ForeignKey('Feed', blank=True, null=True, db_index=True)
    last_update = models.DateTimeField(db_index=True)
    fetched_once = models.BooleanField(default=False)
    known_good = models.BooleanField(default=False, db_index=True)
    has_feed_exception = models.BooleanField(default=False, db_index=True)
    has_page_exception = models.BooleanField(default=False, db_index=True)
    has_page = models.BooleanField(default=True)
    exception_code = models.IntegerField(default=0)
    errors_since_good = models.IntegerField(default=0)
    min_to_decay = models.IntegerField(default=0)
    days_to_trim = models.IntegerField(default=90)
    creation = models.DateField(auto_now_add=True)
    etag = models.CharField(max_length=255, blank=True, null=True)
    last_modified = models.DateTimeField(null=True, blank=True)
    stories_last_month = models.IntegerField(default=0)
    average_stories_per_month = models.IntegerField(default=0)
    next_scheduled_update = models.DateTimeField(db_index=True)
    queued_date = models.DateTimeField(db_index=True)
    last_load_time = models.IntegerField(default=0)
    favicon_color = models.CharField(max_length=6, null=True, blank=True)
    favicon_not_found = models.BooleanField(default=False)
    s3_page = models.NullBooleanField(default=False, blank=True, null=True)
    s3_icon = models.NullBooleanField(default=False, blank=True, null=True)

    class Meta:
        db_table="feeds"
        ordering=["feed_title"]
        # unique_together=[('feed_address', 'feed_link')]
    
    def __unicode__(self):
        if not self.feed_title:
            self.feed_title = "[Untitled]"
            self.save()
        return "%s (%s)" % (self.feed_title, self.pk)
    
    @property
    def title(self):
        return self.feed_title or "[Untitled]"
        
    @property
    def favicon_url(self):
        if settings.BACKED_BY_AWS['icons_on_s3'] and self.s3_icon:
            return "http://%s/%s.png" % (settings.S3_ICONS_BUCKET_NAME, self.pk)
        return reverse('feed-favicon', kwargs={'feed_id': self.pk})
    
    @property
    def favicon_url_fqdn(self):
        if settings.BACKED_BY_AWS['icons_on_s3'] and self.s3_icon:
            return self.favicon_url
        return "http://%s%s" % (
            Site.objects.get_current().domain,
            self.favicon_url
        )
    
    @property
    def s3_pages_key(self):
        return "%s.gz.html" % self.pk
        
    @property
    def s3_icons_key(self):
        return "%s.png" % self.pk
        
    def canonical(self, full=False, include_favicon=True):
        feed = {
            'id': self.pk,
            'feed_title': self.feed_title,
            'feed_address': self.feed_address,
            'feed_link': self.feed_link,
            'num_subscribers': self.num_subscribers,
            'updated': relative_timesince(self.last_update),
            'updated_seconds_ago': seconds_timesince(self.last_update),
            'subs': self.num_subscribers,
            'is_push': self.is_push,
            'fetched_once': self.fetched_once,
            'not_yet_fetched': not self.fetched_once, # Legacy. Doh.
            'favicon_color': self.favicon_color,
            'favicon_fade': self.favicon_fade(),
            'favicon_border': self.favicon_border(),
            'favicon_text_color': self.favicon_text_color(),
            'favicon_fetching': self.favicon_fetching,
            'favicon_url': self.favicon_url,
            's3_page': self.s3_page,
            's3_icon': self.s3_icon,
        }
        
        if include_favicon:
            try:
                feed_icon = MFeedIcon.objects.get(feed_id=self.pk)
                feed['favicon'] = feed_icon.data
            except MFeedIcon.DoesNotExist:
                pass
        if self.has_page_exception or self.has_feed_exception:
            feed['has_exception'] = True
            feed['exception_type'] = 'feed' if self.has_feed_exception else 'page'
            feed['exception_code'] = self.exception_code
        elif full:
            feed['has_exception'] = False
            feed['exception_type'] = None
            feed['exception_code'] = self.exception_code
        
        if not self.has_page:
            feed['disabled_page'] = True
        if full:
            feed['feed_tags'] = json.decode(self.data.popular_tags) if self.data.popular_tags else []
            feed['feed_authors'] = json.decode(self.data.popular_authors) if self.data.popular_authors else []

            
        return feed
    
    def save(self, *args, **kwargs):
        if not self.last_update:
            self.last_update = datetime.datetime.utcnow()
        if not self.next_scheduled_update:
            self.next_scheduled_update = datetime.datetime.utcnow()
        if not self.queued_date:
            self.queued_date = datetime.datetime.utcnow()
        feed_address = self.feed_address or ""
        feed_link = self.feed_link or ""
        self.hash_address_and_link = hashlib.sha1(feed_address+feed_link).hexdigest()
            
        max_feed_title = Feed._meta.get_field('feed_title').max_length
        if len(self.feed_title) > max_feed_title:
            self.feed_title = self.feed_title[:max_feed_title]
        max_feed_address = Feed._meta.get_field('feed_address').max_length
        if len(feed_address) > max_feed_address:
            self.feed_address = feed_address[:max_feed_address]
        max_feed_link = Feed._meta.get_field('feed_link').max_length
        if len(feed_link) > max_feed_link:
            self.feed_link = feed_link[:max_feed_link]
        
        try:
            super(Feed, self).save(*args, **kwargs)
            return self
        except IntegrityError:
            duplicate_feed = Feed.objects.filter(feed_address=self.feed_address, feed_link=self.feed_link)
            if duplicate_feed:
                if self.pk != duplicate_feed[0].pk:
                    merge_feeds(self.pk, duplicate_feed[0].pk, force=True)
                return duplicate_feed[0]

            # Feed has been deleted. Just ignore it.
            logging.debug("%s: %s" % (self.feed_address, duplicate_feed))
            logging.debug(' ***> [%-30s] Feed deleted (%s).' % (unicode(self)[:30], self.pk))
            return
    
    def sync_redis(self):
        return MStory.sync_all_redis(self.pk)
        
    @classmethod
    def find_or_create(cls, feed_address, feed_link, *args, **kwargs):
        feeds = cls.objects.filter(feed_address=feed_address, feed_link=feed_link)
        if feeds:
            return feeds[0], False

        if feed_link and feed_link.endswith('/'):
            feeds = cls.objects.filter(feed_address=feed_address, feed_link=feed_link[:-1])
            if feeds:
                return feeds[0], False
        
        return cls.objects.get_or_create(feed_address=feed_address, feed_link=feed_link, *args, **kwargs)
        
    @classmethod
    def merge_feeds(cls, *args, **kwargs):
        merge_feeds(*args, **kwargs)
        
    @property
    def favicon_fetching(self):
        return bool(not (self.favicon_not_found or self.favicon_color))
        
    @classmethod
    def get_feed_from_url(cls, url, create=True, aggressive=False, fetch=True, offset=0):
        feed = None
        
        def criteria(key, value):
            if aggressive:
                return {'%s__icontains' % key: value}
            else:
                return {'%s' % key: value}
            
        def by_url(address):
            feed = cls.objects.filter(**criteria('feed_address', address)).order_by('-num_subscribers')
            if not feed:
                duplicate_feed = DuplicateFeed.objects.filter(**criteria('duplicate_address', address))
                if duplicate_feed and len(duplicate_feed) > offset:
                    feed = [duplicate_feed[offset].feed]
            if not feed and aggressive:
                feed = cls.objects.filter(**criteria('feed_link', address)).order_by('-num_subscribers')
                
            return feed
        
        # Normalize and check for feed_address, dupes, and feed_link
        url = urlnorm.normalize(url)
        feed = by_url(url)
        
        # Create if it looks good
        if feed and len(feed) > offset:
            feed = feed[offset]
        elif create:
            create_okay = False
            if feedfinder.isFeed(url):
                create_okay = True
            elif aggressive:
                # Could still be a feed. Just check if there are entries
                fp = feedparser.parse(url)
                if len(fp.entries):
                    create_okay = True
            if create_okay:
                feed = cls.objects.create(feed_address=url)
                feed = feed.update()
        
        # Still nothing? Maybe the URL has some clues.
        if not feed and fetch:
            feed_finder_url = feedfinder.feed(url)
            if feed_finder_url:
                feed = by_url(feed_finder_url)
                if not feed and create:
                    feed = cls.objects.create(feed_address=feed_finder_url)
                    feed = feed.update()
                elif feed and len(feed) > offset:
                    feed = feed[offset]
        
        # Not created and not within bounds, so toss results.
        if isinstance(feed, QuerySet):
            return
        
        return feed
        
    @classmethod
    def task_feeds(cls, feeds, queue_size=12):
        if isinstance(feeds, Feed):
            logging.debug(" ---> Tasking feed: %s" % feeds)
            feeds = [feeds]
        else:
            logging.debug(" ---> Tasking %s feeds..." % len(feeds))
        
        feed_queue = []
        for f in feeds:
            f.queued_date = datetime.datetime.utcnow()
            f.set_next_scheduled_update()

        for feed_queue in (feeds[pos:pos + queue_size] for pos in xrange(0, len(feeds), queue_size)):
            feed_ids = [feed.pk for feed in feed_queue]
            UpdateFeeds.apply_async(args=(feed_ids,), queue='update_feeds')

    def update_all_statistics(self, full=True, force=False):
        self.count_subscribers()
        count_extra = False
        if random.random() > .98 or not self.data.popular_tags or not self.data.popular_authors:
            count_extra = True
        if force or (full and count_extra):
            self.count_stories()
            self.save_popular_authors()
            self.save_popular_tags()
    
    def setup_feed_for_premium_subscribers(self):
        self.count_subscribers()
        self.set_next_scheduled_update()
        
    def check_feed_link_for_feed_address(self):
        @timelimit(10)
        def _1():
            feed_address = None
            try:
                is_feed = feedfinder.isFeed(self.feed_address)
            except KeyError:
                is_feed = False
            if not is_feed:
                feed_address = feedfinder.feed(self.feed_address)
                if not feed_address and self.feed_link:
                    feed_address = feedfinder.feed(self.feed_link)
            else:
                feed_address_from_link = feedfinder.feed(self.feed_link)
                if feed_address_from_link != self.feed_address:
                    feed_address = feed_address_from_link
        
            if feed_address:
                if feed_address.endswith('feedburner.com/atom.xml'):
                    # message = """
                    # %s - %s - %s
                    # """ % (feed_address, self.__dict__, pprint(self.__dict__))
                    # mail_admins('Wierdo alert', message, fail_silently=True)
                    logging.debug("  ---> Feed points to 'Wierdo', ignoring.")
                    return False
                try:
                    self.feed_address = feed_address
                    self.next_scheduled_update = datetime.datetime.utcnow()
                    self.has_feed_exception = False
                    self.active = True
                    self.save()
                except IntegrityError:
                    original_feed = Feed.objects.get(feed_address=feed_address, feed_link=self.feed_link)
                    original_feed.has_feed_exception = False
                    original_feed.active = True
                    original_feed.save()
                    merge_feeds(original_feed.pk, self.pk)
            return feed_address
        
        if self.feed_address_locked:
            return
            
        try:
            feed_address = _1()
        except TimeoutError:
            logging.debug('   ---> [%-30s] Feed address check timed out...' % (unicode(self)[:30]))
            self.save_feed_history(505, 'Timeout', '')
            feed_address = None
        
        if feed_address:
            self.has_feed_exception = True
            self.schedule_feed_fetch_immediately()
        
        return not not feed_address

    def save_feed_history(self, status_code, message, exception=None):
        MFeedFetchHistory(feed_id=self.pk, 
                          status_code=int(status_code),
                          message=message,
                          exception=exception,
                          fetch_date=datetime.datetime.utcnow()).save()
        # day_ago = datetime.datetime.now() - datetime.timedelta(hours=24)
        # new_fetch_histories = MFeedFetchHistory.objects(feed_id=self.pk, fetch_date__gte=day_ago)
        # if new_fetch_histories.count() < 5 or True:
        #     old_fetch_histories = MFeedFetchHistory.objects(feed_id=self.pk)[5:]
        # else:
        #     old_fetch_histories = MFeedFetchHistory.objects(feed_id=self.pk, fetch_date__lte=day_ago)
        # for history in old_fetch_histories:
        #     history.delete()
        if status_code not in (200, 304):
            self.errors_since_good += 1
            self.count_errors_in_history('feed', status_code)
            self.set_next_scheduled_update()
        elif self.has_feed_exception or self.errors_since_good:
            self.errors_since_good = 0
            self.has_feed_exception = False
            self.active = True
            self.save()
        
    def save_page_history(self, status_code, message, exception=None):
        MPageFetchHistory(feed_id=self.pk, 
                          status_code=int(status_code),
                          message=message,
                          exception=exception,
                          fetch_date=datetime.datetime.utcnow()).save()
        # old_fetch_histories = MPageFetchHistory.objects(feed_id=self.pk).order_by('-fetch_date')[5:]
        # for history in old_fetch_histories:
        #     history.delete()
            
        if status_code not in (200, 304):
            self.count_errors_in_history('page', status_code)
        elif self.has_page_exception:
            self.has_page_exception = False
            self.has_page = True
            self.active = True
            self.save()
        
    def count_errors_in_history(self, exception_type='feed', status_code=None):
        logging.debug('   ---> [%-30s] Counting errors in history...' % (unicode(self)[:30]))
        history_class = MFeedFetchHistory if exception_type == 'feed' else MPageFetchHistory
        fetch_history = map(lambda h: h.status_code, 
                            history_class.objects(feed_id=self.pk)[:50])
        non_errors = [h for h in fetch_history if int(h)     in (200, 304)]
        errors     = [h for h in fetch_history if int(h) not in (200, 304)]
        
        if len(non_errors) == 0 and len(errors) > 1:
            self.active = True
            if exception_type == 'feed':
                self.has_feed_exception = True
                # self.active = False # No longer, just geometrically fetch
            elif exception_type == 'page':
                self.has_page_exception = True
            self.exception_code = status_code or int(errors[0])
            self.save()
        elif self.exception_code > 0:
            self.active = True
            self.exception_code = 0
            if exception_type == 'feed':
                self.has_feed_exception = False
            elif exception_type == 'page':
                self.has_page_exception = False
            self.save()
        
        return errors, non_errors
    
    def count_subscribers(self, verbose=False):
        SUBSCRIBER_EXPIRE = datetime.datetime.now() - datetime.timedelta(days=settings.SUBSCRIBER_EXPIRE)
        from apps.reader.models import UserSubscription
        
        if self.branch_from_feed:
            original_feed_id = self.branch_from_feed.pk
        else:
            original_feed_id = self.pk
        feed_ids = [f['id'] for f in Feed.objects.filter(branch_from_feed=original_feed_id).values('id')]
        feed_ids.append(original_feed_id)
        feed_ids = list(set(feed_ids))

        subs = UserSubscription.objects.filter(feed__in=feed_ids)
        self.num_subscribers = subs.count()
        
        active_subs = UserSubscription.objects.filter(
            feed__in=feed_ids, 
            active=True,
            user__profile__last_seen_on__gte=SUBSCRIBER_EXPIRE
        )
        self.active_subscribers = active_subs.count()
        
        premium_subs = UserSubscription.objects.filter(
            feed__in=feed_ids, 
            active=True,
            user__profile__is_premium=True
        )
        self.premium_subscribers = premium_subs.count()
        
        active_premium_subscribers = UserSubscription.objects.filter(
            feed__in=feed_ids, 
            active=True,
            user__profile__is_premium=True,
            user__profile__last_seen_on__gte=SUBSCRIBER_EXPIRE
        )
        self.active_premium_subscribers = active_premium_subscribers.count()
        
        self.save()
        
        if verbose:
            if self.num_subscribers <= 1:
                print '.',
            else:
                print "\n %s> %s subscriber%s: %s" % (
                    '-' * min(self.num_subscribers, 20),
                    self.num_subscribers,
                    '' if self.num_subscribers == 1 else 's',
                    self.feed_title,
                ),

    def count_stories(self, verbose=False):
        self.save_feed_stories_last_month(verbose)
        # self.save_feed_story_history_statistics()
    
    def _split_favicon_color(self):
        color = self.favicon_color
        if color:
            splitter = lambda s, p: [s[i:i+p] for i in range(0, len(s), p)]
            red, green, blue = splitter(color[:6], 2)
            return red, green, blue
        return None, None, None
        
    def favicon_fade(self):
        red, green, blue = self._split_favicon_color()
        if red and green and blue:
            fade_red = hex(min(int(red, 16) + 35, 255))[2:].zfill(2)
            fade_green = hex(min(int(green, 16) + 35, 255))[2:].zfill(2)
            fade_blue = hex(min(int(blue, 16) + 35, 255))[2:].zfill(2)
            return "%s%s%s" % (fade_red, fade_green, fade_blue)

    def favicon_border(self):
        red, green, blue = self._split_favicon_color()
        if red and green and blue:
            fade_red = hex(min(int(int(red, 16) * .75), 255))[2:].zfill(2)
            fade_green = hex(min(int(int(green, 16) * .75), 255))[2:].zfill(2)
            fade_blue = hex(min(int(int(blue, 16) * .75), 255))[2:].zfill(2)
            return "%s%s%s" % (fade_red, fade_green, fade_blue)
            
    def favicon_text_color(self):
        # Color format: {r: 1, g: .5, b: 0}
        def contrast(color1, color2):
            lum1 = luminosity(color1)
            lum2 = luminosity(color2)
            if lum1 > lum2:
                return (lum1 + 0.05) / (lum2 + 0.05)
            else:
                return (lum2 + 0.05) / (lum1 + 0.05)

        def luminosity(color):
            r = color['red']
            g = color['green']
            b = color['blue']
            val = lambda c: c/12.92 if c <= 0.02928 else math.pow(((c + 0.055)/1.055), 2.4)
            red = val(r)
            green = val(g)
            blue = val(b)
            return 0.2126 * red + 0.7152 * green + 0.0722 * blue

        red, green, blue = self._split_favicon_color()
        if red and green and blue:
            color = {
                'red': int(red, 16) / 256.0,
                'green': int(green, 16) / 256.0,
                'blue': int(blue, 16) / 256.0,
            }
            white = {
                'red': 1,
                'green': 1,
                'blue': 1,
            }
            grey = {
                'red': 0.5,
                'green': 0.5,
                'blue': 0.5,
            }
            
            if contrast(color, white) > contrast(color, grey):
                return 'white'
            else:
                return 'black'
    
    def save_feed_stories_last_month(self, verbose=False):
        month_ago = datetime.datetime.utcnow() - datetime.timedelta(days=30)
        stories_last_month = MStory.objects(story_feed_id=self.pk, 
                                            story_date__gte=month_ago).count()
        self.stories_last_month = stories_last_month
        
        self.save()
            
        if verbose:
            print "  ---> %s [%s]: %s stories last month" % (self.feed_title, self.pk,
                                                             self.stories_last_month)
    
    def save_feed_story_history_statistics(self, current_counts=None):
        """
        Fills in missing months between earlier occurances and now.
        
        Save format: [('YYYY-MM, #), ...]
        Example output: [(2010-12, 123), (2011-01, 146)]
        """
        now = datetime.datetime.utcnow()
        min_year = now.year
        total = 0
        month_count = 0
        if not current_counts:
            current_counts = self.data.story_count_history and json.decode(self.data.story_count_history)
        
        if not current_counts:
            current_counts = []

        # Count stories, aggregate by year and month. Map Reduce!
        map_f = """
            function() {
                var date = (this.story_date.getFullYear()) + "-" + (this.story_date.getMonth()+1);
                emit(date, 1);
            }
        """
        reduce_f = """
            function(key, values) {
                var total = 0;
                for (var i=0; i < values.length; i++) {
                    total += values[i];
                }
                return total;
            }
        """
        dates = {}
        res = MStory.objects(story_feed_id=self.pk).map_reduce(map_f, reduce_f, output='inline')
        for r in res:
            dates[r.key] = r.value
            year = int(re.findall(r"(\d{4})-\d{1,2}", r.key)[0])
            if year < min_year and year > 2000:
                min_year = year
                
        # Add on to existing months, always amending up, never down. (Current month
        # is guaranteed to be accurate, since trim_feeds won't delete it until after
        # a month. Hacker News can have 1,000+ and still be counted.)
        for current_month, current_count in current_counts:
            year = int(re.findall(r"(\d{4})-\d{1,2}", current_month)[0])
            if current_month not in dates or dates[current_month] < current_count:
                dates[current_month] = current_count
            if year < min_year and year > 2000:
                min_year = year
        
        # Assemble a list with 0's filled in for missing months, 
        # trimming left and right 0's.
        months = []
        start = False
        for year in range(min_year, now.year+1):
            for month in range(1, 12+1):
                if datetime.datetime(year, month, 1) < now:
                    key = u'%s-%s' % (year, month)
                    if dates.get(key) or start:
                        start = True
                        months.append((key, dates.get(key, 0)))
                        total += dates.get(key, 0)
                        month_count += 1
        self.data.story_count_history = json.encode(months)
        self.data.save()
        if not total:
            self.average_stories_per_month = 0
        else:
            self.average_stories_per_month = total / month_count
        self.save()
        
        
    def save_classifier_counts(self):
        from apps.analyzer.models import MClassifierTitle, MClassifierAuthor, MClassifierFeed, MClassifierTag
        
        def calculate_scores(cls, facet):
            map_f = """
                function() {
                    emit(this["%s"], {
                        pos: this.score>0 ? this.score : 0, 
                        neg: this.score<0 ? Math.abs(this.score) : 0
                    });
                }
            """ % (facet)
            reduce_f = """
                function(key, values) {
                    var result = {pos: 0, neg: 0};
                    values.forEach(function(value) {
                        result.pos += value.pos;
                        result.neg += value.neg;
                    });
                    return result;
                }
            """
            scores = []
            res = cls.objects(feed_id=self.pk).map_reduce(map_f, reduce_f, output='inline')
            for r in res:
                facet_values = dict([(k, int(v)) for k,v in r.value.iteritems()])
                facet_values[facet] = r.key
                scores.append(facet_values)
            scores = sorted(scores, key=lambda v: v['neg'] - v['pos'])

            return scores
        
        scores = {}
        for cls, facet in [(MClassifierTitle, 'title'), 
                           (MClassifierAuthor, 'author'), 
                           (MClassifierTag, 'tag'), 
                           (MClassifierFeed, 'feed_id')]:
            scores[facet] = calculate_scores(cls, facet)
            if facet == 'feed_id' and scores[facet]:
                scores['feed'] = scores[facet]
                del scores['feed_id']
            elif not scores[facet]:
                del scores[facet]
                
        if scores:
            self.data.feed_classifier_counts = json.encode(scores)
            self.data.save()
        
    def update(self, **kwargs):
        from utils import feed_fetcher
        if getattr(settings, 'TEST_DEBUG', False):
            self.feed_address = self.feed_address % {'NEWSBLUR_DIR': settings.NEWSBLUR_DIR}
            self.feed_link = self.feed_link % {'NEWSBLUR_DIR': settings.NEWSBLUR_DIR}
            self.save()
        
        options = {
            'verbose': kwargs.get('verbose'),
            'timeout': 10,
            'single_threaded': kwargs.get('single_threaded', True),
            'force': kwargs.get('force'),
            'compute_scores': kwargs.get('compute_scores', True),
            'mongodb_replication_lag': kwargs.get('mongodb_replication_lag', None),
            'fake': kwargs.get('fake'),
            'quick': kwargs.get('quick'),
            'debug': kwargs.get('debug'),
            'fpf': kwargs.get('fpf'),
            'feed_xml': kwargs.get('feed_xml'),
        }
        disp = feed_fetcher.Dispatcher(options, 1)        
        disp.add_jobs([[self.pk]])
        feed = disp.run_jobs()
        
        feed = Feed.get_by_id(feed.pk)
        feed.last_update = datetime.datetime.utcnow()
        feed.set_next_scheduled_update()
        
        if options['force']:
            feed.sync_redis()
            
        return feed

    @classmethod
    def get_by_id(cls, feed_id, feed_address=None):
        try:
            feed = Feed.objects.get(pk=feed_id)
            return feed
        except Feed.DoesNotExist:
            # Feed has been merged after updating. Find the right feed.
            duplicate_feeds = DuplicateFeed.objects.filter(duplicate_feed_id=feed_id)
            if duplicate_feeds:
                return duplicate_feeds[0].feed
            if feed_address:
                duplicate_feeds = DuplicateFeed.objects.filter(duplicate_address=feed_address)
                if duplicate_feeds:
                    return duplicate_feeds[0].feed
                
    def add_update_stories(self, stories, existing_stories, verbose=False):
        ret_values = {
            ENTRY_NEW:0,
            ENTRY_UPDATED:0,
            ENTRY_SAME:0,
            ENTRY_ERR:0
        }
        
        for story in stories:
            if not story.get('title'):
                continue
                
            story_content = story.get('story_content')
            story_content = strip_comments(story_content)
            story_tags = self.get_tags(story)
            story_link = self.get_permalink(story)
                
            existing_story, story_has_changed = self._exists_story(story, story_content, existing_stories)
            if existing_story is None:
                s = MStory(story_feed_id = self.pk,
                       story_date = story.get('published'),
                       story_title = story.get('title'),
                       story_content = story_content,
                       story_author_name = story.get('author'),
                       story_permalink = story_link,
                       story_guid = story.get('guid'),
                       story_tags = story_tags
                )
                try:
                    s.save()
                    ret_values[ENTRY_NEW] += 1
                except (IntegrityError, OperationError):
                    ret_values[ENTRY_ERR] += 1
                    if verbose:
                        logging.info('   ---> [%-30s] ~SN~FRIntegrityError on new story: %s' % (self.feed_title[:30], story.get('title')[:30]))
            elif existing_story and story_has_changed:
                # update story
                # logging.debug('- Updated story in feed (%s - %s): %s / %s' % (self.feed_title, story.get('title'), len(existing_story.story_content), len(story_content)))
                
                original_content = None
                try:
                    if existing_story and existing_story.id:
                        try:
                            existing_story = MStory.objects.get(id=existing_story.id)
                        except ValidationError:
                            existing_story = MStory.objects.get(story_feed_id=existing_story.story_feed_id, 
                                                                story_guid=existing_story.id)
                    elif existing_story and existing_story.story_guid:
                        existing_story = MStory.objects.get(story_feed_id=existing_story.story_feed_id,
                                                            story_guid=existing_story.story_guid)
                    else:
                        raise MStory.DoesNotExist
                except (MStory.DoesNotExist, OperationError):
                    ret_values[ENTRY_ERR] += 1
                    if verbose:
                        logging.info('   ---> [%-30s] ~SN~FROperation on existing story: %s' % (self.feed_title[:30], story.get('title')[:30]))
                    continue
                if existing_story.story_original_content_z:
                    original_content = zlib.decompress(existing_story.story_original_content_z)
                elif existing_story.story_content_z:
                    original_content = zlib.decompress(existing_story.story_content_z)
                # print 'Type: %s %s' % (type(original_content), type(story_content))
                if story_content and len(story_content) > 10:
                    story_content_diff = htmldiff(unicode(original_content), unicode(story_content))
                else:
                    story_content_diff = original_content
                # logging.debug("\t\tDiff: %s %s %s" % diff.getStats())
                # logging.debug("\t\tDiff content: %s" % diff.getDiff())
                # if existing_story.story_title != story.get('title'):
                #    logging.debug('\tExisting title / New: : \n\t\t- %s\n\t\t- %s' % (existing_story.story_title, story.get('title')))
                if existing_story.story_guid != story.get('guid'):
                    self.update_read_stories_with_new_guid(existing_story.story_guid, story.get('guid'))
                
                existing_story.story_feed = self.pk
                # Do not allow publishers to change the story date once a story is published.
                # Leads to incorrect unread story counts.
                # existing_story.story_date = story.get('published')
                existing_story.story_title = story.get('title')
                existing_story.story_content = story_content_diff
                existing_story.story_latest_content = story_content
                existing_story.story_original_content = original_content
                existing_story.story_author_name = story.get('author')
                existing_story.story_permalink = story_link
                existing_story.story_guid = story.get('guid')
                existing_story.story_tags = story_tags
                try:
                    existing_story.save()
                    ret_values[ENTRY_UPDATED] += 1
                except (IntegrityError, OperationError):
                    ret_values[ENTRY_ERR] += 1
                    if verbose:
                        logging.info('   ---> [%-30s] ~SN~FRIntegrityError on updated story: %s' % (self.feed_title[:30], story.get('title')[:30]))
                except ValidationError:
                    ret_values[ENTRY_ERR] += 1
                    if verbose:
                        logging.info('   ---> [%-30s] ~SN~FRValidationError on updated story: %s' % (self.feed_title[:30], story.get('title')[:30]))
            else:
                ret_values[ENTRY_SAME] += 1
                # logging.debug("Unchanged story: %s " % story.get('title'))
        
        return ret_values
    
    def update_read_stories_with_new_guid(self, old_story_guid, new_story_guid):
        from apps.reader.models import MUserStory
        from apps.social.models import MSharedStory
        read_stories = MUserStory.objects.filter(feed_id=self.pk, story_id=old_story_guid)
        for story in read_stories:
            story.story_id = new_story_guid
            try:
                story.save()
            except OperationError:
                # User read both new and old. Just toss.
                pass
        shared_stories = MSharedStory.objects.filter(story_feed_id=self.pk,
                                                     story_guid=old_story_guid)
        for story in shared_stories:
            story.story_guid = new_story_guid
            story.save()
                
    def save_popular_tags(self, feed_tags=None, verbose=False):
        if not feed_tags:
            all_tags = MStory.objects(story_feed_id=self.pk, story_tags__exists=True).item_frequencies('story_tags')
            feed_tags = sorted([(k, v) for k, v in all_tags.items() if int(v) > 0], 
                               key=itemgetter(1), 
                               reverse=True)[:25]
        popular_tags = json.encode(feed_tags)
        if verbose:
            print "Found %s tags: %s" % (len(feed_tags), popular_tags)
        
        # TODO: This len() bullshit will be gone when feeds move to mongo
        #       On second thought, it might stay, because we don't want
        #       popular tags the size of a small planet. I'm looking at you
        #       Tumblr writers.
        if len(popular_tags) < 1024:
            self.data.popular_tags = popular_tags
            self.data.save()
            return

        tags_list = []
        if feed_tags and isinstance(feed_tags, unicode):
            tags_list = json.decode(feed_tags)
        if len(tags_list) >= 1:
            self.save_popular_tags(tags_list[:-1])
    
    def save_popular_authors(self, feed_authors=None):
        if not feed_authors:
            authors = defaultdict(int)
            for story in MStory.objects(story_feed_id=self.pk).only('story_author_name'):
                authors[story.story_author_name] += 1
            feed_authors = sorted([(k, v) for k, v in authors.items() if k], 
                               key=itemgetter(1),
                               reverse=True)[:20]

        popular_authors = json.encode(feed_authors)
        if len(popular_authors) < 1023:
            self.data.popular_authors = popular_authors
            self.data.save()
            return

        if len(feed_authors) > 1:
            self.save_popular_authors(feed_authors=feed_authors[:-1])
            
    def trim_feed(self, verbose=False):
        trim_cutoff = 500
        if self.active_subscribers <= 1 and self.premium_subscribers < 1:
            trim_cutoff = 100
        elif self.active_subscribers <= 3  and self.premium_subscribers < 2:
            trim_cutoff = 200
        elif self.active_subscribers <= 5  and self.premium_subscribers < 3:
            trim_cutoff = 300
        elif self.active_subscribers <= 10 and self.premium_subscribers < 4:
            trim_cutoff = 350
        elif self.active_subscribers <= 20 and self.premium_subscribers < 5:
            trim_cutoff = 400
        elif self.active_subscribers <= 25 and self.premium_subscribers < 5:
            trim_cutoff = 450
            
        stories = MStory.objects(
            story_feed_id=self.pk,
        ).order_by('-story_date')
        
        if stories.count() > trim_cutoff:
            logging.debug('   ---> [%-30s] ~FBFound %s stories. Trimming to ~SB%s~SN...' %
                          (unicode(self)[:30], stories.count(), trim_cutoff))
            try:
                story_trim_date = stories[trim_cutoff].story_date
            except IndexError, e:
                logging.debug(' ***> [%-30s] ~BRError trimming feed: %s' % (unicode(self)[:30], e))
                return
                
            extra_stories = MStory.objects(story_feed_id=self.pk, 
                                           story_date__lte=story_trim_date)
            extra_stories_count = extra_stories.count()
            for story in extra_stories:
                story.delete()
            if verbose:
                existing_story_count = MStory.objects(story_feed_id=self.pk).count()
                print "Deleted %s stories, %s left." % (extra_stories_count,
                                                        existing_story_count)

    @staticmethod
    def clean_invalid_ids():
        history = MFeedFetchHistory.objects(status_code=500, exception__contains='InvalidId:')
        urls = set()
        for h in history:
            u = re.split('InvalidId: (.*?) is not a valid ObjectId\\n$', h.exception)[1]
            urls.add((h.feed_id, u))
        
        for f, u in urls:
            print "db.stories.remove({\"story_feed_id\": %s, \"_id\": \"%s\"})" % (f, u)

        
    def get_stories(self, offset=0, limit=25, force=False):
        stories_db = MStory.objects(story_feed_id=self.pk)[offset:offset+limit]
        stories = self.format_stories(stories_db, self.pk)
        
        return stories
    
    @classmethod
    def format_stories(cls, stories_db, feed_id=None):
        stories = []

        for story_db in stories_db:
            story = cls.format_story(story_db, feed_id)
            stories.append(story)
            
        return stories
    
    @classmethod
    def format_story(cls, story_db, feed_id=None, text=False):
        story_content = story_db.story_content_z and zlib.decompress(story_db.story_content_z) or ''
        story                     = {}
        story['story_tags']       = story_db.story_tags or []
        story['story_date']       = story_db.story_date
        story['story_authors']    = story_db.story_author_name
        story['story_title']      = story_db.story_title
        story['story_content']    = story_content
        story['story_permalink']  = story_db.story_permalink
        story['story_feed_id']    = feed_id or story_db.story_feed_id
        story['comment_count']    = story_db.comment_count if hasattr(story_db, 'comment_count') else 0
        story['comment_user_ids'] = story_db.comment_user_ids if hasattr(story_db, 'comment_user_ids') else []
        story['share_count']      = story_db.share_count if hasattr(story_db, 'share_count') else 0
        story['share_user_ids']   = story_db.share_user_ids if hasattr(story_db, 'share_user_ids') else []
        story['guid_hash']        = story_db.guid_hash if hasattr(story_db, 'guid_hash') else None
        if hasattr(story_db, 'source_user_id'):
            story['source_user_id']   = story_db.source_user_id
        story['id']               = story_db.story_guid or story_db.story_date
        if hasattr(story_db, 'starred_date'):
            story['starred_date'] = story_db.starred_date
        if hasattr(story_db, 'shared_date'):
            story['shared_date'] = story_db.shared_date
        if hasattr(story_db, 'blurblog_permalink'):
            story['blurblog_permalink'] = story_db.blurblog_permalink()
        if text:
            from BeautifulSoup import BeautifulSoup
            soup = BeautifulSoup(story['story_content'])
            text = ''.join(soup.findAll(text=True))
            text = re.sub(r'\n+', '\n\n', text)
            text = re.sub(r'\t+', '\t', text)
            story['text'] = text
        if '<ins' in story['story_content'] or '<del' in story['story_content']:
            story['has_modifications'] = True
        
        return story
    
    def get_tags(self, entry):
        fcat = []
        if entry.has_key('tags'):
            for tcat in entry.tags:
                term = None
                if hasattr(tcat, 'label') and tcat.label:
                    term = tcat.label
                elif hasattr(tcat, 'term') and tcat.term:
                    term = tcat.term
                if not term:
                    continue
                qcat = term.strip()
                if ',' in qcat or '/' in qcat:
                    qcat = qcat.replace(',', '/').split('/')
                else:
                    qcat = [qcat]
                for zcat in qcat:
                    tagname = zcat.lower()
                    while '  ' in tagname:
                        tagname = tagname.replace('  ', ' ')
                    tagname = tagname.strip()
                    if not tagname or tagname == ' ':
                        continue
                    fcat.append(tagname)
        fcat = [strip_tags(t)[:250] for t in fcat[:12]]
        return fcat
    
    def get_permalink(self, entry):
        link = entry.get('link')
        if not link:
            links = entry.get('links')
            if links:
                link = links[0].get('href')
        if not link:
            link = entry.get('id')
        return link
    
    def _exists_story(self, story=None, story_content=None, existing_stories=None):
        story_in_system = None
        story_has_changed = False
        story_pub_date = story.get('published')
        story_published_now = story.get('published_now', False)
        story_link = self.get_permalink(story)
        start_date = story_pub_date - datetime.timedelta(hours=8)
        end_date = story_pub_date + datetime.timedelta(hours=8)

        for existing_story in existing_stories:
            content_ratio = 0
            existing_story_pub_date = existing_story.story_date
            # print 'Story pub date: %s %s' % (story_published_now, story_pub_date)
            if (story_published_now or
                (existing_story_pub_date > start_date and existing_story_pub_date < end_date)):
                
                if 'story_latest_content_z' in existing_story:
                    existing_story_content = unicode(zlib.decompress(existing_story.story_latest_content_z))
                elif 'story_latest_content' in existing_story:
                    existing_story_content = existing_story.story_latest_content
                elif 'story_content_z' in existing_story:
                    existing_story_content = unicode(zlib.decompress(existing_story.story_content_z))
                elif 'story_content' in existing_story:
                    existing_story_content = existing_story.story_content
                else:
                    existing_story_content = u''
                    
                if isinstance(existing_story.id, unicode):
                    existing_story.story_guid = existing_story.id
                if story.get('guid') and story.get('guid') == existing_story.story_guid:
                    story_in_system = existing_story
                
                # Title distance + content distance, checking if story changed
                story_title_difference = abs(levenshtein_distance(story.get('title'),
                                                                  existing_story.story_title))
                
                seq = difflib.SequenceMatcher(None, story_content, existing_story_content)
                
                if (seq
                    and story_content
                    and existing_story_content
                    and seq.real_quick_ratio() > .9 
                    and seq.quick_ratio() > .95):
                    content_ratio = seq.ratio()
                    
                if story_title_difference > 0 and content_ratio > .98:
                    story_in_system = existing_story
                    if story_title_difference > 0 or content_ratio < 1.0:
                        # print "Title difference - %s/%s (%s): %s" % (story.get('title'), existing_story.story_title, story_title_difference, content_ratio)
                        story_has_changed = True
                        break
                
                # More restrictive content distance, still no story match
                if not story_in_system and content_ratio > .98:
                    # print "Content difference - %s/%s (%s): %s" % (story.get('title'), existing_story.story_title, story_title_difference, content_ratio)
                    story_in_system = existing_story
                    story_has_changed = True
                    break
                    
                if story_in_system and not story_has_changed:
                    if story_content != existing_story_content:
                        story_has_changed = True
                    if story_link != existing_story.story_permalink:
                        story_has_changed = True
                    break
                
        
        # if story_has_changed or not story_in_system:
        #     print 'New/updated story: %s' % (story), 
        return story_in_system, story_has_changed
        
    def get_next_scheduled_update(self, force=False, verbose=True):
        if self.min_to_decay and not force:
            random_factor = random.randint(0, self.min_to_decay) / 4
            return self.min_to_decay, random_factor
            
        # Use stories per month to calculate next feed update
        updates_per_month = self.stories_last_month
        # if updates_per_day < 1 and self.num_subscribers > 2:
        #     updates_per_day = 1
        # 0 updates per day = 24 hours
        # 1 subscriber:
        #   0 updates per month = 4 hours
        #   1 update = 2 hours
        #   2 updates = 1.5 hours
        #   4 updates = 1 hours
        #   10 updates = .5 hour
        # 2 subscribers:
        #   1 update per day = 1 hours
        #   10 updates = 20 minutes
        updates_per_day_delay = 3 * 60 / max(.25, ((max(0, self.active_subscribers)**.2)
                                                    * (updates_per_month**0.35)))
        if self.premium_subscribers > 0:
            updates_per_day_delay /= min(self.active_subscribers+self.premium_subscribers, 5)
        # Lots of subscribers = lots of updates
        # 24 hours for 0 subscribers.
        # 4 hours for 1 subscriber.
        # .5 hours for 2 subscribers.
        # .25 hours for 3 subscribers.
        # 1 min for 10 subscribers.
        subscriber_bonus = 6 * 60 / max(.167, max(0, self.active_subscribers)**3)
        if self.premium_subscribers > 0:
            subscriber_bonus /= min(self.active_subscribers+self.premium_subscribers, 5)
        
        slow_punishment = 0
        if self.num_subscribers <= 1:
            if 30 <= self.last_load_time < 60:
                slow_punishment = self.last_load_time
            elif 60 <= self.last_load_time < 200:
                slow_punishment = 2 * self.last_load_time
            elif self.last_load_time >= 200:
                slow_punishment = 6 * self.last_load_time
        total = max(4, int(updates_per_day_delay + subscriber_bonus + slow_punishment))
        
        if self.active_premium_subscribers > 0:
            total = min(total, 60) # 1 hour minimum for premiums
        if self.is_push:
            total = total * 20
        if verbose:
            print "[%s] %s (%s/%s/%s/%s), %s, %s: %s" % (self, updates_per_day_delay, 
                                                self.num_subscribers, self.active_subscribers,
                                                self.premium_subscribers, self.active_premium_subscribers,
                                                subscriber_bonus, slow_punishment, total)
        random_factor = random.randint(0, total) / 4
        
        return total, random_factor*2
        
    def set_next_scheduled_update(self):
        total, random_factor = self.get_next_scheduled_update(force=True, verbose=False)
        
        if self.errors_since_good:
            total = total * self.errors_since_good
            logging.debug('   ---> [%-30s] ~FBScheduling feed fetch geometrically: ~SB%s errors. Time: %s min' % (unicode(self)[:30], self.errors_since_good, total))
            
        next_scheduled_update = datetime.datetime.utcnow() + datetime.timedelta(
                                minutes = total + random_factor)
            
        self.min_to_decay = total
        self.next_scheduled_update = next_scheduled_update

        self.save()

    def schedule_feed_fetch_immediately(self):
        logging.debug('   ---> [%-30s] Scheduling feed fetch immediately...' % (unicode(self)[:30]))
        self.next_scheduled_update = datetime.datetime.utcnow()

        return self.save()
        
    def setup_push(self):
        from apps.push.models import PushSubscription
        try:
            push = self.push
        except PushSubscription.DoesNotExist:
            self.is_push = False
        else:
            self.is_push = push.verified
        self.save()
    
    def queue_pushed_feed_xml(self, xml):
        logging.debug('   ---> [%-30s] [%s] ~FBQueuing pushed stories...' % (unicode(self)[:30], self.pk))
        
        self.queued_date = datetime.datetime.utcnow()
        self.set_next_scheduled_update()

        PushFeeds.apply_async(args=(self.pk, xml), queue='push_feeds')
        
    # def calculate_collocations_story_content(self,
    #                                          collocation_measures=TrigramAssocMeasures,
    #                                          collocation_finder=TrigramCollocationFinder):
    #     stories = MStory.objects.filter(story_feed_id=self.pk)
    #     story_content = ' '.join([s.story_content for s in stories if s.story_content])
    #     return self.calculate_collocations(story_content, collocation_measures, collocation_finder)
    #     
    # def calculate_collocations_story_title(self,
    #                                        collocation_measures=BigramAssocMeasures,
    #                                        collocation_finder=BigramCollocationFinder):
    #     stories = MStory.objects.filter(story_feed_id=self.pk)
    #     story_titles = ' '.join([s.story_title for s in stories if s.story_title])
    #     return self.calculate_collocations(story_titles, collocation_measures, collocation_finder)
    # 
    # def calculate_collocations(self, content,
    #                            collocation_measures=TrigramAssocMeasures,
    #                            collocation_finder=TrigramCollocationFinder):
    #     content = re.sub(r'&#8217;', '\'', content)
    #     content = re.sub(r'&amp;', '&', content)
    #     try:
    #         content = unicode(BeautifulStoneSoup(content,
    #                           convertEntities=BeautifulStoneSoup.HTML_ENTITIES))
    #     except ValueError, e:
    #         print "ValueError, ignoring: %s" % e
    #     content = re.sub(r'</?\w+\s+[^>]*>', '', content)
    #     content = re.split(r"[^A-Za-z-'&]+", content)
    # 
    #     finder = collocation_finder.from_words(content)
    #     finder.apply_freq_filter(3)
    #     best = finder.nbest(collocation_measures.pmi, 10)
    #     phrases = [' '.join(phrase) for phrase in best]
    #     
    #     return phrases

# class FeedCollocations(models.Model):
#     feed = models.ForeignKey(Feed)
#     phrase = models.CharField(max_length=500)
        
class FeedData(models.Model):
    feed = AutoOneToOneField(Feed, related_name='data')
    feed_tagline = models.CharField(max_length=1024, blank=True, null=True)
    story_count_history = models.TextField(blank=True, null=True)
    feed_classifier_counts = models.TextField(blank=True, null=True)
    popular_tags = models.CharField(max_length=1024, blank=True, null=True)
    popular_authors = models.CharField(max_length=2048, blank=True, null=True)
    
    def save(self, *args, **kwargs):
        if self.feed_tagline and len(self.feed_tagline) >= 1000:
            self.feed_tagline = self.feed_tagline[:1000]
        
        try:    
            super(FeedData, self).save(*args, **kwargs)
        except (IntegrityError, OperationError):
            if hasattr(self, 'id') and self.id: self.delete()


class MFeedIcon(mongo.Document):
    feed_id       = mongo.IntField(primary_key=True)
    color         = mongo.StringField(max_length=6)
    data          = mongo.StringField()
    icon_url      = mongo.StringField()
    not_found     = mongo.BooleanField(default=False)
    
    meta = {
        'collection'        : 'feed_icons',
        'allow_inheritance' : False,
    }
    
    def save(self, *args, **kwargs):
        if self.icon_url:
            self.icon_url = unicode(self.icon_url)
        try:    
            super(MFeedIcon, self).save(*args, **kwargs)
        except (IntegrityError, OperationError):
            # print "Error on Icon: %s" % e
            if hasattr(self, '_id'): self.delete()


class MFeedPage(mongo.Document):
    feed_id = mongo.IntField(primary_key=True)
    page_data = mongo.BinaryField()
    
    meta = {
        'collection': 'feed_pages',
        'allow_inheritance': False,
    }
    
    def save(self, *args, **kwargs):
        if self.page_data:
            self.page_data = zlib.compress(self.page_data)
        super(MFeedPage, self).save(*args, **kwargs)
    
    @classmethod
    def get_data(cls, feed_id):
        data = None
        feed_page = cls.objects(feed_id=feed_id)
        if feed_page:
            page_data_z = feed_page[0].page_data
            if page_data_z:
                data = zlib.decompress(page_data_z)
        
        if not data:
            dupe_feed = DuplicateFeed.objects.filter(duplicate_feed_id=feed_id)
            if dupe_feed:
                feed = dupe_feed[0].feed
                feed_page = MFeedPage.objects.filter(feed_id=feed.pk)
                if feed_page:
                    page_data_z = feed_page[0].page_data
                    if page_data_z:
                        data = zlib.decompress(feed_page[0].page_data)

        return data

class MStory(mongo.Document):
    '''A feed item'''
    story_feed_id            = mongo.IntField(unique_with='story_guid')
    story_date               = mongo.DateTimeField()
    story_title              = mongo.StringField(max_length=1024)
    story_content            = mongo.StringField()
    story_content_z          = mongo.BinaryField()
    story_original_content   = mongo.StringField()
    story_original_content_z = mongo.BinaryField()
    story_latest_content     = mongo.StringField()
    story_latest_content_z   = mongo.BinaryField()
    story_content_type       = mongo.StringField(max_length=255)
    story_author_name        = mongo.StringField()
    story_permalink          = mongo.StringField()
    story_guid               = mongo.StringField()
    story_tags               = mongo.ListField(mongo.StringField(max_length=250))
    comment_count            = mongo.IntField()
    comment_user_ids         = mongo.ListField(mongo.IntField())
    share_count              = mongo.IntField()
    share_user_ids           = mongo.ListField(mongo.IntField())

    meta = {
        'collection': 'stories',
        'indexes': [('story_feed_id', '-story_date')],
        'index_drop_dups': True,
        'ordering': ['-story_date'],
        'allow_inheritance': False,
        'cascade': False,
    }
    
    @property
    def guid_hash(self):
        return hashlib.sha1(self.story_guid).hexdigest()[:6]
    
    def save(self, *args, **kwargs):
        story_title_max = MStory._fields['story_title'].max_length
        story_content_type_max = MStory._fields['story_content_type'].max_length
        if self.story_content:
            self.story_content_z = zlib.compress(self.story_content)
            self.story_content = None
        if self.story_original_content:
            self.story_original_content_z = zlib.compress(self.story_original_content)
            self.story_original_content = None
        if self.story_latest_content:
            self.story_latest_content_z = zlib.compress(self.story_latest_content)
            self.story_latest_content = None
        if self.story_title and len(self.story_title) > story_title_max:
            self.story_title = self.story_title[:story_title_max]
        if self.story_content_type and len(self.story_content_type) > story_content_type_max:
            self.story_content_type = self.story_content_type[:story_content_type_max]
        super(MStory, self).save(*args, **kwargs)
        
        self.sync_redis()
    
    def delete(self, *args, **kwargs):
        self.remove_from_redis()
        
        super(MStory, self).delete(*args, **kwargs)
    
    @classmethod
    def find_story(cls, story_feed_id, story_id):
        from apps.social.models import MSharedStory
        original_found = True

        story = cls.objects(story_feed_id=story_feed_id,
                            story_guid=story_id).limit(1).first()
        if not story:
            original_found = False
            story = MSharedStory.objects.filter(story_feed_id=story_feed_id, 
                                                story_guid=story_id).limit(1).first()
        if not story:
            story = MStarredStory.objects.filter(story_feed_id=story_feed_id, 
                                                 story_guid=story_id).limit(1).first()
        
        return story, original_found
        
    def sync_redis(self, r=None):
        if not r:
            r = redis.Redis(connection_pool=settings.REDIS_STORY_POOL)
        DAYS_OF_UNREAD = datetime.datetime.now() - datetime.timedelta(days=settings.DAYS_OF_UNREAD)

        if self.id and self.story_date > DAYS_OF_UNREAD:
            r.sadd('F:%s' % self.story_feed_id, self.id)
            r.zadd('zF:%s' % self.story_feed_id, self.id, time.mktime(self.story_date.timetuple()))
    
    def remove_from_redis(self, r=None):
        if not r:
            r = redis.Redis(connection_pool=settings.REDIS_STORY_POOL)
        if self.id:
            r.srem('F:%s' % self.story_feed_id, self.id)
            r.zrem('zF:%s' % self.story_feed_id, self.id)

    @classmethod
    def sync_all_redis(cls, story_feed_id=None):
        r = redis.Redis(connection_pool=settings.REDIS_STORY_POOL)
        DAYS_OF_UNREAD = datetime.datetime.now() - datetime.timedelta(days=settings.DAYS_OF_UNREAD)
        feed = None
        if story_feed_id:
            feed = Feed.get_by_id(story_feed_id)
        stories = cls.objects.filter(story_date__gte=DAYS_OF_UNREAD)
        if story_feed_id:
            stories = stories.filter(story_feed_id=story_feed_id)
            r.delete('F:%s' % story_feed_id)
            r.delete('zF:%s' % story_feed_id)

        logging.info(" ---> [%-30s] ~FMSyncing ~SB%s~SN stories to redis" % (feed and feed.title[:30] or story_feed_id, stories.count()))
        for story in stories:
            story.sync_redis(r)
        
    def count_comments(self):
        from apps.social.models import MSharedStory
        params = {
            'story_guid': self.story_guid,
            'story_feed_id': self.story_feed_id,
        }
        comments = MSharedStory.objects.filter(has_comments=True, **params).only('user_id')
        shares = MSharedStory.objects.filter(**params).only('user_id')
        self.comment_count = comments.count()
        self.comment_user_ids = [c['user_id'] for c in comments]
        self.share_count = shares.count()
        self.share_user_ids = [s['user_id'] for s in shares]
        self.save()
        

class MStarredStory(mongo.Document):
    """Like MStory, but not inherited due to large overhead of _cls and _type in
       mongoengine's inheritance model on every single row."""
    user_id                  = mongo.IntField(unique_with=('story_guid',))
    starred_date             = mongo.DateTimeField()
    story_feed_id            = mongo.IntField()
    story_date               = mongo.DateTimeField()
    story_title              = mongo.StringField(max_length=1024)
    story_content            = mongo.StringField()
    story_content_z          = mongo.BinaryField()
    story_original_content   = mongo.StringField()
    story_original_content_z = mongo.BinaryField()
    story_content_type       = mongo.StringField(max_length=255)
    story_author_name        = mongo.StringField()
    story_permalink          = mongo.StringField()
    story_guid               = mongo.StringField()
    story_tags               = mongo.ListField(mongo.StringField(max_length=250))

    meta = {
        'collection': 'starred_stories',
        'indexes': [('user_id', '-starred_date'), ('user_id', 'story_feed_id'), 'story_feed_id'],
        'index_drop_dups': True,
        'ordering': ['-starred_date'],
        'allow_inheritance': False,
    }
    
    def save(self, *args, **kwargs):
        if self.story_content:
            self.story_content_z = zlib.compress(self.story_content)
            self.story_content = None
        if self.story_original_content:
            self.story_original_content_z = zlib.compress(self.story_original_content)
            self.story_original_content = None
        super(MStarredStory, self).save(*args, **kwargs)
    
    @property
    def guid_hash(self):
        return hashlib.sha1(self.story_guid).hexdigest()[:6]
    

class MFeedFetchHistory(mongo.Document):
    feed_id = mongo.IntField()
    status_code = mongo.IntField()
    message = mongo.StringField()
    exception = mongo.StringField()
    fetch_date = mongo.DateTimeField()
    
    meta = {
        'collection': 'feed_fetch_history',
        'allow_inheritance': False,
        'ordering': ['-fetch_date'],
        'indexes': ['-fetch_date', ('fetch_date', 'status_code'), ('feed_id', 'status_code')],
    }
    
    def save(self, *args, **kwargs):
        if not isinstance(self.exception, basestring):
            self.exception = unicode(self.exception)
        super(MFeedFetchHistory, self).save(*args, **kwargs)
        
    @classmethod
    def feed_history(cls, feed_id):
        fetches = cls.objects(feed_id=feed_id).order_by('-fetch_date')[:5]
        fetch_history = []
        for fetch in fetches:
            history                = {}
            history['message']     = fetch.message
            history['fetch_date']  = fetch.fetch_date.strftime("%Y-%m-%d %H:%M:%S")
            history['status_code'] = fetch.status_code
            history['exception']   = fetch.exception
            fetch_history.append(history)
        return fetch_history
        
        
class MPageFetchHistory(mongo.Document):
    feed_id = mongo.IntField()
    status_code = mongo.IntField()
    message = mongo.StringField()
    exception = mongo.StringField()
    fetch_date = mongo.DateTimeField()
    
    meta = {
        'collection': 'page_fetch_history',
        'allow_inheritance': False,
        'ordering': ['-fetch_date'],
        'indexes': [('fetch_date', 'status_code'), ('feed_id', 'status_code'), ('feed_id', 'fetch_date')],
    }
    
    def save(self, *args, **kwargs):
        if not isinstance(self.exception, basestring):
            self.exception = unicode(self.exception)
        super(MPageFetchHistory, self).save(*args, **kwargs)

    @classmethod
    def feed_history(cls, feed_id):
        fetches = cls.objects(feed_id=feed_id).order_by('-fetch_date')[:5]
        fetch_history = []
        for fetch in fetches:
            history                = {}
            history['message']     = fetch.message
            history['fetch_date']  = fetch.fetch_date.strftime("%Y-%m-%d %H:%M:%S")
            history['status_code'] = fetch.status_code
            history['exception']   = fetch.exception
            fetch_history.append(history)
        return fetch_history
        
        
class MFeedPushHistory(mongo.Document):
    feed_id = mongo.IntField()
    push_date = mongo.DateTimeField(default=datetime.datetime.now)
    
    meta = {
        'collection': 'feed_push_history',
        'allow_inheritance': False,
        'ordering': ['-push_date'],
        'indexes': ['feed_id', '-push_date'],
    }
    
    @classmethod
    def feed_history(cls, feed_id):
        pushes = cls.objects(feed_id=feed_id).order_by('-push_date')[:5]
        push_history = []
        for push in pushes:
            history = {}
            history['push_date']  = push.push_date.strftime("%Y-%m-%d %H:%M:%S")
            push_history.append(history)
        return push_history
        
        
class DuplicateFeed(models.Model):
    duplicate_address = models.CharField(max_length=255, db_index=True)
    duplicate_link = models.CharField(max_length=255, null=True, db_index=True)
    duplicate_feed_id = models.CharField(max_length=255, null=True, db_index=True)
    feed = models.ForeignKey(Feed, related_name='duplicate_addresses')
   
    def __unicode__(self):
        return "%s: %s / %s" % (self.feed, self.duplicate_address, self.duplicate_link)
        
    def to_json(self):
        return {
            'duplicate_address': self.duplicate_address,
            'duplicate_link': self.duplicate_link,
            'duplicate_feed_id': self.duplicate_feed_id,
            'feed_id': self.feed_id
        }

def merge_feeds(original_feed_id, duplicate_feed_id, force=False):
    from apps.reader.models import UserSubscription
    from apps.social.models import MSharedStory
    
    if original_feed_id == duplicate_feed_id:
        logging.info(" ***> Merging the same feed. Ignoring...")
        return
    if original_feed_id > duplicate_feed_id and not force:
        original_feed_id, duplicate_feed_id = duplicate_feed_id, original_feed_id
    try:
        original_feed = Feed.objects.get(pk=original_feed_id)
        duplicate_feed = Feed.objects.get(pk=duplicate_feed_id)
    except Feed.DoesNotExist:
        logging.info(" ***> Already deleted feed: %s" % duplicate_feed_id)
        return
        
    logging.info(" ---> Feed: [%s - %s] %s - %s" % (original_feed_id, duplicate_feed_id,
                                                    original_feed, original_feed.feed_link))
    logging.info("            ++> %s: %s / %s" % (original_feed.pk, 
                                                  original_feed.feed_address,
                                                  original_feed.feed_link))
    logging.info("            --> %s: %s / %s" % (duplicate_feed.pk,
                                                  duplicate_feed.feed_address,
                                                  duplicate_feed.feed_link))

    user_subs = UserSubscription.objects.filter(feed=duplicate_feed)
    for user_sub in user_subs:
        user_sub.switch_feed(original_feed, duplicate_feed)

    def delete_story_feed(model, feed_field='feed_id'):
        duplicate_stories = model.objects(**{feed_field: duplicate_feed.pk})
        # if duplicate_stories.count():
        #     logging.info(" ---> Deleting %s %s" % (duplicate_stories.count(), model))
        duplicate_stories.delete()
        
    delete_story_feed(MStory, 'story_feed_id')
    delete_story_feed(MFeedPage, 'feed_id')

    try:
        DuplicateFeed.objects.create(
            duplicate_address=duplicate_feed.feed_address,
            duplicate_link=duplicate_feed.feed_link,
            duplicate_feed_id=duplicate_feed.pk,
            feed=original_feed
        )
    except (IntegrityError, OperationError), e:
        logging.info(" ***> Could not save DuplicateFeed: %s" % e)
    
    # Switch this dupe feed's dupe feeds over to the new original.
    duplicate_feeds_duplicate_feeds = DuplicateFeed.objects.filter(feed=duplicate_feed)
    for dupe_feed in duplicate_feeds_duplicate_feeds:
        dupe_feed.feed = original_feed
        dupe_feed.duplicate_feed_id = duplicate_feed.pk
        dupe_feed.save()
    
    logging.debug(' ---> Dupe subscribers: %s, Original subscribers: %s' %
                  (duplicate_feed.num_subscribers, original_feed.num_subscribers))
    duplicate_feed.delete()
    original_feed.count_subscribers()
    logging.debug(' ---> Now original subscribers: %s' %
                  (original_feed.num_subscribers))
    
    MSharedStory.switch_feed(original_feed_id, duplicate_feed_id)
    
def rewrite_folders(folders, original_feed, duplicate_feed):
    new_folders = []
    
    for k, folder in enumerate(folders):
        if isinstance(folder, int):
            if folder == duplicate_feed.pk:
                # logging.info("              ===> Rewrote %s'th item: %s" % (k+1, folders))
                new_folders.append(original_feed.pk)
            else:
                new_folders.append(folder)
        elif isinstance(folder, dict):
            for f_k, f_v in folder.items():
                new_folders.append({f_k: rewrite_folders(f_v, original_feed, duplicate_feed)})

    return new_folders
