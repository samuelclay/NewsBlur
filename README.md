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


## Installation Instructions

### Preface

Both Mac OS X and Linux require [Fabric](http://docs.fabfile.org/) to be installed. 
Many common tasks, such as installing dependencies, deploying servers, migrations,
and configurations are in `fabfile.py`.

    sudo easy_install fabric
    
On recent installations of Mac OS X using XCode 4, you may run into issues around the 
`ppc` architecture. To fix this, simply run:

    sudo ln -s /Developer/Platforms/iPhoneOS.platform/Developer/usr/libexec/gcc/darwin/ppc /Developer/usr/libexec/gcc/darwin
    sudo ln -s /Developer/Platforms/iPhoneOS.platform/Developer/usr/libexec/gcc/darwin/ppc /usr/libexec/gcc/darwin

Sym-linking the ppc architecture comes from this StackOverflow answer on 
"[assembler for architecture ppc not installed on Mac OS](http://stackoverflow.com/questions/5256397/python-easy-install-fails-with-assembler-for-architecture-ppc-not-installed-on)".

### Mac OS X

Using Mac OS X as a development environment, you can run all three servers (app, db, task) 
on the same system. You should have [Fabric](http://docs.fabfile.org/) installed to run 
the `fabfile.py`.

    fab setup_python
    
### Linux / Ubuntu

If you are on Ubuntu, you can simple use [Fabric](http://docs.fabfile.org/) to install 
NewsBlur and its many components. NewsBlur is designed to run on three separate servers: 
an app server, a db server, and assorted task servers. To install everything on a single 
machine, read through `fabfile.py` and setup all three servers without repeating the 
`setup_common` steps.

#### App server
   fab setup_app
   
#### Database server
   fab setup_db
   
#### Task server
   fab setup_task


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