---
layout: post
title: Premium Archive subscription keeps all of your stories searchable, shareable, and unread forever
tags: ['web']
---

There's a new premium tier and it's called the NewsBlur Premium Archive subscription. For $99/year, every story from every site you subscribe to will stay in NewsBlur's archive. This premium tier also allows you to mark any story as unread as well as choose when stories are automatically marked as read. You can now have full control of your story archive, letting you search, share, and read stories forever without having to worry about them being deleted.

The Premium Archive subscription offers you the following:

 * <img src="/assets/icons8/icons8-bursts-100.png" style="width: 16px;margin: 0 6px 0 0;display: inline-block;"> Everything in the premium subscription, of course
 * <img src="/assets/icons8/icons8-relax-with-book-100.png" style="width: 16px;margin: 0 6px 0 0;display: inline-block;"> Choose when stories are automatically marked as read
 * <img src="/assets/icons8/icons8-filing-cabinet-100.png" style="width: 16px;margin: 0 6px 0 0;display: inline-block;"> Every story from every site is archived and searchable forever
 * <img src="/assets/icons8/icons8-quadcopter-100.png" style="width: 16px;margin: 0 6px 0 0;display: inline-block;"> Feeds that support paging are back-filled in for a complete archive
 * <img src="/assets/icons8/icons8-rss-100.png" style="width: 16px;margin: 0 6px 0 0;display: inline-block;"> Export trained stories from folders as RSS feeds
 * <img src="/assets/icons8/icons8-calendar-100.png" style="width: 16px;margin: 0 6px 0 0;display: inline-block;"> Stories can stay unread forever

A note about the backfilling of your archive. NewsBlur uses two techniques to retrieve older stories that are no longer in the RSS feed. The first strategy is to append `?page=2` and `?paged=2` to the RSS feed and seeing if we're about to blindly iterate through the blog's archive. For WordPress and a few other CMSs, this works great and gives us a full archive. A second technique is to use RFC 5005, which supports links embedded inside the RSS feed to denote next and previous pages of an archive. 

NewsBlur attempts all of these techniques on every single feed you've subscribed to, and when it's done backfilling stories, you'll receive an email showing you how big your archive grew during this backfill process.

The launch of this new subscription tier also includes the 2022 redesign. You'll see a third dashboard layout which stretches out your dashboard rivers across the width of the screen. You may recognize this view from the iPad's 3 column layout.

<img src="/assets/premium-archive-dashboard-comfortable.png" style="width: calc(140%);margin: 12px 0 12px calc(-20%);max-width: none;border: none">

The latest redesign style has more accomodations for spacing and padding around each story title element. The result is a cleaner story title with easier to read headlines. The author has been moved and restyled to be next to the story date. Favicons and unread status indicators have been swapped, and font sizes, colors, and weights have been adjusted.

<img src="/assets/premium-archive-dashboard-compact.png" style="width: calc(140%);margin: 12px 0 12px calc(-20%);max-width: none;border: none">

The compact interface is denser than before, giving power users a highly detailed view. Transitions have also been added to help you feel the difference.

If you find the interface to be too airy, there is a setting in the main Manage menu allowing you to switch between Comfortable and Compact. 

And lastly, this redesign comes with a suite of all new icons. The goal with this icon redesign is to bring a consistent weight to each icon as well as vectorize them with SVG so they look good at all resolutions.

<img src="/assets/premium-archive-manage-menu.png" style="width: 275px;border: 1px solid #A0A0A0;margin: 24px auto;display: block;">

A notable icon change is the unread indicator, which now has different size icons for both unread stories and focus stories, giving focus stories more depth.

<img src="/assets/premium-archive-unread-dark.png" style="width: 375px;border: 1px solid #A0A0A0;margin: 24px auto;display: block;">

Here's a screenshot that's only possible with the new premium archive, complete with backfilled blog post from the year 2000, ready to be marked as unread.

<img src="/assets/premium-archive-unread.png" style="width: 100%;border: 1px solid #A0A0A0;margin: 24px auto;display: block;">

I tried to find every icon, so if you spot a dialog or menu that you'd like to see given some more love, reach out on the support forum.
