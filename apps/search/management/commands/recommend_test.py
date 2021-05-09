import pandas as pd
from django.core.management.base import BaseCommand, CommandError
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
from apps.search.constants import (
    SPARSE_FEATURES,
    DENSE_FEATURES,
    TARGET

)
import mongoengine as mongo
from django.db import models
from apps.reader.models import UserSubscription
from apps.analyzer.models import MCurrentModelFeeds
from apps.rss_feeds.models import Feed
from apps.social.models import MSharedStory
from apps.profile.models import Profile

class Command(BaseCommand):

    def add_arguments(self, parser):
        parser.add_argument("-u", "--user", dest="user", default=None)

    def handle(self, *args, **options):
        if options['user']:
            user_id = options['user']
        feeds = list(UserSubscription.objects.order_by().values_list('feed_id', flat=True).distinct())
        feeds = feeds[:250000]
        assert isinstance(feeds, list)
        rec_num = 10
        followed_feeds = list(UserSubscription.objects.filter(user=user_id).values_list('feed_id', flat=True))
        possible_recommendations = set(feeds) - set(followed_feeds)

        feed_ = []
        for x in possible_recommendations:
            feed_items = {}
            feed_object = Feed.objects.get(pk=x)
            feed_items['active_subs'] = feed_object.active_subscribers
            feed_items['premium_subs'] = feed_object.premium_subscribers
            feed_items['num_subs'] = feed_object.num_subscribers
            feed_items['average_stories_per_month'] = feed_object.average_stories_per_month
            feed_items['active_premium_subscribers'] = feed_object.active_premium_subscribers
            feed_items['active'] = feed_object.active
            temp = Feed.get_by_id(x).well_read_score()
            feed_items['read_pct'] = temp['read_pct']
            feed_items['reader_count'] = temp['reader_count']
            feed_items['reach_score'] = temp['reach_score']
            feed_items['story_count'] = temp['story_count']
            feed_items['share_count'] = temp['share_count']
            del temp
            # might be the same as share_count, leaving it in for now
            feed_items['total_shares_per_feed'] = MSharedStory.objects.filter(story_feed_id=x).count()
            feed_.append(feed_items)


        #active_subs = [Feed.objects.get(pk=x).active_subscribers for x in possible_recommendations]
        # premium_subs = [Feed.objects.get(pk=x).premium_subscribers for x in possible_recommendations]
        #num_subs = [Feed.objects.get(pk=x).num_subscribers for x in possible_recommendations]
        #average_stories_per_month = [Feed.objects.get(pk=x).average_stories_per_month for x in possible_recommendations]

        user = [user_id]*(len(possible_recommendations)+1)
        is_premium = Profile.objects.get(user_id=user_id).is_premium
        # not sure how this comes in, will have to check it out on server
        #score_data = [Feed.get_by_id(x).well_read_score() for x in possible_recommendations]
        # pretty sure its a dict
        #temp = pd.DataFrame(score_data)
        #active_premium_subscribers = [Feed.objects.get(pk=x).active_premium_subscribers for x in possible_recommendations]
        user_shared_stories_count = MSharedStory.objects.filter(user_id=self.user).count()

        # total shares_per_feed might be the same as share_count
        #total_shares_per_feed = [MSharedStory.objects.filter(story_feed_id=x).count() for x in possible_recommendations]
        print('through getting data')

        # create our full input dataframe
        input_df = pd.DataFrame(feed_,columns=SPARSE_FEATURES + DENSE_FEATURES)
        #input_df['active'] = [Feed.objects.get(pk=x).active for x in possible_recommendations]
        input_df['user'],input_df['feed_id'] =user,possible_recommendations
        input_df['user_shared_stories_count'] = [user_shared_stories_count] * len((possible_recommendations)+1)

        ### should be all the current fields
        print('through dataframe')
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

        linear_feature_columns = fixlen_feature_columns
        dnn_feature_columns = fixlen_feature_columns

        feature_names = deepctr.feature_column.get_feature_names(linear_feature_columns + dnn_feature_columns)

        test_model_input = {name:input_df[name] for name in feature_names}
        del input_df

        model = keras.models.load_model('model.keras', custom_objects)
        print('time to predict for user')
        pred_ans = model.predict(test_model_input, batch_size=256)

        # lets sort our predictions from highest to lowest
        results = sorted(dict(zip(feeds, predictions)).items(),  key=lambda x: x[1], reverse=True)

        # lets grab the top x amount of feeds
        self.feed_recommendations = results[:rec_num]
        return
