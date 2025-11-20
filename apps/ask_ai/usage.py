import datetime

import pytz

from .models import MAskAIUsage


class AskAIUsageTracker:
    DAILY_LIMIT_PREMIUM = 3
    DAILY_LIMIT_ARCHIVE = 50
    WEEKLY_LIMIT_FREE = 3

    def __init__(self, user):
        self.user = user
        self.profile = user.profile

    # Public API -------------------------------------------------------------
    def can_use(self):
        if self._is_premium_tier:
            limit = self._daily_limit
            used = self._daily_count()
            if used >= limit:
                message = self._daily_limit_message(limit)
                return False, message
            return True, None

        # Free users have weekly limit
        weekly_usage = self._weekly_count()
        if weekly_usage >= self.WEEKLY_LIMIT_FREE:
            time_remaining = self._format_time_until_weekly_reset()
            return (
                False,
                f"You've used all {self.WEEKLY_LIMIT_FREE} free Ask AI requests this week. Your limit resets in {time_remaining}.\n\nUpgrade to Premium Archive for additional questions.",
            )
        return True, None

    def record_usage(self, question_id=None, story_hash=None, request_id=None, cached=False):
        entry = MAskAIUsage(
            user_id=self.user.pk,
            question_id=question_id or "",
            story_hash=story_hash or "",
            request_id=request_id or "",
            plan_tier=self._plan_tier,
            source="cache" if cached else "live",
        )
        entry.save()
        return entry

    def get_usage_message(self):
        if self._is_premium_tier:
            limit = self._daily_limit
            used = self._daily_count()
            remaining = max(0, limit - used)

            upgrade_message = ""
            show_message = True
            if self.profile.is_archive or self.profile.is_pro:
                show_message = remaining <= 3
            else:
                upgrade_message = "\n\nUpgrade to Premium Archive for 50 requests per day."

            if not show_message:
                return None

            time_remaining = self._format_time_until_reset()
            if remaining == 0:
                return (
                    f"You've used all {limit} Ask AI requests today. "
                    f"Your limit resets at midnight tonight, in {time_remaining}.{upgrade_message}"
                )
            return (
                f"You have {remaining} Ask AI request{'s' if remaining != 1 else ''} remaining today "
                f"(resets in {time_remaining}).{upgrade_message}"
            )

        # Free users have weekly limit
        weekly_usage = self._weekly_count()
        remaining = max(0, self.WEEKLY_LIMIT_FREE - weekly_usage)
        if remaining == 0:
            time_remaining = self._format_time_until_weekly_reset()
            return f"You've used all {self.WEEKLY_LIMIT_FREE} free Ask AI requests this week. Your limit resets in {time_remaining}.\n\nUpgrade to Premium Archive for additional questions."

        time_remaining = self._format_time_until_weekly_reset()
        return (
            f"You have {remaining} Ask AI request{'s' if remaining != 1 else ''} remaining this week "
            f"(resets in {time_remaining}).\n\n"
            "Upgrade to Premium Archive for additional questions."
        )

    @classmethod
    def get_usage_snapshot(cls):
        """Return daily (for premium) and weekly (for free) usage counts keyed by user ID."""
        collection = MAskAIUsage._get_collection()
        now = datetime.datetime.utcnow()
        last_day = now - datetime.timedelta(days=1)
        last_week = now - datetime.timedelta(days=7)

        # Daily counts for premium users
        daily_counts = {}
        for doc in collection.aggregate(
            [
                {"$match": {"created_at": {"$gte": last_day}}},
                {"$group": {"_id": "$user_id", "count": {"$sum": 1}}},
            ]
        ):
            daily_counts[doc["_id"]] = doc["count"]

        # Weekly counts for free users
        weekly_counts = {}
        for doc in collection.aggregate(
            [
                {"$match": {"created_at": {"$gte": last_week}}},
                {"$group": {"_id": "$user_id", "count": {"$sum": 1}}},
            ]
        ):
            weekly_counts[doc["_id"]] = doc["count"]

        return {"daily": daily_counts, "weekly": weekly_counts}

    # Internal helpers -------------------------------------------------------
    @property
    def _is_premium_tier(self):
        return self.profile.is_premium or self.profile.is_archive or self.profile.is_pro

    @property
    def _daily_limit(self):
        if self.profile.is_archive or self.profile.is_pro:
            return self.DAILY_LIMIT_ARCHIVE
        return self.DAILY_LIMIT_PREMIUM

    @property
    def _plan_tier(self):
        if self.profile.is_archive or self.profile.is_pro:
            return "archive"
        if self.profile.is_premium:
            return "premium"
        return "free"

    def _daily_window(self):
        tz_name = str(self.profile.timezone or "UTC")
        try:
            user_tz = pytz.timezone(tz_name)
        except pytz.UnknownTimeZoneError:
            user_tz = pytz.UTC

        now_local = datetime.datetime.now(pytz.UTC).astimezone(user_tz)
        start_local = now_local.replace(hour=0, minute=0, second=0, microsecond=0)
        end_local = start_local + datetime.timedelta(days=1)
        start_utc = start_local.astimezone(pytz.UTC).replace(tzinfo=None)
        end_utc = end_local.astimezone(pytz.UTC).replace(tzinfo=None)
        return start_utc, end_utc

    def _daily_count(self):
        start_utc, end_utc = self._daily_window()
        return MAskAIUsage.objects(
            user_id=self.user.pk, created_at__gte=start_utc, created_at__lt=end_utc
        ).count()

    def _weekly_window(self):
        """
        Calculate weekly window for free users.
        Resets Sunday night at midnight (Saturday night into Sunday morning) in user's timezone.
        Week runs from Sunday 00:00 to next Sunday 00:00.
        """
        tz_name = str(self.profile.timezone or "UTC")
        try:
            user_tz = pytz.timezone(tz_name)
        except pytz.UnknownTimeZoneError:
            user_tz = pytz.UTC

        now_local = datetime.datetime.now(pytz.UTC).astimezone(user_tz)

        # Find the most recent Sunday at midnight (start of week)
        # weekday(): Monday=0, Tuesday=1, ..., Saturday=5, Sunday=6
        days_since_sunday = (now_local.weekday() + 1) % 7  # 0 if Sunday, 1 if Monday, etc.

        if days_since_sunday == 0:
            # Today is Sunday - use today's midnight
            start_local = now_local.replace(hour=0, minute=0, second=0, microsecond=0)
        else:
            # Go back to most recent Sunday midnight
            start_local = (now_local - datetime.timedelta(days=days_since_sunday)).replace(
                hour=0, minute=0, second=0, microsecond=0
            )

        end_local = start_local + datetime.timedelta(days=7)
        start_utc = start_local.astimezone(pytz.UTC).replace(tzinfo=None)
        end_utc = end_local.astimezone(pytz.UTC).replace(tzinfo=None)
        return start_utc, end_utc

    def _weekly_count(self):
        """Count questions asked this week for free users."""
        start_utc, end_utc = self._weekly_window()
        return MAskAIUsage.objects(
            user_id=self.user.pk, created_at__gte=start_utc, created_at__lt=end_utc
        ).count()

    def _lifetime_count(self):
        """Lifetime count - kept for analytics purposes only."""
        return MAskAIUsage.objects(user_id=self.user.pk).count()

    def _format_time_until_reset(self):
        """Format time until daily reset for premium users."""
        tz_name = str(self.profile.timezone or "UTC")
        try:
            user_tz = pytz.timezone(tz_name)
        except pytz.UnknownTimeZoneError:
            user_tz = pytz.UTC

        now_local = datetime.datetime.now(pytz.UTC).astimezone(user_tz)
        midnight = (now_local + datetime.timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
        remaining = midnight - now_local
        return self._format_time_delta(remaining)

    def _format_time_until_weekly_reset(self):
        """Format time until weekly reset for free users (Sunday night at midnight)."""
        tz_name = str(self.profile.timezone or "UTC")
        try:
            user_tz = pytz.timezone(tz_name)
        except pytz.UnknownTimeZoneError:
            user_tz = pytz.UTC

        now_local = datetime.datetime.now(pytz.UTC).astimezone(user_tz)

        # Find next Sunday at midnight (Saturday night into Sunday)
        # weekday(): Monday=0, Tuesday=1, ..., Saturday=5, Sunday=6
        days_until_sunday = (6 - now_local.weekday()) % 7  # Days until next Saturday
        if days_until_sunday == 0 and now_local.weekday() == 6:
            # Today is Sunday - next reset is in 7 days
            days_until_sunday = 7
        else:
            # Add 1 to get to Sunday midnight
            days_until_sunday += 1

        next_sunday = (now_local + datetime.timedelta(days=days_until_sunday)).replace(
            hour=0, minute=0, second=0, microsecond=0
        )
        remaining = next_sunday - now_local
        return self._format_time_delta(remaining)

    def _format_time_delta(self, time_delta):
        """
        Format a timedelta into human-readable string.
        Shows only the largest unit: days, hours, or minutes.
        """
        total_seconds = time_delta.total_seconds()

        # Days
        if total_seconds >= 86400:  # 24 hours
            days = int(total_seconds / 86400)
            return f"{days} day{'s' if days != 1 else ''}"

        # Hours
        if total_seconds >= 3600:  # 1 hour
            hours = int(total_seconds / 3600)
            return f"{hours} hour{'s' if hours != 1 else ''}"

        # Minutes
        minutes = max(1, int(total_seconds / 60))
        return f"{minutes} minute{'s' if minutes != 1 else ''}"

    def _daily_limit_message(self, limit):
        time_remaining = self._format_time_until_reset()
        if self.profile.is_archive or self.profile.is_pro:
            return (
                f"You've reached your daily limit of {limit} Ask AI requests. "
                f"Your limit resets at midnight tonight, in {time_remaining}."
            )
        return (
            f"You've reached your daily limit of {limit} Ask AI requests. "
            f"Your limit resets at midnight tonight, in {time_remaining}.\n\n"
            "Upgrade to Premium Archive for 50 requests per day."
        )
