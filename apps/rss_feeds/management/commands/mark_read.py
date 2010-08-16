from django.core.management.base import BaseCommand
from django.core.handlers.wsgi import WSGIHandler
from apps.rss_feeds.models import Feed, Story
from django.contrib.auth.models import User
from django.core.cache import cache
from apps.reader.models import UserSubscription, UserStory
from optparse import OptionParser, make_option
import os
import errno
import re
import datetime

class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        make_option("-d", "--days", dest="days", nargs=1, default=1, help="Days of unread"),
        make_option("-u", "--username", dest="username", nargs=1, help="Specify user id or username"),
        make_option("-U", "--userid", dest="userid", nargs=1, help="Specify user id or username"),
    )

    def handle(self, *args, **options):
        if options['userid']:
            user = User.objects.filter(pk=options['userid'])
        elif options['username']:
            user = User.objects.get(username__icontains=options['username'])
        else:
            raise Exception, "Need username or user id."
        
        feeds = UserSubscription.objects.filter(user=user)
        for sub in feeds:
            if options['days'] == 0:
                sub.mark_feed_read()
            else:
                sub.mark_read_date = datetime.datetime.now() - datetime.timedelta(days=int(options['days']))
                sub.save()