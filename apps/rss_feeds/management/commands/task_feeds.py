from django.core.management.base import BaseCommand
from django.conf import settings
from optparse import make_option
from apps.rss_feeds.tasks import TaskFeeds
import datetime


class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        make_option("-f", "--feed", default=None),
        make_option("-a", "--all", default=False, action='store_true'),
        make_option('-V', '--verbose', action='store_true',
            dest='verbose', default=False, help='Verbose output.'),
    )

    def handle(self, *args, **options):
        TaskFeeds.apply()