import pandas as pd

SPARSE_FEATURES = ["feed_id", "user", "active", "is_premium"]

DENSE_FEATURES = ["premium_subs", "active_subs", "num_subs", "read_pct", "reader_count", "reach_score", "story_count", "share_count", "average_stories_per_month", 'active_premium_subscribers']

TARGET = ['is_following_feed']
# need to save vocabulary sizes to use in creating features
#Columns must be the same as SPARSE_FEATURES
