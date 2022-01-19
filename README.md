# NewsBlur

 * NewsBlur is a personal news reader bringing people together 
   to talk about the world. A new sound of an old instrument.
 * [www.newsblur.com](http://www.newsblur.com).
 * Created by [Samuel Clay](http://www.samuelclay.com). 
 * Twitter: [@samuelclay](http://twitter.com/samuelclay) and 
   [@newsblur](http://twitter.com/newsblur).

<a href="https://f-droid.org/repository/browse/?fdid=com.newsblur" target="_blank">
<img src="https://f-droid.org/badge/get-it-on.png" alt="Get it on F-Droid" height="80"/></a>
<a href="https://play.google.com/store/apps/details?id=com.newsblur" target="_blank">
<img src="https://play.google.com/intl/en_us/badges/images/generic/en-play-badge.png" alt="Get it on Google Play" height="80"/></a>

## Features

 1. Shows the original site (you have to see it to believe it).
 2. Hides stories you don't want to read based on tags, keywords, authors, etc.
 3. Highlights stories you want to read, based on the same criteria.

## Technologies

### Server-side

 * [Python 3.7+](http://www.python.org): The language of choice.
 * [Django](http://www.djangoproject.com): Web framework written in Python, used 
   to serve all pages.
 * [Celery](http://ask.github.com/celery) & [RabbitMQ](http://www.rabbitmq.com): 
   Asynchronous queueing server, used to fetch and parse RSS feeds.
 * [MongoDB](http://www.mongodb.com), [Pymongo](https://pypi.python.org/pypi/pymongo), & 
   [Mongoengine](http://www.github.com/hmarr/mongoengine): Non-relational database, 
   used to store stories, read stories, feed/page fetch histories, and proxied sites.
 * [PostgreSQL](http://www.postgresql.com): Relational database, used to store feeds, 
   subscriptions, and user accounts.
 * [Redis](http://redis.io): Programmer's database, used to assemble stories for the river, store story ids, manage feed fetching schedules, and the minuscule bit of caching that NewsBlur uses.
 * [Elasticsearch](http://elasticsearch.org): Search database, use for searching stories. Optional.
 
### Client-side and design

 * [jQuery](http://www.jquery.com): Cross-browser compliant JavaScript code. IE works without effort.
 * [Underscore.js](http://underscorejs.org/): Functional programming for JavaScript. 
   Indispensable.
 * [Backbone.js](http://backbonejs.org/): Framework for the web app. Also indispensable.
 * Miscellaneous jQuery Plugins: Everything from resizable layouts, to progress 
   bars, sortables, date handling, colors, corners, JSON, animations. 
   [See the complete list](https://github.com/samuelclay/NewsBlur/tree/master/media/js).


### Prerequisites
    * Docker
    * Docker-compose

## Installation Instructions
 1. Clone this repo
 2. Run `make nb` to build all of the NewsBlur containers. This will set up all necessary databases, front-end django apps, celery tasks, node apps, flask database monitor and metrics, nginx, and a haproxy load balancer.
 7. Navigate to: 

         https://localhost

    Note: You will be warned that you are using a self signed certificate. In order to get around this warning you must type "thisisunsafe" as per [this blog post](https://dblazeski.medium.com/chrome-bypass-net-err-cert-invalid-for-development-daefae43eb12).

## Using a custom domain

 1. Run the custom domain script
 
    ```
    bash ./utils/custom_domain.sh <domain name>
    ```
   
    This script will do the following:

      * Change `NEWSBLUR_URL` and `SESSION_COOKIE_DOMAIN` in `newsblur_web/docker_local_settings.py`
      * Change the domain in `config/fixtures/bootstrap.json`
   
   You can also change domains: `bash ./utils/custom_domain.sh <old domain> <new domain>`
  
 2. If you're using a custom subdomain, you'll also want to add it to `ALLOWED_SUBDOMAINS` in `apps/reader/views.py`

 3. A way to make sure you updated all the correct places:

    * Go to the website address in your browser
    * Open developer tools and look at the network tab
    * Try to login
    * Look again at the developer tools, there should be a POST call to /login
    * Observe the Response headers for that call
    * The value of the "set-cookie" header should contain a "Domain=" string

    If the string after `Domain=` is not the domain you are using to access the website, then your configuration still needs your custom domain.
    
    You can also confirm that there is a domain name mismatch in the database by running `make shell` & typing `Site.objects.all()[0]` to show the domain that NewsBlur is expecting.
   
## Making docker-compose work with your existing database

To make docker-compose work with your database, upgrade your local database to the docker-compose version and then volumize the database data path by changing the `./docker/volumes/` part of the volume directive in the service to point to your local database's data directory.

To make docker-compose work with an older database version, change the image version for the database service in the docker-compose file.

## Contribution Instructions

* Making Changes:
    * To apply changes to the Python or JavaScript code, use the `make` command.
    * To apply changes to the docker-compose.yml file, use the `make rebuild` command.
    * To apply changes to the docker/haproxy/haproxy.conf file, node packages, or any new database migrations you will need to use the `make nb` command.

* Adding Python packages:
    Currently, the docker-compose.yml file uses the newsblur/newsblur_python3 image. It is built using the Dockerfile found in `docker/newsblur_base_image.Dockerfile`. Because of how the docker image is set up, you will need to create your own image and direct your docker-compose.yml file to use it. Please follow the following steps to do so.

    1. Add your new site-packages to config/requirements.txt.
    2. Add the following lines of code to your docker-compose.yml file to replace anywhere where it says `image: newsblur/newsblur_python3`

    <code>
        build:
          context: .
          dockerfile: docker/newsblur_base_image.Dockerfile
    </code>

    3. Run the `make nb` command to rebuild your docker-compose containers

* Debugging Python
    * To debug your code, drop `import pdb; pdb.set_trace()` into the Python code where you would like to start debugging
    and run `make` and then `make debug`.

* Using Django shell within Docker
    * Make sure your docker containers are up and run `make shell` to open
    the Django shell within the newsblur_web container.

### Running unit and integration tests

NewsBlur comes complete with a test suite that tests the functionality of the rss_feeds,
reader, and feed importer. To run the test suite:

    `make test`

### Running a performance test

Performance tests use the locust performance testing tool. To run performance tests via CLI, use
`make perf-cli users=1 rate=1 host=https://localhost`. Feel free to change the users, rate, and host
variables in the command to meet you needs.

You can also run locust performance tests using a UI by running `make perf-ui` and then navigating to 
http://127.0.0.1:8089. This allows you to chart and export your performance data.

To run locust using docker, just run `make perf-docker` and navigate to http://127.0.0.1:8089

## Author

 * Created by [Samuel Clay](http://www.samuelclay.com).
 * Email address: <samuel@newsblur.com>
 * [@samuelclay](http://twitter.com/samuelclay) on Twitter.

## License

NewsBlur is licensed under the MIT License. (See LICENSE)
