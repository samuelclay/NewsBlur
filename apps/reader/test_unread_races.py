"""Regression tests for unread-count races between mark-read and recounts.

These reproduce the July 2026 webfeed incident: stale zero badges made an explicit
mark-read a silent no-op, and fetch-time recounts wrote counts computed before a
concurrent mark-read, leaving badges with no unread stories behind them. See
mark_feed_read and calculate_feed_scores in apps/reader/models.py and
count_unreads_for_subscribers in utils/feed_fetcher.py.
"""

import datetime
import time
from unittest.mock import patch

from django.contrib.auth.models import User
from django.test import TestCase

from apps.reader.models import UserSubscription
from apps.rss_feeds.models import Feed, MStory
from utils.feed_fetcher import FeedFetcherWorker


class Test_UnreadRaces(TestCase):
    def setUp(self):
        self.user = User.objects.create_user("racer", "racer@example.com", "password")
        self.user.profile.last_seen_on = datetime.datetime.now()
        self.user.profile.save()
        self.feed = Feed.objects.create(
            feed_address="http://example.com/races.xml",
            feed_link="http://example.com",
            feed_title="Race Feed",
        )
        self.sub = UserSubscription.objects.create(
            user=self.user,
            feed=self.feed,
            active=True,
            mark_read_date=datetime.datetime.now() - datetime.timedelta(days=2),
            last_read_date=datetime.datetime.now() - datetime.timedelta(days=2),
        )

    def tearDown(self):
        MStory.objects(story_feed_id=self.feed.pk).delete()

    def make_story(self, story_date):
        story = MStory(
            story_feed_id=self.feed.pk,
            story_guid=f"http://example.com/story-{story_date:%s}",
            story_date=story_date,
            story_title="A story",
            story_content="Content",
        )
        story.save()
        return story

    def test_forced_mark_feed_read_advances_cutoff_despite_stale_zero_badges(self):
        # Stale-zero badges: counts read 0/0/0 and no recalc flag, but a story
        # newer than the cutoff exists. The badge-trusting skip made an explicit
        # mark-read a silent no-op, so the story resurfaced as unread at the next
        # recount. User actions pass force=True to advance the cutoff anyway.
        story_date = datetime.datetime.now() - datetime.timedelta(hours=6)
        self.make_story(story_date)
        self.feed.last_story_date = story_date
        self.feed.save(update_fields=["last_story_date"])
        old_mark_read = self.sub.mark_read_date

        result = self.sub.mark_feed_read(force=True)

        self.assertTrue(result)
        fresh = UserSubscription.objects.get(pk=self.sub.pk)
        self.assertGreater(fresh.mark_read_date, old_mark_read)
        self.assertGreater(fresh.mark_read_date, story_date)

    def test_unforced_mark_feed_read_still_trusts_zero_badges(self):
        # Internal recount-driven calls keep the badge-trusting skip: forcing
        # there would cement a wrong zero from a racing recount.
        story_date = datetime.datetime.now() - datetime.timedelta(hours=6)
        self.make_story(story_date)
        self.feed.last_story_date = story_date
        self.feed.save(update_fields=["last_story_date"])
        old_mark_read = self.sub.mark_read_date

        result = self.sub.mark_feed_read()

        self.assertIsNone(result)
        fresh = UserSubscription.objects.get(pk=self.sub.pk)
        self.assertEqual(fresh.mark_read_date, old_mark_read)

    def test_recount_discards_stale_counts_when_mark_read_races(self):
        # A recount samples unreads, then a mark-read lands before the write-back.
        # The stale count must not overwrite the mark-read's zeros, and the recalc
        # flag must stay set so the next recount runs from fresh state.
        self.sub.needs_unread_recalc = True
        self.sub.save()
        self.sub.refresh_from_db()

        def concurrent_mark_read(*args, **kwargs):
            UserSubscription.objects.filter(pk=self.sub.pk).update(
                last_read_date=datetime.datetime.now(),
                unread_count_neutral=0,
            )
            return [("%s:aaaaaa" % self.feed.pk, time.time())]

        with patch.object(UserSubscription, "story_hashes", side_effect=concurrent_mark_read), patch.object(
            UserSubscription, "trim_read_stories"
        ):
            self.sub.calculate_feed_scores(silent=True)

        fresh = UserSubscription.objects.get(pk=self.sub.pk)
        self.assertEqual(fresh.unread_count_neutral, 0)
        self.assertTrue(fresh.needs_unread_recalc)

    def test_recount_writes_counts_when_nothing_races(self):
        self.sub.needs_unread_recalc = True
        self.sub.save()
        self.sub.refresh_from_db()

        hashes = [("%s:aaaaaa" % self.feed.pk, time.time())]
        with patch.object(UserSubscription, "story_hashes", return_value=hashes), patch.object(
            UserSubscription, "trim_read_stories"
        ):
            self.sub.calculate_feed_scores(silent=True)

        fresh = UserSubscription.objects.get(pk=self.sub.pk)
        self.assertEqual(fresh.unread_count_neutral, 1)
        self.assertFalse(fresh.needs_unread_recalc)

    def test_count_unreads_flags_subscribers_without_touching_mark_read(self):
        # The fetch-time flag set must be an atomic UPDATE: the old full-model
        # save() wrote back every field from a stale instance, reverting any
        # mark-read that landed in between.
        mark_read = self.sub.mark_read_date
        worker = FeedFetcherWorker(
            {"verbose": False, "updates_off": False, "force": True, "compute_scores": False}
        )
        worker.count_unreads_for_subscribers(self.feed)

        fresh = UserSubscription.objects.get(pk=self.sub.pk)
        self.assertTrue(fresh.needs_unread_recalc)
        self.assertEqual(fresh.mark_read_date, mark_read)

    def test_social_mark_feed_read_accepts_force(self):
        # mark_all_as_read and mark_feed_as_read pass force=True to every
        # subscription type; MSocialSubscription must accept the argument or
        # every user with a blurblog sub gets a TypeError marking all as read.
        import inspect

        from apps.social.models import MSocialSubscription

        self.assertIn("force", inspect.signature(MSocialSubscription.mark_feed_read).parameters)
