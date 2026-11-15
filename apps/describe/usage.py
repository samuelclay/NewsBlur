"""apps/describe/usage.py: daily quota for Describe searches, per plan tier.

Mirrors the shape of apps/ask_ai/usage.py: the window is midnight to midnight
in the user's timezone, and every started search records a row in
MDescribeUsage. Replaying a cached search never records usage.
"""

import datetime

import pytz
from django.utils.translation import gettext, ngettext

from apps.describe.models import MDescribeUsage

TIER_FREE = "free"
TIER_PREMIUM = "premium"
TIER_ARCHIVE = "archive"
TIER_PRO = "pro"


class DescribeUsageTracker:
    # apps/describe/usage.py: searches per day by tier. None would mean unlimited; no tier is, since
    # every search spends real API calls. Pro's limit is a ceiling against runaway use, not a plan feature.
    DAILY_LIMITS = {
        TIER_FREE: 0,
        TIER_PREMIUM: 10,
        TIER_ARCHIVE: 30,
        TIER_PRO: 100,
    }

    def __init__(self, user):
        self.user = user
        self.profile = user.profile

    # Public API -------------------------------------------------------------

    def can_use(self):
        """Return (allowed, message). The message explains a denial to the user."""
        limit = self.daily_limit
        if limit is None:
            return True, None
        if limit == 0:
            return False, gettext(
                "Describing the feeds you want is a premium feature. " "Upgrade to search by description."
            )
        used = self.daily_count()
        if used >= limit:
            return False, self._daily_limit_message(limit)
        return True, None

    def record_usage(self, search_id=None, request_id=None):
        entry = MDescribeUsage(
            user_id=self.user.pk,
            search_id=str(search_id or ""),
            request_id=request_id or "",
            plan_tier=self.plan_tier,
        )
        entry.save()
        return entry

    def record_denied(self, search_id=None, request_id=None):
        entry = MDescribeUsage(
            user_id=self.user.pk,
            search_id=str(search_id or ""),
            request_id=request_id or "",
            plan_tier=self.plan_tier,
            over_quota=True,
        )
        entry.save()
        return entry

    def snapshot(self):
        """What the clients show next to the search box."""
        limit = self.daily_limit
        used = self.daily_count() if limit else 0
        remaining = None if limit is None else max(0, limit - used)
        return {
            "tier": self.plan_tier,
            "limit": limit,
            "used": used,
            "remaining": remaining,
            "resets_in": self._format_time_until_reset() if limit else None,
        }

    def get_usage_message(self):
        """A short note after a search finishes, only when searches are running low."""
        limit = self.daily_limit
        if not limit:
            return None
        remaining = max(0, limit - self.daily_count())
        if remaining > 3:
            return None
        time_remaining = self._format_time_until_reset()
        if remaining == 0:
            return gettext(
                "You've used all %(limit)s Describe searches today. Your limit resets in %(time)s."
            ) % {"limit": limit, "time": time_remaining}
        return ngettext(
            "You have %(count)s Describe search left today (resets in %(time)s).",
            "You have %(count)s Describe searches left today (resets in %(time)s).",
            remaining,
        ) % {"count": remaining, "time": time_remaining}

    # Tiers and windows ------------------------------------------------------

    @property
    def plan_tier(self):
        if self.profile.is_pro:
            return TIER_PRO
        if self.profile.is_archive:
            return TIER_ARCHIVE
        if self.profile.is_premium:
            return TIER_PREMIUM
        return TIER_FREE

    @property
    def daily_limit(self):
        return self.DAILY_LIMITS[self.plan_tier]

    def daily_count(self):
        start_utc, end_utc = self._daily_window()
        return MDescribeUsage.objects(
            user_id=self.user.pk, created_at__gte=start_utc, created_at__lt=end_utc, over_quota=False
        ).count()

    def _user_timezone(self):
        tz_name = str(self.profile.timezone or "UTC")
        try:
            return pytz.timezone(tz_name)
        except pytz.UnknownTimeZoneError:
            return pytz.UTC

    def _daily_window(self):
        user_tz = self._user_timezone()
        now_local = datetime.datetime.now(pytz.UTC).astimezone(user_tz)
        start_local = now_local.replace(hour=0, minute=0, second=0, microsecond=0)
        end_local = start_local + datetime.timedelta(days=1)
        start_utc = start_local.astimezone(pytz.UTC).replace(tzinfo=None)
        end_utc = end_local.astimezone(pytz.UTC).replace(tzinfo=None)
        return start_utc, end_utc

    def _format_time_until_reset(self):
        user_tz = self._user_timezone()
        now_local = datetime.datetime.now(pytz.UTC).astimezone(user_tz)
        midnight = (now_local + datetime.timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
        total_seconds = (midnight - now_local).total_seconds()
        if total_seconds >= 3600:
            hours = int(total_seconds / 3600)
            return ngettext("%(count)s hour", "%(count)s hours", hours) % {"count": hours}
        minutes = max(1, int(total_seconds / 60))
        return ngettext("%(count)s minute", "%(count)s minutes", minutes) % {"count": minutes}

    def _daily_limit_message(self, limit):
        return gettext(
            "You've used all %(limit)s Describe searches today. Your limit resets in %(time)s."
        ) % {"limit": limit, "time": self._format_time_until_reset()}
