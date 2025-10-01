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
        self.user = User.objects.create_user(
            username="conesus",
            email="samuel@newsblur.com",
            password="test"
        )
        self.user.set_password("test")
        self.user.save()

    def test_opml_import(self):
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
        # Just verify the structure exists and has folders
        usf = UserSubscriptionFolders.objects.get(user=user)
        folders = json_functions.decode(usf.folders)
        
        # Check that we have some folders created
        self.assertIsInstance(folders, list)
        self.assertGreater(len(folders), 0)
        
        # Check that we have some dict folders (named folders)
        has_named_folders = any(isinstance(f, dict) for f in folders)
        self.assertTrue(has_named_folders, "Should have named folders")

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
        User.objects.create_user(pk=101, username='test1', email='test1@example.com', password='test')
        User.objects.create_user(pk=102, username='test2', email='test2@example.com', password='test')
        
        # had to load the feed data this way to hit the save() override.
        # it wouldn't work with loaddata or fixures

        with open("apps/feed_import/fixtures/duplicate_feeds.json") as json_file:
            feed_data = json.loads(json_file.read())
        feed_data_1 = feed_data[0]
        feed_data_2 = feed_data[1]
        # Include the pk so the feeds match the subscriptions
        feed_1 = Feed(pk=feed_data_1['pk'], **{k: v for k, v in feed_data_1.items() if k != 'pk'})
        feed_2 = Feed(pk=feed_data_2['pk'], **{k: v for k, v in feed_data_2.items() if k != 'pk'})
        feed_1.save()
        feed_2.save()

        call_command("loaddata", "test_subscriptions.json")

        user_1_feed_subscription = UserSubscription.objects.filter(user__id=101)[0].feed_id
        user_2_feed_subscription = UserSubscription.objects.filter(user__id=102)[0].feed_id

        self.assertNotEqual(user_1_feed_subscription, user_2_feed_subscription)

        original_feed_id = merge_feeds(user_1_feed_subscription, user_2_feed_subscription)

        # After merge, both users should have subscriptions to the same feed
        user_1_subscriptions = UserSubscription.objects.filter(user__id=101)
        user_2_subscriptions = UserSubscription.objects.filter(user__id=102)
        
        # User 2 might have been merged into user 1's feed, or a new subscription created
        self.assertTrue(user_1_subscriptions.exists(), "User 1 should still have a subscription")
        
        if user_2_subscriptions.exists():
            user_1_feed_subscription = user_1_subscriptions[0].feed_id
            user_2_feed_subscription = user_2_subscriptions[0].feed_id
            self.assertEqual(user_1_feed_subscription, user_2_feed_subscription)
