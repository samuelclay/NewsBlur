#!/srv/newsblur/venv/newsblur3/bin/python
from utils.munin.base import MuninGraph
import redis
import os
os.environ["DJANGO_SETTINGS_MODULE"] = "newsblur_web.settings"
import django
django.setup()

class NBMuninGraph(MuninGraph):

    @property
    def graph_config(self):
        return {
            'graph_category' : 'NewsBlur',
            'graph_title' : 'NewsBlur Feed Counts',
            'graph_vlabel' : 'Feeds Feed Counts',
            'graph_args' : '-l 0',
            'scheduled_feeds.label': 'scheduled_feeds',
            'exception_feeds.label': 'exception_feeds',
            'exception_pages.label': 'exception_pages',
            'duplicate_feeds.label': 'duplicate_feeds',
            'active_feeds.label': 'active_feeds',
            'push_feeds.label': 'push_feeds',
        }

    def calculate_metrics(self):
        from apps.rss_feeds.models import Feed, DuplicateFeed
        from apps.push.models import PushSubscription
        from django.conf import settings
        from apps.statistics.models import MStatistics
        
        exception_feeds = MStatistics.get('munin:exception_feeds')
        if not exception_feeds:
            exception_feeds = Feed.objects.filter(has_feed_exception=True).count()
            MStatistics.set('munin:exception_feeds', exception_feeds, 60*60*12)

        exception_pages = MStatistics.get('munin:exception_pages')
        if not exception_pages:
            exception_pages = Feed.objects.filter(has_page_exception=True).count()
            MStatistics.set('munin:exception_pages', exception_pages, 60*60*12)

        duplicate_feeds = MStatistics.get('munin:duplicate_feeds')
        if not duplicate_feeds:
            duplicate_feeds = DuplicateFeed.objects.count()
            MStatistics.set('munin:duplicate_feeds', duplicate_feeds, 60*60*12)

        active_feeds = MStatistics.get('munin:active_feeds')
        if not active_feeds:
            active_feeds = Feed.objects.filter(active_subscribers__gt=0).count()
            MStatistics.set('munin:active_feeds', active_feeds, 60*60*12)

        push_feeds = MStatistics.get('munin:push_feeds')
        if not push_feeds:
            push_feeds = PushSubscription.objects.filter(verified=True).count()
            MStatistics.set('munin:push_feeds', push_feeds, 60*60*12)

        r = redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)
        
        return {
            'scheduled_feeds': r.zcard('scheduled_updates'),
            'exception_feeds': exception_feeds,
            'exception_pages': exception_pages,
            'duplicate_feeds': duplicate_feeds,
            'active_feeds': active_feeds,
            'push_feeds': push_feeds,
        }

if __name__ == '__main__':
    NBMuninGraph().run()
