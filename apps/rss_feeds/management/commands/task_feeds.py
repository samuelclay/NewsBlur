from django.core.management.base import BaseCommand
from django.conf import settings
from apps.rss_feeds.models import Feed
from optparse import make_option
from apps.rss_feeds.tasks import UpdateFeeds
from celery.task import Task
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
        now = datetime.datetime.utcnow()
        
        feeds = Feed.objects.filter(
            next_scheduled_update__lte=now, 
            active=True
        ).exclude(
            active_subscribers=0
        ).order_by('?')
        
        if options['force']:
            feeds = Feed.objects.all().order_by('pk')

        print " ---> Tasking %s feeds..." % feeds.count()
        
        publisher = Task.get_publisher()

        feed_queue = []
        size = 12
        for f in feeds:
            f.queued_date = datetime.datetime.utcnow()
            f.set_next_scheduled_update()

        for feed_queue in (feeds[pos:pos + size] for pos in xrange(0, len(feeds), size)):
            print feed_queue
            feed_ids = [feed.pk for feed in feed_queue]
            print feed_ids
            UpdateFeeds.apply_async(args=(feed_ids,), queue='update_feeds', publisher=publisher)

        publisher.connection.close()