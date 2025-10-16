import logging
import re

from django.contrib.auth.models import User
from django.core.management.base import BaseCommand

from apps.reader.models import UserSubscription
from apps.rss_feeds.models import Feed, MStory


class Command(BaseCommand):
    def add_arguments(self, parser):
        parser.add_argument("-u", "--user", dest="user", type=str, help="Specify user id or username")
        parser.add_argument("-f", "--feed", dest="feed", type=str, help="Specify feed id or feed url")
        parser.add_argument(
            "-R", "--reindex", dest="reindex", action="store_true", help="Drop index and reindex all stories."
        )
        parser.add_argument(
            "-D", "--discover", dest="discover", action="store_true", help="Index discover stories."
        )
        parser.add_argument(
            "-S", "--search", dest="search", action="store_true", help="Index search stories."
        )

    def handle(self, *args, **options):
        print(
            f"Indexing stories for user {options['user']} / feed {options['feed']} with search={options['search']} and discover={options['discover']}"
        )
        if options["reindex"]:
            MStory.index_all_for_search(search=options["search"], discover=options["discover"])
            return

        if not options["user"] and not options["feed"]:
            print("Missing user or feed. Did you want to reindex everything? Use -R.")
            return

        if options["user"]:
            if re.match(r"([0-9]+)", options["user"]):
                user = User.objects.get(pk=int(options["user"]))
            else:
                user = User.objects.get(username=options["user"])

            subscriptions = UserSubscription.objects.filter(user=user)
            print(" ---> Indexing %s feeds..." % subscriptions.count())

            for sub in subscriptions:
                try:
                    sub.feed.index_stories_for_search()
                except Feed.DoesNotExist:
                    print(" ***> Couldn't find %s" % sub.feed_id)
        elif options["feed"]:
            feed = Feed.objects.get(pk=int(options["feed"]))
            feed.index_stories_for_search(force=True)
