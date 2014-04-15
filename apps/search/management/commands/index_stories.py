import re
from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from apps.rss_feeds.models import Feed
from apps.reader.models import UserSubscription
from optparse import make_option

class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        make_option("-u", "--user", dest="user", nargs=1, help="Specify user id or username"),
    )

    def handle(self, *args, **options):
        if re.match(r"([0-9]+)", options['user']):
            user = User.objects.get(pk=int(options['user']))
        else:
            user = User.objects.get(username=options['user'])
        
        subscriptions = UserSubscription.objects.filter(user=user)
        print " ---> Indexing %s feeds..." % subscriptions.count()
        
        for sub in subscriptions:
            try:
                sub.feed.index_stories_for_search()
            except Feed.DoesNotExist:
                print " ***> Couldn't find %s" % sub.feed_id
        