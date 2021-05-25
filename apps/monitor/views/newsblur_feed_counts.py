from django.conf import settings
from django.shortcuts import render
from django.views import View
import redis
from apps.rss_feeds.models import Feed, DuplicateFeed
from apps.push.models import PushSubscription
from apps.statistics.models import MStatistics

class FeedCounts(View):

    def get(self, request):
        
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
        
        data = {
            'scheduled_feeds': r.zcard('scheduled_updates'),
            'exception_feeds': exception_feeds,
            'exception_pages': exception_pages,
            'duplicate_feeds': duplicate_feeds,
            'active_feeds': active_feeds,
            'push_feeds': push_feeds,
        }
        chart_name = "feed_counts"
        chart_type = "counter"

        formatted_data = {}
        for k, v in data.items():
            formatted_data[k] = f'{chart_name}{{category="{k}"}} {v}'

        context = {
            "data": formatted_data,
            "chart_name": chart_name,
            "chart_type": chart_type,
        }
        return render(request, 'monitor/prometheus_data.html', context, content_type="text/plain")


