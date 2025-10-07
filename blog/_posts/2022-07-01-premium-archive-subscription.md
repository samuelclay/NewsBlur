---
layout: post
title: NewsBlur Premium Archive subscription keeps all of your stories searchable, shareable, and unread forever
tags: ['web', 'ios', 'android']
---

For $99/year every story from every site you subscribe to will stay in NewsBlur's archive. This new premium tier also allows you to mark any story as unread as well as choose when stories are automatically marked as read. You can now have full control of your story archive, letting you search, share, and read stories forever without having to worry about them being deleted.

The NewsBlur Premium Archive subscription offers you the following:

 * <img src="/assets/icons8/icons8-bursts-100.png" style="width: 16px;margin: 0 6px 0 0;display: inline-block;"> Everything in the premium subscription, of course
 * <img src="/assets/icons8/icons8-relax-with-book-100.png" style="width: 16px;margin: 0 6px 0 0;display: inline-block;"> Choose when stories are automatically marked as read
 * <img src="/assets/icons8/icons8-filing-cabinet-100.png" style="width: 16px;margin: 0 6px 0 0;display: inline-block;"> Every story from every site is archived and searchable forever
 * <img src="/assets/icons8/icons8-quadcopter-100.png" style="width: 16px;margin: 0 6px 0 0;display: inline-block;"> Feeds that support paging are back-filled in for a complete archive
 * <img src="/assets/icons8/icons8-rss-100.png" style="width: 16px;margin: 0 6px 0 0;display: inline-block;"> Export trained stories from folders as RSS feeds
 * <img src="/assets/icons8/icons8-calendar-100.png" style="width: 16px;margin: 0 6px 0 0;display: inline-block;"> Stories can stay unread forever

You can now enjoy a new preference for exactly when stories are marked as read:

<img src="/assets/premium-archive-mark-read-date.png" style="width: 100%;border: 1px solid #A0A0A0;margin: 24px auto;display: block;">

A technical note about the backfilling of your archive: 

<blockquote>
<p>NewsBlur uses two techniques to retrieve older stories that are no longer in the RSS feed. The first strategy is to append `?page=2` and `?paged=2` to the RSS feed and seeing if we're about to blindly iterate through the blog's archive. For WordPress and a few other CMSs, this works great and gives us a full archive. </p>

<p>A second technique is to use <a href="https://datatracker.ietf.org/doc/html/rfc5005">RFC 5005</a>, which supports links embedded inside the RSS feed to denote next and previous pages of an archive.</p>
</blockquote>

NewsBlur attempts all of these techniques on every single feed you've subscribed to, and when it's done backfilling stories, you'll receive an email showing you how big your archive grew during this backfill process.

The launch of the new Premium Archive subscription tier also contains the [2022 redesign](/2022/07/01/dashboard-redesign-2022/), which includes a new dashboard layout, a refreshed design for story titles and feed title, and all new icons.

Here's a screenshot that's only possible with the new premium archive, complete with backfilled blog post from the year 2000, ready to be marked as unread.

<img src="/assets/premium-archive-unread.png" style="width: 100%;border: 1px solid #A0A0A0;margin: 24px auto;display: block;">

How's that for an archive?
