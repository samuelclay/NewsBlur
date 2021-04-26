from django.core.management.base import BaseCommand
from apps.rss_feeds.models import Feed

class Command(BaseCommand):

    def add_arguments(self, parser):
        parser.add_argument("-f", "--feed", dest="feed", default=None)
        parser.add_argument("-t", "--title", dest="title", default=None)
        parser.add_argument("-V", "--verbose", dest="verbose", action="store_true")
    
    def handle(self, *args, **options):
        if options['title']:
            feeds = Feed.objects.filter(feed_title__icontains=options['title'])
        elif options['feed']:
            feeds = Feed.objects.filter(pk=options['feed'])
        else:
            feeds = Feed.objects.all()

        # Count stories in past month to calculate next scheduled update
        for feed in feeds:
            feed.count_stories(verbose=options['verbose'])
        
        print(("\nCounted %s feeds" % feeds.count()))