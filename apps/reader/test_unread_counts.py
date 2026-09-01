"""
Test for the unread-count recalculation race that produces stuck "phantom" counts.

When a story is marked read in the middle of a feed-score recompute, the recompute
would write back a count computed from its pre-read snapshot AND clear
needs_unread_recalc, clobbering the dirty flag the read just set. The result is a
unread count that is too high and "clean", so no later recount fixes it (only a
manual mark-as-read clears it). This is a lost-update race between marking read and
recomputing scores, and it accumulates on high-traffic feeds that are both read and
recomputed frequently.

The fix (apps/reader/models.py:calculate_feed_scores) snapshots last_read_date before
sampling the unread stories and clears needs_unread_recalc only if last_read_date has
not advanced; otherwise it leaves the feed dirty so the next recount is correct.
"""

import datetime
from unittest.mock import patch

import redis
from django.conf import settings
from django.contrib.auth.models import User
from django.test import TransactionTestCase
from django.utils import timezone as django_tz

from apps.reader.models import RUserStory, UserSubscription
from apps.rss_feeds.models import Feed, MStory


class Test_UnreadRecalcRace(TransactionTestCase):
    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
        "apps/rss_feeds/fixtures/rss_feeds.json",
        "subscriptions.json",
        "apps/rss_feeds/fixtures/gawker1.json",
    ]

    FEED_ID = 1
    USER_ID = 3  # conesus

    def setUp(self):
        # Use the same Redis pool the recompute uses (REDIS_STORY_HASH_POOL is db 1).
        self.r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
        self.user = User.objects.get(pk=self.USER_ID)
        feed = Feed.objects.get(pk=self.FEED_ID)

        # Keep the user "active" so calculate_feed_scores doesn't early-return.
        self.user.profile.last_seen_on = datetime.datetime.now()
        self.user.profile.save()

        MStory.objects(story_feed_id=self.FEED_ID, story_guid__startswith="race-test-").delete()
        self.r.delete("RS:%s" % self.USER_ID)
        self.r.delete("RS:%s:%s" % (self.USER_ID, self.FEED_ID))
        self.r.delete("zF:%s" % self.FEED_ID)
        self.r.delete("zU:%s:%s" % (self.USER_ID, self.FEED_ID))

        # Three fresh, unread stories in the feed's sorted story set.
        self.story_hashes = []
        now_ts = int(django_tz.now().timestamp())
        for i in range(3):
            guid = "race-test-%s-%s" % (self.FEED_ID, i)
            story = MStory(
                story_feed_id=self.FEED_ID,
                story_date=django_tz.now(),
                story_title="Race Test Story %s" % i,
                story_content="Content %s" % i,
                story_guid=guid,
                story_permalink="http://example.com/%s" % guid,
            )
            story.save()
            self.story_hashes.append(story.story_hash)
            self.r.zadd("zF:%s" % self.FEED_ID, {story.story_hash: now_ts})

        # Dirty subscription whose stored count matches the 3 real unread stories.
        UserSubscription.objects.update_or_create(
            user=self.user,
            feed=feed,
            defaults={
                "active": True,
                "unread_count_neutral": 3,
                "unread_count_positive": 0,
                "unread_count_negative": 0,
                "needs_unread_recalc": True,
                "mark_read_date": datetime.datetime.now() - datetime.timedelta(days=1),
                "last_read_date": datetime.datetime.now() - datetime.timedelta(hours=1),
            },
        )

    def tearDown(self):
        for h in self.story_hashes:
            self.r.srem("RS:%s" % self.USER_ID, h)
            self.r.srem("RS:%s:%s" % (self.USER_ID, self.FEED_ID), h)
            self.r.zrem("zF:%s" % self.FEED_ID, h)
            self.r.zrem("zU:%s:%s" % (self.USER_ID, self.FEED_ID), h)
        MStory.objects(story_feed_id=self.FEED_ID, story_guid__startswith="race-test-").delete()

    def test_read_during_recompute_keeps_recalc_flag(self):
        sub = UserSubscription.objects.get(user=self.user, feed_id=self.FEED_ID)
        original_story_hashes = UserSubscription.story_hashes

        def racing_story_hashes(*args, **kwargs):
            # Real snapshot first: it still sees all 3 stories as unread.
            result = original_story_hashes(*args, **kwargs)
            # Then a read lands mid-recompute, exactly like mark_story_ids_as_read:
            # the story enters RS and last_read_date advances.
            RUserStory.mark_read(self.USER_ID, self.FEED_ID, self.story_hashes[0])
            UserSubscription.objects.filter(pk=sub.pk).update(last_read_date=datetime.datetime.now())
            return result

        with patch.object(UserSubscription, "story_hashes", side_effect=racing_story_hashes):
            sub.calculate_feed_scores(silent=True)

        # The count just written is stale (story 0 was read after the snapshot), so the
        # feed MUST stay dirty. Pre-fix the recompute clears the flag -> stuck phantom.
        fresh = UserSubscription.objects.get(pk=sub.pk)
        self.assertTrue(
            fresh.needs_unread_recalc,
            "needs_unread_recalc was clobbered by a read that raced the recompute",
        )

        # And it self-heals: the next (un-raced) recompute lands the correct count of 2
        # and is allowed to clear the flag.
        sub2 = UserSubscription.objects.get(pk=sub.pk)
        sub2.calculate_feed_scores(silent=True)
        healed = UserSubscription.objects.get(pk=sub.pk)
        self.assertEqual(healed.unread_count_neutral, 2)
        self.assertFalse(healed.needs_unread_recalc)

    def test_recompute_clears_flag_when_no_read_races(self):
        """Sanity: with no racing read, the recompute still clears the flag normally."""
        sub = UserSubscription.objects.get(user=self.user, feed_id=self.FEED_ID)
        sub.calculate_feed_scores(silent=True)

        fresh = UserSubscription.objects.get(pk=sub.pk)
        self.assertEqual(fresh.unread_count_neutral, 3)
        self.assertFalse(fresh.needs_unread_recalc)
