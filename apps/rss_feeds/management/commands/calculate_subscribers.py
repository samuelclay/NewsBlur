from django.core.management.base import BaseCommand
from apps.rss_feeds.models import Feed
from optparse import make_option

class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        make_option("-f", "--feed", dest="feed", default=None),
        make_option("-V", "--verbose", dest="verbose", action="store_true"),
    )

    def handle(self, *args, **options):
        if options['feed']:
            feeds = Feed.objects.filter(id=options['feed'])
        else:
            feeds = Feed.objects.all()

        for f in feeds.iterator():
            f.calculate_subscribers(verbose=options['verbose'])
        
