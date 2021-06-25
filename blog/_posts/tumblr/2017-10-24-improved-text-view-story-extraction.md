---
layout: post
title: Improved Text view story extraction
date: '2017-10-24T16:17:25-04:00'
tags:
- web
- ios
- android
tumblr_url: https://blog.newsblur.com/post/166760769571/improved-text-view-story-extraction
redirect_from: /post/166760769571/improved-text-view-story-extraction/
---
The Text view is one of the most popular NewsBlur features. It’s available on all three platforms and gives you the full text of the original story, even in truncated RSS feeds. Up until today, NewsBlur’s implementation of the Text view used Readability’s open source text extractor.

Starting today, all stories will be run through [Postlight Labs’ Mercury Parser](https://mercury.postlight.com/web-parser/). That means that not only will the full text be more likely to correctly pull the entire article, but it will also do a much better job with extracting full size images in stories.

Take a look:

![](https://s3.amazonaws.com/static.newsblur.com/blog/text_view_images.png)

A welcome improvement. This new text extractor and parser also does a better job of handling Unicode and Chinese characters. And when it doesn’t extract text as well as the old text extractor, NewsBlur will automatically fallback on the old method.

