---
layout: post
title: "Add + Discover Sites: YouTube, Reddit, podcasts, newsletters, and thousands of feeds to explore"
tags: ["web"]
---

NewsBlur has always been great at reading feeds. But finding new ones? That was mostly on you. The old "Add Site" dialog was a search box and not much else. If you already had a feed URL, it worked fine. If you were looking for something new to read, you were on your own.

The new **Add + Discover Sites** page changes that. It's a full-page discovery experience with eight tabs covering YouTube channels, Reddit communities, podcasts, newsletters, Google News topics, trending sites, popular feeds, and of course the classic search-and-subscribe workflow. There are over 50,000 curated feeds to browse, all organized into dozens of categories and subcategories.

<img src="/assets/add-site-full-page.png" style="width: 100%;border: 1px solid rgba(0,0,0,0.1);margin: 24px auto;display: block;">

### Eight ways to find feeds

The tab bar across the top gives you eight different lenses into the world of RSS:

<!-- SCREENSHOT: Tab bar showing all eight tabs with icons -->
<img src="/assets/add-site-tabs.png" style="width: 90%;border: 1px solid rgba(0,0,0,0.1);margin: 24px auto;display: block;">

- **Search** — The classic search bar, now with semantic search and autocomplete. Type a topic or URL and get instant suggestions. Below the search results you'll find trending feeds ranked by a hybrid algorithm that combines subscription velocity, read engagement, and subscriber counts.

- **Web Feed** — Create RSS feeds from any website. This one gets its own blog post.

- **Popular Sites** — Thousands of curated RSS feeds organized into categories like Technology, Science, News, and Business. Each category has subcategories for drilling down further.

- **YouTube** — Over 2,000 verified YouTube channels converted to RSS feeds. Browse by category or search for specific channels. Subscribe and read YouTube in your feed reader the way it should be.

- **Reddit** — Nearly 6,000 real subreddits across 47 categories. From r/programming to r/sourdough, you can subscribe to any subreddit as an RSS feed.

- **Newsletters** — Newsletters from Substack, Medium, Ghost, Beehiiv, and other platforms. Platform pills let you filter by newsletter provider if you have a preference.

- **Podcasts** — Popular podcasts organized by genre. Search for shows or browse the curated collection.

- **Google News** — Eight preset topics (World, Business, Technology, Sports, and more) that create feeds from Google News. One click to subscribe.


### Categories and subcategories

Most tabs are organized with a two-level taxonomy. Click a category pill at the top to filter, then drill into subcategories for more specific browsing. YouTube's Technology category, for example, breaks down into Programming, AI & Machine Learning, Gadgets, and more.

<!-- SCREENSHOT: Category pills and subcategory rows showing two-level taxonomy -->
<img src="/assets/add-site-categories.png" style="width: 90%;border: 1px solid rgba(0,0,0,0.1);margin: 24px auto;display: block;">

The categories are consistent across tabs where it makes sense, so you can explore Technology feeds across YouTube, Reddit, Popular Sites, and Podcasts without having to rethink the navigation each time.

### Grid view and list view

Every tab supports two viewing modes. Grid view shows feed cards with thumbnails, descriptions, subscriber counts, and freshness indicators. List view compresses things into a denser layout when you want to scan quickly.

<!-- SCREENSHOT: Side by side of grid view and list view showing the same feeds -->
<img src="/assets/add-site-grid-list.png" style="width: 100%;border: 1px solid rgba(0,0,0,0.1);margin: 24px auto;display: block;">

A style popover in the top right lets you toggle between views. Your preference is saved per tab.

### Try before you subscribe

Every feed card has a **Try** button that instantly fetches the feed and shows you the actual stories. No commitment, no subscribing. Just a quick look at what you'd get. If you like what you see, the subscribe button is right there with a folder picker.

<!-- SCREENSHOT: Try feed preview showing story cards from a YouTube channel or popular site -->
<img src="/assets/add-site-try-feed.png" style="width: 90%;border: 1px solid rgba(0,0,0,0.1);margin: 24px auto;display: block;">

A breadcrumb link at the top takes you back to where you were browsing when you're done previewing.

### The new Add Site popover

If you don't need the full discovery page, the popover that appears when you click "+" in the sidebar has been redesigned too. It still has the quick URL input for when you have a feed address handy, but now it also shows freshness indicators and has buttons to jump into any of the discovery tabs.

<!-- SCREENSHOT: Redesigned Add Site popover showing quick add input and discovery buttons -->
<img src="/assets/add-site-popover.png" style="width: 60%;border: 1px solid rgba(0,0,0,0.1);margin: 24px auto;display: block;">

### Semantic search

The search tab uses Elasticsearch to find feeds by name with fuzzy matching. Type "cooking" and you'll get cooking blogs, YouTube cooking channels, cooking subreddits, and cooking podcasts. It searches across all feed types, not just traditional RSS. If Elasticsearch doesn't find anything, the search falls back to a database query so you'll always get results.

### Where all these feeds came from

Building the discovery page meant curating a lot of feeds. I wrote management commands to discover and verify channels, subreddits, podcasts, and newsletters from real sources. The collection includes over 2,000 YouTube channels, 6,600 subreddits, 7,300 newsletters, 32,000 podcasts, and 14,000 RSS feeds. Over 63,000 feeds in total, all real, verified, and categorized.

The Add + Discover Sites page is available now on the web for all users. If you have feedback or ideas for new categories, platforms, or features, please share them on the <a href="https://forum.newsblur.com">NewsBlur forum</a>.
