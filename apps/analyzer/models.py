from django.db import models
from django.contrib.auth.models import User
import datetime
from apps.rss_feeds.models import Feed, Story, StoryAuthor, Tag
from apps.reader.models import UserSubscription, UserStory

class FeatureCategory(models.Model):

    user = models.ForeignKey(User)
    feed = models.ForeignKey(Feed)
    feature = models.CharField(max_length=255)
    category = models.CharField(max_length=255)
    count = models.IntegerField(default=0)
    
    def __unicode__(self):
        return '%s - %s (%s)' % (self.feature, self.category, self.count)

class Category(models.Model):
    
    user = models.ForeignKey(User)
    feed = models.ForeignKey(Feed)
    category = models.CharField(max_length=255)
    count = models.IntegerField(default=0)
    
    def __unicode__(self):
        return '%s (%s)' % (self.category, self.count)
        
        
class ClassifierTitle(models.Model):
    user = models.ForeignKey(User)
    score = models.SmallIntegerField()
    title = models.CharField(max_length=255)
    feed = models.ForeignKey(Feed)
    original_story = models.ForeignKey(Story, null=True)
    creation_date = models.DateTimeField(auto_now=True)
    
    def __unicode__(self):
        return '%s: %s (%s)' % (self.user, self.title, self.feed)
        
class ClassifierAuthor(models.Model):
    user = models.ForeignKey(User)
    score = models.SmallIntegerField()
    author = models.ForeignKey(StoryAuthor)
    feed = models.ForeignKey(Feed)
    original_story = models.ForeignKey(Story, null=True)
    creation_date = models.DateTimeField(auto_now=True)
    
    def __unicode__(self):
        return '%s: %s (%s)' % (self.user, self.author.author_name, self.feed)
    
class ClassifierFeed(models.Model):
    user = models.ForeignKey(User)
    score = models.SmallIntegerField()
    feed = models.ForeignKey(Feed)
    original_story = models.ForeignKey(Story, null=True)
    creation_date = models.DateTimeField(auto_now=True)
    
    def __unicode__(self):
        return '%s: %s' % (self.user, self.feed)
        
class ClassifierTag(models.Model):
    user = models.ForeignKey(User)
    score = models.SmallIntegerField()
    tag = models.ForeignKey(Tag)
    feed = models.ForeignKey(Feed)
    original_story = models.ForeignKey(Story, null=True)
    creation_date = models.DateTimeField(auto_now=True)
    
    def __unicode__(self):
        return '%s: %s (%s)' % (self.user, self.tag.name, self.feed)