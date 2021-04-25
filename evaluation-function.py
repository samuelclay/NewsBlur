#!/usr/bin/env python
# coding: utf-8

# In[ ]:


""" evaluaton function for DeepFM architecture
    test: test dataframe, negative interactions are removed
    model: DeepFM model 
    full_df: full dataframe used to train model, this can also be any dataframe
             that has negative interactions for us to use
    features: column features we use in training
    
    Prints: TopK evaluation @10 at each step with final evaluation printed at end
"""
def evaluation(test, model, full_df, features):
    df = test.drop(test[test.is_following_feed != 1].index)[features]

    
    hits = []
    counter = 0
    input_dict = {}
    for index, test_row in df.iterrows():
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

