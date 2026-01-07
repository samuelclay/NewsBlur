import datetime

import redis
from django.conf import settings


class RTrendingStory:
    """
    Tracks accumulated read time for stories and feeds to identify trending content.

    Redis Key Structure:
    - Story read time sorted set by day: "sRTi:{date}" -> sorted set {story_hash: total_seconds}
    - Feed read time sorted set by day: "fRT:{date}" -> sorted set {feed_id: total_seconds}
    - Story reader count by day: "sRTc:{date}" -> sorted set {story_hash: reader_count}
    - Feed reader count by day: "fRTc:{date}" -> sorted set {feed_id: reader_count}

    All data is stored in date-partitioned sorted sets for efficient aggregation.
    Reader counts (sRTc/fRTc) track unique read events to measure reach vs depth.
    All keys expire after 8 days for automatic cleanup.
    """

    MIN_READ_TIME_SECONDS = 3
    TTL_DAYS = 8
    CACHE_TTL_SECONDS = 60  # Cache aggregated results for 60 seconds

    @classmethod
    def _get_cached_union(cls, r, prefix, days):
        """
        Get or create a cached ZUNIONSTORE result for multi-day aggregation.

        Uses a deterministic cache key based on prefix, days, and today's date.
        Returns the cache key name which can be used for ZREVRANGE etc.
        The caller should NOT delete this key - it will expire automatically.

        Args:
            r: Redis connection
            prefix: Key prefix (e.g., "sRTi", "sRTc", "fRT", "fRTc")
            days: Number of days to aggregate

        Returns:
            Cache key name containing the aggregated sorted set
        """
        today = datetime.date.today().strftime("%Y-%m-%d")
        cache_key = f"{prefix}:cache:{days}d:{today}"

        # Check if cache exists
        if r.exists(cache_key):
            return cache_key

        # Build list of daily keys
        keys = []
        for i in range(days):
            day = (datetime.date.today() - datetime.timedelta(days=i)).strftime("%Y-%m-%d")
            keys.append(f"{prefix}:{day}")

        # Create the aggregated set
        r.zunionstore(cache_key, keys, aggregate="SUM")
        r.expire(cache_key, cls.CACHE_TTL_SECONDS)

        return cache_key

    @classmethod
    def add_read_time(cls, story_hash, read_time_seconds):
        """
        Add read time for a story. Filters out reads < 3 seconds.
        Updates story-level, feed-level, and story index aggregates.

        Args:
            story_hash: Story hash in format "feed_id:guid_hash"
            read_time_seconds: Number of seconds spent reading
        """
        if read_time_seconds < cls.MIN_READ_TIME_SECONDS:
            return

        # Extract feed_id from story_hash (format: "feed_id:guid_hash")
        try:
            feed_id = story_hash.split(":")[0]
            feed_id = int(feed_id)
        except (ValueError, IndexError, AttributeError):
            return

        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        today = datetime.date.today().strftime("%Y-%m-%d")
        ttl_seconds = cls.TTL_DAYS * 24 * 60 * 60

        pipe = r.pipeline()

        # Increment feed read time in daily sorted set
        feed_day_key = f"fRT:{today}"
        pipe.zincrby(feed_day_key, int(read_time_seconds), str(feed_id))
        pipe.expire(feed_day_key, ttl_seconds)

        # Add to story index sorted set for the day (enables top stories query)
        story_index_key = f"sRTi:{today}"
        pipe.zincrby(story_index_key, int(read_time_seconds), story_hash)
        pipe.expire(story_index_key, ttl_seconds)

        # Increment reader count for story (each call = one read event)
        story_count_key = f"sRTc:{today}"
        pipe.zincrby(story_count_key, 1, story_hash)
        pipe.expire(story_count_key, ttl_seconds)

        # Increment reader count for feed
        feed_count_key = f"fRTc:{today}"
        pipe.zincrby(feed_count_key, 1, str(feed_id))
        pipe.expire(feed_count_key, ttl_seconds)

        pipe.execute()

    @classmethod
    def get_story_read_time(cls, story_hash, days=7):
        """
        Get total read time for a story over the past N days.

        Args:
            story_hash: Story hash in format "feed_id:guid_hash"
            days: Number of days to aggregate (default 7)

        Returns:
            Total seconds spent reading this story
        """
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        total = 0

        pipe = r.pipeline()
        for i in range(days):
            day = (datetime.date.today() - datetime.timedelta(days=i)).strftime("%Y-%m-%d")
            key = f"sRTi:{day}"
            pipe.zscore(key, story_hash)

        values = pipe.execute()
        for val in values:
            if val:
                try:
                    total += int(val)
                except (ValueError, TypeError):
                    pass

        return total

    @classmethod
    def get_trending_feeds(cls, days=7, limit=50):
        """
        Get top trending feeds based on accumulated read time over past N days.

        Args:
            days: Number of days to aggregate (default 7, max 30)
            limit: Maximum feeds to return (default 50, max 200)

        Returns:
            List of (feed_id, total_seconds) tuples sorted by seconds desc
        """
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)

        if days > 1:
            cache_key = cls._get_cached_union(r, "fRT", days)
            result = r.zrevrange(cache_key, 0, limit - 1, withscores=True)
        else:
            today = datetime.date.today().strftime("%Y-%m-%d")
            result = r.zrevrange(f"fRT:{today}", 0, limit - 1, withscores=True)

        return [(int(feed_id), int(score)) for feed_id, score in result]

    @classmethod
    def get_feed_read_time(cls, feed_id, days=7):
        """
        Get total read time for a specific feed over the past N days.

        Args:
            feed_id: Feed ID
            days: Number of days to aggregate (default 7)

        Returns:
            Total seconds spent reading stories from this feed
        """
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        total = 0

        pipe = r.pipeline()
        for i in range(days):
            day = (datetime.date.today() - datetime.timedelta(days=i)).strftime("%Y-%m-%d")
            key = f"fRT:{day}"
            pipe.zscore(key, str(feed_id))

        values = pipe.execute()
        for val in values:
            if val:
                try:
                    total += int(val)
                except (ValueError, TypeError):
                    pass

        return total

    @classmethod
    def get_trending_stories(cls, days=7, limit=50):
        """
        Get top trending stories based on accumulated read time over past N days.

        Args:
            days: Number of days to aggregate (default 7, max 30)
            limit: Maximum stories to return (default 50, max 200)

        Returns:
            List of (story_hash, total_seconds) tuples sorted by seconds desc
        """
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)

        if days > 1:
            cache_key = cls._get_cached_union(r, "sRTi", days)
            result = r.zrevrange(cache_key, 0, limit - 1, withscores=True)
        else:
            today = datetime.date.today().strftime("%Y-%m-%d")
            result = r.zrevrange(f"sRTi:{today}", 0, limit - 1, withscores=True)

        return [
            (story_hash.decode() if isinstance(story_hash, bytes) else story_hash, int(score))
            for story_hash, score in result
        ]

    @classmethod
    def get_stories_for_feed(cls, feed_id, days=7, limit=20):
        """
        Get top stories for a specific feed based on read time.

        Args:
            feed_id: Feed ID to filter by
            days: Number of days to aggregate (default 7)
            limit: Maximum stories to return (default 20)

        Returns:
            List of (story_hash, total_seconds) tuples for stories from this feed
        """
        all_stories = cls.get_trending_stories(days=days, limit=500)
        feed_prefix = f"{feed_id}:"
        feed_stories = [(h, s) for h, s in all_stories if h.startswith(feed_prefix)]
        return feed_stories[:limit]

    @classmethod
    def get_story_reader_count(cls, story_hash, days=7):
        """
        Get total reader count for a story over the past N days.

        Args:
            story_hash: Story hash in format "feed_id:guid_hash"
            days: Number of days to aggregate (default 7)

        Returns:
            Total number of readers for this story
        """
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        total = 0

        pipe = r.pipeline()
        for i in range(days):
            day = (datetime.date.today() - datetime.timedelta(days=i)).strftime("%Y-%m-%d")
            key = f"sRTc:{day}"
            pipe.zscore(key, story_hash)

        values = pipe.execute()
        for val in values:
            if val:
                try:
                    total += int(val)
                except (ValueError, TypeError):
                    pass

        return total

    @classmethod
    def get_trending_stories_detailed(cls, days=7, limit=50):
        """
        Get trending stories with full metrics: total seconds, reader count, and avg per reader.

        This enables different views of "trending":
        - Sort by total_seconds: raw engagement (current default)
        - Sort by reader_count: popularity/reach
        - Sort by avg_seconds_per_reader: captivating content (deep reads)

        Args:
            days: Number of days to aggregate (default 7)
            limit: Maximum stories to return (default 50)

        Returns:
            List of dicts with story_hash, feed_id, total_seconds, reader_count, avg_seconds_per_reader
            sorted by total_seconds desc
        """
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        today = datetime.date.today().strftime("%Y-%m-%d")

        # Get time data
        if days > 1:
            time_cache_key = cls._get_cached_union(r, "sRTi", days)
            time_result = r.zrevrange(time_cache_key, 0, limit - 1, withscores=True)
        else:
            time_result = r.zrevrange(f"sRTi:{today}", 0, limit - 1, withscores=True)

        if not time_result:
            return []

        # Get the story hashes we care about
        story_hashes = [(sh.decode() if isinstance(sh, bytes) else sh) for sh, _ in time_result]
        time_map = {(sh.decode() if isinstance(sh, bytes) else sh): int(score) for sh, score in time_result}

        # Get count data
        if days > 1:
            count_cache_key = cls._get_cached_union(r, "sRTc", days)
        else:
            count_cache_key = f"sRTc:{today}"

        # Get counts for our specific stories
        pipe = r.pipeline()
        for sh in story_hashes:
            pipe.zscore(count_cache_key, sh)
        count_values = pipe.execute()

        count_map = {}
        for sh, val in zip(story_hashes, count_values):
            count_map[sh] = int(val) if val else 0

        # Build results
        results = []
        for story_hash in story_hashes:
            total_seconds = time_map.get(story_hash, 0)
            reader_count = count_map.get(story_hash, 0)

            try:
                feed_id = int(story_hash.split(":")[0])
            except (ValueError, IndexError):
                feed_id = 0

            results.append(
                {
                    "story_hash": story_hash,
                    "feed_id": feed_id,
                    "total_seconds": total_seconds,
                    "reader_count": reader_count,
                    "avg_seconds_per_reader": total_seconds / reader_count if reader_count > 0 else 0,
                }
            )

        return results

    @classmethod
    def get_trending_feeds_detailed(cls, days=7, limit=50):
        """
        Get trending feeds with full metrics: total seconds, reader count, and avg per reader.

        Args:
            days: Number of days to aggregate (default 7)
            limit: Maximum feeds to return (default 50)

        Returns:
            List of dicts with feed_id, total_seconds, reader_count, avg_seconds_per_reader
            sorted by total_seconds desc
        """
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        today = datetime.date.today().strftime("%Y-%m-%d")

        # Get time data
        if days > 1:
            time_cache_key = cls._get_cached_union(r, "fRT", days)
            time_result = r.zrevrange(time_cache_key, 0, limit - 1, withscores=True)
        else:
            time_result = r.zrevrange(f"fRT:{today}", 0, limit - 1, withscores=True)

        if not time_result:
            return []

        feed_ids = [(fid.decode() if isinstance(fid, bytes) else fid) for fid, _ in time_result]
        time_map = {
            (fid.decode() if isinstance(fid, bytes) else fid): int(score) for fid, score in time_result
        }

        # Get count data
        if days > 1:
            count_cache_key = cls._get_cached_union(r, "fRTc", days)
        else:
            count_cache_key = f"fRTc:{today}"

        pipe = r.pipeline()
        for fid in feed_ids:
            pipe.zscore(count_cache_key, fid)
        count_values = pipe.execute()

        count_map = {}
        for fid, val in zip(feed_ids, count_values):
            count_map[fid] = int(val) if val else 0

        results = []
        for feed_id_str in feed_ids:
            try:
                feed_id = int(feed_id_str)
            except ValueError:
                continue

            total_seconds = time_map.get(feed_id_str, 0)
            reader_count = count_map.get(feed_id_str, 0)

            results.append(
                {
                    "feed_id": feed_id,
                    "total_seconds": total_seconds,
                    "reader_count": reader_count,
                    "avg_seconds_per_reader": total_seconds / reader_count if reader_count > 0 else 0,
                }
            )

        return results

    @classmethod
    def get_trending_feeds_normalized(cls, days=7, limit=50, min_subscribers=1, max_subscribers=None):
        """
        Get trending feeds normalized by subscriber count to surface "hidden gems".

        This helps find feeds that may have few subscribers but high engagement per reader,
        rather than popular feeds that dominate due to sheer volume.

        Args:
            days: Number of days to aggregate (default 7)
            limit: Maximum feeds to return (default 50)
            min_subscribers: Minimum subscribers to include (default 1, avoids division issues)
            max_subscribers: Maximum subscribers to include (default None = no max)

        Returns:
            List of dicts with feed_id, total_seconds, num_subscribers, seconds_per_subscriber
            sorted by seconds_per_subscriber desc
        """
        from apps.rss_feeds.models import Feed

        trending = cls.get_trending_feeds(days=days, limit=500)
        if not trending:
            return []

        feed_ids = [feed_id for feed_id, _ in trending]
        feeds = Feed.objects.filter(pk__in=feed_ids).values("pk", "num_subscribers")
        subscriber_map = {f["pk"]: max(f["num_subscribers"], 1) for f in feeds}

        results = []
        for feed_id, total_seconds in trending:
            subs = subscriber_map.get(feed_id, 1)
            if subs < min_subscribers:
                continue
            if max_subscribers and subs > max_subscribers:
                continue

            results.append(
                {
                    "feed_id": feed_id,
                    "total_seconds": total_seconds,
                    "num_subscribers": subs,
                    "seconds_per_subscriber": total_seconds / subs,
                }
            )

        results.sort(key=lambda x: x["seconds_per_subscriber"], reverse=True)
        return results[:limit]
