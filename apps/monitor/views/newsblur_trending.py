import datetime
import time

import redis
from django.conf import settings
from django.http import HttpResponse
from django.shortcuts import render
from django.views import View

from apps.statistics.rtrending import RTrendingStory

CACHE_KEY = "monitor:trending_feeds:cache"
CACHE_TTL = 60 * 60  # 1 hour


class TrendingFeeds(View):
    def get(self, request):
        """
        Metrics endpoint for trending feeds and stories tracking.
        Results are cached for 1 hour since these Grafana graphs don't need real-time data.
        """
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)

        cached = r.get(CACHE_KEY)
        if cached:
            return HttpResponse(cached, content_type="text/plain")

        start_time = time.time()
        today = datetime.date.today().strftime("%Y-%m-%d")

        data = {}
        formatted_data = {}
        chart_name = "trending"
        chart_type = "gauge"

        # Get aggregate metrics for today using running counters + ZCARD
        pipe = r.pipeline()
        pipe.get(f"fRT:total:{today}")
        pipe.get(f"sRTc:total:{today}")
        pipe.get(f"fRTc:total:{today}")
        pipe.zcard(f"sRTi:{today}")
        pipe.zcard(f"fRT:{today}")
        total_read_seconds, total_story_reads, total_feed_reads, unique_stories, unique_feeds = pipe.execute()

        data["total_read_seconds"] = int(total_read_seconds) if total_read_seconds else 0
        data["total_story_reads"] = int(total_story_reads) if total_story_reads else 0
        data["total_feed_reads"] = int(total_feed_reads) if total_feed_reads else 0
        data["unique_stories_read"] = unique_stories
        data["unique_feeds_read"] = unique_feeds

        # Format aggregate metrics
        formatted_data[
            "total_read_seconds"
        ] = f'{chart_name}{{metric="total_read_seconds"}} {data["total_read_seconds"]}'
        formatted_data[
            "total_story_reads"
        ] = f'{chart_name}{{metric="total_story_reads"}} {data["total_story_reads"]}'
        formatted_data[
            "total_feed_reads"
        ] = f'{chart_name}{{metric="total_feed_reads"}} {data["total_feed_reads"]}'
        formatted_data[
            "unique_stories_read"
        ] = f'{chart_name}{{metric="unique_stories_read"}} {data["unique_stories_read"]}'
        formatted_data[
            "unique_feeds_read"
        ] = f'{chart_name}{{metric="unique_feeds_read"}} {data["unique_feeds_read"]}'

        diversity_metrics = {
            key.decode()
            if isinstance(key, bytes)
            else key: value.decode()
            if isinstance(value, bytes)
            else value
            for key, value in r.hgetall(RTrendingStory.DIVERSITY_METRICS_KEY).items()
        }
        list_keys = {
            "well_read": RTrendingStory.WELL_READ_KEY,
            "long_reads": RTrendingStory.LONG_READS_KEY,
            "good_reads": RTrendingStory.GOOD_READS_KEY,
        }
        for list_name in ("well_read", "long_reads", "good_reads"):
            for metric_name in (
                "size",
                "unique_publishers_50",
                "top_publisher_share_50",
                "publisher_hhi_50",
            ):
                value = diversity_metrics.get(f"{list_name}:{metric_name}", 0)
                formatted_data[
                    f"{list_name}_{metric_name}"
                ] = f'{chart_name}{{metric="{metric_name}",list="{list_name}"}} {value}'

        # Stories posted to each curated feed in the last 24 hours. The lists are sorted sets
        # scored by story_date, so ZCOUNT over the last day's timestamps is O(log N) per list.
        day_ago = time.time() - 24 * 60 * 60
        pipe = r.pipeline()
        for list_name in ("well_read", "long_reads", "good_reads"):
            pipe.zcount(list_keys[list_name], day_ago, "+inf")
        stories_24h = pipe.execute()
        for list_name, count in zip(("well_read", "long_reads", "good_reads"), stories_24h):
            formatted_data[
                f"{list_name}_stories_24h"
            ] = f'{chart_name}{{metric="stories_24h",list="{list_name}"}} {count or 0}'

        refresh_timestamp = r.get(RTrendingStory.REFRESH_TIMESTAMP_KEY)
        refresh_timestamp = int(refresh_timestamp) if refresh_timestamp else 0
        refresh_age = max(int(time.time()) - refresh_timestamp, 0) if refresh_timestamp else 0
        formatted_data["trending_refresh_age"] = f'{chart_name}{{metric="refresh_age_seconds"}} {refresh_age}'

        # Read time distribution buckets (0-15, 15-30, 30-60, 60-120, 120+)
        # Using ZCOUNT for O(log N) per bucket instead of fetching all stories
        buckets = [
            ("0-15", 0, 15),
            ("15-30", 15, 30),
            ("30-60", 30, 60),
            ("60-120", 60, 120),
            ("120+", 120, float("inf")),
        ]

        for days in [1, 7]:
            bucket_counts = {b[0]: 0 for b in buckets}

            if days == 1:
                # For single day, use ZCOUNT directly on the key (O(log N) per bucket)
                key = f"sRTi:{today}"
                pipe = r.pipeline()
                for bucket_name, min_val, max_val in buckets:
                    max_score = "+inf" if max_val == float("inf") else f"({max_val}"
                    pipe.zcount(key, min_val, max_score)
                counts = pipe.execute()
                for i, (bucket_name, _, _) in enumerate(buckets):
                    bucket_counts[bucket_name] = counts[i] if counts[i] else 0
            else:
                # For multi-day, we need to aggregate - use top 500 stories as sample
                # This is a trade-off: exact counts vs performance
                all_stories = RTrendingStory.get_trending_stories(days=days, limit=500)
                for story_hash, total_seconds in all_stories:
                    for bucket_name, min_val, max_val in buckets:
                        if min_val <= total_seconds < max_val:
                            bucket_counts[bucket_name] += 1
                            break

            for bucket_name in bucket_counts:
                key = f"bucket_{days}d_{bucket_name}"
                formatted_data[key] = (
                    f'{chart_name}{{metric="stories_by_seconds_bucket",days="{days}",'
                    f'bucket="{bucket_name}"}} {bucket_counts[bucket_name]}'
                )

        # Average seconds per reader (aggregate) - use top 100 as sample for performance
        for days in [1, 7]:
            stories_detailed = RTrendingStory.get_trending_stories_detailed(days=days, limit=100)
            if stories_detailed:
                total_seconds_all = sum(s["total_seconds"] for s in stories_detailed)
                total_readers_all = sum(s["reader_count"] for s in stories_detailed)
                avg_seconds = total_seconds_all / total_readers_all if total_readers_all > 0 else 0
            else:
                avg_seconds = 0

            key = f"avg_seconds_per_reader_{days}d"
            formatted_data[
                key
            ] = f'{chart_name}{{metric="avg_seconds_per_reader",days="{days}"}} {avg_seconds:.1f}'

        # Self-monitoring: track how long this endpoint takes to respond
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
