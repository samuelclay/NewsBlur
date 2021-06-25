---
layout: post
title: A new way to use the Story view while on https (SSL)
date: '2014-10-31T07:00:36-04:00'
tags:
- web
tumblr_url: https://blog.newsblur.com/post/101418566769/a-new-way-to-use-the-story-view-while-on-https
redirect_from: /post/101418566769/a-new-way-to-use-the-story-view-while-on-https/
---
Modern browsers are taking your privacy and security seriously with new restrictions for sites that use https. You can choose to use NewsBlur over https, which will encrypt your communications with NewsBlur and prevent eavesdroppers—hackers, the government, other people on the same wireless network as you—from seeing what you see. While that’s not necessary for everybody, SSL/https is a priority for some and NewsBlur supports this beautifully.

[![](https://s3.amazonaws.com/static.newsblur.com/blog/SSL%20labs.png)](https://www.ssllabs.com/ssltest/analyze.html?d=newsblur.com)

However, what modern browsers like Chrome and Firefox do is not allow you to embed an insecure http-only site in an iframe from a secure https site. That means that the Story view in NewsBlur does not load a thing for many users who are reading NewsBlur over an https connection.

Today I’m launching a fix for this. It’s not perfect, but this will allow you to still get at some of the content while getting around the https-only issue. This feature will proxy http-only sites in the Story view, resulting in a hacked-together but workable view of the original story.

At best, the Story view will look like this:

![](https://s3.amazonaws.com/static.newsblur.com/blog/Story%20Proxy%20view.png)

At worst, the Story view will look like this:

![](https://s3.amazonaws.com/static.newsblur.com/blog/Story%20Proxy%20view%20truncated.png)

While it’s not ideal, it’s a whole lot better than a blank page. Let me know how this new proxied Story view works for you. And if you want it to work flawlessly and are willing to use an unencrypted connection, just use the http version of NewsBlur instead of the https version.

