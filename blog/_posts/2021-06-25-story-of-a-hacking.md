---
layout: post
title: Story of a Hacking
tags: ['backend']
---

I'd like to answer a few questions about what happened here.

 1. Was any data leaked during the hack? How do you know?
 2. How did NewsBlur's MongoDB server get hacked?
 3. What will happen to ensure this doesn't happen again?

Let's start by talking about the importance of your data. As you may know, NewsBlur is open source and enjoys the added protection of having thousands of people looking at the codebase and dozens contributing back to it. 

### 1. Was any data leaked during the hack? How do you know?

I can definitively write that no data was leaked during the hack. I know this because of two different sets of logs showing that the automated attacker only issued deletion commands and did not transfer any data off of the MongoDB server.

This is what the day looks like. This 24 graph of bandwidth shows:

<img src="/assets/hack-timeline.png" style="border: 1px solid rgba(0,0,0,0.1);">

You can imagine the stress I experienced in the forty minutes between 9:35p, when the hack began, and 10:15p, when the fresh backup snapshot was identified and put into gear. 

 1. **6:10p**: 
 2. **9:35p**: 
 3. **10:15p**: 
 4. **3:00a**: 
 5. **4:30a**: 

### 2. How did NewsBlur's MongoDB server get hacked?

It would make for a much more dramatic read if I was hit through a vulnerability in Docker instead of a footgun.

    nbset:PRIMARY> show dbs
    READ__ME_TO_RECOVER_YOUR_DATA   0.000GB
    admin                           0.000GB
    local                          16.471GB
    newsblur                        0.718GB
    
    nbset:PRIMARY> use READ__ME_TO_RECOVER_YOUR_DATA
    switched to db READ__ME_TO_RECOVER_YOUR_DATA
    
    nbset:PRIMARY> show collections
    README
    system.profile
    
    nbset:PRIMARY> db.README.find()
    { "_id" : ObjectId("60d3e112ac48d82047aab95d"), "content" : "All your data is a backed up. You must pay 0.03 BTC to XXXXXXFTHISGUYXXXXXXX 48 hours for recover it. After 48 hours expiration we will leaked and exposed all your data. In case of refusal to pay, we will contact the General Data Protection Regulation, GDPR and notify them that you store user data in an open form and is not safe. Under the rules of the law, you face a heavy fine or arrest and your base dump will be dropped from our server! You can buy bitcoin here, does not take much time to buy https://localbitcoins.com or https://buy.moonpay.io/ After paying write to me in the mail with your DB IP: FTHISGUY@recoverme.one and you will receive a link to download your database dump." }

Looking at the MongoDB access logs, we can invoke a pretty neat command to find everybody who is not one of the 100 known NewsBlur machines that has accessed MongoDB.

    $ cat /var/log/mongodb/mongod.log | egrep -v "159.65.XX.XX|161.89.XX.XX|<< SNIP: A hundred more servers >>"

    2021-06-24T01:33:45.531+0000 I NETWORK  [listener] connection accepted from 171.25.193.78:26003 #63455699 (1189 connections now open)
    2021-06-24T01:33:45.635+0000 I NETWORK  [conn63455699] received client metadata from 171.25.193.78:26003 conn63455699: { driver: { name: "PyMongo", version: "3.11.4" }, os: { type: "Linux", name: "Linux", architecture: "x86_64", version: "5.4.0-74-generic" }, platform: "CPython 3.8.5.final.0" }
    2021-06-24T01:33:46.010+0000 I NETWORK  [listener] connection accepted from 171.25.193.78:26557 #63455724 (1189 connections now open)
    2021-06-24T01:33:46.092+0000 I NETWORK  [conn63455724] received client metadata from 171.25.193.78:26557 conn63455724: { driver: { name: "PyMongo", version: "3.11.4" }, os: { type: "Linux", name: "Linux", architecture: "x86_64", version: "5.4.0-74-generic" }, platform: "CPython 3.8.5.final.0" }
    2021-06-24T01:33:46.500+0000 I NETWORK  [conn63455724] end connection 171.25.193.78:26557 (1198 connections now open)
    2021-06-24T01:33:46.533+0000 I NETWORK  [conn63455699] end connection 171.25.193.78:26003 (1200 connections now open)
    2021-06-24T01:34:06.533+0000 I NETWORK  [listener] connection accepted from 185.220.101.6:10056 #63456621 (1266 connections now open)
    2021-06-24T01:34:06.627+0000 I NETWORK  [conn63456621] received client metadata from 185.220.101.6:10056 conn63456621: { driver: { name: "PyMongo", version: "3.11.4" }, os: { type: "Linux", name: "Linux", architecture: "x86_64", version: "5.4.0-74-generic" }, platform: "CPython 3.8.5.final.0" }
    2021-06-24T01:34:06.890+0000 I NETWORK  [listener] connection accepted from 185.220.101.6:21642 #63456637 (1264 connections now open)
    2021-06-24T01:34:06.962+0000 I NETWORK  [conn63456637] received client metadata from 185.220.101.6:21642 conn63456637: { driver: { name: "PyMongo", version: "3.11.4" }, os: { type: "Linux", name: "Linux", architecture: "x86_64", version: "5.4.0-74-generic" }, platform: "CPython 3.8.5.final.0" }
    2021-06-24T01:34:08.018+0000 I COMMAND  [conn63456637] dropDatabase config - starting
    2021-06-24T01:34:08.018+0000 I COMMAND  [conn63456637] dropDatabase config - dropping 1 collections
    2021-06-24T01:34:08.018+0000 I COMMAND  [conn63456637] dropDatabase config - dropping collection: config.transactions
    2021-06-24T01:34:08.020+0000 I STORAGE  [conn63456637] dropCollection: config.transactions (no UUID) - renaming to drop-pending collection: config.system.drop.1624498448i1t-1.transactions with drop optime { ts: Timestamp(1624498448, 1), t: -1 }
    2021-06-24T01:34:08.029+0000 I REPL     [replication-14545] Completing collection drop for config.system.drop.1624498448i1t-1.transactions with drop optime { ts: Timestamp(1624498448, 1), t: -1 } (notification optime: { ts: Timestamp(1624498448, 1), t: -1 })
    2021-06-24T01:34:08.030+0000 I STORAGE  [replication-14545] Finishing collection drop for config.system.drop.1624498448i1t-1.transactions (no UUID).
    2021-06-24T01:34:08.030+0000 I COMMAND  [conn63456637] dropDatabase config - successfully dropped 1 collections (most recent drop optime: { ts: Timestamp(1624498448, 1), t: -1 }) after 7ms. dropping database
    2021-06-24T01:34:08.032+0000 I REPL     [replication-14546] Completing collection drop for config.system.drop.1624498448i1t-1.transactions with drop optime { ts: Timestamp(1624498448, 1), t: -1 } (notification optime: { ts: Timestamp(1624498448, 5), t: -1 })
    2021-06-24T01:34:08.041+0000 I COMMAND  [conn63456637] dropDatabase config - finished
    2021-06-24T01:34:08.398+0000 I COMMAND  [conn63456637] dropDatabase newsblur - starting
    2021-06-24T01:34:08.398+0000 I COMMAND  [conn63456637] dropDatabase newsblur - dropping 37 collections

    << SNIP: It goes on for a while... >>

    2021-06-24T01:35:18.840+0000 I COMMAND  [conn63456637] dropDatabase newsblur - finished

What you see above...

When I visited the IP address of the [two](http://185.220.101.6/) [connections](http://171.25.193.78/) above, I found a Tor exit router:

<img src="/assets/hack-tor.png">

### 3. What will happen to ensure this doesn't happen again?

VPC all the way.
