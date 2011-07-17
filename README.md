# NewsBlur

 * Live at [www.newsblur.com](http://www.newsblur.com).
 * A visual feed reader with intelligence.
 * Created by [Samuel Clay](http://www.samuelclay.com). 
 * Twitter: [@samuelclay](http://twitter.com/samuelclay) and 
   [@newsblur](http://twitter.com/newsblur).

## Features

 1. Shows the original site (you have to see it to believe it)
 2. Hides stories you don't want to read based on tags, keywords, authors, etc.
 3. Highlights stories you want to read, based on the same criteria.

## Technologies

### Server-side

 * Django: Web framework written in Python, used to serve all pages.
 * Celery & RabbitMQ: Asynchronous queueing server, used to fetch and parse 
   RSS feeds.
 * MongoDB, Pymongo, & Mongoengine: Non-relational database, used to store 
   stories, read stories, feed/page fetch histories, and proxied sites.
 * PostgreSQL: Relational database, used to store feeds, subscriptions, and 
   user accounts.

### Client-side and design

 * jQuery: Cross-browser compliant JavaScript code. IE works without effort.
 * Underscore.js: Functional programming for JavaScript. Indispensible.
 * Miscellaneous jQuery Plugins: Everything from resizable layouts, to progress 
   bars, sortables, date handling, colors, corners, JSON, animations. 
   [See the complete list](https://github.com/samuelclay/NewsBlur/tree/master/media/js).

Roadmap
-------

### Winter 2011 ###

 * River of News
 * Starred stories

### Summer 2011 ###
 
 * iPhone app
 * Implicit sorting in River of News
 
### Fall 2011 ###

 * Social features

Author
------

 * [Samuel Clay](http://www.samuelclay.com) <samuel@ofbrooklyn.com>
 * [@samuelclay](http://twitter.com/samuelclay) on Twitter
 
License
-------

NewsBlur is licensed under the MIT License. (See LICENSE)