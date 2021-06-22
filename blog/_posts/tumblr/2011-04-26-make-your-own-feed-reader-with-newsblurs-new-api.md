---
layout: post
title: Make your own feed reader with NewsBlur's new API
date: '2011-04-26T06:41:00-04:00'
tags: []
tumblr_url: https://blog.newsblur.com/post/4955915076/make-your-own-feed-reader-with-newsblurs-new-api
redirect_from: /post/4955915076/make-your-own-feed-reader-with-newsblurs-new-api/
---
_Please vote for this blog post on Hacker News: [http://news.ycombinator.com/item?id=2485377](http://news.ycombinator.com/item?id=2485377)._

It’s a big news day here at NewsBlur HQ. For those of you who don’t know, NewsBlur HQ is a comfy seat on the A train, part of the NYC subway system, since that’s where most of the code gets written anyhow.

I’m happy to announce [NewsBlur’s brand-spanking-new API](http://www.newsblur.com/api). It’s free, it comes with tons of juicy data, and it can be used to create your own feed reader. Let’s look at what this all means.

[NewsBlur](http://www.newsblur.com) is a visual feed reader with intelligence. This API gives you access to all the moving parts that make up the flagship newsblur.com site. This includes the original site, stories, intelligence classifiers, statistics, and a really neat River of News view that aggregates multiple feeds into a single view.

## Juicy Data from the API

Let’s take a quick look at a visualization of the data you can get out of the API. This is a screenshot from the Statistics dialog from a single feed:

![](http://cl.ly/6FN3/statistics.png)

To get this data, you would need to make two calls:

    
    $ curl http://www.newsblur.com/rss_feeds/search_feed?address=techcrunch
    
    {
        "feed_address": "http://feeds.feedburner.com/TechCrunch",
        "updated": "4 minutes",
        "subs": 2514,
        "feed_link": "http://techcrunch.com",
        "favicon_fetching": false,
        "feed_title": "TechCrunch",
        "favicon": "[BASE64 FAVICON GOODNESS DATA]",
        "favicon_color": "90b490",
        "id": 12,
        "result": "ok"
    }
    
    $ curl http://www.newsblur.com/rss_feeds/statistics/12
    
    {
        "premium_subscribers": 66,
        "average_stories_per_month": 490.33333333333331,
        "subscriber_count": 2514,
        "last_load_time": 40,
        "update_interval_minutes": 4,
        "last_update": "5 minutes",
        "feed_fetch_history": [...],
        "result": "ok",
        "stories_last_month": 501,
        "active_subscribers": 43,
        "story_count_history": [["2010-11", 455.0], ["2010-12", 500.0], 
                                ["2011-1", 500.0], ["2011-2", 500.0], 
                                ["2011-3", 487.0], ["2011-4", 500.0]],
        "next_update": "3 minutes",
        "classifier_counts": {
            "feed": [{
                "neg": 5,
                "feed_id": 12,
                "pos": 40
            }],
            "title": [
            {
                "neg": 4,
                "tag": "techcrunch tv",
                "pos": 14
            },
            {
                "neg": 3,
                "tag": "iphone 4",
                "pos": 11
            }
            ...
            ],
            "author": [{
                "neg": 2,
                "pos": 24,
                "author": "MG Siegler"
            },
            {
                "neg": 3,
                "pos": 25,
                "author": "Michael Arrington"
            },
            {
                "neg": 4,
                "pos": 13,
                "author": "Paul Carr"
            }
            ...
            ]
        }
    }

How about the intelligence classifiers for a site?

![](http://f.cl.ly/items/1o3V3D2K1u1Q1P2N2B42/Screen%20shot%202011-04-26%20at%2010.09.33%20AM.png)

    
    $ curl http://www.newsblur.com/rss_feeds/search_feed?address=louisgray
    
    {
        "feed_address": "http://blog.louisgray.com/feeds/posts/default?alt=rss",
        "updated": "2 minutes",
        "subs": 130,
        "feed_link": "http://blog.louisgray.com/",
        "favicon_fetching": false,
        "feed_title": "louisgray.com",
        "favicon": "[FAVICON GOES HERE]",
        "favicon_color": "f96402",
        "id": 172,
        "result": "ok"
    }
    
    $ curl http://www.newsblur.com/reader/feeds_trainer?feed_id=172
    
    [{
        "stories_last_month": 24,
        "feed_id": 172,
        "feed_tags": [["android", 13.0], ["google", 12.0], ["apple", 12.0], 
                      ["iphone", 9.0], ["twitter", 7.0], ["facebook", 5.0], 
                      ["sxsw", 5.0], ["media", 5.0], ["spotify", 4.0], 
                      ["itunes", 4.0], ["ipad", 4.0], ["silicon valley", 4.0], 
                      ["personal", 3.0], ["apple tv", 3.0], ["quora", 3.0], 
                      ["social networking", 3.0], ["yobongo", 3.0], 
                      ["entertainment", 3.0], ["seesmic", 3.0], ["search", 3.0], 
                      ["music", 3.0], ["beluga", 3.0], ["work", 3.0], 
                      ["chat", 3.0], ["samsung", 3.0]],
        "classifiers": {
            "authors": {},
            "feeds": {},
            "titles": {},
            "tags": {
                "personal": 1,
                "android": -1,
                "facebook": -1,
                "twitter": 1,
                "rss": 1
            }
        },
        "feed_authors": [["louisgray@gmail.com (Louis Gray)", 62]]
    }]

Without going too deep into explaining various parts of the API, you can dive right into it by viewing the various API endpoints at [http://www.newsblur.com/api](http://www.newsblur.com/api). The API is meant to be used with an authenticated account, which can be created directly from the API. I spent a lot of time polishing the look and readability of the API, so I hope you like it, since if you’re going to be developing on top of it, you will probably spend a looong time working with the 30 endpoints.

I’d like to briefly note that I work on NewsBlur in my free time, and it’s entirely open-source on GitHub: [http://github.com/samuelclay](http://github.com/samuelclay). This API is the result of 22 months of work and thought. But it’s not corporate, not funded, and certainly not battle-tested. Go easy on it for the time being. And [offer feedback on Twitter](http://twitter.com/samuelclay).

## Is making a NewsBlur client cannibalism?

Woah! How does that even work? There’s no endpoint for _cannibalism_. (OK, there is, it’s `/reader/delete_feed`.) But what does this API mean for you?

Twitter has a web client, but the real iceberg is the ecosystem built on their API. Google Reader has a website, but more than a handful of enormous venture-engorged companies make their living by using the Reader API.

If you choose to use the NewsBlur API, you are building complements to the website. You can mix-and-mash data as you please. But more importantly, you can use NewsBlur data in ways that are not even possible on the website today.

Want to mix up a social layer with the subscriptions in your NewsBlur account? Just use `/reader/feeds`, `/reader/feed/:id`, and `/rss_feeds/statistics`. Got an Android device and want to make a mobile client that you can _charge money_ for and make a profit? The NewsBlur API supports that.

What you can’t do is wrap advertisements around NewsBlur data. Why? Because NewsBlur preserves the original site, so there are already ads on the page if the publisher chooses to have them. Additionally, ads degrade the NewsBlur experience. NewsBlur is not some fly-by-night air-ride-equipped service out to make a buck. NewsBlur is built to make life better, a small net-enabled reading experience at a time. Profit is great, but not at the cost of ads.

## If you build it, they will come, and there’s no hard scaling part

You’re building on an API, not a service end-to-end. If you want to handle the scaling part, use the raw NewsBlur code on GitHub: [http://github.com/samuelclay](http://github.com/samuelclay). NewsBlur.com will take care of the scaling and infrastructure, and you can take care of building a new layer that might make you famous/well-off/existentially-happy.

The API is ready for you at [http://www.newsblur.com/api](http://www.newsblur.com/api).

Questions? Feedback? Want to stay up to date when I drive cross country and take photos of the beautiful countryside between New York and California? Follow [@samuelclay on Twitter](http://twitter.com/samuelclay).

- Samuel Clay, innocent Founder of NewsBlur

