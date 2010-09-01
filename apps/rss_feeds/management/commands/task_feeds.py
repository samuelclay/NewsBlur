from django.core.management.base import BaseCommand
from django.conf import settings
from apps.rss_feeds.models import Feed
from optparse import make_option
from apps.rss_feeds.tasks import RefreshFeed
import datetime


class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        make_option("-f", "--feed", default=None),
        make_option("-F", "--force", dest="force", action="store_true"),
        make_option('-V', '--verbose', action='store_true',
            dest='verbose', default=False, help='Verbose output.'),
    )

    def handle(self, *args, **options):
        settings.LOG_TO_STREAM = True
        now = datetime.datetime.now()
        
        feeds = Feed.objects.filter(next_scheduled_update__lte=now, active=True).order_by('?')
        
        if options['force']:
            feeds = Feed.objects.all().order_by('pk')

        print " ---> Tasking %s feeds..." % feeds.count()
        
        i = 0
        feed_queue = []
        for f in feeds:
            f.set_next_scheduled_update()
            i += 1
            feed_queue.append(f.pk)
            
            if i == 10:
                print feed_queue
                RefreshFeed.apply_async(args=(feed_queue,))
                feed_queue = []
                i = 0
        if feed_queue:
            RefreshFeed.apply_async(args=(feed_queue,))