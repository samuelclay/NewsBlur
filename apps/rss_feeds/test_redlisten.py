"""Tests for the RedListen budget and client (utils/redlisten.py) and the hourly poller
(utils/redlisten_poller.py). Redis is apps/rss_feeds/fake_redis.py and the network is
patched, so nothing here spends the real RedListen quota."""

import datetime
import json
import time
from unittest.mock import MagicMock, patch

from django.test import SimpleTestCase, override_settings

from apps.rss_feeds.fake_redis import FakeRedis
from utils.reddit_post_cache import RedditPostCache
from utils.redlisten import (
    DENIED_BUDGET,
    DENIED_NOT_CONFIGURED,
    ONE_OFF,
    POLLER,
    SCHEDULED,
    RedListenBudget,
    RedListenClient,
    RedListenResult,
    count_results,
)
from utils.redlisten_poller import (
    LAST_POLL_KEY,
    STATS_KEY,
    PollBatch,
    PollTarget,
    RedListenPoller,
    allocate,
    build_batches,
    epoch_seconds,
)

NOW = datetime.datetime(2026, 11, 10, 12, 0, 0)
NOW_TS = epoch_seconds(NOW)

# A small plan so the 99% line is easy to hit: 99 requests and 990 results in the background.
SMALL_PLAN = dict(
    REDLISTEN_MONTHLY_REQUESTS=100,
    REDLISTEN_MONTHLY_RESULTS=1000,
    REDLISTEN_BACKGROUND_SHARE=0.99,
    REDLISTEN_REQUESTS_PER_MINUTE=100,
    REDLISTEN_API_KEY="rl_test_key",
    DEBUG=False,
)


def listing(posts, after=None):
    return {
        "kind": "Listing",
        "data": {"after": after, "children": [{"kind": "t3", "data": p} for p in posts]},
    }


def post(post_id, subreddit="python", created=NOW_TS - 60, author="someone"):
    return {
        "id": post_id,
        "title": "Post %s" % post_id,
        "subreddit": subreddit,
        "author": author,
        "created_utc": created,
        "permalink": "/r/%s/comments/%s/t/" % (subreddit, post_id),
    }


def http_response(status, body, headers=None):
    response = MagicMock(status_code=status, headers=headers or {})
    response.json.return_value = body
    return response


@override_settings(**SMALL_PLAN)
class Test_RedListenBudget(SimpleTestCase):
    def setUp(self):
        self.r = FakeRedis()
        self.budget = RedListenBudget(r=self.r, now=NOW)

    def set_usage(self, requests, results):
        self.r.hset(self.budget.usage_key(), mapping={"requests": requests, "results": results})

    def test_background_stops_at_99_percent_and_one_offs_get_the_rest(self):
        self.set_usage(10, 985)
        self.assertFalse(self.budget.reserve(POLLER, 10))
        self.assertFalse(self.budget.reserve(SCHEDULED, 10))
        # A refused reservation claims nothing.
        self.assertEqual(self.budget.usage()["results"], 985)
        self.assertTrue(self.budget.reserve(ONE_OFF, 10))
        self.assertFalse(self.budget.reserve(ONE_OFF, 10))

    def test_request_quota_has_the_same_reserve(self):
        self.set_usage(99, 0)
        self.assertFalse(self.budget.reserve(POLLER, 0))
        self.assertTrue(self.budget.reserve(ONE_OFF, 0))
        self.assertFalse(self.budget.reserve(ONE_OFF, 0))

    def test_settle_replaces_the_estimate_and_adopts_redlistens_counters(self):
        reservation = self.budget.reserve(POLLER, 25)
        self.assertEqual(reservation.month, "202611")
        self.assertEqual(self.budget.usage()["results"], 25)
        self.budget.settle(POLLER, reservation, 7, {})
        self.assertEqual(self.budget.usage()["results"], 7)
        self.assertEqual(self.budget.spend()["poller_results"], 7)
        self.assertEqual(self.budget.pending(), (0, 0))

        # Other keys on the account spent more; the headers predate the request they came on.
        headers = {
            "x-quota-used": "40",
            "x-items-used": "500",
            "x-quota-limit": "50000",
            "x-items-limit": "1000000",
        }
        self.budget.sync_headers(headers, 7, reservation.month)
        usage = self.budget.usage()
        self.assertEqual((usage["requests"], usage["results"]), (41, 507))
        self.assertEqual((usage["request_limit"], usage["result_limit"]), (50000, 1000000))

        # Counters that trail ours never pull usage back down.
        self.budget.sync_headers({"x-quota-used": "3", "x-items-used": "10"}, 0, reservation.month)
        self.assertEqual(self.budget.usage()["results"], 507)

    def test_unlimited_headers_keep_the_configured_limits(self):
        self.budget.sync_headers({"x-quota-limit": "unlimited", "x-items-limit": "unlimited"}, 0, "202611")
        usage = self.budget.usage()
        self.assertEqual((usage["request_limit"], usage["result_limit"]), (100, 1000))

    def test_redlistens_counters_count_toward_the_cap(self):
        # Another key on the account spent 985 results; our own reservations are 0.
        self.r.zadd(self.budget.observed_key(), {"results": 985})
        self.assertIsNone(self.budget.reserve(POLLER, 10))
        self.assertTrue(self.budget.reserve(POLLER, 5))

    def test_concurrent_reservations_see_each_other(self):
        self.r.zadd(self.budget.observed_key(), {"results": 985})
        first = self.budget.reserve(POLLER, 5)
        self.assertTrue(first)
        # A second worker reserving before the first settles would make 995.
        self.assertIsNone(self.budget.reserve(POLLER, 5))
        # Once the first settles, RedListen's counters include it.
        self.budget.settle(POLLER, first, 5, {"x-items-used": "985"})
        self.assertEqual(self.budget.usage()["results"], 990)
        self.assertIsNone(self.budget.reserve(POLLER, 1))

    def test_a_settle_racing_a_reservation_still_counts_once(self):
        """Worker A settles after worker B has claimed its own slot but before B checks
        usage. B's check reads in one transaction, so it sees A either still pending or
        already in RedListen's counters, never in neither."""
        self.r.zadd(self.budget.observed_key(), {"results": 985})
        first = self.budget.reserve(POLLER, 5)
        original_pipeline = self.r.pipeline
        pipelines = []

        def pipeline_settling_a_before_bs_check(*args, **kwargs):
            pipelines.append(kwargs)
            # B's reserve() writes its claim in its first pipeline and checks usage in its second.
            if len(pipelines) == 2:
                self.budget.settle(POLLER, first, 5, {"x-items-used": "985"})
            return original_pipeline(*args, **kwargs)

        with patch.object(self.r, "pipeline", side_effect=pipeline_settling_a_before_bs_check):
            self.assertIsNone(self.budget.reserve(POLLER, 5))
        self.assertEqual(pipelines[1], {"transaction": True})

    def test_an_abandoned_reservation_stops_counting(self):
        self.r.zadd(self.budget.observed_key(), {"results": 900})
        self.r.zadd(self.budget.pending_key(), {"dead-worker:80": time.time() - 10 * 60})
        self.r.zadd(self.budget.pending_key(), {"live-worker:5": time.time()})
        self.assertEqual(self.budget.pending(), (1, 5))
        self.assertEqual(self.budget.usage()["results"], 905)

    def test_a_stale_header_never_undoes_reservations_or_newer_counters(self):
        for _ in range(2):
            self.budget.settle(POLLER, self.budget.reserve(POLLER, 10), 10, {})
        # A worker reports counters from before both reservations, then an older one.
        self.budget.sync_headers({"x-quota-used": "500", "x-items-used": "600"}, 0, "202611")
        self.budget.sync_headers({"x-quota-used": "0", "x-items-used": "0"}, 0, "202611")
        usage = self.budget.usage()
        self.assertEqual((usage["requests"], usage["results"]), (501, 600))
        self.assertEqual(self.r.hgetall(self.budget.usage_key())["requests"], "2")

    def test_a_request_crossing_midnight_settles_in_the_month_it_started(self):
        self.budget.fixed_now = datetime.datetime(2026, 11, 30, 23, 59, 59)
        reservation = self.budget.reserve(POLLER, 25)
        self.budget.fixed_now = datetime.datetime(2026, 12, 1, 0, 0, 5)
        self.budget.settle(POLLER, reservation, 3, {"x-quota-used": "49000", "x-items-used": "989000"})

        december = self.budget.usage()
        self.assertEqual((december["requests"], december["results"]), (0, 0))
        november = self.budget.usage("202611")
        self.assertEqual((november["requests"], november["results"]), (49001, 989003))

    def test_projected_month_runs_every_kind_at_its_last_day_pace(self):
        self.r.hset(self.budget.usage_key(), mapping={"requests": 10, "results": 100})
        self.r.hset(
            self.budget.spend_key(),
            mapping={
                "poller_requests": 3,
                "poller_results": 30,
                "scheduled_requests": 1,
                "one_off_results": 2,
            },
        )
        days_left = (datetime.datetime(2026, 12, 1) - NOW).total_seconds() / 86400
        requests, results = self.budget.projected_month()
        self.assertAlmostEqual(requests, 10 + 4 * days_left)
        self.assertAlmostEqual(results, 100 + 32 * days_left)

    def test_exhausted_quota_stops_everyone(self):
        self.budget.mark_exhausted("items_quota_exceeded")
        self.assertFalse(self.budget.reserve(POLLER, 1))
        self.assertFalse(self.budget.reserve(ONE_OFF, 1))

    def test_development_only_spends_on_one_offs(self):
        with self.settings(DEBUG=True):
            self.assertFalse(self.budget.reserve(POLLER, 1))
            self.assertFalse(self.budget.reserve(SCHEDULED, 1))
            self.assertTrue(self.budget.reserve(ONE_OFF, 1))
        with self.settings(DEBUG=True, REDLISTEN_BACKGROUND_IN_DEBUG=True):
            self.assertTrue(self.budget.reserve(POLLER, 1))

    def test_a_profiled_production_task_still_spends_in_the_background(self):
        # DBProfilerMiddleware.process_celery saves the real DEBUG and turns DEBUG on.
        with self.settings(DEBUG=True, ORIGINAL_DEBUG=False):
            self.assertTrue(self.budget.reserve(SCHEDULED, 1))
        with self.settings(DEBUG=True, ORIGINAL_DEBUG=True):
            self.assertFalse(self.budget.reserve(SCHEDULED, 1))

    def test_minute_window(self):
        with self.settings(REDLISTEN_REQUESTS_PER_MINUTE=2):
            self.assertTrue(self.budget.reserve_minute_slot())
            self.assertTrue(self.budget.reserve_minute_slot())
            self.assertFalse(self.budget.reserve_minute_slot())
        self.assertEqual(self.r.ttl("redlisten:ratelimit"), 60)

    def test_last_day_spend_blends_in_the_rest_of_yesterday(self):
        yesterday = NOW - datetime.timedelta(days=1)
        self.r.hset(
            self.budget.spend_key(yesterday), mapping={"scheduled_requests": 100, "scheduled_results": 1000}
        )
        self.r.hset(self.budget.spend_key(), mapping={"scheduled_requests": 40, "scheduled_results": 400})
        # Noon: half of yesterday is still inside the last 24 hours.
        self.assertEqual(self.budget.last_day_spend(SCHEDULED), (90, 900))


class Test_CountResults(SimpleTestCase):
    def test_listing_counts_posts_and_comments_only(self):
        payload = {"data": {"children": [{"kind": "t3"}, {"kind": "t3"}, {"kind": "more"}]}}
        self.assertEqual(count_results(payload), 2)

    def test_thread_counts_the_post_and_nested_replies(self):
        reply = {"kind": "t1", "data": {"replies": ""}}
        comment = {"kind": "t1", "data": {"replies": {"data": {"children": [reply, reply]}}}}
        thread = [{"data": {"children": [{"kind": "t3", "data": {}}]}}, {"data": {"children": [comment]}}]
        self.assertEqual(count_results(thread), 4)

    def test_nothing_returned_counts_nothing(self):
        self.assertEqual(count_results(None), 0)


@override_settings(**SMALL_PLAN)
class Test_RedListenClient(SimpleTestCase):
    def setUp(self):
        self.r = FakeRedis()
        self.budget = RedListenBudget(r=self.r, now=NOW)
        self.client = RedListenClient(budget=self.budget)

    @patch("utils.redlisten.requests.get")
    def test_successful_get_bills_what_came_back(self, mock_get):
        mock_get.return_value = http_response(200, listing([post("a"), post("b"), post("c")]))
        result = self.client.get("/r/python+golang/new.json", {"limit": 25}, kind=POLLER, max_results=25)

        self.assertTrue(result.ok)
        self.assertEqual(result.results, 3)
        self.assertEqual(self.budget.usage()["results"], 3)
        self.assertEqual(self.budget.usage()["requests"], 1)
        url = mock_get.call_args[0][0]
        self.assertEqual(url, "https://api.redlisten.com/r/python+golang/new.json")
        self.assertEqual(mock_get.call_args[1]["headers"]["Authorization"], "Bearer rl_test_key")

    @patch("utils.redlisten.requests.get")
    def test_spent_budget_sends_nothing(self, mock_get):
        self.r.hset(self.budget.usage_key(), mapping={"requests": 0, "results": 990})
        result = self.client.get("/r/python/new.json", kind=SCHEDULED, max_results=25)
        self.assertEqual(result.denied, DENIED_BUDGET)
        self.assertTrue(result.throttled)
        mock_get.assert_not_called()

    @patch("utils.redlisten.requests.get")
    def test_quota_429_stops_spending_until_the_month_rolls_over(self, mock_get):
        body = {
            "error": {
                "status": 429,
                "code": "items_quota_exceeded",
                "message": "Monthly feed item quota reached.",
            }
        }
        mock_get.return_value = http_response(429, body)
        result = self.client.get("/r/python/new.json", kind=ONE_OFF, max_results=25)
        self.assertTrue(result.throttled)
        self.assertEqual(result.error_code, "items_quota_exceeded")
        self.assertFalse(self.budget.reserve(ONE_OFF, 1))

    @patch("utils.redlisten.requests.get")
    def test_missing_key_sends_nothing(self, mock_get):
        with self.settings(REDLISTEN_API_KEY=None):
            result = self.client.get("/r/python/new.json")
        self.assertEqual(result.denied, DENIED_NOT_CONFIGURED)
        mock_get.assert_not_called()


class Test_Allocate(SimpleTestCase):
    def test_everyone_gets_everything_when_the_budget_covers_it(self):
        self.assertEqual(allocate({"a": 3, "b": 4}, {"a": 1, "b": 1}, 10), {"a": 3, "b": 4})

    def test_shares_follow_readers_and_quiet_targets_keep_everything(self):
        shares = allocate({"popular": 10, "busy": 10, "quiet": 1}, {"popular": 10, "busy": 1, "quiet": 1}, 12)
        self.assertAlmostEqual(shares["popular"], 10, places=3)
        self.assertAlmostEqual(shares["busy"], 1, places=3)
        self.assertAlmostEqual(shares["quiet"], 1, places=3)
        self.assertAlmostEqual(sum(shares.values()), 12, places=3)


def target(key, readers=1, feed_ids=(), last_polled=0, posts=0, window=0):
    t = PollTarget(key, {"posts": posts, "window": window, "updated": NOW_TS, "last_polled": last_polled})
    t.readers = readers
    t.feed_ids = list(feed_ids)
    return t


class Test_BuildBatches(SimpleTestCase):
    def test_quiet_targets_drain_and_busy_ones_share_a_page(self):
        targets = [target("r:quiet%d" % i) for i in range(3)] + [target("r:busy%d" % i) for i in range(3)]
        demands = {t.key: (2 if "quiet" in t.key else 200) for t in targets}
        shares = {t.key: (2 if "quiet" in t.key else 40) for t in targets}
        batches = build_batches(targets, demands, shares, is_user=False)

        drained = [b for b in batches if b.drain]
        capped = [b for b in batches if not b.drain]
        self.assertEqual(len(drained), 1)
        self.assertEqual(len(drained[0].targets), 3)
        # Capped shares of 40 + 40 fit one page of 100; the third starts another.
        self.assertEqual([len(b.targets) for b in capped], [2, 1])
        self.assertEqual(capped[0].first_limit(), 80)
        path, params = capped[0].request(capped[0].first_limit())
        self.assertEqual(path, "/r/busy0+busy1/new.json")
        self.assertEqual(params, {"limit": 80})

    def test_user_batches_search_by_author(self):
        batch = PollBatch(drain=True, is_user=True)
        batch.add(target("u:alice"), 1, 1)
        batch.add(target("u:bob"), 1, 1)
        path, params = batch.request(10, after="t3_x")
        self.assertEqual(path, "/search.json")
        self.assertEqual(params["q"], "author:alice OR author:bob")
        self.assertEqual(params["sort"], "new")
        self.assertEqual(params["after"], "t3_x")


class FakeClient:
    """Answers RedListenPoller's requests from a queue of payloads, recording each call."""

    def __init__(self, payloads):
        self.payloads = list(payloads)
        self.calls = []

    def get(self, path, params=None, kind=SCHEDULED, max_results=25, timeout=30):
        self.calls.append((path, dict(params or {}), kind, max_results))
        payload = self.payloads.pop(0)
        return RedListenResult(status=200, payload=payload, results=count_results(payload))


class EndlessListingClient:
    """Answers every request with a full page of fresh posts from the requested subreddits,
    the way a busy batch would page forever, recording each call."""

    def __init__(self):
        self.calls = []
        self.served = 0

    def get(self, path, params=None, kind=SCHEDULED, max_results=25, timeout=30):
        self.calls.append((path, dict(params or {}), kind, max_results))
        subreddit = path.split("/")[2].split("+")[0]
        posts = []
        for _ in range(params["limit"]):
            self.served += 1
            posts.append(post("e%d" % self.served, subreddit=subreddit, created=NOW_TS - 10 * self.served))
        payload = listing(posts, after="t3_e%d" % self.served)
        return RedListenResult(status=200, payload=payload, results=len(posts))


@override_settings(**SMALL_PLAN)
@patch("utils.redlisten_poller.time.sleep")
class Test_RedListenPoller(SimpleTestCase):
    def setUp(self):
        self.r = FakeRedis()
        self.budget = RedListenBudget(r=self.r, now=NOW)

    def poller(self, payloads):
        client = FakeClient(payloads)
        poller = RedListenPoller(budget=self.budget, client=client, r=self.r, now=NOW)
        return poller, client

    def test_drained_batch_pages_back_to_the_previous_poll(self, _sleep):
        python = target("r:python", feed_ids=[11, 12], last_polled=NOW_TS - 3600)
        golang = target("r:golang", feed_ids=[13], last_polled=NOW_TS - 3600)
        batch = PollBatch(drain=True, is_user=False)
        batch.add(python, 3, 3)
        batch.add(golang, 2, 2)
        first_limit = batch.first_limit()
        page_one = [post("p%d" % i, created=NOW_TS - 60 * (i + 1)) for i in range(first_limit)]
        page_two = [post("g1", subreddit="golang", created=NOW_TS - 3000), post("old", created=NOW_TS - 7200)]
        poller, client = self.poller([listing(page_one, after="t3_last"), listing(page_two)])

        self.assertTrue(poller.poll_batch(batch))

        self.assertEqual(len(client.calls), 2)
        self.assertEqual(client.calls[0][0], "/r/python+golang/new.json")
        self.assertEqual(client.calls[1][1]["after"], "t3_last")
        # The first page posted 12 in 720 seconds, so the 3,180 seconds left back to the
        # previous poll should hold about 53 posts: ceil(53 * 1.3) + 5.
        self.assertEqual(client.calls[1][1]["limit"], 74)
        self.assertEqual(client.calls[0][2], POLLER)
        cache = RedditPostCache(r=self.r)
        self.assertEqual([p["id"] for p in cache.posts(["r:golang"])], ["g1"])
        self.assertEqual(poller.feeds_to_schedule, {11, 12, 13})
        self.assertEqual(python.last_polled, NOW_TS)
        # Every post since the previous poll (less the overlap) was seen, so the rate
        # sample is the posts in that window over the window.
        window = 3600 + 5 * 60
        self.assertEqual(golang.window, window)
        self.assertEqual(golang.posts, 1)

    def test_capped_batch_takes_one_page_and_learns_from_its_span(self, _sleep):
        busy = target("r:busy", feed_ids=[21])
        batch = PollBatch(drain=False, is_user=False)
        batch.add(busy, 50, 3)
        page = [post("b%d" % i, subreddit="busy", created=NOW_TS - 100 * (i + 1)) for i in range(3)]
        poller, client = self.poller([listing(page, after="t3_more")])

        self.assertTrue(poller.poll_batch(batch))

        self.assertEqual(len(client.calls), 1)
        self.assertEqual(client.calls[0][1]["limit"], 3)
        # Three posts span the 300 seconds back to the oldest of them.
        self.assertEqual((busy.posts, busy.window), (3, 300))

    def test_a_first_poll_schedules_feeds_even_without_new_posts(self, _sleep):
        """A feed still backed off from Reddit's 401s rereads the cache and clears its error
        once its subreddit is first polled, even if nothing new was posted."""
        quiet = target("r:quiet", feed_ids=[41])
        batch = PollBatch(drain=True, is_user=False)
        batch.add(quiet, 1, 1)
        poller, _ = self.poller([listing([])])

        poller.poll_batch(batch)

        self.assertEqual(poller.feeds_to_schedule, {41})
        self.assertEqual(quiet.last_polled, NOW_TS)

    def test_posts_already_cached_do_not_reschedule_feeds(self, _sleep):
        quiet = target("r:quiet", feed_ids=[31], last_polled=NOW_TS - 3600)
        RedditPostCache(r=self.r).add("r:quiet", [post("q1", subreddit="quiet")])
        batch = PollBatch(drain=True, is_user=False)
        batch.add(quiet, 1, 1)
        poller, _ = self.poller([listing([post("q1", subreddit="quiet")])])

        poller.poll_batch(batch)

        self.assertEqual(poller.feeds_to_schedule, set())

    def test_run_spends_the_hours_share_and_schedules_feeds(self, _sleep):
        targets = {
            "r:python": target("r:python", readers=5, feed_ids=[1], last_polled=NOW_TS - 3600),
            "r:golang": target("r:golang", readers=1, feed_ids=[2], last_polled=NOW_TS - 3600),
        }
        payload = listing([post("p1"), post("g1", subreddit="golang")])
        poller, client = self.poller([payload])
        # The small plan's 99 requests and 990 results a month are under one request and
        # its smallest first page per hour; use Pro's.
        with self.settings(REDLISTEN_MONTHLY_REQUESTS=50000, REDLISTEN_MONTHLY_RESULTS=1000000), patch.object(
            RedListenPoller, "load_targets", return_value=targets
        ):
            summary = poller.poll()

        self.assertEqual(len(client.calls), 1)
        self.assertEqual(summary["spent_results"], 2)
        self.assertEqual(summary["scheduled_feeds"], 2)
        self.assertIsNotNone(self.r.zscore("scheduled_updates", 1))
        self.assertIn("r:python", self.r.hgetall(STATS_KEY))
        self.assertEqual(json.loads(self.r.get(LAST_POLL_KEY))["polled_batches"], 1)
        self.assertIsNone(self.r.get("redlisten:poll_lock"))

    def test_a_short_hour_polls_the_longest_waiting_batch_first(self, _sleep):
        """With room for one request, the batch whose targets have waited longest goes first,
        even with fewer readers, so a short budget rotates instead of starving the tail."""
        busy = {"posts": 1000, "window": 86400}
        recently_polled = target("r:popular", readers=10, feed_ids=[1], last_polled=NOW_TS - 3600, **busy)
        never_polled = target("u:starved", readers=1, feed_ids=[2], last_polled=0, **busy)
        targets = {t.key: t for t in (recently_polled, never_polled)}
        poller, client = self.poller([listing([post("s1", author="starved")])])
        # About 1.5 requests and 5 results for this hour.
        with self.settings(REDLISTEN_MONTHLY_REQUESTS=750, REDLISTEN_MONTHLY_RESULTS=2500), patch.object(
            RedListenPoller, "load_targets", return_value=targets
        ):
            summary = poller.poll()

        self.assertEqual(summary["capped_targets"], 2)
        self.assertEqual((summary["batches"], summary["polled_batches"]), (2, 1))
        self.assertEqual([call[0] for call in client.calls], ["/search.json"])
        self.assertEqual(never_polled.last_polled, NOW_TS)

    def test_ties_keep_drained_then_most_read_first(self, _sleep):
        quiet = PollBatch(drain=True, is_user=False)
        quiet.add(target("r:quiet", readers=1, last_polled=NOW_TS - 3600), 1, 1)
        popular = PollBatch(drain=False, is_user=False)
        popular.add(target("r:popular", readers=50, last_polled=NOW_TS - 3600), 50, 5)
        niche = PollBatch(drain=False, is_user=False)
        niche.add(target("r:niche", readers=2, last_polled=NOW_TS - 3600), 50, 1)
        self.assertEqual(sorted([niche, popular, quiet], key=PollBatch.priority), [quiet, popular, niche])

    def test_a_drained_batch_stops_paging_at_the_hours_budget(self, _sleep):
        quiet_until_now = target("r:quiet", feed_ids=[51], last_polled=NOW_TS - 3600)
        batch = PollBatch(drain=True, is_user=False)
        batch.add(quiet_until_now, 1, 1)
        client = EndlessListingClient()
        poller = RedListenPoller(budget=self.budget, client=client, r=self.r, now=NOW)
        poller.result_budget = 50

        poller.poll_batch(batch)

        limits = [call[1]["limit"] for call in client.calls]
        self.assertEqual(sum(limits), 50)
        self.assertEqual(poller.spent_results, 50)
        # Cut short, so the next poll reaches back for the rest.
        self.assertEqual(quiet_until_now.last_polled, NOW_TS - 3600)

    def test_a_poll_never_starts_a_batch_past_the_hours_budget(self, _sleep):
        """A quiet-looking subreddit that turns out busy spends the hour; the capped user
        batch after it waits for the next hour instead of running over."""
        targets = {
            "r:quiet": target("r:quiet", readers=10, feed_ids=[1], last_polled=NOW_TS - 3600),
            "u:busy": target(
                "u:busy", readers=1, feed_ids=[2], last_polled=NOW_TS - 3600, posts=1000, window=86400
            ),
        }
        client = EndlessListingClient()
        poller = RedListenPoller(budget=self.budget, client=client, r=self.r, now=NOW)
        with patch.object(RedListenPoller, "cycle_budget", return_value=(50.0, 100.0)), patch.object(
            RedListenPoller, "load_targets", return_value=targets
        ):
            summary = poller.poll()

        self.assertEqual(summary["spent_results"], 50)
        self.assertEqual((summary["batches"], summary["polled_batches"]), (2, 1))
        self.assertTrue(all(call[0].startswith("/r/quiet/") for call in client.calls))

    def test_a_poll_that_outlived_its_lock_leaves_the_next_polls_lock(self, _sleep):
        poller, _ = self.poller([])

        def next_poll_takes_the_lock():
            self.r.set("redlisten:poll_lock", "next-poll")

        with patch.object(RedListenPoller, "run", side_effect=next_poll_takes_the_lock):
            poller.poll()
        self.assertEqual(self.r.get("redlisten:poll_lock"), "next-poll")

    def test_no_poll_in_development_or_while_another_runs(self, _sleep):
        poller, client = self.poller([])
        with self.settings(DEBUG=True):
            self.assertIsNone(poller.poll())
        self.r.set("redlisten:poll_lock", 1)
        self.assertIsNone(poller.poll())
        self.assertEqual(client.calls, [])

    def test_cycle_budget_spreads_the_month_and_sets_aside_feeds_and_one_offs(self, _sleep):
        self.r.hset(self.budget.usage_key(), mapping={"requests": 9, "results": 270})
        poller, _ = self.poller([])
        hours_left = (datetime.datetime(2026, 12, 1) - NOW).total_seconds() / 3600
        results, requests = poller.cycle_budget()
        self.assertAlmostEqual(results, (990 - 270) / hours_left)
        self.assertAlmostEqual(requests, (99 - 9) / hours_left)

        # Comment/search feeds and readers' one-offs both get their 24-hour pace set aside
        # through month end, for requests as well as results.
        self.r.hset(
            self.budget.spend_key(),
            mapping={
                "scheduled_requests": 1,
                "scheduled_results": 10,
                "one_off_requests": 1,
                "one_off_results": 5,
            },
        )
        days_left = hours_left / 24
        results, requests = poller.cycle_budget()
        self.assertAlmostEqual(results, (990 - 270 - 15 * days_left) / hours_left)
        self.assertAlmostEqual(requests, (99 - 9 - 2 * days_left) / hours_left)
        self.assertAlmostEqual(poller.set_aside[0], 2 * days_left)
        self.assertAlmostEqual(poller.set_aside[1], 15 * days_left)
