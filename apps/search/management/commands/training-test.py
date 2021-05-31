from django.core.management.base import BaseCommand, CommandError
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

import pandas as pd
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
    Separate function to get the specific users and feeds we need
    This is where are any changes to the input should happen, in terms of changes

    General idea is to have as many feeds in training as possible
    Feeds cannot be recommended unless seen in training
    '''
    def get_users_feeds():
        # grab all the user/feed that are active
        df = DataFrame(list(UserSubscription.objects.filter(active=True).values('user','feed_id')))

        # remove feeds where only 1 person is subscribed
        # this number will be adjusted to improve results
        df = df[df.groupby('feed_id').feed_id.transform(len) > 1]

        '''
        TO ADD:
        Remove users if low following count, improves training time and results
        '''

        # add is_following_feed label
        df.loc[:, 'is_following_feed'] = 1

        return df

    '''
    Fixes issue where LBE complains about never seeing item

    Creates LBE based on largest value

    that final one might need to be adjusted,
    length of the actual element, which should be 1 for all our data
    '''
    def set_lbe(col):
        max = col.max() + 1
        return np.arange(0,max,1)

    '''
    Functionality to add negative samples to training model
    Dataframe is only positive interactions before this Functionality

    TO DO:
    Results could in theory be improved by better choices for feeds,
    probability of positive feed overlap is low, but possible
    '''
    def add_negative_samples(df, item_tag, user_tag,label_tag, num_negs=6):

        updated_df = pd.DataFrame(columns=[user_tag,item_tag,label_tag])
        all_feeds = df[item_tag].unique()
        users, items, labels = [], [], []

        user_item_set = set(zip(df[user_tag], df[item_tag]))
        num_negatives = num_negs

        for (u, i) in user_item_set:
            users.append(u)
            items.append(i)
            labels.append(1) # items that the user has interacted with are positive
            for _ in range(num_negatives):
                # randomly select an item
                negative_item = np.random.choice(all_feeds)
                # check that the user has not interacted with this item
                while (u, negative_item) in user_item_set:
                    negative_item = np.random.choice(all_feeds)
                users.append(u)
                items.append(negative_item)
                labels.append(0) # items not interacted with are negative
        updated_df[user_tag] = users
        updated_df[item_tag] = items
        updated_df[label_tag] = labels
        del df
        return updated_df

    '''
    Defines LR schedule
    takes in current epoch num
    '''
    def schedule(epoch):
        if epoch < 30:
            return 0.001
        elif epoch < 37:
            return 0.0008
        else:
            return 0.0005

    '''
    HR based evaluation: As seen here and other academic papers: https://arxiv.org/pdf/2010.01258.pdf

    Given our input contains negative samples, we must remove them
    Look ahead bias not accounted for, can be added easily when spliting dfs
    Currently just prints the results @ 10-HR

    Current baseline for Tensorflows model is .63 HR
    '''
    def evaluation(test, model, full_df, features):
        df = test.drop(test[test.is_following_feed != 1].index)[features]


        hits = []
        counter = 0
        input_dict = {}
        for index, test_row in df.iterrows():
            if counter > 1500:
                return
            # get rows from full df
            user_id = test_row['user']
            mask = full_df['user'] == user_id
            # full_df[mask]

            items = list(full_df[mask]['feed_id'])

            #selected_not_interacted_list(full_df[full_df['user'] != user_id], features)

            not_interacted_items = set(full_df['feed_id'].unique()) - set(items)
            selected_not_interacted = list(np.random.choice(list(not_interacted_items), 99))

            # might not be sparse enough, might add 15% back from reader_count != 0.0 list to add more variation
            # not sure why I still need to subract items, I guess they should pass a mask with feeds

            if bool(len({*items} & {*selected_not_interacted})):
                raise ValueError
            input_df = pd.DataFrame(columns=features)
            # need to grab the extra data needed for
            for feed in selected_not_interacted:
                rows = full_df.loc[full_df['feed_id'] == feed]

                first = rows.iloc[0]

                input_df = input_df.append(first)


            # add our final correct one on the end

            input_df.loc[:, 'is_following_feed'] = 0
            input_df.loc[:, 'user'] = user_id
            test_row['is_following_feed'] = 1
            input_df = input_df.append(test_row)


            input_df = input_df.drop(['is_following_feed', 'Unnamed: 0'], axis=1)
            # predict with correct input format
            pred_ans = model.predict({name:input_df[name] for name in features})


            # convert predictions to a little bit better format
            predictions = [i[0] for i in pred_ans]

            feeds = input_df['feed_id'].tolist()

            results = sorted(dict(zip(feeds, predictions)).items(),  key=lambda x: x[1], reverse=True)
            counter = counter + 1
            if counter % 100 == 0:
                print('we are at step: ' + str(counter))
                print("the hit ratio at this step is {:.2f}".format(np.average(hits)))

            top10_items = [i[0] for i in results[0:10]]
            if test_row['feed_id'] in top10_items:
                hits.append(1)
    #         print('we hit for feed: ' + str(u))
            else:
                hits.append(0)
    #         print('we missed for feed: ' + str(u))

        print("The Hit Ratio @ 10 is {:.2f}".format(np.average(hits)))

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
        feed_df = pd.DataFrame([feed_],columns=list(feed_[0].keys()))
        feed_df['feed_id'] = feeds

        users = df['user'].unique()

        user_df = pd.DataFrame(users,['user'])
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




        '''
        create our LabelEncoders and MMS
        These might be slighly adjusted as I work through how to get any feed number < max num + 1

        includes new function to include any possible input under largest input
        ex. Largest user id is 608092, so any user id under that can now be passed in, no matter seen in training or not
        Users/feeds not seen in do not perform as well, as any relationship has not been learned for that user/feed,
        but they can now be passed in without errors thrown
        '''

        for feat in sparse_features:
            lbe = LabelEncoder()
            lbe.fit(set_lbe(df[feat]))
            df[feat] = lbe.transform(df[feat])
            #df[feat] = lbe.fit_transform(df[feat])
            dump(lbe, open(feat + '-' + 'lbe.pkl', 'wb'))


        mms = MinMaxScaler(feature_range=(0,1))
        df[dense_features] = mms.fit_transform(df[dense_features])

        # For sparse features, we transform them into dense vectors by embedding techniques. For dense numerical features,
        # we concatenate them to the input tensors of fully connected layer.
        fixlen_feature_columns = [SparseFeat(feat, vocabulary_size=df[feat].max() + 1,embedding_dim=16)
                       for i,feat in enumerate(sparse_features)] + [DenseFeat(feat, 1,)
                      for feat in dense_features]

        print(type(fixlen_feature_columns))
        print(fixlen_feature_columns[2])

        # I know this doesn't do much, but future runs can contain varlen columns, which get appended here
        linear_feature_columns = fixlen_feature_columns
        dnn_feature_columns = fixlen_feature_columns

        feature_names = deepctr.feature_column.get_feature_names(linear_feature_columns + dnn_feature_columns)


        train, test = train_test_split(data, test_size=0.2, random_state=2020)
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
        checkpointer = ModelCheckpoint(monitor='val_binary_crossentropy',filepath='model.keras', verbose=1, save_best_only=True)
        model.compile(optimizer, "binary_crossentropy", metrics=['binary_crossentropy'], )

        history = model.fit(train_model_input, train[target].values,
                        batch_size=256, epochs=35, verbose=2, validation_split=0.2, callbacks = [checkpointer, lr_scheduler])

        '''
        Let's evaluate the model we just trained
        Assuming its still in memory, as well as a test dataset
        '''

        evaluation(test, model, data, sparse_features + dense_features)
