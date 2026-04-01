from unittest.mock import patch

from django.contrib.auth.models import User
from django.test import TestCase

from apps.profile.models import Profile
from apps.rss_feeds.models import UNSUPPORTED_SOCIAL_FEED_MESSAGE
from utils import json_functions as json


class Test_APISocialURLValidation(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="testuser", password="testpass", email="test@test.com"
        )
        Profile.objects.get_or_create(user=self.user)
        self.client.login(username="testuser", password="testpass")

    @patch("apps.api.views.Feed.get_feed_from_url")
    def test_share_story_rejects_unsupported_twitter_urls(self, mock_get_feed):
        response = self.client.post(
            "/api/share_story",
            {
                "story_url": "https://x.com/newsblur/status/12345",
                "title": "Test story",
            },
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(json.decode(response.content)["message"], UNSUPPORTED_SOCIAL_FEED_MESSAGE)
        mock_get_feed.assert_not_called()

    @patch("apps.api.views.Feed.get_feed_from_url")
    def test_save_story_rejects_unsupported_twitter_urls(self, mock_get_feed):
        response = self.client.post(
            "/api/save_story",
            {
                "story_url": "https://twitter.com/newsblur",
                "title": "Test story",
            },
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(json.decode(response.content)["message"], UNSUPPORTED_SOCIAL_FEED_MESSAGE)
        mock_get_feed.assert_not_called()
