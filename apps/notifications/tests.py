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
