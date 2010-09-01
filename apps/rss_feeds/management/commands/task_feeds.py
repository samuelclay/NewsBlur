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
        
        feeds = Feed.objects.filter(next_scheduled_update__lte=now).order_by('?')
        
        if options['force']:
            feeds = Feed.objects.all()

        print " ---> Tasking %s feeds..." % feeds.count()

        for f in feeds:
            RefreshFeed.apply_async(args=(f.pk,))
            