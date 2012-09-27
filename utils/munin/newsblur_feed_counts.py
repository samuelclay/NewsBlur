#!/usr/bin/env python 
from utils.munin.base import MuninGraph

class NBMuninGraph(MuninGraph):

    @property
    def graph_config(self):
        return {
            'graph_category' : 'NewsBlur',
            'graph_title' : 'NewsBlur Feed Counts',
            'graph_vlabel' : 'Feeds Feed Counts',
            'exception_feeds.label': 'exception_feeds',
            'exception_pages.label': 'exception_pages',
            'inactive_feeds.label': 'inactive_feeds',
            'duplicate_feeds.label': 'duplicate_feeds',
            'active_feeds.label': 'active_feeds',
            'known_good_feeds.label': 'known_good',
            'push_feeds.label': 'push_feeds',
            'push_feeds_failed.label': 'push_feeds_failed',
        }

    def calculate_metrics(self):
        from apps.rss_feeds.models import Feed, DuplicateFeed
        from apps.push.models import PushSubscription
    
        return {
            'exception_feeds': Feed.objects.filter(has_feed_exception=True).count(),
            'exception_pages': Feed.objects.filter(has_page_exception=True).count(),
            'inactive_feeds': Feed.objects.filter(active=False).count(),
            'duplicate_feeds': DuplicateFeed.objects.count(),
            'active_feeds': Feed.objects.filter(active_subscribers__gt=0).count(),
            'known_good_feeds': Feed.objects.filter(known_good=True).count(),
            'push_feeds': PushSubscription.objects.filter(verified=True).count(),
            'push_feeds_failed': PushSubscription.objects.filter(verified=False).count(),
        }

if __name__ == '__main__':
    NBMuninGraph().run()
