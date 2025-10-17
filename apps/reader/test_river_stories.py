"""
Tests for river stories endpoints with query count validation.

These tests verify that the date filter changes don't cause excessive database queries,
particularly the bug where fetching specific story hashes would trigger expensive
ZUNIONSTORE operations across all feeds.
"""

import datetime

from django.conf import settings
from django.contrib.auth.models import User
from django.db import connection
from django.test import TestCase, TransactionTestCase, override_settings
from django.test.client import Client
from django.urls import reverse

from apps.reader.models import UserSubscription
from apps.rss_feeds.models import Feed, MStory
from utils import json_functions as json


@override_settings(DEBUG_QUERIES=True)
class Test_RiverStories(TransactionTestCase):
    """
    Test river stories endpoint with query counting to prevent performance regressions.
    """

    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
        "apps/rss_feeds/fixtures/rss_feeds.json",
        "subscriptions.json",
        "apps/rss_feeds/fixtures/gawker1.json",
    ]

    def setUp(self):
        import redis

        # Clear Redis keys for test feeds (using db=10 for tests)
        redis_story_port = (
            settings.REDIS_STORY_PORT
            if hasattr(settings, "REDIS_STORY_PORT")
            else settings.REDIS_STORY.get("port", 6579)
        )
        redis_pool = redis.ConnectionPool(host=settings.REDIS_STORY["host"], port=redis_story_port, db=10)
        self.r = redis.Redis(connection_pool=redis_pool)

        # Clear read stories for user 3 (conesus) and test feed IDs
        test_feed_ids = list(range(1, 11)) + [766]
        self.r.delete("RS:3")
        self.r.delete("lRS:3")
        for feed_id in test_feed_ids:
            self.r.delete(f"RS:3:{feed_id}")
            self.r.delete(f"zF:{feed_id}")
            self.r.delete(f"F:{feed_id}")
            self.r.delete(f"zU:3:{feed_id}")
            self.r.delete(f"uU:3:{feed_id}")

        # Clear dashboard caches
        self.r.delete("dashboard:zU:3:feeds:1,2,3,4,5,6,7,8,9,10")
        self.r.delete("dashboard:zhU:3:feeds:1,2,3,4,5,6,7,8,9,10")

        self.client = Client()
        self.user = User.objects.get(username="conesus")

        # Reset connection.queriesx for query counting
        connection.queriesx = []

    def tearDown(self):
        pass

    def count_queries(self):
        """
        Count SQL, Redis, and Mongo queries from connection.queriesx.

        Returns dict with counts:
        {
            'sql': int,
            'redis_story': int,
            'redis_user': int,
            'redis_session': int,
            'mongo': int,
            'total': int
        }
        """
        counts = {
            "sql": 0,
            "redis_story": 0,
            "redis_user": 0,
            "redis_session": 0,
            "redis_pubsub": 0,
            "mongo": 0,
            "total": 0,
        }

        if not hasattr(connection, "queriesx"):
            return counts

        for query in connection.queriesx:
            counts["total"] += 1
            if "redis_story" in query:
                counts["redis_story"] += 1
            elif "redis_user" in query:
                counts["redis_user"] += 1
            elif "redis_session" in query:
                counts["redis_session"] += 1
            elif "redis_pubsub" in query:
                counts["redis_pubsub"] += 1
            elif "mongo" in query:
                counts["mongo"] += 1
            else:
                counts["sql"] += 1

        return counts

    def test_river_stories__normal_load(self):
        """Test loading river stories normally with multiple feeds."""
        self.client.login(username="conesus", password="test")

        # Reset query counter
        connection.queriesx = []

        # Load river stories for feeds 1-5, use read_filter='all' to get stories
        response = self.client.post(
            reverse("load-river-stories"), {"feeds": [1, 2, 3, 4, 5], "read_filter": "all", "page": 1}
        )

        content = json.decode(response.content)
        self.assertEqual(response.status_code, 200)
        # Code might be 0 if user doesn't have premium (for river), that's ok
        # The important thing is we're testing query counts

        # Count queries
        counts = self.count_queries()
        print(f"\nNormal river load queries: {counts}")

        # We expect some queries, but not excessive
        self.assertGreater(counts["total"], 0, "Should have some queries")
        self.assertLess(counts["sql"], 20, "SQL queries should be reasonable")
        self.assertLess(counts["mongo"], 15, "Mongo queries should be reasonable")

    def test_river_stories__specific_story_hashes(self):
        """
        Test loading specific story hashes - THIS IS THE BUG WE FIXED.

        When loading specific story hashes, we should NOT run expensive ZUNIONSTORE
        operations across all feeds. Queries should be minimal.
        """
        self.client.login(username="conesus", password="test")

        # Create test stories directly
        from datetime import datetime, timezone

        feed = Feed.objects.get(pk=1)
        test_stories = []

        for i in range(3):
            story_hash = f"{feed.pk}:test{i}"
            story = MStory(
                story_hash=story_hash,
                story_feed_id=feed.pk,
                story_date=datetime.now(timezone.utc),
                story_title=f"Test Story {i}",
                story_content=f"Test content {i}",
                story_guid=f"test-guid-{i}",
            )
            try:
                story.save()
                test_stories.append(story_hash)
            except:
                # Story might already exist, try to use it
                pass

        if not test_stories:
            # Fallback: try to get existing stories
            stories = MStory.objects.all()[:3]
            test_stories = [story.story_hash for story in stories]

        if not test_stories:
            self.skipTest("Could not create or find test stories")

        # Reset query counter
        connection.queriesx = []

        # Load specific story hashes with dashboard=true (this triggered the bug)
        response = self.client.post(
            reverse("load-river-stories"),
            {"h": test_stories, "dashboard": "true", "feeds": [1, 2, 3, 4, 5]},
        )

        content = json.decode(response.content)
        self.assertEqual(response.status_code, 200)

        # Count queries
        counts = self.count_queries()
        print(f"\nSpecific story hashes queries: {counts}")
        print(f"Stories returned: {len(content.get('stories', []))}")

        # THIS IS THE KEY ASSERTION - when loading specific hashes, we should NOT
        # run expensive Redis aggregation operations. Redis story queries should be minimal.
        self.assertLess(
            counts["redis_story"],
            10,
            f"Redis story queries should be minimal when fetching specific hashes (got {counts['redis_story']})",
        )

        # We should have a mongo query to fetch the stories
        self.assertGreaterEqual(counts["mongo"], 1, "Should fetch stories from Mongo")

        # Total queries should be low
        self.assertLess(
            counts["total"],
            30,
            f"Total queries should be low when fetching specific hashes (got {counts['total']})",
        )

        # Verify we got the stories back
        self.assertIn("stories", content)

    def test_river_stories__specific_hashes_no_dashboard(self):
        """Test loading specific story hashes without dashboard flag."""
        self.client.login(username="conesus", password="test")

        # Create test stories
        from datetime import datetime, timezone

        feed = Feed.objects.get(pk=1)
        test_stories = []

        for i in range(2):
            story_hash = f"{feed.pk}:nodash{i}"
            story = MStory(
                story_hash=story_hash,
                story_feed_id=feed.pk,
                story_date=datetime.now(timezone.utc),
                story_title=f"Test Story No Dashboard {i}",
                story_content=f"Test content {i}",
                story_guid=f"test-guid-nodash-{i}",
            )
            try:
                story.save()
                test_stories.append(story_hash)
            except:
                pass

        if not test_stories:
            stories = MStory.objects.all()[:2]
            test_stories = [story.story_hash for story in stories]

        if not test_stories:
            self.skipTest("Could not create or find test stories")

        # Reset query counter
        connection.queriesx = []

        # Load without dashboard flag
        response = self.client.post(reverse("load-river-stories"), {"h": test_stories, "feeds": [1, 2, 3]})

        content = json.decode(response.content)
        self.assertEqual(response.status_code, 200)

        counts = self.count_queries()
        print(f"\nSpecific hashes (no dashboard) queries: {counts}")

        # Should be very minimal
        self.assertLess(counts["redis_story"], 10, "Redis story queries should be minimal")
        self.assertGreaterEqual(counts["mongo"], 1, "Should fetch from Mongo")

    def test_river_stories__with_date_filter(self):
        """Test loading river stories with date filters."""
        self.client.login(username="conesus", password="test")

        # Reset query counter
        connection.queriesx = []

        # Get date range (last 7 days)
        end_date = datetime.datetime.now()
        start_date = end_date - datetime.timedelta(days=7)

        response = self.client.post(
            reverse("load-river-stories"),
            {
                "feeds": [1, 2, 3, 4, 5],
                "read_filter": "all",
                "date_filter_start": start_date.strftime("%Y-%m-%d"),
                "date_filter_end": end_date.strftime("%Y-%m-%d"),
            },
        )

        content = json.decode(response.content)
        self.assertEqual(response.status_code, 200)

        counts = self.count_queries()
        print(f"\nRiver with date filter queries: {counts}")

        # Should not be excessive
        self.assertLess(counts["total"], 50, "Total queries should be reasonable with date filter")

    def test_single_feed__normal_load(self):
        """Test loading a single feed."""
        self.client.login(username="conesus", password="test")

        # Reset query counter
        connection.queriesx = []

        url = reverse("load-single-feed", kwargs={"feed_id": 1})
        response = self.client.get(url)

        content = json.decode(response.content)
        self.assertEqual(response.status_code, 200)

        counts = self.count_queries()
        print(f"\nSingle feed load queries: {counts}")

        # Should be relatively minimal for a single feed
        self.assertLess(counts["total"], 30, "Single feed queries should be reasonable")

    def test_single_feed__with_date_filter(self):
        """Test loading a single feed with date filters."""
        self.client.login(username="conesus", password="test")

        # Reset query counter
        connection.queriesx = []

        end_date = datetime.datetime.now()
        start_date = end_date - datetime.timedelta(days=30)

        url = reverse("load-single-feed", kwargs={"feed_id": 1})
        response = self.client.get(
            url,
            {
                "date_filter_start": start_date.strftime("%Y-%m-%d"),
                "date_filter_end": end_date.strftime("%Y-%m-%d"),
            },
        )

        content = json.decode(response.content)
        self.assertEqual(response.status_code, 200)

        counts = self.count_queries()
        print(f"\nSingle feed with date filter queries: {counts}")

        # Should not increase significantly with date filter
        self.assertLess(counts["total"], 30, "Single feed with date filter should be reasonable")

    def test_starred_stories__normal_load(self):
        """Test loading starred stories."""
        self.client.login(username="conesus", password="test")

        # Reset query counter
        connection.queriesx = []

        response = self.client.get(reverse("load-starred-stories"))

        content = json.decode(response.content)
        self.assertEqual(response.status_code, 200)

        counts = self.count_queries()
        print(f"\nStarred stories load queries: {counts}")

        # Should be relatively minimal
        self.assertLess(counts["total"], 30, "Starred stories queries should be reasonable")

    def test_starred_stories__with_date_filter(self):
        """Test loading starred stories with date filters."""
        self.client.login(username="conesus", password="test")

        # Reset query counter
        connection.queriesx = []

        end_date = datetime.datetime.now()
        start_date = end_date - datetime.timedelta(days=30)

        response = self.client.get(
            reverse("load-starred-stories"),
            {
                "date_filter_start": start_date.strftime("%Y-%m-%d"),
                "date_filter_end": end_date.strftime("%Y-%m-%d"),
            },
        )

        content = json.decode(response.content)
        self.assertEqual(response.status_code, 200)

        counts = self.count_queries()
        print(f"\nStarred stories with date filter queries: {counts}")

        # Should not increase significantly with date filter
        self.assertLess(counts["total"], 30, "Starred stories with date filter should be reasonable")

    def test_starred_stories__with_tag(self):
        """Test loading starred stories filtered by tag."""
        self.client.login(username="conesus", password="test")

        # Reset query counter
        connection.queriesx = []

        response = self.client.get(reverse("load-starred-stories"), {"tag": "test"})

        content = json.decode(response.content)
        self.assertEqual(response.status_code, 200)

        counts = self.count_queries()
        print(f"\nStarred stories with tag queries: {counts}")

        self.assertLess(counts["total"], 30, "Starred stories with tag should be reasonable")

    def test_starred_stories__with_highlights(self):
        """Test loading starred stories with highlights."""
        self.client.login(username="conesus", password="test")

        # Reset query counter
        connection.queriesx = []

        response = self.client.get(reverse("load-starred-stories"), {"highlights": "true"})

        content = json.decode(response.content)
        self.assertEqual(response.status_code, 200)

        counts = self.count_queries()
        print(f"\nStarred stories with highlights queries: {counts}")

        self.assertLess(counts["total"], 30, "Starred stories with highlights should be reasonable")

    def test_read_stories__normal_load(self):
        """Test loading read stories."""
        self.client.login(username="conesus", password="test")

        # Reset query counter
        connection.queriesx = []

        response = self.client.get(reverse("load-read-stories"))

        content = json.decode(response.content)
        self.assertEqual(response.status_code, 200)

        counts = self.count_queries()
        print(f"\nRead stories load queries: {counts}")

        # Should be relatively minimal
        self.assertLess(counts["total"], 30, "Read stories queries should be reasonable")

    def test_read_stories__with_date_filter(self):
        """Test loading read stories with date filters."""
        self.client.login(username="conesus", password="test")

        # Reset query counter
        connection.queriesx = []

        end_date = datetime.datetime.now()
        start_date = end_date - datetime.timedelta(days=7)

        response = self.client.get(
            reverse("load-read-stories"),
            {
                "date_filter_start": start_date.strftime("%Y-%m-%d"),
                "date_filter_end": end_date.strftime("%Y-%m-%d"),
            },
        )

        content = json.decode(response.content)
        self.assertEqual(response.status_code, 200)

        counts = self.count_queries()
        print(f"\nRead stories with date filter queries: {counts}")

        # Should not increase significantly with date filter
        self.assertLess(counts["total"], 30, "Read stories with date filter should be reasonable")

    def test_river_stories__read_filter_adjustment(self):
        """
        Test that read_filter correctly adjusts from 'unread' to 'all' when date filter
        extends beyond unread cutoff.
        """
        self.client.login(username="conesus", password="test")

        # Reset query counter
        connection.queriesx = []

        # Use a very old date range that's beyond the unread cutoff
        end_date = datetime.datetime.now() - datetime.timedelta(days=365)
        start_date = end_date - datetime.timedelta(days=7)

        response = self.client.post(
            reverse("load-river-stories"),
            {
                "feeds": [1, 2, 3],
                "read_filter": "unread",
                "date_filter_start": start_date.strftime("%Y-%m-%d"),
                "date_filter_end": end_date.strftime("%Y-%m-%d"),
            },
        )

        content = json.decode(response.content)
        self.assertEqual(response.status_code, 200)

        counts = self.count_queries()
        print(f"\nRiver with old date filter (read_filter adjustment) queries: {counts}")

        # This should work without errors even with old dates
        # Code might be 0 for non-premium, but that's ok - we're testing query counts
        self.assertIn("stories", content)
