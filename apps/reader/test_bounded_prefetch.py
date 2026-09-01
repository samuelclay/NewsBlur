"""
Tests for the bounded fetch-time story prefetch used by unread scoring.

count_unreads_for_subscribers (utils/feed_fetcher.py) used to format every story
newer than feed.unread_cutoff before scoring. A single archive subscriber drags
that cutoff back 27 years, so feeds like AP formatted their entire 10k-story
archive (~18s) on every fetch with new stories — while a subscriber's effective
unread window (profile cutoff clamped by mark_read_date) almost never reaches
past DAYS_OF_UNREAD.

The prefetch is now bounded to DAYS_OF_UNREAD and carries its coverage cutoff.
calculate_feed_scores (apps/reader/models.py) compares that cutoff to the
subscriber's own window and falls back to the targeted per-user query whenever
the prefetch does not reach far enough, so archive users with long windows are
never undercounted by the truncated list.
"""

import datetime
from unittest.mock import MagicMock, patch

import redis
from django.conf import settings
from django.contrib.auth.models import User
from django.core.cache import cache
from django.test import TransactionTestCase, override_settings
from django.utils import timezone as django_tz

from apps.analyzer.models import MClassifierTitle
from apps.reader.models import UserSubscription
from apps.rss_feeds.models import Feed, MStory


@override_settings(DAYS_OF_UNREAD=30)
class Test_BoundedScorePrefetch(TransactionTestCase):
    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
        "apps/rss_feeds/fixtures/rss_feeds.json",
        "subscriptions.json",
        "apps/rss_feeds/fixtures/gawker1.json",
    ]

    FEED_ID = 1
    USER_ID = 3  # conesus

    def setUp(self):
        self.r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
        self.user = User.objects.get(pk=self.USER_ID)
        self.feed = Feed.objects.get(pk=self.FEED_ID)

        # Keep the user "active" so calculate_feed_scores doesn't early-return.
        self.user.profile.last_seen_on = datetime.datetime.now()
        self.user.profile.save()

        MStory.objects(story_feed_id=self.FEED_ID, story_guid__startswith="prefetch-test-").delete()
        self.r.delete("RS:%s" % self.USER_ID)
        self.r.delete("RS:%s:%s" % (self.USER_ID, self.FEED_ID))
        self.r.delete("zF:%s" % self.FEED_ID)
        self.r.delete("zU:%s:%s" % (self.USER_ID, self.FEED_ID))
        cache.delete("S:v4:%s" % self.FEED_ID)

        # A title classifier makes the subscription genuinely trained, which is
        # the only path that touches the story prefetch at all.
        MClassifierTitle.objects.create(
            user_id=self.USER_ID,
            feed_id=self.FEED_ID,
            social_user_id=0,
            title="prefetch-test-nomatch",
            score=-1,
        )

        # Two recent stories (inside the DAYS_OF_UNREAD window) and one old story
        # 40 days back — outside the bounded prefetch but still unread.
        self.recent_hashes = []
        self.old_hash = None
        for i, age_days in enumerate([0, 1, 40]):
            story_date = django_tz.now() - datetime.timedelta(days=age_days)
            story = MStory(
                story_feed_id=self.FEED_ID,
                story_date=story_date,
                story_title="Prefetch Test Story %s" % i,
                story_content="Content %s" % i,
                story_guid="prefetch-test-%s-%s" % (self.FEED_ID, i),
                story_permalink="http://example.com/prefetch-test-%s" % i,
            )
            story.save()
            self.r.zadd("zF:%s" % self.FEED_ID, {story.story_hash: int(story_date.timestamp())})
            if age_days < 30:
                self.recent_hashes.append(story.story_hash)
            else:
                self.old_hash = story.story_hash

    def tearDown(self):
        MClassifierTitle.objects(user_id=self.USER_ID, feed_id=self.FEED_ID).delete()
        MStory.objects(story_feed_id=self.FEED_ID, story_guid__startswith="prefetch-test-").delete()
        self.r.delete("RS:%s" % self.USER_ID)
        self.r.delete("RS:%s:%s" % (self.USER_ID, self.FEED_ID))
        self.r.delete("zF:%s" % self.FEED_ID)
        self.r.delete("zU:%s:%s" % (self.USER_ID, self.FEED_ID))
        cache.delete("S:v4:%s" % self.FEED_ID)

    def _make_sub(self, mark_read_days_ago):
        sub, _ = UserSubscription.objects.update_or_create(
            user=self.user,
            feed=self.feed,
            defaults={
                "active": True,
                "is_trained": True,
                "needs_unread_recalc": True,
                "mark_read_date": datetime.datetime.now() - datetime.timedelta(days=mark_read_days_ago),
                "last_read_date": datetime.datetime.now() - datetime.timedelta(days=mark_read_days_ago),
            },
        )
        return sub

    def _bounded_prefetch(self):
        """Format only the stories a bounded fetch-time prefetch would contain."""
        cutoff = datetime.datetime.utcnow() - datetime.timedelta(days=settings.DAYS_OF_UNREAD)
        stories_db = MStory.objects(story_feed_id=self.FEED_ID, story_date__gte=cutoff)
        return Feed.format_stories(stories_db, self.FEED_ID), cutoff

    def test_covered_subscriber_scores_from_prefetch_without_mongo(self):
        """A subscriber whose window fits inside the prefetch must not need the
        targeted per-user story query at all."""
        self.user.profile.is_premium = True
        self.user.profile.is_archive = False
        self.user.profile.save()
        sub = self._make_sub(mark_read_days_ago=10)

        stories, cutoff = self._bounded_prefetch()
        with patch("apps.reader.models.MStory") as mock_mstory:
            sub.calculate_feed_scores(silent=True, stories=stories, stories_cutoff=cutoff)
            mock_mstory.objects.assert_not_called()

        fresh = UserSubscription.objects.get(pk=sub.pk)
        # Both recent stories counted; the 40-day story is outside a premium
        # user's own unread window, so 2 is the correct total here.
        self.assertEqual(fresh.unread_count_neutral, 2)

    def test_archive_subscriber_with_long_window_is_not_undercounted(self):
        """The regression the coverage check exists to prevent: an archive user
        whose unread window reaches past the prefetch bound must fall back to the
        targeted query and still count the old story."""
        self.user.profile.is_archive = True
        self.user.profile.days_of_unread = 9999
        self.user.profile.save()
        sub = self._make_sub(mark_read_days_ago=60)

        stories, cutoff = self._bounded_prefetch()
        self.assertEqual(
            len([s for s in stories if s["story_hash"] == self.old_hash]),
            0,
            "sanity: the bounded prefetch must not contain the 40-day-old story",
        )

        sub.calculate_feed_scores(silent=True, stories=stories, stories_cutoff=cutoff)

        fresh = UserSubscription.objects.get(pk=sub.pk)
        self.assertEqual(
            fresh.unread_count_neutral,
            3,
            "the 40-day-old unread story must be counted via the targeted fallback",
        )

    def test_cache_round_trip_carries_cutoff(self):
        """Scoring outside fetch time reads the S:v4 dict payload and honors its
        coverage cutoff the same way as a passed-in prefetch."""
        self.user.profile.is_archive = True
        self.user.profile.days_of_unread = 9999
        self.user.profile.save()
        sub = self._make_sub(mark_read_days_ago=60)

        stories, cutoff = self._bounded_prefetch()
        cache.set("S:v4:%s" % self.FEED_ID, {"stories": stories, "cutoff": cutoff}, 60)

        sub.calculate_feed_scores(silent=True)

        fresh = UserSubscription.objects.get(pk=sub.pk)
        self.assertEqual(fresh.unread_count_neutral, 3)

    def test_fetcher_bounds_the_prefetch_window(self):
        """count_unreads_for_subscribers must never format the feed's whole
        archive: the Mongo query, the zF reconciliation, and the cache payload
        all use the bounded cutoff."""
        from utils.feed_fetcher import FeedFetcherWorker

        worker = FeedFetcherWorker.__new__(FeedFetcherWorker)
        worker.options = {"compute_scores": True, "verbose": 0}

        feed = MagicMock()
        feed.pk = self.FEED_ID
        feed.unread_cutoff = datetime.datetime(1999, 4, 8)  # archive-wide cutoff
        feed.log_title = "Archive Feed"

        captured = {}

        def capture_mstory(**kwargs):
            captured["mongo_cutoff"] = kwargs.get("story_date__gte")
            return []

        passthrough = {}

        def capture_calc(user_subs, stories, stories_cutoff=None):
            passthrough["cutoff"] = stories_cutoff

        with patch("utils.feed_fetcher.MStory") as mock_mstory, patch(
            "utils.feed_fetcher.Feed"
        ) as mock_feed, patch("utils.feed_fetcher.cache") as mock_cache, patch(
            "utils.feed_fetcher.redis"
        ) as mock_redis, patch(
            "utils.feed_fetcher.UserSubscription"
        ) as mock_us, patch.object(
            FeedFetcherWorker, "calculate_feed_scores_with_stories", side_effect=capture_calc
        ):
            mock_mstory.objects.side_effect = capture_mstory
            mock_feed.format_stories.return_value = []
            mock_redis.Redis.return_value.zrangebyscore.return_value = []
            mock_us.objects.filter.return_value.order_by.return_value.count.return_value = 1

            worker.count_unreads_for_subscribers(feed, new_story_count=0)

        bound = datetime.datetime.utcnow() - datetime.timedelta(days=settings.DAYS_OF_UNREAD + 1)
        self.assertGreater(
            captured["mongo_cutoff"],
            bound,
            "the Mongo prefetch must be bounded to DAYS_OF_UNREAD, not the archive cutoff",
        )

        # zF reconciliation uses the same bound, not the 1999 cutoff.
        zargs = mock_redis.Redis.return_value.zrangebyscore.call_args.args
        self.assertGreater(
            zargs[1],
            int(bound.strftime("%s")),
            "the zF range must be bounded or archive feeds re-fetch everything from primary",
        )

        # The cache payload carries the cutoff for readers to check coverage.
        cache_args = mock_cache.set.call_args.args
        self.assertEqual(cache_args[0], "S:v4:%s" % self.FEED_ID)
        self.assertEqual(cache_args[1]["cutoff"], captured["mongo_cutoff"])

        # And the same cutoff is passed to the scoring loop.
        self.assertEqual(passthrough["cutoff"], captured["mongo_cutoff"])
