from django.core.management.base import BaseCommand
from apps.reader.models import UserSubscription
from django.conf import settings
from optparse import make_option
from django.contrib.auth.models import User
from apps.rss_feeds.models import Feed
import os
import errno
import re
import datetime

class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        make_option("-q", "--query", dest="query", help="Search query"),
        make_option("-l", "--limit", dest="limit", type="int", default=1000, help="Limit of stories"),
    )

    def handle(self, *args, **options):
        # settings.LOG_TO_STREAM = True

        # Feed.query_popularity(options['query'], limit=options['limit'])
        Feed.xls_query_popularity(options['query'], limit=options['limit'])