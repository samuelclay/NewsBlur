"""
URL tests for the analyzer app.

Tests URL resolution and basic access patterns for all analyzer endpoints.
"""

import pytest
from django.test import Client, TransactionTestCase
from django.urls import resolve, reverse


class Test_AnalyzerURLResolution(TransactionTestCase):
    """Test that all analyzer URLs resolve correctly."""

    def test_analyzer_index_resolves(self):
        """Test analyzer index URL resolves."""
        resolved = resolve("/analyzer/")
        assert resolved.func.__name__ == "index"

    def test_classifier_index_resolves(self):
        """Test classifier index URL resolves."""
        resolved = resolve("/classifier/")
        assert resolved.func.__name__ == "index"

    def test_save_classifier_resolves(self):
        """Test save classifier URL resolves."""
        resolved = resolve("/analyzer/save")
        assert resolved.func.__name__ == "save_classifier"

    def test_popularity_query_resolves(self):
        """Test popularity query URL resolves."""
        resolved = resolve("/analyzer/popularity")
        assert resolved.func.__name__ == "popularity_query"

    def test_get_classifiers_feed_resolves(self):
        """Test get classifiers feed URL resolves."""
        resolved = resolve("/analyzer/1")
        assert resolved.func.__name__ == "get_classifiers_feed"


class Test_AnalyzerURLAccess(TransactionTestCase):
    """Test access patterns for analyzer URLs."""

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

    def test_analyzer_index_authenticated(self):
        """Test authenticated access to analyzer index."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get("/analyzer/")
        assert response.status_code in [200, 302]

    def test_get_classifiers_feed_authenticated(self):
        """Test authenticated access to get classifiers feed."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(f"/analyzer/{self.feed.pk}")
        assert response.status_code in [200, 302, 404]

    def test_popularity_query_authenticated(self):
        """Test authenticated access to popularity query."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get("/analyzer/popularity")
        assert response.status_code in [200, 302]


class Test_AnalyzerURLPOST(TransactionTestCase):
    """Test POST endpoints for analyzer URLs."""

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

    def test_save_classifier_post(self):
        """Test POST to save classifier."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.post("/analyzer/save", {"feed_id": self.feed.pk, "like_title": "test"})
        assert response.status_code in [200, 302, 400]

    def test_save_classifier_title_post(self):
        """Test POST to save title classifier."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.post(
            "/classifier/save/", {"feed_id": self.feed.pk, "like_title": ["important", "breaking"]}
        )
        assert response.status_code in [200, 302, 400]

    def test_save_classifier_author_post(self):
        """Test POST to save author classifier."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.post("/classifier/save/", {"feed_id": self.feed.pk, "like_author": ["John Doe"]})
        assert response.status_code in [200, 302, 400]

    def test_save_classifier_tag_post(self):
        """Test POST to save tag classifier."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.post("/classifier/save/", {"feed_id": self.feed.pk, "like_tag": ["technology"]})
        assert response.status_code in [200, 302, 400]

    def test_save_classifier_dislike_post(self):
        """Test POST to save dislike classifier."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.post("/classifier/save/", {"feed_id": self.feed.pk, "dislike_title": ["spam"]})
        assert response.status_code in [200, 302, 400]
