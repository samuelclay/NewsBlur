---
layout: post
title: Building real-time feed updates for NewsBlur with Redis and WebSockets
date: '2012-04-02T17:52:00-04:00'
tags:
- code
tumblr_url: https://blog.newsblur.com/post/20371256202/building-real-time-feed-updates-for-newsblur
redirect_from: /post/20371256202/building-real-time-feed-updates-for-newsblur/
---
Today, NewsBlur is going real-time. Blogs using the PubSubHubbub protocol (PuSH), which includes all Blogger, Tumblr, and many Wordpress blogs, will instantaneously show new updates to subscribers on NewsBlur. Making this happen, while not for the faint of heart, was straight-forward enough that I’m sharing the recipe I used to get everything hooked up and running smoothly.

Every user, both premium and standard, will now receive instantaneous updates. I’ve been beta-testing this feature for the past few weeks, and I’ve been quite pleased in knowing that I’m now reading on the bleeding-edge.

If you are a developer, you may be interested in how this was done. There are two components in a real-time feed: detecting updates and then informing users of those updates.

## Get blog updates in real-time

If you are building a system that consumes an RSS feed and you want it to push to you, you’ll have to subscribe to a special PubSubHubbub hub url that the RSS feed gives you in the original RSS feed.

Take a look at the `<feed>` section in the NewsBlur Blog’s RSS feed:

    >>> # Python
    >>> from utils import feedparser
    >>> from pprint import pprint
    >>> fp = feedparser.parse('http://blog.newsblur.com/rss')
    >>> pprint(fp.feed)
    {'generator': u'Tumblr (3.0; @newsblur)',
     'generator_detail': {'name': u'Tumblr (3.0; @newsblur)'},
     'link': u'http://blog.newsblur.com/',
     'links': [{'href': u'http://tumblr.superfeedr.com/',
                'rel': u'hub',
                'type': u'text/html'},
               {'href': u'http://blog.newsblur.com/',
                'rel': u'alternate',
                'type': u'text/html'}],
     'subtitle': u'Visual feed reading with intelligence.',
     'subtitle_detail': {'base': u'http://blog.newsblur.com/rss',
                         'language': None,
                         'type': u'text/html',
                         'value': u'Visual feed reading with intelligence.'},
     'title': u'The NewsBlur Blog',
     'title_detail': {'base': u'http://blog.newsblur.com/rss',
                      'language': None,
                      'type': u'text/plain',
                      'value': u'The NewsBlur Blog'}}

If there’s a `rel="hub"` node under `links`, then the RSS feed is advertising its PubSubHubbub abilities. If you make a subscription request to that address, then the feed will push out updates to your callback URL.

The code for sending the subscription requests, along with generating the verification token, can be found on GitHub: [the PuSH views for handling updates and the initial callback](http://github.com/samuelclay/NewsBlur/tree/master/apps/push/views.py) and [the PuSH models used to store subscriptions in the DB](http://github.com/samuelclay/NewsBlur/tree/master/apps/push/models.py). Here’s the main request that your server has to send:

    # Python
    response = self._send_request(hub, {
        'hub.mode' : 'subscribe',
        'hub.callback' : callback,
        'hub.topic' : topic,
        'hub.verify' : ['async', 'sync'],
        'hub.verify_token' : subscription.generate_token('subscribe'),
        'hub.lease_seconds' : lease_seconds,
    })

The publisher will then ping your server back to confirm the subscription. Once the publisher is configured to send blog updates to your server, you just have to let users know when there’s a new story, and that’s takes some COMET/push technology with the help of WebSockets.

## Serving updates to visitors in real-time

When a publisher pushes a new story to your server, apart from dupe detection and storing it in your database, you need to alert users who are currently on the site.

[Redis](http://redis.io) is your new best friend. One of its primary data structures, apart from hashes, sets, sorted sets, and key-value, is a pubsub type that is perfect for this kind of update. Users subscribe to the updates of all of the feeds to which they subscribe. When these sites have a new story, they publish a simple notification to each of the feed’s subscribers.

Here the feed fetcher is publishing to any listening subscribers.

    # Python
    def publish_to_subscribers(self, feed):
        try:
            r = redis.Redis(connection_pool=settings.REDIS_POOL)
            listeners_count = r.publish(str(feed.pk), 'story:new')
            if listeners_count:
                logging.debug(" ---> [%-30s] Published to %s subscribers" % (
                              feed.title[:30], listeners_count))
        except redis.ConnectionError:
            logging.debug(" ***> [%-30s] Redis is unavailable for real-time." % (
                          feed.title[:30],))

These subscribers have subscribed via Redis. To know that a user is currently connected and wants to be notified of updates, [Socket.io](http://socket.io) is used to connect the browser to a Node.js server that will subscribe to updates via Redis.

The browser opens up a WebSocket and listens for updates for the feeds that they care about:

    // JavaScript
    setup_socket_realtime_unread_counts: function() {
        if (!this.socket) {
            var server = window.location.protocol + '//' +
                         window.location.hostname + ':8888';
            this.socket = this.socket || io.connect(server);
    
            this.socket.on('connect', _.bind(function() {
                var active_feeds = this.send_socket_active_feeds();
                console.log(["Connected to real-time pubsub with " + 
                             active_feeds.length + " feeds."]);
    
                this.socket.on('feed:update', _.bind(function(feed_id, message) {
                    console.log(['Real-time feed update', feed_id, message]);
                    this.force_feeds_refresh(false, false, parseInt(feed_id, 10));
                }, this));
    
                this.flags.feed_refreshing_in_realtime = true;
                this.setup_feed_refresh();
            }, this));
    
            this.socket.on('disconnect', _.bind(function() {
                console.log(["Lost connection to real-time pubsub. Falling back to polling."]);
                this.setup_feed_refresh();
            }, this));
        }
    },

The app server is ready to handle thousands of concurrent subscription requests, being Node.js and asynchronous:

    # CoffeeScript
    fs = require 'fs'
    io = require('socket.io').listen 8888
    redis = require 'redis'
    
    REDIS_SERVER = if process.env.NODE_ENV == 'dev' then 'localhost' else 'db01'
    client = redis.createClient 6379, REDIS_SERVER
    
    io.sockets.on 'connection', (socket) ->
        console.log " ---> New connection brings total to" +
                    " #{io.sockets.clients().length} consumers."
        socket.on 'subscribe:feeds', (feeds, username) ->
            socket.subscribe?.end()
            socket.subscribe = redis.createClient 6379, REDIS_SERVER
    
            console.log " ---> [#{username}] Subscribing to #{feeds.length} feeds"
            socket.subscribe.subscribe feeds
    
            socket.subscribe.on 'message', (channel, message) ->
                console.log " ---> [#{username}] Update on #{channel}: #{message}"
                socket.emit 'feed:update', channel
    
        socket.on 'disconnect', () ->
            socket.subscribe?.end()
            console.log " ---> [] Disconnect, there are now" +
                        " #{io.sockets.clients().length-1} consumers."

That’s all there is to it. There a lot going on, but it’s effectively a small circle composed of subscribers and publishers, using Redis to maintain pubsub connections between the many clients and their many feeds.

<script src="http://yandex.st/highlightjs/6.1/highlight.min.js"></script><link rel="stylesheet" type="text/css" href="http://yandex.st/highlightjs/6.1/styles/github.min.css">

<script type="text/javascript">
  hljs.initHighlightingOnLoad();
</script>
