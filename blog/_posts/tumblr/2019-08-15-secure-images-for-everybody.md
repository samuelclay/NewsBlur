---
layout: post
title: Secure images for everybody
date: '2019-08-15T10:59:11-04:00'
tags:
- web
tumblr_url: https://blog.newsblur.com/post/187031418021/secure-images-for-everybody
redirect_from: /post/187031418021/secure-images-for-everybody/
---
There are two ways to connect to the NewsBlur website. The first is _http_://www.newsblur.com. The second is _https_://www.newsblur.com. The first is plain text and the second is encrypted. You get to choose which one you want to use.

Part of the draw of using an encrypted https connection instead of a plain text http connection is that you can protect your privacy. As far as I can tell, there are two reasons for preferring https over http.

One is that using an encrypted https connection to NewsBlur protects what you read from hackers or a man-in-the-middle changing your data as it comes to you. This could be your internet service provider (ISP) inserting ads or it could be snooping wifi router that you are connected to that injects malware into your content. Some companies have been known to do this and https protects you.

But the second reason is that your privacy is also protected from more benign, aggregate collections by ISPs and middlemen that sees what you read and sells that data. NewsBlur doesn’t sell any of your data and beginning this week NewsBlur can ensure that nobody other than you and the site you read can either.

The feature that is launching this week (it actually launched Monday in order for me to ensure that it works well) is a secure image proxy for all images served on NewsBlur. That means that NewsBlur will take any images that isn’t behind an encrypted https connection and proxies it behind NewsBlur’s own secure, encrypted connection.

<figure class="tmblr-full" data-orig-height="1021" data-orig-width="1110" data-orig-src="https://s3.amazonaws.com/static.newsblur.com/blog/https-proxy.png"><img width="650" style="margin: 0 auto; width: 650px;" data-orig-height="1021" data-orig-width="1110" src="https://s3.amazonaws.com/static.newsblur.com/blog/https-proxy.png"></figure>

You should notice next to no difference. The only difference you may notice is that some images may load _faster_, since NewsBlur has a thicker pipe to the Internet and can download data faster than your client browser can, which means that your persistent connection to NewsBlur’s servers takes over instead of having to make new connections with the associated overhead to various servers around the net.

<figure class="tmblr-full" data-orig-height="488" data-orig-width="1392" data-orig-src="https://s3.amazonaws.com/static.newsblur.com/blog/https-preference.png"><img style="margin: 0 auto; border: 1px solid #A0A0A0;" data-orig-height="488" data-orig-width="1392" src="https://s3.amazonaws.com/static.newsblur.com/blog/https-preference.png"></figure>

Now you can turn on the SSL setting on the NewsBlur Web and ensure your data stays private.

And to answer the question of why you wouldn’t wan t to use https — it used to mean serving and loading pages over https gave a slight performance hit, but that’s no longer true. But some people use http because it will load images from both http and https websites, whereas loading NewsBlur via https means that you can only load images via https, as loading an image via http will throw up a Mixed Content Warning. This update addresses that issue and it is my hope that http-only will be phased out.

