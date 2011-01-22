from django.core.management.base import BaseCommand
from apps.rss_feeds.models import Feed
from optparse import make_option
import gc

class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        make_option("-f", "--feed", dest="feed", default=None),
    )

    def handle(self, *args, **options):
        if not options['feed']:
            feeds = Feed.objects.filter(
                fetched_once=True, 
                active_subscribers=0,
                premium_subscribers=0
            )
        else:
            feeds = Feed.objects.filter(feed_id=options['feed'])

        for f in queryset_iterator(feeds):
            f.trim_feed(verbose=True)
        

def queryset_iterator(queryset, chunksize=100):
    '''
    Iterate over a Django Queryset ordered by the primary key

    This method loads a maximum of chunksize (default: 1000) rows in it's
    memory at the same time while django normally would load all rows in it's
    memory. Using the iterator() method only causes it to not preload all the
    classes.

    Note that the implementation of the iterator does not support ordered query sets.
    '''
    last_pk = queryset.order_by('-pk')[0].pk
    queryset = queryset.order_by('pk')
    pk = queryset[0].pk
    while pk < last_pk:
        for row in queryset.filter(pk__gte=pk, pk__lte=last_pk)[:chunksize]:
            yield row
        pk += chunksize
        gc.collect()