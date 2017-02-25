# NewsBlur

 * NewsBlur is a personal news reader bringing people together 
   to talk about the world. A new sound of an old instrument.
 * [www.newsblur.com](http://www.newsblur.com).
 * Created by [Samuel Clay](http://www.samuelclay.com). 
 * Twitter: [@samuelclay](http://twitter.com/samuelclay) and 
   [@newsblur](http://twitter.com/newsblur).

## Features

 1. Shows the original site (you have to see it to believe it).
 2. Hides stories you don't want to read based on tags, keywords, authors, etc.
 3. Highlights stories you want to read, based on the same criteria.

## Technologies

### Server-side

 * [Python 2.7+](http://www.python.org): The language of choice.
 * [Django](http://www.djangoproject.com): Web framework written in Python, used 
   to serve all pages.
 * [Celery](http://ask.github.com/celery) & [RabbitMQ](http://www.rabbitmq.com): 
   Asynchronous queueing server, used to fetch and parse RSS feeds.
 * [MongoDB](http://www.mongodb.com), [Pymongo](https://pypi.python.org/pypi/pymongo), & 
   [Mongoengine](http://www.github.com/hmarr/mongoengine): Non-relational database, 
   used to store stories, read stories, feed/page fetch histories, and proxied sites.
 * [PostgreSQL](http://www.postgresql.com): Relational database, used to store feeds, 
   subscriptions, and user accounts.

### Client-side and design

 * [jQuery](http://www.jquery.com): Cross-browser compliant JavaScript code. IE works without effort.
 * [Underscore.js](http://underscorejs.org/): Functional programming for JavaScript. 
   Indispensible.
 * Miscellaneous jQuery Plugins: Everything from resizable layouts, to progress 
   bars, sortables, date handling, colors, corners, JSON, animations. 
   [See the complete list](https://github.com/samuelclay/NewsBlur/tree/master/media/js).


## Installation Instructions

### Prerequisites

#### What you can safely ignore

Not every program listed in the Prerequisites section is necessary to run NewsBlur. 

 * `Elasticsearch` is the only module that requires Java. If you can live without searching for feeds or searching for stories, then you can ignore it and NewsBlur will just spit out that you don't have a search server in the logs.
 * `Jammit` is for asset compression. Don't bother using it since the alternative is to just serve every js and css file in individual files without compression. Besides, nginx gzips those files automatically if you use the built-in nginx config. Just set `DEBUG_ASSETS = True` in your local_settings.py (which is also in local_settings.py.template).
 * `numpy` and `scipy` are used for the colors used all over the site. Every site's favicon is analyzed for its dominant color, and that color is what gives every site its feel. You'll see it by every story all over. I'd recommend installing it, as you can just use prebuilt packages and don't have to install from source, which is possible but not trivial.

#### Relational Database (MySQL, PostgreSQL)

You will want to have your database set up before you begin installation. Fabric can install
both PostgreSQL and MongoDB for you, but only on Ubuntu. Mac OS X users will want to have
MySQL or PostgreSQL already installed. You can [download MySQL](http://dev.mysql.com/downloads/mysql/)
or [download PostgreSQL](http://www.postgresql.org/download/). Additionally,
if running as a development machine on Mac OS X, I would recommend using MySQL with 
[Sequel Pro](http://www.sequelpro.com/) as a GUI.

If you are installing MySQL, you will also need the MySQLDB python library:

    sudo easy_install mysql-python
    
#### Fabric 

Both Mac OS X and Linux require [Fabric](http://docs.fabfile.org/) to be installed. 
Many common tasks, such as installing dependencies, deploying servers, migrations,
and configurations are in `fabfile.py`.

    sudo easy_install fabric
    
On recent installations of Mac OS X using XCode 4, you may run into issues around the 
`ppc` architecture. To fix this, simply run:

    sudo ln -s /Developer/Platforms/iPhoneOS.platform/Developer/usr/libexec/gcc/darwin/ppc \
    /Developer/usr/libexec/gcc/darwin
    sudo ln -s /Developer/Platforms/iPhoneOS.platform/Developer/usr/libexec/gcc/darwin/ppc \
    /usr/libexec/gcc/darwin

Sym-linking the ppc architecture comes from this StackOverflow answer on 
"[assembler for architecture ppc not installed on Mac OS](http://stackoverflow.com/questions/5256397/)".

#### MongoDB

On top of MySQL/PostgreSQL, NewsBlur uses MongoDB to store non-relational data. You will want to 
[download MongoDB](http://www.mongodb.org/downloads). If you are on Ubuntu, the `setup_mongo` Fabric 
command will automatically do this for you, but Mac OS X needs to have it installed manually.

#### Numpy and Scipy

Not the easiest to get installed. If you are running Mac OS X, you have a few options:

 * Use the [Superpack by Chris Fonnesbeck](http://fonnesbeck.github.com/ScipySuperpack/)
 * Use MacPorts: `sudo port install py26-numpy py26-scipy`
 * Install from source (grueling): [http://www.scipy.org/Download](http://www.scipy.org/Download)
 * Use a combination of pip, easy_install, and [homebrew](http://mxcl.github.com/homebrew/): `pip install numpy && brew install gfortran && easy_install scipy`

#### Jammit

You must have Java 7 installed to run Jammit.

 * Install Java 7 on OS X by following directions from http://www.cc.gatech.edu/~simpkins/teaching/gatech/cs2340/guides/java7-macosx.html
 * Also install the following gems:
   
     `sudo gem install closure-compiler jsmin cssmin uglifier`
   
#### Other assorted packages

From inside the repository, run: 

    pip install -r requirements.txt
 
### Configure paths

In `fabfile.py` there are two paths that need to be configured. 

 * `env.paths.NEWSBLUR` is the relative path to the NewsBlur repository.
 * `env.paths.VENDOR` is the relative path to where all downloaded code should go.
 
In `local_settings.py` there are a few paths that need to be configured. Configure 
these after the installation below.

### Installing on Mac OS X

 1. Using Mac OS X as a development environment, you can run all three servers (app, db, task) 
    on the same system. You should have [Fabric](http://docs.fabfile.org/) installed to run 
    the `fabfile.py`. You should also have MySQL/PostgreSQL and MongoDB already installed.

        fab -R local setup_python
        fab -R local setup_imaging
        fab -R local setup_mongoengine
        fab -R local setup_forked_mongoengine
        fab -R local setup_repo_local_settings
        fab -R local compress_assets
    
    If any of the packages fail to install (`lxml`, for instance), look through `fabfile.py` 
    and check if there is a function that can be used to circumvent broken easy_install 
    processes. For example, lxml may need libxslt and libxml2 to be installed. This is 
    automated with the following Fabric command:

        fab -R local setup_libxml_code
        
 2. Configure MySQL/PostgreSQL by adding in a `newsblur` user and a `newsblur` database. Here's an example for MySQL:
 	
        mysql_install_db --verbose --user=`whoami` --basedir="$(brew --prefix mysql)" --datadir=/path/to/var/mysql --tmpdir=/tmp
        mysql.server start
        mysql -u root
        > CREATE USER 'newsblur'@'localhost' IDENTIFIED BY '';
        > GRANT ALL PRIVILEGES ON *.* TO 'newsblur'@'localhost' WITH GRANT OPTION;
        > CREATE DATABASE newsblur;
        > exit
 
    Then load up the database with empty NewsBlur tables and bootstrap the database:
    
        ./manage.py syncdb --all
        ./manage.py migrate --fake
        ./manage.py migrate
        ./manage.py loaddata config/fixtures/bootstrap.json
        
    If you don't create a user during `syncdb`, the `bootstrap.json` file will create a 
    newsblur user with no password.

 3. Start mongodb (if not already running):
 
        mongod run
 
 4. Run the development server. At this point, all dependencies should be installed and no
    additional configuration is needed. If you find that something is not working at this
    point, please email the resulting output to Samuel Clay at 
    [samuel@newsblur.com](mailto:samuel@newsblur.com).
 
        ./manage.py runserver
 
 5. Navigate to: 

         http://localhost:8000/ 

    Create an account. At the end of the account creation process, you
    will be redirected to https://localhost/profile/stripe_form. Hit
    the back button a few times, and you will be inside the app.
    
### Installing on Linux / Ubuntu

If you are on Ubuntu, you can simply use [Fabric](http://docs.fabfile.org/) to install 
NewsBlur and its many components. NewsBlur is designed to run on three separate servers: 
an app server, a db server, and assorted task servers. To install everything on a single 
machine, read through `fabfile.py` and setup all three servers without repeating the 
`setup_common` steps.

### Finishing Installation

You must perform a few tasks to tie all of the various systems together.

 1. First, copy local_settings.py and fill in your OAuth keys, S3 keys, database names (if not `newsblur`),
task server/broker address (RabbitMQ), and paths:

        cp local_settings.py.template local_settings.py
    
    Edit local_settings.py to change any keys that you have.

 2. Create the `newsblur` database in MySQL/PostgreSQL

    #### MySQL/PostgreSQL
    
        ./manage.py syncdb


#### App server

    fab -R local setup_app
   
#### Database server

    fab -R local setup_db
   
#### Task server

    fab -R local setup_task


## Keeping NewsBlur Running

These commands keep NewsBlur fresh and updated. While on a development server, these 
commands do not need to be run more than once. However, you will probably want to run
the `refresh_feeds` command regularly so you have new stories to test with and read.

### Fetching feeds

If you just want to fetch feeds once, you can use the `refresh_feeds` management command:

    ./manage.py refresh_feeds --force
    
You can also fetch the feeds for a specific user:

    ./manage.py refresh_feeds --user=newsblur --force

### Feedback

To populate the feedback table on the homepage, use the `collect_feedback` management 
command every few minutes:

    ./manage.py collect_feedback

### Statistics

To populate the statistics graphs on the homepage, use the `collect_stats` management 
command every few minutes:

    ./manage.py collect_stats

### Bootstrapping Search

Once you have an elasticsearch server running, you'll want to bootstrap it with feed and story indexes.

    ./manage.py index_feeds
    
Stories will be indexed automatically.

If you need to move search servers and want to just delete everything in the search database, you need to reset the MUserSearch table.

    >>> from apps.search.models import MUserSearch
    >>> MUserSearch.remove_all()
    
### Running unit and integration tests

NewsBlur comes complete with a test suite that tests the functionality of the rss_feeds,
reader, and feed importer. To run the test suite:

    ./manage.py test --settings=utils.test-settings


## In Case of Downtime

You got the downtime message either through email or SMS. This is the order of operations for determining what's wrong.

 0a. If downtime goes over 5 minutes, go to Twitter and say you're handling it. Be transparent about what it is,
    NewsBlur's followers are largely technical. Also the 502 page points users to Twitter for status updates.
 
 0b. Ensure you have `secrets-newsblur/configs/hosts` installed in your `/etc/hosts` so server hostnames 
    work.

 1. Check www.newsblur.com to confirm it's down.
    
    If you don't get a 502 page, then NewsBlur isn't even reachable and you just need to contact [the
    hosting provider](http://cloud.digitalocean.com/support) and yell at them. 
    
 2. Check [Sentry](https://app.getsentry.com/newsblur/app/) and see if the answer is at the top of the 
    list.
 
    This will show if a database (redis, mongo, postgres) can't be found.

 3. Check which servers can't be reached on HAProxy stats page. Basic auth can be found in secrets/configs/haproxy.conf.
 
    Typically it'll be mongo, but any of the redis or postgres servers can be unreachable due to
    acts of god. Otherwise, a frequent cause is lack of disk space. There are monitors on every DB
    server watching for disk space, emailing me when they're running low, but it still happens.
 
 4. Check the various databases:

     a. If Redis server (db_redis, db_redis_story, db_redis_pubsub) can't connect, redis is probably down.
        
        SSH into the offending server (or just check both the `db_redis` and `db_redis_story` servers) and
        check if `redis` is running. You can often `tail -f -n 100 /var/log/redis.log` to find out if
        background saving was being SIG(TERM|INT)'ed. When redis goes down, it's always because it's
        consuming too much memory. That shouldn't happen, so check the [munin
        graphs](http://db_redis/munin/).
        
        Boot it with `sudo /etc/init.d/redis start`.
     
     b. If mongo (db_mongo) can't connect, mongo is probably down.
        
        This is rare and usually signifies hardware failure. SSH into `db_mongo` and check logs with `tail
        -f -n 100 /var/log/mongodb/mongodb.log`. Start mongo with `sudo /etc/init.d/mongodb start` then
        promote the next largest mongodb server. You want to then promote one of the secondaries to
        primary, kill the offending primary machine, and rebuild it (preferably at a higher size). I
        recommend waiting a day to rebuild it so that you get a different machine. Don't forget to lodge a
        support ticket with the hosting provider so they know to check the machine.
        
        If it's the db_mongo_analytics machine, there is no backup nor secondaries of the data (because
        it's ephemeral and used for, you guessed it, analytics). You can easily provision a new mongodb
        server and point to that machine.
        
        If mongo is out of space, which happens, the servers need to be re-synced every 2-3 months to 
        compress the data bloat. Simply `rm -fr /var/lib/mongodb/*` and re-start Mongo. It will re-sync.
        
        If both secondaries are down, then the primary Mongo will go down. You'll need a secondary mongo
        in the sync state at the very least before the primary will accept reads. It shouldn't take long to
        get into that state, but you'll need a mongodb machine setup. You can immediately reuse the 
        non-working secondary if disk space is the only issue.
        
     c. If postgresql (db_pgsql) can't connect, postgres is probably down.
        
        This is the rarest of the rare and has in fact never happened. Machine failure. If you can salvage
        the db data, move it to another machine. Worst case you have nightly backups in S3. The fabfile.py
        has commands to assist in restoring from backup (the backup file just needs to be local).
    
 4. Point to a new/different machine
    
    a. Confirm the IP address of the new machine with `fab list_do`.
    
    b. Change `secrets-newsbur/config/hosts` to reflect the new machine.
    
    c. Copy the new `hosts` file to all machines with:
    
       ```
       fab all setup_hosts
       ```
    
    d. Changes should be instant, but you can also bounce every machine with:
    
       ```
       fab web deploy:fast=True # fast=True just kill -9's processes.
       fab task celery
       ```
      
    e. Monitor `utils/tlnb.py` and `utils/tlnbt.py` for lots of reading and feed fetching.

  5. If feeds aren't fetching, check that the `tasked_feeds` queue is empty. You can drain it by running:
  
    ```
    Feed.drain_task_feeds()
    ```
    
    This happens when a deploy on the task servers hits faults and the task servers lose their 
    connection without giving the tasked feeds back to the queue. Feeds that fall through this 
    crack are automatically fixed after 24 hours, but if many feeds fall through due to a bad 
    deploy or electrical failure, you'll want to accelerate that check by just draining the 
    tasked feeds pool, adding those feeds back into the queue. This command is idempotent.
      
## Author

 * Created by [Samuel Clay](http://www.samuelclay.com).
 * Email address: <samuel@newsblur.com>
 * [@samuelclay](http://twitter.com/samuelclay) on Twitter.
 

## License

NewsBlur is licensed under the MIT License. (See LICENSE)
