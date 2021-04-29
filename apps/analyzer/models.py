import datetime
import mongoengine as mongo
from collections import defaultdict
from django.db import models
from django.contrib.auth.models import User
from django.template.loader import render_to_string
from django.core.mail import EmailMultiAlternatives
from django.conf import settings
from apps.rss_feeds.models import Feed
from apps.analyzer.tasks import EmailPopularityQuery
from utils import log as logging

class FeatureCategory(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    feed = models.ForeignKey(Feed, on_delete=models.CASCADE)
    feature = models.CharField(max_length=255)
    category = models.CharField(max_length=255)
    count = models.IntegerField(default=0)
    
    def __str__(self):
        return '%s - %s (%s)' % (self.feature, self.category, self.count)

class Category(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    feed = models.ForeignKey(Feed, on_delete=models.CASCADE)
    category = models.CharField(max_length=255)
    count = models.IntegerField(default=0)
    
    def __str__(self):
        return '%s (%s)' % (self.category, self.count)


class MPopularityQuery(mongo.Document):
    email = mongo.StringField()
    query = mongo.StringField()
    is_emailed = mongo.BooleanField()
    creation_date = mongo.DateTimeField(default=datetime.datetime.now)
    
    meta = {
        'collection': 'popularity_query',
        'allow_inheritance': False,
    }
    
    def __str__(self):
        return "%s - \"%s\"" % (self.email, self.query)

    def queue_email(self):
        EmailPopularityQuery.delay(pk=str(self.pk))
    
    @classmethod
    def ensure_all_sent(cls, queue=True):
        for query in cls.objects.all().order_by('creation_date'):
            query.ensure_sent(queue=queue)
            
    def ensure_sent(self, queue=True):
        if self.is_emailed:
            logging.debug(" ---> Already sent %s" % self)
            return
        
        if queue:
            self.queue_email()
        else:
            self.send_email()
        
    def send_email(self, limit=5000):
        filename = Feed.xls_query_popularity(self.query, limit=limit)
        xlsx = open(filename, "r")
        
        params = {
            'query': self.query
        }
        text    = render_to_string('mail/email_popularity_query.txt', params)
        html    = render_to_string('mail/email_popularity_query.xhtml', params)
        subject = "Keyword popularity spreadsheet: \"%s\"" % self.query
        msg     = EmailMultiAlternatives(subject, text, 
                                         from_email='NewsBlur <%s>' % settings.HELLO_EMAIL,
                                         to=['<%s>' % (self.email)])
        msg.attach_alternative(html, "text/html")
        msg.attach(filename, xlsx.read(), 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        msg.send()
        
        self.is_emailed = True
        self.save()
        
        logging.debug(" -> ~BB~FM~SBSent email for popularity query: %s" % self)

import pandas as pd
from sklearn.preprocessing import LabelEncoder, MinMaxScaler
from sklearn.model_selection import train_test_split
from deepctr.models import DeepFM
import deepctr.feature_column
from deepctr.feature_column import SparseFeat, DenseFeat
import ast
from pickle import load
import keras
import numpy as np
from deepctr.layers import custom_objects
import sys
        
# This class is a place to store the current feeds in the model
# We need to insure we recommend feeds based on ones already in the model,
# so we should store the current ones and update the list when retrained
class MCurrentModelFeeds(models.Document):
    current_feeds = mongo.ListField(mongo.IntField())
    
    def init_feeds(self):
        self.current_feeds = list(UserSubscription.objects.order_by().values_list('feed_id', flat=True).distinct())
        
    # our function to update our feed list
    @classmethod
    def update_current_feeds(self, feeds):
        assert len(feeds) > 0
        self.current_feeds = feeds
        
class MUserFeedRecommendation(models.Model):
    user_id = mongo.IntField()
    feed_recommendations = mongo.ListField(mongo.IntField())
    followed_feeds = mongo.ListField(mongo.IntField())
    # nice check for when a bunch of users have new followed feeds not in model
    has_outside_feeds = models.BooleanField(default=False, null=True, blank=True)
    
    @classmethod
    def set_followed_feeds(self):
        self.followed_feeds = UserSubscription.objects.filter(user=self.user).feed_id
    
    def fill_recommendations(self):
        
        # First lets get our datapoints we need
        # list of all feeds followed by a user
        # get list of feeds we can recommend
        total_feeds = list(MCurrentModelFeeds.objects.values_list('current_feeds', flat=True))
        
        # iffy on this check theres no new elements
        if not set(followed_feeds).isdisjoint(set(total_feeds)):
            self.has_outside_feeds = True
       
        possible_recommendations = set(total_feeds) - set(list(self.followed_feeds))
        
        active_subs = [Feed.objects.get(pk=x).active_subscribers for x in possible_recommendations]
        premium_subs = [Feed.objects.get(pk=x).premium_subscribers for x in possible_recommendations]
        num_subs = [Feed.objects.get(pk=x).num_subscribers for x in possible_recommendations]
        average_stories_per_month = [Feed.objects.get(pk=x).average_stories_per_month for x in possible_recommendations]
        user = [self.user_id]*(len(possible_recommendations)+1)
        
        # not sure how this comes in, will have to check it out on server
        score_data = [Feed.get_by_id(x).well_read_score() for x in possible_recommendations]
        
        from constants import (
            SPARSE_FEATURES,
            DENSE_FEATURES,
            TARGET
        )
        # create our full input dataframe
        input_df = pd.DataFrame(columns=SPARSE_FEATURES + DENSE_FEATURES)
        input_df['active_subs'],input_df['num_subs'],input_df['premium_subs'] = active_subs,num_subs,premium_subs
        input_df['average_stories_per_month'],input_df['user'],input_df['feed_id'] =average_stories_per_month,user,possible_recommendations
       
        ### still have to add the rest of the features and merge
        
        assert input_df.columns == SPARSE_FEATURES + DENSE_FEATURES
        
        # get vocab sizes for SparseFeat, in the future the right way to do this might be
        # using the .classes_ field on scikit models
        # printing right now just to check
        file1 = open("myfile.txt","r+")
        sizes = file1.readlines()
        file1.close()
        updated = [x.replace('\n','') for x in sizes]
        print(updated)
        
        vocabs = {name:updated[feature_names.index(name)] for name in feature_names}

        print('vocab dict')
        print(vocabs)
        
        # normalize data
        # this must be done

        for feat in SPARSE_FEATURES:
            # need a labelEncoder for each feature
            lbe = load(open( feat + '-' + 'lbe.pkl', 'rb'))
            input_df[feat] = lbe.transform(input_df[feat])
        
        mms = MinMaxScaler(feature_range=(0,1))
        # shouldn't need to save and load an ranged features model
        #mms = load(open('minmax.pkl', 'rb'))
        input_df[DENSE_FEATURES] = mms.transform(input_df[DENSE_FEATURES])
        
        fixlen_feature_columns = [SparseFeat(feat, vocabulary_size=vocabs.get(feat),embedding_dim=8)
                       for i,feat in enumerate(SPARSE_FEATURES)] + [DenseFeat(feat, 1,)
                      for feat in DENSE_FEATURES]
        
        
        test_model_input = {name:input_df[name] for name in feature_names}

        model = keras.models.load_model('model.keras', custom_objects)

        pred_ans = model.predict(test_model_input, batch_size=256)
        
        # convert predictions to a little bit better format
        predictions = [i[0] for i in pred_ans]

        # lets sort our predictions from highest to lowest
        results = sorted(dict(zip(feeds, predictions)).items(),  key=lambda x: x[1], reverse=True)
        
        self.feed_recommendations = results[:10]
        
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
    
    def __str__(self):
        user = User.objects.get(pk=self.user_id)
        return "%s - %s/%s: (%s) %s" % (user, self.feed_id, self.social_user_id, self.score, self.title[:30])
        
            
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
    
    def __str__(self):
        user = User.objects.get(pk=self.user_id)
        return "%s - %s/%s: (%s) %s" % (user, self.feed_id, self.social_user_id, self.score, self.author[:30])

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
    
    def __str__(self):
        user = User.objects.get(pk=self.user_id)
        return "%s - %s/%s: (%s) %s" % (user, self.feed_id, self.social_user_id, self.score, self.tag[:30])
    

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
    
    def __str__(self):
        user = User.objects.get(pk=self.user_id)
        if self.feed_id:
            feed = Feed.get_by_id(self.feed_id)
        else:
            feed = User.objects.get(pk=self.social_user_id)
        return "%s - %s/%s: (%s) %s" % (user, self.feed_id, self.social_user_id, self.score, feed)
    

def compute_story_score(story, classifier_titles, classifier_authors, classifier_tags, classifier_feeds):
    intelligence = {
        'feed': apply_classifier_feeds(classifier_feeds, story['story_feed_id']),
        'author': apply_classifier_authors(classifier_authors, story),
        'tags': apply_classifier_tags(classifier_tags, story),
        'title': apply_classifier_titles(classifier_titles, story),
    }
    score = 0
    score_max = max(intelligence['title'],
                    intelligence['author'],
                    intelligence['tags'])
    score_min = min(intelligence['title'],
                    intelligence['author'],
                    intelligence['tags'])
    if score_max > 0:
        score = score_max
    elif score_min < 0:
        score = score_min

    if score == 0:
        score = intelligence['feed']
    
    return score
    
def apply_classifier_titles(classifiers, story):
    score = 0
    for classifier in classifiers:
        if classifier.feed_id != story['story_feed_id']:
            continue
        if classifier.title.lower() in story['story_title'].lower():
            # print 'Titles: (%s) %s -- %s' % (classifier.title in story['story_title'], classifier.title, story['story_title'])
            score = classifier.score
            if score > 0: return score
    return score
    
def apply_classifier_authors(classifiers, story):
    score = 0
    for classifier in classifiers:
        if classifier.feed_id != story['story_feed_id']:
            continue
        if story.get('story_authors') and classifier.author == story.get('story_authors'):
            # print 'Authors: %s -- %s' % (classifier.author, story['story_authors'])
            score = classifier.score
            if score > 0: return classifier.score
    return score
    
def apply_classifier_tags(classifiers, story):
    score = 0
    for classifier in classifiers:
        if classifier.feed_id != story['story_feed_id']:
            continue
        if story['story_tags'] and classifier.tag in story['story_tags']:
            # print 'Tags: (%s-%s) %s -- %s' % (classifier.tag in story['story_tags'], classifier.score, classifier.tag, story['story_tags'])
            score = classifier.score
            if score > 0: return classifier.score
    return score
    
def apply_classifier_feeds(classifiers, feed, social_user_ids=None):
    if not feed and not social_user_ids: return 0
    feed_id = None
    if feed:
        feed_id = feed if isinstance(feed, int) else feed.pk
    
    if social_user_ids and not isinstance(social_user_ids, list):
        social_user_ids = [social_user_ids]
        
    for classifier in classifiers:
        if classifier.feed_id == feed_id:
            # print 'Feeds: %s -- %s' % (classifier.feed_id, feed.pk)
            return classifier.score
        if (social_user_ids and not classifier.feed_id and 
            classifier.social_user_id in social_user_ids):
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
