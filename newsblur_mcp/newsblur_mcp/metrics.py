"""Redis-backed MCP usage counters."""

import datetime

import redis

from newsblur_mcp.settings import MCP_REDIS_URL

KEY_PREFIX = "mcp_usage"
KEY_EXPIRY_DAYS = 60

_redis_client = None


def _get_redis():
    global _redis_client
    if _redis_client is None:
        _redis_client = redis.Redis.from_url(MCP_REDIS_URL, decode_responses=True)
    return _redis_client


def _date_key(date=None):
    if date is None:
        date = datetime.date.today()
    return date.strftime("%Y-%m-%d")


def _expiry_timestamp(date=None):
    if date is None:
        date = datetime.date.today()
    expiry = date + datetime.timedelta(days=KEY_EXPIRY_DAYS)
    return int(expiry.strftime("%s"))


def record_mcp_usage(user_id=None):
    """Record one MCP tool or resource invocation."""
    r = _get_redis()
    date_key = _date_key()
    expiry = _expiry_timestamp()

    pipe = r.pipeline()

    daily_key = f"{KEY_PREFIX}:{date_key}:requests"
    pipe.incr(daily_key)
    pipe.expireat(daily_key, expiry)

    alltime_key = f"{KEY_PREFIX}:alltime:requests"
    pipe.incr(alltime_key)

    if user_id:
        user_id = str(user_id)

        daily_users_key = f"{KEY_PREFIX}:{date_key}:users"
        pipe.sadd(daily_users_key, user_id)
        pipe.expireat(daily_users_key, expiry)

        alltime_users_key = f"{KEY_PREFIX}:alltime:users"
        pipe.sadd(alltime_users_key, user_id)

    pipe.execute()
