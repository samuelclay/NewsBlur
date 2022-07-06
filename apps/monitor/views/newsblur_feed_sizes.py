from django.conf import settings
from django.shortcuts import render
from django.views import View
from django.db.models import Sum
import redis
from apps.rss_feeds.models import Feed, DuplicateFeed
from apps.push.models import PushSubscription
from apps.statistics.models import MStatistics

class FeedSizes(View):

    def get(self, request):
        
        fs_size_bytes = MStatistics.get('munin:fs_size_bytes')
        if not fs_size_bytes:
            fs_size_bytes = Feed.objects.aggregate(Sum('fs_size_bytes'))['fs_size_bytes__sum']
            MStatistics.set('munin:fs_size_bytes', fs_size_bytes, 60*60*12)

        archive_users_size_bytes = MStatistics.get('munin:archive_users_size_bytes')
        if not archive_users_size_bytes:
            archive_users_size_bytes = Feed.objects.filter(archive_subscribers__gte=1).aggregate(Sum('fs_size_bytes'))['fs_size_bytes__sum']
            MStatistics.set('munin:archive_users_size_bytes', archive_users_size_bytes, 60*60*12)

        data = {
            'fs_size_bytes': fs_size_bytes,
            'archive_users_size_bytes': archive_users_size_bytes,
        }
        chart_name = "feed_sizes"
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


