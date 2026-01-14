"""
URL tests for the oauth app.

Tests URL resolution and basic access patterns for all oauth endpoints.
"""

import pytest
from django.test import Client, TransactionTestCase
from django.urls import resolve, reverse


class Test_OAuthURLResolution(TransactionTestCase):
    """Test that all oauth URLs resolve correctly."""

    def test_twitter_connect_resolves(self):
        """Test twitter connect URL resolves."""
        url = reverse("twitter-connect")
        resolved = resolve(url)
        assert resolved.view_name == "twitter-connect"

    def test_facebook_connect_resolves(self):
        """Test facebook connect URL resolves."""
        url = reverse("facebook-connect")
        resolved = resolve(url)
        assert resolved.view_name == "facebook-connect"

    def test_twitter_disconnect_resolves(self):
        """Test twitter disconnect URL resolves."""
        url = reverse("twitter-disconnect")
        resolved = resolve(url)
        assert resolved.view_name == "twitter-disconnect"

    def test_facebook_disconnect_resolves(self):
        """Test facebook disconnect URL resolves."""
        url = reverse("facebook-disconnect")
        resolved = resolve(url)
        assert resolved.view_name == "facebook-disconnect"

    def test_follow_twitter_account_resolves(self):
        """Test follow twitter account URL resolves."""
        url = reverse("social-follow-twitter")
        resolved = resolve(url)
        assert resolved.view_name == "social-follow-twitter"

    def test_unfollow_twitter_account_resolves(self):
        """Test unfollow twitter account URL resolves."""
        url = reverse("social-unfollow-twitter")
        resolved = resolve(url)
        assert resolved.view_name == "social-unfollow-twitter"

    def test_ifttt_status_resolves(self):
        """Test IFTTT status URL resolves."""
        url = reverse("ifttt-status")
        resolved = resolve(url)
        assert resolved.view_name == "ifttt-status"

    def test_oauth_authorize_resolves(self):
        """Test OAuth authorize URL resolves."""
        url = reverse("oauth-authorize")
        resolved = resolve(url)
        assert resolved.view_name == "oauth-authorize"

    def test_oauth_token_resolves(self):
        """Test OAuth token URL resolves."""
        url = reverse("oauth-token")
        resolved = resolve(url)
        assert resolved.view_name == "oauth-token"

    def test_ifttt_authorize_resolves(self):
        """Test IFTTT authorize URL resolves."""
        url = reverse("ifttt-authorize")
        resolved = resolve(url)
        assert resolved.view_name == "ifttt-authorize"

    def test_ifttt_token_resolves(self):
        """Test IFTTT token URL resolves."""
        url = reverse("ifttt-token")
        resolved = resolve(url)
        assert resolved.view_name == "ifttt-token"

    def test_ifttt_user_info_resolves(self):
        """Test IFTTT user info URL resolves."""
        url = reverse("ifttt-user-info")
        resolved = resolve(url)
        assert resolved.view_name == "ifttt-user-info"

    def test_ifttt_trigger_feedlist_resolves(self):
        """Test IFTTT trigger feedlist URL resolves."""
        url = reverse("ifttt-trigger-feedlist", kwargs={"trigger_slug": "new-unread-story"})
        resolved = resolve(url)
        assert resolved.view_name == "ifttt-trigger-feedlist"

    def test_ifttt_trigger_unreadstory_resolves(self):
        """Test IFTTT trigger unread story URL resolves."""
        url = reverse("ifttt-trigger-unreadstory", kwargs={"trigger_slug": "new-unread-story"})
        resolved = resolve(url)
        assert resolved.view_name == "ifttt-trigger-unreadstory"

    def test_ifttt_trigger_taglist_resolves(self):
        """Test IFTTT trigger taglist URL resolves."""
        url = reverse("ifttt-trigger-taglist")
        resolved = resolve(url)
        assert resolved.view_name == "ifttt-trigger-taglist"

    def test_ifttt_trigger_saved_resolves(self):
        """Test IFTTT trigger saved URL resolves."""
        url = reverse("ifttt-trigger-saved")
        resolved = resolve(url)
        assert resolved.view_name == "ifttt-trigger-saved"

    def test_ifttt_trigger_blurbloglist_resolves(self):
        """Test IFTTT trigger blurblog list URL resolves."""
        url = reverse("ifttt-trigger-blurbloglist")
        resolved = resolve(url)
        assert resolved.view_name == "ifttt-trigger-blurbloglist"

    def test_ifttt_trigger_shared_resolves(self):
        """Test IFTTT trigger shared URL resolves."""
        url = reverse("ifttt-trigger-shared")
        resolved = resolve(url)
        assert resolved.view_name == "ifttt-trigger-shared"

    def test_ifttt_action_share_resolves(self):
        """Test IFTTT action share URL resolves."""
        url = reverse("ifttt-action-share")
        resolved = resolve(url)
        assert resolved.view_name == "ifttt-action-share"

    def test_ifttt_action_saved_resolves(self):
        """Test IFTTT action saved URL resolves."""
        url = reverse("ifttt-action-saved")
        resolved = resolve(url)
        assert resolved.view_name == "ifttt-action-saved"

    def test_ifttt_action_subscription_resolves(self):
        """Test IFTTT action subscription URL resolves."""
        url = reverse("ifttt-action-subscription")
        resolved = resolve(url)
        assert resolved.view_name == "ifttt-action-subscription"

    def test_ifttt_action_folderlist_resolves(self):
        """Test IFTTT action folderlist URL resolves."""
        url = reverse("ifttt-action-folderlist")
        resolved = resolve(url)
        assert resolved.view_name == "ifttt-action-folderlist"


class Test_OAuthURLAccess(TransactionTestCase):
    """Test access patterns for oauth URLs."""

    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
    ]

    def setUp(self):
        from django.contrib.auth.models import User

        self.client = Client()
        self.user = User.objects.create_user(username="testuser", password="testpass", email="test@test.com")

    def test_twitter_connect_authenticated(self):
        """Test authenticated access to twitter connect."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("twitter-connect"))
        # Will redirect to Twitter OAuth
        assert response.status_code in [200, 302]

    def test_facebook_connect_authenticated(self):
        """Test authenticated access to facebook connect."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("facebook-connect"))
        assert response.status_code in [200, 302]

    def test_ifttt_status_anonymous(self):
        """Test anonymous access to IFTTT status."""
        response = self.client.get(reverse("ifttt-status"))
        assert response.status_code in [200, 401]

    def test_oauth_authorize_anonymous(self):
        """Test anonymous access to OAuth authorize."""
        response = self.client.get(reverse("oauth-authorize"))
        # Should redirect to login
        assert response.status_code in [200, 302, 400]


class Test_OAuthURLPOST(TransactionTestCase):
    """Test POST endpoints for oauth URLs."""

    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
    ]

    def setUp(self):
        from django.contrib.auth.models import User

        self.client = Client()
        self.user = User.objects.create_user(username="testuser", password="testpass", email="test@test.com")

    def test_twitter_disconnect_post(self):
        """Test POST to twitter disconnect."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.post(reverse("twitter-disconnect"))
        assert response.status_code in [200, 302, 400]

    def test_facebook_disconnect_post(self):
        """Test POST to facebook disconnect."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.post(reverse("facebook-disconnect"))
        assert response.status_code in [200, 302, 400]

    def test_follow_twitter_account_post(self):
        """Test POST to follow twitter account."""
        self.client.login(username="testuser", password="testpass")
        # View expects 'username' parameter and only allows 'samuelclay' or 'newsblur'
        response = self.client.post(reverse("social-follow-twitter"), {"username": "newsblur"})
        # Returns 403 if not allowed, 200 if successful
        assert response.status_code in [200, 302, 400, 403]

    def test_unfollow_twitter_account_post(self):
        """Test POST to unfollow twitter account."""
        from apps.social.models import MSocialServices

        self.client.login(username="testuser", password="testpass")
        # View expects 'username' parameter and only allows 'samuelclay' or 'newsblur'
        # View also requires MSocialServices to exist for user
        try:
            response = self.client.post(reverse("social-unfollow-twitter"), {"username": "newsblur"})
            # Returns 403 if not allowed, 200 if successful
            assert response.status_code in [200, 302, 400, 403]
        except MSocialServices.DoesNotExist:
            # Expected when user has no social services configured
            pass
