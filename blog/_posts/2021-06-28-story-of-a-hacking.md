---
layout: post
title: How a Docker footgun led to a vandal deleting NewsBlur's MongoDB database
tags: ['backend']
---

*tl;dr: A vandal deleted NewsBlur's MongoDB database during a migration. No data was stolen or lost.*

I'm in the process of moving everything on NewsBlur over to Docker containers in prep for a [big redesign launching next week](https://beta.newsblur.com). It's been a great year of maintenance and I've enjoyed the fruits of Ansible + Docker for NewsBlur's 5 database servers (PostgreSQL, MongoDB, Redis, Elasticsearch, and soon ML models). The day was wrapping up and I settled into [a new book on how to tame the machines once they're smarter than us](https://en.wikipedia.org/wiki/Human_Compatible) when I received a strange NewsBlur error on my phone.

    "query killed during yield: renamed collection 'newsblur.feed_icons' to 'newsblur.system.drop.1624498448i220t-1.feed_icons'"

There is honestly no set of words in that error message that I ever want to see again. What is `drop` doing in that error message? Better go find out.

Logging into the MongoDB machine to check out what state the DB is in and I come across the following...

{% highlight javascript %}
nbset:PRIMARY> show dbs
READ__ME_TO_RECOVER_YOUR_DATA   0.000GB
newsblur                        0.718GB

nbset:PRIMARY> use READ__ME_TO_RECOVER_YOUR_DATA
switched to db READ__ME_TO_RECOVER_YOUR_DATA
    
nbset:PRIMARY> db.README.find()
{ 
    "_id" : ObjectId("60d3e112ac48d82047aab95d"), 
    "content" : "All your data is a backed up. You must pay 0.03 BTC to XXXXXXFTHISGUYXXXXXXX 48 hours for recover it. After 48 hours expiration we will leaked and exposed all your data. In case of refusal to pay, we will contact the General Data Protection Regulation, GDPR and notify them that you store user data in an open form and is not safe. Under the rules of the law, you face a heavy fine or arrest and your base dump will be dropped from our server! You can buy bitcoin here, does not take much time to buy https://localbitcoins.com or https://buy.moonpay.io/ After paying write to me in the mail with your DB IP: FTHISGUY@recoverme.one and you will receive a link to download your database dump." 
}
{% endhighlight %}

Two thoughts immediately occured:

 1. Thank goodness I have some recently checked backups on hand
 2. No way they have that data without me noticing

Three and a half hours before this happened, I switched the MongoDB cluster over to the new servers. When I did that, I shut down the original primary in order to delete it in a few days when all was well. And thank goodness I did that as it came in handy a few hours later. Knowing this, I realized that the hacker could not have taken all that data in so little time.

With that in mind, I'd like to answer a few questions about what happened here.

 1. Was any data leaked during the hack? How do you know?
 2. How did NewsBlur's MongoDB server get hacked?
 3. What will happen to ensure this doesn't happen again?

Let's start by talking about the most important question of all which is what happened to your data.

### 1. Was any data leaked during the hack? How do you know?

I can definitively write that no data was leaked during the hack. I know this because of two different sets of logs showing that the automated attacker only issued deletion commands and did not transfer any data off of the MongoDB server.

Below is a snapshot of the bandwidth of the db-mongo1 machine over 24 hours:

<img src="/assets/hack-timeline.png" style="border: 1px solid rgba(0,0,0,0.1);">

You can imagine the stress I experienced in the forty minutes between 9:35p, when the hack began, and 10:15p, when the fresh backup snapshot was identified and put into gear. Let's breakdown each moment:

 1. **6:10p**: The new db-mongo1 server was put into rotation as the MongoDB primary server. This machine was the first of the new, soon-to-be private cloud.
 2. **9:35p**: Three hours later an automated hacking attempt opened a connection to the db-mongo1 server and immediately dropped the database. Downtime ensued.
 3. **10:15p**: Before the former primary server could be placed into rotation, a snapshot of the server was made to ensure the backup would not delete itself upon reconnection. This cost a few hours of downtime, but saved nearly 18 hours of a day's data by not forcing me to go into the daily backup archive.
 4. **3:00a**: Snapshot completes, replication from original primary server to new db-mongo1 begins. What you see in the next hour and a half is what the transfer of the DB looks like in terms of bandwidth.
 5. **4:30a**: Replication, which is inbound from the old primary server, completes, and now replication begins outbound on the new secondaries. NewsBlur is now back up.

The most important bit of information the above chart shows us is what a full database transfer looks like in terms of bandwidth. From 6p to 9:30p, the amount of data was the expected amount from a working primary server with multiple secondaries syncing to it. At 3a, you'll see an enormous amount of data transfered. 

This tells us that the hacker was an automated digital vandal rather than a concerted hacking attempt. And if we were to pay the ransom, it wouldn't do anything because the vandals don't have the data and have nothing to release. 

We can also reason that the vandal was not able to access any files that were on the server outside of MongoDB due to using a recent version of MongoDB in a Docker container. Unless the attacker had access to a 0-day to both MongoDB and Docker, it is highly unlikely they were able to break out of the MongoDB server connection. 

While the server was being snapshot, I used that time to figure out how the hacker got in. 

### 2. How did NewsBlur's MongoDB server get hacked?

Turns out the ufw firewall I enabled and diligently kept on a strict allowlist with only my internal servers didn't work on a new server because of Docker. When I containerized MongoDB, Docker helpfully inserted an allow rule into iptables, opening up MongoDB to the world. So while my firewall was "active", doing a `sudo iptables -L | grep 27017` showed that MongoDB was open the world. This has been [a Docker footgun since 2014](https://github.com/moby/moby/issues/4737).

To be honest, I'm a bit surprised it took over 3 hours from when I flipped the switch to when a hacker/vandal dropped NewsBlur's MongoDB collections and pretended to ransom about 250GB of data. This is the work of an automated hack and one that I was prepared for. NewsBlur was back online a few hours later once the backups were restored and the Docker-made hole was patched.

It would make for a much more dramatic read if I was hit through a vulnerability in Docker instead of a footgun. By having Docker silently override the firewall, Docker has made it easier for developers who want to open up ports on their containers at the expense of security. Better would be for Docker to issue a warning when it detects that the most popular firewall on Linux is active and filtering traffic to a port that Docker is about to open.

<img src="/assets/ornament-pill.png" style="display: block; margin: 0 auto;width: 100px;">

The second reason we know that no data was taken comes from looking through the MongoDB access logs. With these rich and verbose logging sources we can invoke a pretty neat command to find everybody who is not one of the 100 known NewsBlur machines that has accessed MongoDB.

<div class="language-plaintext highlighter-rouge"><div class="highlight"><pre class="highlight" style="max-height: 200px;"><code>
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
</code></pre></div></div>

The above is a lot, but the important bit of information to take from it is that by using a subtractive filter, capturing everything that doesn't match a known IP, I was able to find the two connections that were made a few seconds apart. Both connections from these unknown IPs occured only moments before the database-wide deletion. By following the connection ID, it became easy to see the hacker come into the server only to delete it seconds later. 

Interestingly, when I visited the IP address of the [two](http://185.220.101.6/) [connections](http://171.25.193.78/) above, I found a Tor exit router:

<img src="/assets/hack-tor.png">

This means that it is virtually impossible to track down who is responsible due to the anonymity-preserving quality of Tor exit routers. [Tor exit nodes have poor reputations](https://blog.cloudflare.com/the-trouble-with-tor/) due to the havoc they wreak. Site owners are split on whether to block Tor entirely, but some see the value of allowing anonymous traffic to hit their servers. In NewsBlur's case, because NewsBlur is a home of free speech, allowing users in countries with censored news outlets to bypass restrictions and get access to the world at large, the continuing risk of supporting anonymous Internet traffic is worth the cost. 

### 3. What will happen to ensure this doesn't happen again?

Of course, being in support of free speech and providing enhanced ways to access speech comes at a cost. So for NewsBlur to continue serving traffic to all of its worldwide readers, several changes have to be made.

The first change is the one that, ironically, we were in the process of moving to. A VPC, a virtual private cloud, keeps critical servers only accessible from others servers in a private network. But in moving to a private network, I need to migrate all of the data off of the publicly accessible machines. And this was the first step in that process.

The second change is to use database user authentication on all of the databases. We had been relying on the firewall to provide protection against threats, but when the firewall silently failed, we were left exposed. Now who's to say that this would have been caught if the firewall failed but authentication was in place. I suspect the password needs to be long enough to not be brute-forced, because eventually, knowing that an open but password protected DB is there, it could very possibly end up on a list.

Lastly, a change needs to be made as to which database users have permission to drop the database. Most database users only need read and write privileges. The ideal would be a localhost-only user being allowed to perform potentially destructive actions. If a rogue database user starts deleting stories, it would get noticed a whole lot faster than a database being dropped all at once.

But each of these is only one piece of a defense strategy. [As this well-attended Hacker News thread from the day of the hack made clear](https://news.ycombinator.com/item?id=27613217), a proper defense strategy can never rely on only one well-setup layer. And for NewsBlur that layer was a allowlist-only firewall that worked perfectly up until it didn't. 

As usual the real heros are backups. Regular, well-tested backups are a necessary component to any web service. And with that, I'll prepare to [launch the big NewsBlur redesign later this week](https://beta.newsblur.com).
