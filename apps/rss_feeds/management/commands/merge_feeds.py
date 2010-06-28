from django.core.management.base import BaseCommand
from apps.rss_feeds.models import Feed
from optparse import make_option

class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        make_option("-f", "--feed", dest="feed", default=None),
        make_option("-V", "--verbose", dest="verbose", action="store_true"),
    )

    def handle(self, *args, **options):
        feeds = Feed.objects.all()
            
        feeds_count = feeds.count()
        
        for i in xrange(0, feeds_count, 100):
            feeds = Feed.objects.all()[i:i+100]
            for feed in feeds.iterator():
                pass
        
