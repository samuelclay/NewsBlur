"""
Tests for the statistics app, including trending feeds functionality.
"""

import redis
from django.conf import settings
from django.test import TestCase

from apps.statistics.rtrending import RTrendingStory


class Test_RTrendingStory(TestCase):
    """Tests for the RTrendingStory Redis class that tracks read times."""

    def setUp(self):
        self.r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        for pattern in ["sRT:*", "fRT:*", "sRTi:*", "sRTc:*", "fRTc:*"]:
            for key in self.r.scan_iter(match=pattern):
                self.r.delete(key)

    def tearDown(self):
        for pattern in ["sRT:*", "fRT:*", "sRTi:*", "sRTc:*", "fRTc:*"]:
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
