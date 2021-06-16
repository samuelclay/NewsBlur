from django.core.management.base import BaseCommand, CommandError
import keras
import numpy as np
from deepctr.layers import custom_objects
import sys
import tensorflow as tf
from apps.search.constants import (
    SPARSE_FEATURES,
    DENSE_FEATURES,
    TARGET

)
from apps.recommendations.recoFunctions import (
    get_users_feeds,
    set_lbe,
    add_negative_samples,
    schedule,
    evaluation


)
import mongoengine as mongo
from django.db import models
from apps.reader.models import UserSubscription
from apps.analyzer.models import MCurrentModelFeeds
from apps.rss_feeds.models import Feed
from apps.social.models import MSharedStory
from apps.profile.models import Profile

import pandas as pd
from pandas import DataFrame
from sklearn.preprocessing import LabelEncoder, MinMaxScaler
from sklearn.model_selection import train_test_split
from deepctr.models import DeepFM, xDeepFM
import deepctr.feature_column
from deepctr.feature_column import SparseFeat, DenseFeat
import ast
from pickle import dump
from keras.callbacks import ModelCheckpoint, CSVLogger, LearningRateScheduler, ReduceLROnPlateau

class Command(BaseCommand):

    '''
    Could pass embedding size, num layers, num nodes etc etc

    With new size of data we might need more layers + nodes
    '''
    def handle(self, *args, **options):

        df = get_users_feeds()
        df = add_negative_samples(df,'feed_id','user','is_following_feed')

        feeds = df['feed_id'].unique()

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
                del temp
                # might be the same as share_count, leaving it in for now
                feed_items['total_shares_per_feed'] = MSharedStory.objects.filter(story_feed_id=x).count()
                feed_.append(feed_items)
        print('through the loop')
        feed_df = pd.DataFrame(feed_,columns=list(feed_[0].keys()))
        feed_df['feed_id'] = feeds

        users = df['user'].unique()

        user_df = pd.DataFrame(users,columns=['user'])
        user_df['is_premium'] = [Profile.objects.get(user_id=x).is_premium for x in users]
        user_df['user_shared_stories_count'] = [MSharedStory.objects.filter(user_id=x).count() for x in users]



        '''
        merge into main df
        '''
        df = df.merge(user_df[['user_shared_stories_count','is_premium', 'user']], how = 'left',
                    left_on = 'user', right_on = 'user')

        df = df.merge(feed_df[feed_df.columns], how = 'left',
                    left_on = 'feed_id', right_on = 'feed_id')

        print('final columns:' + str(df.columns))

        df['active'] = df['active'].apply(lambda x: int(x == True))
        df['is_premium'] = df['is_premium'].apply(lambda x: int(x == True))


        df.to_csv('current-model-dataframe.csv')

        '''
        create our LabelEncoders and MMS
        These might be slighly adjusted as I work through how to get any feed number < max num + 1

        includes new function to include any possible input under largest input
        ex. Largest user id is 608092, so any user id under that can now be passed in, no matter seen in training or not
        Users/feeds not seen in do not perform as well, as any relationship has not been learned for that user/feed,
        but they can now be passed in without errors thrown
        '''

        for feat in SPARSE_FEATURES:
            lbe = LabelEncoder()
            lbe.fit(set_lbe(df[feat]))
            df[feat] = lbe.transform(df[feat])
            #df[feat] = lbe.fit_transform(df[feat])
            dump(lbe, open(feat + '-' + 'lbe.pkl', 'wb'))


        mms = MinMaxScaler(feature_range=(0,1))
        df[DENSE_FEATURES] = mms.fit_transform(df[DENSE_FEATURES])

        # For sparse features, we transform them into dense vectors by embedding techniques. For dense numerical features,
        # we concatenate them to the input tensors of fully connected layer.
        fixlen_feature_columns = [SparseFeat(feat, vocabulary_size=df[feat].max() + 1,embedding_dim=16)
                       for i,feat in enumerate(SPARSE_FEATURES)] + [DenseFeat(feat, 1,)
                      for feat in DENSE_FEATURES]

        print(type(fixlen_feature_columns))
        print(fixlen_feature_columns[2])

        # I know this doesn't do much, but future runs can contain varlen columns, which get appended here
        linear_feature_columns = fixlen_feature_columns
        dnn_feature_columns = fixlen_feature_columns

        feature_names = deepctr.feature_column.get_feature_names(linear_feature_columns + dnn_feature_columns)


        train, test = train_test_split(df, test_size=0.2, random_state=2020)
        train_model_input = {name:train[name] for name in feature_names}
        test_model_input = {name:test[name] for name in feature_names}

        '''
        No GPUs....
        '''
        #import tensorflow as tf
        #strategy = tf.distribute.MirroredStrategy(["GPU:0", "GPU:1", "GPU:2", "GPU:3"])

        lr_scheduler = LearningRateScheduler(schedule)
        '''
        Current model is DeepFM as defined here: https://arxiv.org/pdf/1703.04247.pdf
        Given the size of our data the number of layers we use the upgraded deep learning model

        As features count increases and more user datapoints are added this could be replaced by xDeepFM

        Models are saved as validation loss improves, to prevent overfitting
        '''
        model = DeepFM(linear_feature_columns, dnn_feature_columns, task='binary', dnn_hidden_units=(128,128,128,128)) # dnn_hidden_units=(128,128,128,128)
        optimizer = tf.keras.optimizers.Adam(learning_rate=0.001)
        checkpointer = ModelCheckpoint(monitor='val_binary_crossentropy',filepath='discovery/model.keras', verbose=1, save_best_only=True)
        model.compile(optimizer, "binary_crossentropy", metrics=['binary_crossentropy'], )

        history = model.fit(train_model_input, train[TARGET].values,
                        batch_size=256, epochs=35, verbose=2, validation_split=0.2, callbacks = [checkpointer, lr_scheduler])

        '''
        Let's evaluate the model we just trained
        Assuming its still in memory, as well as a test dataset
        '''

        evaluation(test, model, df, SPARSE_FEATURES + DENSE_FEATURES)
