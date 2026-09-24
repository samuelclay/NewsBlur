---
layout: post
title: "NewsBlur v15 for Android: Smoother scrolling, Add + Discover Sites, floating toolbars, and a new image viewer"
tags: ["android"]
---

I read NewsBlur on my Android phone every day, and for a while now it hasn't felt as quick as it should. The feed list would hitch while scrolling, opening a story took a beat too long, and marking a story read made the whole list stutter. So for v15 I started with performance. I measured scrolling across the feed list, the story list, and long articles, then fixed whatever the numbers pointed at.

With that foundation in place, v15 also brings the Add + Discover Sites experience from the web to Android, along with floating toolbars, full bleed images with a new image viewer, and gestures you can configure.

### Smoother scrolling and faster story opens

Most of the slowness came from the app doing far more work than it needed to:

- Marking a story read used to rebuild its entire row, parsing the title again and reloading the thumbnail. Now only the read styling changes, with a short fade.
- Background syncs could overlap, with a canceled sync still doing network work while its replacement started. Syncs now run one at a time.
- The feed list waited for the sync service before showing anything. It now loads straight from the local cache, so your feeds show up right away and work fully offline.
- The reader waited for the article to finish rendering before appearing. Now it slides in immediately with the title, and the article fades in a moment later.

The difference is easy to feel, and it shows up in the measurements too:

- Janky frames while scrolling the feed list dropped from 32% to 15%.
- Janky frames while scrolling the story list dropped from 14% to 7%.
- The worst stall while scrolling a long article went from 152ms to 88ms.
- Opening a story you've opened before went from 889ms to 189ms.

<video autoplay loop muted playsinline width="720" height="1466" style="width: 45%;height: auto;margin: 24px auto;display: block;">
<source src="/assets/android-15-scroll.mp4" type="video/mp4">
</video>

### Add + Discover Sites

The + button in the feed list now opens a compact Add Site sheet. Paste a URL or search for a site, pick a folder, and add it. Below that are eight shortcuts into discovery: Web Feed, Popular, Trending, YouTube, Reddit, Newsletters, Podcasts, and Google News.

Each shortcut opens the full Add + Discover Sites screen, the same one I launched [on the web](/2026/03/04/add-and-discover-sites/) earlier this year. Browse by category, search within a source, and add a site straight into the folder you want. Folder pickers remember the last folder you chose, and Web Feed turns any website into a feed.

<video autoplay loop muted playsinline width="720" height="1466" style="width: 45%;height: auto;margin: 24px auto;display: block;">
<source src="/assets/android-15-discover.mp4" type="video/mp4">
</video>

Every site has a Try button that previews its stories without subscribing. If a feed hasn't been fetched in a while, the preview fetches fresh stories automatically and shows you its progress. Tap a story in a discovery card and it opens that exact story, with the rest of the site's stories loaded behind it.

Related Sites uses the same cards. Tap the Related Sites button on the left side of the story list toolbar, or pick it from the feed menu, to see similar sites along with their latest stories, images, and excerpts. Your Grid or List choice carries over between the two.

<img src="/assets/android-15-related-sites.png" style="width: 45%;margin: 24px auto;display: block;">

### Floating toolbars

The story list controls now float at the bottom of the screen, so stories scroll right behind them and you get more room to read. If you'd rather have them at the top, there's a Story list toolbar position setting under Story Layout in Preferences. The feed list has a single floating capsule too, with Add on the left, the All, Unread, Focus, and Saved filter in the middle, and settings on the right.

In the reader, the toolbar hides as you scroll down and comes back the moment you scroll up.

<img src="/assets/android-15-story-list.png" style="width: 45%;margin: 24px auto;display: block;">

### Full bleed images and a new image viewer

Wide article images now run edge to edge, in both portrait and landscape. Tap any image to open it full screen. Double tap to zoom in, pinch to zoom further, drag to pan around, and swipe in any direction to dismiss it and go right back to the article.

<video autoplay loop muted playsinline width="720" height="1466" style="width: 45%;height: auto;margin: 24px auto;display: block;">
<source src="/assets/android-15-reader.mp4" type="video/mp4">
</video>

### Gestures, your way

There's a new Gestures section in Preferences. Choose what swiping left and right does on feeds and on stories, what a long press does (saving a story is a new option), and what a double tap does in the reader. Rows now follow your finger as you swipe and show an icon for the action you're about to trigger.

<img src="/assets/android-15-gestures.png" style="width: 45%;margin: 24px auto;display: block;">

### Menus that stay out of the way

Menus now fade in and grow out of the button you tapped. Long press a feed or a story and you get a grouped menu with icons, including Mark newer as read and Mark older as read. Font size, list density, and theme are right in the settings menu, so changing them doesn't mean digging through Preferences.

<div style="display: flex; gap: 12px; justify-content: center; margin: 24px auto;">
<img src="/assets/android-15-story-menu.png" style="width: 45%;">
<img src="/assets/android-15-appearance-menu.png" style="width: 45%;">
</div>

### Everything else

Beyond the headline features, this release includes a long list of improvements and fixes.

#### Improvements

- Nested folders show up as an indented tree, and folder pickers can choose subfolders and create new folders inside them.
- A single Mark stories read setting covers on scroll or selection, on selection only, after a delay of 1 to 60 seconds, or manually.
- Matching stories from other sites are marked read along with the story they match, following your web preference.
- The story you tapped stays highlighted while the reader opens. When you go back, the list scrolls to the last story you read and fades its highlight.
- Next and Previous prepare the next story before it animates in, so you never see a blank page.
- Story rows use Whitney to match iOS, and long headlines wrap in balanced lines.
- Folders animate smoothly as they expand and collapse.

#### Fixes

- Fixed the next folder search looping forever when nothing was unread.
- Fixed the Previous button sometimes being disabled.
- Fixed dark bands appearing during folder animations.
- Fixed an older bulk mark read overriding stories you had since marked unread.

NewsBlur v15 for Android is available now on the [Google Play Store](https://play.google.com/store/apps/details?id=com.newsblur). The same performance and discovery work also shipped in [NewsBlur v15 for iOS and Mac](/2026/09/23/newsblur-v15-for-ios-and-mac/). If you have feedback or run into issues, I'd love to hear about it on the [NewsBlur forum](https://forum.newsblur.com).
