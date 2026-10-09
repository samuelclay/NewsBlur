"""Behavioral coverage for adding discovery bundles by feed ID without URL discovery."""

import datetime
import json
from unittest.mock import PropertyMock, patch

from django.contrib.auth.models import User
from django.db import connection, transaction
from django.test import TestCase
from django.test.utils import CaptureQueriesContext

from apps.discover.models import PopularFeed
from apps.feed_import.models import OPMLImporter
from apps.profile.models import Profile
from apps.reader.models import UserSubscription, UserSubscriptionFolders
from apps.reader.subscription_batch import add_feed_ids
from apps.reader.tasks import MaintainFeedSubscriptions
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
        self.maintenance = patch("apps.reader.tasks.MaintainFeedSubscriptions.delay").start()
        self.setup_premium = Feed.setup_feed_for_premium_subscribers
        self.count_subscribers = Feed.count_subscribers
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
            self.assertEqual("", result["message"])
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
        self.activity.assert_not_called()

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
        self.assertEqual("Invalid feed ID.", result["message"])
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

    def test_uncatalogued_zero_and_one_subscriber_feeds_are_private(self):
        original = self.tree()
        Feed.objects.filter(pk=self.first.pk).update(num_subscribers=0)
        Feed.objects.filter(pk=self.second.pk).update(num_subscribers=1)
        result = self.post([self.first.pk, self.second.pk], folder_path="[]", new_folder="Private")
        self.assertEqual([-1, -1], [item["code"] for item in result["results"]])
        self.assertFalse(
            UserSubscription.objects.filter(user=self.user, feed__in=[self.first, self.second]).exists()
        )
        self.assertEqual(original, self.tree())

    def test_existing_private_subscriptions_can_be_placed_and_reactivated(self):
        newsletter = Feed.objects.create(feed_address="newsletter:existing", num_subscribers=0)
        branch = Feed.objects.create(
            feed_address="https://private.example/existing", branch_from_feed=self.first, num_subscribers=1
        )
        Feed.objects.filter(pk=self.first.pk).update(num_subscribers=0)
        Feed.objects.filter(pk=self.second.pk).update(num_subscribers=1)
        feeds = [self.first, self.second, newsletter, branch]
        for feed in feeds:
            UserSubscription.objects.create(user=self.user, feed=feed, active=False)
        result = self.post([feed.pk for feed in feeds], folder_path="[]", new_folder="Existing")
        self.assertEqual([1] * len(feeds), [item["code"] for item in result["results"]])
        self.assertTrue(all(not item["created"] for item in result["results"]))
        self.assertEqual(
            len(feeds), UserSubscription.objects.filter(user=self.user, feed__in=feeds, active=True).count()
        )
        self.assertIn({"Existing": [feed.pk for feed in feeds]}, self.tree())

    def test_staff_can_add_uncatalogued_zero_and_one_subscriber_feeds(self):
        self.user.is_staff = True
        self.user.save(update_fields=["is_staff"])
        Feed.objects.filter(pk=self.first.pk).update(num_subscribers=0)
        Feed.objects.filter(pk=self.second.pk).update(num_subscribers=1)
        result = self.post([self.first.pk, self.second.pk], folder_path="[]", new_folder="Staff")
        self.assertEqual([1, 1], [item["code"] for item in result["results"]])
        self.assertEqual(
            2, UserSubscription.objects.filter(user=self.user, feed__in=[self.first, self.second]).count()
        )

    def test_multiple_invalid_inputs_each_receive_a_result(self):
        invalid = ["garbage", "other", "garbage", 0, -1, True, "01", 2147483648]
        result = self.post(
            json.dumps([self.first.pk, *invalid, self.first.pk]), folder_path="[]", new_folder="Mixed"
        )
        self.assertEqual(0, result["code"])
        self.assertEqual([self.first.pk, *invalid], [item["feed_id"] for item in result["results"]])
        self.assertEqual([1] + [-1] * len(invalid), [item["code"] for item in result["results"]])
        self.assertTrue(all(item["message"] == "Invalid feed ID." for item in result["results"][1:]))
        self.assertEqual(1, UserSubscription.objects.filter(user=self.user, feed=self.first).count())

    def test_limit_applies_to_new_subscriptions_but_allows_existing_placement(self):
        UserSubscription.objects.create(user=self.user, feed=self.first, active=True)
        count = UserSubscription.objects.filter(user=self.user, active=True).count()
        with patch.object(Profile, "add_feed_limit", new_callable=PropertyMock, return_value=count):
            result = self.post([self.first.pk, self.second.pk], folder_path="[]", new_folder="Bundle")
        self.assertEqual([1, -1], [item["code"] for item in result["results"]])
        self.assertFalse(UserSubscription.objects.filter(user=self.user, feed=self.second).exists())

    def test_feed_limit_reason_is_available_for_failed_and_partial_batches(self):
        UserSubscription.objects.create(user=self.user, feed=self.first, active=True)
        count = UserSubscription.objects.filter(user=self.user, active=True).count()
        original = self.tree()
        with patch.object(Profile, "add_feed_limit", new_callable=PropertyMock, return_value=count):
            rejected = self.post([self.second.pk], folder_path="[]", new_folder="Rejected")
            self.assertEqual(-1, rejected["code"])
            self.assertEqual(original, self.tree())
            partial = self.post([self.first.pk, self.second.pk], folder_path="[]", new_folder="Partial")
        self.assertEqual(0, partial["code"])
        for result in (rejected, partial):
            with self.subTest(code=result["code"]):
                self.assertIn("limit of %s sites" % count, result.get("message", ""))
                self.assertEqual(result["results"][-1]["message"], result["message"])
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

    def test_import_merges_bundle_placements_added_while_outline_is_processing(self):
        importer = OPMLImporter(
            '<opml version="1.0"><body><outline text="Interests"><outline text="Science">'
            '<outline text="Imported" xmlUrl="https://bundle.example/second" />'
            "</outline></outline></body></opml>",
            self.user,
        )
        process_feed = importer.process_feed

        def overlap(*args, **kwargs):
            folders = process_feed(*args, **kwargs)
            self.post([self.first.pk], folder_path='["Interests"]', new_folder="Science")
            self.post([self.first.pk], folder_path="[]", new_folder="Cooking")
            return folders

        with patch.object(importer, "process_feed", side_effect=overlap):
            importer.process()
        self.assertEqual(
            [
                {"Keep": [1]},
                {"Interests": [{"Science": [2, self.first.pk, self.second.pk]}]},
                {"Cooking": [self.first.pk]},
            ],
            self.tree(),
        )

    def test_batch_returns_without_running_slow_feed_maintenance(self):
        with patch.object(
            Feed, "setup_feed_for_premium_subscribers", side_effect=RuntimeError("Slow search service")
        ):
            result = self.post([self.first.pk], folder_path="[]", new_folder="Science")
        self.assertEqual(1, result["code"])
        self.assertTrue(UserSubscription.objects.filter(user=self.user, feed=self.first).exists())

    def test_import_does_not_restore_folders_removed_while_resolving_feeds(self):
        importer = OPMLImporter(
            '<opml version="1.0"><body><outline text="Imported" '
            'xmlUrl="https://bundle.example/second" /></body></opml>',
            self.user,
        )
        process_feed = importer.process_feed

        def overlap(*args, **kwargs):
            folders = process_feed(*args, **kwargs)
            UserSubscriptionFolders.objects.filter(user=self.user).update(folders='[{"Latest": []}]')
            return folders

        with patch.object(importer, "process_feed", side_effect=overlap):
            importer.process()
        self.assertEqual([{"Latest": []}, self.second.pk], self.tree())

    def test_maintenance_waits_for_commit_and_is_discarded_on_rollback(self):
        callback_start = len(connection.run_on_commit)
        with transaction.atomic():
            result = self.post([self.first.pk], folder_path="[]", new_folder="Science")
            self.assertEqual(1, result["code"])
            self.maintenance.assert_not_called()
        callbacks = connection.run_on_commit[callback_start:]
        self.assertEqual(2, len(callbacks))
        # test_batch_subscriptions.py executes Django 3.1's captured callbacks; TestCase never commits its outer transaction.
        with patch("apps.reader.subscription_batch.redis.Redis"):
            for _, callback in callbacks:
                callback()
        self.maintenance.assert_called_once_with(self.user.pk, [(self.first.pk, True)], [self.first.pk])

        callback_start = len(connection.run_on_commit)
        with self.assertRaises(RuntimeError), transaction.atomic():
            self.post([self.second.pk], folder_path="[]", new_folder="Rolled back")
            raise RuntimeError("Abort enclosing transaction")
        self.assertEqual(callback_start, len(connection.run_on_commit))
        self.assertFalse(UserSubscription.objects.filter(user=self.user, feed=self.second).exists())

    def test_worker_maintains_changed_feeds_and_only_records_new_subscriptions(self):
        with patch.object(Feed, "setup_feed_for_premium_subscribers") as setup, patch(
            "apps.search.models.MUserSearch.schedule_index_feeds_for_search"
        ) as index, patch("apps.reader.tasks.redis.Redis") as redis_client:
            MaintainFeedSubscriptions.run(
                self.user.pk,
                [(self.first.pk, True), (self.second.pk, False)],
                [self.first.pk, self.second.pk],
            )
        self.activity.assert_called_once_with(
            user_id=self.user.pk, feed_id=self.first.pk, feed_title=self.first.title
        )
        self.assertEqual(2, setup.call_count)
        index.assert_called_once_with([self.first.pk, self.second.pk], self.user.pk)
        redis_client.return_value.publish.assert_called_once_with(self.user.username, "reload:feeds")

    def test_worker_refreshes_counts_before_scheduling_and_syncing_first_archive_subscriber(self):
        self.user.profile.is_premium = True
        self.user.profile.is_archive = True
        self.user.profile.last_seen_on = datetime.datetime.now()
        self.user.profile.save()
        Feed.objects.filter(pk=self.first.pk).update(
            num_subscribers=0, active_premium_subscribers=0, archive_count=1
        )
        UserSubscription.objects.create(user=self.user, feed=self.first, active=True)

        def assert_current_counts(feed, **kwargs):
            self.assertEqual(1, feed.num_subscribers)
            self.assertEqual(1, feed.active_premium_subscribers)
            self.assertEqual(1, feed.archive_subscribers)

        # test_batch_subscriptions.py exercises the real setup/count methods, isolating external services.
        with patch.object(Feed, "setup_feed_for_premium_subscribers", self.setup_premium), patch.object(
            Feed, "count_subscribers", self.count_subscribers
        ), patch.object(
            Feed, "counts_converted_to_redis", new_callable=PropertyMock, return_value=False
        ), patch.object(
            Profile, "count_feed_subscribers"
        ), patch.object(
            Feed, "count_similar_feeds"
        ), patch.object(
            Feed, "set_next_scheduled_update", autospec=True, side_effect=assert_current_counts
        ) as schedule, patch.object(
            Feed, "sync_redis", autospec=True, side_effect=assert_current_counts
        ) as sync, patch(
            "apps.reader.tasks.redis.Redis"
        ):
            MaintainFeedSubscriptions.run(self.user.pk, [(self.first.pk, True)], [self.first.pk])
        schedule.assert_called_once()
        sync.assert_called_once()
        self.assertFalse(sync.call_args.kwargs["allow_skip_resync"])
        self.first.refresh_from_db()
        self.assertEqual(1, self.first.num_subscribers)
        self.assertEqual(1, self.first.archive_subscribers)

    def test_twitter_credentials_checked_once_before_folder_locks(self):
        feeds = [
            Feed.objects.create(feed_address="https://twitter.com/%s" % name, num_subscribers=20)
            for name in ["first", "second"]
        ]
        self.user.profile.is_premium = True
        self.user.profile.save()
        with CaptureQueriesContext(connection) as queries, patch(
            "apps.reader.subscription_batch.MSocialServices.get_user"
        ) as get_services:

            def assert_unlocked():
                self.assertFalse(any("FOR UPDATE" in query["sql"] for query in queries.captured_queries))

            check = get_services.return_value.twitter_api.return_value.me
            check.side_effect = assert_unlocked
            result = add_feed_ids(
                self.user, [feed.pk for feed in feeds], folder_path=[], new_folder="Twitter"
            )
        self.assertEqual(1, result["code"])
        self.assertEqual(1, check.call_count)
