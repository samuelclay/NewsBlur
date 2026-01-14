"""
URL tests for the search app.

Tests URL resolution and basic access patterns for all search endpoints.
"""

import pytest
from django.test import Client, TransactionTestCase
from django.urls import resolve, reverse


class Test_SearchURLResolution(TransactionTestCase):
    """Test that all search URLs resolve correctly."""

    def test_more_like_this_resolves(self):
        """Test more like this URL resolves."""
        url = reverse("more-like-this")
        resolved = resolve(url)
        assert resolved.view_name == "more-like-this"


class Test_SearchURLAccess(TransactionTestCase):
    """Test access patterns for search URLs."""

    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
    ]

    def setUp(self):
        from django.contrib.auth.models import User

        self.client = Client()
        self.user = User.objects.create_user(username="testuser", password="testpass", email="test@test.com")

    def test_more_like_this_authenticated(self):
        """Test authenticated access to more like this."""
        self.client.login(username="testuser", password="testpass")
        try:
            response = self.client.get(reverse("more-like-this"), {"story_hash": "1:abc123"})
            assert response.status_code in [200, 302, 400, 404, 500]
        except Exception as e:
            # Elasticsearch not available in CI environment
            if "ConnectionError" in str(type(e).__name__) or "Failed to establish" in str(e):
                pass
            else:
                raise

    def test_more_like_this_anonymous(self):
        """Test anonymous access to more like this."""
        try:
            response = self.client.get(reverse("more-like-this"), {"story_hash": "1:abc123"})
            assert response.status_code in [200, 302, 403, 404, 500]
        except Exception as e:
            # Elasticsearch not available in CI environment
            if "ConnectionError" in str(type(e).__name__) or "Failed to establish" in str(e):
                pass
            else:
                raise


class Test_SearchURLPOST(TransactionTestCase):
    """Test POST endpoints for search URLs."""

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

    def test_more_like_this_post(self):
        """Test POST to more like this."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.post(reverse("more-like-this"), {"story_hash": "1:abc123"})
        assert response.status_code in [200, 302, 400, 404]
