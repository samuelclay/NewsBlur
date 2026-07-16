"""Unit tests for utils/domain_fetch_limiter.py.

These avoid the database and the network: Redis is a MagicMock and the budget
settings are overridden per test. See utils/domain_fetch_limiter.py.
"""

from unittest.mock import MagicMock, patch

from django.test import SimpleTestCase, override_settings

from utils.domain_fetch_limiter import (
    MAX_DEFER_SECONDS,
    MIN_DEFER_SECONDS,
    feed_host,
    host_budget_per_minute,
    reserve_fetch_slot,
)


class Test_FeedHost(SimpleTestCase):
    def test_strips_www_and_port(self):
        self.assertEqual(feed_host("https://www.abebooks.com/servlet/SearchResults?x=1"), "abebooks.com")
        self.assertEqual(feed_host("https://arstechnica.com:443/feed/"), "arstechnica.com")

    def test_webfeed_prefix(self):
        self.assertEqual(feed_host("webfeed:https://www.abebooks.com/servlet/x"), "abebooks.com")

    def test_subdomains_are_distinct_hosts(self):
        self.assertEqual(feed_host("https://feeds.feedburner.com/blog"), "feeds.feedburner.com")
        self.assertEqual(feed_host("https://author.substack.com/feed"), "author.substack.com")

    def test_scheme_optional(self):
        self.assertEqual(feed_host("reddit.com/r/python/.rss"), "reddit.com")

    def test_local_addresses_are_not_limited(self):
        self.assertIsNone(feed_host("/srv/newsblur/apps/rss_feeds/fixtures/gawker1.xml"))
        self.assertIsNone(feed_host("http://localhost:8000/feed"))
        self.assertIsNone(feed_host("daily-briefing:12345"))
        self.assertIsNone(feed_host(""))
        self.assertIsNone(feed_host(None))

    def test_userinfo_is_stripped(self):
        self.assertEqual(feed_host("https://user:pass@example.com/feed"), "example.com")


class Test_HostBudget(SimpleTestCase):
    @override_settings(
        DOMAIN_FETCHES_PER_MINUTE=6,
        DOMAIN_FETCHES_PER_MINUTE_OVERRIDES={"youtube.com": 500},
    )
    def test_default_and_override(self):
        self.assertEqual(host_budget_per_minute("abebooks.com"), 6)
        self.assertEqual(host_budget_per_minute("youtube.com"), 500)


@override_settings(DOMAIN_FETCHES_PER_MINUTE=6, DOMAIN_FETCHES_PER_MINUTE_OVERRIDES={})
class Test_ReserveFetchSlot(SimpleTestCase):
    def mock_redis(self, incr_result, ttl_result=30):
        mock_r = MagicMock()
        mock_r.incr.return_value = incr_result
        mock_r.ttl.return_value = ttl_result
        return mock_r

    def test_under_budget_allows(self):
        mock_r = self.mock_redis(incr_result=3)
        with patch("utils.domain_fetch_limiter.redis.Redis", return_value=mock_r):
            allowed, defer_seconds = reserve_fetch_slot("https://example.com/feed.xml")
        self.assertTrue(allowed)
        self.assertEqual(defer_seconds, 0)
        mock_r.incr.assert_called_once_with("domain_fetch:ratelimit:example.com")

    def test_first_claim_of_window_sets_expiry(self):
        mock_r = self.mock_redis(incr_result=1)
        with patch("utils.domain_fetch_limiter.redis.Redis", return_value=mock_r):
            allowed, _ = reserve_fetch_slot("https://example.com/feed.xml")
        self.assertTrue(allowed)
        mock_r.expire.assert_called_once_with("domain_fetch:ratelimit:example.com", 60)

    def test_missing_expiry_is_repaired(self):
        mock_r = self.mock_redis(incr_result=4, ttl_result=-1)
        with patch("utils.domain_fetch_limiter.redis.Redis", return_value=mock_r):
            allowed, _ = reserve_fetch_slot("https://example.com/feed.xml")
        self.assertTrue(allowed)
        mock_r.expire.assert_called_once_with("domain_fetch:ratelimit:example.com", 60)

    def test_over_budget_defers_with_floor(self):
        mock_r = self.mock_redis(incr_result=7)
        with patch("utils.domain_fetch_limiter.redis.Redis", return_value=mock_r):
            allowed, defer_seconds = reserve_fetch_slot("https://example.com/feed.xml")
        self.assertFalse(allowed)
        self.assertEqual(defer_seconds, MIN_DEFER_SECONDS)

    def test_deep_overage_defers_by_position(self):
        # The 600th feed past a budget of 6 waits 100 minutes, its place in line
        # at the domain's sustainable drain rate.
        mock_r = self.mock_redis(incr_result=606)
        with patch("utils.domain_fetch_limiter.redis.Redis", return_value=mock_r):
            allowed, defer_seconds = reserve_fetch_slot("https://example.com/feed.xml")
        self.assertFalse(allowed)
        self.assertEqual(defer_seconds, 6000)

    def test_deferral_is_capped(self):
        mock_r = self.mock_redis(incr_result=100000)
        with patch("utils.domain_fetch_limiter.redis.Redis", return_value=mock_r):
            allowed, defer_seconds = reserve_fetch_slot("https://example.com/feed.xml")
        self.assertFalse(allowed)
        self.assertEqual(defer_seconds, MAX_DEFER_SECONDS)

    def test_throttle_is_recorded_for_tuning(self):
        mock_r = self.mock_redis(incr_result=7)
        with patch("utils.domain_fetch_limiter.redis.Redis", return_value=mock_r):
            reserve_fetch_slot("https://example.com/feed.xml")
        (stats_key, host, count), _ = mock_r.hincrby.call_args
        self.assertTrue(stats_key.startswith("domain_fetch:throttled:"))
        self.assertEqual(host, "example.com")
        self.assertEqual(count, 1)

    def test_allowed_fetch_records_no_stats(self):
        mock_r = self.mock_redis(incr_result=6)
        with patch("utils.domain_fetch_limiter.redis.Redis", return_value=mock_r):
            allowed, _ = reserve_fetch_slot("https://example.com/feed.xml")
        self.assertTrue(allowed)
        mock_r.hincrby.assert_not_called()

    def test_unlimitable_address_skips_redis(self):
        mock_r = self.mock_redis(incr_result=1)
        with patch("utils.domain_fetch_limiter.redis.Redis", return_value=mock_r):
            allowed, defer_seconds = reserve_fetch_slot("/srv/newsblur/fixtures/feed.xml")
        self.assertTrue(allowed)
        self.assertEqual(defer_seconds, 0)
        mock_r.incr.assert_not_called()

    @override_settings(
        DOMAIN_FETCHES_PER_MINUTE=6,
        DOMAIN_FETCHES_PER_MINUTE_OVERRIDES={"youtube.com": 500},
    )
    def test_override_budget_applies(self):
        mock_r = self.mock_redis(incr_result=300)
        with patch("utils.domain_fetch_limiter.redis.Redis", return_value=mock_r):
            allowed, _ = reserve_fetch_slot("https://www.youtube.com/feeds/videos.xml?channel_id=UC1")
        self.assertTrue(allowed)
