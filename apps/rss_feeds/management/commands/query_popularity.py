from django.core.management.base import BaseCommand
from apps.reader.models import UserSubscription
from django.conf import settings
from django.contrib.auth.models import User
from apps.rss_feeds.models import Feed
import os
import errno
import re
import datetime

class Command(BaseCommand):

    def add_argument(self, parser):
        parser.add_argument("-q", "--query", dest="query", help="Search query")
        parser.add_argument("-l", "--limit", dest="limit", type="int", default=1000, help="Limit of stories")

    def handle(self, *args, **options):
        # settings.LOG_TO_STREAM = True

        # Feed.query_popularity(options['query'], limit=options['limit'])
        Feed.xls_query_popularity(options['query'], limit=options['limit'])