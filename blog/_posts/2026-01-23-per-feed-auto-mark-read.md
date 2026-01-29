---
layout: post
title: "Premium Archive: Per-feed and per-folder auto-mark-as-read settings"
tags: ["web"]
---

Some feeds I want to read every single story. Others I'm happy to skim once a week. And a few high-volume feeds I only check occasionally, so stories older than a day or two aren't worth catching up on. <a href="https://newsblur.com/?next=premium">Premium Archive</a> subscribers get the site-wide "days of unread" setting, but it was too blunt, applying the same rule to everything. Now you can set how long stories stay unread on a per-feed and per-folder basis.

### How it works

Open the feed options popover (click the gear icon in the feed header) and you'll see a new "Auto Mark as Read" section. Choose how many days stories should remain unread before NewsBlur automatically marks them as read:

<!-- SCREENSHOT: Feed options popover showing Auto Mark as Read section with slider -->
<img src="/assets/auto-mark-read-popover.png" style="width: 100%;border: 1px solid rgba(0,0,0,0.1);margin: 24px auto;display: block;">

The slider goes from 1 day to 365 days, with a "never" zone at the far right for feeds where you truly want to read every story regardless of age. Choose "Default" to inherit from the parent folder or site-wide setting, "Days" to set a specific duration, or "Never" to disable auto-marking entirely.

### Folder inheritance

Settings cascade down from folders to feeds. Set a folder to 7 days, and all feeds inside inherit that setting unless they have their own override. This is perfect for organizing feeds by how aggressively you want to age them out:

- **Must Read** folder: Set to "Never" so nothing ages out
- **News** folder: Set to 2 days since news gets stale fast
- **Blogs** folder: Set to 30 days for long-form content worth revisiting
- Individual feeds can still override their folder's setting

<!-- SCREENSHOT: Folder settings dialog showing Auto Mark as Read with inheritance text -->
<img src="/assets/auto-mark-read-folder-settings.png" style="width: 80%;border: 1px solid rgba(0,0,0,0.1);margin: 24px auto;display: block;">

The status text below the slider shows where the current setting comes from: the site-wide preference, a parent folder, or an explicit setting on this feed.

### Site settings dialog

You can also configure auto-mark-read from the site settings dialog (right-click a feed and choose "Site settings"). The same controls are available there, redesigned to match the popover style.

<!-- SCREENSHOT: Site settings dialog showing Auto Mark as Read section -->
<img src="/assets/auto-mark-read-site-settings.png" style="width: 80%;border: 1px solid rgba(0,0,0,0.1);margin: 24px auto;display: block;">

### Availability

Per-feed and per-folder auto-mark-as-read settings are a <a href="https://newsblur.com/?next=premium">Premium Archive</a> feature, available now on the web. They work alongside the existing site-wide "days of unread" preference in Manage → Preferences → General → Days of unreads, which is also a Premium Archive feature.

If you have feedback or ideas for improvements, please share them on the <a href="https://forum.newsblur.com">NewsBlur forum</a>.
