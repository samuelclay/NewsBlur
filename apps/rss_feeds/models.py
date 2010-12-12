import difflib
import datetime
import hashlib
import random
import re
import mongoengine as mongo
import pymongo
import zlib
import urllib
from collections import defaultdict
from operator import itemgetter
from BeautifulSoup import BeautifulStoneSoup
from nltk.collocations import TrigramCollocationFinder, BigramCollocationFinder, TrigramAssocMeasures, BigramAssocMeasures
from django.db import models
from django.db import IntegrityError
from django.core.cache import cache
from django.conf import settings
from mongoengine.queryset import OperationError
from utils import json_functions as json
from utils import feedfinder
from utils.feed_functions import levenshtein_distance
from utils.feed_functions import timelimit
from utils.story_functions import pre_process_story
from utils.compressed_textfield import StoryField
from utils.diff import HTMLDiff
from utils import log as logging

ENTRY_NEW, ENTRY_UPDATED, ENTRY_SAME, ENTRY_ERR = range(4)

class Feed(models.Model):
    feed_address = models.URLField(max_length=255, verify_exists=True, unique=True)
    feed_link = models.URLField(max_length=1000, default="", blank=True, null=True)
    feed_title = models.CharField(max_length=255, default="", blank=True, null=True)
    feed_tagline = models.CharField(max_length=1024, default="", blank=True, null=True)
    active = models.BooleanField(default=True)
    num_subscribers = models.IntegerField(default=-1)
    active_subscribers = models.IntegerField(default=-1)
    premium_subscribers = models.IntegerField(default=-1)
    last_update = models.DateTimeField(db_index=True)
    fetched_once = models.BooleanField(default=False)
    has_feed_exception = models.BooleanField(default=False, db_index=True)
    has_page_exception = models.BooleanField(default=False, db_index=True)
    exception_code = models.IntegerField(default=0)
    min_to_decay = models.IntegerField(default=15)
    days_to_trim = models.IntegerField(default=90)
    creation = models.DateField(auto_now_add=True)
    etag = models.CharField(max_length=255, blank=True, null=True)
    last_modified = models.DateTimeField(null=True, blank=True)
    stories_last_month = models.IntegerField(default=0)
    average_stories_per_month = models.IntegerField(default=0)
    story_count_history = models.TextField(blank=True, null=True)
    next_scheduled_update = models.DateTimeField(db_index=True)
    queued_date = models.DateTimeField(db_index=True)
    last_load_time = models.IntegerField(default=0)
    popular_tags = models.CharField(max_length=1024, blank=True, null=True)
    popular_authors = models.CharField(max_length=2048, blank=True, null=True)
    
    
    def __unicode__(self):
        if not self.feed_title:
            self.feed_title = "[Untitled]"
            self.save()
        return self.feed_title

    def save(self, *args, **kwargs):
        if self.feed_tagline and len(self.feed_tagline) > 1024:
            self.feed_tagline = self.feed_tagline[:1024]
        if not self.last_update:
            self.last_update = datetime.datetime.utcnow()
        if not self.next_scheduled_update:
            self.next_scheduled_update = datetime.datetime.utcnow()
        if not self.queued_date:
            self.queued_date = datetime.datetime.utcnow()
        

        try:
            super(Feed, self).save(*args, **kwargs)
        except IntegrityError, e:
            duplicate_feed = Feed.objects.filter(feed_address=self.feed_address)
            logging.debug("%s: %s" % (self.feed_address, duplicate_feed))
            logging.debug(' ***> [%-30s] Feed deleted. Could not save: %s' % (self, e))
            if duplicate_feed:
                merge_feeds(self.pk, duplicate_feed[0].pk)
                return duplicate_feed[0].pk
            # Feed has been deleted. Just ignore it.
            pass
    
    def update_all_statistics(self):
        self.count_subscribers()
        self.count_stories()
        self.save_popular_authors()
        self.save_popular_tags()
    
    def setup_feed_for_premium_subscribers(self):
        self.count_subscribers()
        self.set_next_scheduled_update()
        
    @timelimit(20)
    def check_feed_address_for_feed_link(self):
        feed_address = None

        if not feedfinder.isFeed(self.feed_address):
            feed_address = feedfinder.feed(self.feed_address)
            if not feed_address:
                feed_address = feedfinder.feed(self.feed_link)
        else:
            feed_address_from_link = feedfinder.feed(self.feed_link)
            if feed_address_from_link != self.feed_address:
                feed_address = feed_address_from_link
        
        if feed_address:
            try:
                self.feed_address = feed_address
                self.next_scheduled_update = datetime.datetime.utcnow()
                self.has_feed_exception = False
                self.active = True
                self.save()
            except IntegrityError:
                original_feed = Feed.objects.get(feed_address=feed_address)
                original_feed.has_feed_exception = False
                original_feed.active = True
                original_feed.save()
                merge_feeds(original_feed.pk, self.pk)
        
        return not not feed_address

    def save_feed_history(self, status_code, message, exception=None):
        MFeedFetchHistory(feed_id=self.pk, 
                          status_code=int(status_code),
                          message=message,
                          exception=exception,
                          fetch_date=datetime.datetime.utcnow()).save()
        old_fetch_histories = MFeedFetchHistory.objects(feed_id=self.pk).order_by('-fetch_date')[5:]
        for history in old_fetch_histories:
            history.delete()
        if status_code not in (200, 304):
            fetch_history = map(lambda h: h.status_code, 
                                MFeedFetchHistory.objects(feed_id=self.pk))
            self.count_errors_in_history(fetch_history, status_code, 'feed')
        elif self.has_feed_exception:
            self.has_feed_exception = False
            self.active = True
            self.save()
        
    def save_page_history(self, status_code, message, exception=None):
        MPageFetchHistory(feed_id=self.pk, 
                          status_code=int(status_code),
                          message=message,
                          exception=exception,
                          fetch_date=datetime.datetime.utcnow()).save()
        old_fetch_histories = MPageFetchHistory.objects(feed_id=self.pk).order_by('-fetch_date')[5:]
        for history in old_fetch_histories:
            history.delete()
            
        if status_code not in (200, 304):
            fetch_history = map(lambda h: h.status_code, 
                                MPageFetchHistory.objects(feed_id=self.pk))
            self.count_errors_in_history(fetch_history, status_code, 'page')
        elif self.has_page_exception:
            self.has_page_exception = False
            self.active = True
            self.save()
        
    def count_errors_in_history(self, fetch_history, status_code, exception_type):
        non_errors = [h for h in fetch_history if int(h) in (200, 304)]
        errors = [h for h in fetch_history if int(h) not in (200, 304)]

        if len(non_errors) == 0 and len(errors) >= 1:
            if exception_type == 'feed':
                self.has_feed_exception = True
                self.active = False
            elif exception_type == 'page':
                self.has_page_exception = True
            self.exception_code = status_code
            self.save()
        elif self.exception_code > 0:
            self.active = True
            self.exception_code = 0
            self.save()
    
    def count_subscribers(self, verbose=False):
        SUBSCRIBER_EXPIRE = datetime.datetime.now() - datetime.timedelta(days=settings.SUBSCRIBER_EXPIRE)
        from apps.reader.models import UserSubscription
        
        subs = UserSubscription.objects.filter(feed=self)
        self.num_subscribers = subs.count()
        
        active_subs = UserSubscription.objects.filter(
            feed=self, 
            active=True,
            user__profile__last_seen_on__gte=SUBSCRIBER_EXPIRE
        )
        self.active_subscribers = active_subs.count()
        
        premium_subs = UserSubscription.objects.filter(
            feed=self, 
            active=True,
            user__profile__is_premium=True
        )
        self.premium_subscribers = premium_subs.count()
        
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
            current_counts = self.story_count_history and json.decode(self.story_count_history)
        
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
        res = MStory.objects(story_feed_id=self.pk).map_reduce(map_f, reduce_f, keep_temp=False)
        for r in res:
            dates[r.key] = r.value
                
        # Add on to existing months, always amending up, never down. (Current month
        # is guaranteed to be accurate, since trim_feeds won't delete it until after
        # a month. Hacker News can have 1,000+ and still be counted.)
        for current_month, current_count in current_counts:
            if current_month not in dates or dates[current_month] < current_count:
                dates[current_month] = current_count
                year = int(re.findall(r"(\d{4})-\d{1,2}", current_month)[0])
                if year < min_year:
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
        
        self.story_count_history = json.encode(months)
        if not total:
            self.average_stories_per_month = 0
        else:
            self.average_stories_per_month = total / month_count
        self.save()
        
        
    def update(self, force=False, single_threaded=True, compute_scores=True):
        from utils import feed_fetcher
        try:
            self.feed_address = self.feed_address % {'NEWSBLUR_DIR': settings.NEWSBLUR_DIR}
        except:
            pass
        
        self.set_next_scheduled_update()
        
        options = {
            'verbose': 1 if not force else 2,
            'timeout': 10,
            'single_threaded': single_threaded,
            'force': force,
            'compute_scores': compute_scores,
        }
        disp = feed_fetcher.Dispatcher(options, 1)        
        disp.add_jobs([[self.pk]])
        disp.run_jobs()

    def add_update_stories(self, stories, existing_stories):
        ret_values = {
            ENTRY_NEW:0,
            ENTRY_UPDATED:0,
            ENTRY_SAME:0,
            ENTRY_ERR:0
        }
        
        for story in stories:
            story = pre_process_story(story)
            
            if story.get('title'):
                story_contents = story.get('content')
                story_tags = self.get_tags(story)
                
                if story_contents is not None:
                    story_content = story_contents[0]['value']
                else:
                    story_content = story.get('summary')
                    
                existing_story, story_has_changed = self._exists_story(story, story_content, existing_stories)
                if existing_story is None:
                    s = MStory(story_feed_id = self.pk,
                           story_date = story.get('published'),
                           story_title = story.get('title'),
                           story_content = story_content,
                           story_author_name = story.get('author'),
                           story_permalink = story.get('link'),
                           story_guid = story.get('guid') or story.get('id') or story.get('link'),
                           story_tags = story_tags
                    )
                    try:
                        s.save()
                        ret_values[ENTRY_NEW] += 1
                        cache.set('updated_feed:%s' % self.id, 1)
                    except (IntegrityError, OperationError):
                        ret_values[ENTRY_ERR] += 1
                        # print('Saving new story, IntegrityError: %s - %s: %s' % (self.feed_title, story.get('title'), e))
                elif existing_story and story_has_changed:
                    # update story
                    # logging.debug('- Updated story in feed (%s - %s): %s / %s' % (self.feed_title, story.get('title'), len(existing_story.story_content), len(story_content)))
                
                    original_content = None
                    if existing_story.get('story_original_content_z'):
                        original_content = zlib.decompress(existing_story.get('story_original_content_z'))
                    elif existing_story.get('story_content_z'):
                        original_content = zlib.decompress(existing_story.get('story_content_z'))
                    # print 'Type: %s %s' % (type(original_content), type(story_content))
                    if story_content and len(story_content) > 10:
                        diff = HTMLDiff(unicode(original_content), story_content)
                        story_content_diff = diff.getDiff()
                    else:
                        story_content_diff = original_content
                    # logging.debug("\t\tDiff: %s %s %s" % diff.getStats())
                    # logging.debug("\t\tDiff content: %s" % diff.getDiff())
                    if existing_story.get('story_title') != story.get('title'):
                        # logging.debug('\tExisting title / New: : \n\t\t- %s\n\t\t- %s' % (existing_story.story_title, story.get('title')))
                        pass

                    existing_story['story_feed'] = self.pk
                    existing_story['story_date'] = story.get('published')
                    existing_story['story_title'] = story.get('title')
                    existing_story['story_content'] = story_content_diff
                    existing_story['story_original_content'] = original_content
                    existing_story['story_author_name'] = story.get('author')
                    existing_story['story_permalink'] = story.get('link')
                    existing_story['story_guid'] = story.get('guid') or story.get('id') or story.get('link')
                    existing_story['story_tags'] = story_tags
                    try:
                        settings.MONGODB.stories.update({'_id': existing_story['_id']}, existing_story)
                        ret_values[ENTRY_UPDATED] += 1
                        cache.set('updated_feed:%s' % self.id, 1)
                    except (IntegrityError, OperationError):
                        ret_values[ENTRY_ERR] += 1
                        # print('Saving updated story, IntegrityError: %s - %s' % (self.feed_title, story.get('title')))
                else:
                    ret_values[ENTRY_SAME] += 1
                    # logging.debug("Unchanged story: %s " % story.get('title'))
            
        return ret_values
        
    def save_popular_tags(self, feed_tags=None):
        if not feed_tags:
            try:
                all_tags = MStory.objects(story_feed_id=self.pk, story_tags__exists=True).item_frequencies('story_tags')
            except pymongo.errors.OperationFailure, err:
                print "Mongo Error on statistics: %s" % err
                return
            feed_tags = sorted([(k, v) for k, v in all_tags.items() if isinstance(v, float) and int(v) > 1], 
                               key=itemgetter(1), 
                               reverse=True)[:20]
        popular_tags = json.encode(feed_tags)
        
        # TODO: This len() bullshit will be gone when feeds move to mongo
        #       On second thought, it might stay, because we don't want
        #       popular tags the size of a small planet. I'm looking at you
        #       Tumblr writers.
        if len(popular_tags) < 1024:
            self.popular_tags = popular_tags
            self.save()
            return

        tags_list = json.decode(feed_tags) if feed_tags else []
        if len(tags_list) > 1:
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
        if len(popular_authors) < 1024:
            self.popular_authors = popular_authors
            self.save()
            return

        if len(feed_authors) > 1:
            self.save_popular_authors(feed_authors=feed_authors[:-1])
            
    def trim_feed(self):
        from apps.reader.models import MUserStory
        trim_cutoff = 500
        if self.active_subscribers <= 1:
            trim_cutoff = 50
        elif self.active_subscribers <= 3:
            trim_cutoff = 100
        elif self.active_subscribers <= 5:
            trim_cutoff = 150
        elif self.active_subscribers <= 10:
            trim_cutoff = 250
        elif self.active_subscribers <= 25:
            trim_cutoff = 350
        stories = MStory.objects(
            story_feed_id=self.pk,
        ).order_by('-story_date')
        if stories.count() > trim_cutoff:
            # print 'Found %s stories in %s. Trimming...' % (stories.count(), self),
            story_trim_date = stories[trim_cutoff].story_date
            extra_stories = MStory.objects(story_feed_id=self.pk, story_date__lte=story_trim_date)
            extra_stories.delete()
            # print "Deleted stories, %s left." % MStory.objects(story_feed_id=self.pk).count()
            userstories = MUserStory.objects(feed_id=self.pk, read_date__lte=story_trim_date)
            if userstories.count():
                # print "Found %s user stories. Deleting..." % userstories.count()
                userstories.delete()
        
    def get_stories(self, offset=0, limit=25, force=False):
        stories = cache.get('feed_stories:%s-%s-%s' % (self.id, offset, limit), [])
        
        if not stories or force:
            stories_db = MStory.objects(story_feed_id=self.pk)[offset:offset+limit]
            stories = Feed.format_stories(stories_db, self.pk)
            cache.set('feed_stories:%s-%s-%s' % (self.id, offset, limit), stories)
        
        return stories
    
    @classmethod
    def format_stories(cls, stories_db, feed_id=None):
        stories = []

        for story_db in stories_db:
            story = {}
            story['story_tags'] = story_db.story_tags or []
            story['story_date'] = story_db.story_date
            story['story_authors'] = story_db.story_author_name
            story['story_title'] = story_db.story_title
            story['story_content'] = story_db.story_content_z and zlib.decompress(story_db.story_content_z)
            story['story_permalink'] = urllib.unquote(urllib.unquote(story_db.story_permalink))
            story['story_feed_id'] = feed_id or story_db.story_feed_id
            story['id'] = story_db.story_guid
            if hasattr(story_db, 'starred_date'):
                story['starred_date'] = story_db.starred_date
            
            stories.append(story)
            
        return stories
        
    def get_tags(self, entry):
        fcat = []
        if entry.has_key('tags'):
            for tcat in entry.tags:
                if tcat.label:
                    term = tcat.label
                elif tcat.term:
                    term = tcat.term
                else:
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
        return fcat

    def _exists_story(self, story=None, story_content=None, existing_stories=None):
        story_in_system = None
        story_has_changed = False
        story_pub_date = story.get('published')
        story_published_now = story.get('published_now', False)
        start_date = story_pub_date - datetime.timedelta(hours=8)
        end_date = story_pub_date + datetime.timedelta(hours=8)
        existing_stories.rewind()
        
        for existing_story in existing_stories:
            content_ratio = 0
            existing_story_pub_date = existing_story['story_date']
            # print 'Story pub date: %s %s' % (story_published_now, story_pub_date)
            if (story_published_now or
                (existing_story_pub_date > start_date and existing_story_pub_date < end_date)):
                if isinstance(existing_story['_id'], unicode):
                    existing_story['story_guid'] = existing_story['_id']
                if story.get('guid') and story.get('guid') == existing_story['story_guid']:
                    story_in_system = existing_story
                elif story.get('link') and story.get('link') == existing_story['story_permalink']:
                    story_in_system = existing_story
                
                # Title distance + content distance, checking if story changed
                story_title_difference = levenshtein_distance(story.get('title'),
                                                              existing_story['story_title'])
                if 'story_content_z' in existing_story:
                    existing_story_content = unicode(zlib.decompress(existing_story['story_content_z']))
                elif 'story_content' in existing_story:
                    existing_story_content = existing_story['story_content']
                else:
                    existing_story_content = u''
                
                seq = difflib.SequenceMatcher(None, story_content, existing_story_content)
                
                if (seq
                    and story_content
                    and existing_story_content
                    and seq.real_quick_ratio() > .9 
                    and seq.quick_ratio() > .95):
                    content_ratio = seq.ratio()
                    
                if story_title_difference > 0 and story_title_difference < 5 and content_ratio > .98:
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
                                        
                if story_in_system:
                    if story_content != existing_story_content:
                        story_has_changed = True
                    break
        
        # if story_has_changed or not story_in_system:
            # print 'New/updated story: %s' % (story), 
        return story_in_system, story_has_changed
        
    def get_next_scheduled_update(self):
        # Use stories per month to calculate next feed update
        updates_per_day = self.stories_last_month / 30.0
        # if updates_per_day < 1 and self.num_subscribers > 2:
        #     updates_per_day = 1
        # 0 updates per day = 24 hours
        # 1 subscriber:
        #   1 update per day = 6 hours
        #   2 updates = 3.5 hours
        #   4 updates = 2 hours
        #   10 updates = 1 hour
        # 2 subscribers:
        #   1 update per day = 4.5 hours
        #   10 updates = 55 minutes
        updates_per_day_delay = 6 * 60 / max(.25, ((max(0, self.num_subscribers)**.20) 
                                                   * (updates_per_day**.70)))
        if self.premium_subscribers > 0:
            updates_per_day_delay = updates_per_day_delay / 4
        # Lots of subscribers = lots of updates
        # 144 hours for 0 subscribers.
        # 24 hours for 1 subscriber.
        # 7 hours for 2 subscribers.
        # 3 hours for 3 subscribers.
        # 25 min for 10 subscribers.
        subscriber_bonus = 24 * 60 / max(.167, max(0, self.num_subscribers)**1.35)
        if self.premium_subscribers > 0:
            subscriber_bonus = subscriber_bonus / 4
        
        slow_punishment = 0
        if self.num_subscribers <= 1:
            if 30 <= self.last_load_time < 60:
                slow_punishment = self.last_load_time
            elif 60 <= self.last_load_time < 200:
                slow_punishment = 2 * self.last_load_time
            elif self.last_load_time >= 200:
                slow_punishment = 6 * self.last_load_time
        total = max(6, int(updates_per_day_delay + subscriber_bonus + slow_punishment))
        # print "[%s] %s (%s-%s), %s, %s: %s" % (self, updates_per_day_delay, updates_per_day, self.num_subscribers, subscriber_bonus, slow_punishment, total)
        random_factor = random.randint(0, total) / 4
        
        return total, random_factor
        
    def set_next_scheduled_update(self):
        total, random_factor = self.get_next_scheduled_update()

        next_scheduled_update = datetime.datetime.utcnow() + datetime.timedelta(
                                minutes = total + random_factor)
            
        self.next_scheduled_update = next_scheduled_update

        self.save()

    def schedule_feed_fetch_immediately(self):
        self.next_scheduled_update = datetime.datetime.utcnow()

        self.save()
        
    def calculate_collocations_story_content(self,
                                             collocation_measures=TrigramAssocMeasures,
                                             collocation_finder=TrigramCollocationFinder):
        stories = MStory.objects.filter(story_feed_id=self.pk)
        story_content = ' '.join([s.story_content for s in stories if s.story_content])
        return self.calculate_collocations(story_content, collocation_measures, collocation_finder)
        
    def calculate_collocations_story_title(self,
                                           collocation_measures=BigramAssocMeasures,
                                           collocation_finder=BigramCollocationFinder):
        stories = MStory.objects.filter(story_feed_id=self.pk)
        story_titles = ' '.join([s.story_title for s in stories if s.story_title])
        return self.calculate_collocations(story_titles, collocation_measures, collocation_finder)
    
    def calculate_collocations(self, content,
                               collocation_measures=TrigramAssocMeasures,
                               collocation_finder=TrigramCollocationFinder):
        content = re.sub(r'&#8217;', '\'', content)
        content = re.sub(r'&amp;', '&', content)
        try:
            content = unicode(BeautifulStoneSoup(content,
                              convertEntities=BeautifulStoneSoup.HTML_ENTITIES))
        except ValueError, e:
            print "ValueError, ignoring: %s" % e
        content = re.sub(r'</?\w+\s+[^>]*>', '', content)
        content = re.split(r"[^A-Za-z-'&]+", content)

        finder = collocation_finder.from_words(content)
        finder.apply_freq_filter(3)
        best = finder.nbest(collocation_measures.pmi, 10)
        phrases = [' '.join(phrase) for phrase in best]
        
        return phrases
        
    class Meta:
        db_table="feeds"
        ordering=["feed_title"]

# class FeedCollocations(models.Model):
#     feed = models.ForeignKey(Feed)
#     phrase = models.CharField(max_length=500)
        
class Tag(models.Model):
    feed = models.ForeignKey(Feed)
    name = models.CharField(max_length=255)

    def __unicode__(self):
        return '%s - %s' % (self.feed, self.name)
    
    def save(self):
        super(Tag, self).save()
        
class StoryAuthor(models.Model):
    feed = models.ForeignKey(Feed)
    author_name = models.CharField(max_length=255, null=True, blank=True)
        
    def __unicode__(self):
        return '%s - %s' % (self.feed, self.author_name)

class FeedPage(models.Model):
    feed = models.OneToOneField(Feed, related_name="feed_page")
    page_data = StoryField(null=True, blank=True)
    
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

class FeedXML(models.Model):
    feed = models.OneToOneField(Feed, related_name="feed_xml")
    rss_xml = StoryField(null=True, blank=True)
    
class Story(models.Model):
    '''A feed item'''
    story_feed = models.ForeignKey(Feed, related_name="stories")
    story_date = models.DateTimeField()
    story_title = models.CharField(max_length=255)
    story_content = StoryField(null=True, blank=True)
    story_original_content = StoryField(null=True, blank=True)
    story_content_type = models.CharField(max_length=255, null=True,
                                          blank=True)
    story_author = models.ForeignKey(StoryAuthor)
    story_author_name = models.CharField(max_length=500, null=True, blank=True)
    story_permalink = models.CharField(max_length=1000)
    story_guid = models.CharField(max_length=1000)
    story_guid_hash = models.CharField(max_length=40)
    story_past_trim_date = models.BooleanField(default=False)
    story_tags = models.CharField(max_length=2000, null=True, blank=True)

    def __unicode__(self):
        return self.story_title

    class Meta:
        verbose_name_plural = "stories"
        verbose_name = "story"
        db_table="stories"
        ordering=["-story_date"]
        unique_together = (("story_feed", "story_guid_hash"),)

    def save(self, *args, **kwargs):
        if not self.story_guid_hash and self.story_guid:
            self.story_guid_hash = hashlib.md5(self.story_guid).hexdigest()
        if len(self.story_title) > self._meta.get_field('story_title').max_length:
            self.story_title = self.story_title[:255]
        super(Story, self).save(*args, **kwargs)
        
        
class MStory(mongo.Document):
    '''A feed item'''
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
        'collection': 'stories',
        'indexes': ['story_date', ('story_feed_id', '-story_date')],
        'ordering': ['-story_date'],
        'allow_inheritance': False,
    }
    
    def save(self, *args, **kwargs):
        if self.story_content:
            self.story_content_z = zlib.compress(self.story_content)
            self.story_content = None
        if self.story_original_content:
            self.story_original_content_z = zlib.compress(self.story_original_content)
            self.story_original_content = None
        super(MStory, self).save(*args, **kwargs)


class MStarredStory(mongo.Document):
    """Like MStory, but not inherited due to large overhead of _cls and _type in
       mongoengine's inheritance model on every single row."""
    user_id                  = mongo.IntField()
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
    story_guid               = mongo.StringField(unique_with=('user_id',))
    story_tags               = mongo.ListField(mongo.StringField(max_length=250))

    meta = {
        'collection': 'starred_stories',
        'indexes': [('user_id', '-starred_date'), 'story_feed_id'],
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
    
    
class FeedUpdateHistory(models.Model):
    fetch_date = models.DateTimeField(auto_now=True)
    number_of_feeds = models.IntegerField()
    seconds_taken = models.IntegerField()
    average_per_feed = models.DecimalField(decimal_places=1, max_digits=4)
    
    def __unicode__(self):
        return "[%s] %s feeds: %s seconds" % (
            self.fetch_date.strftime('%F %d'),
            self.number_of_feeds,
            self.seconds_taken,
        )
    
    def save(self, *args, **kwargs):
        self.average_per_feed = str(self.seconds_taken / float(max(1.0,self.number_of_feeds)))
        super(FeedUpdateHistory, self).save(*args, **kwargs)


class FeedFetchHistory(models.Model):
    feed = models.ForeignKey(Feed, related_name='feed_fetch_history')
    status_code = models.CharField(max_length=10, null=True, blank=True)
    message = models.CharField(max_length=255, null=True, blank=True)
    exception = models.TextField(null=True, blank=True)
    fetch_date = models.DateTimeField(auto_now=True)
    
    def __unicode__(self):
        return "[%s] %s (%s): %s %s: %s" % (
            self.feed.id,
            self.feed,
            self.fetch_date,
            self.status_code,
            self.message,
            self.exception and self.exception[:50]
        )
        
        
class MFeedFetchHistory(mongo.Document):
    feed_id = mongo.IntField()
    status_code = mongo.IntField()
    message = mongo.StringField()
    exception = mongo.StringField()
    fetch_date = mongo.DateTimeField()
    
    meta = {
        'collection': 'feed_fetch_history',
        'allow_inheritance': False,
        'indexes': [('fetch_date', 'status_code'), ('feed_id', 'status_code'), ('feed_id', 'fetch_date')],
    }
    
    def save(self, *args, **kwargs):
        if not isinstance(self.exception, basestring):
            self.exception = unicode(self.exception)
        super(MFeedFetchHistory, self).save(*args, **kwargs)
        
        
class PageFetchHistory(models.Model):
    feed = models.ForeignKey(Feed, related_name='page_fetch_history')
    status_code = models.CharField(max_length=10, null=True, blank=True)
    message = models.CharField(max_length=255, null=True, blank=True)
    exception = models.TextField(null=True, blank=True)
    fetch_date = models.DateTimeField(auto_now=True)
    
    def __unicode__(self):
        return "[%s] %s (%s): %s %s: %s" % (
            self.feed.id,
            self.feed,
            self.fetch_date,
            self.status_code,
            self.message,
            self.exception and self.exception[:50]
        )
        
        
class MPageFetchHistory(mongo.Document):
    feed_id = mongo.IntField()
    status_code = mongo.IntField()
    message = mongo.StringField()
    exception = mongo.StringField()
    fetch_date = mongo.DateTimeField()
    
    meta = {
        'collection': 'page_fetch_history',
        'allow_inheritance': False,
        'indexes': [('fetch_date', 'status_code'), ('feed_id', 'status_code'), ('feed_id', 'fetch_date')],
    }
    
    def save(self, *args, **kwargs):
        if not isinstance(self.exception, basestring):
            self.exception = unicode(self.exception)
        super(MPageFetchHistory, self).save(*args, **kwargs)


class FeedLoadtime(models.Model):
    feed = models.ForeignKey(Feed)
    date_accessed = models.DateTimeField(auto_now=True)
    loadtime = models.FloatField()
    
    def __unicode__(self):
        return "%s: %s sec" % (self.feed, self.loadtime)
    
class DuplicateFeed(models.Model):
    duplicate_address = models.CharField(max_length=255, unique=True)
    duplicate_feed_id = models.CharField(max_length=255, null=True)
    feed = models.ForeignKey(Feed, related_name='duplicate_addresses')

def merge_feeds(original_feed_id, duplicate_feed_id):
    from apps.reader.models import UserSubscription, UserSubscriptionFolders, MUserStory
    from apps.analyzer.models import MClassifierTitle, MClassifierAuthor, MClassifierFeed, MClassifierTag
    if original_feed_id > duplicate_feed_id:
        original_feed_id, duplicate_feed_id = duplicate_feed_id, original_feed_id
    try:
        original_feed = Feed.objects.get(pk=original_feed_id)
        duplicate_feed = Feed.objects.get(pk=duplicate_feed_id)
    except Feed.DoesNotExist:
        logging.info(" ***> Already deleted feed: %s" % duplicate_feed_id)
        return
        
    logging.info(" ---> Feed: [%s - %s] %s - %s" % (original_feed_id, duplicate_feed_id,
                                             original_feed, original_feed.feed_link))
    logging.info("            --> %s" % original_feed.feed_address)
    logging.info("            --> %s" % duplicate_feed.feed_address)

    user_subs = UserSubscription.objects.filter(feed=duplicate_feed)
    for user_sub in user_subs:
        # Rewrite feed in subscription folders
        try:
            user_sub_folders = UserSubscriptionFolders.objects.get(user=user_sub.user)
        except Exception, e:
            logging.info(" *** ---> UserSubscriptionFolders error: %s" % e)
            continue
    
        # Switch to original feed for the user subscription
        logging.info("      ===> %s " % user_sub.user)
        user_sub.feed = original_feed
        user_sub.needs_unread_recalc = True
        try:
            user_sub.save()
            folders = json.decode(user_sub_folders.folders)
            folders = rewrite_folders(folders, original_feed, duplicate_feed)
            user_sub_folders.folders = json.encode(folders)
            user_sub_folders.save()
        except (IntegrityError, OperationError):
            logging.info("      !!!!> %s already subscribed" % user_sub.user)
            user_sub.delete()

    # Switch read stories
    user_stories = MUserStory.objects(feed_id=duplicate_feed.pk)
    logging.info(" ---> %s read stories" % user_stories.count())
    for user_story in user_stories:
        user_story.feed_id = original_feed.pk
        duplicate_story = user_story.story
        story_guid = duplicate_story.story_guid if hasattr(duplicate_story, 'story_guid') else duplicate_story.id
        original_story = MStory.objects(story_feed_id=original_feed.pk,
                                        story_guid=story_guid)
        
        if original_story:
            user_story.story = original_story[0]
            try:
                user_story.save()
            except OperationError:
                # User read the story in the original feed, too. Ugh, just ignore it.
                pass
        else:
            logging.info(" ***> Can't find original story: %s" % duplicate_story.id)
            user_story.delete()

    def delete_story_feed(model, feed_field='feed_id'):
        duplicate_stories = model.objects(**{feed_field: duplicate_feed.pk})
        # if duplicate_stories.count():
        #     logging.info(" ---> Deleting %s %s" % (duplicate_stories.count(), model))
        duplicate_stories.delete()
        
    def switch_feed(model):
        duplicates = model.objects(feed_id=duplicate_feed.pk)
        if duplicates.count():
            logging.info(" ---> Switching %s %s" % (duplicates.count(), model))
        for duplicate in duplicates:
            duplicate.feed_id = original_feed.pk
            try:
                duplicate.save()
                pass
            except (IntegrityError, OperationError):
                logging.info("      !!!!> %s already exists" % duplicate)
                duplicate.delete()
        
    delete_story_feed(MStory, 'story_feed_id')
    switch_feed(MClassifierTitle)
    switch_feed(MClassifierAuthor)
    switch_feed(MClassifierFeed)
    switch_feed(MClassifierTag)

    try:
        DuplicateFeed.objects.create(
            duplicate_address=duplicate_feed.feed_address,
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
        
    duplicate_feed.delete()
    
                    
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