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
        for key in self.r.scan_iter(match="sRT:*"):
            self.r.delete(key)
        for key in self.r.scan_iter(match="fRT:*"):
            self.r.delete(key)

    def tearDown(self):
        for key in self.r.scan_iter(match="sRT:*"):
            self.r.delete(key)
        for key in self.r.scan_iter(match="fRT:*"):
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
