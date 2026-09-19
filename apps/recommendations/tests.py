import datetime
from unittest.mock import patch

from django.contrib.auth.models import User
from django.test import Client, TestCase, override_settings
from django.urls import reverse

from apps.reader.models import UserSubscription
from apps.recommendations.discovery import Discovery
from apps.recommendations.models import MRecommendationFeedback
from apps.rss_feeds.models import Feed, MStarredStory, MStory
from apps.social.models import MSharedStory


@override_settings(CACHES={"default": {"BACKEND": "django.core.cache.backends.locmem.LocMemCache"}})
class Test_StoryRecommendationFeedback(TestCase):
    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
        "apps/rss_feeds/fixtures/rss_feeds.json",
    ]

    def setUp(self):
        self.user = User.objects.create_user(username="feedback-reader", password="testpass")
        self.other_user = User.objects.create_user(username="feedback-other", password="testpass")
        self.feed = Feed.objects.get(pk=1)
        self.story = MStory(
            story_feed_id=self.feed.pk,
            story_guid="recommendation-feedback-story",
            story_title="A useful article",
            story_content="<p>Practical article context.</p>",
            story_date=datetime.datetime.utcnow(),
            story_permalink="https://example.com/article",
        ).save()
        self.url = reverse("save-story-feedback")
        self.client.force_login(self.user)

    def tearDown(self):
        MRecommendationFeedback.objects(user_id__in=[self.user.pk, self.other_user.pk]).delete()
        MStory.objects(story_hash=self.story.story_hash).delete()
        MStory.objects(story_guid__startswith="discovery-test-").delete()
        MStarredStory.objects(story_guid__startswith="discovery-test-").delete()
        MSharedStory.objects(story_guid__startswith="discovery-test-").delete()

    def vote(self, value, **extra):
        data = dict(story_hash=self.story.story_hash, value=value, surface="good_reads")
        data.update(extra)
        return self.client.post(self.url, data)

    def test_repeated_vote_replaces_preference_and_undo_restores_previous_value(self):
        for value in [1, 1, -1, 1, 0]:
            self.assertEqual(self.vote(value).json()["value"], value)
            self.assertEqual(MRecommendationFeedback.objects(user_id=self.user.pk).count(), 1)
        feedback = MRecommendationFeedback.objects.get(user_id=self.user.pk)
        self.assertEqual(feedback.value, 0)
        self.assertEqual(feedback.story_title, "A useful article")
        self.assertEqual(feedback.story_excerpt, "Practical article context.")

    def test_feedback_is_account_scoped_and_survives_story_expiry(self):
        self.vote(1, user_id=self.other_user.pk)
        MRecommendationFeedback.record(self.other_user.pk, self.story, -1, "good_reads")
        self.assertEqual(
            MRecommendationFeedback.for_stories(self.user.pk, [self.story.story_hash]),
            {self.story.story_hash: 1},
        )
        self.story.delete()
        self.assertEqual(
            MRecommendationFeedback.objects.get(user_id=self.user.pk).story_title, "A useful article"
        )
        self.assertEqual(MRecommendationFeedback.objects.get(user_id=self.other_user.pk).value, -1)

    def test_feedback_does_not_mark_read_train_filters_or_subscribe(self):
        with patch("apps.reader.models.RUserStory.mark_read") as mark_read, patch(
            "apps.analyzer.views.save_classifier"
        ) as save_classifier:
            self.assertEqual(self.vote(-1).json()["code"], 1)
        mark_read.assert_not_called()
        save_classifier.assert_not_called()
        self.assertFalse(UserSubscription.objects.filter(user=self.user, feed=self.feed).exists())

    def test_invalid_requests_and_missing_stories_do_not_create_feedback(self):
        for data in [
            {"value": "2"},
            {"value": "true"},
            {"surface": "focus"},
            {"story_hash": "invalid"},
            {"story_hash": "1:ffffff"},
        ]:
            with self.subTest(data=data):
                payload = dict(story_hash=self.story.story_hash, value=1, surface="good_reads")
                payload.update(data)
                self.assertEqual(self.client.post(self.url, payload).json()["code"], -1)
        self.assertEqual(MRecommendationFeedback.objects(user_id=self.user.pk).count(), 0)

    def test_endpoint_requires_post_and_authentication(self):
        self.assertEqual(self.client.get(self.url).status_code, 405)
        self.client.logout()
        self.assertEqual(self.vote(1).status_code, 403)
        self.assertEqual(MRecommendationFeedback.objects(user_id=self.user.pk).count(), 0)

    def test_feedback_requires_a_csrf_token_supplied_by_discovery(self):
        client = Client(enforce_csrf_checks=True)
        client.force_login(self.user)
        payload = dict(story_hash=self.story.story_hash, value=1, surface="discovery")
        self.assertEqual(client.post(self.url, payload).status_code, 403)
        with patch.object(Discovery, "page", return_value=([], "snapshot", 0)):
            response = client.get(reverse("load-trending-stories"), {"trending_type": "discovery"})
        payload["csrfmiddlewaretoken"] = response.cookies["csrftoken"].value
        self.assertEqual(client.post(self.url, payload).json()["code"], 1)

    def test_private_feed_requires_a_subscription(self):
        parent = Feed.objects.exclude(pk=self.feed.pk).first()
        Feed.objects.filter(pk=self.feed.pk).update(branch_from_feed_id=parent.pk)
        self.assertEqual(self.vote(1).json()["code"], -1)
        UserSubscription.objects.create(user=self.user, feed=self.feed)
        self.assertEqual(self.vote(1).json()["code"], 1)

    def test_account_deletion_removes_its_feedback_only(self):
        self.vote(1)
        MRecommendationFeedback.record(self.other_user.pk, self.story, -1, "good_reads")
        user_id = self.user.pk
        self.user.delete()
        self.assertEqual(MRecommendationFeedback.objects(user_id=user_id).count(), 0)
        self.assertEqual(MRecommendationFeedback.objects(user_id=self.other_user.pk).count(), 1)

    def make_discovery_story(self, slug, title, feed=None):
        feed = feed or Feed.objects.create(
            feed_address="https://%s.example.com/feed" % slug,
            feed_link="https://%s.example.com" % slug,
            feed_title=slug,
        )
        return MStory(
            story_feed_id=feed.pk,
            story_guid="discovery-test-" + slug,
            story_title=title,
            story_content=title,
            story_date=datetime.datetime.utcnow(),
            story_permalink="https://%s.example.com/article" % slug,
        ).save()

    def test_discovery_excludes_followed_aliases_private_and_duplicate_stories(self):
        followed = Feed.objects.create(
            feed_address="https://followed.example.com/rss",
            feed_link="https://followed.example.com",
            feed_title="Followed",
        )
        UserSubscription.objects.create(user=self.user, feed=followed)
        alias = Feed.objects.create(
            feed_address="https://followed.example.com/atom",
            feed_link="http://www.followed.example.com/",
            feed_title="Alias",
        )
        private = Feed.objects.create(
            feed_address="https://private.example.com/rss",
            feed_link="https://private.example.com",
            feed_title="Private",
            branch_from_feed=followed,
        )
        token = Feed.objects.create(
            feed_address="https://token.example.com/rss?token=private",
            feed_link="https://token.example.com",
            feed_title="Token",
        )
        stories = [
            self.make_discovery_story(str(i), "Article", feed)
            for i, feed in enumerate([followed, alias, private, token])
        ]
        public = self.make_discovery_story("public", "Public article")
        duplicate = self.make_discovery_story("duplicate", "Public article")
        duplicate.story_permalink = public.story_permalink + "?utm_source=rss"
        duplicate.save()
        hashes = [s.story_hash for s in stories + [public, duplicate]]
        self.assertEqual(
            [s.story_hash for s in Discovery.eligible_stories(self.user.pk, hashes)], [public.story_hash]
        )

    def test_discovery_votes_change_similar_article_order_and_undo_restores_it(self):
        cooking = self.make_discovery_story("cooking", "Lentil cooking recipe plant protein")
        security = self.make_discovery_story("security", "Camera security vulnerabilities software passwords")
        example = self.make_discovery_story("example", "Camera security vulnerabilities software passwords")
        candidates = [cooking, security]
        examples = [(example.story_hash, Discovery.story_text(example), 1.0)]
        self.assertEqual(Discovery.rank(candidates, examples, [])[0], security.story_hash)
        MRecommendationFeedback.record(self.user.pk, example, -1, "discovery")
        votes = list(MRecommendationFeedback.objects(user_id=self.user.pk))
        self.assertEqual(Discovery.rank(candidates, examples, votes)[0], cooking.story_hash)
        MRecommendationFeedback.record(self.user.pk, example, 1, "discovery")
        self.assertEqual(
            Discovery.rank(candidates, [], list(MRecommendationFeedback.objects(user_id=self.user.pk)))[0],
            security.story_hash,
        )
        MRecommendationFeedback.record(self.user.pk, example, 0, "discovery")
        self.assertEqual(
            Discovery.rank(candidates, examples, list(MRecommendationFeedback.objects(user_id=self.user.pk)))[
                0
            ],
            security.story_hash,
        )

    def test_discovery_snapshot_stays_stable_after_feedback_and_is_account_scoped(self):
        first = self.make_discovery_story("first", "Cooking lentils")
        second = self.make_discovery_story("second", "Security cameras")
        with patch.object(
            Discovery, "candidate_hashes", return_value=[first.story_hash, second.story_hash]
        ), patch.object(Discovery, "reading_examples", return_value=[]):
            hashes, snapshot, _ = Discovery.page(self.user.pk, limit=1, read_filter="all")
            self.assertEqual(hashes, [first.story_hash])
            MRecommendationFeedback.record(self.user.pk, second, 1, "discovery")
            hashes, _, _ = Discovery.page(self.user.pk, page=2, limit=1, snapshot=snapshot)
            self.assertEqual(hashes, [second.story_hash])
            fresh, _, _ = Discovery.page(self.user.pk, limit=1, read_filter="all")
            self.assertEqual(fresh, [second.story_hash])
            with self.assertRaises(ValueError):
                Discovery.page(self.other_user.pk, page=2, limit=1, snapshot=snapshot)
            with self.assertRaises(ValueError):
                Discovery.page(self.user.pk, page=2, snapshot="expired")
            UserSubscription.objects.create(user=self.user, feed_id=second.story_feed_id)
            self.assertEqual(Discovery.page(self.user.pk, page=2, limit=1, snapshot=snapshot)[0], [])

    def test_discovery_response_restores_feedback_and_rejects_anonymous_requests(self):
        self.vote(-1, surface="discovery")
        with patch.object(Discovery, "page", return_value=([self.story.story_hash], "snapshot", 1)):
            response = self.client.get(
                reverse("load-trending-stories"), {"trending_type": "discovery"}
            ).json()
        self.assertEqual(response["stories"][0]["recommendation_feedback"], -1)
        self.assertEqual(response["discovery_snapshot"], "snapshot")
        self.assertEqual(response["discovery_next_cursor"], 1)
        self.client.logout()
        self.assertEqual(
            self.client.get(reverse("load-trending-stories"), {"trending_type": "discovery"}).json()["code"],
            -1,
        )

    def test_discovery_continues_past_newly_ineligible_pages(self):
        stories = [self.make_discovery_story("continuation-%s" % i, "Article") for i in range(5)]
        with patch.object(
            Discovery, "candidate_hashes", return_value=[s.story_hash for s in stories]
        ), patch.object(Discovery, "reading_examples", return_value=[]):
            first = Discovery.page(self.user.pk, limit=1, read_filter="all")
        for story in stories[1:3]:
            UserSubscription.objects.create(user=self.user, feed_id=story.story_feed_id)
        second = Discovery.page(self.user.pk, page=2, limit=1, snapshot=first[1])
        self.assertEqual(second[0], [stories[3].story_hash])
        third = Discovery.page(self.user.pk, page=3, limit=1, snapshot=first[1], cursor=second[2])
        self.assertEqual(third[0], [stories[4].story_hash])
        self.assertEqual(
            Discovery.page(self.user.pk, page=4, limit=1, snapshot=first[1], cursor=third[2])[0], []
        )
        for invalid_cursor in ("-1", "bad", "99999", "6"):
            with self.subTest(cursor=invalid_cursor), self.assertRaises(ValueError):
                Discovery.page(self.user.pk, page=2, snapshot=first[1], cursor=invalid_cursor)

    def test_discovery_dwell_uses_bounded_point_reads_and_ignores_brief_views(self):
        from unittest.mock import MagicMock

        from django.core.cache import cache

        cache.delete("discovery:profile:v1:%s" % self.user.pk)
        stats, reader = MagicMock(), MagicMock()
        reader.lrange.return_value = [self.story.story_hash]
        stats.pipeline.return_value.execute.return_value = [45.0] + [None] * 7
        with patch("apps.recommendations.discovery.redis.Redis", side_effect=[reader, stats]):
            examples = Discovery.reading_examples(self.user.pk)
        self.assertEqual(examples[0][0], self.story.story_hash)
        self.assertEqual(stats.pipeline.return_value.zscore.call_count, 8)
        stats.scan.assert_not_called()
        stats.zscan.assert_not_called()
        cache.delete("discovery:profile:v1:%s" % self.user.pk)
        stats.pipeline.return_value.execute.return_value = [5.0] + [None] * 7
        with patch("apps.recommendations.discovery.redis.Redis", side_effect=[reader, stats]):
            self.assertEqual(Discovery.reading_examples(self.user.pk), [])

    def test_discovery_cold_start_is_deterministic_and_diversifies_sources(self):
        stories = [self.make_discovery_story("same-%s" % i, "Camera security", self.feed) for i in range(5)]
        other = self.make_discovery_story("different", "Cooking lentils")
        hashes = Discovery.rank(stories + [other], [], [])
        self.assertEqual(hashes[:3], [stories[0].story_hash, stories[1].story_hash, other.story_hash])
        self.assertEqual(set(hashes), {s.story_hash for s in stories + [other]})
        self.assertEqual(Discovery.rank([], [], []), [])

    def test_saved_and_shared_text_is_available_after_original_story_expires(self):
        import zlib
        from unittest.mock import MagicMock

        from django.core.cache import cache

        for model, date_field in ((MStarredStory, "starred_date"), (MSharedStory, "shared_date")):
            model._get_collection().insert_one(
                dict(
                    user_id=self.user.pk,
                    story_hash="1:%s" % date_field,
                    story_guid="discovery-test-" + date_field,
                    story_title="Useful article",
                    story_tags=[],
                    story_content_z=zlib.compress(b"<p>Camera security research</p>"),
                    **{date_field: datetime.datetime.utcnow()},
                )
            )
        cache.delete("discovery:profile:v1:%s" % self.user.pk)
        reader = MagicMock()
        reader.lrange.return_value = []
        reader.pipeline.return_value.execute.return_value = []
        with patch("apps.recommendations.discovery.redis.Redis", return_value=reader):
            examples = Discovery.reading_examples(self.user.pk)
        self.assertEqual(len(examples), 2)
        self.assertTrue(
            all("Camera security research" in text and weight == 2 for _, text, weight in examples)
        )
