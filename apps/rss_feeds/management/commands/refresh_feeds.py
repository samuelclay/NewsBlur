from django.core.management.base import BaseCommand
from django.core.handlers.wsgi import WSGIHandler
from apps.rss_feeds.models import Feed, Story
from optparse import OptionParser, make_option
from utils import feed_fetcher
from utils.management_functions import daemonize
import logging
import socket
import os
import math


class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        make_option("-f", "--feed", default=None),
        make_option("-d", "--daemon", dest="daemonize", action="store_true"),
        make_option("-s", "--single_threaded", dest="single_threaded", action="store_true"),
        make_option('-t', '--timeout', type='int', default=10,
            help='Wait timeout in seconds when connecting to feeds.'),
        make_option('-V', '--verbose', action='store_true',
            dest='verbose', default=False, help='Verbose output.'),
        make_option('-w', '--workerthreads', type='int', default=4,
            help='Worker threads that will fetch feeds in parallel.'),
    )

    def handle(self, *args, **options):
        if options['daemonize']:
            daemonize()
        
        feeds = Feed.objects.all().order_by('?')
        num_workers = min(len(feeds), options['workerthreads'])
        
        if options['single_threaded']:
            num_workers = 1
            
        # settting socket timeout (default= 10 seconds)
        socket.setdefaulttimeout(options['timeout'])
        
        disp = feed_fetcher.Dispatcher(options, num_workers)        
        
        
        
        feeds_queue = []
        for _ in range(num_workers):
            feeds_queue.append([])
        i = 0
        for feed in feeds:
            feeds_queue[i%num_workers].append(feed)
            i += 1
        disp.add_jobs(feeds_queue)
        
        print "Running jobs..."
        disp.run_jobs()
        
        print "Polling..."
        disp.poll()
        
        os._exit(1)
        sys.exit()
        
