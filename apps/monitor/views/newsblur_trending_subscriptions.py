import re
import time

from django.shortcuts import render
from django.views import View

from apps.rss_feeds.models import Feed
from apps.statistics.rtrending_subscriptions import RTrendingSubscription


class TrendingSubscriptions(View):
    def get(self, request):
        """
        Prometheus metrics endpoint for trending feed subscriptions.

        Tracks which feeds are being added most frequently to identify
        trending/hot new feeds. Exposes 3 time windows: daily, weekly, monthly.

        Metrics exported:
        - Aggregate totals (total subscriptions today, unique feeds)
        - Top 10 trending feeds for each window (1d, 7d, 30d)
        - Daily subscription totals for charting
        """
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

        # Top trending feeds for 1d, 7d, and 30d windows
        for days in [1, 7, 30]:
            trending = RTrendingSubscription.get_trending_feeds_detailed(days=days, limit=10)

            if trending:
                feed_ids = [f["feed_id"] for f in trending]
                feeds_by_id = {}
                for feed in Feed.objects.filter(pk__in=feed_ids).values(
                    "pk", "feed_title", "num_subscribers"
                ):
                    feeds_by_id[feed["pk"]] = feed

                for rank, feed_data in enumerate(trending, 1):
                    feed_id = feed_data["feed_id"]
                    weighted_score = feed_data["weighted_score"]
                    raw_subs = feed_data["raw_subscriptions"]
                    subs_today = feed_data["subscriptions_today"]

                    feed_info = feeds_by_id.get(feed_id, {})
                    feed_title = self._sanitize_label(feed_info.get("feed_title", "Unknown"))
                    total_subs = feed_info.get("num_subscribers", 0)

                    key = f"trending_feed_{days}d_{rank}"
                    formatted_data[key] = (
                        f'{chart_name}{{metric="trending_feed",days="{days}",rank="{rank}",'
                        f'feed_id="{feed_id}",feed_title="{feed_title}",'
                        f'total_subscribers="{total_subs}",new_subscriptions="{raw_subs}",'
                        f'subscriptions_today="{subs_today}"}} {weighted_score:.2f}'
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
        return render(request, "monitor/prometheus_data.html", context, content_type="text/plain")

    def _sanitize_label(self, value):
        """Sanitize a string for use as a Prometheus label value."""
        if not value:
            return "Unknown"
        value = str(value)[:100]
        value = value.replace("\\", "\\\\")
        value = value.replace('"', '\\"')
        value = value.replace("\n", " ")
        value = value.replace("\r", " ")
        value = re.sub(r"[^\x20-\x7E]", "", value)
        return value
