---
layout: post
title: Redesigning NewsBlur on the web, iOS, and Android
tags: ['backend', 'web', 'ios', 'android']
draft: true
---
This past year we've focused on maintenance and improving quality behind the scenes. It just so happens that the urge to clean is so strong that this work extended to the front-end. After months of work, today we're launching a redesigned NewsBlur for all three platforms: on the web, on iOS, and on Android. There's a lot that's new.

To start, let's take a look below at the redesigned NewsBlur.

<img src="/assets/redesign-web.jpg" style="width: 750px;">

Loads of new features:

 * The dashboard now has multiple, customizable rivers of news
 * Image previews are now customizable by size and layout
 * Story previews are also customizable by length
 * Images are now full bleed on the web (edge-to-edge)
 * Controls have been re-styled and made more accessible
 * Sizes, spaces, and text have all been tweaked for a more legible read
 * Upgraded backend: Python 2 to Python 3, latest Django and libraries, containerized infrastructure
 * Both Android and iOS apps have been updated with the new design

Below you can see the design in action. Notice how easy it is to change where the image preview is located as well as adjust the number of lines of story text to show.

<p>
    <video autoplay loop playsinline width="500" style="width: 500px;margin: 0 auto;display: block; border: 2px solid rgba(0,0,0,0.1)">
        <source src="/assets/redesign-content-preview.mp4" type="video/mp4">
    </video>
</p>

The reading experience itself has also seen improvement. Full bleed images have been ported over from iOS to both Android and the web. This means that images will now run edge-to-edge. And the controls at the top and bottom of the web app have been restyled to be easier to understand at a quick glance.

<img src="/assets/redesign-full-bleed.jpg" style="margin: 0 auto; border: 2px solid rgba(0,0,0,0.1);">

And on mobile:

<img src="/assets/redesign-ios-android.jpg" style="width: 750px;">

This whole redesign weighs in at a whopping 1,316 commits, which [you can view on GitHub](https://github.com/samuelclay/NewsBlur/compare/dashboard3).
