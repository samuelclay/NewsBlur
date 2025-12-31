import datetime

import redis
from django.conf import settings


class RTrendingSubscription:
    """
    Tracks feed subscription events to identify trending feeds by subscription velocity.

    Unlike RTrendingStory (which tracks read engagement), this class tracks
    how quickly feeds are gaining new subscribers - a leading indicator of
    feed popularity.

    Redis Key Structure:
    - fSub:{date} -> sorted set {feed_id: subscription_count}

    All data is stored in date-partitioned sorted sets for efficient aggregation.
    All keys expire after 35 days (to support 30-day trending window).
    """

    TTL_DAYS = 35
    CACHE_TTL_SECONDS = 60
    MIN_SUBSCRIBERS_THRESHOLD = 4

    # Decay weights for multi-day aggregation (today=1.0, progressively lower)
    # More recent subscriptions count more heavily toward trending
    DECAY_WEIGHTS = {
        1: [1.0],
        7: [1.0, 0.85, 0.7, 0.55, 0.4, 0.3, 0.2],
        30: [
            1.0,
            0.97,
            0.93,
            0.90,
            0.87,
            0.83,
            0.80,
            0.77,
            0.73,
            0.70,
            0.67,
            0.63,
            0.60,
            0.57,
            0.53,
            0.50,
            0.47,
            0.43,
            0.40,
            0.37,
            0.33,
            0.30,
            0.27,
            0.23,
            0.20,
            0.17,
            0.13,
            0.10,
            0.07,
            0.03,
        ],
    }

    @classmethod
    def add_subscription(cls, feed_id):
        """
        Record a subscription event for a feed.

        Args:
            feed_id: The feed ID being subscribed to
        """
        if not feed_id:
            return

        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        today = datetime.date.today().strftime("%Y-%m-%d")
        ttl_seconds = cls.TTL_DAYS * 24 * 60 * 60

        key = f"fSub:{today}"
        pipe = r.pipeline()
        pipe.zincrby(key, 1, str(feed_id))
        pipe.expire(key, ttl_seconds)
        pipe.execute()

    @classmethod
    def _get_decay_weights(cls, days):
        """
        Get decay weights for the specified number of days.
        Uses predefined weights for common windows, interpolates for others.
        """
        if days in cls.DECAY_WEIGHTS:
            return cls.DECAY_WEIGHTS[days]

        # Interpolate for non-standard day counts
        return [max(0.03, 1.0 - (i * 0.97 / max(days - 1, 1))) for i in range(days)]

    @classmethod
    def _get_cached_weighted_union(cls, r, days):
        """
        Get or create a cached weighted aggregation across multiple days.

        Uses decay weights so recent subscriptions count more than older ones.
        Returns the cache key name which can be used for ZREVRANGE etc.

        Args:
            r: Redis connection
            days: Number of days to aggregate

        Returns:
            Cache key name containing the aggregated sorted set
        """
        today = datetime.date.today().strftime("%Y-%m-%d")
        cache_key = f"fSub:cache:{days}d:{today}"

        # Check if cache exists
        if r.exists(cache_key):
            return cache_key

        weights = cls._get_decay_weights(days)

        # Build weighted union
        keys = []
        weight_list = []
        for i in range(min(days, len(weights))):
            day = (datetime.date.today() - datetime.timedelta(days=i)).strftime("%Y-%m-%d")
            key = f"fSub:{day}"
            if r.exists(key):
                keys.append(key)
                weight_list.append(weights[i])

        if keys:
            r.zunionstore(cache_key, dict(zip(keys, weight_list)), aggregate="SUM")
            r.expire(cache_key, cls.CACHE_TTL_SECONDS)

        return cache_key

    @classmethod
    def get_trending_feeds(cls, days=7, limit=50, min_subscribers=None):
        """
        Get feeds trending by subscription velocity.

        Args:
            days: Number of days to aggregate (1, 7, or 30 recommended)
            limit: Maximum feeds to return (default 50, max 200)
            min_subscribers: Minimum raw subscriptions to include (default: MIN_SUBSCRIBERS_THRESHOLD)

        Returns:
            List of (feed_id, weighted_score) tuples sorted by score desc
        """
        if min_subscribers is None:
            min_subscribers = cls.MIN_SUBSCRIBERS_THRESHOLD

        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)

        if days == 1:
            today = datetime.date.today().strftime("%Y-%m-%d")
            cache_key = f"fSub:{today}"
        else:
            cache_key = cls._get_cached_weighted_union(r, days)

        # Get more results than needed to filter by threshold
        results = r.zrevrange(cache_key, 0, limit * 3, withscores=True)

        # Filter by minimum threshold and limit
        filtered = []
        for feed_id, score in results:
            if score >= min_subscribers:
                try:
                    feed_id_str = feed_id.decode() if isinstance(feed_id, bytes) else feed_id
                    filtered.append((int(feed_id_str), score))
                except ValueError:
                    continue
            if len(filtered) >= limit:
                break

        return filtered

    @classmethod
    def get_feed_subscription_count(cls, feed_id, days=7):
        """
        Get raw subscription count for a specific feed over N days.
        Does NOT apply decay weights - returns actual subscription count.

        Args:
            feed_id: Feed ID
            days: Number of days to aggregate

        Returns:
            Raw subscription count (not weighted)
        """
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        total = 0

        pipe = r.pipeline()
        for i in range(days):
            day = (datetime.date.today() - datetime.timedelta(days=i)).strftime("%Y-%m-%d")
            key = f"fSub:{day}"
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
    def get_trending_feeds_detailed(cls, days=7, limit=50, min_subscribers=None):
        """
        Get trending feeds with full details including raw counts and weighted scores.

        Args:
            days: Number of days to aggregate (1, 7, or 30 recommended)
            limit: Maximum feeds to return (default 50)
            min_subscribers: Minimum to include (default: MIN_SUBSCRIBERS_THRESHOLD)

        Returns:
            List of dicts with feed_id, weighted_score, raw_subscriptions,
            subscriptions_today, avg_per_day
        """
        if min_subscribers is None:
            min_subscribers = cls.MIN_SUBSCRIBERS_THRESHOLD

        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        today = datetime.date.today().strftime("%Y-%m-%d")

        # Get weighted results
        trending = cls.get_trending_feeds(days=days, limit=limit, min_subscribers=min_subscribers)

        if not trending:
            return []

        feed_ids = [str(fid) for fid, _ in trending]
        weighted_scores = {str(fid): score for fid, score in trending}

        # Get today's counts
        pipe = r.pipeline()
        for fid in feed_ids:
            pipe.zscore(f"fSub:{today}", fid)
        today_counts = pipe.execute()
        today_map = {fid: int(c) if c else 0 for fid, c in zip(feed_ids, today_counts)}

        # Get raw totals
        raw_totals = {}
        for fid in feed_ids:
            raw_totals[fid] = cls.get_feed_subscription_count(int(fid), days=days)

        results = []
        for feed_id_str in feed_ids:
            feed_id = int(feed_id_str)
            raw = raw_totals.get(feed_id_str, 0)

            results.append(
                {
                    "feed_id": feed_id,
                    "weighted_score": weighted_scores.get(feed_id_str, 0),
                    "raw_subscriptions": raw,
                    "subscriptions_today": today_map.get(feed_id_str, 0),
                    "avg_per_day": raw / days if days > 0 else 0,
                }
            )

        return results

    @classmethod
    def get_daily_totals(cls, days=7):
        """
        Get total subscriptions per day for the past N days.

        Useful for charting subscription activity over time.

        Args:
            days: Number of days to retrieve

        Returns:
            List of (date_str, total_subscriptions) tuples, most recent first
        """
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)

        results = []
        for i in range(days):
            day = (datetime.date.today() - datetime.timedelta(days=i)).strftime("%Y-%m-%d")
            key = f"fSub:{day}"

            # Sum all scores in the sorted set for this day
            all_scores = r.zrange(key, 0, -1, withscores=True)
            total = sum(int(score) for _, score in all_scores)
            results.append((day, total))

        return results

    @classmethod
    def get_stats_for_prometheus(cls):
        """
        Get aggregate statistics for Prometheus metrics.

        Returns:
            Dict with total_subscriptions_today, unique_feeds_today
        """
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        today = datetime.date.today().strftime("%Y-%m-%d")
        key = f"fSub:{today}"

        all_subs = r.zrange(key, 0, -1, withscores=True)
        total_subscriptions = sum(int(score) for _, score in all_subs)
        unique_feeds = r.zcard(key)

        return {
            "total_subscriptions_today": total_subscriptions,
            "unique_feeds_today": unique_feeds,
        }
