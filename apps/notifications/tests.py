from unittest.mock import patch

from django.contrib.auth.models import User
from django.test import TestCase

from apps.notifications.models import MUserClassifierNotification, MUserFeedNotification
from apps.reader.models import UserSubscription
from apps.rss_feeds.models import Feed


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
