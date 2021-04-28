from django.core.management.base import BaseCommand
from django.conf import settings
from apps.rss_feeds.tasks import TaskFeeds, TaskBrokenFeeds
import datetime


class Command(BaseCommand):

    def add_arguments(self, parser):
        parser.add_argument("-f", "--feed", default=None)
        parser.add_argument("-a", "--all", default=False, action='store_true')
        parser.add_argument("-b", "--broken", help="Task broken feeds that havent been fetched in a day.", default=False, action='store_true')
        parser.add_argument('-V', '--verbose', action='store_true',
            dest='verbose', default=False, help='Verbose output.')
 
    def handle(self, *args, **options):
        if options['broken']:
            TaskBrokenFeeds.apply()
        else:
            TaskFeeds.apply()
