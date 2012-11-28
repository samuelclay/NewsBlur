from django.core.management.base import BaseCommand
from apps.rss_feeds.models import Feed
from optparse import make_option
from utils.management_functions import daemonize

class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        make_option("-f", "--feed", dest="feed", default=None),
        make_option("-F", "--force", dest="force", action="store_true"),
        make_option("-t", "--title", dest="title", default=None),
        make_option("-d", "--daemon", dest="daemonize", action="store_true"),
    )

    def handle(self, *args, **options):
        if options['daemonize']:
            daemonize()
        
        if options['title']:
            feed = Feed.objects.get(feed_title__icontains=options['title'])
        else:
            feed = Feed.get_by_id(options['feed'])
        feed.update(force=options['force'], single_threaded=True, verbose=2)