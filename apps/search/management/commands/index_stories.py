import re
from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from apps.rss_feeds.models import Feed, MStory
from apps.reader.models import UserSubscription

class Command(BaseCommand):

    def add_arguments(self, parser):
        parser.add_argument("-u", "--user", dest="user", type=str, help="Specify user id or username")
        parser.add_argument("-R", "--reindex", dest="reindex", action="store_true", help="Drop index and reindex all stories.")


    def handle(self, *args, **options):
        if options['reindex']:
            MStory.index_all_for_search()
            return
        
        if not options['user']:
            print("Missing user. Did you want to reindex everything? Use -R.")
            return
        
        if re.match(r"([0-9]+)", options['user']):
            user = User.objects.get(pk=int(options['user']))
        else:
            user = User.objects.get(username=options['user'])
        
        subscriptions = UserSubscription.objects.filter(user=user)
        print(" ---> Indexing %s feeds..." % subscriptions.count())
        
        for sub in subscriptions:
            try:
                sub.feed.index_stories_for_search()
            except Feed.DoesNotExist:
                print(" ***> Couldn't find %s" % sub.feed_id)
        