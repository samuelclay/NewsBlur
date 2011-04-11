from django.core.management.base import BaseCommand
from django.conf import settings
from optparse import make_option
import datetime


class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        make_option("-f", "--feed", default=None),
        make_option('-V', '--verbose', action='store_true',
            dest='verbose', default=False, help='Verbose output.'),
    )

    def handle(self, *args, **options):
        from apps.rss_feeds.models import Feed
        settings.LOG_TO_STREAM = True
        now = datetime.datetime.utcnow()
        
        # Active feeds
        feeds = Feed.objects.filter(
            next_scheduled_update__lte=now,
            active=True
        ).exclude(
            active_subscribers=0
        ).order_by('?')
        Feed.task_feeds(feeds)
        
        # Mistakenly inactive feeds
        day = now - datetime.timedelta(days=1)
        feeds = Feed.objects.filter(
            last_update__lte=day, 
            queued_date__lte=day,
            min_to_decay__lte=60*24,
            active_subscribers__gte=1,
            active=True
        ).order_by('?')
        if feeds: Feed.task_feeds(feeds)
        
        week = now - datetime.timedelta(days=7)
        feeds = Feed.objects.filter(
            last_update__lte=week, 
            queued_date__lte=day,
            active_subscribers__gte=1,
            active=True
        ).order_by('?')
        if feeds: Feed.task_feeds(feeds)