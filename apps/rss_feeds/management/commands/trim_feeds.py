from django.core.management.base import BaseCommand
from django.core.handlers.wsgi import WSGIHandler
from apps.rss_feeds.models import Feed, Story
from django.core.cache import cache
from apps.rss_feeds.models import Feed
from optparse import OptionParser, make_option
import os
import errno

class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        make_option("-f", "--feed", dest="feed", default=None),
    )

    def handle(self, *args, **options):
        if not options['feed']:
            feeds = Feed.objects.filter(fetched_once=True, average_stories_per_month__gte=30)
        else:
            feeds = Feed.objects.filter(feed_id=options['feed'])
            
        for f in feeds:
            f.trim_feed()
        