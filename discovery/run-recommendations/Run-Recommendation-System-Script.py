#!/usr/bin/env python
# coding: utf-8

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
from constants import (
    SPARSE_FEATURES,
    DENSE_FEATURES,
    TARGET

)

user = sys.argv[1]
# takes in list of feeds
feeds = sys.argv[2]
assert type(feeds) == list()

#feeds = list(UserSubscription.objects.filter(user=user).values('feed_id'))

active_subs = [Feed.objects.get(pk=x).active_subscribers for x in feeds]

premium_subs = [Feed.objects.get(pk=x).premium_subscribers for x in feeds]

num_subs = [Feed.objects.get(pk=x).num_subscribers for x in feeds]

average_stories_per_month = [Feed.objects.get(pk=x).average_stories_per_month]

score_data = [Feed.get_by_id(x).well_read_score() for x in feeds]
# [Profile.objects.get(user_id=x).is_premium for x in uniques]
scores = pd.DataFrame(columns=['scores', 'feed_id'])
scores['scores'] = score_data
scores['scores'] = scores['scores'].apply(lambda x: ast.literal_eval(x))
df2 = pd.json_normalize(scores['scores'])
df2['feed_id'] = scores['feed_id']

# get total shares per feed csv is shares.csv
#shares = [MSharedStory.objects.filter(story_feed_id=x).count() for x in feeds]

input_df = pd.DataFrame(columns=SPARSE_FEATURES + DENSE_FEATURES)
input_df['feed_id'] = feeds
input_df['user'] = [user] * len(feeds)
input_df['active_subs'] = active_subs
input_df['num_subs'] = num_subs
input_df['average_stories_per_month'] = average_stories_per_month

input_df = input_df.merge(df2[['read_pct', 'feed_id', 'reader_count', 'reach_score', 'story_count', 'share_count']], how = 'left',
                    left_on = 'feed_id', right_on = 'feed_id')

# scores['scores'] = scores['scores'].apply(lambda x: ast.literal_eval(x))
# df2 = pd.json_normalize(scores['scores'])
# df2['feed_id'] = scores['feed_id']

# assert len(df2) != 0

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

# mms = load(open('minmax.pkl', 'rb'))
# lbe = load(open('lbe.pkl', 'rb'))
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

linear_feature_columns = fixlen_feature_columns
dnn_feature_columns = fixlen_feature_columns

feature_names = deepctr.feature_column.get_feature_names(linear_feature_columns + dnn_feature_columns)

test_model_input = {name:input_df[name] for name in feature_names}

model = keras.models.load_model('model.keras', custom_objects)

pred_ans = model.predict(test_model_input, batch_size=256)

# Some loss values from our run
from sklearn.metrics import log_loss, roc_auc_score
print("test LogLoss", round(log_loss(test[target].values, pred_ans), 4))
print("test AUC", round(roc_auc_score(test[target].values, pred_ans), 4))

# convert predictions to a little bit better format
predictions = [i[0] for i in pred_ans]

# feeds = input_df['feed_id'].tolist()


# lets sort our predictions from highest to lowest
results = sorted(dict(zip(feeds, predictions)).items(),  key=lambda x: x[1], reverse=True)

# this last step can be whatever you want to do with the recommendations
pd.DataFrame(results, columns = ['feed_id', 'predictions']).to_csv('results.csv')
