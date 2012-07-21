import mongoengine as mongo
from collections import defaultdict
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
    social_user_id = mongo.IntField()
    title = mongo.StringField(max_length=255)
    score = mongo.IntField()
    creation_date = mongo.DateTimeField()
    
    meta = {
        'collection': 'classifier_title',
        'indexes': [('user_id', 'feed_id'), 'feed_id', ('user_id', 'social_user_id'), 'social_user_id'],
        'allow_inheritance': False,
    }
            
class MClassifierAuthor(mongo.Document):
    user_id = mongo.IntField(unique_with=('feed_id', 'social_user_id', 'author'))
    feed_id = mongo.IntField()
    social_user_id = mongo.IntField()
    author = mongo.StringField(max_length=255)
    score = mongo.IntField()
    creation_date = mongo.DateTimeField()
    
    meta = {
        'collection': 'classifier_author',
        'indexes': [('user_id', 'feed_id'), 'feed_id', ('user_id', 'social_user_id'), 'social_user_id'],
        'allow_inheritance': False,
    }

class MClassifierTag(mongo.Document):
    user_id = mongo.IntField(unique_with=('feed_id', 'social_user_id', 'tag'))
    feed_id = mongo.IntField()
    social_user_id = mongo.IntField()
    tag = mongo.StringField(max_length=255)
    score = mongo.IntField()
    creation_date = mongo.DateTimeField()
    
    meta = {
        'collection': 'classifier_tag',
        'indexes': [('user_id', 'feed_id'), 'feed_id', ('user_id', 'social_user_id'), 'social_user_id'],
        'allow_inheritance': False,
    }
    

class MClassifierFeed(mongo.Document):
    user_id = mongo.IntField(unique_with=('feed_id', 'social_user_id'))
    feed_id = mongo.IntField()
    social_user_id = mongo.IntField()
    score = mongo.IntField()
    creation_date = mongo.DateTimeField()
    
    meta = {
        'collection': 'classifier_feed',
        'indexes': [('user_id', 'feed_id'), 'feed_id', ('user_id', 'social_user_id'), 'social_user_id'],
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
    
def apply_classifier_feeds(classifiers, feed, social_user_id=None):
    feed_id = feed if isinstance(feed, int) else feed.pk
    for classifier in classifiers:
        if classifier.feed_id == feed_id:
            # print 'Feeds: %s -- %s' % (classifier.feed_id, feed.pk)
            return classifier.score
        if social_user_id and not classifier.feed_id and social_user_id == classifier.social_user_id:
            return classifier.score
    return 0
    
def get_classifiers_for_user(user, feed_id=None, social_user_id=None, classifier_feeds=None, classifier_authors=None, 
                             classifier_titles=None, classifier_tags=None):
    params = dict(user_id=user.pk)
    if isinstance(feed_id, list):
        params['feed_id__in'] = feed_id
    elif feed_id:
        params['feed_id'] = feed_id
    if social_user_id:
        if isinstance(social_user_id, basestring):
            social_user_id = int(social_user_id.replace('social:', ''))
        params['social_user_id'] = social_user_id

    if classifier_authors is None:
        classifier_authors = list(MClassifierAuthor.objects(**params))
    if classifier_titles is None:
        classifier_titles = list(MClassifierTitle.objects(**params))
    if classifier_tags is None:
        classifier_tags = list(MClassifierTag.objects(**params))
    if classifier_feeds is None:
        if not social_user_id and feed_id:
            params['social_user_id'] = 0
        classifier_feeds = list(MClassifierFeed.objects(**params))
    
    feeds = []
    for f in classifier_feeds:
        if f.social_user_id and not f.feed_id:
            feeds.append(('social:%s' % f.social_user_id, f.score))
        else:
            feeds.append((f.feed_id, f.score))
            
    payload = {
        'feeds': dict(feeds),
        'authors': dict([(a.author, a.score) for a in classifier_authors]),
        'titles': dict([(t.title, t.score) for t in classifier_titles]),
        'tags': dict([(t.tag, t.score) for t in classifier_tags]),
    }
    
    return payload
    
def sort_classifiers_by_feed(user, feed_ids=None,
                             classifier_feeds=None,
                             classifier_authors=None,
                             classifier_titles=None,
                             classifier_tags=None):
    def sort_by_feed(classifiers):
        feed_classifiers = defaultdict(list)
        for classifier in classifiers:
            feed_classifiers[classifier.feed_id].append(classifier)
        return feed_classifiers
    
    classifiers = {}

    if feed_ids:
        classifier_feeds   = sort_by_feed(classifier_feeds)
        classifier_authors = sort_by_feed(classifier_authors)
        classifier_titles  = sort_by_feed(classifier_titles)
        classifier_tags    = sort_by_feed(classifier_tags)

        for feed_id in feed_ids:
            classifiers[feed_id] = get_classifiers_for_user(user, feed_id=feed_id, 
                                                            classifier_feeds=classifier_feeds[feed_id], 
                                                            classifier_authors=classifier_authors[feed_id],
                                                            classifier_titles=classifier_titles[feed_id],
                                                            classifier_tags=classifier_tags[feed_id])
    
    return classifiers