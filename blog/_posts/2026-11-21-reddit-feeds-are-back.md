---
layout: post
title: "Reddit feeds are back on NewsBlur"
date: 2026-11-21 11:18:05 -0800
tags: ["web"]
---

In the middle of October, Reddit started refusing NewsBlur's requests for subreddit feeds, and by early November every Reddit feed in NewsBlur had stopped updating. It [came up on the forum](https://forum.newsblur.com/t/13890) right away. Reddit is also retiring its RSS feeds.

Since November 10, NewsBlur gets Reddit posts from [RedListen](https://redlisten.com), a service that serves Reddit's own listings. Subreddit, user, multireddit, comment, and search feeds all update again, and you don't need to change anything.

### What's different

RedListen has a monthly limit on how many posts it returns, so NewsBlur reads Reddit a little differently than it used to:

- **Subreddits are checked about once an hour,** many at a time. Quiet subreddits get every post. The busiest ones get a share of their posts, and that share grows with the number of NewsBlur readers following them.
- **Hot and Top feeds read the same as New.**
- **Reddit's front page, r/all, and r/popular aren't available,** and those feeds will say so.
- **Comment thread and search feeds update at most twice a day,** and less often while they're quiet. Comment threads older than 30 days can't be fetched anymore.
- **Refreshing a Reddit feed yourself still fetches it right away,** and so does adding a new one.
- **Posts keep their formatting.** Reddit sends post text as plain text with formatting marks, and NewsBlur turns it into paragraphs, links, emphasis, code, quotes, and lists. Images come through too.
- **Personal Reddit RSS feeds,** the ones with `?feed=` in the address, still come straight from Reddit for as long as Reddit serves them.

### Availability

It's been live since November 10. It all happens on NewsBlur's servers, so it works on the web and in every app without an update. If a subreddit isn't coming through the way you'd expect, let me know on the <a href="https://forum.newsblur.com">NewsBlur forum</a>.
