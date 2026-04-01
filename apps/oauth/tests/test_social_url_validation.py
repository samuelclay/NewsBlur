import json as json_lib
from unittest.mock import patch

from django.contrib.auth.models import User
from django.test import TestCase
from django.urls import reverse

from apps.profile.models import Profile
from apps.rss_feeds.models import UNSUPPORTED_SOCIAL_FEED_MESSAGE
from utils import json_functions as json


class Test_OAuthSocialURLValidation(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="testuser", password="testpass", email="test@test.com"
        )
        Profile.objects.get_or_create(user=self.user)
        self.client.login(username="testuser", password="testpass")

    @patch("apps.oauth.views.Feed.get_feed_from_url")
    def test_api_share_new_story_rejects_unsupported_twitter_urls(self, mock_get_feed):
        response = self.client.post(
            reverse("ifttt-action-share"),
            data=json_lib.dumps({"actionFields": {"story_url": "https://x.com/newsblur/status/12345"}}),
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            json.decode(response.content)["errors"][0]["message"], UNSUPPORTED_SOCIAL_FEED_MESSAGE
        )
        mock_get_feed.assert_not_called()

    @patch("apps.oauth.views.Feed.get_feed_from_url")
    def test_api_save_new_story_rejects_unsupported_twitter_urls(self, mock_get_feed):
        response = self.client.post(
            reverse("ifttt-action-saved"),
            data=json_lib.dumps({"actionFields": {"story_url": "https://twitter.com/newsblur"}}),
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            json.decode(response.content)["errors"][0]["message"], UNSUPPORTED_SOCIAL_FEED_MESSAGE
        )
        mock_get_feed.assert_not_called()
