## file to define data flowing into model
import pandas as pd
import numpy as np
from pandas import DataFrame
import math
import tensorflow as tf
import ast
import pytorch_lightning as pl

def get_users_to_feeds(file):
    return pd.read_csv(file)


def shrink_users_df(df,user_id):
    userIds = np.random.choice(df[user_id].unique(),
                                    size=int(len(df[user_id].unique())*0.35),
                                    replace=False)
    return df.loc[df[user_id].isin(userIds)]


def add_negative_samples(df, item_tag, user_tag,label_tag):

    updated_df = pd.DataFrame(columns=[user_tag,item_tag,label_tag])
    all_feeds = df[item_tag].unique()
    users, items, labels = [], [], []

    user_item_set = set(zip(df[user_tag], df[item_tag]))
    num_negatives = 2

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

def mask_first(x):
    """
    Return a list of 0 for the first item and 1 for all others
    """
    result = np.ones_like(x)
    result[0] = 0

    return result
# needs to add validate in the future
def train_test_split(full_df):
    df_test = df.copy(deep=True)
    df_test = df_test.groupby(['user']).first()

    df_test['user'] = df_test.index
    df_test = df_test[['user', 'feed_id','is_following_feed']]
    df_test = df_test.rename_axis(None, axis=1)

    df_train = df.copy(deep=True)
    mask = df.groupby(['user'])['user'].transform(mask_first).astype(bool)

    df_train = df.loc[mask]
    return df_train, df_test





df = get_users_to_feeds('users-feeds.csv')

df = shrink_users_df(df, 'user')

print(len(df))

df.loc[:, 'is_following_feed'] = 1

print(df.head())

df = add_negative_samples(df,'feed_id','user','is_following_feed')

print(df.sample(10))


df_train, df_test = train_test_split(df)

print(df_train.sample(10))

from ncfImpl import NCF



## run a model
num_users = df['user'].max()+1
num_feeds = df['feed_id'].max()+1
all_feed_ids = df['feed_id'].unique()

model = NCF(num_users, num_feeds, df_train, all_feed_ids)

trainer = pl.Trainer(max_epochs=5, gpus=0, reload_dataloaders_every_epoch=True,
                     progress_bar_refresh_rate=50, logger=False, checkpoint_callback=False)

trainer.fit(model)
