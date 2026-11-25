"""Listen limits by plan (apps/listen/usage.py).

Premium Pro, Premium Archive Extra and Premium Archive users get full stories up to a weekly cap of estimated
audio time, counting only audio generated fresh for them (cached segments are free). Weeks start on Sunday at
midnight in the account's timezone. Everyone else gets a 60 second sample of any story, with a daily budget of
fresh preview audio so sampling story after story, or rebuilding one with other voices, can't generate without
end. Voice previews have a separate daily allowance.

Staff can reset an account's usage (reset_usage). That records a "reset" row, and every counter here only
counts usage after the latest one, so the original rows stay as they were.
"""

import datetime

import pytz
from django.utils import formats
from django.utils.translation import gettext, ngettext

from utils import log as logging

from .models import MListenUsage

PRO_WEEKLY_SECONDS = 10 * 60 * 60
ARCHIVE_EXTRA_WEEKLY_SECONDS = 2 * 60 * 60
ARCHIVE_WEEKLY_SECONDS = 1 * 60 * 60
WEEKLY_SECONDS = {
    "pro": PRO_WEEKLY_SECONDS,
    "archive_extra": ARCHIVE_EXTRA_WEEKLY_SECONDS,
    "archive": ARCHIVE_WEEKLY_SECONDS,
}
# Python's weekday() counts Monday as 0; Listen's week starts on Sunday (6).
WEEK_START_WEEKDAY = 6
SAMPLE_SECONDS = 60
# Fresh preview audio a non-Archive user can cause in a day. Samples of audio already cached by other listeners
# are free, so this only stops one account from generating new audio story after story.
SAMPLE_FRESH_SECONDS_PER_DAY = 10 * 60
PREVIEWS_PER_DAY = 25
ARCHIVE_PREVIEWS_PER_DAY = 200


class ListenUsageTracker:
    def __init__(self, user):
        self.user = user
        self.profile = user.profile

    # Plan ---------------------------------------------------------------------
    @property
    def tier(self):
        if self.profile.is_pro:
            return "pro"
        if self.profile.is_archive and self.profile.is_archive_extra:
            return "archive_extra"
        if self.profile.is_archive:
            return "archive"
        if self.profile.is_premium:
            return "premium"
        return "free"

    @property
    def is_archive_tier(self):
        return self.tier in WEEKLY_SECONDS

    @property
    def weekly_limit(self):
        return WEEKLY_SECONDS.get(self.tier)

    @property
    def previews_limit(self):
        return ARCHIVE_PREVIEWS_PER_DAY if self.is_archive_tier else PREVIEWS_PER_DAY

    # Windows ------------------------------------------------------------------
    def _user_timezone(self):
        try:
            return pytz.timezone(str(self.profile.timezone or "UTC"))
        except pytz.UnknownTimeZoneError:
            return pytz.UTC

    def _local_now(self, now=None):
        return (now or datetime.datetime.now(pytz.UTC)).astimezone(self._user_timezone())

    def _local_midnight(self, date):
        """Midnight of `date` in the user's timezone, with that night's UTC offset (it may differ across DST)."""
        return self._user_timezone().localize(datetime.datetime(date.year, date.month, date.day))

    def _to_utc(self, local):
        return local.astimezone(pytz.UTC).replace(tzinfo=None)

    def day_window(self, now=None):
        today = self._local_now(now).date()
        start = self._local_midnight(today)
        end = self._local_midnight(today + datetime.timedelta(days=1))
        return self._to_utc(start), self._to_utc(end)

    def week_window(self, now=None):
        """(start_utc, end_utc, reset_local): the week containing `now`, Sunday to Sunday at the user's midnight."""
        today = self._local_now(now).date()
        days_since_sunday = (today.weekday() - WEEK_START_WEEKDAY) % 7
        sunday = today - datetime.timedelta(days=days_since_sunday)
        start = self._local_midnight(sunday)
        end = self._local_midnight(sunday + datetime.timedelta(days=7))
        return self._to_utc(start), self._to_utc(end), end

    # Resets -------------------------------------------------------------------
    def last_reset(self):
        return MListenUsage.objects(user_id=self.user.pk, kind="reset").order_by("-created_at").first()

    def _since_reset(self, start):
        """A window's start, moved up to the latest staff reset if that came later."""
        reset = self.last_reset()
        if reset and reset.created_at > start:
            return reset.created_at
        return start

    def reset_usage(self, staff_user=None):
        """Start this account's weekly cap and daily allowances over from now. The usage rows themselves are
        kept; the "reset" row marks where counting starts again (apps/listen/views.py listen_reset_usage)."""
        MListenUsage(user_id=self.user.pk, kind="reset", reason="manual", plan_tier=self.tier).save()
        logging.user(
            self.user,
            "~FMListen usage reset manually%s" % (" by ~SB%s~SN" % staff_user.username if staff_user else ""),
        )

    # Counters -----------------------------------------------------------------
    def seconds_used(self):
        start, end, _ = self.week_window()
        start = self._since_reset(start)
        result = MListenUsage._get_collection().aggregate(
            [
                {
                    "$match": {
                        "user_id": self.user.pk,
                        "kind": "segment",
                        "cached": False,
                        "created_at": {"$gte": start, "$lt": end},
                    }
                },
                {"$group": {"_id": None, "seconds": {"$sum": "$seconds"}}},
            ]
        )
        for row in result:
            return int(row["seconds"])
        return 0

    def sampled_story_hashes(self):
        start, end = self.day_window()
        start = self._since_reset(start)
        return set(
            MListenUsage.objects(
                user_id=self.user.pk,
                kind="segment",
                is_sample=True,
                created_at__gte=start,
                created_at__lt=end,
            ).distinct("story_hash")
        )

    def fresh_sample_seconds(self):
        """Preview audio generated fresh for this user today, whatever story or voice it was for."""
        start, end = self.day_window()
        start = self._since_reset(start)
        result = MListenUsage._get_collection().aggregate(
            [
                {
                    "$match": {
                        "user_id": self.user.pk,
                        "kind": "segment",
                        "is_sample": True,
                        "cached": False,
                        "created_at": {"$gte": start, "$lt": end},
                    }
                },
                {"$group": {"_id": None, "seconds": {"$sum": "$seconds"}}},
            ]
        )
        for row in result:
            return row["seconds"]
        return 0

    def previews_used(self):
        start, end = self.day_window()
        start = self._since_reset(start)
        return MListenUsage.objects(
            user_id=self.user.pk, kind="preview", created_at__gte=start, created_at__lt=end
        ).count()

    # Checks -------------------------------------------------------------------
    def check_story(self, story_hash):
        """(allowed, reason, message) for starting to listen to a story.

        Anyone can open any story: everyone else gets its first SAMPLE_SECONDS. The weekly cap and the daily
        budget of fresh sample audio only limit audio that has to be generated, so check_segment() enforces
        them on each uncached segment and cached audio keeps playing past them.
        """
        return True, None, None

    def check_segment(self, story_hash, cached):
        """(allowed, reason, message) for one segment. Checked here rather than when the manifest was made,
        because manifests can be made for many stories before any of them is played."""
        if cached:
            return True, None, None
        if self.is_archive_tier:
            if self.seconds_used() >= self.weekly_limit:
                return False, "cap_reached", self.cap_message()
            return True, None, None
        if self.fresh_sample_seconds() >= SAMPLE_FRESH_SECONDS_PER_DAY:
            return False, "sample_limit", self.sample_limit_message()
        return True, None, None

    def check_preview(self):
        if self.previews_used() >= self.previews_limit:
            return (
                False,
                "preview_limit",
                gettext("You've played all your voice previews for today. They reset at midnight."),
            )
        return True, None, None

    # Recording ----------------------------------------------------------------
    def record_segment(self, manifest, segment, cached):
        return MListenUsage(
            user_id=self.user.pk,
            kind="segment",
            story_hash=manifest["story_hash"],
            manifest_id=manifest["manifest_id"],
            segment_index=segment["index"],
            characters=len(segment["text"]),
            seconds=segment["duration"],
            cached=cached,
            is_sample=not self.is_archive_tier,
            plan_tier=self.tier,
            voice_id=manifest["voice_id"],
            model=manifest["model"],
            language=manifest["language"],
        ).save()

    def record_denied(self, reason, story_hash=None, manifest_id=None, segment_index=None):
        """A refused request, so the usage dashboard can count limits reached (apps/monitor/views/newsblur_listen.py)."""
        return MListenUsage(
            user_id=self.user.pk,
            kind="denied",
            reason=reason,
            story_hash=story_hash or "",
            manifest_id=manifest_id or "",
            segment_index=segment_index,
            plan_tier=self.tier,
        ).save()

    def record_preview(self, story_hash, voice_id, model, language, text, seconds, cached):
        return MListenUsage(
            user_id=self.user.pk,
            kind="preview",
            story_hash=story_hash or "",
            characters=len(text),
            seconds=seconds,
            cached=cached,
            plan_tier=self.tier,
            voice_id=voice_id,
            model=model,
            language=language,
        ).save()

    # Messages -----------------------------------------------------------------
    def format_duration(self, seconds):
        """ "30 minutes", "1 hour", "1 hour 30 minutes": whole hours and minutes, dropping a zero part."""
        hours, remainder = divmod(int(seconds), 3600)
        minutes = remainder // 60
        parts = []
        if hours:
            parts.append(ngettext("%(count)d hour", "%(count)d hours", hours) % {"count": hours})
        if minutes or not hours:
            parts.append(ngettext("%(count)d minute", "%(count)d minutes", minutes) % {"count": minutes})
        return " ".join(parts)

    def _reset_day(self):
        """The weekday the allowance comes back, e.g. "Sunday", in the user's language."""
        _, _, reset_local = self.week_window()
        return formats.date_format(reset_local.date(), "l")

    def cap_message(self):
        if self.tier == "pro":
            return gettext(
                "You've listened to %(limit)s of stories this week. Listening resets on %(day)s."
            ) % {
                "limit": self.format_duration(PRO_WEEKLY_SECONDS),
                "day": self._reset_day(),
            }
        if self.tier == "archive":
            return gettext(
                "You've listened to %(limit)s of stories this week. Listening resets on %(day)s, "
                "or switch to Premium Archive Extra for %(extra_limit)s a week."
            ) % {
                "limit": self.format_duration(ARCHIVE_WEEKLY_SECONDS),
                "day": self._reset_day(),
                "extra_limit": self.format_duration(ARCHIVE_EXTRA_WEEKLY_SECONDS),
            }
        return gettext(
            "You've listened to %(limit)s of stories this week. Listening resets on %(day)s, "
            "or upgrade to Premium Pro for %(pro_limit)s a week."
        ) % {
            "limit": self.format_duration(ARCHIVE_EXTRA_WEEKLY_SECONDS),
            "day": self._reset_day(),
            "pro_limit": self.format_duration(PRO_WEEKLY_SECONDS),
        }

    def sample_limit_message(self):
        return gettext(
            "You've played all of today's story previews. They come back at midnight, "
            "or upgrade to Premium Archive to listen to full stories."
        )

    def upgrade_message(self):
        if self.is_archive_tier:
            return None
        return gettext("Premium Archive unlocks full stories read aloud, up to %(limit)s a week.") % {
            "limit": self.format_duration(ARCHIVE_WEEKLY_SECONDS)
        }

    # Snapshot -----------------------------------------------------------------
    def snapshot(self):
        limit = self.weekly_limit
        used = self.seconds_used() if limit else 0
        _, _, reset_local = self.week_window()
        samples_used = 0 if self.is_archive_tier else len(self.sampled_story_hashes())
        last_reset = self.last_reset()
        return {
            "tier": self.tier,
            "is_archive_tier": self.is_archive_tier,
            "seconds_used": used,
            "seconds_limit": limit,
            "seconds_remaining": max(0, limit - used) if limit else None,
            # The allowance window. Clients word the footer ("left this week") and the reset day from these.
            "period": "week" if limit else None,
            "resets_at": reset_local.isoformat() if limit else None,
            "samples_used": samples_used,
            # Previews have no story limit any more. Older apps show "N story previews left" only when this is
            # a number, so it stays in the payload as null.
            "samples_limit": None,
            "preview_seconds": None if self.is_archive_tier else SAMPLE_SECONDS,
            "previews_used": self.previews_used(),
            "previews_limit": self.previews_limit,
            "upgrade_message": self.upgrade_message(),
            "last_reset_at": last_reset.created_at.isoformat() if last_reset else None,
        }
