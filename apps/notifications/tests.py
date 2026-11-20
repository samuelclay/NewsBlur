import datetime
from unittest.mock import MagicMock, patch

import redis
from django.conf import settings
from django.contrib.auth.models import User
from django.test import TestCase

from apps.analyzer.models import MClassifierPrompt
from apps.notifications.models import MUserClassifierNotification, MUserFeedNotification
from apps.reader.models import UserSubscription, UserSubscriptionFolders
from apps.rss_feeds.models import Feed, MStory
from utils import json_functions as json


class FakeNotificationRedis:
    def __init__(self):
        self.store = {}

    def setex(self, key, ttl, value):
        self.store[key] = value
        return True

    def set(self, key, value, ex=None, nx=False):
        if nx and key in self.store:
            return False
        self.store[key] = value
        return True

    def exists(self, key):
        return key in self.store


class Test_EmailNotifications(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="notifytest",
            password="testpass",
            email="notify@example.com",
        )

    def make_feed(self, feed_address, feed_title):
        return Feed.objects.create(
            feed_address=feed_address,
            feed_link="https://example.com",
            feed_title=feed_title,
            fetched_once=True,
            known_good=True,
        )

    def send_email_subject(self, feed, story_title):
        usersub = UserSubscription.objects.create(user=self.user, feed=feed, active=True)
        notification = MUserFeedNotification(user_id=self.user.pk, feed_id=feed.pk, is_email=True)
        story = {
            "story_title": story_title,
            "story_content": "<p>Summary</p>",
        }

        with patch("apps.notifications.models.redis.Redis") as mock_redis_cls, patch(
            "apps.notifications.models.render_to_string", return_value=""
        ), patch("apps.notifications.models.Site.objects.get_current") as mock_get_current, patch(
            "apps.notifications.models.EmailMultiAlternatives"
        ) as mock_email_cls:
            mock_redis = mock_redis_cls.return_value
            mock_redis.hget.return_value = 1
            mock_get_current.return_value.domain = "newsblur.com"

            notification.send_email(story, usersub)

        return mock_email_cls.call_args[0][0]

    def test_story_notification_subject_includes_feed_title(self):
        feed = self.make_feed("https://example.com/feed.xml", "Example Feed")

        subject = self.send_email_subject(feed, "A Regular Story")

        self.assertEqual(subject, "Example Feed: A Regular Story")

    def test_daily_briefing_email_subject_uses_story_title_without_feed_prefix(self):
        feed = self.make_feed("daily-briefing:%s" % self.user.pk, "Daily Briefing")

        subject = self.send_email_subject(feed, "Morning Daily Briefing - May 8, 2026")

        self.assertEqual(subject, "Morning Daily Briefing - May 8, 2026")

    def test_prompt_classifier_notification_matches_on_ai_score(self):
        """Natural Language classifier notifications fire off cached AI scores."""
        feed = self.make_feed("https://example.com/ai.xml", "AI Feed")
        notif = MUserClassifierNotification(
            user_id=self.user.pk,
            classifier_type="prompt",
            classifier_value="AI and machine learning",
            scope="feed",
            feed_id=feed.pk,
            is_email=True,
        )
        story = {"story_hash": "%s:abc123" % feed.pk, "story_feed_id": feed.pk}

        # AI scored the story as a match (1) for this prompt -> notify
        self.assertTrue(
            notif.matches_story(story, feed.pk, prompt_scores={notif.pk: {story["story_hash"]: 1}})
        )
        # AI scored it neutral (0) -> no match
        self.assertFalse(
            notif.matches_story(story, feed.pk, prompt_scores={notif.pk: {story["story_hash"]: 0}})
        )
        # No cached AI score at all -> no match
        self.assertFalse(notif.matches_story(story, feed.pk, prompt_scores={}))
        # A match in a different feed must not fire a feed-scoped notification
        self.assertFalse(
            notif.matches_story(story, feed.pk + 1, prompt_scores={notif.pk: {story["story_hash"]: 1}})
        )

    def test_image_prompt_classifier_notification_matches_on_ai_score(self):
        """Image classifier notifications match the same way as text prompts."""
        feed = self.make_feed("https://example.com/img.xml", "Image Feed")
        notif = MUserClassifierNotification(
            user_id=self.user.pk,
            classifier_type="image_prompt",
            classifier_value="charts and graphs",
            scope="feed",
            feed_id=feed.pk,
            is_ios=True,
        )
        story = {"story_hash": "%s:def456" % feed.pk, "story_feed_id": feed.pk}

        self.assertTrue(
            notif.matches_story(story, feed.pk, prompt_scores={notif.pk: {story["story_hash"]: 1}})
        )
        self.assertFalse(notif.matches_story(story, feed.pk, prompt_scores={}))

    def test_prompt_notification_applies_to_feed_scope(self):
        """A folder-scoped prompt notification only covers feeds inside its folder."""
        in_folder = self.make_feed("https://example.com/in.xml", "In Folder")
        out_folder = self.make_feed("https://example.com/out.xml", "Out of Folder")
        notif = MUserClassifierNotification(
            user_id=self.user.pk,
            classifier_type="prompt",
            classifier_value="space exploration",
            scope="folder",
            folder_name="Science",
            is_email=True,
        )
        folder_feed_ids = {"Science": {in_folder.pk}}

        # Folder scope covers a feed inside the folder, not one outside it.
        # The matcher relies on this so it never warms billable AI scoring for
        # feeds a folder-scoped prompt notification can never fire on.
        self.assertTrue(notif.applies_to_feed(in_folder.pk, folder_feed_ids))
        self.assertFalse(notif.applies_to_feed(out_folder.pk, folder_feed_ids))
        # Folder scope with no folder map resolves to no coverage
        self.assertFalse(notif.applies_to_feed(in_folder.pk, None))

        # Global scope covers any feed
        notif.scope = "global"
        self.assertTrue(notif.applies_to_feed(out_folder.pk, None))

    def test_feed_notification_does_not_send_email_after_classifier_email(self):
        feed = self.make_feed("https://example.com/dedupe.xml", "Dedupe Feed")
        usersub = UserSubscription.objects.create(user=self.user, feed=feed, active=True)
        notification = MUserFeedNotification(user_id=self.user.pk, feed_id=feed.pk, is_email=True)
        story = {
            "story_title": "Duplicate Alert",
            "story_hash": "dedupe:%s:1" % feed.pk,
            "story_feed_id": feed.pk,
            "story_content": "<p>Summary</p>",
            "story_tags": [],
        }
        fake_redis = FakeNotificationRedis()

        with patch("apps.notifications.models.redis.Redis", return_value=fake_redis):
            MUserClassifierNotification.mark_story_sent(self.user.pk, story["story_hash"], is_email=True)

            with patch.object(MUserFeedNotification, "send_email") as mock_send_email:
                sent = notification.push_story_notification(story, {}, usersub)

        self.assertFalse(sent)
        mock_send_email.assert_not_called()


class Test_PromptNotificationFolderScope(TestCase):
    """apps/notifications/tests.py: push_classifier_notifications warms prompt scores with
    MClassifierPrompt.classify_stories. A prompt scoped to a folder must not run or bill
    there for a site outside that folder, even when another prompt notification does
    apply to the site."""

    def setUp(self):
        self.user = User.objects.create_user(
            username="notifyfolder", password="testpass", email="notifyfolder@example.com"
        )
        self.user.profile.is_archive = True
        self.user.profile.is_usage_billing = True
        self.user.profile.last_seen_on = datetime.datetime.now()
        self.user.profile.save()
        self.feed = Feed.objects.create(
            feed_address="https://example.com/robots.xml",
            feed_link="https://example.com",
            feed_title="Robots Weekly",
            fetched_once=True,
            known_good=True,
        )
        self.science_feed = Feed.objects.create(
            feed_address="https://example.com/science.xml",
            feed_link="https://example.com",
            feed_title="Science Daily",
            fetched_once=True,
            known_good=True,
        )
        UserSubscription.objects.create(user=self.user, feed=self.feed, active=True)
        UserSubscription.objects.create(user=self.user, feed=self.science_feed, active=True)
        UserSubscriptionFolders.objects.create(
            user=self.user, folders=json.encode([{"Science": [self.science_feed.pk]}, self.feed.pk])
        )

        self.global_prompt = MClassifierPrompt.objects.create(
            user_id=self.user.pk, feed_id=0, folder_id="", prompt="robots", classifier_type="focus"
        )
        self.science_prompt = MClassifierPrompt.objects.create(
            user_id=self.user.pk, feed_id=0, folder_id="Science", prompt="space", classifier_type="focus"
        )
        self.notification = MUserClassifierNotification.objects.create(
            user_id=self.user.pk,
            classifier_type="prompt",
            classifier_value="robots",
            scope="global",
            is_email=True,
        )

        self.story = MStory(
            story_feed_id=self.feed.pk,
            story_date=datetime.datetime.now(),
            story_title="A robot lands on the moon",
            story_content="Robots in space.",
            story_guid="notifyfolder-robot-moon",
            story_permalink="https://example.com/robot-moon",
        )
        self.story.save()
        # The test Redis may hold another test's stories for this feed id, so the new
        # story must be the only one push_classifier_notifications finds in zF.
        self.r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
        self.r.delete("zF:%s" % self.feed.pk)
        self.r.zadd("zF:%s" % self.feed.pk, {self.story.story_hash: 1})

    def tearDown(self):
        self.r.delete("zF:%s" % self.feed.pk)
        self.story.delete()
        for prompt in (self.global_prompt, self.science_prompt):
            MClassifierPrompt.invalidate_cache(
                self.user.pk, str(prompt.id), feed_ids=[self.feed.pk, self.science_feed.pk]
            )
        MClassifierPrompt.objects(user_id=self.user.pk).delete()
        MUserClassifierNotification.objects(user_id=self.user.pk).delete()

    def test_folder_prompt_is_not_warmed_for_a_feed_outside_its_folder(self):
        block = MagicMock()
        block.type = "tool_use"
        block.name = "classify_stories"
        block.input = {"classifications": [{"id": self.story.story_hash, "classification": 1}]}

        with patch("apps.ask_ai.providers.AnthropicProvider.is_configured", return_value=True), patch(
            "utils.ai_functions.anthropic.Anthropic"
        ) as MockAnthropic, patch(
            "utils.ai_functions.LLMCostTracker.record_usage"
        ) as record_usage, patch.object(
            MUserClassifierNotification,
            "claim_story_channels",
            return_value={"email": False, "web": False, "ios": False, "android": False},
        ) as claim:
            create = MockAnthropic.return_value.messages.create
            create.return_value.content = [block]
            MUserClassifierNotification.push_classifier_notifications(self.feed.pk, 1)

        asked = [call.kwargs["system"] for call in create.call_args_list]
        self.assertEqual(len(asked), 1, "Only the global prompt applies to Robots Weekly")
        self.assertIn("robots", asked[0])
        self.assertNotIn("space", asked[0])
        self.assertEqual(record_usage.call_count, 1)
        # The global prompt's verdict still drives the notification.
        claim.assert_called_once()
