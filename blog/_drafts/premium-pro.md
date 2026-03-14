---
layout: post
title: "Introducing Premium Pro: high-frequency fetching and precision regex filtering"
tags: ["web"]
---

Some of you don't just read the news. You monitor it. You're tracking competitors, watching for security disclosures, following regulatory changes, or covering a beat where being 30 minutes late means you missed the story. NewsBlur has always been a great reader, but for people who need it to be a monitoring tool, I wanted to build something that takes feed fetching and filtering seriously.

Premium Pro is the new top tier. It includes everything in <a href="https://newsblur.com/pricing/archive">Premium Archive</a> and adds three things that matter when speed and precision are the priority: high-frequency fetching, regex-powered training, and a 10,000 site limit.

### Every feed fetched every 5 minutes

This is the headline feature. When you're on Pro, every single feed in your account is checked every 5 minutes. This isn't based on how often the feed publishes or how popular it is. It's every feed, every time, regardless.

<!-- SCREENSHOT: Feed statistics showing 5-minute fetch interval -->
<img src="/assets/pro-fetch-frequency.png" style="width: 90%;border: 1px solid rgba(0,0,0,0.1);margin: 24px auto;display: block;">

For context, most RSS readers check feeds every hour or two. Even NewsBlur's Premium tier updates feeds up to 5x more often than standard, but Pro goes further. If a CVE drops, a competitor publishes a press release, or a regulatory filing appears, you'll see it in minutes, not hours.

### Notifications that actually keep up

Fast fetching only matters if you find out about new stories quickly. NewsBlur has a full notification system that pairs perfectly with Pro's 5-minute polling. You can enable notifications per feed and choose whether to be notified about all unread stories or only Focus stories that match your intelligence training.

Notifications go to every platform at once: iOS push notifications, Android push notifications, browser notifications on the web, Mac notifications, and email. Set up a few critical feeds with notifications enabled and you have a real-time alerting pipeline built on RSS.

<!-- SCREENSHOT: Collage showing notifications arriving simultaneously on iOS, Android, Mac, web browser, and email -->
<img src="/assets/pro-notifications-all-platforms.png" style="width: 100%;border: 1px solid rgba(0,0,0,0.1);margin: 24px auto;display: block;">

<!-- SCREENSHOT: Notification settings modal for a feed showing channel toggles and Focus filter -->
<img src="/assets/pro-notification-settings.png" style="width: 60%;border: 1px solid rgba(0,0,0,0.1);margin: 24px auto;display: block;">

### Train stories with regular expressions

The Intelligence Trainer already lets you filter stories by author, tag, title, text, and URL. But exact phrase matching has limits. If you want to catch "iPhone" and "iPad" and "MacBook" in one classifier, you need three separate entries. With regex mode, that's just `iPhone|iPad|MacBook`.

<!-- SCREENSHOT: Regex mode toggle in the Intelligence Trainer showing a pattern -->
<img src="/assets/pro-regex-training.png" style="width: 90%;border: 1px solid rgba(0,0,0,0.1);margin: 24px auto;display: block;">

Regex patterns work on titles, body text, and URLs. Some examples of what you can build:

- **Security monitoring**: `\bCVE-\d{4}-\d+\b` matches any CVE identifier
- **Multi-product tracking**: `iPhone|iPad|MacBook|Vision Pro` in one classifier
- **Filtering sponsored content**: `/sponsored/|/partner/` on URLs to hide or highlight paid posts
- **Price alerts**: `\$\d{1,3}(,\d{3})*\.\d{2}` to catch dollar amounts in stories

The trainer validates patterns in real-time and includes a help popover with syntax examples. Regex matching is case-insensitive, so `apple` catches "Apple", "APPLE", and "apple". I wrote more about regex mode in the <a href="/2026/01/22/intelligence-trainer-overhaul/">Intelligence Trainer overhaul post</a>.

### Follow up to 10,000 sites

Pro raises the feed limit to 10,000. Premium supports 1,024 sites, Archive supports 4,096, and Pro takes it to 10,000. If you need comprehensive coverage across industries, beats, competitors, or research domains, this is the ceiling you've been looking for.

### Everything in Archive, included

Pro includes the full <a href="https://newsblur.com/pricing/archive">Premium Archive</a> feature set. That means every story archived and searchable forever, Ask AI for answering questions about stories, full-text content training, global and folder-scoped intelligence training, per-feed auto-mark-read timers, and more. Pro adds speed and precision on top of that foundation.

You also get priority support, so when you need help, you're at the front of the line.

### Pricing

Premium Pro is $29/month. It's monthly rather than yearly because the high-frequency fetching infrastructure costs more to operate. You're paying for dedicated polling of up to 10,000 feeds every 5 minutes, and the regex processing that runs against every incoming story. If your work depends on being the first to know, Pro pays for itself.

You can upgrade from the <a href="https://newsblur.com/?next=premium">Premium page</a> on the web. If you have feedback or ideas for Pro, I'd love to hear them on the <a href="https://forum.newsblur.com">NewsBlur forum</a>.
