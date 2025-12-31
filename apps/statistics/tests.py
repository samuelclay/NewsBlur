"""
Tests for the statistics app, including trending feeds functionality.
"""

import redis
from django.conf import settings
from django.test import TestCase

from apps.statistics.rtrending import RTrendingStory
from apps.statistics.rtrending_subscriptions import RTrendingSubscription


class Test_RTrendingStory(TestCase):
    """Tests for the RTrendingStory Redis class that tracks read times."""

    def setUp(self):
        self.r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        for pattern in ["fRT:*", "sRTi:*", "sRTc:*", "fRTc:*"]:
            for key in self.r.scan_iter(match=pattern):
                self.r.delete(key)

    def tearDown(self):
        for pattern in ["fRT:*", "sRTi:*", "sRTc:*", "fRTc:*"]:
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
