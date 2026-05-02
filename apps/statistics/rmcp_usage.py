"""
Redis-based MCP usage tracking.

The MCP server writes into its shared Redis database so OAuth state and usage
metrics stay available across MCP container restarts. The Django monitor reads
the same Redis database and exposes aggregate counts to Prometheus.

Key structure:
- mcp_usage:{date}:requests - daily MCP tool/resource invocation count
- mcp_usage:{date}:users - set of user IDs that used MCP that day
- mcp_usage:alltime:requests - cumulative invocation count
- mcp_usage:alltime:users - set of all user IDs that have used MCP

Daily keys expire after 60 days. All-time keys do not expire.
"""

import datetime

import redis
from django.conf import settings


class RMCPUsage:
    KEY_PREFIX = "mcp_usage"
    KEY_EXPIRY_DAYS = 60
    METRICS = ["requests", "unique_users"]

    @classmethod
    def _get_redis(cls):
        return redis.Redis(
            host=settings.REDIS_SESSIONS["host"],
            port=settings.REDIS_SESSION_PORT,
            db=settings.SESSION_REDIS_DB,
            decode_responses=True,
        )

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
    def record(cls, user_id=None):
        """Record a usage event using the same key contract as the MCP server."""
        r = cls._get_redis()
        date_key = cls._date_key()
        expiry = cls._expiry_timestamp()

        pipe = r.pipeline()

        daily_key = f"{cls.KEY_PREFIX}:{date_key}:requests"
        pipe.incr(daily_key)
        pipe.expireat(daily_key, expiry)

        pipe.incr(f"{cls.KEY_PREFIX}:alltime:requests")

        if user_id:
            user_id = str(user_id)
            users_key = f"{cls.KEY_PREFIX}:{date_key}:users"
            pipe.sadd(users_key, user_id)
            pipe.expireat(users_key, expiry)
            pipe.sadd(f"{cls.KEY_PREFIX}:alltime:users", user_id)

        pipe.execute()

    @classmethod
    def get_period_stats(cls, days=1):
        """Get request and unique-user counts for the last N days."""
        r = cls._get_redis()
        today = datetime.date.today()

        request_keys = []
        user_keys = []
        for day_offset in range(days):
            date = today - datetime.timedelta(days=day_offset)
            date_key = cls._date_key(date)
            request_keys.append(f"{cls.KEY_PREFIX}:{date_key}:requests")
            user_keys.append(f"{cls.KEY_PREFIX}:{date_key}:users")

        request_values = r.mget(request_keys) if request_keys else []
        requests = sum(int(value) for value in request_values if value is not None)

        if days == 1:
            unique_users = r.scard(user_keys[0]) if user_keys else 0
        else:
            users = r.sunion(*user_keys) if user_keys else set()
            unique_users = len(users) if users else 0

        return {
            "requests": requests,
            "unique_users": unique_users,
        }

    @classmethod
    def get_alltime_stats(cls):
        """Get cumulative request and unique-user counts."""
        r = cls._get_redis()
        requests = r.get(f"{cls.KEY_PREFIX}:alltime:requests")
        return {
            "requests": int(requests) if requests is not None else 0,
            "unique_users": r.scard(f"{cls.KEY_PREFIX}:alltime:users"),
        }
