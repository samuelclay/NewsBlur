#!/usr/bin/env python 
from utils.munin.base import MuninGraph

class NBMuninGraph(MuninGraph):

    @property
    def graph_config(self):
        return {
            'graph_category' : 'NewsBlur',
            'graph_title' : 'NewsBlur Feed Counts',
            'graph_vlabel' : 'Feeds Feed Counts',
            'graph_args' : '-l 0',
            'exception_feeds.label': 'exception_feeds',
            'exception_pages.label': 'exception_pages',
            'duplicate_feeds.label': 'duplicate_feeds',
            'active_feeds.label': 'active_feeds',
            'push_feeds.label': 'push_feeds',
        }

    def calculate_metrics(self):
        from apps.rss_feeds.models import Feed, DuplicateFeed
        from apps.push.models import PushSubscription
    
        return {
            'exception_feeds': Feed.objects.filter(has_feed_exception=True).count(),
            'exception_pages': Feed.objects.filter(has_page_exception=True).count(),
            'duplicate_feeds': DuplicateFeed.objects.count(),
            'active_feeds': Feed.objects.filter(active_subscribers__gt=0).count(),
            'push_feeds': PushSubscription.objects.filter(verified=True).count(),
        }

if __name__ == '__main__':
    NBMuninGraph().run()
