import datetime
import uuid

import redis
from django.conf import settings


class RTrendingStory:
    """
    Tracks accumulated read time for stories and feeds to identify trending content.

    Redis Key Structure:
    - Story read time by day: "sRT:{story_hash}:{date}" -> total_seconds (string/int)
    - Feed read time sorted set by day: "fRT:{date}" -> sorted set {feed_id: total_seconds}

    All keys expire after 8 days for automatic cleanup.
    """

    MIN_READ_TIME_SECONDS = 10
    TTL_DAYS = 8

    @classmethod
    def add_read_time(cls, story_hash, read_time_seconds):
        """
        Add read time for a story. Filters out reads < 10 seconds.
        Updates both story-level and feed-level aggregates.

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

        # Increment story read time for today
        story_key = f"sRT:{story_hash}:{today}"
        pipe.incrby(story_key, int(read_time_seconds))
        pipe.expire(story_key, ttl_seconds)

        # Increment feed read time in daily sorted set
        feed_day_key = f"fRT:{today}"
        pipe.zincrby(feed_day_key, int(read_time_seconds), str(feed_id))
        pipe.expire(feed_day_key, ttl_seconds)

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
            key = f"sRT:{story_hash}:{day}"
            pipe.get(key)

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

        # Get keys for past N days
        keys = []
        for i in range(days):
            day = (datetime.date.today() - datetime.timedelta(days=i)).strftime("%Y-%m-%d")
            keys.append(f"fRT:{day}")

        if not keys:
            return []

        if len(keys) > 1:
            # Create temporary union key
            temp_key = f"fRT:temp:{uuid.uuid4()}"

            # ZUNIONSTORE to combine all daily sorted sets
            r.zunionstore(temp_key, keys, aggregate="SUM")
            r.expire(temp_key, 60)  # Short TTL for temp key

            result = r.zrevrange(temp_key, 0, limit - 1, withscores=True)
            r.delete(temp_key)
        else:
            result = r.zrevrange(keys[0], 0, limit - 1, withscores=True)

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
