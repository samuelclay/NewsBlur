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
class MCurrentModelFeeds(mongo.Document):
    current_feeds = mongo.ListField(mongo.IntField())
    
    def init_feeds(self):
        self.current_feeds = list(UserSubscription.objects.order_by().values_list('feed_id', flat=True).distinct())
        
    # our function to update our feed list
    @classmethod
    def update_current_feeds(self, feeds):
        assert len(feeds) > 0
        self.current_feeds = feeds
        
class MUserFeedRecommendation(mongo.Document):
    user_id = mongo.IntField()
    feed_recommendations = mongo.ListField(mongo.IntField())
    followed_feeds = mongo.ListField(mongo.IntField())
    # nice check for when a bunch of users have new followed feeds not in model
    has_outside_feeds = models.BooleanField(default=False, null=True, blank=True)
    
    meta = {
        'collection': 'classifier_feedrecommendations',
        'indexes': [('user_id'), 'user_id'],
        'allow_inheritance': False,
    }
    
    def __str__(self):
        user = User.objects.get(pk=self.user_id)
        return "%s - %s/%s: (%s) %s" % (user, self.feed_recommendations, self.followed_feeds, self.has_outside_feeds)
    
    # quick function to set this
    def check_outside_feeds(self):
        # not sure if I need to wrap the MCurrentModelFeeds in a list()
        if set(self.followed_feeds).issubset(set(MCurrentModelFeeds.objects.values_list('current_feeds', flat=True))):
            self.has_outside_feeds = False
        else:
            self.has_outside_feeds = True
    
    @classmethod
    def set_followed_feeds(self):
        self.followed_feeds = UserSubscription.objects.values_list('feed_id', flat=True).filter(user=self.user)
    
    def fill_recommendations(self, rec_num=10):
        
        # First lets get our datapoints we need
        # list of all feeds followed by a user
        # get list of feeds we can recommend
        # does require that we have an updated list of feeds
        total_feeds = list(MCurrentModelFeeds.objects.values_list('current_feeds', flat=True))
        # can either raise issue and return, or just grab all the feeds from other parts of db
        if len(total_feeds) == 0:
            raise exception('Unable to get list of feeds the model is trained on, this could be caused by an error')
            return
        
        # should check if theres new feeds the user follows that aren't in the total_feeds,
        # we don't need the followed feeds to run the model, but it could cause issues in the recommendations,
        # especially if there user doesn't follow alot of feeds
        if not set(followed_feeds).issubset(set(total_feeds)):
            self.has_outside_feeds = True
       
        possible_recommendations = set(total_feeds) - set(list(self.followed_feeds))
        
        active_subs = [Feed.objects.get(pk=x).active_subscribers for x in possible_recommendations]
        premium_subs = [Feed.objects.get(pk=x).premium_subscribers for x in possible_recommendations]
        num_subs = [Feed.objects.get(pk=x).num_subscribers for x in possible_recommendations]
        average_stories_per_month = [Feed.objects.get(pk=x).average_stories_per_month for x in possible_recommendations]
        user = [self.user_id]*(len(possible_recommendations)+1)
        is_premium = Profile.objects.get(user_id=user).is_premium
        # not sure how this comes in, will have to check it out on server
        score_data = [Feed.get_by_id(x).well_read_score() for x in possible_recommendations]
        # pretty sure its a dict
        temp = pd.DataFrame(score_data)
        
        active_premium_subscribers = [Feed.objects.get(pk=x).active_premium_subscribers for x in possible_recommendations]
        user_shared_stories_count = MSharedStory.objects.filter(user_id=self.user).count()
        
        # total shares_per_feed might be the same as share_count
        total_shares_per_feed = [MSharedStory.objects.filter(story_feed_id=x).count() for x in possible_recommendations]
        from constants import (
            SPARSE_FEATURES,
            DENSE_FEATURES,
            TARGET
        )
        # create our full input dataframe
        input_df = pd.DataFrame(columns=SPARSE_FEATURES + DENSE_FEATURES)
        input_df['read_pct'],input_df['reader_count'],input_df['reach_score'] = temp['read_pct'],temp['reader_count'],temp['reach_score']
        input_df['story_count'],input_df['share_count'] = temp['story_count'],temp['share_count']
        del temp
        input_df['active'] = [Feed.objects.get(pk=x).active for x in possible_recommendations]
        input_df['active_subs'],input_df['num_subs'],input_df['premium_subs'] = active_subs,num_subs,premium_subs
        input_df['average_stories_per_month'],input_df['user'],input_df['feed_id'] =average_stories_per_month,user,possible_recommendations
        input_df['is_premium'] = [is_premium] * (len(possible_recommendations)+1)
        input_df['active_premium_subscribers'] = active_premium_subscribers
        input_df['user_shared_stories_count'] = [user_shared_stories_count] * len((possible_recommendations)+1)
        input_df['total_shares_per_feed'] = total_shares_per_feed
        ### should be all the current fields
        
        assert input_df.columns == SPARSE_FEATURES + DENSE_FEATURES


        # normalize data
        # this must be done
        # no need anymore for reading/writing vocab sizes to file, figured it out
        vocabs = {}
        for feat in SPARSE_FEATURES:
            # need a labelEncoder for each feature
            lbe = load(open( feat + '-' + 'lbe.pkl', 'rb'))
            input_df[feat] = lbe.transform(input_df[feat])
            vocabs[feat] = len(lbe.classes_)
        
        mms = MinMaxScaler(feature_range=(0,1))
        # shouldn't need to save and load a ranged numerical features model like minmaxscaler
        #mms = load(open('minmax.pkl', 'rb'))
        input_df[DENSE_FEATURES] = mms.transform(input_df[DENSE_FEATURES])
        
        fixlen_feature_columns = [SparseFeat(feat, vocabulary_size=vocabs[feat],embedding_dim=16)
                       for i,feat in enumerate(SPARSE_FEATURES)] + [DenseFeat(feat, 1,)
                      for feat in DENSE_FEATURES]
        
        
        test_model_input = {name:input_df[name] for name in feature_names}
        # might not use this delete, trying to reduce memory before we run model
        del input_df
        model = keras.models.load_model('model.keras', custom_objects)
        
        # predict probability for each feed
        pred_ans = model.predict(test_model_input, batch_size=256)
        
        # convert predictions to a little bit better format
        predictions = [i[0] for i in pred_ans]

        # lets sort our predictions from highest to lowest
        results = sorted(dict(zip(feeds, predictions)).items(),  key=lambda x: x[1], reverse=True)
        # lets grab the top x amount of feeds
        self.feed_recommendations = results[:rec_num]
        
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
