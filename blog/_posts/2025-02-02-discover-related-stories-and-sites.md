---
layout: post
title: Discover related stories and sites
tags: ["web"]
---

I want to introduce you to the new Discover Stories and Discover Sites features. Sometimes you’re reading a story and want to know everything there is to know about that topic. You want other stories, but depending on the topic, you might want them from the same site, from similar sites, or from all of your subscriptions. That’s the new Discover Stories feature, and it’s only for NewsBlur Premium Archive subscribers. The Premium Archive subscription is meant for this use case of being able to peer deeply into your story archive and not just what’s been published in the last month.

Second I'm introducing Discover Sites, which is available at the top of every feed and folder to everybody, both free and premium users. Having tried all of the competing discover sites features, I built the popover dialog that has all the features I wanted. It’s an infinite scroll of related sites, showing the most recent five stories, formatted exactly as your story titles are personally styled. You can read stories from unsubscribed feeds and easily subscribe to them while scrolling through the discover stories dialog.

<img src="/assets/discover-1.png"  style="width: 100%;border: none;margin: 24px auto;display: block;">

Here’s a set of features I’ve been wanting to build since the very first days of NewsBlur in 2009. I built prototypes of this feature using a few of the modern text tools at the time: nltk (the natural language toolkit), support vector machines, and LDA (Latent Dirichlet Allocation) to group stories by topic. It didn’t work, or it was too slow, and even then not accurate enough. I read the tea leaves and could tell a better tool would come out eventually that was basically a drop-in classifier and topic grouper. Out came word embeddings (word2vec initially, then <a href="https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2">sentence transformers</a>). And now those transformers are available basically for free.

<img src="/assets/discover-3.png"  style="width: 100%;border: none;margin: 24px auto;display: block;">

As you can see, this isn’t your normal related stories feature. It shows all of the related stories, segmented by the folders that a site is a part of. This folder control allows you to filter down to an individual site and up to every feed you subscribe to when finding related stories.

And it's important to note that none of the data presented in the Discover Stories or Discover Sites dialog is trained on your personal data, like feeds that other people subscribe to in relation to any particular site. All of the data is extracted and grouped by the content of the RSS feed's title, description, and the titles of the first few stories. 

<img src="/assets/discover-2.png"  style="width: 100%;border: none;margin: 24px auto;display: block;">

Above we see that Discover Sites is right on the money. An infinite scroll of related sites, showing story previews, and multiple interaction points that let you choose between trying out a site by reading one of the stories, adding it directly to a folder, or checking the statistics of the site. The stats dialog is great in this case because it gives you a feel for what other people like and dislike about the site.

I’m super proud of this release; it took years to build and a decade to plan. And while the Discover Stories feature is technically only available to Premium Archive subscribers, you can see related stories if another Premium Archive subscriber is subscribed to that site. I don’t think hiding those stories from free and premium users is worthwhile.

Please post your feedback on the <a href="https://forum.newsblur.com">NewsBlur forum</a>, ideally as an “idea,” but you know I love responding to all feedback. For every person who writes up their thoughts on the forum, there are ten people who are thinking the same thing, so it’s worthwhile to hear from you, knowing the multiplier it represents.
