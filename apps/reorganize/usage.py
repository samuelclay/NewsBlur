"""How often an account may ask for a reorganization proposal, and whether it may apply one.

Anyone may ask for a proposal and review it. Applying one needs Premium Archive or Premium Pro,
which apps/reorganize/apply.py enforces. An account without Premium Archive gets MONTHLY_RUNS runs
per calendar month in its own time zone. Premium Archive and Pro have no monthly limit, only a cap
of DAILY_RUNS runs in any 24 hours. A user has one run working at a time.

Runs are counted from the MReorganizeProposal documents by created_date. A run counts unless it
failed, so a failed run never uses up an allowance. Every date here is naive UTC, as the documents
store them.
"""

import datetime

import pytz
from pymongo import ReadPreference

from apps.reorganize.models import FAILED, WORKING, MReorganizeProposal

MONTHLY_RUNS = 1
DAILY_RUNS = 10
DAY = datetime.timedelta(hours=24)
# The task's time limit in apps/reorganize/tasks.py ends every run well before this, so a run still
# working after it was left behind by a worker that went away.
STALE_AFTER = datetime.timedelta(minutes=20)

# Refusals from can_start().
ALREADY_RUNNING = "already_running"  # another run for this user is still working
MONTHLY_LIMIT = "monthly_limit"  # an account without Premium Archive has had this month's run
DAILY_CAP = "daily_cap"  # Premium Archive or Pro has made DAILY_RUNS runs in the last 24 hours

# The error a stale run is failed with.
STALLED = "stalled"

# The windows limits() reports.
MONTH = "month"  # a calendar month in the user's time zone
ROLLING_DAY = "day"  # the 24 hours up to now


def clock():
    """Now, as naive UTC."""
    return datetime.datetime.utcnow()


def can_start(user):
    """Whether `user` may start a run now.

    Returns {"allowed": True}, or {"allowed": False, "code": one of the refusals above,
    "next_date": when the limit next lets a run through, or None}. A run left working longer than
    STALE_AFTER is failed first, so it neither blocks a new run nor counts.
    """
    now = clock()
    _fail_stale_runs(user.pk, now)
    if _is_running(user.pk):
        return {"allowed": False, "code": ALREADY_RUNNING, "next_date": None}
    window = _window(user, now)
    if window["remaining"] == 0:
        code = MONTHLY_LIMIT if window["period"] == MONTH else DAILY_CAP
        return {"allowed": False, "code": code, "next_date": window["next_date"]}
    return {"allowed": True}


def limits(user):
    """What the Organize sites dialog explains before the user starts a run.

    Returns {"can_apply": whether the user may apply a proposal, "period": MONTH or ROLLING_DAY,
    "limit": runs allowed in it, "remaining": runs left in it, "next_date", "running": whether a run
    is working}. For MONTH, next_date is when the month resets. For ROLLING_DAY it is when the next
    run counted now stops counting, or None if no run counts.
    """
    now = clock()
    _fail_stale_runs(user.pk, now)
    return {"can_apply": _has_archive(user), **_window(user, now), "running": _is_running(user.pk)}


def _window(user, now):
    if _has_archive(user):
        dates = _run_dates(user.pk, created_date__gt=now - DAY)
        next_date = dates[max(0, len(dates) - DAILY_RUNS)] + DAY if dates else None
        return {
            "period": ROLLING_DAY,
            "limit": DAILY_RUNS,
            "remaining": max(0, DAILY_RUNS - len(dates)),
            "next_date": next_date,
        }

    start, end = _calendar_month(user, now)
    dates = _run_dates(user.pk, created_date__gte=start, created_date__lt=end)
    return {
        "period": MONTH,
        "limit": MONTHLY_RUNS,
        "remaining": max(0, MONTHLY_RUNS - len(dates)),
        "next_date": end,
    }


def _has_archive(user):
    return bool(user.profile.is_archive or user.profile.is_pro)


def _run_dates(user_id, **date_range):
    """The created dates of the user's counted runs in `date_range`, oldest first."""
    return list(
        MReorganizeProposal.objects(user_id=user_id, status__ne=FAILED, **date_range)
        .read_preference(ReadPreference.PRIMARY)
        .order_by("created_date")
        .scalar("created_date")
    )


def _is_running(user_id):
    working = MReorganizeProposal.objects(user_id=user_id, status=WORKING)
    return working.read_preference(ReadPreference.PRIMARY).only("id").first() is not None


def _fail_stale_runs(user_id, now):
    MReorganizeProposal.objects(user_id=user_id, status=WORKING, created_date__lt=now - STALE_AFTER).update(
        set__status=FAILED, set__error=STALLED, set__updated_date=now
    )


def _calendar_month(user, now):
    """(start, end) of the calendar month `now` falls in, in the user's time zone."""
    zone = _time_zone(user)
    local = pytz.UTC.localize(now).astimezone(zone)
    first = datetime.datetime(local.year, local.month, 1)
    if local.month == 12:
        following = datetime.datetime(local.year + 1, 1, 1)
    else:
        following = datetime.datetime(local.year, local.month + 1, 1)
    return _naive_utc(zone.localize(first)), _naive_utc(zone.localize(following))


def _time_zone(user):
    """The user's time zone, read as apps/ask_ai/usage.py reads it, or UTC if it is unknown."""
    try:
        return pytz.timezone(str(user.profile.timezone or "UTC"))
    except pytz.UnknownTimeZoneError:
        return pytz.UTC


def _naive_utc(moment):
    return moment.astimezone(pytz.UTC).replace(tzinfo=None)
