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
            users = options['user'].split(',')
            users = list(users)
            users = [int(x) for x in users]
            print('num of users for run: ' + str(len(users)))

            lbe = load(open( 'feed_id' + '-' + 'lbe.pkl', 'rb'))
            feeds = list(lbe.classes_)
            #feeds = feeds[:2000]
            print(len(lbe.classes_))
            assert isinstance(feeds, list)
            rec_num = 10
            #followed_feeds = list(UserSubscription.objects.filter(user=user_id).values_list('feed_id', flat=True))
            #possible_recommendations = set(feeds) - set(followed_feeds)

            feed_ = []
            for x in feeds:
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
                feed_items['feed_id'] = x
                del temp
                # might be the same as share_count, leaving it in for now
                feed_items['total_shares_per_feed'] = MSharedStory.objects.filter(story_feed_id=x).count()
                feed_.append(feed_items)
            print('through the loop')
            # this is all data for data points that are feed data specific
            # add this key so we can run model on correct feeds after they've been transformed
            feed_info = pd.DataFrame(feed_,columns=list(feed_[0].keys()) + ['feed_id-key'])
            feed_info['feed_id-key'] = feeds

            vocabs = {}
            for feat in list(set(feed_info.columns) & set(SPARSE_FEATURES)):
                # need a labelEncoder for each feature
                lbe = load(open( feat + '-' + 'lbe.pkl', 'rb'))
                print(feat)
                print(lbe.classes_)
                feed_info[feat] = lbe.transform(feed_info[feat])
                vocabs[feat] = len(lbe.classes_)



            for user_id in users:
                '''
                Get user specific info, and transform it
                '''
                followed_feeds = list(UserSubscription.objects.filter(user=user_id).values_list('feed_id', flat=True))
                possible_recommendations = set(feeds) - set(followed_feeds)
                user = [user_id]*(len(possible_recommendations))
                is_premium = Profile.objects.get(user_id=user_id).is_premium
                user_shared_stories_count = MSharedStory.objects.filter(user_id=user_id).count()



                '''
                now we can creat the input df, without making as many db calls
                need to remove rows where followed feeds are, as feed_ has all feeds
                '''
                input_df = feed_info[feed_info['feed_id-key'].map(lambda x: x not in followed_feeds)]

                print('possible_recommendations length:' + str(len(possible_recommendations)))
                print('input_df length: ' + str(len(input_df)))

                assert followed_feeds not in input_df['feed_id-key'].tolist()

                input_df['user'] = user
                input_df['is_premium'] = [is_premium] * len(possible_recommendations)
                input_df['user_shared_stories_count'] = [user_shared_stories_count] * len(possible_recommendations)


                ### should be all the current fields
                print('through dataframe')
                print(len(input_df.columns))
                print(SPARSE_FEATURES + DENSE_FEATURES)

                mms = MinMaxScaler(feature_range=(0,1))
                # shouldn't need to save and load a ranged numerical features model like minmaxscaler
                #mms = load(open('minmax.pkl', 'rb'))
                input_df[DENSE_FEATURES] = mms.fit_transform(input_df[DENSE_FEATURES])

                remaining = set(SPARSE_FEATURES) - set(vocabs.keys())
                print(remaining)
                items = {}
                for feat in remaining:
                    # need a labelEncoder for each feature
                    lbe = load(open( feat + '-' + 'lbe.pkl', 'rb'))
                    print(feat)
                    print(lbe.classes_)
                    input_df[feat] = lbe.transform(input_df[feat])
                    items[feat] = len(lbe.classes_)
                vocabs_ = {**vocabs, **items}


                fixlen_feature_columns = [SparseFeat(feat, vocabulary_size=vocabs_[feat],embedding_dim=16)
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
                results = sorted(dict(zip(feeds,pred_ans)).items(),  key=lambda x: x[1], reverse=True)

                # lets grab the top x amount of feeds
                #self.feed_recommendations = results[:rec_num]
                print('results for user: ' + str(user_id))
                print(results[:rec_num])
