"""Regression coverage for coordinated promotion in public story discovery."""

import datetime
from unittest.mock import patch

from django.contrib.auth.models import User
from django.test import TestCase

from apps.social.curation import collect_candidates
from apps.social.models import MSharedStory, MSocialProfile


class Test_SharedDiscovery(TestCase):
    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
        "apps/rss_feeds/fixtures/rss_feeds.json",
    ]

    def setUp(self):
        self.now = datetime.datetime.now()
        self.users = [User.objects.create_user(username="discovery-%s" % i) for i in range(7)]
        self.user_ids = [user.pk for user in self.users]
        self.addCleanup(lambda: MSharedStory.objects(user_id__in=self.user_ids).delete())
        self.addCleanup(lambda: MSocialProfile.objects(user_id__in=self.user_ids).delete())
        for user in self.users:
            MSocialProfile.get_user(user.pk)
        for method in ("curated_story_hashes", "considered_story_hashes", "muted_user_ids"):
            patcher = patch("apps.social.rglobal.RGlobalSharedStory.%s" % method, return_value=set())
            patcher.start()
            self.addCleanup(patcher.stop)

    def share(self, user, story, comment="thank you", feed_id=1, hours_ago=1):
        # apps/social/test_shared_discovery.py: Save real Mongo documents so both discovery
        # paths exercise their actual queries, aggregation and per-story deduplication.
        return MSharedStory.objects.create(
            user_id=user.pk,
            shared_date=self.now - datetime.timedelta(hours=hours_ago),
            story_date=self.now,
            story_feed_id=feed_id,
            story_guid="discovery-%s-%s" % (feed_id, story),
            story_title="Discovery story %s" % story,
            story_content="A story for discovery regression coverage.",
            comments=comment,
            has_comments=bool(comment),
        )

    def campaign(self):
        for user in self.users[:6]:
            self.share(user, "first", hours_ago=20)
            shared = self.share(user, "second")
        return shared.story_hash

    def test_repeated_comment_campaign_cannot_make_popular(self):
        story_hash = self.campaign()
        stories, _ = MSharedStory.collect_popular_stories()
        self.assertNotIn(story_hash, stories)
        self.assertEqual(stories, {})

    def test_global_uses_history_before_its_six_hour_candidate_window(self):
        self.campaign()
        self.assertEqual(collect_candidates(now=self.now), [])

    def test_independent_reader_can_still_recommend_a_promoted_story(self):
        story_hash = self.campaign()
        self.share(self.users[6], "second", comment="This explains the tradeoffs clearly", hours_ago=2)
        candidates = collect_candidates(now=self.now)
        self.assertEqual(
            [(c["story_hash"], c["username"]) for c in candidates], [(story_hash, self.users[6].username)]
        )
        stories, _ = MSharedStory.collect_popular_stories(cutoff=2)
        self.assertEqual(stories, {})

    def test_one_shared_comment_on_one_story_is_not_a_campaign(self):
        for user in self.users[:6]:
            shared = self.share(user, "one-off")
        stories, _ = MSharedStory.collect_popular_stories()
        self.assertEqual(stories[shared.story_hash]["count"], 6)
        self.assertEqual(len(collect_candidates(now=self.now)), 1)

    def test_two_readers_repeating_comments_are_not_a_campaign(self):
        for user in self.users[:2]:
            self.share(user, "first")
            self.share(user, "second")
        stories, _ = MSharedStory.collect_popular_stories(cutoff=2)
        self.assertEqual(len(stories), 2)
        self.assertEqual(len(collect_candidates(now=self.now)), 2)

    def test_unrelated_shares_from_campaign_accounts_remain_eligible(self):
        self.campaign()
        for user in self.users[:6]:
            shared = self.share(user, "unrelated", comment="Other reading", feed_id=2)
        stories, _ = MSharedStory.collect_popular_stories()
        self.assertEqual(set(stories), {shared.story_hash})
        self.assertEqual([c["story_hash"] for c in collect_candidates(now=self.now)], [shared.story_hash])

    def test_different_groups_using_same_comment_do_not_form_a_campaign(self):
        for user in self.users[:3]:
            self.share(user, "first")
        for user in self.users[3:6]:
            self.share(user, "second")
        stories, _ = MSharedStory.collect_popular_stories(cutoff=3)
        self.assertEqual(len(stories), 2)
        self.assertEqual(len(collect_candidates(now=self.now)), 2)

    def test_comment_formatting_does_not_disguise_a_campaign(self):
        for user, comment in zip(self.users[:3], ["Thank YOU", "<b>thank</b> you", "thank&nbsp; you"]):
            self.share(user, "first", comment=comment)
            self.share(user, "second", comment=comment)
        stories, _ = MSharedStory.collect_popular_stories(cutoff=3)
        self.assertEqual(stories, {})
        self.assertEqual(collect_candidates(now=self.now), [])

    def test_repeated_synchronized_blank_shares_are_excluded(self):
        for index, user in enumerate(self.users[:3]):
            self.share(user, "first", comment="", hours_ago=20 + index / 60)
            self.share(user, "second", comment="", hours_ago=1 + index / 60)
        stories, _ = MSharedStory.collect_popular_stories(cutoff=3)
        self.assertEqual(stories, {})
        self.assertEqual(collect_candidates(now=self.now), [])

    def test_naturally_spread_blank_shares_remain_eligible(self):
        for index, user in enumerate(self.users[:3]):
            self.share(user, "first", comment="", hours_ago=20 + index)
            self.share(user, "second", comment="", hours_ago=1 + index)
        stories, _ = MSharedStory.collect_popular_stories(cutoff=3)
        self.assertEqual(len(stories), 2)
        self.assertEqual(len(collect_candidates(now=self.now)), 1)

    def test_blank_shares_need_a_burst_on_both_stories(self):
        for index, user in enumerate(self.users[:3]):
            self.share(user, "first", comment="", hours_ago=20 + index)
            self.share(user, "second", comment="", hours_ago=1 + index / 60)
        stories, _ = MSharedStory.collect_popular_stories(cutoff=3)
        self.assertEqual(len(stories), 2)
        self.assertEqual(len(collect_candidates(now=self.now)), 1)

    def test_two_overlapping_readers_are_not_enough(self):
        for user in self.users[:3]:
            self.share(user, "first")
        for user in self.users[1:4]:
            self.share(user, "second")
        stories, _ = MSharedStory.collect_popular_stories(cutoff=3)
        self.assertEqual(len(stories), 2)
        self.assertEqual(len(collect_candidates(now=self.now)), 2)

    def test_old_campaign_evidence_expires(self):
        for user in self.users[:3]:
            self.share(user, "first", hours_ago=73)
            shared = self.share(user, "second")
        stories, _ = MSharedStory.collect_popular_stories(cutoff=3)
        self.assertEqual(set(stories), {shared.story_hash})
        self.assertEqual(len(collect_candidates(now=self.now)), 1)
