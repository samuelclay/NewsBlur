---
layout: post
title: Add your own Custom CSS and Custom JavaScript to NewsBlur on the web
date: '2017-05-22T05:00:41-04:00'
tags:
- web
tumblr_url: https://blog.newsblur.com/post/160944994686/add-your-own-custom-css-and-custom-javascript-to
redirect_from: /post/160944994686/add-your-own-custom-css-and-custom-javascript-to/
---
Ever wanted to customize NewsBlur on the web but didn’t want to install custom browser extensions so you could shoe-horn in monkey-patched code? And if you did use a browser extension, didn’t you just hate having to keep it synchronized between your computers? Just for you, NewsBlur now has two new fields: Custom CSS and Custom Javascript.

Head to _Manage \> Account \> Custom CSS/JS_. And here’s what you can do with this new feature.

**Install an unofficial dark theme for NewsBlur**

<figure class="tmblr-full" data-orig-height="960" data-orig-width="1098" data-orig-src="https://userstyles.org/style_screenshots/124890_after.png"><img style="width: 650px;" data-orig-height="960" data-orig-width="1098" src="https://userstyles.org/style_screenshots/124890_after.png"></figure>

Over on Stylish, a community for custom CSS, there are [a bunch of stylesheets that change how NewsBlur looks](https://userstyles.org/styles/browse?search_terms=newsblur). Have you ever wanted a dark theme? There’s a few and [the most popular is made by NewsBlur user Splike](https://userstyles.org/styles/124890/newsblur-dark-theme-by-splike). (Note: you will have to remove the @moz delcaraction along with the surrounding {}’s at the top and bottom lines.)

**Hide that module or link that you don’t want to see on NewsBlur**

<figure class="tmblr-full" data-orig-height="1033" data-orig-width="1300" data-orig-src="https://s3.amazonaws.com/static.newsblur.com/blog/custom-css.png"><img style="width: 650px;" data-orig-height="1033" data-orig-width="1300" src="https://s3.amazonaws.com/static.newsblur.com/blog/custom-css.png"></figure>

Don’t like seeing Global Shared Stories or the River of News on the Dashboard? You can hide them with this little bit of CSS:

    /* Hides the Global Shared Stories feed */
    .NB-feeds-header-river-global-container { 
        display: none !important; 
    }
    
    /* Hides the Dashboard River */
    .NB-module-river {
        display: none !important;
    }

**Run a custom script**

Ok, to be 100% truthful, I have no idea why you’d want to run custom JavaScript on NewsBlur. But if you figure out a reason please let me know! Either [shoot me an email](http://samuel@newsblur.com) or mention it to [@newsblur on Twitter](https://twitter.com/newsblur).

