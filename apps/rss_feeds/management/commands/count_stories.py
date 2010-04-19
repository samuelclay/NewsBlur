from django.core.management.base import BaseCommand
from django.core.handlers.wsgi import WSGIHandler
from apps.rss_feeds.models import Feed, Story
from django.core.cache import cache
from django.db.models import Q
from optparse import OptionParser, make_option
from utils.management_functions import daemonize
import os
import logging
import errno
import datetime

class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        make_option("-f", "--feed", dest="feed", default=None),
        make_option("-t", "--title", dest="title", default=None),
        make_option("-d", "--daemon", dest="daemonize", action="store_true"),
    )

    def handle(self, *args, **options):
        if options['daemonize']:
            daemonize()
        
        if options['title']:
            feeds = Feed.objects.filter(feed_title__icontains=options['title'])
        elif options['feed']:
            feeds = Feed.objects.filter(pk=options['feed'])
        else:
            feeds = Feed.objects.all()

        # Count stories in past month to calculate next scheduled update
        for feed in feeds:
            month_ago = datetime.datetime.now() - datetime.timedelta(days=30)
            stories_count = Story.objects.filter(story_feed=feed, story_date__gte=month_ago).count()
            stories_count = stories_count
            feed.stories_per_month = stories_count
            feed.save()
            print "  ---> %s [%s]: %s stories" % (feed.feed_title, feed.pk, feed.stories_per_month)
        
        print "\nCounted %s feeds" % feeds.count()