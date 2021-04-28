from django.core.management.base import BaseCommand
from apps.rss_feeds.models import Feed
from utils.management_functions import daemonize

class Command(BaseCommand):

    def add_arguments(self, parser):
        parser.add_argument("-f", "--feed", dest="feed", default=None)
        parser.add_argument("-F", "--force", dest="force", action="store_true")
        parser.add_argument("-t", "--title", dest="title", default=None)
        parser.add_argument("-d", "--daemon", dest="daemonize", action="store_true")

    def handle(self, *args, **options):
        if options['daemonize']:
            daemonize()
        
        if options['title']:
            feed = Feed.objects.get(feed_title__icontains=options['title'])
        else:
            feed = Feed.get_by_id(options['feed'])
        feed.update(force=options['force'], single_threaded=True, verbose=True)
