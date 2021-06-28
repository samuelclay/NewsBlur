---
layout: post
title: Explaining Intelligence
date: '2011-04-01T11:11:33-04:00'
tags: []
tumblr_url: https://blog.newsblur.com/post/4262089560/explaining-intelligence
redirect_from: /post/4262089560/explaining-intelligence/
---
If you’re not using intelligence classifiers, you’re only getting half the value out of NewsBlur.&nbsp;

Intelligence classifiers are the phrases, tags, and authors that you like and dislike. Training your sites by choosing classifiers for each feed will automatically highlight the stories you want to read and hide the stories you don’t want to see.

<figure class="tmblr-full" data-orig-height="298" data-orig-width="600" data-orig-src="http://f.cl.ly/items/1J1N2e2Q0E133N3R0r3m/slider_states.png"><img data-orig-height="298" data-orig-width="600" src="http://f.cl.ly/items/1J1N2e2Q0E133N3R0r3m/slider_states.png"></figure>

## How to train intelligence

To train your feeds, you have four options:

1) Train everything at once using the intelligence trainer, linked to from the Dashboard:

<figure class="tmblr-full" data-orig-height="95" data-orig-width="471"><img src="https://64.media.tumblr.com/cd8ffc2728c10f595c7fac06ce4f42b4/1a17e4479e9a96eb-0d/s540x810/d068b09f480a0052176b5a146e87761b13e08489.png" data-orig-height="95" data-orig-width="471"></figure>

2) Train a feed individually:

<figure data-orig-height="272" data-orig-width="266"><img src="https://64.media.tumblr.com/32a74af0de7004dbfceee0632e014f35/1a17e4479e9a96eb-62/s540x810/c27823f31bb1d19c39d9a1a05fdffa8a54958ca1.png" align="middle" data-orig-height="272" data-orig-width="266"></figure>&nbsp;&nbsp;<figure data-orig-height="71" data-orig-width="264"><img src="https://64.media.tumblr.com/6cdfff509662b28d905a2b9d59c07b43/1a17e4479e9a96eb-f6/s540x810/878ded95af12fc01e5c699422bb64bdc04aae1e3.png" align="middle" data-orig-height="71" data-orig-width="264"></figure>

3) Train a story:

![](http://f.cl.ly/items/3G1w0X3P2i0T2J1L2D2K/story_trainer.png)

4) Choose tags and authors in the Feed view:

![](http://f.cl.ly/items/2o2x0b1E3I0F2Z273i0F/story_tags.png)

## What’s happening under the hood

To get a better picture of how stories are being classified into the red, yellow, and green states, we need to take a look at how NewsBlur is using your intelligence classifiers and applying them to stories.

When you select a tag, author, or phrase, NewsBlur looks for an exact match in all other stories in the same feed. It’s a very simple match, and nothing mysterious is happening without you being explicit about what you want to see.

Green always wins. If you have 2 green classifiers and 3 red classifiers on a single story, the story will show up green, since it’s clear there is at least \*something\* you like about the story.

However, classifying the publisher (i.e. the feed itself) works slightly differently. If you specify that you like or dislike the feed, all stories are automatically classified according to this preference, unless there is a tag, author, or title phrase that is classified, in which case it wins over the feed’s classification.

This offers a neat trick to hide most stories from a feed, even in the yellow intelligence state, except for the few stories that you want to watch. Simply train the feed to dislike the feed itself, but give a thumbs up to the tags/authors/phrases in the stories you want to read. This will result in all stories being either red or green, which keeps the site out of your yellow intelligence setting.

## What’s in store for the future

Right now the intelligence classifiers are pretty naive. But the impetus for building NewsBlur was to passively train your feeds, just based on your implicit preferences. There’s a lot of work to be done to make this happen, and you can follow NewsBlur’s progress over on GitHub at [http://github.com/samuelclay](http://github.com/samuelclay).

