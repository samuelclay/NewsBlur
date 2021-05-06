import pandas as pd
import numpy as np
import tensorflow as tf
import math
from pandas import DataFrame
from ncf-util import mask_first
class DataLoader(object):
    def __init__(self, path):
        self.path = path

    def load_ncf_data(self):
        if path is None:
            raise RuntimeError

        try:
            return pd.read_csv(self.path)
        except Exception:
            raise ValueError

    def shrink_users_df(self,df,user_id='user', amount=.12):
        userIds = np.random.choice(df[user_id].unique(),
                                        size=int(len(df[user_id].unique())*amount),
                                        replace=False)
        return df.loc[df[user_id].isin(userIds)]

    def add_negative_samples(self, df, item_tag, user_tag,label_tag):

        updated_df = pd.DataFrame(columns=[user_tag,item_tag,label_tag])
        all_feeds = df[item_tag].unique()
        users, items, labels = [], [], []

        user_item_set = set(zip(df[user_tag], df[item_tag]))
        num_negatives = 6

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
