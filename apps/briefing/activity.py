import datetime

import pytz
import redis
from django.conf import settings

from utils import log as logging


class RUserActivity:
    """
    Track hourly user activity patterns for briefing scheduling.

    Redis Key Structure:
    - "uAct:{user_id}" -> hash {hour_0..hour_23: count}
      Incremented each time user is seen active in that hour (user's local timezone).
      Used to compute "typical reading time" = hour with highest count.

    Updated from the existing LastSeenMiddleware (hourly throttle already exists).
    """

    REDIS_KEY_PREFIX = "uAct"
    MIN_DATA_POINTS = 7  # Minimum activity records before auto-detection kicks in
    DEFAULT_HOUR = 7  # 7:00 AM default if insufficient data

    @classmethod
    def record_activity(cls, user_id, timezone_str):
        """
        Record that user was active now. Convert UTC to user's local hour.

        Called from LastSeenMiddleware alongside the existing last_seen_on update,
        so it runs at most once per hour per user.
        """
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)

        try:
            tz = pytz.timezone(str(timezone_str))
        except (pytz.UnknownTimeZoneError, AttributeError):
            tz = pytz.timezone("America/New_York")

        local_now = datetime.datetime.now(tz)
        local_hour = local_now.hour

        key = "%s:%s" % (cls.REDIS_KEY_PREFIX, user_id)
        r.hincrby(key, "hour_%s" % local_hour, 1)
        # apps/briefing/activity.py: No TTL — activity data accumulates indefinitely

    @classmethod
    def get_activity_histogram(cls, user_id):
        """
        Return a dict of {hour: count} for the user's activity pattern.
        Hours are in the user's local timezone.
        """
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        key = "%s:%s" % (cls.REDIS_KEY_PREFIX, user_id)
        data = r.hgetall(key)

        histogram = {}
        for field, count in data.items():
            field_str = field.decode() if isinstance(field, bytes) else field
            if field_str.startswith("hour_"):
                try:
                    hour = int(field_str.split("_")[1])
                    histogram[hour] = int(count)
                except (ValueError, IndexError):
                    pass

        return histogram

    @classmethod
    def get_typical_reading_hour(cls, user_id):
        """
        Return the hour (0-23) when user most often reads.
        Returns None if insufficient data (< MIN_DATA_POINTS total records).
        """
        histogram = cls.get_activity_histogram(user_id)
        if not histogram:
            return None

        total_points = sum(histogram.values())
        if total_points < cls.MIN_DATA_POINTS:
            return None

        return max(histogram, key=histogram.get)

    @classmethod
    def get_briefing_generation_time(cls, user_id, timezone_str):
        """
        Compute the next briefing generation time for this user.

        Returns a datetime in UTC representing when the briefing should be generated
        (30 minutes before their typical reading time).

        Falls back to DEFAULT_HOUR (7:00 AM) if insufficient activity data.
        """
        try:
            tz = pytz.timezone(str(timezone_str))
        except (pytz.UnknownTimeZoneError, AttributeError):
            tz = pytz.timezone("America/New_York")

        typical_hour = cls.get_typical_reading_hour(user_id)
        if typical_hour is None:
            typical_hour = cls.DEFAULT_HOUR

        # apps/briefing/activity.py: Target generation time is 30 min before typical reading
        today = datetime.datetime.now(tz).date()
        local_target = tz.localize(datetime.datetime.combine(today, datetime.time(typical_hour, 0)))
        generation_time = local_target - datetime.timedelta(minutes=30)

        # apps/briefing/activity.py: Convert to UTC
        utc_time = generation_time.astimezone(pytz.utc).replace(tzinfo=None)

        return utc_time
