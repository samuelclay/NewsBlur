import keras
import numpy as np
from deepctr.layers import custom_objects

import pandas as pd
from pandas import DataFrame
from sklearn.preprocessing import LabelEncoder, MinMaxScaler

'''
Not sure I can call functions defined in the Commands class
Moving functions here for now
'''

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
