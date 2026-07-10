"""
Tests for the statistics app, including load time and trending feed functionality.
"""

import datetime
from collections import Counter
from unittest.mock import patch

import redis
from django.conf import settings
from django.test import TestCase

from apps.rss_feeds.models import MStory
from apps.statistics.models import MStatistics
from apps.statistics.rmcp_usage import RMCPUsage
from apps.statistics.rstats import RStats
from apps.statistics.rtrending import RTrendingStory
from apps.statistics.rtrending_subscriptions import RTrendingSubscription


class Test_MStatistics(TestCase):
    """Tests for MStatistics aggregation helpers."""

    def setUp(self):
        self.r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        self._delete_page_load_keys()
        MStatistics.objects.filter(
            key__in=[
                "sites_loaded",
                "avg_time_taken",
                "latest_sites_loaded",
                "latest_avg_time_taken",
                "max_sites_loaded",
                "max_avg_time_taken",
                "last_1_min_time_taken",
            ]
        ).delete()

    def tearDown(self):
        self._delete_page_load_keys()
        MStatistics.objects.filter(
            key__in=[
                "sites_loaded",
                "avg_time_taken",
                "latest_sites_loaded",
                "latest_avg_time_taken",
                "max_sites_loaded",
                "max_avg_time_taken",
                "last_1_min_time_taken",
            ]
        ).delete()

    def _delete_page_load_keys(self):
        for key in self.r.scan_iter(match="PLT:*"):
            self.r.delete(key)

    def _set_page_load_minute(self, minute, count, total_duration):
        prefix = RStats.stats_type("page_load")
        key = f"{prefix}:{minute.strftime('%s')}"
        self.r.set(f"{key}:s", count)
        self.r.set(f"{key}:a", total_duration)

    @patch("apps.statistics.models.round_time")
    def test_collect_statistics_sites_loaded_uses_latest_minute(self, mock_round_time):
        """last_1_min_time_taken should reflect the latest complete minute, not the oldest."""
        fixed_now = datetime.datetime(2026, 3, 23, 12, 0, 0)
        mock_round_time.return_value = fixed_now

        oldest_minute = fixed_now - datetime.timedelta(hours=1)
        latest_minute = fixed_now - datetime.timedelta(minutes=1)

        self._set_page_load_minute(oldest_minute, count=5, total_duration=1.95)  # 390ms
        self._set_page_load_minute(latest_minute, count=4, total_duration=0.44)  # 110ms

        MStatistics.collect_statistics_sites_loaded()

        self.assertEqual(MStatistics.get("last_1_min_time_taken"), 0.11)


class Test_RTrendingStory(TestCase):
    """Tests for the RTrendingStory Redis class that tracks read times."""

    def setUp(self):
        self.r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        for pattern in [
            "fRT:*",
            "sRTi:*",
            "sRTc:*",
            "fRTc:*",
            "sRTud:*",
            "sRTqa:*",
            "trending:*",
        ]:
            for key in self.r.scan_iter(match=pattern):
                self.r.delete(key)

    def tearDown(self):
        for pattern in [
            "fRT:*",
            "sRTi:*",
            "sRTc:*",
            "fRTc:*",
            "sRTud:*",
            "sRTqa:*",
            "trending:*",
        ]:
            for key in self.r.scan_iter(match=pattern):
                self.r.delete(key)

    def test_trending_feeds_sorted_by_read_time(self):
        """Stories aggregate into feeds, sorted by total read time descending."""
        # Feed 100: 30 seconds (two stories)
        RTrendingStory.add_read_time("100:story1", 10)
        RTrendingStory.add_read_time("100:story2", 20)
        # Feed 200: 50 seconds (one story, should be first)
        RTrendingStory.add_read_time("200:story1", 50)
        # Feed 300: 2 seconds (below threshold, should be ignored)
        RTrendingStory.add_read_time("300:story1", 2)

        trending = RTrendingStory.get_trending_feeds(days=1, limit=10)

        self.assertEqual(len(trending), 2)
        self.assertEqual(trending[0], (200, 50))
        self.assertEqual(trending[1], (100, 30))

    def test_invalid_input_ignored(self):
        """Invalid story hashes and short reads don't crash or pollute data."""
        RTrendingStory.add_read_time("invalidhash", 10)
        RTrendingStory.add_read_time("abc:story1", 10)
        RTrendingStory.add_read_time("", 10)
        RTrendingStory.add_read_time(None, 10)

        self.assertEqual(RTrendingStory.get_trending_feeds(days=1, limit=10), [])

    def test_trending_stories_indexed(self):
        """Stories are indexed in sRTi and retrievable via get_trending_stories."""
        RTrendingStory.add_read_time("100:story1", 60)
        RTrendingStory.add_read_time("100:story2", 30)
        RTrendingStory.add_read_time("200:story1", 45)

        stories = RTrendingStory.get_trending_stories(days=1, limit=10)

        self.assertEqual(len(stories), 3)
        self.assertEqual(stories[0], ("100:story1", 60))
        self.assertEqual(stories[1], ("200:story1", 45))
        self.assertEqual(stories[2], ("100:story2", 30))

    def test_reader_counts_and_detailed_metrics(self):
        """Reader counts are tracked separately from read time."""
        # Story with many short reads (20 readers × 5 sec = 100 sec total)
        for _ in range(20):
            RTrendingStory.add_read_time("100:popular", 5)
        # Story with few deep reads (2 readers × 60 sec = 120 sec total)
        RTrendingStory.add_read_time("200:deep", 60)
        RTrendingStory.add_read_time("200:deep", 60)

        detailed = RTrendingStory.get_trending_stories_detailed(days=1, limit=10)

        self.assertEqual(len(detailed), 2)
        # Sorted by total_seconds, so deep story first (120 > 100)
        self.assertEqual(detailed[0]["story_hash"], "200:deep")
        self.assertEqual(detailed[0]["total_seconds"], 120)
        self.assertEqual(detailed[0]["reader_count"], 2)
        self.assertEqual(detailed[0]["avg_seconds_per_reader"], 60.0)

        self.assertEqual(detailed[1]["story_hash"], "100:popular")
        self.assertEqual(detailed[1]["total_seconds"], 100)
        self.assertEqual(detailed[1]["reader_count"], 20)
        self.assertEqual(detailed[1]["avg_seconds_per_reader"], 5.0)

    def test_distinct_user_durations_keep_longest_session_per_user(self):
        """Repeated sessions from one account count as one reader with its longest dwell."""
        RTrendingStory.add_read_time("100:story", 20, user_id=1)
        RTrendingStory.add_read_time("100:story", 45, user_id=1)
        RTrendingStory.add_read_time("100:story", 30, user_id=2)

        durations = RTrendingStory.get_distinct_user_durations(days=1)

        self.assertEqual(sorted(durations["100:story"].values()), [30, 45])

    def test_distinct_user_duration_is_capped(self):
        """A foreground session cannot dominate rankings with an implausibly long duration."""
        RTrendingStory.add_read_time("100:story", 5000, user_id=1)

        durations = RTrendingStory.get_distinct_user_durations(days=1)

        self.assertEqual(durations["100:story"]["1"], RTrendingStory.MAX_READ_TIME_SECONDS)

    def test_quality_actions_are_unique_per_user(self):
        """Saving and sharing the same story still represents one committed reader."""
        RTrendingStory.record_quality_action("100:story", user_id=1)
        RTrendingStory.record_quality_action("100:story", user_id=1)
        RTrendingStory.record_quality_action("100:story", user_id=2)

        actions = RTrendingStory.get_quality_action_users(days=1)

        self.assertEqual(actions["100:story"], {"1", "2"})

    def test_length_aware_long_read_threshold(self):
        """Required dwell scales with article length and remains within sensible bounds."""
        self.assertEqual(RTrendingStory.required_long_read_seconds(600), 45)
        self.assertEqual(RTrendingStory.required_long_read_seconds(1200), 75)
        self.assertEqual(RTrendingStory.required_long_read_seconds(3000), 180)
        self.assertEqual(RTrendingStory.required_long_read_seconds(10000), 180)

    def test_good_read_quality_gate(self):
        """Good Reads needs a commitment action unless four people read deeply."""
        self.assertTrue(RTrendingStory.good_read_qualifies(deep_reader_count=2, action_count=1))
        self.assertTrue(RTrendingStory.good_read_qualifies(deep_reader_count=4, action_count=0))
        self.assertFalse(RTrendingStory.good_read_qualifies(deep_reader_count=3, action_count=0))

    def test_diversity_blocks_cap_sources_topics_and_clusters(self):
        """A 12-story block contains one canonical source, one cluster, and at most three topics."""
        candidates = []
        for i in range(16):
            candidates.append(
                {
                    "story_hash": f"{i}:story",
                    "feed_id": i,
                    "domain": f"source-{i}.example.com",
                    "publisher": f"Source {i}",
                    "topic": "technology" if i < 6 else f"topic-{i}",
                    "cluster_id": "duplicate-cluster" if i in (0, 1) else None,
                    "title_key": f"story {i}",
                }
            )
        candidates.insert(
            2,
            {
                "story_hash": "99:second-source-story",
                "feed_id": 0,
                "domain": "source-0.example.com",
                "publisher": "Source 0",
                "topic": "other",
                "cluster_id": None,
                "title_key": "second source story",
            },
        )

        diversified = RTrendingStory.diversify_candidates(candidates, block_size=12)
        first_block = diversified[:12]

        self.assertEqual(len(first_block), 12)
        self.assertEqual(len({story["feed_id"] for story in first_block}), 12)
        self.assertEqual(len({story["domain"] for story in first_block}), 12)
        self.assertLessEqual(sum(story["topic"] == "technology" for story in first_block), 3)
        self.assertEqual(
            sum(story["cluster_id"] == "duplicate-cluster" for story in diversified),
            1,
        )

    def test_good_reads_reserves_small_feed_slots(self):
        """Good Reads gives four first-page positions to qualified small feeds."""
        candidates = []
        for i in range(16):
            candidates.append(
                {
                    "story_hash": f"{i}:story",
                    "feed_id": i,
                    "domain": f"source-{i}.example.com",
                    "publisher": f"Source {i}",
                    "topic": f"topic-{i}",
                    "cluster_id": None,
                    "title_key": f"story {i}",
                    "active_subscribers": 500 if i < 12 else 25,
                }
            )

        diversified = RTrendingStory.diversify_candidates(candidates, small_feed_slots=4)

        self.assertEqual(
            sum(story["active_subscribers"] <= 50 for story in diversified[:12]),
            4,
        )

    def test_diversity_caps_canonical_sources_at_ten_percent(self):
        """Repeated feeds, domains, and publishers never exceed 10% of a diverse list."""
        candidates = []
        for i in range(20):
            source = 0 if i < 10 else i
            candidates.append(
                {
                    "story_hash": f"{i}:story",
                    "feed_id": source,
                    "domain": f"source-{source}.example.com",
                    "publisher": f"Source {source}",
                    "topic": f"topic-{i}",
                    "cluster_id": None,
                    "title_key": f"story {i}",
                }
            )

        diversified = RTrendingStory.diversify_candidates(candidates)
        counts = Counter(story["feed_id"] for story in diversified)

        self.assertLessEqual(max(counts.values()) / len(diversified), 0.10)

    @patch.object(RTrendingStory, "materialize_diverse_lists")
    def test_refresh_qualifies_two_distinct_length_aware_readers(self, mock_materialize):
        """Hourly refresh adds a text story when two people clear its length-aware dwell."""
        story = MStory(
            story_feed_id=100,
            story_date=datetime.datetime.now(),
            story_title="A substantial test essay",
            story_content="word " * 1200,
            story_guid="distinct-reader-long-read",
            story_permalink="https://example.com/long-read",
        )
        story.save()
        self.addCleanup(lambda: MStory.objects(story_hash=story.story_hash).delete())
        RTrendingStory.add_read_time(story.story_hash, 80, user_id=1)
        RTrendingStory.add_read_time(story.story_hash, 90, user_id=2)
        RTrendingStory.record_quality_action(story.story_hash, user_id=1)

        result = RTrendingStory.refresh_trending_lists(days=1)

        self.assertIsNotNone(self.r.zscore(RTrendingStory.WELL_READ_KEY, story.story_hash))
        self.assertIsNotNone(self.r.zscore(RTrendingStory.LONG_READS_KEY, story.story_hash))
        self.assertIsNotNone(self.r.zscore(RTrendingStory.GOOD_READS_KEY, story.story_hash))
        self.assertEqual(result["well_read"], 1)
        self.assertEqual(result["long_reads"], 1)
        self.assertEqual(result["good_reads"], 1)
        mock_materialize.assert_called_once_with()


class Test_RTrendingSubscription(TestCase):
    """Tests for the RTrendingSubscription class that tracks feed subscription velocity."""

    def setUp(self):
        self.r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        for key in self.r.scan_iter(match="fSub:*"):
            self.r.delete(key)

    def tearDown(self):
        for key in self.r.scan_iter(match="fSub:*"):
            self.r.delete(key)

    def test_subscription_increments_count(self):
        """Each subscription call increments the feed's count."""
        RTrendingSubscription.add_subscription(100)
        RTrendingSubscription.add_subscription(100)
        RTrendingSubscription.add_subscription(100)

        count = RTrendingSubscription.get_feed_subscription_count(100, days=1)
        self.assertEqual(count, 3)

    def test_trending_sorted_by_subscriptions(self):
        """Feeds are sorted by subscription count descending."""
        # Feed 200: 5 subscriptions (should be first)
        for _ in range(5):
            RTrendingSubscription.add_subscription(200)
        # Feed 100: 4 subscriptions
        for _ in range(4):
            RTrendingSubscription.add_subscription(100)
        # Feed 300: 2 subscriptions (below threshold, excluded by default)
        for _ in range(2):
            RTrendingSubscription.add_subscription(300)

        trending = RTrendingSubscription.get_trending_feeds(days=1, limit=10)

        self.assertEqual(len(trending), 2)
        self.assertEqual(trending[0][0], 200)
        self.assertEqual(trending[0][1], 5)
        self.assertEqual(trending[1][0], 100)
        self.assertEqual(trending[1][1], 4)

    def test_min_threshold_filters_feeds(self):
        """Feeds below the minimum threshold are excluded."""
        for _ in range(3):
            RTrendingSubscription.add_subscription(100)

        # Default threshold is 4
        trending = RTrendingSubscription.get_trending_feeds(days=1, limit=10)
        self.assertEqual(len(trending), 0)

        # Override threshold to 3
        trending = RTrendingSubscription.get_trending_feeds(days=1, limit=10, min_subscribers=3)
        self.assertEqual(len(trending), 1)

    def test_invalid_feed_id_ignored(self):
        """Invalid feed IDs don't crash or pollute data."""
        RTrendingSubscription.add_subscription(None)
        RTrendingSubscription.add_subscription(0)
        RTrendingSubscription.add_subscription("")

        trending = RTrendingSubscription.get_trending_feeds(days=1, limit=10, min_subscribers=1)
        # Only the 0 feed_id should be present (it's a valid number)
        self.assertLessEqual(len(trending), 1)

    def test_detailed_metrics(self):
        """Detailed metrics include weighted score and raw counts."""
        for _ in range(5):
            RTrendingSubscription.add_subscription(100)

        detailed = RTrendingSubscription.get_trending_feeds_detailed(days=1, limit=10, min_subscribers=1)

        self.assertEqual(len(detailed), 1)
        self.assertEqual(detailed[0]["feed_id"], 100)
        self.assertEqual(detailed[0]["raw_subscriptions"], 5)
        self.assertEqual(detailed[0]["subscriptions_today"], 5)
        self.assertEqual(detailed[0]["weighted_score"], 5)

    def test_prometheus_stats(self):
        """Prometheus stats return aggregate counts."""
        RTrendingSubscription.add_subscription(100)
        RTrendingSubscription.add_subscription(100)
        RTrendingSubscription.add_subscription(200)

        stats = RTrendingSubscription.get_stats_for_prometheus()

        self.assertEqual(stats["total_subscriptions_today"], 3)
        self.assertEqual(stats["unique_feeds_today"], 2)

    def test_daily_totals(self):
        """Daily totals return subscription counts per day."""
        RTrendingSubscription.add_subscription(100)
        RTrendingSubscription.add_subscription(200)

        totals = RTrendingSubscription.get_daily_totals(days=1)

        self.assertEqual(len(totals), 1)
        self.assertEqual(totals[0][1], 2)  # 2 subscriptions today


class Test_RMCPUsage(TestCase):
    """Tests for Redis-backed MCP usage metrics."""

    def setUp(self):
        self.r = RMCPUsage._get_redis()
        self._delete_mcp_usage_keys()

    def tearDown(self):
        self._delete_mcp_usage_keys()

    def _delete_mcp_usage_keys(self):
        for key in self.r.scan_iter(match="mcp_usage:*"):
            self.r.delete(key)

    def test_record_counts_requests_and_unique_users(self):
        RMCPUsage.record("1")
        RMCPUsage.record("1")
        RMCPUsage.record("2")
        RMCPUsage.record()

        daily = RMCPUsage.get_period_stats(days=1)
        weekly = RMCPUsage.get_period_stats(days=7)
        alltime = RMCPUsage.get_alltime_stats()

        self.assertEqual(daily["requests"], 4)
        self.assertEqual(daily["unique_users"], 2)
        self.assertEqual(weekly["requests"], 4)
        self.assertEqual(weekly["unique_users"], 2)
        self.assertEqual(alltime["requests"], 4)
        self.assertEqual(alltime["unique_users"], 2)

    def test_weekly_unique_users_deduplicates_across_days(self):
        RMCPUsage.record("1")
        RMCPUsage.record("2")

        yesterday = datetime.date.today() - datetime.timedelta(days=1)
        yesterday_key = RMCPUsage._date_key(yesterday)
        self.r.incrby(f"mcp_usage:{yesterday_key}:requests", 3)
        self.r.sadd(f"mcp_usage:{yesterday_key}:users", "2", "3")

        weekly = RMCPUsage.get_period_stats(days=7)

        self.assertEqual(weekly["requests"], 5)
        self.assertEqual(weekly["unique_users"], 3)
