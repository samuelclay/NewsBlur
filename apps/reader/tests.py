import datetime
import re
import threading
import time
from unittest.mock import MagicMock, call, patch

import redis
from django.conf import settings
from django.contrib.auth.models import User
from django.test import TestCase
from django.test.client import Client
from django.urls import reverse

from apps.briefing.models import MBriefingPreferences
from apps.reader.models import UserSubscription
from apps.rss_feeds.models import Feed, MStarredStory, MStarredStoryCounts, MStory
from utils import json_functions as json

# Real time.sleep captured before any test patches apps.reader.models.time.sleep.
# Because apps.reader.models does `import time`, patching apps.reader.models.time.sleep
# replaces sleep on the shared global time module, which would send background daemon
# threads (e.g. pymongo's PeriodicExecutor busy-wait loop) into a full-speed spin. Tests
# route those threads' sleeps back to the real implementation to keep them well-behaved.
_REAL_SLEEP = time.sleep


class Test_ReaderPreferencesBootstrap(TestCase):
    def setUp(self):
        self.client = Client()
        self.user = User.objects.create_user(
            username="prefstest", password="testpass", email="prefs@test.com"
        )
        self.client.login(username="prefstest", password="testpass")

    def test_daily_briefing_preference_defaults_true_in_reader_bootstrap(self):
        response = self.client.get(reverse("index"))
        content = response.content.decode("utf-8")

        self.assertRegex(content, re.compile(r"['\"]briefing_enabled['\"]\s*:\s*true"))

    def test_briefing_generation_preference_is_bootstrapped_on_reload(self):
        MBriefingPreferences(user_id=self.user.pk, enabled=True).save()

        response = self.client.get(reverse("index"))
        content = response.content.decode("utf-8")

        self.assertRegex(content, re.compile(r'"briefing_enabled"\s*:\s*true'))


class Test_RenameStarredTag(TestCase):
    """Tests for renaming starred story tags."""

    def setUp(self):
        self.client = Client()
        # Create test user
        self.user = User.objects.create_user(username="testuser", password="testpass", email="test@test.com")
        self.client.login(username="testuser", password="testpass")

        # Clear any existing starred stories for this user
        MStarredStory.objects(user_id=self.user.pk).delete()
        MStarredStoryCounts.objects(user_id=self.user.pk).delete()

        # Create some starred stories with tags
        self.story1 = MStarredStory(
            user_id=self.user.pk,
            starred_date=datetime.datetime.now(),
            story_feed_id=1,
            story_title="Test Story 1",
            story_guid="guid1",
            user_tags=["oldtag", "othertag"],
        )
        self.story1.save()

        self.story2 = MStarredStory(
            user_id=self.user.pk,
            starred_date=datetime.datetime.now(),
            story_feed_id=1,
            story_title="Test Story 2",
            story_guid="guid2",
            user_tags=["oldtag"],
        )
        self.story2.save()

        self.story3 = MStarredStory(
            user_id=self.user.pk,
            starred_date=datetime.datetime.now(),
            story_feed_id=1,
            story_title="Test Story 3",
            story_guid="guid3",
            user_tags=["anothertag"],
        )
        self.story3.save()

        # Count tags to create the counts entries
        MStarredStoryCounts.count_for_user(self.user.pk)

    def tearDown(self):
        MStarredStory.objects(user_id=self.user.pk).delete()
        MStarredStoryCounts.objects(user_id=self.user.pk).delete()

    def test_rename_tag_updates_all_stories(self):
        """Verify all stories with old tag now have new tag."""
        response = self.client.post(
            reverse("rename-starred-tag"),
            {"old_tag_name": "oldtag", "new_tag_name": "newtag"},
        )
        data = json.decode(response.content)

        self.assertEqual(data["code"], 1)

        # Check stories were updated
        story1 = MStarredStory.objects.get(user_id=self.user.pk, story_guid="guid1")
        story2 = MStarredStory.objects.get(user_id=self.user.pk, story_guid="guid2")

        self.assertIn("newtag", story1.user_tags)
        self.assertNotIn("oldtag", story1.user_tags)
        self.assertIn("othertag", story1.user_tags)  # Other tags preserved

        self.assertIn("newtag", story2.user_tags)
        self.assertNotIn("oldtag", story2.user_tags)

    def test_rename_tag_updates_counts(self):
        """Verify MStarredStoryCounts updated correctly."""
        response = self.client.post(
            reverse("rename-starred-tag"),
            {"old_tag_name": "oldtag", "new_tag_name": "newtag"},
        )
        data = json.decode(response.content)

        self.assertEqual(data["code"], 1)

        # Old tag count should not exist
        old_count = MStarredStoryCounts.objects(user_id=self.user.pk, tag="oldtag").first()
        self.assertIsNone(old_count)

        # New tag count should exist with correct count
        new_count = MStarredStoryCounts.objects(user_id=self.user.pk, tag="newtag").first()
        self.assertIsNotNone(new_count)
        self.assertEqual(new_count.count, 2)

    def test_rename_tag_merge_existing(self):
        """If new tag already exists, counts should merge."""
        # Create a story with the new tag already
        story4 = MStarredStory(
            user_id=self.user.pk,
            starred_date=datetime.datetime.now(),
            story_feed_id=1,
            story_title="Test Story 4",
            story_guid="guid4",
            user_tags=["existingtag"],
        )
        story4.save()

        # Recount to include the new story
        MStarredStoryCounts.count_for_user(self.user.pk)

        # Verify initial counts
        old_count = MStarredStoryCounts.objects(user_id=self.user.pk, tag="oldtag").first()
        existing_count = MStarredStoryCounts.objects(user_id=self.user.pk, tag="existingtag").first()
        self.assertEqual(old_count.count, 2)
        self.assertEqual(existing_count.count, 1)

        # Rename oldtag to existingtag (should merge)
        response = self.client.post(
            reverse("rename-starred-tag"),
            {"old_tag_name": "oldtag", "new_tag_name": "existingtag"},
        )
        data = json.decode(response.content)

        self.assertEqual(data["code"], 1)

        # Old tag should not exist
        old_count = MStarredStoryCounts.objects(user_id=self.user.pk, tag="oldtag").first()
        self.assertIsNone(old_count)

        # Merged tag should have combined count (2 + 1 = 3)
        merged_count = MStarredStoryCounts.objects(user_id=self.user.pk, tag="existingtag").first()
        self.assertIsNotNone(merged_count)
        self.assertEqual(merged_count.count, 3)

    def test_rename_tag_case_insensitive(self):
        """'News' renamed to 'news' should update casing, not create duplicate."""
        # First rename to 'News' (capitalized)
        response = self.client.post(
            reverse("rename-starred-tag"),
            {"old_tag_name": "oldtag", "new_tag_name": "News"},
        )
        data = json.decode(response.content)
        self.assertEqual(data["code"], 1)

        # Now rename 'News' to 'news' (lowercase) - should be same tag, different case
        response = self.client.post(
            reverse("rename-starred-tag"),
            {"old_tag_name": "News", "new_tag_name": "news"},
        )
        data = json.decode(response.content)
        self.assertEqual(data["code"], 1)

        # Should only have one count entry for 'news'
        news_counts = list(MStarredStoryCounts.objects(user_id=self.user.pk, tag__iexact="news"))
        self.assertEqual(len(news_counts), 1)
        self.assertEqual(news_counts[0].tag, "news")

    def test_rename_tag_requires_auth(self):
        """Ensure endpoint requires login."""
        self.client.logout()
        response = self.client.post(
            reverse("rename-starred-tag"),
            {"old_tag_name": "oldtag", "new_tag_name": "newtag"},
        )
        # Should return 403 Forbidden for AJAX requests (ajax_login_required decorator)
        self.assertEqual(response.status_code, 403)

    def test_rename_tag_empty_name_fails(self):
        """Validation: can't rename to empty string."""
        response = self.client.post(
            reverse("rename-starred-tag"),
            {"old_tag_name": "oldtag", "new_tag_name": ""},
        )
        data = json.decode(response.content)
        self.assertEqual(data["code"], -1)

    def test_rename_tag_whitespace_only_fails(self):
        """Validation: can't rename to whitespace-only string."""
        response = self.client.post(
            reverse("rename-starred-tag"),
            {"old_tag_name": "oldtag", "new_tag_name": "   "},
        )
        data = json.decode(response.content)
        self.assertEqual(data["code"], -1)

    def test_rename_tag_too_long_fails(self):
        """Validation: tag name must be 128 characters or less."""
        long_name = "a" * 129
        response = self.client.post(
            reverse("rename-starred-tag"),
            {"old_tag_name": "oldtag", "new_tag_name": long_name},
        )
        data = json.decode(response.content)
        self.assertEqual(data["code"], -1)


class Test_DeleteStarredTag(TestCase):
    """Tests for deleting starred story tags."""

    def setUp(self):
        self.client = Client()
        # Create test user
        self.user = User.objects.create_user(
            username="testuser2", password="testpass", email="test2@test.com"
        )
        self.client.login(username="testuser2", password="testpass")

        # Clear any existing starred stories for this user
        MStarredStory.objects(user_id=self.user.pk).delete()
        MStarredStoryCounts.objects(user_id=self.user.pk).delete()

        # Create some starred stories with tags
        self.story1 = MStarredStory(
            user_id=self.user.pk,
            starred_date=datetime.datetime.now(),
            story_feed_id=1,
            story_title="Test Story 1",
            story_guid="guid1",
            user_tags=["tagtoremove", "othertag"],
        )
        self.story1.save()

        self.story2 = MStarredStory(
            user_id=self.user.pk,
            starred_date=datetime.datetime.now(),
            story_feed_id=1,
            story_title="Test Story 2",
            story_guid="guid2",
            user_tags=["tagtoremove"],
        )
        self.story2.save()

        self.story3 = MStarredStory(
            user_id=self.user.pk,
            starred_date=datetime.datetime.now(),
            story_feed_id=1,
            story_title="Test Story 3",
            story_guid="guid3",
            user_tags=["anothertag"],
        )
        self.story3.save()

        # Count tags to create the counts entries
        MStarredStoryCounts.count_for_user(self.user.pk)

    def tearDown(self):
        MStarredStory.objects(user_id=self.user.pk).delete()
        MStarredStoryCounts.objects(user_id=self.user.pk).delete()

    def test_delete_tag_removes_from_all_stories(self):
        """Tag removed from user_tags list."""
        response = self.client.post(
            reverse("delete-starred-tag"),
            {"tag_name": "tagtoremove"},
        )
        data = json.decode(response.content)

        self.assertEqual(data["code"], 1)

        # Check stories were updated
        story1 = MStarredStory.objects.get(user_id=self.user.pk, story_guid="guid1")
        story2 = MStarredStory.objects.get(user_id=self.user.pk, story_guid="guid2")

        self.assertNotIn("tagtoremove", story1.user_tags)
        self.assertIn("othertag", story1.user_tags)  # Other tags preserved

        self.assertNotIn("tagtoremove", story2.user_tags)

    def test_delete_tag_stories_remain_saved(self):
        """Stories still exist as starred, just without the tag."""
        response = self.client.post(
            reverse("delete-starred-tag"),
            {"tag_name": "tagtoremove"},
        )
        data = json.decode(response.content)

        self.assertEqual(data["code"], 1)

        # All stories should still exist
        self.assertEqual(MStarredStory.objects(user_id=self.user.pk).count(), 3)

    def test_delete_tag_removes_count(self):
        """MStarredStoryCounts entry deleted."""
        response = self.client.post(
            reverse("delete-starred-tag"),
            {"tag_name": "tagtoremove"},
        )
        data = json.decode(response.content)

        self.assertEqual(data["code"], 1)

        # Tag count should not exist
        tag_count = MStarredStoryCounts.objects(user_id=self.user.pk, tag="tagtoremove").first()
        self.assertIsNone(tag_count)

    def test_delete_tag_requires_auth(self):
        """Ensure endpoint requires login."""
        self.client.logout()
        response = self.client.post(
            reverse("delete-starred-tag"),
            {"tag_name": "tagtoremove"},
        )
        # Should return 403 Forbidden for AJAX requests (ajax_login_required decorator)
        self.assertEqual(response.status_code, 403)

    def test_delete_tag_empty_name_fails(self):
        """Validation: can't delete empty tag name."""
        response = self.client.post(
            reverse("delete-starred-tag"),
            {"tag_name": ""},
        )
        data = json.decode(response.content)
        self.assertEqual(data["code"], -1)

    def test_delete_last_tag_on_story(self):
        """Story remains saved with empty user_tags list."""
        # Delete 'tagtoremove' first
        self.client.post(
            reverse("delete-starred-tag"),
            {"tag_name": "tagtoremove"},
        )

        # Story2 now has no tags - verify it still exists
        story2 = MStarredStory.objects.get(user_id=self.user.pk, story_guid="guid2")
        self.assertIsNotNone(story2)
        self.assertEqual(len(story2.user_tags), 0)


class Test_ArchiveBackfillDispatch(TestCase):
    """An archive backfill starts one feed's walk every 10 seconds, which takes hours for a
    big subscription list. Queuing every walk up front left countdown tasks waiting in a
    worker for hours, past the broker's visibility timeout, so the broker handed them out
    again every hour (on 2026-10-10 each feed of a 3,910 feed backfill was walked up to 44
    times). A dispatcher now queues one batch at a time, so no task waits long
    (apps/reader/models.py dispatch_archive_backfill)."""

    def setUp(self):
        self.user = User.objects.create_user(
            username="dispatchtest", password="password", email="dispatch@test.com"
        )
        self.feeds = []
        for i in range(5):
            feed = Feed.objects.create(
                feed_address=f"http://example.com/dispatch{i}.xml",
                feed_link=f"http://example.com/dispatch{i}",
                feed_title=f"Dispatch Feed {i}",
            )
            self.feeds.append(feed)
            UserSubscription.objects.create(user=self.user, feed=feed, active=True)
        self.r = redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)
        self.feeds_key = UserSubscription.archive_backfill_feeds_key(self.user.pk)
        self.claim_key = UserSubscription.archive_backfill_claim_key(self.user.pk)
        for key in (self.feeds_key, self.claim_key):
            self.r.delete(key)
            self.addCleanup(self.r.delete, key)

    def tearDown(self):
        for feed in self.feeds:
            MStory.objects(story_feed_id=feed.pk).delete()

    def _store_feeds(self):
        self.r.rpush(self.feeds_key, *[feed.pk for feed in self.feeds])

    def _dispatch(self):
        UserSubscription.dispatch_archive_backfill(self.user.pk, start_time=1.0, starting_story_count=0)

    @patch("apps.profile.tasks.DispatchArchiveBackfill.apply_async")
    def test_a_backfill_stores_the_users_feeds_and_queues_the_dispatcher(self, mock_dispatch):
        UserSubscription.fetch_archive_feeds_for_user(self.user.pk)

        self.assertEqual(
            [int(feed_id) for feed_id in self.r.lrange(self.feeds_key, 0, -1)],
            [feed.pk for feed in self.feeds],
        )
        mock_dispatch.assert_called_once()
        self.assertEqual(mock_dispatch.call_args[1]["queue"], "search_indexer")

    @patch("apps.reader.models.ARCHIVE_BACKFILL_BATCH_SIZE", 2)
    @patch("apps.profile.tasks.FinishFetchArchiveFeeds.apply_async")
    @patch("apps.profile.tasks.DispatchArchiveBackfill.apply_async")
    @patch("apps.profile.tasks.FetchArchiveFeedsChunk.apply_async")
    def test_each_dispatch_queues_one_batch_ten_seconds_apart(self, mock_chunk, mock_dispatch, mock_finish):
        self._store_feeds()

        self._dispatch()

        self.assertEqual([c[1]["countdown"] for c in mock_chunk.call_args_list], [0, 10])
        self.assertEqual(
            [c[1]["kwargs"]["feed_ids"] for c in mock_chunk.call_args_list],
            [[self.feeds[0].pk], [self.feeds[1].pk]],
        )
        # The next dispatch starts where this batch's spacing ends.
        self.assertEqual(mock_dispatch.call_args[1]["countdown"], 20)
        self.assertEqual(self.r.llen(self.feeds_key), 3)
        mock_finish.assert_not_called()

        self._dispatch()
        self._dispatch()

        self.assertEqual(mock_chunk.call_count, len(self.feeds))
        self.assertEqual(mock_dispatch.call_count, 2)
        # After the last batch, the finish waits out the last walk's time limit.
        mock_finish.assert_called_once()
        finish_kwargs = mock_finish.call_args[1]
        self.assertEqual(finish_kwargs["countdown"], settings.MAX_SECONDS_ARCHIVE_FETCH_SINGLE_FEED)
        self.assertEqual(finish_kwargs["time_limit"], settings.MAX_SECONDS_COMPLETE_ARCHIVE_FETCH)
        self.assertEqual(finish_kwargs["kwargs"]["user_id"], self.user.pk)

    @patch("apps.profile.tasks.DispatchArchiveBackfill.apply_async")
    @patch("apps.profile.tasks.FetchArchiveFeedsChunk.apply_async")
    def test_a_dispatch_that_fails_partway_keeps_the_unqueued_feeds(self, mock_chunk, mock_dispatch):
        """Publishing gives up after about a second of broker errors. Feeds whose walks were
        not queued stay in the list for the dispatcher's retry, and the claim stays."""
        from kombu.exceptions import OperationalError

        self._store_feeds()
        self.r.set(self.claim_key, 1)
        mock_chunk.side_effect = [None, OperationalError("broker dropped")]

        with self.assertRaises(OperationalError):
            self._dispatch()

        self.assertEqual(
            [int(feed_id) for feed_id in self.r.lrange(self.feeds_key, 0, -1)],
            [feed.pk for feed in self.feeds[1:]],
        )
        self.assertTrue(self.r.exists(self.claim_key))

    def test_no_backfill_task_waits_past_the_broker_visibility_timeout(self):
        """Countdown tasks wait unacknowledged in a worker until they run, and a worker that
        is killed rather than stopped hands nothing back: the broker gives its tasks out
        again only once the visibility timeout passes. Every backfill task has to start and
        finish inside that timeout, and the timeout must stay at an hour so a killed worker's
        tasks are never stuck for longer."""
        from apps.reader.models import (
            ARCHIVE_BACKFILL_BATCH_SIZE,
            ARCHIVE_BACKFILL_STAGGER_SECONDS,
        )
        from newsblur_web.celeryapp import app

        visibility_timeout = app.conf.broker_transport_options.get("visibility_timeout", 60 * 60)
        self.assertLessEqual(visibility_timeout, 60 * 60)

        from apps.profile.tasks import FinishFetchArchiveFeeds

        last_walk_countdown = (ARCHIVE_BACKFILL_BATCH_SIZE - 1) * ARCHIVE_BACKFILL_STAGGER_SECONDS
        next_dispatch_countdown = ARCHIVE_BACKFILL_BATCH_SIZE * ARCHIVE_BACKFILL_STAGGER_SECONDS
        finish_countdown = last_walk_countdown + settings.MAX_SECONDS_ARCHIVE_FETCH_SINGLE_FEED
        # A walk waits for its countdown and then runs up to its time limit before it is acknowledged.
        self.assertLess(
            last_walk_countdown + settings.MAX_SECONDS_ARCHIVE_FETCH_SINGLE_FEED, visibility_timeout
        )
        self.assertLess(next_dispatch_countdown, visibility_timeout)
        self.assertLess(finish_countdown, visibility_timeout)
        # The finish's Redis sync can run for most of an hour on a big subscription list, so it
        # is acknowledged when it starts rather than when it ends.
        self.assertFalse(FinishFetchArchiveFeeds.acks_late)


class Test_ArchiveBackfillScheduling(TestCase):
    """Concurrent payment webhooks for one archive upgrade must start one backfill of the
    user's feeds, not one per webhook (apps/reader/models.py schedule_fetch_archive_feeds_for_user)."""

    def setUp(self):
        self.user = User.objects.create_user(
            username="backfillonce", password="password", email="backfillonce@test.com"
        )
        r = redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)
        for key in (
            UserSubscription.archive_backfill_claim_key(self.user.pk),
            UserSubscription.archive_backfill_feeds_key(self.user.pk),
        ):
            r.delete(key)
            self.addCleanup(r.delete, key)

    @patch("apps.profile.tasks.FetchArchiveFeedsForUser.apply_async")
    def test_archive_backfill_is_scheduled_once_while_one_is_running(self, mock_apply):
        UserSubscription.schedule_fetch_archive_feeds_for_user(self.user.pk)
        UserSubscription.schedule_fetch_archive_feeds_for_user(self.user.pk)

        self.assertEqual(mock_apply.call_count, 1)

    @patch("apps.profile.tasks.FetchArchiveFeedsForUser.apply_async")
    def test_a_backfill_that_could_not_be_queued_can_be_scheduled_again(self, mock_apply):
        """A user who paid for Archive must not wait out the claim because the broker was
        briefly unreachable when the first upgrade event tried to queue their backfill."""
        from kombu.exceptions import OperationalError

        mock_apply.side_effect = [OperationalError("broker unreachable"), None]

        with self.assertRaises(OperationalError):
            UserSubscription.schedule_fetch_archive_feeds_for_user(self.user.pk)
        UserSubscription.schedule_fetch_archive_feeds_for_user(self.user.pk)

        self.assertEqual(mock_apply.call_count, 2)

    @patch("apps.profile.tasks.FetchArchiveFeedsForUser.apply_async")
    def test_a_backfill_that_fails_before_queuing_its_feeds_can_be_scheduled_again(self, mock_apply):
        UserSubscription.schedule_fetch_archive_feeds_for_user(self.user.pk)
        with patch.object(
            UserSubscription, "build_archive_backfill", side_effect=RuntimeError("mongo unreachable")
        ):
            with self.assertRaises(RuntimeError):
                UserSubscription.fetch_archive_feeds_for_user(self.user.pk)
        UserSubscription.schedule_fetch_archive_feeds_for_user(self.user.pk)

        self.assertEqual(mock_apply.call_count, 2)

    @patch("apps.profile.tasks.FetchArchiveFeedsForUser.apply_async")
    def test_a_backfill_whose_dispatcher_could_not_be_queued_can_be_scheduled_again(self, mock_apply):
        """No feed walk is queued until the dispatcher runs, so a failure queuing it frees
        the claim without risking walking any feed twice."""
        from kombu.exceptions import OperationalError

        UserSubscription.schedule_fetch_archive_feeds_for_user(self.user.pk)
        with patch(
            "apps.profile.tasks.DispatchArchiveBackfill.apply_async",
            side_effect=OperationalError("broker unreachable"),
        ):
            with self.assertRaises(OperationalError):
                UserSubscription.fetch_archive_feeds_for_user(self.user.pk)
        UserSubscription.schedule_fetch_archive_feeds_for_user(self.user.pk)

        self.assertEqual(mock_apply.call_count, 2)


class Test_FinishArchiveFeedsSyncRedis(TestCase):
    """Tests for sync_redis calls in finish_fetch_archive_feeds (apps/reader/models.py)."""

    def setUp(self):
        self.user = User.objects.create_user(
            username="finishtest", password="password", email="finish@test.com"
        )
        self.feeds = []
        for i in range(3):
            feed = Feed.objects.create(
                feed_address=f"http://example.com/finish{i}.xml",
                feed_link=f"http://example.com/finish{i}",
                feed_title=f"Finish Feed {i}",
            )
            self.feeds.append(feed)
            UserSubscription.objects.create(user=self.user, feed=feed, active=True)

    def tearDown(self):
        for feed in self.feeds:
            MStory.objects(story_feed_id=feed.pk).delete()

    @patch("apps.reader.models.MStory.objects")
    @patch("apps.reader.models.time.sleep")
    @patch("apps.rss_feeds.models.Feed.sync_redis")
    @patch("apps.reader.models.redis.Redis")
    def test_finish_fetch_calls_sync_redis_for_each_feed(
        self, mock_redis_cls, mock_sync_redis, mock_sleep, mock_mstory_objects
    ):
        """finish_fetch_archive_feeds should call sync_redis on each subscribed feed."""
        mock_redis_cls.return_value = MagicMock()
        mock_mstory_objects.return_value.count.return_value = 0

        start_time = time.time()
        UserSubscription.finish_fetch_archive_feeds(self.user.pk, start_time, 0)

        # sync_redis should be called once per feed
        self.assertEqual(
            mock_sync_redis.call_count,
            len(self.feeds),
            f"sync_redis should be called {len(self.feeds)} times, got {mock_sync_redis.call_count}",
        )

    @patch("apps.reader.models.MStory.objects")
    @patch("apps.reader.models.time.sleep")
    @patch("apps.rss_feeds.models.Feed.sync_redis")
    @patch("apps.reader.models.redis.Redis")
    def test_finish_fetch_staggers_sync_redis_with_sleep(
        self, mock_redis_cls, mock_sync_redis, mock_sleep, mock_mstory_objects
    ):
        """finish_fetch_archive_feeds should sleep between sync_redis calls to avoid Redis spike."""
        mock_redis_cls.return_value = MagicMock()
        mock_mstory_objects.return_value.count.return_value = 0

        # Patching apps.reader.models.time.sleep neutralizes sleep on the global time
        # module. Background daemon threads (e.g. pymongo's PeriodicExecutor, whose
        # busy-wait loop calls time.sleep(0.5)) would then spin at full speed, both
        # polluting the call list with tens of thousands of unrelated sleep(0.5) calls
        # and flooding the mock with enough recorded calls to hang the test (an 8-minute
        # CI timeout was observed). So: sleeps from this test's own thread (where the
        # synchronous finish_fetch_archive_feeds runs) are recorded and skipped; sleeps
        # from any other thread run the real sleep so those threads stay well-behaved.
        test_thread = threading.current_thread()
        sleep_calls = []

        def record_sleep(*args, **kwargs):
            if threading.current_thread() is test_thread:
                sleep_calls.append(call(*args, **kwargs))
            else:
                _REAL_SLEEP(*args, **kwargs)

        mock_sleep.side_effect = record_sleep

        start_time = time.time()
        UserSubscription.finish_fetch_archive_feeds(self.user.pk, start_time, 0)

        # sleep(0.5) should be called between feeds (n-1 times for n feeds).
        expected_sleeps = len(self.feeds) - 1
        sleep_half_calls = [c for c in sleep_calls if c == call(0.5)]
        self.assertEqual(
            len(sleep_half_calls),
            expected_sleeps,
            f"time.sleep(0.5) should be called {expected_sleeps} times (between feeds), "
            f"got {len(sleep_half_calls)}",
        )

    @patch("apps.reader.models.MStory.objects")
    @patch("apps.reader.models.time.sleep")
    @patch("apps.rss_feeds.models.Feed.sync_redis")
    @patch("apps.reader.models.redis.Redis")
    def test_finish_fetch_publishes_done_before_sync(
        self, mock_redis_cls, mock_sync_redis, mock_sleep, mock_mstory_objects
    ):
        """finish_fetch_archive_feeds should publish fetch_archive:done to Redis pubsub."""
        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_mstory_objects.return_value.count.return_value = 0

        start_time = time.time()
        UserSubscription.finish_fetch_archive_feeds(self.user.pk, start_time, 0)

        # Verify fetch_archive:done was published
        mock_r.publish.assert_called_with(self.user.username, "fetch_archive:done")
