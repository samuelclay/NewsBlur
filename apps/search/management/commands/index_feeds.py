from django.core.management.base import BaseCommand
from apps.rss_feeds.models import Feed
from optparse import make_option

class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        make_option("-o", "--offset", dest="offset", type="int", default=0, help="Specify offset to start at"),
        make_option("-s", "--subscribers", dest="subscribers", type="int", default=2, help="Specify minimum number of subscribers"),
    )

    def handle(self, *args, **options):
        offset = options['offset']
        subscribers = options.get('subscribers', None)
        Feed.index_all_for_search(offset=offset, subscribers=subscribers)
        