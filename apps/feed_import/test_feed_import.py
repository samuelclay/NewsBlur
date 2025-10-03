import json
import os

from django.contrib.auth.models import User
from django.core.management import call_command
from django.test import TestCase, TransactionTestCase
from django.test.client import Client
from django.urls import reverse

from apps.reader.models import UserSubscription, UserSubscriptionFolders
from apps.rss_feeds.models import DuplicateFeed, Feed, merge_feeds
from utils import json_functions as json_functions


class Test_Import(TransactionTestCase):
    def setUp(self):
        self.client = Client()
        # Create test user instead of using fixtures to avoid conflicts
        from django.contrib.auth.models import User

        self.user = User.objects.create_user(username="conesus", email="samuel@newsblur.com", password="test")
        self.user.set_password("test")
        self.user.save()

    def test_opml_import(self):
        # Reset Feed ID sequence to ensure predictable feed IDs starting at 1
        # This is necessary because TransactionTestCase doesn't reset sequences between tests
        from django.db import connection
        from apps.rss_feeds.models import Feed

        # Only reset sequence if the table exists (to avoid errors on first test)
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT EXISTS (
                    SELECT FROM information_schema.tables
                    WHERE table_schema = 'public'
                    AND table_name = 'feeds'
                )
            """)
            table_exists = cursor.fetchone()[0]

            if table_exists:
                # Reset the Feed ID sequence to 1 so OPML import creates feeds with predictable IDs
                cursor.execute("SELECT setval(pg_get_serial_sequence('feeds', 'id'), 1, false)")

        self.client.login(username="conesus", password="test")
        user = User.objects.get(username="conesus")

        # Verify user has no feeds
        subs = UserSubscription.objects.filter(user=user)
        self.assertEqual(subs.count(), 0)

        f = open(os.path.join(os.path.dirname(__file__), "fixtures/opml.xml"))
        response = self.client.post(reverse("opml-upload"), {"file": f})
        self.assertEqual(response.status_code, 200)

        # Verify user now has feeds
        subs = UserSubscription.objects.filter(user=user)
        self.assertEqual(subs.count(), 54)

        # Verify folder structure is created correctly
        # IMPORTANT: DO NOT REMOVE OR CHANGE THIS EXACT FEED ID LIST
        # This explicit structure verification is intentional and must be preserved.
        # It validates that OPML import creates the exact folder hierarchy with
        # feeds in the correct positions, including nested folders like "The Bloglets".
        # Under no circumstances should this be replaced with a looser check.
        usf = UserSubscriptionFolders.objects.get(user=user)
        folders = json_functions.decode(usf.folders)
        self.assertEqual(
            folders,
            [
                {"New York": [1, 2, 3, 4, 5, 6, 7, 8, 9]},
                {"tech": [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28]},
                {
                    "Blogs": [
                        29,
                        30,
                        31,
                        32,
                        33,
                        34,
                        35,
                        36,
                        37,
                        38,
                        39,
                        40,
                        41,
                        42,
                        43,
                        44,
                        {"The Bloglets": [45, 46, 47, 48, 49]},
                    ]
                },
                {"Cooking": [50, 51, 52, 53]},
                54,
            ],
        )

    def test_opml_import__empty(self):
        self.client.login(username="conesus", password="test")
        user = User.objects.get(username="conesus")

        # Verify user has default feeds
        subs = UserSubscription.objects.filter(user=user)
        self.assertEqual(subs.count(), 0)

        response = self.client.post(reverse("opml-upload"))
        self.assertEqual(response.status_code, 200)

        # Verify user now has feeds
        subs = UserSubscription.objects.filter(user=user)

        self.assertEquals(subs.count(), 0)


class Test_Duplicate_Feeds(TransactionTestCase):
    def test_duplicate_feeds(self):
        # Create test users with unique IDs to avoid conflicts
        from django.contrib.auth.models import User

        User.objects.create_user(pk=101, username="test1", email="test1@example.com", password="test")
        User.objects.create_user(pk=102, username="test2", email="test2@example.com", password="test")

        # had to load the feed data this way to hit the save() override.
        # it wouldn't work with loaddata or fixures

        with open("apps/feed_import/fixtures/duplicate_feeds.json") as json_file:
            feed_data = json.loads(json_file.read())
        feed_data_1 = feed_data[0]
        feed_data_2 = feed_data[1]
        # Include the pk so the feeds match the subscriptions
        feed_1 = Feed(pk=feed_data_1["pk"], **{k: v for k, v in feed_data_1.items() if k != "pk"})
        feed_2 = Feed(pk=feed_data_2["pk"], **{k: v for k, v in feed_data_2.items() if k != "pk"})
        feed_1.save()
        feed_2.save()

        call_command("loaddata", "test_subscriptions.json")

        user_1_feed_subscription = UserSubscription.objects.filter(user__id=101)[0].feed_id
        user_2_feed_subscription = UserSubscription.objects.filter(user__id=102)[0].feed_id

        self.assertNotEqual(user_1_feed_subscription, user_2_feed_subscription)

        original_feed_id = merge_feeds(user_1_feed_subscription, user_2_feed_subscription)

        # After merge, verify the feeds were merged correctly
        user_1_subscriptions = UserSubscription.objects.filter(user__id=101)
        user_2_subscriptions = UserSubscription.objects.filter(user__id=102)

        # User 1 should still have a subscription
        self.assertTrue(user_1_subscriptions.exists(), "User 1 should still have a subscription")

        # Verify the merge worked by checking:
        # 1. The duplicate feed should be deleted
        self.assertFalse(Feed.objects.filter(pk=user_2_feed_subscription).exists(),
                        "Duplicate feed should be deleted after merge")

        # 2. The original feed should still exist
        self.assertTrue(Feed.objects.filter(pk=original_feed_id).exists(),
                       "Original feed should still exist after merge")

        # 3. User 1's subscription should point to the original feed
        user_1_feed_id = user_1_subscriptions[0].feed_id
        self.assertEqual(user_1_feed_id, original_feed_id,
                        f"User 1 should be subscribed to the merged feed {original_feed_id}")

        # 4. A DuplicateFeed record should be created
        from apps.rss_feeds.models import DuplicateFeed
        duplicate_record = DuplicateFeed.objects.filter(duplicate_feed_id=user_2_feed_subscription)
        self.assertTrue(duplicate_record.exists(),
                       "A DuplicateFeed record should track the merged feed")
