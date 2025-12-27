---
layout: post
title: Auto-enable captions on YouTube videos
tags: ['web']
---

You can now automatically enable captions on YouTube videos embedded in your feeds. Head to Preferences > Stories and check the new "YouTube Captions" option.

<img src="/assets/youtube-captions-preference.png" style="border: 1px solid rgba(0,0,0,0.1);">

When enabled, any YouTube video in any story will automatically show captions when you start playing it (assuming the video has captions available). This is great for watching videos in noisy environments, for accessibility, or for following along in a language you're learning.

<img src="/assets/youtube-captions-video.png" style="border: 1px solid rgba(0,0,0,0.1);">

This works by adding the `cc_load_policy=1` parameter to YouTube embed URLs on-the-fly, so it applies to all your feeds without modifying the original content. The preference is off by default, so existing behavior is unchanged unless you opt in.
