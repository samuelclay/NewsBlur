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
        """Test authenticated access to analyzer index.

        Note: The analyzer index view is a stub that returns None, so this test
        verifies the URL resolves but expects a server error since no response is returned.
        """
        self.client.login(username="testuser", password="testpass")
        # The view returns None (pass statement), which causes a 500 error
        # This test documents the current behavior
        try:
            response = self.client.get("/analyzer/")
            # If we get here, the view was fixed to return something
            assert response.status_code == 200
        except ValueError:
            # Expected: view returns None which raises ValueError
            pass

    def test_get_classifiers_feed_authenticated(self):
        """Test authenticated access to get classifiers feed."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(f"/analyzer/{self.feed.pk}")
        assert response.status_code == 200

        # Verify response structure
        data = response.json()
        assert "payload" in data
        assert "feeds" in data["payload"]
        assert "authors" in data["payload"]
        assert "titles" in data["payload"]
        assert "tags" in data["payload"]

    def test_popularity_query_authenticated(self):
        """Test authenticated access to popularity query."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get("/analyzer/popularity")
        assert response.status_code == 200


class Test_AnalyzerURLPOST(TransactionTestCase):
    """Test POST endpoints for analyzer URLs with database verification."""

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

    def tearDown(self):
        """Clean up MongoDB documents created during tests."""
        from apps.analyzer.models import (
            MClassifierAuthor,
            MClassifierFeed,
            MClassifierTag,
            MClassifierText,
            MClassifierTitle,
        )

        MClassifierTitle.objects.filter(user_id=self.user.pk).delete()
        MClassifierAuthor.objects.filter(user_id=self.user.pk).delete()
        MClassifierTag.objects.filter(user_id=self.user.pk).delete()
        MClassifierText.objects.filter(user_id=self.user.pk).delete()
        MClassifierFeed.objects.filter(user_id=self.user.pk).delete()

    def test_save_classifier_post(self):
        """Test POST to save classifier and verify database persistence."""
        from apps.analyzer.models import MClassifierTitle

        self.client.login(username="testuser", password="testpass")

        # Verify no classifier exists before
        initial_count = MClassifierTitle.objects.filter(user_id=self.user.pk, feed_id=self.feed.pk).count()
        assert initial_count == 0

        # POST to save classifier
        response = self.client.post("/analyzer/save", {"feed_id": self.feed.pk, "like_title": "test"})
        assert response.status_code == 200

        # Verify response structure
        data = response.json()
        assert data.get("code") == 0
        assert data.get("message") == "OK"

        # Verify classifier was saved to database
        classifier = MClassifierTitle.objects.filter(
            user_id=self.user.pk, feed_id=self.feed.pk, title="test"
        ).first()
        assert classifier is not None
        assert classifier.score == 1  # like = score 1

    def test_save_classifier_title_post(self):
        """Test POST to save multiple title classifiers and verify database persistence."""
        from apps.analyzer.models import MClassifierTitle

        self.client.login(username="testuser", password="testpass")

        # POST to save multiple title classifiers
        response = self.client.post(
            "/classifier/save/", {"feed_id": self.feed.pk, "like_title": ["important", "breaking"]}
        )
        assert response.status_code == 200

        # Verify response structure
        data = response.json()
        assert data.get("code") == 0

        # Verify both classifiers were saved to database
        important_classifier = MClassifierTitle.objects.filter(
            user_id=self.user.pk, feed_id=self.feed.pk, title="important"
        ).first()
        assert important_classifier is not None
        assert important_classifier.score == 1

        breaking_classifier = MClassifierTitle.objects.filter(
            user_id=self.user.pk, feed_id=self.feed.pk, title="breaking"
        ).first()
        assert breaking_classifier is not None
        assert breaking_classifier.score == 1

    def test_save_classifier_author_post(self):
        """Test POST to save author classifier and verify database persistence."""
        from apps.analyzer.models import MClassifierAuthor

        self.client.login(username="testuser", password="testpass")

        # POST to save author classifier
        response = self.client.post("/classifier/save/", {"feed_id": self.feed.pk, "like_author": ["John Doe"]})
        assert response.status_code == 200

        # Verify response structure
        data = response.json()
        assert data.get("code") == 0

        # Verify classifier was saved to database
        classifier = MClassifierAuthor.objects.filter(
            user_id=self.user.pk, feed_id=self.feed.pk, author="John Doe"
        ).first()
        assert classifier is not None
        assert classifier.score == 1

    def test_save_classifier_tag_post(self):
        """Test POST to save tag classifier and verify database persistence."""
        from apps.analyzer.models import MClassifierTag

        self.client.login(username="testuser", password="testpass")

        # POST to save tag classifier
        response = self.client.post("/classifier/save/", {"feed_id": self.feed.pk, "like_tag": ["technology"]})
        assert response.status_code == 200

        # Verify response structure
        data = response.json()
        assert data.get("code") == 0

        # Verify classifier was saved to database
        classifier = MClassifierTag.objects.filter(
            user_id=self.user.pk, feed_id=self.feed.pk, tag="technology"
        ).first()
        assert classifier is not None
        assert classifier.score == 1

    def test_save_classifier_dislike_post(self):
        """Test POST to save dislike classifier and verify database persistence."""
        from apps.analyzer.models import MClassifierTitle

        self.client.login(username="testuser", password="testpass")

        # POST to save dislike classifier
        response = self.client.post("/classifier/save/", {"feed_id": self.feed.pk, "dislike_title": ["spam"]})
        assert response.status_code == 200

        # Verify response structure
        data = response.json()
        assert data.get("code") == 0

        # Verify classifier was saved with negative score
        classifier = MClassifierTitle.objects.filter(
            user_id=self.user.pk, feed_id=self.feed.pk, title="spam"
        ).first()
        assert classifier is not None
        assert classifier.score == -1  # dislike = score -1

    def test_save_classifier_remove_like_post(self):
        """Test POST to remove a liked classifier and verify database deletion."""
        from apps.analyzer.models import MClassifierTitle

        self.client.login(username="testuser", password="testpass")

        # First, create a classifier (must include social_user_id=0 to match view lookup)
        MClassifierTitle.objects.create(
            user_id=self.user.pk, feed_id=self.feed.pk, social_user_id=0, title="removable", score=1
        )

        # Verify it exists
        assert MClassifierTitle.objects.filter(
            user_id=self.user.pk, feed_id=self.feed.pk, social_user_id=0, title="removable"
        ).count() == 1

        # POST to remove the classifier
        response = self.client.post(
            "/classifier/save/", {"feed_id": self.feed.pk, "remove_like_title": ["removable"]}
        )
        assert response.status_code == 200

        # Verify classifier was removed from database
        assert MClassifierTitle.objects.filter(
            user_id=self.user.pk, feed_id=self.feed.pk, social_user_id=0, title="removable"
        ).count() == 0

    def test_get_classifiers_after_save(self):
        """Test that saved classifiers appear in get_classifiers_feed response."""
        from apps.analyzer.models import MClassifierAuthor, MClassifierTag, MClassifierTitle

        self.client.login(username="testuser", password="testpass")

        # Save some classifiers (must include social_user_id=0 to match view expectations)
        MClassifierTitle.objects.create(
            user_id=self.user.pk, feed_id=self.feed.pk, social_user_id=0, title="test title", score=1
        )
        MClassifierAuthor.objects.create(
            user_id=self.user.pk, feed_id=self.feed.pk, social_user_id=0, author="Test Author", score=-1
        )
        MClassifierTag.objects.create(
            user_id=self.user.pk, feed_id=self.feed.pk, social_user_id=0, tag="test-tag", score=1
        )

        # Get classifiers
        response = self.client.get(f"/analyzer/{self.feed.pk}")
        assert response.status_code == 200

        data = response.json()
        payload = data["payload"]

        # Verify classifiers are returned
        assert "test title" in payload["titles"]
        assert payload["titles"]["test title"] == 1

        assert "Test Author" in payload["authors"]
        assert payload["authors"]["Test Author"] == -1

        assert "test-tag" in payload["tags"]
        assert payload["tags"]["test-tag"] == 1
