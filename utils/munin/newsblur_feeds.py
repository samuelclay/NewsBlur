#!/usr/bin/env python 
from utils.munin.base import MuninGraph
from apps.rss_feeds.models import Feed, DuplicateFeed
from apps.reader.models import UserSubscription
from django.db.models import Q

graph_config = {
    'graph_category' : 'NewsBlur',
    'graph_title' : 'NewsBlur Feeds & Subscriptions',
    'graph_vlabel' : 'Feeds & Subscribers',
    'feeds.label': 'feeds',
    'subscriptions.label': 'subscriptions',
    'exception_feeds.label': 'exception_feeds',
    'inactive_feeds.label': 'inactive_feeds',
    'duplicate_feeds.label': 'duplicate_feeds',
    'active_feeds.label': 'active_feeds',
}

metrics = {
    'feeds': Feed.objects.count(),
    'subscriptions': UserSubscription.objects.count(),
    'exception_feeds': Feed.objects.filter(Q(has_feed_exception=True) | Q(has_page_exception=True)).count(),
    'inactive_feeds': Feed.objects.filter(active=False).count(),
    'duplicate_feeds': DuplicateFeed.objects.count(),
    'active_feeds': Feed.objects.filter(active_subscribers__gte=0).count(),
}

if __name__ == '__main__':
    MuninGraph(graph_config, metrics).run()
