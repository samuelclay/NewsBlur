import time

import redis
from django.conf import settings
from django.http import HttpResponse
from django.shortcuts import render
from django.views import View

from apps.statistics.rtrending_subscriptions import RTrendingSubscription

CACHE_KEY = "monitor:trending_subs:cache"
CACHE_TTL = 60 * 60  # 1 hour


class TrendingSubscriptions(View):
    def get(self, request):
        """
        Prometheus metrics endpoint for trending feed subscriptions.
        Results are cached for 1 hour since these Grafana graphs don't need real-time data.
        """
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)

        cached = r.get(CACHE_KEY)
        if cached:
            return HttpResponse(cached, content_type="text/plain")

        start_time = time.time()

        formatted_data = {}
        chart_name = "trending_subscriptions"
        chart_type = "gauge"

        # Get aggregate stats for today
        stats = RTrendingSubscription.get_stats_for_prometheus()

        formatted_data["total_subscriptions_today"] = (
            f'{chart_name}{{metric="total_subscriptions_today"}} ' f'{stats["total_subscriptions_today"]}'
        )
        formatted_data["unique_feeds_subscribed_today"] = (
            f'{chart_name}{{metric="unique_feeds_subscribed_today"}} ' f'{stats["unique_feeds_today"]}'
        )

        # Daily totals for the past 7 days (for charting subscription activity)
        daily_totals = RTrendingSubscription.get_daily_totals(days=7)
        for date_str, total in daily_totals:
            key = f"daily_total_{date_str}"
            formatted_data[key] = f'{chart_name}{{metric="daily_subscriptions",date="{date_str}"}} {total}'

        # Self-monitoring: track endpoint response time
        elapsed_ms = (time.time() - start_time) * 1000
        formatted_data["scrape_duration"] = f'{chart_name}{{metric="scrape_duration_ms"}} {elapsed_ms:.1f}'

        context = {
            "data": formatted_data,
            "chart_name": chart_name,
            "chart_type": chart_type,
        }
        response = render(request, "monitor/prometheus_data.html", context, content_type="text/plain")
        r.set(CACHE_KEY, response.content, ex=CACHE_TTL)
        return response
