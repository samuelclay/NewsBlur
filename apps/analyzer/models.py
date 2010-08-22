import mongoengine as mongo
from django.db import models
from django.contrib.auth.models import User
from apps.rss_feeds.models import Feed, StoryAuthor, Tag

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
    # original_story = models.ForeignKey(Story, null=True)
    creation_date = models.DateTimeField(auto_now=True)
    
    unique_together = (('user', 'feed', 'title'),)
    
    def __unicode__(self):
        return '%s: %s (%s)' % (self.user, self.title, self.feed)
        
class MClassifierTitle(mongo.Document):
    user_id = mongo.IntField()
    feed_id = mongo.IntField()
    title = mongo.StringField(max_length=255)
    score = mongo.IntField()
    creation_date = mongo.DateTimeField()
    
    meta = {
        'collection': 'classifier_title',
        'indexes': ['feed_id', ('user_id', 'feed_id')],
        'allow_inheritance': False,
    }
            
class ClassifierAuthor(models.Model):
    user = models.ForeignKey(User)
    score = models.SmallIntegerField()
    author = models.ForeignKey(StoryAuthor)
    feed = models.ForeignKey(Feed)
    # original_story = models.ForeignKey(Story, null=True)
    creation_date = models.DateTimeField(auto_now=True)
    
    unique_together = (('user', 'feed', 'author'),)
    
    def __unicode__(self):
        return '%s: %s (%s)' % (self.user, self.author.author_name, self.feed)
        
class MClassifierAuthor(mongo.Document):
    user_id = mongo.IntField()
    feed_id = mongo.IntField()
    author = mongo.StringField(max_length=255, unique_with=('user_id', 'feed_id'))
    score = mongo.IntField()
    creation_date = mongo.DateTimeField()
    
    meta = {
        'collection': 'classifier_author',
        'indexes': ['feed_id', ('user_id', 'feed_id')],
        'allow_inheritance': False,
    }
    

class ClassifierFeed(models.Model):
    user = models.ForeignKey(User)
    score = models.SmallIntegerField()
    feed = models.ForeignKey(Feed)
    # original_story = models.ForeignKey(Story, null=True)
    creation_date = models.DateTimeField(auto_now=True)
    
    unique_together = (('user', 'feed'),)
    
    def __unicode__(self):
        return '%s: %s' % (self.user, self.feed)
        
class MClassifierFeed(mongo.Document):
    user_id = mongo.IntField()
    feed_id = mongo.IntField(unique_with='user_id')
    score = mongo.IntField()
    creation_date = mongo.DateTimeField()
    
    meta = {
        'collection': 'classifier_feed',
        'indexes': ['feed_id', ('user_id', 'feed_id')],
        'allow_inheritance': False,
    }
    
        
class ClassifierTag(models.Model):
    user = models.ForeignKey(User)
    score = models.SmallIntegerField()
    tag = models.ForeignKey(Tag)
    feed = models.ForeignKey(Feed)
    # original_story = models.ForeignKey(Story, null=True)
    creation_date = models.DateTimeField(auto_now=True)
    
    unique_together = (('user', 'feed', 'tag'),)
    
    def __unicode__(self):
        return '%s: %s (%s)' % (self.user, self.tag.name, self.feed)
        
class MClassifierTag(mongo.Document):
    user_id = mongo.IntField()
    feed_id = mongo.IntField()
    tag = mongo.StringField(max_length=255, unique_with=('user_id', 'feed_id'))
    score = mongo.IntField()
    creation_date = mongo.DateTimeField()
    
    meta = {
        'collection': 'classifier_tag',
        'indexes': ['feed_id', ('user_id', 'feed_id')],
        'allow_inheritance': False,
    }
    
    
def apply_classifier_titles(classifiers, story):
    for classifier in classifiers:
        if classifier.title.lower() in story['story_title'].lower():
            # print 'Titles: (%s) %s -- %s' % (classifier.title in story['story_title'], classifier.title, story['story_title'])
            return classifier.score
    return 0
    
def apply_classifier_feeds(classifiers, feed):
    for classifier in classifiers:
        if classifier.feed_id == feed.pk:
            # print 'Feeds: %s -- %s' % (classifier.feed_id, feed.pk)
            return classifier.score
    return 0
    
def apply_classifier_authors(classifiers, story):
    for classifier in classifiers:
        if story.get('story_authors') and classifier.author == story.get('story_authors'):
            # print 'Authors: %s -- %s' % (classifier.author, story['story_authors'])
            return classifier.score
    return 0
    
def apply_classifier_tags(classifiers, story):
    for classifier in classifiers:
        if story['story_tags'] and classifier.tag in story['story_tags']:
            # print 'Tags: (%s-%s) %s -- %s' % (classifier.tag in story['story_tags'], classifier.score, classifier.tag, story['story_tags'])
            return classifier.score
    return 0
    
def get_classifiers_for_user(user, feed_id, classifier_feeds=None, classifier_authors=None, classifier_titles=None, classifier_tags=None):
    if classifier_feeds is None:
        # print "Fetching Feeds"
        classifier_feeds = MClassifierFeed.objects(user_id=user.pk, feed_id=feed_id)
    if classifier_authors is None:
        # print "Fetching Authors"
        classifier_authors = MClassifierAuthor.objects(user_id=user.pk, feed_id=feed_id)
    if classifier_titles is None:
        # print "Fetching Titles"
        classifier_titles = MClassifierTitle.objects(user_id=user.pk, feed_id=feed_id)
    if classifier_tags is None:
        # print "Fetching Tags"
        classifier_tags = MClassifierTag.objects(user_id=user.pk, feed_id=feed_id)
    
    payload = {
        'feeds': dict([(f.feed_id, f.score) for f in classifier_feeds]),
        'authors': dict([(a.author, a.score) for a in classifier_authors]),
        'titles': dict([(t.title, t.score) for t in classifier_titles]),
        'tags': dict([(t.tag, t.score) for t in classifier_tags]),
    }
    
    return payload