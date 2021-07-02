---
layout: post
title: Upping unread stories to 30 days for premium accounts
date: '2013-09-16T17:09:14-04:00'
tags: []
tumblr_url: https://blog.newsblur.com/post/61451693579/upping-unread-stories-to-30-days-for-premium
redirect_from: /post/61451693579/upping-unread-stories-to-30-days-for-premium/
---
While I love shipping new features and fixing bugs, the single largest user request was neither a feature nor a bug. NewsBlur allows for two weeks of unread stories. Once a story is more than 14 days old, it would no longer show up as unread. The justification for this was simple: you have a week to read a story, and have a second week as a grace period.

But after scaling out to tens of thousands of users, a new pattern emerged. Some users would go on vacation for two weeks at a time and then want to catch up on everything they missed. Some users only check RSS once a month. Some users just want to leave lightly updated feeds alone until they have free time to read them, and that can take a few weeks to get to.

Starting today, all premium users are automatically upgraded to 30 days of unread stories. Free standard users will remain at 14 days. I wish I could have offered the full 30 days to everybody, but after testing that out, my server and performance graphs all made a very scary movement up.

![](https://s3.amazonaws.com/static.newsblur.com/blog/30d_mongodb_page_faults-day.png)

With the new 30 day unread interval in place, NewsBlur has a great track record in listening to user feedback and working out a solution, however large the task may be.

