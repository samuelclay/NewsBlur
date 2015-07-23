from django.core.management.base import BaseCommand
from django.conf import settings
from optparse import make_option
from apps.rss_feeds.tasks import TaskFeeds, TaskBrokenFeeds
import datetime


class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        make_option("-f", "--feed", default=None),
        make_option("-a", "--all", default=False, action='store_true'),
        make_option("-b", "--broken", help="Task broken feeds that havent been fetched in a day.", default=False, action='store_true'),
        make_option('-V', '--verbose', action='store_true',
            dest='verbose', default=False, help='Verbose output.'),
    )

    def handle(self, *args, **options):
        if options['broken']:
            TaskBrokenFeeds.apply()
        else:
            TaskFeeds.apply()