"""
Redis-based discover feature usage tracking.

Provides fast aggregation for Prometheus metrics by maintaining
counters in Redis that are updated in real-time when discover
endpoints are called.

Key structure:
- discover:{date}:{type}:requests - daily request count
- discover:{date}:{type}:users - set of user IDs for the day
- discover:alltime:{type}:requests - cumulative request count (no expiry)
- discover:alltime:{type}:users - set of all user IDs ever (no expiry)

Keys expire after 60 days (except alltime keys).
"""

import datetime

import redis
from django.conf import settings


class RDiscoverUsage:
    KEY_PREFIX = "discover"
    KEY_EXPIRY_DAYS = 60
    TYPES = ["feeds", "stories"]

    @classmethod
    def _get_redis(cls):
        return redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)

    @classmethod
    def _date_key(cls, date=None):
        if date is None:
            date = datetime.date.today()
        return date.strftime("%Y-%m-%d")

    @classmethod
    def _expiry_timestamp(cls, date=None):
        if date is None:
            date = datetime.date.today()
        expiry = date + datetime.timedelta(days=cls.KEY_EXPIRY_DAYS)
        return int(expiry.strftime("%s"))

    @classmethod
    def record(cls, discover_type, user_id=None):
        """
        Record a discover request in Redis.

        Args:
            discover_type: "feeds" or "stories"
            user_id: Optional user ID for tracking unique users
        """
        r = cls._get_redis()
        date_key = cls._date_key()
        expiry = cls._expiry_timestamp()

        pipe = r.pipeline()

        # Daily request counter
        daily_key = f"{cls.KEY_PREFIX}:{date_key}:{discover_type}:requests"
        pipe.incr(daily_key)
        pipe.expireat(daily_key, expiry)

        # All-time counter (no expiry)
        alltime_key = f"{cls.KEY_PREFIX}:alltime:{discover_type}:requests"
        pipe.incr(alltime_key)

        # Track unique users per day and all-time
        if user_id:
            user_key = f"{cls.KEY_PREFIX}:{date_key}:{discover_type}:users"
            pipe.sadd(user_key, user_id)
            pipe.expireat(user_key, expiry)

            alltime_user_key = f"{cls.KEY_PREFIX}:alltime:{discover_type}:users"
            pipe.sadd(alltime_user_key, user_id)

        pipe.execute()

    @classmethod
    def get_period_stats(cls, days=1):
        """
        Get aggregated request counts for the last N days.

        Returns dict: {"feeds": {"requests": N}, "stories": {"requests": N}}
        """
        r = cls._get_redis()
        today = datetime.date.today()

        all_keys = []
        key_metadata = []

        for day_offset in range(days):
            date = today - datetime.timedelta(days=day_offset)
            date_key = cls._date_key(date)
            for discover_type in cls.TYPES:
                key = f"{cls.KEY_PREFIX}:{date_key}:{discover_type}:requests"
                all_keys.append(key)
                key_metadata.append(discover_type)

        values = r.mget(all_keys) if all_keys else []

        stats = {t: {"requests": 0} for t in cls.TYPES}
        for i, value in enumerate(values):
            if value is not None:
                stats[key_metadata[i]]["requests"] += int(value)

        return stats

    @classmethod
    def get_alltime_stats(cls):
        """
        Get all-time cumulative request counts.

        Returns dict: {"feeds": N, "stories": N}
        """
        r = cls._get_redis()
        keys = [f"{cls.KEY_PREFIX}:alltime:{t}:requests" for t in cls.TYPES]
        values = r.mget(keys)

        stats = {}
        for i, discover_type in enumerate(cls.TYPES):
            stats[discover_type] = int(values[i]) if values[i] is not None else 0

        return stats

    @classmethod
    def get_alltime_unique_users(cls, discover_type):
        """Get all-time unique user count from the persistent set."""
        r = cls._get_redis()
        return r.scard(f"{cls.KEY_PREFIX}:alltime:{discover_type}:users")

    @classmethod
    def get_unique_users_for_period(cls, discover_type, days=1):
        """
        Get unique user count for a period using set union.
        """
        r = cls._get_redis()
        today = datetime.date.today()

        if days == 1:
            key = f"{cls.KEY_PREFIX}:{cls._date_key()}:{discover_type}:users"
            return r.scard(key)

        keys = []
        for day_offset in range(days):
            date = today - datetime.timedelta(days=day_offset)
            keys.append(f"{cls.KEY_PREFIX}:{cls._date_key(date)}:{discover_type}:users")

        try:
            union_result = r.sunion(*keys)
            return len(union_result) if union_result else 0
        except Exception:
            return 0
