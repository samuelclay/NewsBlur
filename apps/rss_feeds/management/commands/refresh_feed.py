from django.core.management.base import BaseCommand
from django.core.handlers.wsgi import WSGIHandler
from apps.rss_feeds.models import Feed, Story
from django.core.cache import cache
from django.db.models import Q
from apps.reader.models import UserSubscription, UserStory
from optparse import OptionParser, make_option
from utils.management_functions import daemonize
import os
import logging
import errno

class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        make_option("-f", "--feed", dest="feed", default=None),
        make_option("-F", "--force", dest="force", action="store_true"),
        make_option("-t", "--title", dest="title", default=None),
        make_option("-d", "--daemon", dest="daemonize", action="store_true"),
    )

    def handle(self, *args, **options):
        if options['daemonize']:
            daemonize()
        
        if options['title']:
            feed = Feed.objects.get(feed_title__contains=options['title'])
        else:
            feed = Feed.objects.get(pk=options['feed'])
        self._refresh_feeds([feed], force=options['force'])
        
    def _refresh_feeds(self, feeds, force=False):
        for feed in feeds:
            feed.update(force=force, single_threaded=True)
            usersubs = UserSubscription.objects.filter(
                feed=feed.id
            )