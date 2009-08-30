from django.core.management.base import BaseCommand
from django.core.handlers.wsgi import WSGIHandler
from apps.rss_feeds.models import Feed, Story
from optparse import OptionParser, make_option
from utils import feed_fetcher
from utils.management_functions import daemonize
import logging
import socket


class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        make_option("-f", "--feed", default=None),
        make_option("-d", "--daemon", dest="daemonize", action="store_true"),
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
        
        # settting socket timeout (default= 10 seconds)
        socket.setdefaulttimeout(options['timeout'])
        
        disp = feed_fetcher.Dispatcher(options, options['workerthreads'])        
        
        feeds = Feed.objects.all()
        for feed in feeds:
            disp.add_job(feed)
        
        disp.poll()
        
        