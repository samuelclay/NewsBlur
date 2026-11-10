"""RedListen (api.redlisten.com) client and monthly budget for Reddit data.

Reddit blocked NewsBlur's API client in October 2026 and retires its RSS feeds on
13 Nov 2026, so Reddit feeds now come from RedListen, a third-party Reddit data API
that answers Reddit's own listing JSON on Reddit's paths (/r/a+b/new.json,
/comments/<id>.json, /search.json, /user/<name>/submitted.json).

RedListen meters two quotas per account per UTC calendar month: requests, and
results (every post or comment a response returns). The Pro plan is 50,000 requests
and 1,000,000 results, and running out turns every endpoint into a 429 until the
month rolls over. So every call goes through RedListenBudget:

  * Automatic fetching may spend 99% of each quota (settings.REDLISTEN_BACKGROUND_SHARE).
    That is the hourly poller in utils/redlisten_poller.py (POLLER) and the per-feed
    comment-thread and search fetches the feed scheduler runs (SCHEDULED).
  * One-off fetches a reader asks for (insta-fetch, refresh, retry, a brand-new
    feed) may spend the last 1% too (ONE_OFF).

Usage lives in Redis (settings.REDIS_FEED_UPDATE_POOL) so every web and task server
shares it. A request reserves one request and the most results it can return before
it is sent, then trues up against what came back. RedListen's x-quota-used and
x-items-used headers, which count every key on the account, are kept alongside as the
highest values seen, and usage is whichever is higher. Running out
of budget is expected backpressure, so it is reported on the result, never raised.
See utils/redlisten.py.
"""

import datetime
import time
import uuid

import redis
import requests
from django.conf import settings

from utils import log as logging

BASE_URL = "https://api.redlisten.com"
USER_AGENT = "NewsBlur/1.0 (+https://www.newsblur.com)"

# Who is spending: the hourly poller, a scheduled per-feed fetch, or a reader's one-off.
POLLER = "poller"
SCHEDULED = "scheduled"
ONE_OFF = "one_off"
SPEND_KINDS = (POLLER, SCHEDULED, ONE_OFF)
BACKGROUND_KINDS = (POLLER, SCHEDULED)

# Redis keys (settings.REDIS_FEED_UPDATE_POOL, db 4).
USAGE_KEY = "redlisten:usage:%s"  # hash per UTC month (YYYYMM): our reservations, and the plan limits
OBSERVED_KEY = "redlisten:observed:%s"  # sorted set per UTC month: RedListen's own counters, highest seen
PENDING_KEY = "redlisten:pending:%s"  # sorted set per UTC month: reservations not yet settled, by start time
SPEND_KEY = "redlisten:spend:%s"  # hash per UTC day (YYYYMMDD): <kind>_requests, <kind>_items
RATE_LIMIT_KEY = "redlisten:ratelimit"  # fixed one-minute window shared by every server
USAGE_TTL = 60 * 60 * 24 * 40
# A reservation still pending after this long belongs to a worker that died mid-request
# (requests time out after 30 seconds), so it stops counting.
PENDING_SECONDS = 5 * 60
SPEND_TTL = 60 * 60 * 24 * 40

# Why a request was not sent. See RedListenResult.denied.
DENIED_BUDGET = "budget"
DENIED_RATE_LIMIT = "rate_limit"
DENIED_NOT_CONFIGURED = "not_configured"


def utcnow():
    return datetime.datetime.utcnow()


def month_end(now):
    """First instant of the next UTC month, when RedListen's quotas reset."""
    if now.month == 12:
        return datetime.datetime(now.year + 1, 1, 1)
    return datetime.datetime(now.year, now.month + 1, 1)


def int_header(headers, name):
    """Read a numeric RedListen header, or None when it is missing or "unlimited"."""
    value = (headers or {}).get(name)
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def count_results(payload):
    """Count the posts and comments in a response the way RedListen bills them: each
    record is one result, including comment replies nested inside a thread."""
    if isinstance(payload, list):
        return sum(count_results(part) for part in payload)
    if not isinstance(payload, dict):
        return 0
    data = payload.get("data")
    if not isinstance(data, dict):
        return 0
    total = 0
    for child in data.get("children") or []:
        if child.get("kind") not in ("t1", "t3"):
            continue
        total += 1
        replies = (child.get("data") or {}).get("replies")
        if isinstance(replies, dict):
            total += count_results(replies)
    return total


class RedListenResult:
    """What one RedListen call produced. denied is set when no request was sent."""

    def __init__(self, status=None, payload=None, results=0, denied=None, error_code=None):
        self.status = status
        self.payload = payload
        self.results = results
        self.denied = denied
        self.error_code = error_code

    @property
    def ok(self):
        return self.status == 200 and self.payload is not None

    @property
    def throttled(self):
        """True for budget or rate-limit backpressure, ours or RedListen's."""
        return self.denied in (DENIED_BUDGET, DENIED_RATE_LIMIT) or self.status == 429


class Reservation:
    """A claim on the budget: the billing month it was made in, and its pending entry."""

    def __init__(self, month, token, results):
        self.month = month
        self.token = token
        self.results = results


class RedListenBudget:
    """Monthly request and result accounting shared through Redis. See utils/redlisten.py."""

    def __init__(self, r=None, now=None):
        self.r = r or redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)
        self.fixed_now = now

    def now(self):
        return self.fixed_now or utcnow()

    def month(self):
        """The UTC billing month (YYYYMM) a request starting now is billed to."""
        return self.now().strftime("%Y%m")

    def usage_key(self, month=None):
        return USAGE_KEY % (month or self.month())

    def observed_key(self, month=None):
        return OBSERVED_KEY % (month or self.month())

    def spend_key(self, day=None):
        return SPEND_KEY % (day or self.now()).strftime("%Y%m%d")

    def pending_key(self, month=None):
        return PENDING_KEY % (month or self.month())

    def usage(self, month=None):
        """A month's usage and limits. Usage is the higher of our own reservations and
        RedListen's account-wide counters plus the reservations still in flight, which
        those counters cannot include yet. Limits come from RedListen's headers once a
        response has carried them, so a plan change applies without a deploy."""
        snapshot = self.snapshot(month)
        data = snapshot["counters"]
        observed = snapshot["observed"]
        pending_requests, pending_results = snapshot["pending"]
        return {
            "requests": max(int(data.get("requests") or 0), observed["requests"] + pending_requests),
            "results": max(int(data.get("results") or 0), observed["results"] + pending_results),
            "request_limit": int(data.get("request_limit") or settings.REDLISTEN_MONTHLY_REQUESTS),
            "result_limit": int(data.get("result_limit") or settings.REDLISTEN_MONTHLY_RESULTS),
        }

    def snapshot(self, month=None):
        """Our counters, RedListen's observed counters and the pending reservations, read
        in one MULTI/EXEC transaction. Read separately, a worker settling in between could
        move a request from pending into the observed counters after the observed read and
        before the pending read, and it would be missing from both."""
        month = month or self.month()
        since = time.time() - PENDING_SECONDS
        pipe = self.r.pipeline(transaction=True)
        pipe.hgetall(self.usage_key(month))
        pipe.zscore(self.observed_key(month), "requests")
        pipe.zscore(self.observed_key(month), "results")
        pipe.zrangebyscore(self.pending_key(month), since, "+inf")
        counters, observed_requests, observed_results, tokens = pipe.execute()
        return {
            "counters": counters or {},
            "observed": {"requests": int(observed_requests or 0), "results": int(observed_results or 0)},
            "pending": (len(tokens), sum(int(token.rsplit(":", 1)[1]) for token in tokens)),
        }

    def observed(self, month=None):
        """RedListen's own counters, as the highest values its headers have reported."""
        return self.snapshot(month)["observed"]

    def pending(self, month=None):
        """(requests, results) reserved but not yet settled, ignoring abandoned ones."""
        return self.snapshot(month)["pending"]

    def caps(self, kind, usage=None):
        """(request cap, result cap) this kind of spending may reach this month."""
        usage = usage or self.usage()
        share = 1.0 if kind == ONE_OFF else settings.REDLISTEN_BACKGROUND_SHARE
        return int(usage["request_limit"] * share), int(usage["result_limit"] * share)

    def remaining(self, kind):
        """(requests, results) still spendable by this kind this month."""
        usage = self.usage()
        request_cap, result_cap = self.caps(kind, usage)
        return max(0, request_cap - usage["requests"]), max(0, result_cap - usage["results"])

    def background_allowed(self):
        """Automatic fetching stays off in development unless explicitly turned on, since
        every key on the account draws on the same production quota. Production celery
        turns settings.DEBUG on for the 1% of feed tasks it profiles
        (DBProfilerMiddleware.process_celery in apps/profile/middleware.py), so the server's
        own setting is read from ORIGINAL_DEBUG when profiling has saved it."""
        debug = getattr(settings, "ORIGINAL_DEBUG", settings.DEBUG)
        return not debug or getattr(settings, "REDLISTEN_BACKGROUND_IN_DEBUG", False)

    def reserve(self, kind, results):
        """Claim one request and up to `results` results. Returns a Reservation, which
        settle() and mark_exhausted() take back so a request that finishes after midnight
        on the 1st is still counted in the month it started, or None, claiming nothing,
        when the claim would cross this kind's cap.

        The claim is written before it is checked: to our own counters, and as a pending
        entry on top of RedListen's counters. Two workers reserving at once therefore each
        see the other's claim, so together they can never pass the cap."""
        if kind in BACKGROUND_KINDS and not self.background_allowed():
            return None
        month = self.month()
        key = self.usage_key(month)
        token = "%s:%d" % (uuid.uuid4().hex, results)
        pipe = self.r.pipeline()
        pipe.hincrby(key, "requests", 1)
        pipe.hincrby(key, "results", results)
        pipe.expire(key, USAGE_TTL)
        pipe.zadd(self.pending_key(month), {token: time.time()})
        pipe.expire(self.pending_key(month), USAGE_TTL)
        pipe.execute()

        usage = self.usage(month)
        request_cap, result_cap = self.caps(kind, usage)
        if usage["requests"] > request_cap or usage["results"] > result_cap:
            pipe = self.r.pipeline()
            pipe.hincrby(key, "requests", -1)
            pipe.hincrby(key, "results", -results)
            pipe.zrem(self.pending_key(month), token)
            pipe.execute()
            return None

        self.record_spend(kind, 1, results)
        return Reservation(month, token, results)

    def settle(self, kind, reservation, returned_results, headers):
        """Replace a reservation's result estimate with what actually came back, catch up
        with RedListen's counters, and only then drop the pending entry, so the request is
        never missing from both. All in the reservation's month."""
        month = reservation.month
        correction = returned_results - reservation.results
        if correction:
            self.r.hincrby(self.usage_key(month), "results", correction)
            self.record_spend(kind, 0, correction)
        self.sync_headers(headers, returned_results, month)
        self.r.zrem(self.pending_key(month), reservation.token)
        # Abandoned entries stop counting after PENDING_SECONDS; clear them out too.
        self.r.zremrangebyscore(self.pending_key(month), 0, time.time() - PENDING_SECONDS)

    def sync_headers(self, headers, returned_results, month):
        """Record RedListen's counters when they are ahead (other keys on the account, or
        requests we never saw). The headers report usage from before the request they
        arrive on, so that request is added back in. ZADD GT keeps the highest value any
        worker has seen without a read-then-write race, and never touches our own
        reservations."""
        observed = {}
        quota_used = int_header(headers, "x-quota-used")
        if quota_used is not None:
            observed["requests"] = quota_used + 1
        items_used = int_header(headers, "x-items-used")
        if items_used is not None:
            observed["results"] = items_used + returned_results
        if observed:
            self.r.zadd(self.observed_key(month), observed, gt=True)
            self.r.expire(self.observed_key(month), USAGE_TTL)

        limits = {}
        quota_limit = int_header(headers, "x-quota-limit")
        if quota_limit:
            limits["request_limit"] = quota_limit
        items_limit = int_header(headers, "x-items-limit")
        if items_limit:
            limits["result_limit"] = items_limit
        if limits:
            self.r.hset(self.usage_key(month), mapping=limits)
            self.r.expire(self.usage_key(month), USAGE_TTL)

    def mark_exhausted(self, error_code, month=None):
        """RedListen says a quota is gone; stop spending until the month rolls over."""
        usage = self.usage(month)
        if error_code == "quota_exceeded":
            self.r.zadd(self.observed_key(month), {"requests": usage["request_limit"]}, gt=True)
        elif error_code == "items_quota_exceeded":
            self.r.zadd(self.observed_key(month), {"results": usage["result_limit"]}, gt=True)
        self.r.expire(self.observed_key(month), USAGE_TTL)

    def record_spend(self, kind, requests_spent, results_spent):
        key = self.spend_key()
        pipe = self.r.pipeline()
        if requests_spent:
            pipe.hincrby(key, "%s_requests" % kind, requests_spent)
        if results_spent:
            pipe.hincrby(key, "%s_results" % kind, results_spent)
        pipe.expire(key, SPEND_TTL)
        pipe.execute()

    def spend(self, day=None):
        """{"poller_requests": n, ...} for one UTC day, zero-filled."""
        data = self.r.hgetall(self.spend_key(day)) or {}
        spent = {}
        for kind in SPEND_KINDS:
            for unit in ("requests", "results"):
                field = "%s_%s" % (kind, unit)
                spent[field] = int(data.get(field) or 0)
        return spent

    def last_day_spend(self, kind):
        """(requests, results) this kind spent over roughly the last 24 hours: all of
        today plus the part of yesterday still inside the window."""
        now = self.now()
        today = self.spend(now)
        yesterday = self.spend(now - datetime.timedelta(days=1))
        midnight = now.replace(hour=0, minute=0, second=0, microsecond=0)
        yesterday_share = 1 - (now - midnight).total_seconds() / 86400
        return tuple(
            today["%s_%s" % (kind, unit)] + yesterday["%s_%s" % (kind, unit)] * yesterday_share
            for unit in ("requests", "results")
        )

    def days_left(self):
        """Days until RedListen's quotas reset at the next UTC month."""
        return max(0.0, (month_end(self.now()) - self.now()).total_seconds() / 86400)

    def projected_month(self):
        """(requests, results) the month ends at if every kind keeps spending at its pace
        over the last 24 hours. Charted against the plan by /monitor/redlisten."""
        usage = self.usage()
        days_left = self.days_left()
        requests_per_day = results_per_day = 0.0
        for kind in SPEND_KINDS:
            kind_requests, kind_results = self.last_day_spend(kind)
            requests_per_day += kind_requests
            results_per_day += kind_results
        return (
            usage["requests"] + requests_per_day * days_left,
            usage["results"] + results_per_day * days_left,
        )

    def reserve_minute_slot(self):
        """Fixed one-minute window under RedListen's per-minute limit (120 on Pro)."""
        count = self.r.incr(RATE_LIMIT_KEY)
        if count == 1:
            self.r.expire(RATE_LIMIT_KEY, 60)
        elif self.r.ttl(RATE_LIMIT_KEY) < 0:
            # A worker that died between INCR and EXPIRE must not wedge the window shut.
            self.r.expire(RATE_LIMIT_KEY, 60)
        return count <= settings.REDLISTEN_REQUESTS_PER_MINUTE


class RedListenClient:
    """GETs from RedListen through the budget. See utils/redlisten.py."""

    def __init__(self, budget=None):
        self.budget = budget or RedListenBudget()

    def get(self, path, params=None, kind=SCHEDULED, max_results=25, timeout=30):
        """Fetch a RedListen path. max_results is the most results the request can
        return (its limit, plus the post itself on a thread) and is what gets reserved."""
        api_key = getattr(settings, "REDLISTEN_API_KEY", None)
        if not api_key:
            logging.debug("   ***> ~FRRedListen API key is not configured")
            return RedListenResult(denied=DENIED_NOT_CONFIGURED)
        if not self.budget.reserve_minute_slot():
            return RedListenResult(denied=DENIED_RATE_LIMIT)
        reservation = self.budget.reserve(kind, max_results)
        if not reservation:
            return RedListenResult(denied=DENIED_BUDGET)

        headers = {"Authorization": "Bearer %s" % api_key, "User-Agent": USER_AGENT}
        try:
            response = requests.get(BASE_URL + path, params=params, headers=headers, timeout=timeout)
        except requests.RequestException as e:
            # Nothing came back, so nothing was returned to bill; keep the request counted.
            self.budget.settle(kind, reservation, 0, {})
            logging.debug("   ***> ~FRRedListen request failed: %s: %s" % (path[:120], e))
            return RedListenResult()

        payload = None
        error_code = None
        try:
            body = response.json()
        except ValueError:
            body = None
        if response.status_code == 200:
            payload = body
        elif isinstance(body, dict):
            error_code = (body.get("error") or {}).get("code")

        results = count_results(payload)
        self.budget.settle(kind, reservation, results, response.headers)
        if response.status_code == 429 and error_code in ("quota_exceeded", "items_quota_exceeded"):
            self.budget.mark_exhausted(error_code, reservation.month)
        if response.status_code != 200:
            logging.debug(
                "   ***> ~FRRedListen HTTP %s%s: %s"
                % (response.status_code, " (%s)" % error_code if error_code else "", path[:120])
            )
        return RedListenResult(
            status=response.status_code, payload=payload, results=results, error_code=error_code
        )
