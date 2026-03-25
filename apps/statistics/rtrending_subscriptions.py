import datetime

import redis
from django.conf import settings


class RTrendingSubscription:
    """
    Tracks feed subscription events to identify trending feeds by subscription velocity.

    Redis Key Structure:
    - fSub:{date} -> sorted set {feed_id: subscription_count}
    - fSub:total:{date} -> counter (total subscriptions for the day)

    All data is stored in date-partitioned sorted sets for efficient aggregation.
    All keys expire after 35 days (to support 30-day trending window).
    """

    TTL_DAYS = 35
    MIN_SUBSCRIBERS_THRESHOLD = 4

    # Decay weights for multi-day aggregation (today=1.0, progressively lower)
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
        """
        if not feed_id:
            return

        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        today = datetime.date.today().strftime("%Y-%m-%d")
        ttl_seconds = cls.TTL_DAYS * 24 * 60 * 60

        key = f"fSub:{today}"
        total_key = f"fSub:total:{today}"
        pipe = r.pipeline()
        pipe.zincrby(key, 1, str(feed_id))
        pipe.expire(key, ttl_seconds)
        pipe.incr(total_key)
        pipe.expire(total_key, ttl_seconds)
        pipe.execute()

    @classmethod
    def _get_decay_weights(cls, days):
        if days in cls.DECAY_WEIGHTS:
            return cls.DECAY_WEIGHTS[days]
        return [max(0.03, 1.0 - (i * 0.97 / max(days - 1, 1))) for i in range(days)]

    @classmethod
    def _get_top_weighted(cls, r, days, limit):
        """Get top items by reading each daily key and applying decay weights in Python.

        No ZUNIONSTORE — just pipelined ZREVRANGE reads.
        """
        weights = cls._get_decay_weights(days)
        fetch_limit = max(limit * 3, 100)

        pipe = r.pipeline()
        for i in range(min(days, len(weights))):
            day = (datetime.date.today() - datetime.timedelta(days=i)).strftime("%Y-%m-%d")
            pipe.zrevrange(f"fSub:{day}", 0, fetch_limit - 1, withscores=True)
        daily_results = pipe.execute()

        merged = {}
        for i, results in enumerate(daily_results):
            weight = weights[i]
            for member, score in results:
                key = member.decode() if isinstance(member, bytes) else member
                merged[key] = merged.get(key, 0) + score * weight

        sorted_results = sorted(merged.items(), key=lambda x: -x[1])
        return sorted_results[:limit]

    @classmethod
    def get_trending_feeds(cls, days=7, limit=50, min_subscribers=None):
        """
        Get feeds trending by subscription velocity.
        """
        if min_subscribers is None:
            min_subscribers = cls.MIN_SUBSCRIBERS_THRESHOLD

        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)

        if days == 1:
            today = datetime.date.today().strftime("%Y-%m-%d")
            results = r.zrevrange(f"fSub:{today}", 0, limit * 3, withscores=True)
            results = [(m.decode() if isinstance(m, bytes) else m, s) for m, s in results]
        else:
            results = cls._get_top_weighted(r, days, limit * 3)

        filtered = []
        for feed_id_str, score in results:
            if score >= min_subscribers:
                try:
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
        """
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)

        pipe = r.pipeline()
        for i in range(days):
            day = (datetime.date.today() - datetime.timedelta(days=i)).strftime("%Y-%m-%d")
            pipe.zscore(f"fSub:{day}", str(feed_id))

        total = 0
        for val in pipe.execute():
            if val:
                try:
                    total += int(val)
                except (ValueError, TypeError):
                    pass

        return total

    @classmethod
    def get_trending_feeds_detailed(cls, days=7, limit=50, min_subscribers=None):
        """
        Get trending feeds with full details. Batches all Redis lookups into
        a single pipeline instead of per-feed calls.
        """
        if min_subscribers is None:
            min_subscribers = cls.MIN_SUBSCRIBERS_THRESHOLD

        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        today = datetime.date.today().strftime("%Y-%m-%d")

        trending = cls.get_trending_feeds(days=days, limit=limit, min_subscribers=min_subscribers)

        if not trending:
            return []

        feed_ids = [str(fid) for fid, _ in trending]
        weighted_scores = {str(fid): score for fid, score in trending}

        # Batch all lookups into a single pipeline:
        # - today's counts for each feed
        # - raw totals (zscore per day per feed)
        pipe = r.pipeline()

        # Today's counts
        for fid in feed_ids:
            pipe.zscore(f"fSub:{today}", fid)

        # Raw totals: for each feed, get zscore for each of the N days
        day_keys = []
        for i in range(days):
            day = (datetime.date.today() - datetime.timedelta(days=i)).strftime("%Y-%m-%d")
            day_keys.append(f"fSub:{day}")

        for fid in feed_ids:
            for day_key in day_keys:
                pipe.zscore(day_key, fid)

        all_results = pipe.execute()

        # Parse today's counts (first len(feed_ids) results)
        today_map = {}
        for i, fid in enumerate(feed_ids):
            c = all_results[i]
            today_map[fid] = int(c) if c else 0

        # Parse raw totals (remaining results, grouped by feed then day)
        offset = len(feed_ids)
        raw_totals = {}
        for i, fid in enumerate(feed_ids):
            total = 0
            for j in range(days):
                val = all_results[offset + i * days + j]
                if val:
                    try:
                        total += int(val)
                    except (ValueError, TypeError):
                        pass
            raw_totals[fid] = total

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
        Get total subscriptions per day using running counters.
        Falls back to sorted set scan if counter doesn't exist yet.
        """
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)

        # Batch all lookups in a single pipeline
        pipe = r.pipeline()
        day_strs = []
        for i in range(days):
            day = (datetime.date.today() - datetime.timedelta(days=i)).strftime("%Y-%m-%d")
            day_strs.append(day)
            pipe.get(f"fSub:total:{day}")

        counter_values = pipe.execute()

        results = []
        # For days without a counter, fall back to sorted set scan
        fallback_days = []
        for i, (day, counter_val) in enumerate(zip(day_strs, counter_values)):
            if counter_val is not None:
                results.append((day, int(counter_val)))
            else:
                fallback_days.append((i, day))

        if fallback_days:
            pipe = r.pipeline()
            for _, day in fallback_days:
                pipe.zrange(f"fSub:{day}", 0, -1, withscores=True)
            fallback_results = pipe.execute()

            for (idx, day), scores in zip(fallback_days, fallback_results):
                total = sum(int(score) for _, score in scores)
                results.insert(idx, (day, total))

        return results

    @classmethod
    def get_stats_for_prometheus(cls):
        """
        Get aggregate statistics using running counter for total and ZCARD for unique feeds.
        """
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        today = datetime.date.today().strftime("%Y-%m-%d")

        pipe = r.pipeline()
        pipe.get(f"fSub:total:{today}")
        pipe.zcard(f"fSub:{today}")
        counter_val, unique_feeds = pipe.execute()

        if counter_val is not None:
            total_subscriptions = int(counter_val)
        else:
            # Fallback: sum sorted set scores if counter doesn't exist yet
            all_subs = r.zrange(f"fSub:{today}", 0, -1, withscores=True)
            total_subscriptions = sum(int(score) for _, score in all_subs)

        return {
            "total_subscriptions_today": total_subscriptions,
            "unique_feeds_today": unique_feeds,
        }
