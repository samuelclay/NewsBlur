---
layout: post
title: "NewsBlur v15 for iOS and Mac: Faster story lists, Add + Discover Sites, glass toolbars, and a new image viewer"
tags: ["ios"]
---

I use NewsBlur on my iPhone and iPad all day, and the story list had gotten slower than I wanted. Opening a big folder took over a second, scrolling would hitch whenever the next page of stories loaded, and articles would flash blank for a moment before appearing. So I spent this release measuring every part of the story list and reader, then fixing what the numbers pointed at.

On top of that, v15 brings the full Add + Discover Sites experience to iPhone, iPad, and Mac, along with a glass story list toolbar, a new image viewer, native context menus, and offline storage that finally cleans up after itself.

Here's what's new.

### Faster story lists and smoother scrolling

Most of the slowness came from work happening at the wrong time or happening more often than it needed to:

- Loading the next page of a folder reloaded the entire story list. New stories are now appended in place.
- Feeds tucked inside collapsed folders were still building rows and loading favicons. They're skipped now.
- Favicons, thumbnails, and story text were being read and measured on the main thread while you scrolled. That work now happens in the background, ahead of time.
- Opening a feed waited on the server before showing anything. Now the first page appears immediately from cache, and fresh stories merge in as they arrive.
- Articles used to slide in blank and then fill in. Now the reader appears right away, and the article fades in fully laid out.

The measurements:

- Opening All Site Stories went from 1,148ms to 208ms.
- Opening a single feed went from 671ms to 233ms.
- Loading another page into a list of 5,000 stories went from 722ms to 22ms.
- Stalls during the first fast scroll through the feed list after launch dropped by 86%.

<video autoplay loop muted playsinline width="720" height="1472" style="width: 45%;height: auto;margin: 24px auto;display: block;">
<source src="/assets/ios-15-scroll.mp4" type="video/mp4">
</video>

### Add + Discover Sites

Add + Discover Sites now sits at the top of your feed list. The + button in the bottom toolbar opens a Quick Add sheet where you can paste a URL or search for a site, pick a folder, and add it, with shortcuts below into every discovery source.

The discovery screen itself covers Search, Web Feed, Popular, YouTube, Reddit, Newsletters, Podcasts, and Google News, and you can swipe between them like pages. Each source has categories to browse and a Grid or List view. List view shows the latest few stories from each site with an image and a short excerpt, so you know what you're getting before you subscribe. Every card also shows how recently the site published, and there's a folder picker right next to each Add button that remembers the last folder you chose.

<video autoplay loop muted playsinline width="720" height="1472" style="width: 45%;height: auto;margin: 24px auto;display: block;">
<source src="/assets/ios-15-discover.mp4" type="video/mp4">
</video>

If you've used [Add + Discover Sites on the web](/2026/03/04/add-and-discover-sites/), this is the same catalog, rebuilt natively for iOS.

### Try before you subscribe

Tap Try on any site to preview its stories without subscribing. A banner at the top lets you subscribe once you've decided. If the feed hasn't been fetched in a while, the preview fetches fresh stories automatically. Tapping a story in a discovery card opens that exact story, and when you come back, Discover returns you to the same spot in the list with that story highlighted.

On iPad, Try keeps all three columns in place, so you can browse a new site's stories and read them side by side.

### Related Sites

The Related Sites button in the story list toolbar now uses the same cards as discovery, with story excerpts, freshness, and Try, folder, and Add buttons. Tapping one of its stories closes Related Sites and opens that exact article.

<video autoplay loop muted playsinline width="720" height="1472" style="width: 45%;height: auto;margin: 24px auto;display: block;">
<source src="/assets/ios-15-related.mp4" type="video/mp4">
</video>

### A glass story list toolbar

The story list toolbar is now a floating glass footer on both iPhone and iPad. Your stories scroll right behind it. Related Sites, the story order menu, and search sit on the left, with Add and Mark as read on the right. When there's room, the two groups separate and search gets its label back. If you'd rather keep the toolbar at the top, change Story list toolbar position under Story Layout in Preferences.

<img src="/assets/ios-15-story-list.png" style="width: 45%;margin: 24px auto;display: block;">

### A new image viewer

Tap any image in an article and it opens in a full screen viewer, animating out from its spot in the story. Pinch or double tap to zoom, drag to pan, and tap or swipe in any direction to go back to the story. The menu in the corner has Save Image, Copy Image, Share Image, and Open Image in Browser. On iPad, the viewer covers all three columns, and your reading position is right where you left it when you close it.

<video autoplay loop muted playsinline width="720" height="1472" style="width: 45%;height: auto;margin: 24px auto;display: block;">
<source src="/assets/ios-15-reader.mp4" type="video/mp4">
</video>

### Native context menus

Long press any feed, folder, or story for a native context menu. Story menus include Mark as read, Mark newer as read, Mark older as read, Save, sharing, Share on NewsBlur, Train intelligence, and Ask AI. Mark newer and Mark older now include the story you pressed and update your unread counts right away, including in collapsed folders. Settings and reader menus got the same treatment, with grouped actions, grayscale icons, and inline appearance controls.

<video autoplay loop muted playsinline width="720" height="1472" style="width: 45%;height: auto;margin: 24px auto;display: block;">
<source src="/assets/ios-15-menu.mp4" type="video/mp4">
</video>

### Offline storage that cleans up after itself

A reader on the forum found NewsBlur using 4.2 GB on their iPhone with no unread stories. Digging in turned up three bugs in the offline cache. Automatic cleanup skipped pruning whenever you had fewer unread stories than your storage limit, which is exactly the case when you're all caught up. It also never cleared cached article text because it was pointed at the wrong table, and it compacted the database before deleting anything, so no space came back.

Automatic cleanup now keeps storage within your Stories to store limit, giving unread stories priority and filling the remaining space with recent read stories. Delete offline stories under Offline Stories in Preferences clears cached stories, article text, and images and actually reclaims the space. In testing, it shrank an 8.5 MB database down to 115 KB. Your subscriptions and any pending read or saved changes are preserved.

### Everything else

Beyond the headline features, this release includes a long list of improvements and fixes across iPhone, iPad, and Mac.

#### Improvements

- The Mac app gets the new discovery screen, Related Sites cards, image viewer, menus, and offline cleanup.
- Explicitly selecting the same feed or folder again clears the old story and loads fresh titles, opening the first story if you have that preference on.
- In phone landscape, Related Sites opens as a popover you can close by tapping outside.
- Compact phone landscape headers no longer waste space under the status bar.
- At the largest accessibility text sizes, discovery keeps the search field usable.
- Trained URLs are easier to read in the gray theme.

#### Fixes

- Fixed tapping a notification sometimes getting stuck instead of opening the story.
- Fixed reading positions not being restored correctly.
- Fixed the trainer and other dialogs disappearing while the reader was still loading.
- Fixed unread counts going stale after Mark newer or older as read, including while offline.
- Fixed a number of story selection and theme issues.

NewsBlur v15 is available now on the [App Store](https://apps.apple.com/app/newsblur/id463981119) for iPhone, iPad, and Mac. The same performance and discovery work also shipped in [NewsBlur v15 for Android](/2026/09/23/newsblur-v15-for-android/). If you have feedback or run into issues, I'd love to hear about it on the [NewsBlur forum](https://forum.newsblur.com).
