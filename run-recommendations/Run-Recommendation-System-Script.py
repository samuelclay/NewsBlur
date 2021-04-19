#!/usr/bin/env python
# coding: utf-8

# In[ ]:


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

from constants import (
    SPARSE_FEATURES,
    DENSE_FEATURES,
    TARGET,
    VOCABULARY_SIZE 

)




# pass in a user and a few feeds to figure out which ones they would want to follow, must have the other datapoints to match
try:
    data = pd.read_csv('run-csv.csv')
except Exception as e:
    print('exception occured, make sure you have the required csv')
    

# scores['scores'] = scores['scores'].apply(lambda x: ast.literal_eval(x))
# df2 = pd.json_normalize(scores['scores'])
# df2['feed_id'] = scores['feed_id']

# assert len(df2) != 0

assert data.columns == SPARSE_FEATURES + DENSE_FEATURES + TARGET


# normalize data
# this must be done 

# mms = load(open('minmax.pkl', 'rb'))
# lbe = load(open('lbe.pkl', 'rb'))
for feat in SPARSE_FEATURES:
    
        # need a labelEncoder for each feature
        lbe = load(open( feat + '-' + 'lbe.pkl', 'rb'))
        data[feat] = lbe.fit_transform(data[feat])
        
#mms = MinMaxScaler(feature_range=(0,1))
mms = load(open('minmax.pkl', 'rb'))
data[DENSE_FEATURES] = mms.fit_transform(data[DENSE_FEATURES])


# values will be different here than when trained, need to make a schema of the trained data to use here
# different as less feeds and only one user
fixlen_feature_columns = [SparseFeat(feat, vocabulary_size=data[feat].max() + 1,embedding_dim=4)
                       for i,feat in enumerate(SPARSE_FEATURES)] + [DenseFeat(feat, 1,)
                      for feat in DENSE_FEATURES]



linear_feature_columns = fixlen_feature_columns
dnn_feature_columns = fixlen_feature_columns


feature_names = deepctr.feature_column.get_feature_names(linear_feature_columns + dnn_feature_columns)


test_model_input = {name:data[name] for name in feature_names}


model = keras.models.load_model('model.keras', custom_objects)


pred_ans = model.predict(test_model_input, batch_size=256)




# Some loss values from our run
from sklearn.metrics import log_loss, roc_auc_score
print("test LogLoss", round(log_loss(test[target].values, pred_ans), 4))
print("test AUC", round(roc_auc_score(test[target].values, pred_ans), 4))


# convert predictions to a little bit better format
predictions = [i[0] for i in pred_ans]

feeds = input_df['feed_id'].tolist()

# lets sort our predictions from highest to lowest
results = sorted(dict(zip(feeds, predictions)).items(),  key=lambda x: x[1], reverse=True)


# this last step can be whatever you want to do with the recommendations
pd.DataFrame(results, columns = ['feed_id', 'predictions']).to_csv('results.csv')

