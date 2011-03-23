#!/usr/bin/env python 
from utils.munin.base import MuninGraph

graph_config = {
    'graph_category' : 'NewsBlur',
    'graph_title' : 'NewsBlur Feeds & Subscriptions',
    'graph_vlabel' : 'Feeds & Subscribers',
    'feeds.label': 'feeds',
    'subscriptions.label': 'subscriptions',
}

def calculate_metrics():
    from apps.rss_feeds.models import Feed
    from apps.reader.models import UserSubscription
    return {
        'feeds': Feed.objects.count(),
        'subscriptions': UserSubscription.objects.count(),
    }

if __name__ == '__main__':
    MuninGraph(graph_config, calculate_metrics).run()
