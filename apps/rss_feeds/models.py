import time
import settings
import difflib
import datetime
import hashlib
import random
import re
from collections import defaultdict
from BeautifulSoup import BeautifulStoneSoup
from nltk.collocations import TrigramCollocationFinder, BigramCollocationFinder, TrigramAssocMeasures, BigramAssocMeasures
from django.db import models
from django.db import IntegrityError
from django.core.cache import cache
from utils import json
from utils.feed_functions import levenshtein_distance
from utils.story_functions import format_story_link_date__short
from utils.story_functions import format_story_link_date__long
from utils.story_functions import pre_process_story
from utils.compressed_textfield import CompressedTextField, StoryField
from utils.diff import HTMLDiff

USER_AGENT = 'NewsBlur v1.0 - newsblur.com'

ENTRY_NEW, ENTRY_UPDATED, ENTRY_SAME, ENTRY_ERR = range(4)

class Feed(models.Model):
    feed_address = models.URLField(max_length=255, verify_exists=True, unique=True)
    feed_link = models.URLField(max_length=1000, default="", blank=True, null=True)
    feed_title = models.CharField(max_length=255, default="", blank=True, null=True)
    feed_tagline = models.CharField(max_length=1024, default="", blank=True, null=True)
    active = models.BooleanField(default=True)
    num_subscribers = models.IntegerField(default=0)
    last_update = models.DateTimeField(auto_now=True)
    fetched_once = models.BooleanField(default=False)
    has_exception = models.BooleanField(default=False)
    min_to_decay = models.IntegerField(default=15)
    days_to_trim = models.IntegerField(default=90)
    creation = models.DateField(auto_now_add=True)
    etag = models.CharField(max_length=50, blank=True, null=True)
    last_modified = models.DateTimeField(null=True, blank=True)
    stories_last_month = models.IntegerField(default=0)
    average_stories_per_month = models.IntegerField(default=0)
    story_count_history = models.TextField(blank=True, null=True)
    next_scheduled_update = models.DateTimeField(default=datetime.datetime.now)
    last_load_time = models.IntegerField(default=0)
    popular_tags = models.CharField(max_length=1024, blank=True, null=True)
    popular_authors = models.CharField(max_length=2048, blank=True, null=True)
    
    
    def __unicode__(self):
        return self.feed_title

    def save(self, lock=None, *args, **kwargs):
        if self.feed_tagline and len(self.feed_tagline) > 1024:
            self.feed_tagline = self.feed_tagline[:1024]
            
        if lock:
            lock.acquire()
            try:
                super(Feed, self).save(*args, **kwargs)
            finally:
                lock.release()
        else:
            super(Feed, self).save(*args, **kwargs)
        
    def save_feed_history(self, status_code, message, exception=None):
        FeedFetchHistory.objects.create(feed=self, 
                                        status_code=status_code,
                                        message=message,
                                        exception=exception)
        old_fetch_histories = self.feed_fetch_history.all()[10:]
        for history in old_fetch_histories:
            history.delete()
            
        if status_code >= 400:
            fetch_history = self.feed_fetch_history.all().values('status_code')
            self.count_errors_in_history(fetch_history)
        
    def save_page_history(self, status_code, message, exception=None):
        PageFetchHistory.objects.create(feed=self, 
                                        status_code=status_code,
                                        message=message,
                                        exception=exception)
        old_fetch_histories = self.page_fetch_history.all()[10:]
        for history in old_fetch_histories:
            history.delete()
            
        if status_code >= 400:
            fetch_history = self.page_fetch_history.all().values('status_code')
            self.count_errors_in_history(fetch_history)
        
    def count_errors_in_history(self, fetch_history):
        non_errors = [h for h in fetch_history if int(h['status_code']) < 400]
        errors = [h for h in fetch_history if int(h['status_code']) >= 400]

        if len(non_errors) == 0 and len(errors) >= 1:
            self.has_exception = True
            self.active = False
            self.save()
    
    def count_subscribers(self, verbose=False, lock=None):
        from apps.reader.models import UserSubscription
        subs = UserSubscription.objects.filter(feed=self)
        self.num_subscribers = subs.count()

        self.save(lock=lock)
        
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

    def count_stories(self, verbose=False, lock=None):
        month_ago = datetime.datetime.now() - datetime.timedelta(days=30)
        stories_last_month = Story.objects.filter(story_feed=self, story_date__gte=month_ago).count()
        self.stories_last_month = stories_last_month
        
        self.recount_feed(lock)
        
        self.save(lock=lock)
            
        if verbose:
            print "  ---> %s [%s]: %s stories" % (self.feed_title, self.pk, self.stories_last_month)
    
    def recount_feed(self, lock=None):
        """
        Fills in missing months between earlier occurances and now.
        
        Save format: [('YYYY-MM, #), ...]
        Example output: [(2010-12, 123), (2011-01, 146)]
        """
        d = defaultdict(int)
        now = datetime.datetime.now()
        min_year = now.year
        total = 0
        month_count = 0
        current_counts = self.story_count_history and json.decode(self.story_count_history)
        
        if not current_counts:
            current_counts = []
        
        # Count stories, aggregate by year and month
        stories = Story.objects.filter(story_feed=self).extra(select={
            'year': "EXTRACT(year FROM story_date)", 
            'month': "EXTRACT(month from story_date)"
        }).values('year', 'month')
        for story in stories:
            year = int(story['year'])
            d['%s-%s' % (year, int(story['month']))] += 1
            if year < min_year:
                min_year = year
        
        # Add on to existing months, always amending up, never down. (Current month
        # is guaranteed to be accurate, since trim_feeds won't delete it until after
        # a month. Hacker News can have 1,000+ and still be counted.)
        for current_month, current_count in current_counts:
            if current_month not in d or d[current_month] < current_count:
                d[current_month] = current_count
                year = re.findall(r"(\d{4})-\d{1,2}", current_month)[0]
                if year < min_year:
                    min_year = year
                    
        # Assemble a list with 0's filled in for missing months, 
        # trimming left and right 0's.
        months = []
        start = False
        for year in range(min_year, now.year+1):
            for month in range(1, 12+1):
                if datetime.datetime(year, month, 1) < now:
                    key = '%s-%s' % (year, month)
                    if d.get(key) or start:
                        start = True
                        months.append((key, d.get(key, 0)))
                        total += d.get(key, 0)
                        month_count += 1
        
        self.story_count_history = json.encode(months)
        if not total:
            self.average_stories_per_month = 0
        else:
            self.average_stories_per_month = total / month_count
        self.save(lock)
        
        
    def last_updated(self):
        return time.time() - time.mktime(self.last_update.timetuple())
    
    def new_stories_since_date(self, date):
        stories = Story.objects.filter(story_date__gte=date,
                                       story_feed=self)
        return stories
        
    def add_feed(self, feed_address, feed_link, feed_title):
        print locals()
        
    def update(self, force=False, feed=None, single_threaded=False):
        from utils import feed_fetcher
        try:
            self.feed_address = self.feed_address % {'NEWSBLUR_DIR': settings.NEWSBLUR_DIR}
        except:
            pass
        
        options = {
            'verbose': 2,
            'timeout': 10,
            'single_threaded': single_threaded,
            'force': force,
        }
        disp = feed_fetcher.Dispatcher(options, 1)        
        disp.add_jobs([[self]])
        disp.run_jobs()
        disp.poll()

        return

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
                story_author, _ = self._save_story_author(story.get('author'))
                if existing_story is None:
                    # pub_date = datetime.datetime.timetuple(story.get('published'))
                    # logging.debug('- New story: %s %s' % (pub_date, story.get('title')))
                    
                    s = Story(story_feed = self,
                           story_date = story.get('published'),
                           story_title = story.get('title'),
                           story_content = story_content,
                           story_author = story_author,
                           story_author_name = story.get('author'),
                           story_permalink = story.get('link'),
                           story_guid = story.get('guid') or story.get('id') or story.get('link'),
                           story_tags = self._shorten_story_tags(story_tags)
                    )
                    try:
                        s.save(force_insert=True)
                        ret_values[ENTRY_NEW] += 1
                        cache.set('updated_feed:%s' % self.id, 1)
                    except IntegrityError:
                        ret_values[ENTRY_ERR] += 1
                        # print('Saving new story, IntegrityError: %s - %s: %s' % (self.feed_title, story.get('title'), e))
                    [s.tags.add(tcat) for tcat in story_tags]
                elif existing_story and story_has_changed:
                    # update story
                    # logging.debug('- Updated story in feed (%s - %s): %s / %s' % (self.feed_title, story.get('title'), len(existing_story.story_content), len(story_content)))
                
                    original_content = None
                    if existing_story.story_original_content:
                        original_content = existing_story.story_original_content
                    else:
                        original_content = existing_story.story_content
                    # print 'Type: %s %s' % (type(original_content), type(story_content))
                    if len(story_content) > 10:
                        diff = HTMLDiff(unicode(original_content), story_content)
                        story_content_diff = diff.getDiff()
                    else:
                        story_content_diff = original_content
                    # logging.debug("\t\tDiff: %s %s %s" % diff.getStats())
                    # logging.debug("\t\tDiff content: %s" % diff.getDiff())
                    if existing_story.story_title != story.get('title'):
                        # logging.debug('\tExisting title / New: : \n\t\t- %s\n\t\t- %s' % (existing_story.story_title, story.get('title')))
                        pass

                    s = Story(id = existing_story.id,
                           story_feed = self,
                           story_date = story.get('published'),
                           story_title = story.get('title'),
                           story_content = story_content_diff,
                           story_original_content = original_content,
                           story_author = story_author,
                           story_author_name = story.get('author'),
                           story_permalink = story.get('link'),
                           story_guid = story.get('guid') or story.get('id') or story.get('link'),
                           story_tags = self._shorten_story_tags(story_tags)
                    )
                    s.tags.clear()
                    [s.tags.add(tcat) for tcat in story_tags]
                    try:
                        s.save(force_update=True)
                        ret_values[ENTRY_UPDATED] += 1
                        cache.set('updated_feed:%s' % self.id, 1)
                    except IntegrityError:
                        ret_values[ENTRY_ERR] += 1
                        # print('Saving updated story, IntegrityError: %s - %s' % (self.feed_title, story.get('title')))
                else:
                    ret_values[ENTRY_SAME] += 1
                    # logging.debug("Unchanged story: %s " % story.get('title'))
            
        return ret_values
        
    def _save_story_author(self, author):
        author, created = StoryAuthor.objects.get_or_create(feed=self, author_name=author)
        return author, created
    
    def save_popular_tags(self, feed_tags=None, lock=None):
        if not feed_tags:
            from apps.rss_feeds.models import Tag
            from django.db.models.aggregates import Count
            all_tags = Tag.objects.filter(feed=self)\
                      .annotate(stories_count=Count('story'))\
                      .order_by('-stories_count')[:20]
            feed_tags = [(tag.name, tag.stories_count) for tag in all_tags if tag.stories_count > 1]
        popular_tags = json.encode(feed_tags)
        if len(popular_tags) < 1024:
            self.popular_tags = popular_tags
            self.save(lock=lock)
            return

        tags_list = json.decode(feed_tags) if feed_tags else []
        if len(tags_list) > 1:
            self.save_popular_tags(tags_list[:-1])
    
    def save_popular_authors(self, feed_authors=None, lock=None):
        if not feed_authors:
            from django.db.models.aggregates import Count
            all_authors = StoryAuthor.objects.filter(feed=self, author_name__isnull=False)\
                          .annotate(stories_count=Count('story'))\
                          .order_by('-stories_count')[:20]
            feed_authors = [(author.author_name, author.stories_count) for author in all_authors\
                                                                       if author.stories_count > 1]
        popular_authors = json.encode(feed_authors)
        if len(popular_authors) < 1024:
            self.popular_authors = popular_authors
            self.save(lock=lock)
            return

        authors_list = json.decode(feed_authors) if feed_authors else []
        if len(authors_list) > 1:
            self.save_popular_authors(authors_list[:-1])
    
    def _shorten_story_tags(self, story_tags):
        encoded_tags = json.encode([t.name for t in story_tags])
        if len(encoded_tags) < 2000:
            return encoded_tags
        
        if len(story_tags) > 1:
            return self._shorten_story_tags(story_tags[:-1])
        
    def trim_feed(self):
        from apps.reader.models import UserStory
        stories_deleted_count = 0
        user_stories_count = 0
        month_ago = datetime.datetime.now() - datetime.timedelta(days=30)
        stories = Story.objects.filter(
            story_feed=self,
            story_date__lte=month_ago
        ).order_by('-story_date')
        print 'Found %s stories in %s. Trimming...' % (stories.count(), self)
        if stories.count() > 1000:
            old_story = stories[1000]
            user_stories = UserStory.objects.filter(feed=self,
                                                    read_date__lte=old_story.story_date)
            user_stories_count = user_stories.count()
            user_stories.delete()
            old_stories = Story.objects.filter(story_feed=self,
                                               story_date__lte=old_story.story_date)
            stories_deleted_count = old_stories.count()
            old_stories.delete()
        
        if stories_deleted_count:
            print "Trimming %s stories from %s. %s user stories." % (
                stories_deleted_count, 
                self, 
                user_stories_count)
                
    def get_stories(self, offset=0, limit=25, force=False):
        if not force:
            stories = cache.get('feed_stories:%s-%s-%s' % (self.id, offset, limit), [])
        else:
            stories = None

        if not stories or force:
            stories_db = Story.objects.filter(story_feed=self)[offset:offset+limit]
            stories = self.format_stories(stories_db)
            cache.set('feed_stories:%s-%s-%s' % (self.id, offset, limit), stories)
        
        return stories
    
    def format_stories(self, stories_db):
        stories = []
        # from django.db import connection
        # print "Formatting Stories: %s" % stories_db.count()
        for story_db in stories_db:
            story = {}
            # story_tags = story_db.tags.all()
            story['story_tags'] = (story_db.story_tags and json.decode(story_db.story_tags)) or []
            story['short_parsed_date'] = format_story_link_date__short(story_db.story_date)
            story['long_parsed_date'] = format_story_link_date__long(story_db.story_date)
            story['story_date'] = story_db.story_date
            story['story_authors'] = story_db.story_author_name
            story['story_title'] = story_db.story_title
            story['story_content'] = story_db.story_content
            story['story_permalink'] = story_db.story_permalink
            story['story_feed_id'] = self.pk
            story['id'] = story_db.id
            
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
                    if not Tag.objects.filter(name=tagname, feed=self):
                        cobj = Tag(name=tagname, feed=self)
                        cobj.save()
                    fcat.append(Tag.objects.get(name=tagname, feed=self))
        return fcat

    def _exists_story(self, story=None, story_content=None, existing_stories=None):
        story_in_system = None
        story_has_changed = False
        story_pub_date = story.get('published')
        story_published_now = story.get('published_now', False)
        start_date = story_pub_date - datetime.timedelta(hours=8)
        end_date = story_pub_date + datetime.timedelta(hours=8)
        
        for existing_story in existing_stories:
            content_ratio = 0
            # print 'Story pub date: %s %s' % (story_published_now, story_pub_date)
            if story_published_now or\
               (story_pub_date > start_date and story_pub_date < end_date):
                if story.get('guid') and story.get('guid') == existing_story.story_guid:
                    story_in_system = existing_story
                elif story.get('link') and story.get('link') == existing_story.story_permalink:
                    story_in_system = existing_story
                
                # import pdb
                # pdb.set_trace()
                
                # Title distance + content distance, checking if story changed
                story_title_difference = levenshtein_distance(story.get('title'),
                                                              existing_story.story_title)
                seq = difflib.SequenceMatcher(None, story_content, existing_story.story_content)
                
                if (seq
                    and story_content
                    and existing_story.story_content
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
                    if story_content != existing_story.story_content:
                        story_has_changed = True
                    break
        
        # if story_has_changed or not story_in_system:
            # print 'New/updated story: %s' % (story), 
        return story_in_system, story_has_changed
        
    def get_next_scheduled_update(self):
        # Use stories per month to calculate next feed update
        updates_per_day = self.stories_last_month / 30.0
        # 0 updates per day = 24 hours
        # 1 update per day = 6 hours
        # > 1 update per day:
        #   2 updates = 3 hours
        #   4 updates = 1 hour
        #   10 updates = 20 minutes
        updates_per_day_delay = 6 * 60 / max(.25, updates_per_day ** 1.55)
        
        # Lots of subscribers = lots of updates
        # 144 hours for 0 subscribers.
        # 24 hours for 1 subscriber.
        # 3 hours for 2 subscribers.
        # ~53 min for 3 subscribers.
        subscriber_bonus = 24 * 60 / max(.167, self.num_subscribers**3)
        
        slow_punishment = 0
        if 30 <= self.last_load_time < 60:
            slow_punishment = self.last_load_time
        elif 60 <= self.last_load_time < 100:
            slow_punishment = 4 * self.last_load_time
        elif self.last_load_time >= 100:
            slow_punishment = 12 * self.last_load_time
        
        total = int(updates_per_day_delay + subscriber_bonus + slow_punishment)
        random_factor = random.randint(0, total) / 4
        
        return total, random_factor
        
    def set_next_scheduled_update(self, lock=None):
        total, random_factor = self.get_next_scheduled_update()

        next_scheduled_update = datetime.datetime.now() + datetime.timedelta(
                                minutes = total + random_factor)
            
        self.next_scheduled_update = next_scheduled_update

        self.save(lock=lock)
        
    def calculate_collocations_story_content(self,
                                             collocation_measures=TrigramAssocMeasures,
                                             collocation_finder=TrigramCollocationFinder):
        stories = Story.objects.filter(story_feed=self)
        story_content = ' '.join([s.story_content for s in stories if s.story_content])
        return self.calculate_collocations(story_content, collocation_measures, collocation_finder)
        
    def calculate_collocations_story_title(self,
                                           collocation_measures=BigramAssocMeasures,
                                           collocation_finder=BigramCollocationFinder):
        stories = Story.objects.filter(story_feed=self)
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
    tags = models.ManyToManyField('Tag')

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
        if len(self.story_title) > 255:
            self.story_title = self.story_title[:255]
        super(Story, self).save(*args, **kwargs)
        
class FeedUpdateHistory(models.Model):
    fetch_date = models.DateTimeField(default=datetime.datetime.now)
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
    fetch_date = models.DateTimeField(default=datetime.datetime.now)
    
    def __unicode__(self):
        return "[%s] %s (%s): %s %s: %s" % (
            self.feed.id,
            self.feed,
            self.fetch_date,
            self.status_code,
            self.message,
            self.exception[:50]
        )
        
class PageFetchHistory(models.Model):
    feed = models.ForeignKey(Feed, related_name='page_fetch_history')
    status_code = models.CharField(max_length=10, null=True, blank=True)
    message = models.CharField(max_length=255, null=True, blank=True)
    exception = models.TextField(null=True, blank=True)
    fetch_date = models.DateTimeField(default=datetime.datetime.now)
    
    def __unicode__(self):
        return "[%s] %s (%s): %s %s: %s" % (
            self.feed.id,
            self.feed,
            self.fetch_date,
            self.status_code,
            self.message,
            self.exception[:50]
        )
