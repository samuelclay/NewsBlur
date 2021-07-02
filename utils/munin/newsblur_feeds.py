#!/srv/newsblur/venv/newsblur3/bin/python
from utils.munin.base import MuninGraph
import os
os.environ["DJANGO_SETTINGS_MODULE"] = "newsblur_web.settings"
import django
django.setup()

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
        from apps.statistics.models import MStatistics

        feeds_count = MStatistics.get('munin:feeds_count')
        if not feeds_count:
            feeds_count = Feed.objects.all().count()
            MStatistics.set('munin:feeds_count', feeds_count, 60*60*12)

        subscriptions_count = MStatistics.get('munin:subscriptions_count')
        if not subscriptions_count:
            subscriptions_count = UserSubscription.objects.all().count()
            MStatistics.set('munin:subscriptions_count', subscriptions_count, 60*60*12)

        return {
            'feeds': feeds_count,
            'subscriptions': subscriptions_count,
            'profiles': MSocialProfile.objects.count(),
            'social_subscriptions': MSocialSubscription.objects.count(),
        }

if __name__ == '__main__':
    NBMuninGraph().run()
