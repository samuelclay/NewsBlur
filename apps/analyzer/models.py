import mongoengine as mongo
from django.db import models
from django.contrib.auth.models import User
from apps.rss_feeds.models import Feed

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
        

class MClassifierTitle(mongo.Document):
    user_id = mongo.IntField()
    feed_id = mongo.IntField()
    title = mongo.StringField(max_length=255)
    score = mongo.IntField()
    creation_date = mongo.DateTimeField()
    
    meta = {
        'collection': 'classifier_title',
        'indexes': ['feed_id', 'user_id', ('user_id', 'feed_id')],
        'allow_inheritance': False,
    }
            
class MClassifierAuthor(mongo.Document):
    user_id = mongo.IntField()
    feed_id = mongo.IntField()
    author = mongo.StringField(max_length=255, unique_with=('user_id', 'feed_id'))
    score = mongo.IntField()
    creation_date = mongo.DateTimeField()
    
    meta = {
        'collection': 'classifier_author',
        'indexes': ['feed_id', 'user_id', ('user_id', 'feed_id')],
        'allow_inheritance': False,
    }
    

class MClassifierFeed(mongo.Document):
    user_id = mongo.IntField()
    feed_id = mongo.IntField(unique_with='user_id')
    score = mongo.IntField()
    creation_date = mongo.DateTimeField()
    
    meta = {
        'collection': 'classifier_feed',
        'indexes': ['feed_id', 'user_id', ('user_id', 'feed_id')],
        'allow_inheritance': False,
    }
    
        
class MClassifierTag(mongo.Document):
    user_id = mongo.IntField()
    feed_id = mongo.IntField()
    tag = mongo.StringField(max_length=255, unique_with=('user_id', 'feed_id'))
    score = mongo.IntField()
    creation_date = mongo.DateTimeField()
    
    meta = {
        'collection': 'classifier_tag',
        'indexes': ['feed_id', 'user_id', ('user_id', 'feed_id')],
        'allow_inheritance': False,
    }
    
    
def apply_classifier_titles(classifiers, story):
    score = 0
    for classifier in classifiers:
        if classifier.title.lower() in story['story_title'].lower():
            # print 'Titles: (%s) %s -- %s' % (classifier.title in story['story_title'], classifier.title, story['story_title'])
            score = classifier.score
            if score > 0: return score
    return score
    
def apply_classifier_feeds(classifiers, feed):
    feed_id = feed if isinstance(feed, int) else feed.pk
    for classifier in classifiers:
        if classifier.feed_id == feed_id:
            # print 'Feeds: %s -- %s' % (classifier.feed_id, feed.pk)
            return classifier.score
    return 0
    
def apply_classifier_authors(classifiers, story):
    score = 0
    for classifier in classifiers:
        if story.get('story_authors') and classifier.author == story.get('story_authors'):
            # print 'Authors: %s -- %s' % (classifier.author, story['story_authors'])
            score = classifier.score
            if score > 0: return classifier.score
    return score
    
def apply_classifier_tags(classifiers, story):
    score = 0
    for classifier in classifiers:
        if story['story_tags'] and classifier.tag in story['story_tags']:
            # print 'Tags: (%s-%s) %s -- %s' % (classifier.tag in story['story_tags'], classifier.score, classifier.tag, story['story_tags'])
            score = classifier.score
            if score > 0: return classifier.score
    return score
    
def get_classifiers_for_user(user, feed_id, classifier_feeds=None, classifier_authors=None, classifier_titles=None, classifier_tags=None):
    if classifier_feeds is None:
        classifier_feeds = MClassifierFeed.objects(user_id=user.pk, feed_id=feed_id)
    else: classifier_feeds.rewind()
    if classifier_authors is None:
        classifier_authors = MClassifierAuthor.objects(user_id=user.pk, feed_id=feed_id)
    else: classifier_authors.rewind()
    if classifier_titles is None:
        classifier_titles = MClassifierTitle.objects(user_id=user.pk, feed_id=feed_id)
    else: classifier_titles.rewind()
    if classifier_tags is None:
        classifier_tags = MClassifierTag.objects(user_id=user.pk, feed_id=feed_id)
    else: classifier_tags.rewind()

    payload = {
        'feeds': dict([(f.feed_id, f.score) for f in classifier_feeds]),
        'authors': dict([(a.author, a.score) for a in classifier_authors]),
        'titles': dict([(t.title, t.score) for t in classifier_titles]),
        'tags': dict([(t.tag, t.score) for t in classifier_tags]),
    }
    
    return payload