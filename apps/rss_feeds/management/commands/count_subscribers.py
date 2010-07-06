from django.core.management.base import BaseCommand
from apps.rss_feeds.models import Feed
from optparse import make_option

class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        make_option("-f", "--feed", dest="feed", default=None),
        make_option("-t", "--title", dest="title", default=None),
        make_option("-V", "--verbose", dest="verbose", action="store_true"),
        make_option("-D", "--delete", dest="delete", action="store_true"),
    )

    def handle(self, *args, **options):
        if options['title']:
            feeds = Feed.objects.filter(feed_title__icontains=options['title'])
        elif options['feed']:
            feeds = Feed.objects.filter(pk=options['feed'])
        else:
            feeds = Feed.objects.all()
            
        feeds_count = feeds.count()
        
        for i in xrange(0, feeds_count, 100):
            feeds = Feed.objects.all()[i:i+100]
            for feed in feeds.iterator():
                feed.count_subscribers(verbose=options['verbose'])
        
        if options['delete']:
            print "# Deleting old feeds..."
            old_feeds = Feed.objects.filter(num_subscribers=0)
            for feed in old_feeds:
                feed.count_subscribers(verbose=True)
                if feed.num_subscribers == 0:
                    print ' ---> Deleting: [%s] %s' % (feed.pk, feed)
                    feed.delete()