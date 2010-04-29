from django.db import models
from django.db import IntegrityError
from django.contrib.auth.models import User
from django.contrib.contenttypes.models import ContentType
from django.core import serializers
from django.core.cache import cache
from utils import feedparser, object_manager, json
from utils.dateutil.parser import parse as dateutil_parse
from utils.feed_functions import encode, prints, mtime, levenshtein_distance
import time, datetime, random
from django.utils.http import urlquote
from django.utils.safestring import mark_safe
from utils.story_functions import format_story_link_date__short
from utils.story_functions import format_story_link_date__long
from utils.story_functions import pre_process_story
from utils.compressed_textfield import StoryField
from django.db.models import Q
import settings
import logging
import difflib
import datetime
import hashlib
from utils.diff import HTMLDiff

USER_AGENT = 'NewsBlur v1.0 - newsblur.com'

ENTRY_NEW, ENTRY_UPDATED, ENTRY_SAME, ENTRY_ERR = range(4)

class Feed(models.Model):
    feed_address = models.URLField(max_length=255, verify_exists=True, unique=True)
    feed_link = models.URLField(max_length=200, default="")
    feed_title = models.CharField(max_length=255, default="")
    feed_tagline = models.CharField(max_length=1024, default="")
    active = models.BooleanField(default=True)
    num_subscribers = models.IntegerField(default=0)
    last_update = models.DateTimeField(auto_now=True, default=0)
    min_to_decay = models.IntegerField(default=15)
    days_to_trim = models.IntegerField(default=90)
    creation = models.DateField(auto_now_add=True)
    etag = models.CharField(max_length=50, blank=True, null=True)
    last_modified = models.DateTimeField(null=True, blank=True)
    page_data = StoryField(null=True, blank=True)
    stories_per_month = models.IntegerField(default=0)
    next_scheduled_update = models.DateTimeField(default=datetime.datetime.now)
    last_load_time = models.IntegerField(default=0)
    
    
    def __unicode__(self):
        return self.feed_title
        
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
                    pub_date = datetime.datetime.timetuple(story.get('published'))
                    # logging.debug('- New story: %s %s' % (pub_date, story.get('title')))
                    
                    s = Story(story_feed = self,
                           story_date = story.get('published'),
                           story_title = story.get('title'),
                           story_content = story_content,
                           story_author = story_author,
                           story_permalink = story.get('link'),
                           story_guid = story.get('guid') or story.get('id') or story.get('link'),
                           story_tags = json.encode([t.name for t in story_tags])
                    )
                    try:
                        ret_values[ENTRY_NEW] += 1
                        s.save(force_insert=True)
                    except IntegrityError, e:
                        ret_values[ENTRY_ERR] += 1
                        print('Saving new story, IntegrityError: %s - %s: %s' % (self.feed_title, story.get('title'), e))
                    [s.tags.add(tcat) for tcat in story_tags]
                elif existing_story and story_has_changed:
                    # update story
                    logging.debug('- Updated story in feed (%s - %s): %s / %s' % (self.feed_title, story.get('title'), len(existing_story.story_content), len(story_content)))
                
                    original_content = None
                    if existing_story.story_original_content:
                        original_content = existing_story.story_original_content
                    else:
                        original_content = existing_story.story_content
                    # print 'Type: %s %s' % (type(original_content), type(story_content))
                    diff = HTMLDiff(unicode(original_content), story_content)
                    # logging.debug("\t\tDiff: %s %s %s" % diff.getStats())
                    # logging.debug("\t\tDiff content: %s" % diff.getDiff())
                    if existing_story.story_title != story.get('title'):
                        # logging.debug('\tExisting title / New: : \n\t\t- %s\n\t\t- %s' % (existing_story.story_title, story.get('title')))
                        pass

                    s = Story(id = existing_story.id,
                           story_feed = self,
                           story_date = story.get('published'),
                           story_title = story.get('title'),
                           story_content = diff.getDiff(),
                           story_original_content = original_content,
                           story_author = story_author,
                           story_permalink = story.get('link'),
                           story_guid = story.get('guid') or story.get('id') or story.get('link'),
                           story_tags = json.encode([t.name for t in story_tags])
                    )
                    s.tags.clear()
                    [s.tags.add(tcat) for tcat in story_tags]
                    try:
                        ret_values[ENTRY_UPDATED] += 1
                        s.save(force_update=True)
                    except IntegrityError, e:
                        ret_values[ENTRY_ERR] += 1
                        print('Saving updated story, IntegrityError: %s - %s' % (self.feed_title, story.get('title')))
                else:
                    ret_values[ENTRY_SAME] += 1
                    # logging.debug("Unchanged story: %s " % story.get('title'))
            
        return ret_values
        
    def _save_story_author(self, author):
        author, created = StoryAuthor.objects.get_or_create(feed=self, author_name=author)
        return author, created
        
    def trim_feed(self):
        from apps.reader.models import UserStory
        stories_deleted_count = 0
        user_stories_count = 0
        stories = Story.objects.filter(story_feed=self).order_by('-story_date')
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
                
    def get_stories(self, offset=0, limit=25):
        stories = cache.get('feed_stories:%s-%s-%s' % (self.id, offset, limit), [])

        if not stories:
            stories_db = Story.objects.filter(story_feed=self)\
                                      .select_related('story_author')[offset:offset+limit]
            stories = self.format_stories(stories_db)
            cache.set('feed_stories:%s-%s-%s' % (self.id, offset, limit), stories, 600)
        
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
            story['story_authors'] = story_db.story_author.author_name
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
                if tcat.label != None:
                    term = tcat.label
                else:
                    term = tcat.term
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
                
                if seq and seq.real_quick_ratio() > .9 and seq.quick_ratio() > .95:
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
            
    class Meta:
        db_table="feeds"
        ordering=["feed_title"]
        
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
    story_permalink = models.CharField(max_length=1000)
    story_guid = models.CharField(max_length=1000)
    story_guid_hash = models.CharField(max_length=40)
    story_past_trim_date = models.BooleanField(default=False)
    story_tags = models.CharField(max_length=1000)
    tags = models.ManyToManyField(Tag)

    def __unicode__(self):
        return self.story_title

    class Meta:
        verbose_name_plural = "stories"
        verbose_name = "story"
        db_table="stories"
        ordering=["-story_date"]
        
    def save(self, *args, **kwargs):
        if not self.story_guid_hash and self.story_guid:
            self.story_guid_hash = hashlib.md5(self.story_guid).hexdigest()
        super(Story, self).save(*args, **kwargs)
        
class FeedUpdateHistory(models.Model):
    fetch_date = models.DateTimeField(default=datetime.datetime.now)
    number_of_feeds = models.IntegerField()
    seconds_taken = models.IntegerField()
    average_per_feed = models.DecimalField(decimal_places=1, max_digits=4)
    
    def __unicode__(self):
        return "[%s] %s feeds: %s seconds" % (
            fetch_date.strftime('%F %d'),
            self.number_of_feeds,
            self.seconds_taken,
        )
    
    def save(self, *args, **kwargs):
        self.average_per_feed = str(self.seconds_taken / float(max(1.0,self.number_of_feeds)))
        super(FeedUpdateHistory, self).save(*args, **kwargs)
    