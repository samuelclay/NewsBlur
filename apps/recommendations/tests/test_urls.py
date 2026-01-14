"""
URL tests for the recommendations app.

Tests URL resolution and basic access patterns for all recommendations endpoints.
"""

import pytest
from django.test import Client, TransactionTestCase
from django.urls import resolve, reverse


class Test_RecommendationsURLResolution(TransactionTestCase):
    """Test that all recommendations URLs resolve correctly."""

    def test_load_recommended_feed_resolves(self):
        """Test load recommended feed URL resolves."""
        url = reverse("load-recommended-feed")
        resolved = resolve(url)
        assert resolved.view_name == "load-recommended-feed"

    def test_save_recommended_feed_resolves(self):
        """Test save recommended feed URL resolves."""
        url = reverse("save-recommended-feed")
        resolved = resolve(url)
        assert resolved.view_name == "save-recommended-feed"

    def test_approve_recommended_feed_resolves(self):
        """Test approve recommended feed URL resolves."""
        url = reverse("approve-recommended-feed")
        resolved = resolve(url)
        assert resolved.view_name == "approve-recommended-feed"

    def test_decline_recommended_feed_resolves(self):
        """Test decline recommended feed URL resolves."""
        url = reverse("decline-recommended-feed")
        resolved = resolve(url)
        assert resolved.view_name == "decline-recommended-feed"

    def test_load_recommended_feed_info_resolves(self):
        """Test load recommended feed info URL resolves."""
        url = reverse("load-recommended-feed-info", kwargs={"feed_id": "1"})
        resolved = resolve(url)
        assert resolved.view_name == "load-recommended-feed-info"


class Test_RecommendationsURLAccess(TransactionTestCase):
    """Test access patterns for recommendations URLs."""

    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
        "apps/rss_feeds/fixtures/rss_feeds.json",
    ]

    def setUp(self):
        from django.contrib.auth.models import User

        self.client = Client()
        self.user = User.objects.create_user(username="testuser", password="testpass", email="test@test.com")

    def test_load_recommended_feed_authenticated(self):
        """Test authenticated access to load recommended feed."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("load-recommended-feed"))
        assert response.status_code in [200, 302]

    def test_load_recommended_feed_info_authenticated(self):
        """Test authenticated access to load recommended feed info."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("load-recommended-feed-info", kwargs={"feed_id": "1"}))
        assert response.status_code in [200, 302, 404]


class Test_RecommendationsURLPOST(TransactionTestCase):
    """Test POST endpoints for recommendations URLs."""

    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
        "apps/rss_feeds/fixtures/rss_feeds.json",
    ]

    def setUp(self):
        from django.contrib.auth.models import User

        from apps.rss_feeds.models import Feed

        self.client = Client()
        self.user = User.objects.create_user(username="testuser", password="testpass", email="test@test.com")
        self.feed = Feed.objects.get(pk=1)

    def test_save_recommended_feed_post(self):
        """Test POST to save recommended feed."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.post(
            reverse("save-recommended-feed"),
            {"feed_id": self.feed.pk, "description": "Great feed!", "twitter": "testuser"},
        )
        assert response.status_code in [200, 302, 400]

    def test_approve_recommended_feed_post(self):
        """Test POST to approve recommended feed."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.post(reverse("approve-recommended-feed"), {"feed_id": self.feed.pk})
        assert response.status_code in [200, 302, 400, 403]

    def test_decline_recommended_feed_post(self):
        """Test POST to decline recommended feed."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.post(reverse("decline-recommended-feed"), {"feed_id": self.feed.pk})
        assert response.status_code in [200, 302, 400, 403]
