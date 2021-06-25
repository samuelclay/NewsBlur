---
layout: post
title: A Downtime Irony
date: '2014-08-21T21:08:24-04:00'
tags: []
tumblr_url: https://blog.newsblur.com/post/95431965676/a-downtime-irony
redirect_from: /post/95431965676/a-downtime-irony/
---
So many things can go wrong and often do, but I spend a good third of my time working on infrastructure, monitoring, and analytics so that they don’t.

Here’s what happened: At approximately 4:30pm PT feed fetching ceased. The feed fetchers were still working, which is why my monitors didn’t fire and alert anybody. But I have a second large Mongo database server used exclusively for collecting data about feeds being fetched. There are approximately 75 servers dedicated to feed fetching. These analytics look at average fetch times on a per task server basis. I use these analytics to ensure that my task servers are humming along, as they each use a ton of network, cpu, and memory.

This Mongo analytics servers works in a curious way. If you right-click on a feed and go to Statistics you’ll see the feed fetch history for a feed, stretching back a hundred fetches if the feed has had any issues in fetching. I keep these statistics on an analytics server separate from the regular Mongo server. I do this so that if the mongo analytics server goes down, everything will operate normally.

But the mongo server didn’t go down. It merely gave this error:

    OperationError: Could not save document (Can't take a write lock while out of disk space)

Mongo continues serving read queries while not allowing write queries. I didn’t plan for that! And it gets worse. The way MongoDB stores data is that is just keeps growing, even as you delete data. NewsBlur only saves the last few fetches, but deleting old fetches doesn’t give you back any disk space. Every other database server I use has an autovacuum process that takes care of this maintenance work (PostgreSQL, Redis, Elasticsearch, but not MongoDB). It’s unfortunate that this is yet another instance of MongoDB being the cause of downtime, even though the fault lies with me.

The server that is meant to only be used to ensure things are working correctly was itself the culprit for feeds no longer being fetched. This is the ironic part.

![](https://s3.amazonaws.com/static.newsblur.com/blog/Big%20Sur.jpg)

###### NewsBlur’s developer during happier times wearing the 2013 NewsBlur t-shirt in Big Sur

Now comes the painful part. On Wednesday morning (yesterday) I packed my car and headed down to Big Sur to go backpack camping for the first time. I’ve car camped plenty of times, but I felt confident enough to pack my sleeping bag and tent into a big bag and head ten miles into the woods of coastal California.

I headed out, away from cellular service, at 4pm PT, half an hour before the analytics server ran out of disk space. And then returned nearly 24 hours later to a bevy of alarmed tweets, emails, direct messages, and a voicemail letting me know that things were haywire.

But the real problem is that I set a vacation reply on both my personal and work email accounts to say that I’d be out until September 3rd. Now, I hired a firm to watch the servers while I’m at Burning Man starting this Saturday. But I figured I could get away with leaving the servers for twenty four hours. And I neglected to tweet out that I’d be gone for a day, so theories cropped up that I was injured, dead, or worse, ignoring the service.

![](https://s3.amazonaws.com/static.newsblur.com/blog/Brittany%20in%20Big%20Sur.jpg)

###### Brittany, NewsBlur’s developer’s girlfriend, can handle any situation, including driving a hysterical developer three hours back to San Francisco without breaking a sweat.

If you’re wondering, I think about NewsBlur first thing in the morning and last thing at night when I check Twitter for mentions. It’s my life and I would never just give up on it. I just got cocky after a year and a half of nearly uninterrupted service. NewsBlur requires next to no maintenance, apart from handling support requests and building new features (and occasionally fixing old ones). So I figured what harm could 24 hours of away time be? Boy was I wrong.

If you made it this far then you probably care about NewsBlur’s future. I want to not only assure you that I will be building better monitoring to ensure this never happens again, but to also offer anybody who feels that they are not getting their money’s worth a refund. Even if you are months away from payment, if you aren’t completely satisfied and think NewsBlur’s just about the best thing to happen to RSS since Brent Simmons released NetNewsWire back in 2004, then I want to give you your money back and let you keep your premium account until it expires.

I would like to also mention how much I appreciate the more light-hearted tweets that I read while on the frenetic three hour drive back to San Francisco from Big Sur. I do this for all of your happiness. If I did it for the money I’d probably find a way to juice the data so that I could at least afford to hire an employee. This is a labor of love and your payment goes directly into supporting it.

![](https://s3.amazonaws.com/static.newsblur.com/blog/Tent%20in%20Big%20Sur.jpg)

###### Big Sur is where a good many new ideas are thought.
