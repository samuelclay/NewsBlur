from django.db import models
from django.contrib.auth.models import User
import datetime
from apps.rss_feeds.models import Feed, Story, StoryAuthor, Tag

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
        
    def apply_classifier(self, story):
        if story['author'] == self.author:
            return True
        return False


class ClassifierFeed(models.Model):
    user = models.ForeignKey(User)
    score = models.SmallIntegerField()
    feed = models.ForeignKey(Feed)
    original_story = models.ForeignKey(Story, null=True)
    creation_date = models.DateTimeField(auto_now=True)
    
    def __unicode__(self):
        return '%s: %s' % (self.user, self.feed)
        
    def apply_classifier(self, story):
        if self.feed == story.feed:
            return True
        return False

        
class ClassifierTag(models.Model):
    user = models.ForeignKey(User)
    score = models.SmallIntegerField()
    tag = models.ForeignKey(Tag)
    feed = models.ForeignKey(Feed)
    original_story = models.ForeignKey(Story, null=True)
    creation_date = models.DateTimeField(auto_now=True)
    
    def __unicode__(self):
        return '%s: %s (%s)' % (self.user, self.tag.name, self.feed)
        
def apply_classifier_titles(classifiers, story):
    for classifier in classifiers:
        if classifier.title.lower() in story['story_title'].lower():
            # print 'Titles: (%s) %s -- %s' % (classifier.title in story['story_title'], classifier.title, story['story_title'])
            return classifier.score
    return 0
    
def apply_classifier_feeds(classifiers, feed):
    for classifier in classifiers:
        if classifier.feed == feed:
            # print 'Feeds: %s -- %s' % (classifier.feed, feed)
            return classifier.score
    return 0
    
def apply_classifier_authors(classifiers, story):
    for classifier in classifiers:
        if story.get('story_authors') and classifier.author.author_name in story.get('story_authors'):
            # print 'Authors: %s -- %s' % (classifier.author.id, story['story_author_id'])
            return classifier.score
    return 0
    
def apply_classifier_tags(classifiers, story):
    for classifier in classifiers:
        if classifier.tag.name in story['story_tags']:
            # print 'Tags: (%s) %s -- %s' % (classifier.tag.name in story['story_tags'], classifier.tag.name, story['story_tags'])
            return classifier.score
    return 0
    
def get_classifiers_for_user(user, feed, classifier_feeds=None, classifier_authors=None, classifier_titles=None, classifier_tags=None):
    if not classifier_feeds:
        classifier_feeds = ClassifierFeed.objects.filter(user=user, feed=feed)
    if not classifier_authors:
        classifier_authors = ClassifierAuthor.objects.filter(user=user, feed=feed)
    if not classifier_titles:
        classifier_titles = ClassifierTitle.objects.filter(user=user, feed=feed)
    if not classifier_tags:
        classifier_tags = ClassifierTag.objects.filter(user=user, feed=feed)
    
    payload = {
        'feeds': dict((f.feed.feed_link, {
            'feed_title': f.feed.feed_title, 
            'feed_link': f.feed.feed_link, 
            'score': f.score
        }) for f in classifier_feeds),
        'authors': dict([(a.author.author_name, a.score) for a in classifier_authors]),
        'titles': dict([(t.title, t.score) for t in classifier_titles]),
        'tags': dict([(t.tag.name, t.score) for t in classifier_tags]),
    }
    
    return payload