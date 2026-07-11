"""Tests for the hourly curated Global Shared Stories river."""

import datetime
from unittest.mock import patch

import redis
from django.conf import settings
from django.contrib.auth.models import User
from django.test import TestCase
from django.test.client import Client
from django.urls import reverse
from django.utils import timezone as django_tz

from apps.rss_feeds.models import MStory
from apps.social.curation import (
    collect_candidates,
    curate_global_shared_stories,
    parse_picks,
    select_by_heuristic,
)
from apps.social.models import MSharedStory, MSocialProfile
from apps.social.rglobal import RGlobalSharedStory
from utils import json_functions as json


class Test_GlobalSharedStories(TestCase):
    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
        "apps/rss_feeds/fixtures/rss_feeds.json",
        "subscriptions.json",
        "apps/rss_feeds/fixtures/gawker1.json",
    ]

    def setUp(self):
        self.client = Client(HTTP_USER_AGENT="Mozilla/5.0")
        self.r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        self.r.delete(RGlobalSharedStory.CURATED_KEY)
        self.addCleanup(lambda: self.r.delete(RGlobalSharedStory.CURATED_KEY))

        self.sharer = User.objects.create_user(username="global-sharer", password="password")
        self.other_sharer = User.objects.create_user(username="global-other", password="password")
        self.private_sharer = User.objects.create_user(username="global-private", password="password")
        self.popular = User.objects.get_or_create(username="popular")[0]
        self.reader = User.objects.get(username="conesus")

        self.user_ids = [
            self.sharer.pk,
            self.other_sharer.pk,
            self.private_sharer.pk,
            self.popular.pk,
        ]
        self.addCleanup(lambda: MSharedStory.objects.filter(user_id__in=self.user_ids).delete())
        self.addCleanup(lambda: MSocialProfile.objects.filter(user_id__in=self.user_ids).delete())
        self.addCleanup(lambda: MStory.objects.filter(story_feed_id__in=[1, 2, 3]).delete())

        private_profile = MSocialProfile.get_user(self.private_sharer.pk)
        private_profile.private = True
        private_profile.save()

        self.story_counter = 0

    def make_story(self, feed_id=1, title="A story worth reading"):
        self.story_counter += 1
        story = MStory(
            story_feed_id=feed_id,
            story_date=django_tz.now(),
            story_title=title,
            story_content="Content of the story",
            story_guid="global-shared-%s" % self.story_counter,
            story_permalink="http://example.com/global-shared-%s" % self.story_counter,
        )
        story.save()

        return story

    def share_story(self, user, story, comments=None, likes=0, minutes_ago=5):
        shared = MSharedStory(
            user_id=user.pk,
            shared_date=datetime.datetime.now() - datetime.timedelta(minutes=minutes_ago),
            story_hash=story.story_hash,
            story_feed_id=story.story_feed_id,
            story_date=story.story_date,
            story_title=story.story_title,
            story_content=story.story_content,
            story_guid=story.story_guid,
            story_permalink=story.story_permalink,
            comments=comments or "",
            has_comments=bool(comments),
            liking_users=list(range(1000, 1000 + likes)),
        )
        shared.save()

        return shared

    def test_collect_candidates_caps_shares_per_user(self):
        """One prolific sharer can't take over the pool."""
        for i in range(5):
            story = self.make_story(title="Prolific story %s" % i)
            self.share_story(self.sharer, story, comments="Worth a read %s" % i)

        candidates = collect_candidates()

        self.assertEqual(len(candidates), 3)

    def test_collect_candidates_excludes_private_and_bot_shares(self):
        """Private blurblogs stay private, and @popular's auto-shares carry no human signal."""
        self.share_story(self.private_sharer, self.make_story(title="Private share"))
        self.share_story(self.popular, self.make_story(title="Bot share"))
        self.share_story(self.sharer, self.make_story(title="Real share"), comments="Read this")

        candidates = collect_candidates()

        self.assertEqual([c["story_title"] for c in candidates], ["Real share"])

    def test_collect_candidates_skips_stories_already_in_the_river(self):
        """A story picked in an earlier hour never comes back up for selection."""
        story = self.make_story(title="Already curated")
        self.share_story(self.sharer, story, comments="Great piece")
        RGlobalSharedStory.add_stories({story.story_hash: story.story_date.timestamp()})

        candidates = collect_candidates()

        self.assertEqual(candidates, [])

    def test_collect_candidates_ignores_stale_shares(self):
        """Only shares inside the lookback window are candidates."""
        self.share_story(self.sharer, self.make_story(title="Old share"), minutes_ago=60 * 24)

        candidates = collect_candidates(hours=6)

        self.assertEqual(candidates, [])

    def test_heuristic_prefers_commented_shares_and_spreads_across_sites(self):
        """The fallback ranks a commented share over a bare one and won't repeat a site."""
        candidates = [
            {"story_hash": "a", "comments": "", "likes": 0, "replies": 0, "feed_title": "Site A"},
            {"story_hash": "b", "comments": "Really good", "likes": 0, "replies": 0, "feed_title": "Site B"},
            {"story_hash": "c", "comments": "Also good", "likes": 0, "replies": 0, "feed_title": "Site B"},
        ]

        picks = select_by_heuristic(candidates, max_picks=4)

        picked_hashes = [candidates[pick["index"]]["story_hash"] for pick in picks]
        self.assertEqual(picked_hashes, ["b", "a"])

    def test_parse_picks_drops_malformed_and_duplicate_ids(self):
        """A hallucinated index or a repeated pick can't put a story in the river."""
        response = """Here you go:
        {"picks": [{"id": 1, "reason": "sharp"}, {"id": 9, "reason": "out of range"},
                   {"id": 1, "reason": "duplicate"}, {"id": "x"}, {"id": 0, "reason": "good"}]}"""

        picks = parse_picks(response, candidate_count=3)

        self.assertEqual([pick["index"] for pick in picks], [1, 0])

    def test_parse_picks_survives_a_non_json_response(self):
        self.assertEqual(parse_picks("I could not find anything good.", candidate_count=3), [])

    def test_curate_adds_the_models_picks_to_the_river(self):
        story = self.make_story(title="Chosen story")
        self.share_story(self.sharer, story, comments="This one is special")
        other = self.make_story(feed_id=2, title="Passed over")
        self.share_story(self.other_sharer, other, comments="Meh")

        def pick_the_chosen_story(candidates, max_picks=8):
            index = next(i for i, c in enumerate(candidates) if c["story_title"] == "Chosen story")
            return [{"index": index, "reason": "sharp writing"}]

        with patch("apps.social.curation.select_with_llm", side_effect=pick_the_chosen_story):
            result = curate_global_shared_stories()

        self.assertEqual(result["picked"], 1)
        self.assertEqual(result["added"], 1)
        self.assertTrue(result["used_llm"])
        self.assertEqual(RGlobalSharedStory.get_story_hashes(), [story.story_hash])

    def test_curate_falls_back_to_the_heuristic_when_the_api_is_unusable(self):
        """An Anthropic outage doesn't stop the river."""
        story = self.make_story(title="Fallback story")
        self.share_story(self.sharer, story, comments="Still worth reading")

        with patch("apps.social.curation.select_with_llm", return_value=None):
            result = curate_global_shared_stories()

        self.assertFalse(result["used_llm"])
        self.assertEqual(result["added"], 1)
        self.assertEqual(RGlobalSharedStory.get_story_hashes(), [story.story_hash])

    def test_curate_adds_nothing_when_no_story_clears_the_bar(self):
        """Haiku is allowed to pick nothing in a quiet hour."""
        self.share_story(self.sharer, self.make_story(title="Not good enough"))

        with patch("apps.social.curation.select_with_llm", return_value=[]):
            result = curate_global_shared_stories()

        self.assertEqual(result["added"], 0)
        self.assertEqual(RGlobalSharedStory.get_story_hashes(), [])

    def test_river_blurblog_serves_the_curated_river(self):
        """river:global reads the curated list, not anybody's social subscriptions."""
        story = self.make_story(title="Curated for everyone")
        self.share_story(self.sharer, story, comments="Worth your time")
        RGlobalSharedStory.add_stories({story.story_hash: story.story_date.timestamp()})
        self.client.force_login(self.reader)

        response = self.client.get(
            reverse("social-river-blurblog"), {"global_feed": "true", "read_filter": "all"}
        )
        content = json.decode(response.content)

        self.assertEqual(response.status_code, 200)
        self.assertEqual([s["story_hash"] for s in content["stories"]], [story.story_hash])
