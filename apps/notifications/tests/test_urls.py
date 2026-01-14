"""
URL tests for the notifications app.

Tests URL resolution and basic access patterns for all notifications endpoints.
"""

import pytest
from django.test import Client, TransactionTestCase
from django.urls import resolve, reverse


class Test_NotificationsURLResolution(TransactionTestCase):
    """Test that all notifications URLs resolve correctly."""

    def test_notifications_by_feed_resolves(self):
        """Test notifications by feed URL resolves."""
        url = reverse("notifications-by-feed")
        resolved = resolve(url)
        assert resolved.view_name == "notifications-by-feed"

    def test_set_notifications_for_feed_resolves(self):
        """Test set notifications for feed URL resolves."""
        url = reverse("set-notifications-for-feed")
        resolved = resolve(url)
        assert resolved.view_name == "set-notifications-for-feed"

    def test_set_apns_token_resolves(self):
        """Test set APNS token URL resolves."""
        url = reverse("set-apns-token")
        resolved = resolve(url)
        assert resolved.view_name == "set-apns-token"

    def test_set_android_token_resolves(self):
        """Test set Android token URL resolves."""
        url = reverse("set-android-token")
        resolved = resolve(url)
        assert resolved.view_name == "set-android-token"

    def test_force_push_notification_resolves(self):
        """Test force push notification URL resolves."""
        url = reverse("force-push-notification")
        resolved = resolve(url)
        assert resolved.view_name == "force-push-notification"


class Test_NotificationsURLAccess(TransactionTestCase):
    """Test access patterns for notifications URLs."""

    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
    ]

    def setUp(self):
        from django.contrib.auth.models import User

        self.client = Client()
        self.user = User.objects.create_user(username="testuser", password="testpass", email="test@test.com")

    def test_notifications_by_feed_authenticated(self):
        """Test authenticated access to notifications by feed."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("notifications-by-feed"))
        assert response.status_code == 200


class Test_NotificationsURLPOST(TransactionTestCase):
    """Test POST endpoints for notifications URLs."""

    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
        "apps/rss_feeds/fixtures/rss_feeds.json",
    ]

    def setUp(self):
        from django.contrib.auth.models import User

        from apps.reader.models import UserSubscription
        from apps.rss_feeds.models import Feed

        self.client = Client()
        self.user = User.objects.create_user(username="testuser", password="testpass", email="test@test.com")
        self.feed = Feed.objects.get(pk=1)
        UserSubscription.objects.create(user=self.user, feed=self.feed)

    def test_set_notifications_for_feed_post(self):
        """Test POST to set notifications for feed."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.post(
            reverse("set-notifications-for-feed"),
            {"feed_id": self.feed.pk, "notification_types": "", "notification_filter": "focus"},
        )
        assert response.status_code in [200, 302, 400]

    def test_set_apns_token_post(self):
        """Test POST to set APNS token."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.post(reverse("set-apns-token"), {"apns_token": "test_token_123"})
        assert response.status_code in [200, 302, 400]

    def test_set_android_token_post(self):
        """Test POST to set Android token."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.post(reverse("set-android-token"), {"android_token": "test_token_123"})
        assert response.status_code in [200, 302, 400]
