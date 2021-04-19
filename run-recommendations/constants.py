#!/usr/bin/env python
# coding: utf-8

# In[ ]:


import pandas as pd

SPARSE_FEATURES = ["feed_id", "user"]

DENSE_FEATURES = ["premium_subs", "active_subs", "num_subs", "read_pct", "reader_count", "reach_score", "story_count", "share_count", "average_stories_per_month"]

TARGET = ['is_following_feed']
# need to save vocabulary sizes to use in creating features
#Columns must be the same as SPARSE_FEATURES
VOCABULARY_SIZE = pd.DataFrame([608038,8112587], columns = ['user', 'feed_id'])

