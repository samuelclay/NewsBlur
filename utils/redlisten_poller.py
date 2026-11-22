"""Hourly RedListen poll of every subreddit and Reddit user that active feeds read.

RedListen (utils/redlisten.py) bills every post it returns, and on the Pro plan that
is 1,000,000 results a month, about a third of what the ~8,000 subreddits NewsBlur
readers follow post. Requests are the cheap side: one listing call covers hundreds of
subreddits joined with + (/r/a+b+c/new.json), and one search covers dozens of authors
(author:a OR author:b). So once an hour, this poller:

  1. Finds the targets: every subreddit ("r:<name>") and user ("u:<name>") that a
     subreddit, multireddit or user feed with active readers points at, with those
     feeds and their reader counts (utils/reddit_fetcher.py parses the addresses).
  2. Works out this hour's result budget: what is left of the month's 99% background
     share, less what comment-thread and search feeds are spending, spread evenly over
     the hours left in the month.
  3. Splits that budget with weighted water-filling. Each target is expected to post
     its learned rate times the time since it was last polled, and gets
     min(expected, level x readers), with the level set so the shares add up to the
     budget. Quiet targets get every post; busy ones get a share that grows with how
     many NewsBlur readers follow them.
  4. Packs targets into requests. Targets that get everything are drained: their batch
     pages back (after=) until it reaches the previous poll. Capped targets are grouped
     with others capped at a similar fraction and get one page sized to their combined
     share, so the newest posts across the batch split roughly in proportion. Batches run
     longest-waiting first, so a short hour rotates through targets instead of skipping
     the same ones.
  5. Learns each target's posting rate from what came back. The newest N posts across a
     batch are every post its targets made since the oldest of them, so a page's counts
     over its time span are a fair rate sample even when the batch was capped. Samples
     decay with a three-day half-life.
  6. Caches the posts (utils/reddit_post_cache.py) and schedules every feed whose
     targets gained a post, so it ingests them on its next task run.

Users are polled every other hour to save requests. Development servers skip the poll
unless settings.REDLISTEN_BACKGROUND_IN_DEBUG is on, since every key on the account
spends the production quota. See utils/redlisten_poller.py.
"""

import calendar
import datetime
import json
import math
import time
import uuid

import redis
from django.conf import settings

from utils import log as logging
from utils.reddit_fetcher import REDDIT_ADDRESS_PATTERN, RedditFetcher
from utils.reddit_post_cache import RedditPostCache, subreddit_target, user_target
from utils.redlisten import (
    ONE_OFF,
    POLLER,
    SCHEDULED,
    RedListenBudget,
    RedListenClient,
    month_end,
)

CYCLE_SECONDS = 60 * 60
USER_POLL_EVERY_HOURS = 2

# Redis keys (settings.REDIS_FEED_UPDATE_POOL, db 4).
STATS_KEY = "redlisten:target_stats"  # hash: target -> JSON {posts, window, updated, last_polled}
LAST_POLL_KEY = "redlisten:last_poll"  # JSON summary of the latest poll, for /monitor/redlisten
POLL_LOCK_KEY = "redlisten:poll_lock"

# Posting rates: decayed counts over decayed observed seconds, plus a weak prior of
# PRIOR_POSTS_PER_DAY over PRIOR_SECONDS for targets not seen yet. The prior is short so
# that a single hour's poll outweighs it: a two-hour prior held a sub posting 3,600 a day
# to an estimate of 1,500 in testing.
RATE_HALF_LIFE_SECONDS = 3 * 24 * 60 * 60
PRIOR_POSTS_PER_DAY = 10.0
PRIOR_SECONDS = 15 * 60

# A drained batch starts this far before the previous poll, since RedListen delivers a
# post a few seconds after Reddit timestamps it, and never reaches back further than
# MAX_LOOKBACK_SECONDS, so an outage costs a gap instead of a burst of old posts.
OVERLAP_SECONDS = 5 * 60
MAX_LOOKBACK_SECONDS = 2 * CYCLE_SECONDS

# RedListen caps Reddit-style listings at 100 per page. A drained batch holds about one
# page of expected posts, and pages at most MAX_PAGES_PER_BATCH times.
PAGE_SIZE = 100
DRAIN_BATCH_EXPECTED_POSTS = 70
MAX_PAGES_PER_BATCH = 5

# Request size limits. 1,000 subreddits in one path (12K characters) worked in testing
# and 2,500 (30K) failed, so batches stay well under the first.
MAX_SUBREDDIT_PATH_CHARS = 7000
MAX_AUTHOR_QUERY_CHARS = 3000

# Spacing between the poller's requests, under RedListen's 120 a minute with room left
# for the feed fetches running alongside.
REQUEST_SPACING_SECONDS = 0.7


def epoch_seconds(when):
    """A naive UTC datetime as true epoch seconds, comparable with Reddit's created_utc."""
    return calendar.timegm(when.utctimetuple())


def scheduler_timestamp(when):
    """Seconds since the epoch the way the feed scheduler counts them for scheduled_updates
    (apps/rss_feeds/tasks.py TaskFeeds), which must match it to the second."""
    return int(when.strftime("%s"))


def allocate(demands, weights, budget):
    """Weighted water-filling. Every target gets min(demand, level * weight), with the
    level chosen so the shares add up to the budget, or every demand in full when the
    budget covers them all. Returns {target: share}."""
    if sum(demands.values()) <= budget:
        return dict(demands)
    low, high = 0.0, max(demands[key] / weights[key] for key in demands)
    for _ in range(60):
        level = (low + high) / 2
        if sum(min(demands[key], level * weights[key]) for key in demands) > budget:
            high = level
        else:
            low = level
    return {key: min(demands[key], low * weights[key]) for key in demands}


class PollTarget:
    """One subreddit or user the poller reads, with what it has learned about it."""

    def __init__(self, key, stats=None):
        self.key = key
        self.feed_ids = []
        self.readers = 0
        stats = stats or {}
        self.posts = float(stats.get("posts") or 0)
        self.window = float(stats.get("window") or 0)
        self.updated = float(stats.get("updated") or 0)
        self.last_polled = float(stats.get("last_polled") or 0)

    @property
    def name(self):
        return self.key[2:]

    @property
    def is_user(self):
        return self.key.startswith("u:")

    def posts_per_second(self):
        prior_posts = PRIOR_POSTS_PER_DAY * PRIOR_SECONDS / 86400
        return (self.posts + prior_posts) / (self.window + PRIOR_SECONDS)

    def poll_from(self, now_ts):
        """Where this target's next poll should reach back to."""
        if not self.last_polled:
            return now_ts - CYCLE_SECONDS
        return max(self.last_polled, now_ts - MAX_LOOKBACK_SECONDS)

    def expected_posts(self, now_ts):
        return self.posts_per_second() * (now_ts - self.poll_from(now_ts))

    def observe(self, count, seconds, now_ts):
        """Fold in `count` posts seen over `seconds`, decaying older samples."""
        if self.updated:
            decay = 0.5 ** (max(0, now_ts - self.updated) / RATE_HALF_LIFE_SECONDS)
            self.posts *= decay
            self.window *= decay
        self.posts += count
        self.window += max(0, seconds)
        self.updated = now_ts

    def stats(self):
        return json.dumps(
            {
                "posts": round(self.posts, 3),
                "window": round(self.window, 1),
                "updated": self.updated,
                "last_polled": self.last_polled,
            }
        )


class PollBatch:
    """Targets fetched together in one RedListen request (and its pages)."""

    def __init__(self, drain, is_user):
        self.drain = drain
        self.is_user = is_user
        self.targets = []
        self.expected = 0.0
        self.share = 0.0
        self.chars = 0
        self.readers = 0

    def cost(self, target):
        if self.is_user:
            return len(target.name) + len("author: OR ")
        return len(target.name) + 1

    def fits(self, target, expected, share):
        if not self.targets:
            return True
        if self.chars + self.cost(target) > (
            MAX_AUTHOR_QUERY_CHARS if self.is_user else MAX_SUBREDDIT_PATH_CHARS
        ):
            return False
        if self.drain:
            return self.expected + expected <= DRAIN_BATCH_EXPECTED_POSTS
        return self.share + share <= PAGE_SIZE

    def add(self, target, expected, share):
        self.targets.append(target)
        self.expected += expected
        self.share += share
        self.chars += self.cost(target)
        self.readers += target.readers

    def oldest_poll(self):
        """When the least recently polled target in this batch was last polled, 0 if never."""
        return min(target.last_polled for target in self.targets)

    def priority(self):
        """Sort key for the hour's batches: longest-waiting first, so when the budget runs
        short the batches left over go first next hour and every target gets polled in turn.
        The first prod poll ran 12 of 34 batches while busy targets of unknown rate spent the
        budget, and ordering by readers alone would skip the same low-reader batches every
        hour. Ties go to drained batches (quiet targets that get every post), then the
        most-read."""
        return (self.oldest_poll(), not self.drain, -self.readers)

    def first_limit(self):
        if self.drain:
            return max(5, min(PAGE_SIZE, math.ceil(self.expected * 1.3) + 5))
        return max(1, min(PAGE_SIZE, int(round(self.share))))

    def request(self, limit, after=None):
        """(path, params) for this batch's next page."""
        params = {"limit": limit}
        if after:
            params["after"] = after
        if self.is_user:
            params["q"] = " OR ".join("author:%s" % target.name for target in self.targets)
            params["type"] = "link"
            # Paging and rate learning need newest first; Reddit's search defaults to relevance.
            params["sort"] = "new"
            return "/search.json", params
        return "/r/%s/new.json" % "+".join(target.name for target in self.targets), params

    def target_key(self, post):
        if self.is_user:
            return user_target(post.get("author") or "")
        return subreddit_target(post.get("subreddit") or "")


def build_batches(targets, demands, shares, is_user):
    """Drained batches for targets that get every post, then capped batches grouped by
    the fraction of their posts they get. See utils/redlisten_poller.py."""
    drained = sorted((t for t in targets if shares[t.key] >= demands[t.key] * 0.999), key=lambda t: t.key)
    capped = sorted(
        (t for t in targets if shares[t.key] < demands[t.key] * 0.999),
        key=lambda t: shares[t.key] / demands[t.key],
    )
    batches = []
    for drain, group in ((True, drained), (False, capped)):
        batch = PollBatch(drain, is_user)
        for target in group:
            if not batch.fits(target, demands[target.key], shares[target.key]):
                batches.append(batch)
                batch = PollBatch(drain, is_user)
            batch.add(target, demands[target.key], shares[target.key])
        if batch.targets:
            batches.append(batch)
    return batches


class RedListenPoller:
    def __init__(self, budget=None, client=None, cache=None, r=None, now=None):
        self.r = r or redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)
        self.budget = budget or RedListenBudget(r=self.r)
        self.client = client or RedListenClient(budget=self.budget)
        self.cache = cache or RedditPostCache(r=self.r)
        self.now = now or datetime.datetime.utcnow()
        self.now_ts = epoch_seconds(self.now)
        self.lock_token = uuid.uuid4().hex
        self.spent_requests = 0
        self.spent_results = 0
        # This hour's results ceiling, set by run() from cycle_budget().
        self.result_budget = float("inf")
        # (requests, results) cycle_budget sets aside for other spending through month end.
        self.set_aside = (0.0, 0.0)
        self.feeds_to_schedule = set()

    def load_targets(self):
        """Every subreddit and user that active Reddit feeds read, with stats attached."""
        from apps.rss_feeds.models import Feed

        stats = {}
        for key, raw in (self.r.hgetall(STATS_KEY) or {}).items():
            try:
                stats[key] = json.loads(raw)
            except ValueError:
                continue

        targets = {}
        feeds = Feed.objects.filter(
            active_subscribers__gte=1, feed_address__iregex=REDDIT_ADDRESS_PATTERN
        ).values_list("pk", "feed_address", "active_subscribers")
        for feed_id, address, readers in feeds.iterator():
            for key in RedditFetcher.for_address(address).poll_targets():
                if key not in targets:
                    targets[key] = PollTarget(key, stats.get(key))
                targets[key].feed_ids.append(feed_id)
                targets[key].readers += max(1, readers or 0)

        stale = [key for key in stats if key not in targets]
        for start in range(0, len(stale), 1000):
            self.r.hdel(STATS_KEY, *stale[start : start + 1000])
        return targets

    def cycle_budget(self):
        """(results, requests) this hour's poll may spend: the month's remaining
        background share, less what comment-thread and search feeds and readers' one-off
        fetches are on pace to spend by month end at their last 24 hours' rate, spread
        evenly over the hours left in the month. What is set aside is kept on
        self.set_aside for the poll summary."""
        usage = self.budget.usage()
        request_cap, result_cap = self.budget.caps(POLLER, usage)
        seconds_left = max(CYCLE_SECONDS, (month_end(self.now) - self.now).total_seconds())
        cycles_left = seconds_left / CYCLE_SECONDS
        days_left = seconds_left / 86400
        set_aside_requests = set_aside_results = 0.0
        for kind in (SCHEDULED, ONE_OFF):
            requests_per_day, results_per_day = self.budget.last_day_spend(kind)
            set_aside_requests += requests_per_day * days_left
            set_aside_results += results_per_day * days_left
        self.set_aside = (set_aside_requests, set_aside_results)
        results_left = result_cap - usage["results"] - set_aside_results
        requests_left = request_cap - usage["requests"] - set_aside_requests
        return max(0.0, results_left / cycles_left), max(0.0, requests_left / cycles_left)

    def poll(self):
        if not getattr(settings, "REDLISTEN_API_KEY", None):
            logging.debug(" ---> ~FRRedListen poll skipped: no API key")
            return None
        if not self.budget.background_allowed():
            logging.debug(" ---> ~FYRedListen poll skipped in development (REDLISTEN_BACKGROUND_IN_DEBUG)")
            return None
        if not self.r.set(POLL_LOCK_KEY, self.lock_token, nx=True, ex=CYCLE_SECONDS - 5 * 60):
            logging.debug(" ---> ~FYRedListen poll skipped: the previous poll is still running")
            return None
        try:
            return self.run()
        finally:
            # Only release our own lock: if this poll outlived the lock's expiry, the next
            # poll may hold it now.
            if self.r.get(POLL_LOCK_KEY) == self.lock_token:
                self.r.delete(POLL_LOCK_KEY)

    def run(self):
        started = time.time()
        targets = self.load_targets()
        include_users = self.now.hour % USER_POLL_EVERY_HOURS == 0
        polled = [t for t in targets.values() if include_users or not t.is_user]
        result_budget, request_budget = self.cycle_budget()
        self.result_budget = result_budget

        demands = {t.key: max(0.01, t.expected_posts(self.now_ts)) for t in polled}
        weights = {t.key: max(1, t.readers) for t in polled}
        shares = allocate(demands, weights, result_budget)
        capped = sum(1 for t in polled if shares[t.key] < demands[t.key] * 0.999)

        batches = []
        for is_user in (False, True):
            group = [t for t in polled if t.is_user == is_user]
            batches.extend(build_batches(group, demands, shares, is_user))
        batches.sort(key=PollBatch.priority)

        # The hour's results budget is a hard ceiling: a batch starts only if its first page
        # fits in what is left, and poll_batch caps every later page the same way. Any
        # overspend would come out of every later hour, since cycle_budget spreads what is
        # left (polls that ran ~14% over would have left late-month hours ~40% short).
        polled_batches = 0
        for batch in batches:
            if self.spent_requests + 1 > request_budget:
                break
            if self.spent_results + batch.first_limit() > result_budget:
                continue
            if self.poll_batch(batch):
                polled_batches += 1

        stats = {t.key: t.stats() for t in polled if t.updated}
        keys = list(stats)
        for start in range(0, len(keys), 1000):
            self.r.hset(STATS_KEY, mapping={key: stats[key] for key in keys[start : start + 1000]})
        self.schedule_feeds()

        summary = {
            "polled_at": self.now_ts,
            "seconds": round(time.time() - started, 1),
            "targets": len(targets),
            "polled_targets": len(polled),
            "capped_targets": capped,
            "batches": len(batches),
            "polled_batches": polled_batches,
            "result_budget": round(result_budget),
            "request_budget": round(request_budget, 1),
            "set_aside_requests": round(self.set_aside[0]),
            "set_aside_results": round(self.set_aside[1]),
            "expected_results": round(sum(demands.values())),
            "spent_results": self.spent_results,
            "spent_requests": self.spent_requests,
            "scheduled_feeds": len(self.feeds_to_schedule),
        }
        self.r.set(LAST_POLL_KEY, json.dumps(summary))
        logging.debug(
            " ---> ~FBRedListen poll: ~SB%s~SN targets (%s capped), %s/%s batches, "
            "%s results / %s requests (budget %s / %s), %s feeds scheduled"
            % (
                len(polled),
                capped,
                polled_batches,
                len(batches),
                self.spent_results,
                self.spent_requests,
                summary["result_budget"],
                summary["request_budget"],
                len(self.feeds_to_schedule),
            )
        )
        return summary

    def poll_batch(self, batch):
        """Fetch one batch (paging a drained batch back to its previous poll), cache the
        posts and learn from them. Returns True when RedListen answered."""
        poll_from = min(target.poll_from(self.now_ts) for target in batch.targets) - OVERLAP_SECONDS
        expected_per_second = sum(target.posts_per_second() for target in batch.targets)
        posts = []
        limit = batch.first_limit()
        after = None
        reached_poll_from = False
        complete = False
        for page in range(MAX_PAGES_PER_BATCH):
            if page:
                # Later pages fit in what is left of the hour's results budget. A batch cut
                # short stays incomplete, so the next poll reaches back for the rest.
                budget_left = self.result_budget - self.spent_results
                if budget_left < limit:
                    limit = int(budget_left)
                if limit < 1:
                    break
                time.sleep(REQUEST_SPACING_SECONDS)
            path, params = batch.request(limit, after)
            result = self.client.get(path, params=params, kind=POLLER, max_results=limit)
            self.spent_requests += 1
            if not result.ok:
                break
            self.spent_results += result.results
            listing = result.payload.get("data") or {}
            children = [child.get("data") or {} for child in listing.get("children") or []]
            children = [post for post in children if post.get("id")]
            posts.extend(children)
            created = [post.get("created_utc") or 0 for post in children]
            if len(children) < limit or (created and min(created) <= poll_from):
                reached_poll_from = True
                complete = True
                break
            if not batch.drain or not listing.get("after"):
                complete = True
                break
            after = listing["after"]
            # Size the next page from how fast the batch is actually posting too, since the
            # learned rates know nothing yet about a new or suddenly busy target.
            oldest = min(post.get("created_utc") or self.now_ts for post in posts)
            observed_per_second = len(posts) / max(60, self.now_ts - oldest)
            remaining = max(expected_per_second, observed_per_second) * max(0, min(created) - poll_from)
            limit = max(5, min(PAGE_SIZE, math.ceil(remaining * 1.3) + 5))
        time.sleep(REQUEST_SPACING_SECONDS)
        if not posts and not complete:
            return False

        # The pages hold every post the batch's targets made since window_start.
        if reached_poll_from or not posts:
            window_start = poll_from
        else:
            window_start = min(post.get("created_utc") or self.now_ts for post in posts)
        by_target = {}
        for post in posts:
            by_target.setdefault(batch.target_key(post), []).append(post)
        for target in batch.targets:
            target_posts = by_target.get(target.key, [])
            seen = sum(1 for post in target_posts if (post.get("created_utc") or 0) >= window_start)
            target.observe(seen, self.now_ts - window_start, self.now_ts)
            # A target's first complete poll schedules its feeds even with no new posts, so
            # a feed still backed off from an old error (Reddit's 401s before RedListen) or
            # one that is new rereads the cache and clears it instead of waiting out its
            # backoff, up to a week, for the next post.
            first_poll = complete and not target.last_polled
            if complete:
                target.last_polled = self.now_ts
            added = self.cache.add(target.key, target_posts) if target_posts else 0
            if added or first_poll:
                self.feeds_to_schedule.update(target.feed_ids)
        return True

    def schedule_feeds(self):
        """Queue every feed whose targets gained a post, the way
        Feed.schedule_feed_fetch_immediately does (apps/rss_feeds/models.py)."""
        feed_ids = list(self.feeds_to_schedule)
        now = scheduler_timestamp(self.now)
        for start in range(0, len(feed_ids), 1000):
            self.r.zadd("scheduled_updates", {feed_id: now for feed_id in feed_ids[start : start + 1000]})
