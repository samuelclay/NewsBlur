#!/usr/bin/env python 
import datetime
from utils.munin.base import MuninGraph
from apps.rss_feeds.models import Feed
from apps.reader.models import UserSubscription
from django.db.models import Q

graph_config = {
    'graph_category' : 'NewsBlur',
    'graph_title' : 'NewsBlur Feeds',
    'graph_vlabel' : 'Feeds & Subscribers',
    'feeds.label': 'feeds',
    'subscriptions.label': 'subscriptions',
    'update_queue.label': 'update_queue',
    'exception_feeds.label': 'exception_feeds',
}

metrics = {
    'feeds': Feed.objects.count(),
    'subscriptions': UserSubscription.objects.count(),
    'exception_feeds': Feed.objects.filter(Q(has_feed_exception=True) | Q(has_page_exception=True)).count(),
    'update_queue': Feed.objects.filter(next_scheduled_update__lte=datetime.datetime.now()).count(),
}

if __name__ == '__main__':
    MuninGraph(graph_config, metrics).run()
