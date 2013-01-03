#!/usr/bin/env python 
from utils.munin.base import MuninGraph

class NBMuninGraph(MuninGraph):

    @property
    def graph_config(self):
        return {
            'graph_category' : 'NewsBlur',
            'graph_title' : 'NewsBlur Feeds & Subscriptions',
            'graph_vlabel' : 'Feeds & Subscribers',
            'graph_args' : '-l 0',
            'feeds.label': 'feeds',
            'subscriptions.label': 'subscriptions',
            'profiles.label': 'profiles',
            'social_subscriptions.label': 'social_subscriptions',
        }

    def calculate_metrics(self):
        from apps.rss_feeds.models import Feed
        from apps.reader.models import UserSubscription
        from apps.social.models import MSocialProfile, MSocialSubscription
        return {
            'feeds': Feed.objects.count(),
            'subscriptions': UserSubscription.objects.count(),
            'profiles': MSocialProfile.objects.count(),
            'social_subscriptions': MSocialSubscription.objects.count(),
        }

if __name__ == '__main__':
    NBMuninGraph().run()
