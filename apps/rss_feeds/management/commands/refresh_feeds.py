from django.core.management.base import BaseCommand
from django.conf import settings
from django.contrib.auth.models import User
from apps.statistics.models import MStatistics
from apps.rss_feeds.models import Feed
from optparse import make_option
from utils import feed_fetcher
from utils.management_functions import daemonize
import django
import socket
import datetime


class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        make_option("-f", "--feed", default=None),
        make_option("-d", "--daemon", dest="daemonize", action="store_true"),
        make_option("-F", "--force", dest="force", action="store_true"),
        make_option("-s", "--single_threaded", dest="single_threaded", action="store_true"),
        make_option('-t', '--timeout', type='int', default=10,
            help='Wait timeout in seconds when connecting to feeds.'),
        make_option('-u', '--username', type='str', dest='username'),
        make_option('-V', '--verbose', action='store_true',
            dest='verbose', default=False, help='Verbose output.'),
        make_option('-S', '--skip', type='int',
            dest='skip', default=0, help='Skip stories per month < #.'),
        make_option('-w', '--workerthreads', type='int', default=4,
            help='Worker threads that will fetch feeds in parallel.'),
    )

    def handle(self, *args, **options):
        if options['daemonize']:
            daemonize()
        
        settings.LOG_TO_STREAM = True
        now = datetime.datetime.utcnow()
        
        if options['skip']:
            feeds = Feed.objects.filter(next_scheduled_update__lte=now,
                                        average_stories_per_month__lt=options['skip'],
                                        active=True)
            print " ---> Skipping %s feeds" % feeds.count()
            for feed in feeds:
                feed.set_next_scheduled_update()
                print '.',
            return
            
        socket.setdefaulttimeout(options['timeout'])
        if options['force']:
            feeds = Feed.objects.all()
        elif options['username']:
            feeds = Feed.objects.filter(subscribers__user=User.objects.get(username=options['username']))
        elif options['feed']:
            feeds = Feed.objects.filter(pk=options['feed'])
        else:
            feeds = Feed.objects.filter(next_scheduled_update__lte=now, active=True)
        
        feeds = feeds.order_by('?')
        
        for f in feeds:
            f.set_next_scheduled_update()
        
        num_workers = min(len(feeds), options['workerthreads'])
        if options['single_threaded']:
            num_workers = 1
        
        options['compute_scores'] = True
        options['quick'] = float(MStatistics.get('quick_fetch', 0))
        options['updates_off'] = MStatistics.get('updates_off', False)
        
        disp = feed_fetcher.Dispatcher(options, num_workers)        
        
        feeds_queue = []
        for _ in range(num_workers):
            feeds_queue.append([])
        
        i = 0
        for feed in feeds:
            feeds_queue[i%num_workers].append(feed.pk)
            i += 1
        disp.add_jobs(feeds_queue, i)
        
        django.db.connection.close()
        
        print " ---> Fetching %s feeds..." % feeds.count()
        disp.run_jobs()
