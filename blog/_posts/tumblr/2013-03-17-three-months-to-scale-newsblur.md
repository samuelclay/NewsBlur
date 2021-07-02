---
layout: post
title: Three Months to Scale NewsBlur
date: '2013-03-17T17:24:00-04:00'
tags: []
tumblr_url: https://blog.newsblur.com/post/45632737156/three-months-to-scale-newsblur
redirect_from: /post/45632737156/three-months-to-scale-newsblur/
---
At 4:16pm last Wednesday I got a short and to-the-point email from Nilay Patel at The Verge with only a link that started with the host “googlereader.blogspot.com”. The sudden spike in NewsBlur’s visitors immediately confirmed — Google was shutting down Reader.

<figure class="tmblr-full" data-orig-height="800" data-orig-width="600" data-orig-src="https://s3.amazonaws.com/static.newsblur.com/blog/Late%20night%20at%20the%20office.jpeg"><img width="500" style="margin: 0 auto;" data-orig-height="800" data-orig-width="600" src="https://s3.amazonaws.com/static.newsblur.com/blog/Late%20night%20at%20the%20office.jpeg"></figure>

##### Late night at the office

I had been preparing for a black swan event like this for the last four years since I began NewsBlur. With the deprecation of their social features a year ago I knew it was only a matter of time before Google stopped supporting Reader entirely. I did not expect it to come this soon.

As the [Storify history of the Reader-o-calypse](http://storify.com/mattrose/reader-o-calypse-from-the-pov-of-a-competitor), NewsBlur suffered a number of hurdles with the onslaught of new subscribers.

## A few of my challenges and solutions

I was able to handle the 1,500 users who were using the service everyday, but when 50,000 users hit an uncachable and resource intensive backend, unless you’ve done your homework and load tested the living crap out of your entire stack, there’s going to be trouble brewing. Here’s just a few of the immediate challenges I faced over the past four days:

- My hosting provider, Reliable Hosting Services, was neither reliable, able to host my increasing demands, or a service I could count on. I switched to Digital Ocean and immediately got to [writing new Fabric scripts](https://github.com/samuelclay/NewsBlur/blob/master/fabfile.py#L934-L970) so I could deploy a new app/task server by issuing a single command and having it serve requests automatically within 10 minutes of bootstrapping.
- It didn’t take long to max out my Amazon Simple Email Service (SES) account’s quota of 10,000 emails a day. So a few hours into the melee I switched to Mailgun, which unfortunately resulted in emailing myself 250,000 error reports. If you tried to email me and couldn’t get through, it’s because 50,000 emails about lost database connections made their way ahead of you in line.
- Eventually, I was just plain blacklisted on SES for sending too many emails.
- Fortunately, when the PayPal fraud department called because of an unprecedented spike in payments, I was prepared.

> Paypal’s fraud department just called, asked me what’s going on. Asked the rep from Omaha if she’s heard of Reader, and then a big Ohhh.
> 
> — NewsBlur (@NewsBlur) [March 17, 2013](https://twitter.com/NewsBlur/status/313354032083259394)

<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>
- HAProxy would serve errors (site is down, maintenance, timeouts, etc) with a 200 OK status code instead of the proper 500 Exception status code because of a ridiculous undocumented requirement to [include HTTP Headers at the top of the error template](https://github.com/samuelclay/NewsBlur/blob/master/templates/502.http#L1-L4). When your webapp uses status codes to determine errors, you get extremely strange behavior when it loads utter crap into your DOM.
- The inevitable file descriptor limits on Linux means that for every database connection you make, you use up one of the 1,024 file descriptors that are allocated to your process by default. Changing these limits is not only non-trivial, but they don’t tend to stick. This is responsible for bringing down Mongo, PostgreSQL, and the real-time Node servers, all at different times of the night.
- The support queue is enormous and I’ve had to spend big chunks of my 16 hour days reassuring paying customers that eventually Stripe will forgive me and my unresponsive servers and will send the payment notification that is responsible for automatically upgrading their accounts to premium.

<figure class="tmblr-full" data-orig-height="450" data-orig-width="600" data-orig-src="https://s3.amazonaws.com/static.newsblur.com/blog/St%20Pattys%20Day%20Desk.jpeg"><img width="500" style="margin: 0 auto;" data-orig-height="450" data-orig-width="600" src="https://s3.amazonaws.com/static.newsblur.com/blog/St%20Pattys%20Day%20Desk.jpeg"></figure>

##### The sad extent of my St. Patrick’s Day

As a one-man-shop it has been humbling to receive the benefit of the doubt from many who have withheld their judgment despite the admittedly slow loadtimes and downtime NewsBlur experienced. Having the support of the amazing NewsBlur community is more than a guy could ask for. The tweets of encouragement, voting NewsBlur up on [replacereader.com](http://replacereader.com) (If you haven’t yet, please tweet a vote for [“#newsblur to #replacereader”](https://twitter.com/intent/tweet?source=webclient&text=I%20think%20%23NewsBlur%20should%20%23replacereader.%20http://replacereader.com)), and the many positive comments and blog posts from people who have tried NewsBlur is great.

It has also been a dream come true to receive accolades from the many who are trying NewsBlur for the first time and loving it. Since the announcement, NewsBlur has welcomed 5,000 new premium subscribers and 60,000 new users (from 50,000 users originally).

<table cellpadding="12" cellspacing="12" width="100%"\><tr\><td\><figure class="tmblr-full" data-orig-height="225" data-orig-width="300" data-orig-src="https://s3.amazonaws.com/static.newsblur.com/blog/Shirt%201.jpg"><img width="300" data-orig-height="225" data-orig-width="300" src="https://s3.amazonaws.com/static.newsblur.com/blog/Shirt%201.jpg"></figure></td\> <td\><figure class="tmblr-full" data-orig-height="200" data-orig-width="300" data-orig-src="https://s3.amazonaws.com/static.newsblur.com/blog/Shirt%202.jpg"><img width="300" data-orig-height="200" data-orig-width="300" src="https://s3.amazonaws.com/static.newsblur.com/blog/Shirt%202.jpg"></figure></td\> </tr\><tr\><td\><figure class="tmblr-full" data-orig-height="225" data-orig-width="300" data-orig-src="https://s3.amazonaws.com/static.newsblur.com/blog/Shirt%203.jpg"><img width="300" data-orig-height="225" data-orig-width="300" src="https://s3.amazonaws.com/static.newsblur.com/blog/Shirt%203.jpg"></figure></td\> <td\><figure class="tmblr-full" data-orig-height="225" data-orig-width="300" data-orig-src="https://s3.amazonaws.com/static.newsblur.com/blog/Shirt%204.jpg"><img width="300" data-orig-height="225" data-orig-width="300" src="https://s3.amazonaws.com/static.newsblur.com/blog/Shirt%204.jpg"></figure></td\> </tr\><tr\><td\><figure class="tmblr-full" data-orig-height="400" data-orig-width="300" data-orig-src="https://s3.amazonaws.com/static.newsblur.com/blog/Shirt%205.jpg"><img width="300" data-orig-height="400" data-orig-width="300" src="https://s3.amazonaws.com/static.newsblur.com/blog/Shirt%205.jpg"></figure></td\> <td\><figure class="tmblr-full" data-orig-height="405" data-orig-width="300" data-orig-src="https://s3.amazonaws.com/static.newsblur.com/blog/Shirt%206.jpg"><img width="300" data-orig-height="405" data-orig-width="300" src="https://s3.amazonaws.com/static.newsblur.com/blog/Shirt%206.jpg"></figure></td\> </tr\></table\>
##### NewsBlur users are intelligent, kind, and good looking!

# The next three months

Over the next three months I’ll be working on:

- Scaling, scaling, scaling
- Launching the redesign ([which you can preview](http://dev.newsblur.com))
- Listening to all of you

For those of you who are still trying to decide where to go now that you’re a Reader refugee let me tell you a few of the unique things NewsBlur has to offer:

1. Radical transparency. [NewsBlur is totally open source](https://github.com/samuelclay) and will remain that way.
2. It still feels like RSS, just with a few more bells and whistles. NewsBlur provides actual list of posts, as opposed to the more curated magazine format of some of the other popular replacements. This clean interface makes it easy to see the stories you want. One innovation however is the four different view options you have. NewsBlur can show you the original site, feed, text or story view.
3. It has training. NewsBlur hides stories you don’t want to read based on tags, keywords, authors, etc. It also highlights stories you want to read, based on the same criteria. This allows you to find the stories you care about, not just the stories that the hive cares about. And best of all, NewsBlur will show you why stories are either highlighted or hidden by showing the criteria in green or red.
4. NewsBlur has rebuilt the social community that Google had stripped out of Reader. Users can share stories through their Blurblog and discover new content by following friends’ Blurblogs. [The People Have Spoken](http://popular.newsblur.com) is the blurblog of popular stories.
5. Because NewsBlur is entirely open-source, if you don’t want to pay you can host your own server. [Instructions are on GitHub](http://github.com/samuelclay/NewsBlur), where you can also find the source code for the [NewsBlur iPhone + iPad app](https://github.com/samuelclay/NewsBlur/tree/master/media/ios) and [Android app](https://github.com/samuelclay/NewsBlur/tree/master/media/android/NewsBlur).
6. Most importantly, NewsBlur is not entirely a free app. The immediate benefits of revenue have been very clear over the past few days. Not only are NewsBlur’s interests aligned with its users, but as more users join NewsBlur, it makes more revenue that can be used to directly support the new users. Not convinced that paid is better than free? Read Pinboard’s Maciej Ceglowski’s essay [Don’t Be a Free User](http://blog.pinboard.in/2011/12/don_t_be_a_free_user/).

<figure class="tmblr-full" data-orig-height="450" data-orig-width="600" data-orig-src="https://s3.amazonaws.com/static.newsblur.com/blog/Shiloh%20in%20good%20times.jpeg"><img width="500" style="margin: 0 auto;" data-orig-height="450" data-orig-width="600" src="https://s3.amazonaws.com/static.newsblur.com/blog/Shiloh%20in%20good%20times.jpeg"></figure>

##### Shiloh during better times. Your premium subscription goes to both server costs and feeding her

With NewsBlur’s native iOS app and Android app, you can read your news and share it with your friends anywhere. And with the coming improvements over the next three months, you bet NewsBlur will be the #1 choice for Google Reader refugees.

[Join NewsBlur for $24/year](http://www.newsblur.com) and discover what RSS should have been.

