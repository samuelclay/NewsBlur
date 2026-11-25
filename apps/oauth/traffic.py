import logging
import time

import redis
from django.conf import settings

logger = logging.getLogger(__name__)
REQUESTS_KEY = "oauth:application:requests"
LAST_USED_KEY = "oauth:application:last_used"


def readers_key(application_id, utc_day):
    return f"{REQUESTS_KEY}:readers:{application_id}:{utc_day}"


def recorded_application_ids():
    connection = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
    return [int(app_id) for app_id in connection.hkeys(REQUESTS_KEY)]


def record_request(application_id, user_id):
    try:
        pipe = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL).pipeline()
        pipe.hincrby(REQUESTS_KEY, application_id, 1)
        now = int(time.time())
        pipe.hset(LAST_USED_KEY, application_id, now)
        if user_id:
            day = now // 86400
            key = readers_key(application_id, day)
            pipe.pfadd(key, user_id)
            pipe.expireat(key, (day + 8) * 86400)
        pipe.execute()
    except redis.RedisError:
        logger.warning("Could not count an authenticated OAuth request", exc_info=True)


def application_usage(application_ids):
    if not application_ids:
        return {}
    pipe = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL).pipeline(transaction=False)
    pipe.hmget(REQUESTS_KEY, application_ids)
    pipe.hmget(LAST_USED_KEY, application_ids)
    day = int(time.time()) // 86400
    for pk in application_ids:
        pipe.pfcount(*(readers_key(pk, day - offset) for offset in range(7)))
    counts, last_used, *readers = pipe.execute()
    return {
        pk: {"requests": int(count or 0), "last_used": int(last) if last else None, "readers": reader_count}
        for pk, count, last, reader_count in zip(application_ids, counts, last_used, readers)
    }
