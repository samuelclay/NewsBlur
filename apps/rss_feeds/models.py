from django.db import models
from django.contrib.auth.models import User
from django.contrib.contenttypes.models import ContentType
from django.core.cache import cache
from utils import feedparser, object_manager
from utils.dateutil.parser import parse as dateutil_parse
from utils.feed_functions import encode, prints, mtime, levenshtein_distance
import time, datetime, random
from django.utils.http import urlquote
from django.utils.safestring import mark_safe
from utils.story_functions import format_story_link_date__short
from utils.story_functions import format_story_link_date__long
from django.db.models import Q
from utils.diff import HTMLDiff
import logging

USER_AGENT = 'NewsBlur v1.0 - newsblur.com'


class Feed(models.Model):
    feed_address = models.URLField(max_length=255, verify_exists=True, unique=True)
    feed_link = models.URLField(max_length=200, blank=True)
    feed_title = models.CharField(max_length=255, blank=True)
    active = models.BooleanField(default=True)
    num_subscribers = models.IntegerField(default=0)
    last_update = models.DateTimeField(auto_now=True, default=0)
    min_to_decay = models.IntegerField(default=15)
    days_to_trim = models.IntegerField(default=90)
    creation = models.DateField(auto_now_add=True)
    etag = models.CharField(max_length=50, blank=True)
    last_modified = models.DateTimeField(null=True, blank=True)
    
    
    def __unicode__(self):
        return self.feed_title
        
    def last_updated(self):
        return time.time() - time.mktime(self.last_update.timetuple())
    
    def new_stories_since_date(self, date):
        story_count = Story.objects.filter(story_date__gte=date,
                                           story_feed=self).count()
        return story_count
        
    def add_feed(self, feed_address, feed_link, feed_title):
        print locals()
        
    def update(self, force=False, feed=None):
        last_updated = self.last_updated() / 60
        min_to_decay = self.min_to_decay + (random.random()*self.min_to_decay)
        if last_updated < min_to_decay and not force:
            logging.debug('Feed unchanged: ' + self.feed_title)
            return
            
        feed_updated, feed = cache.get("feed:" + self.feed_address, (None, None,))
        if feed and not force:
            logging.debug('Feed Cached: ' + self.feed_title)
        if not feed or force:
            last_modified = None
            now = datetime.datetime.now()
            if self.last_modified:
                last_modified = datetime.datetime.timetuple(self.last_modified)
            if not feed:
                logging.debug('[%d] Retrieving Feed: %s'
                              % (self.id, self.feed_title))
                feed = feedparser.parse(self.feed_address,
                                        etag=self.etag,
                                        modified=last_modified,
                                        agent=USER_AGENT)
                cache.set("feed:" + self.feed_address, (now, feed), min_to_decay)
        
        # check for movement or disappearance
        if hasattr(feed, 'status'):
            if feed.status == 301:
                self.feed_url = feed.href
            if feed.status == 410:
                self.active = False
            if feed.status >= 400:
                return

        # Fill in optional fields
        if not self.feed_title:
            self.feed_title = feed.feed.get('title', feed.feed.get('link'))
        if not self.feed_link:
            self.feed_link = feed.feed.get('link')
        self.etag = feed.get('etag', '')
        self.last_update = datetime.datetime.now()
        self.last_modified = mtime(feed.get('modified',
                                        datetime.datetime.timetuple(datetime.datetime.now())))
        self.save()
        
        num_entries = len(feed['entries'])
        # Compare new stories to existing stories, adding and updating
        existing_stories = Story.objects.filter(
            story_feed=self
        ).order_by('-story_date').values()[:num_entries]
        
        self.add_update_stories(feed['entries'], existing_stories)

        self.trim_feed();

        return

    def add_update_stories(self, stories, existing_stories):
        for story in stories:
            story = self._pre_process_story(story)

            if story.get('title'):
                story_contents = story.get('content')
                if story_contents is not None:
                    story_content = story_contents[0]['value']
                else:
                    story_content = story.get('summary')
                existing_story, is_different = self._exists_story(story, story_content, existing_stories)
                if existing_story is None:
                    pub_date = datetime.datetime.timetuple(story.get('published'))
                    logging.debug('- New story: %s %s' % (pub_date, story.get('title')))
                
                    s = Story(story_feed = self,
                           story_date = story.get('published'),
                           story_title = story.get('title'),
                           story_content = story_content,
                           story_author = story.get('author'),
                           story_permalink = story.get('link')
                    )
                    try:
                        s.save(force_insert=True)
                    except:
                        pass
                elif existing_story and is_different:
                    # update story
                    logging.debug('- Updated story in feed (%s - %s/%s): %s / %s' % (self.feed_title, len(existing_story['story_content']), len(story.get('title')), len(existing_story['story_content']), len(story_content)))
                
                    original_content = None
                    if existing_story['story_original_content']:
                        original_content = existing_story['story_original_content']
                    else:
                        original_content = existing_story['story_content']
                    diff = HTMLDiff(original_content, story_content)
                    # logging.debug("\t\tDiff: %s %s %s" % diff.getStats())
                    # logging.debug("\t\tDiff content: %s" % diff.getDiff())
                    if existing_story['story_title'] != story.get('title'):
                        logging.debug('\tExisting title / New: : \n\t\t- %s\n\t\t- %s' % (existing_story['story_title'], story.get('title')))

                    s = Story(id = existing_story['id'],
                           story_feed = self,
                           story_date = story.get('published'),
                           story_title = story.get('title'),
                           story_content = diff.getDiff(),
                           story_original_content = original_content,
                           story_author = story.get('author'),
                           story_permalink = story.get('link')
                    )
                    try:
                        s.save(force_update=True)
                    except:
                        pass
                # else:
                    # logging.debug("Unchanged story: %s " % story.get('title'))
            
        return
        
            
    def trim_feed(self):
        date_diff = datetime.datetime.now() - datetime.timedelta(self.days_to_trim)
        stories = Story.objects.filter(story_feed=self, story_date__lte=date_diff)
        for story in stories:
            story.story_past_trim_date = True
            story.save()
        
    def get_stories(self, offset=0, limit=25):
        stories = cache.get('feed_stories:%s-%s-%s' % (self.id, offset, limit))
    
        if stories is None:
            stories = Story.objects.filter(story_feed=self).values()[offset:offset+limit]
            for story in stories:
                story['short_parsed_date'] = format_story_link_date__short(story['story_date'])
                story['long_parsed_date'] = format_story_link_date__long(story['story_date'])
                story['story_feed_title'] = self.feed_title
                story['story_feed_link'] = mark_safe(self.feed_link)
                story['story_permalink'] = mark_safe(story['story_permalink'])
            cache.set('feed_stories:%s-%s-%s' % (self.id, offset, limit), stories)
        
        return stories
    
    def _exists_story(self, story=None, story_content=None, existing_stories=None):
        same_story = None
        is_different = False
        story_pub_date = story.get('published')
        start_date = story_pub_date - datetime.timedelta(hours=8)
        end_date = story_pub_date + datetime.timedelta(hours=8)

        for existing_story in existing_stories:
            if story_pub_date > start_date and story_pub_date < end_date:
                if story.get('link') == existing_story['story_permalink']:
                    same_story = existing_story
                    
                story_title_difference = levenshtein_distance(story.get('title'),
                                                              existing_story['story_title'])
                if same_story and story_title_difference < 10:
                    same_story = existing_story
                    if story_title_difference > 0:
                        is_different = True
                                        
                if same_story:
                    if story_content != existing_story['story_content']:
                        is_different = True
                    break

        return same_story, is_different
        
    def _pre_process_story(self, entry):
        date_published = entry.get('published', entry.get('updated'))
        if not date_published:
            date_published = str(datetime.datetime.now())
        date_published = dateutil_parse(date_published)
        # Change the date to UTC and remove timezone info since 
        # MySQL doesn't support it.
        timezone_diff = datetime.datetime.utcnow() - datetime.datetime.now()
        date_published_offset = date_published.utcoffset()
        if date_published_offset:
            date_published = (date_published - date_published_offset
                              - timezone_diff).replace(tzinfo=None)
        else:
            date_published = date_published.replace(tzinfo=None)

        entry['published'] = date_published

        protocol_index = entry['link'].find("://")
        if protocol_index != -1:
            entry['link'] = (entry['link'][:protocol_index+3]
                            + urlquote(entry['link'][protocol_index+3:]))
        else:
            entry['link'] = urlquote(entry['link'])
        return entry
            
    class Meta:
        db_table="feeds"
        ordering=["feed_title"]
        
class Tag(models.Model):
    name = models.CharField(max_length=100)

    def __unicode__(self):
        return self.name
    
    def save(self):
        super(Tag, self).save()
        
class Story(models.Model):
    '''A feed item'''
    story_feed = models.ForeignKey(Feed)
    story_date = models.DateTimeField()
    story_title = models.CharField(max_length=255)
    story_content = models.TextField(null=True, blank=True)
    story_original_content = models.TextField(null=True, blank=True)
    story_content_type = models.CharField(max_length=255, null=True,
                                          blank=True)
    story_author = models.CharField(max_length=255, null=True, blank=True)
    story_permalink = models.CharField(max_length=1000)
    story_past_trim_date = models.BooleanField(default=False)
    tags = models.ManyToManyField(Tag)

    def __unicode__(self):
        return self.story_title

    class Meta:
        verbose_name_plural = "stories"
        verbose_name = "story"
        db_table="stories"
        ordering=["-story_date"]
        