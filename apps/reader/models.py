from django.db import models
from django.contrib.auth.models import User
import datetime
from apps.rss_feeds.models import Feed, Story
from utils import feedparser, object_manager

class UserSubscription(models.Model):
    user = models.ForeignKey(User)
    feed = models.ForeignKey(Feed)
    last_read_date = models.DateTimeField(default=datetime.datetime(2000,1,1))
    mark_read_date = models.DateTimeField(default=datetime.datetime(2000,1,1))
    unread_count = models.IntegerField(default=0)
    unread_count_updated = models.DateTimeField(
                               default=datetime.datetime(2000,1,1)
                           )

    def __unicode__(self):
        return '[' + self.feed.feed_title + '] '

    def save(self, force_insert=False, force_update=False):
        self.unread_count_updated = datetime.datetime.now()
        super(UserSubscription, self).save(force_insert, force_update)
        
    def get_user_feeds(self):
        return Feed.objects.get(user=self.user, feed=feeds)
    
    def count_unread(self):
        if self.unread_count_updated > self.feed.last_update:
            return self.unread_count
            
        count = (self.stories_newer_lastread()
                 + self.stories_between_lastread_allread())
        if count == 0:
            self.mark_read_date = datetime.datetime.now()
            self.last_read_date = datetime.datetime.now()
            self.unread_count_updated = datetime.datetime.now()
            self.unread_count = 0
            self.save()
        else:
            self.unread_count = count
            self.unread_count_updated = datetime.datetime.now()
            self.save()
        return count
    
    def mark_read(self):
        self.last_read_date = datetime.datetime.now()
        self.unread_count -= 1
        self.unread_count_updated = datetime.datetime.now()
        self.save()
        
    def mark_feed_read(self):
        self.last_read_date = datetime.datetime.now()
        self.mark_read_date = datetime.datetime.now()
        self.unread_count = 0
        self.unread_count_updated = datetime.datetime.now()
        self.save()
        readstories = ReadStories.objects.filter(user=self.user, feed=self.feed)
        readstories.delete()
        
    def stories_newer_lastread(self):
        return self.feed.new_stories_since_date(self.last_read_date)
        
    def stories_between_lastread_allread(self):
        story_count =   Story.objects.filter(
                            story_date__gte=self.mark_read_date,
                            story_date__lte=self.last_read_date,
                            story_feed=self.feed
                        ).count()
        read_count =    ReadStories.objects.filter(
                            feed=self.feed, 
                            read_date__gte=self.mark_read_date,
                            read_date__lte=self.last_read_date
                        ).count()
        return story_count - read_count
        
    def subscribe_to_feed(self, feed_id):
        feed = Feed.objects.get(id=feed_id)
        new_subscription = UserSubscription(user=self.user, feed=feed)
        new_subscription.save()
    
    class Meta:
        unique_together = ("user", "feed")
        
        
class ReadStories(models.Model):
    user = models.ForeignKey(User)
    feed = models.ForeignKey(Feed)
    story = models.ForeignKey(Story)
    read_date = models.DateTimeField(auto_now=True)
    
    def __unicode__(self):
        return ('[' + self.feed.feed_title + '] '
                + self.story.story_title)
        
    class Meta:
        verbose_name_plural = "read stories"
        verbose_name = "read story"
        unique_together = ("user", "story")
        
class StoryOpinions(models.Model):
    user = models.ForeignKey(User)
    feed = models.ForeignKey(Feed)
    story = models.ForeignKey(Story)
    opinion = models.IntegerField(default=0)
    
    def __unicode__(self):
        return ("%s [%s]: %s - %s" %
                    (self.user.username, self.feed.feed_title, self.story.story_title, self.opinion))
        
    class Meta:
        verbose_name_plural = "opinions"
        verbose_name = "opinion"
        unique_together = ("user", "story")
        
class UserSubscriptionFolders(models.Model):
    user = models.ForeignKey(User)
    user_sub = models.ForeignKey(UserSubscription)
    feed = models.ForeignKey(Feed)
    folder = models.CharField(max_length=255)
    
    def __unicode__(self):
        return ('[' + self.feed.feed_title + '] '
                + self.folder)
        
    class Meta:
        verbose_name_plural = "folders"
        verbose_name = "folder"
        unique_together = ("user", "user_sub")