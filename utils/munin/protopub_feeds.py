#!/usr/bin/env python 

from utils.munin.base import MuninGraph
from rss_feeds.models import Feed
from reader.models import UserSubscriptions

graph_config = {
    'graph_category' : 'Protopub',
    'graph_title' : 'Protopub Feeds',
    'graph_vlabel' : 'users',
    'feeds.label': 'feeds',
    'subscriptions.label': 'subscriptions',
}

metrics = {
    'feeds': Feed.objects.count(),
    'subscriptions': UserSubscriptions.objects.count(),
}

if __name__ == '__main__':
    MuninGraph(graph_config, metrics).run()
