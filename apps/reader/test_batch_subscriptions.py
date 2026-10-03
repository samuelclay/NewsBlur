"""Behavioral coverage for adding discovery bundles by feed ID without URL discovery."""

import json
from unittest.mock import PropertyMock, patch

from django.contrib.auth.models import User
from django.test import TestCase

from apps.discover.models import PopularFeed
from apps.profile.models import Profile
from apps.reader.models import UserSubscription, UserSubscriptionFolders
from apps.rss_feeds.models import Feed


class Test_BatchSubscriptions(TestCase):
    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
        "apps/rss_feeds/fixtures/rss_feeds.json",
        "subscriptions.json",
        "apps/rss_feeds/fixtures/gawker1.json",
    ]

    def setUp(self):
        self.user = User.objects.get(username="conesus")
        self.client.force_login(self.user)
        self.first = Feed.objects.create(feed_address="https://bundle.example/first", num_subscribers=20)
        self.second = Feed.objects.create(feed_address="https://bundle.example/second", num_subscribers=20)
        self.folders, _ = UserSubscriptionFolders.objects.get_or_create(user=self.user)
        self.folders.folders = json.dumps([{"Keep": [1]}, {"Interests": [{"Science": [2]}]}])
        self.folders.save()
        for target in [
            "apps.social.models.MActivity.new_feed_subscription",
            "apps.statistics.rtrending_subscriptions.RTrendingSubscription.add_subscription",
            "apps.rss_feeds.models.Feed.setup_feed_for_premium_subscribers",
            "apps.rss_feeds.models.Feed.count_subscribers",
            "apps.rss_feeds.models.Feed.schedule_fetch_archive_feed",
            "apps.search.models.MUserSearch.schedule_index_feeds_for_search",
        ]:
            mock = patch(target).start()
            if target.endswith("new_feed_subscription"):
                self.activity = mock
        self.addCleanup(patch.stopall)

    def post(self, feed_ids, **kwargs):
        with patch("apps.reader.views.redis.Redis"), patch("apps.reader.models.redis.Redis"):
            response = self.client.post("/reader/add_feeds", {"feed_ids": feed_ids, **kwargs})
        self.assertEqual(200, response.status_code)
        return json.loads(response.content)

    def tree(self):
        self.folders.refresh_from_db()
        return json.loads(self.folders.folders)

    def test_batch_creates_subscriptions_and_preserves_folder_on_retry(self):
        with patch.object(
            Feed, "get_feed_from_url", side_effect=AssertionError("No URL discovery")
        ), patch.object(Feed, "update", side_effect=AssertionError("No synchronous fetch")):
            result = self.post(
                [self.first.pk, self.second.pk, self.first.pk],
                folder_path='["Interests"]',
                new_folder="Science",
            )
            self.assertEqual(1, result["code"])
            self.assertEqual([self.first.pk, self.second.pk], [item["feed_id"] for item in result["results"]])
            self.assertTrue(all(item["created"] for item in result["results"]))
            retry = self.post(
                [self.first.pk, self.second.pk], folder_path='["Interests"]', new_folder="Science"
            )
        self.assertEqual(1, retry["code"])
        self.assertTrue(all(not item["created"] for item in retry["results"]))
        self.assertEqual(
            [{"Keep": [1]}, {"Interests": [{"Science": [2, self.first.pk, self.second.pk]}]}], self.tree()
        )
        self.assertEqual(
            2,
            UserSubscription.objects.filter(
                user=self.user, feed__in=[self.first, self.second], active=True
            ).count(),
        )
        self.assertEqual(2, self.activity.call_count)

    def test_existing_subscription_gets_new_placement_without_losing_previous(self):
        UserSubscription.objects.create(user=self.user, feed=self.first, active=True)
        self.folders.folders = json.dumps([{"Keep": [self.first.pk]}])
        self.folders.save()
        result = self.post([self.first.pk, self.second.pk], folder_path="[]", new_folder="Bundle")
        self.assertEqual(1, result["code"])
        self.assertFalse(result["results"][0]["created"])
        self.assertEqual(
            [{"Keep": [self.first.pk]}, {"Bundle": [self.first.pk, self.second.pk]}], self.tree()
        )

    def test_mixed_invalid_and_private_ids_leave_successful_feeds_added(self):
        private = Feed.objects.create(feed_address="newsletter:someone-else", num_subscribers=20)
        branch = Feed.objects.create(
            feed_address="https://private.example/secret", branch_from_feed=self.first, num_subscribers=20
        )
        single = Feed.objects.create(feed_address="https://single.example/rss", num_subscribers=1)
        result = self.post(
            [self.first.pk, "invalid", 2147483647, private.pk, branch.pk, single.pk],
            folder_path="[]",
            new_folder="Bundle",
        )
        self.assertEqual(0, result["code"])
        self.assertEqual([1, -1, -1, -1, -1, -1], [item["code"] for item in result["results"]])
        self.assertEqual(
            [self.first.pk],
            list(
                UserSubscription.objects.filter(
                    user=self.user, feed__in=[self.first, private, branch, single]
                ).values_list("feed_id", flat=True)
            ),
        )

    def test_stale_parent_is_rejected_before_any_subscription_or_folder_write(self):
        original = self.tree()
        result = self.post([self.first.pk], folder_path='["Missing"]', new_folder="Bundle")
        self.assertEqual(-1, result["code"])
        self.assertFalse(UserSubscription.objects.filter(user=self.user, feed=self.first).exists())
        self.assertEqual(original, self.tree())

    def test_limit_applies_to_new_subscriptions_but_allows_existing_placement(self):
        UserSubscription.objects.create(user=self.user, feed=self.first, active=True)
        count = UserSubscription.objects.filter(user=self.user, active=True).count()
        with patch.object(Profile, "add_feed_limit", new_callable=PropertyMock, return_value=count):
            result = self.post([self.first.pk, self.second.pk], folder_path="[]", new_folder="Bundle")
        self.assertEqual([1, -1], [item["code"] for item in result["results"]])
        self.assertFalse(UserSubscription.objects.filter(user=self.user, feed=self.second).exists())

    def test_unauthenticated_and_get_requests_cannot_add_subscriptions(self):
        capability = self.client.get("/reader/add_feeds", {"feed_ids": [self.first.pk]})
        self.assertTrue(json.loads(capability.content)["batch_add_supported"])
        self.assertEqual(100, json.loads(capability.content)["max_feeds"])
        self.assertEqual(405, self.client.put("/reader/add_feeds").status_code)
        self.client.logout()
        self.assertEqual(
            403, self.client.post("/reader/add_feeds", {"feed_ids": [self.first.pk]}).status_code
        )
        self.assertFalse(UserSubscription.objects.filter(user=self.user, feed=self.first).exists())

    def test_public_catalog_feeds_with_zero_or_one_subscriber_are_addable(self):
        Feed.objects.filter(pk=self.first.pk).update(num_subscribers=0)
        Feed.objects.filter(pk=self.second.pk).update(num_subscribers=1)
        for feed in [self.first, self.second]:
            PopularFeed.objects.create(
                feed=feed,
                feed_url=feed.feed_address,
                feed_type="rss",
                category="Science",
                title="Public catalog feed",
            )
        result = self.post([self.first.pk, self.second.pk], folder_path="[]", new_folder="Science")
        self.assertEqual(1, result["code"])
        self.assertEqual(
            2, UserSubscription.objects.filter(user=self.user, feed__in=[self.first, self.second]).count()
        )

    def test_muted_subscriptions_do_not_consume_active_feed_limit(self):
        UserSubscription.objects.filter(user=self.user).update(active=False)
        with patch.object(Profile, "add_feed_limit", new_callable=PropertyMock, return_value=1):
            result = self.post([self.first.pk, self.second.pk], folder_path="[]", new_folder="Science")
        self.assertEqual([1, -1], [item["code"] for item in result["results"]])
        self.assertEqual(1, UserSubscription.objects.filter(user=self.user, active=True).count())

    def test_alternate_wire_encodings_and_all_invalid_batch(self):
        original = self.tree()
        result = self.post(["garbage"], folder_path="[]", new_folder="Empty")
        self.assertEqual(-1, result["code"])
        self.assertEqual(original, self.tree())
        result = self.post(
            json.dumps([self.first.pk, self.second.pk]), folder_path="[]", new_folder="Science"
        )
        self.assertEqual(1, result["code"])
        with patch("apps.reader.views.redis.Redis"):
            response = self.client.post(
                "/reader/add_feeds",
                {"feed_ids[]": [self.first.pk], "folder_path": "[]", "new_folder": "science"},
            )
        self.assertEqual(1, json.loads(response.content)["code"])
        self.assertEqual(1, sum(isinstance(item, dict) and "Science" in item for item in self.tree()))

    def test_oversized_batch_is_rejected_without_writes(self):
        original = self.tree()
        result = self.post([self.first.pk] * 101, folder_path="[]", new_folder="Too large")
        self.assertEqual(-1, result["code"])
        self.assertEqual(original, self.tree())
        self.assertFalse(UserSubscription.objects.filter(user=self.user, feed=self.first).exists())
