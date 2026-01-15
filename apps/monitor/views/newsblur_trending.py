import datetime
import re
import time

import redis
from django.conf import settings
from django.shortcuts import render
from django.views import View

from apps.rss_feeds.models import Feed, MStory
from apps.statistics.rtrending import RTrendingStory


class TrendingFeeds(View):
    def get(self, request):
        """
        Metrics endpoint for trending feeds and stories tracking.

        Exposes data from the 4 daily Redis keys:
        - fRT:{date} - Feed read time (feed_id -> total_seconds)
        - sRTi:{date} - Story read time index (story_hash -> total_seconds)
        - sRTc:{date} - Story reader count (story_hash -> reader_count)
        - fRTc:{date} - Feed reader count (feed_id -> reader_count)

        Metrics exported:
        - Aggregate totals (total seconds, story/feed reads, unique counts)
        - Top 5 stories with full details (for Grafana table)
        - Top 10 feeds by read time
        - Read time distribution buckets
        """
        start_time = time.time()

        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        today = datetime.date.today().strftime("%Y-%m-%d")

        data = {}
        formatted_data = {}
        chart_name = "trending"
        chart_type = "gauge"

        # Get aggregate metrics for today
        feed_time_key = f"fRT:{today}"
        story_time_key = f"sRTi:{today}"
        story_count_key = f"sRTc:{today}"
        feed_count_key = f"fRTc:{today}"

        # Total seconds read today (sum of all feed read times)
        feed_times = r.zrange(feed_time_key, 0, -1, withscores=True)
        total_read_seconds = sum(int(score) for _, score in feed_times)
        data["total_read_seconds"] = total_read_seconds

        # Total story reads today (sum of all story reader counts)
        story_counts = r.zrange(story_count_key, 0, -1, withscores=True)
        total_story_reads = sum(int(score) for _, score in story_counts)
        data["total_story_reads"] = total_story_reads

        # Total feed reads today (sum of all feed reader counts)
        feed_counts = r.zrange(feed_count_key, 0, -1, withscores=True)
        total_feed_reads = sum(int(score) for _, score in feed_counts)
        data["total_feed_reads"] = total_feed_reads

        # Unique stories read today
        unique_stories = r.zcard(story_time_key)
        data["unique_stories_read"] = unique_stories

        # Unique feeds read today
        unique_feeds = r.zcard(feed_time_key)
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

        # Top stories for both 1-day and 7-day windows
        for days in [1, 7]:
            top_stories = RTrendingStory.get_trending_stories_detailed(days=days, limit=5)

            if top_stories:
                # Get story hashes to look up details
                story_hashes = [s["story_hash"] for s in top_stories]

                # Bulk fetch stories from MongoDB
                stories_by_hash = {}
                for story in MStory.objects(story_hash__in=story_hashes).only(
                    "story_hash", "story_title", "story_date", "story_feed_id"
                ):
                    stories_by_hash[story.story_hash] = story

                # Get feed titles
                feed_ids = list(set(s["feed_id"] for s in top_stories))
                feeds_by_id = {}
                for feed in Feed.objects.filter(pk__in=feed_ids).values("pk", "feed_title"):
                    feeds_by_id[feed["pk"]] = feed["feed_title"]

                for rank, story_data in enumerate(top_stories, 1):
                    story_hash = story_data["story_hash"]
                    feed_id = story_data["feed_id"]
                    total_seconds = story_data["total_seconds"]
                    reader_count = story_data["reader_count"]

                    # Get story details from MongoDB lookup
                    story = stories_by_hash.get(story_hash)
                    if story:
                        story_title = story.story_title or "Unknown"
                        story_date = (
                            story.story_date.strftime("%Y-%m-%d %H:%M") if story.story_date else "Unknown"
                        )
                    else:
                        story_title = "Unknown"
                        story_date = "Unknown"

                    feed_title = feeds_by_id.get(feed_id, "Unknown Feed")

                    # Sanitize strings for Prometheus labels (escape quotes and backslashes)
                    story_title_safe = self._sanitize_label(story_title)
                    feed_title_safe = self._sanitize_label(feed_title)
                    story_hash_safe = self._sanitize_label(story_hash)

                    key = f"top_story_{days}d_{rank}"
                    formatted_data[key] = (
                        f'{chart_name}{{metric="top_story",days="{days}",rank="{rank}",'
                        f'feed_id="{feed_id}",feed_title="{feed_title_safe}",'
                        f'story_hash="{story_hash_safe}",story_title="{story_title_safe}",'
                        f'story_date="{story_date}",reader_count="{reader_count}"}} {total_seconds}'
                    )

        # Top feeds for both 1-day and 7-day windows
        for days in [1, 7]:
            top_feeds = RTrendingStory.get_trending_feeds_detailed(days=days, limit=10)

            if top_feeds:
                feed_ids = [f["feed_id"] for f in top_feeds]
                feeds_by_id = {}
                for feed in Feed.objects.filter(pk__in=feed_ids).values("pk", "feed_title"):
                    feeds_by_id[feed["pk"]] = feed["feed_title"]

                for rank, feed_data in enumerate(top_feeds, 1):
                    feed_id = feed_data["feed_id"]
                    total_seconds = feed_data["total_seconds"]
                    reader_count = feed_data["reader_count"]
                    feed_title = feeds_by_id.get(feed_id, "Unknown Feed")
                    feed_title_safe = self._sanitize_label(feed_title)

                    key = f"top_feed_{days}d_{rank}"
                    formatted_data[key] = (
                        f'{chart_name}{{metric="top_feed",days="{days}",rank="{rank}",'
                        f'feed_id="{feed_id}",feed_title="{feed_title_safe}",'
                        f'reader_count="{reader_count}"}} {total_seconds}'
                    )

        # Long Reads (stories with ≥3 readers, sorted by avg read time)
        for days in [1, 7]:
            long_reads = RTrendingStory.get_long_reads(days=days, limit=5, min_readers=3)

            if long_reads:
                story_hashes = [s["story_hash"] for s in long_reads]

                # Bulk fetch stories from MongoDB
                stories_by_hash = {}
                for story in MStory.objects(story_hash__in=story_hashes).only(
                    "story_hash", "story_title", "story_date", "story_feed_id"
                ):
                    stories_by_hash[story.story_hash] = story

                # Get feed titles
                feed_ids = list(set(s["feed_id"] for s in long_reads))
                feeds_by_id = {}
                for feed in Feed.objects.filter(pk__in=feed_ids).values("pk", "feed_title"):
                    feeds_by_id[feed["pk"]] = feed["feed_title"]

                for rank, story_data in enumerate(long_reads, 1):
                    story_hash = story_data["story_hash"]
                    feed_id = story_data["feed_id"]
                    total_seconds = story_data["total_seconds"]
                    reader_count = story_data["reader_count"]
                    avg_seconds = story_data["avg_seconds_per_reader"]

                    story = stories_by_hash.get(story_hash)
                    if story:
                        story_title = story.story_title or "Unknown"
                        story_date = (
                            story.story_date.strftime("%Y-%m-%d %H:%M") if story.story_date else "Unknown"
                        )
                    else:
                        story_title = "Unknown"
                        story_date = "Unknown"

                    feed_title = feeds_by_id.get(feed_id, "Unknown Feed")

                    story_title_safe = self._sanitize_label(story_title)
                    feed_title_safe = self._sanitize_label(feed_title)
                    story_hash_safe = self._sanitize_label(story_hash)

                    key = f"long_read_{days}d_{rank}"
                    formatted_data[key] = (
                        f'{chart_name}{{metric="long_read",days="{days}",rank="{rank}",'
                        f'feed_id="{feed_id}",feed_title="{feed_title_safe}",'
                        f'story_hash="{story_hash_safe}",story_title="{story_title_safe}",'
                        f'story_date="{story_date}",reader_count="{reader_count}",'
                        f'total_seconds="{total_seconds}"}} {avg_seconds:.1f}'
                    )

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
        return render(request, "monitor/prometheus_data.html", context, content_type="text/plain")

    def _sanitize_label(self, value):
        """Sanitize a string for use as a Prometheus label value."""
        if not value:
            return "Unknown"
        # Escape backslashes first, then quotes, then newlines
        value = str(value)[:100]  # Truncate to 100 chars
        value = value.replace("\\", "\\\\")
        value = value.replace('"', '\\"')
        value = value.replace("\n", " ")
        value = value.replace("\r", " ")
        # Remove any other problematic characters
        value = re.sub(r"[^\x20-\x7E]", "", value)
        return value
