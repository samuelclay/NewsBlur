"""Per-domain feed fetch budget shared across all task servers.

A Pro subscriber's feeds are fetched every PRO_MINUTES_BETWEEN_FETCHES minutes, so one
user subscribing to a thousand feeds on a single site turns into a constant hammering
of that site: 1,100 abebooks.com web feeds at Pro speed came out to ~213 fetches/minute,
around 175,000/day, against one domain. Production data (July 2026) shows 99.75% of the
~88,000 hosts fetched in any given hour already stay under 1 fetch/minute; only a couple
dozen hosts exceed the default budget here, and they are either genuinely hammered
single sites (abebooks.com, news.google.com, nitter.net) or huge multi-tenant hosts
serving thousands of distinct legitimate feeds (youtube.com, feeds.feedburner.com),
which get raised budgets via DOMAIN_FETCHES_PER_MINUTE_OVERRIDES.

This is modeled on the shared Reddit API budget in utils/reddit_fetcher.py: a fixed
one-minute window in Redis (settings.REDIS_FEED_UPDATE_POOL, shared by every task
server) counts fetch attempts per domain. The difference is what happens when the
budget is spent: Reddit records a 429 in fetch history, but recording errors for
expected backpressure poisons fetch history and eventually flags feed exceptions, so
here the fetch is silently deferred instead. Feed.update() in apps/rss_feeds/models.py
asks reserve_fetch_slot() for a slot before fetching; when the budget is spent it
reschedules the feed with set_next_scheduled_update(delay_fetch_sec=...) and no fetch
history is written. Backpressure is a return flag, never an exception.
"""

import datetime
from urllib.parse import urlparse

import redis
from django.conf import settings

# Redis key for a domain's current one-minute window counter.
RATE_LIMIT_KEY_PREFIX = "domain_fetch:ratelimit:"

# Redis hash per day of host -> deferred fetch count, kept for a week. Read this to
# find hosts that need a budget override in DOMAIN_FETCHES_PER_MINUTE_OVERRIDES:
#   redis-cli -n 4 HGETALL domain_fetch:throttled:20260714
THROTTLE_STATS_KEY_PREFIX = "domain_fetch:throttled:"
THROTTLE_STATS_TTL = 60 * 60 * 24 * 7

# Deferral bounds for a feed that lost the budget race: never sooner than 5 minutes
# (feeds on hot domains gain nothing from retrying within the same few windows), never
# later than 4 hours (matching the premium scheduling cap in
# apps/rss_feeds/models.py get_next_scheduled_update).
MIN_DEFER_SECONDS = 60 * 5
MAX_DEFER_SECONDS = 60 * 60 * 4


def feed_host(feed_address):
    """Return the budget key for a feed address: hostname minus www. and port.

    Web feed addresses carry a webfeed: prefix ahead of the page URL
    (see apps/webfeed/views.py). Returns None for addresses without a real
    hostname (local fixture paths, docker hostnames), which are never limited.
    """
    address = (feed_address or "").strip()
    if address.startswith("webfeed:"):
        address = address[len("webfeed:") :]
    if not address:
        return None
    if "://" not in address:
        address = "http://" + address
    try:
        host = urlparse(address).netloc
    except ValueError:
        return None
    host = host.rpartition("@")[2].split(":")[0].lower()
    if host.startswith("www."):
        host = host[4:]
    # Hosts without a dot are local/docker names, not internet domains.
    if "." not in host:
        return None
    return host


def host_budget_per_minute(host):
    """Return the per-minute fetch budget for a host.

    Multi-tenant hosts that legitimately serve thousands of distinct feeds get raised
    budgets from settings.DOMAIN_FETCHES_PER_MINUTE_OVERRIDES; everything else gets
    settings.DOMAIN_FETCHES_PER_MINUTE. Settings are read at call time so tests can
    override them. See newsblur_web/settings.py for the tuned values.
    """
    overrides = getattr(settings, "DOMAIN_FETCHES_PER_MINUTE_OVERRIDES", {})
    default = getattr(settings, "DOMAIN_FETCHES_PER_MINUTE", 30)
    return overrides.get(host, default)


def reserve_fetch_slot(feed_address):
    """Atomically claim one slot in a domain's shared per-minute fetch budget.

    Returns (allowed, defer_seconds). allowed is True when the fetch may proceed,
    in which case defer_seconds is 0. When the budget is spent, allowed is False and
    defer_seconds says how long the caller should wait before retrying this feed.

    Uses the same fixed one-minute window as reserve_rate_limit_slot() in
    utils/reddit_fetcher.py: the first claim of a window sets a 60s TTL, and at most
    budget claims succeed before the window rolls over. Rejected claims still
    increment the counter, so each rejected feed learns its position in the backlog:
    the deferral grows with the overage, which staggers a stampeding domain (1,100
    feeds arriving at once spread out over hours instead of retrying in lockstep).
    """
    host = feed_host(feed_address)
    if not host:
        return True, 0

    budget = host_budget_per_minute(host)
    r = redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)
    key = RATE_LIMIT_KEY_PREFIX + host
    count = r.incr(key)
    if count == 1:
        r.expire(key, 60)
    elif r.ttl(key) < 0:
        # Guard the rare case where the window key lost its expiry (e.g. a worker
        # crashed between INCR and EXPIRE) so the limiter can never wedge shut.
        r.expire(key, 60)

    if count <= budget:
        return True, 0

    # Position-based deferral: the Nth feed past the budget waits ~N/budget minutes,
    # its place in line at the domain's sustainable drain rate.
    overage = count - budget
    defer_seconds = min(max(int(overage * 60 / budget), MIN_DEFER_SECONDS), MAX_DEFER_SECONDS)

    stats_key = THROTTLE_STATS_KEY_PREFIX + datetime.datetime.utcnow().strftime("%Y%m%d")
    r.hincrby(stats_key, host, 1)
    r.expire(stats_key, THROTTLE_STATS_TTL)

    return False, defer_seconds
