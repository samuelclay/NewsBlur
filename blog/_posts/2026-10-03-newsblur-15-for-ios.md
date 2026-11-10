---
layout: post
title: "NewsBlur 15 for iOS and Mac: faster story lists, a glass toolbar, and Add + Discover Sites"
tags: ["ios"]
image: /assets/ios-15-story-list.png
mobile_release: true
---

I spent a lot of this release optimizing speed in the iOS app. Opening a big folder took over a second, scrolling would hitch whenever the next page of stories loaded, and articles flashed blank for a moment before appearing. So I measured every part of the story list and the reader, then fixed whatever the numbers pointed at.

### Faster story lists

Loading the next page of a folder used to reload the entire list. Now new stories are added in place. Favicons, thumbnails, and story text get prepared in the background ahead of time instead of while you're scrolling. Opening a feed shows its cached stories immediately while fresh ones load, and articles appear fully laid out instead of flashing blank first.

Opening All Site Stories went from 1.1s to 0.2s. A single feed went from 0.7s to 0.2s. Loading another page into a list of 5,000 stories went from 0.7s to 0.02s.

{% include mobile-release-phone.html image="/assets/ios-15-story-list.webp" video="/assets/ios-15-reader.mp4" alt="iPhone story list with the floating glass toolbar at the bottom" %}

### A glass toolbar

The story list toolbar is now a floating glass bar at the bottom of the screen on iPhone and iPad, and your stories scroll right behind it. Related Sites, story order, and search are on the left. Add and Mark as read are on the right. If you'd rather keep it at the top, you can move it back in Preferences. In the reader, the controls hide as you scroll down and come back when you scroll up.

{% include mobile-release-phone.html image="/assets/ios-15-reader.webp" video="/assets/ios-15-article-scroll.mp4" alt="Scrolling an article on iPhone as its floating controls hide and return" %}

### Images

Tap an image in a story and it opens full screen, zooming out from its spot in the article. Pinch or double tap to zoom, drag to look around, and swipe to go back. On iPad the viewer covers all three columns, and you land right back where you were in the story.

Long press an image to see its hover text above it, which is where comics like xkcd hide the punchline. Copy Image, Save Image, and Share Image are right there with it.

{% include mobile-release-phone.html image="/assets/ios-15-image-viewer.webp" video="/assets/ios-15-image-viewer.mp4" alt="An article image opening in the iPhone image viewer and returning to the article" %}

### Add + Discover Sites

The + button opens a Quick Add sheet. Paste an address or search for a site, pick a folder, and add it. Below that are shortcuts into every discovery source: Search, Web Feed, Popular, YouTube, Reddit, Newsletters, Podcasts, and Google News. You can swipe between them like pages. It's the same [Add + Discover Sites](/2026/03/04/add-and-discover-sites/) catalog from the web, rebuilt natively for iOS.

{% include mobile-release-phone.html image="/assets/ios-15-add-site.webp" video="/assets/ios-15-add-site.mp4" alt="The iPhone Add Site sheet with an address field and discovery source shortcuts" %}

Each site shows its latest stories with an image and a short excerpt, along with how recently it published. Tap a story to read it, or tap **Try** to browse the site without subscribing. When you come back, you're in the same spot with that story highlighted. On iPad, Try keeps all three columns, so you can browse a new site and read its stories side by side. Related Sites uses the same cards.

{% include mobile-release-phone.html image="/assets/ios-15-discover.webp" video="/assets/ios-15-discover.mp4" alt="Opening a story from iPhone discovery results and returning to its highlighted preview" %}

### Offline storage that cleans up after itself

A reader on the forum noticed NewsBlur using 4.2 GB on their iPhone with no unread stories. Digging in turned up three bugs in the offline cache. Cleanup skipped pruning whenever you were all caught up, it never cleared cached article text, and it compacted the database before deleting anything, so no space ever came back.

All three are fixed. Cleanup now keeps storage within your Stories to store limit, and **Delete offline stories** in Preferences actually gives you the space back. Your subscriptions and any pending read or save changes are kept.

### Everything else

- Long press any feed, folder, or story for a native menu.
- Mark newer as read and Mark older as read update your unread counts right away, even inside collapsed folders and while offline.
- Feed and story gestures each have their own settings.
- The Mac app gets the new discovery screen, image viewer, menus, and offline cleanup too.
- Tapping a notification opens the story instead of sometimes getting stuck.
- Reading positions are restored correctly.

NewsBlur 15 is available on the [App Store](https://apps.apple.com/app/newsblur/id463981119) for iPhone, iPad, and Mac. The [Android release](/2026/10/03/newsblur-15-for-android/) got a lot of the same work. If you have feedback, I'd love to hear it on the [NewsBlur forum](https://forum.newsblur.com).
