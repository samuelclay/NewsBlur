import pandas as pd
from pandas import DataFrame
import ast
'''
A file containing different functions and lines to grab data
to train the model

'''


# table_name ex: FeedData
# columns is list of columns from the table ['popular_tags', 'feed']
def get_df_from_database(table_name, columns):
    return DataFrame(list(table_name.objects.values(columns)))


# list of dataframes to combine
def combine_table_dfs_together(dfs):
    if len(dfs) > 1:
        main = dfs.pop(0)
        for df in dfs:
            for column in df:
                main[column] = df[column]
        return main
    return dfs.pop(0)

#get user ids + feeds they subscribe to
df = get_df_from_database('UserSubscription', ['user','feed_id'])



df = DataFrame(list(UserSubscription.objects.values('user','feed_id')))

# randomly choose users to make data manageable for now

userIds = np.random.choice(df_users['user'].unique(),
                                size=int(len(df_users['user'].unique())*0.35),
                                replace=False)

df_users = df_users.loc[df_users['user'].isin(userIds)]

# add a followed_feed column, all will be 1 for now but we will add negatives later
df.loc[:, 'is_following_feed'] = 1



#map = dict(zip(categories.feed_id, categories.feed_id))

#create df of feed_id and popular_tags

ids = list(FeedData.objects.values('feed_id'))
input = list(FeedData.objects.values('popular_tags'))
import ast
#remove Nones from popular_tags
def try_conversion(x):
    try:
        return ast.literal_eval(x)
    except Exception as e:
        return []

def define_bad_tags(x):
    if x == [] or '[]' or None:
        return True
    return False

input = [try_conversion(x.get('popular_tags')) for x in input]
df['cities'] = df['cities'].apply(lambda x: ast.literal_eval(x))

ids = [x.get('feed_id') for x in ids]

tags_df = pd.DataFrame(columns=['feed_id','popular_tags'])
tags_df['feed_id'] = ids
tags_df['popular_tags'] = input

#remove feeds with empty tags, or uncategorized, can add [] back in in the main dataset:
df_new = tags_df[tags_df['popular_tags'].map(lambda x: x != [])]
df = df[df['popular_tags'].map(lambda x: x != ['uncategorized'])]


# take just top 3 feeds, and convert the dict pair to strings
def polish_top_tags(x):
    fixed = x[:3]
    return [x[0] for x in x[:3]]


tags_df['popular_tags'] = df_new['popular_tags'].map(lambda x: polish_top_tags(x))

df_new['popular_tags'] = tags_df

# popular_tags comes in as a string looking like a list, can convert to real list with:
import ast
ast.literal_eval(df['popular_tags'][0])
tags_df['popular_tags'].str.len().mean()




# Getting num_active_subscribers
value = Feed.objects.get(pk=13).active_subscribers

def get_active_subs(feed_id):
    return Feed.objects.get(pk=feed_id).active_subscribers


# this might work it takes forever to run:
df['feed_active_subs'] = df['feed_id'].apply(lambda x: Feed.objects.get(pk=x).active_subscribers)

df['feed_active_subs'] = df['feed_id'].apply(get_active_subs)
for (u, i) in user_item_set:
    users.append(u)
    items.append(i)
    labels.append(1) # items that the user has interacted with are positive
    for _ in range(num_negatives):
        # randomly select an item
        negative_item = np.random.choice(all_ids)
        # check that the user has not interacted with this item
        while (u, negative_item) in user_item_set:
            negative_item = np.random.choice(all_ids)
        users.append(u)
        items.append(negative_item)
        labels.append(0) # items not interacted with are negative
