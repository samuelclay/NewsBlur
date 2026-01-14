"""
URL tests for the ask_ai app.

Tests URL resolution and basic access patterns for all ask_ai endpoints.
"""

import pytest
from django.test import Client, TransactionTestCase
from django.urls import resolve, reverse


class Test_AskAIURLResolution(TransactionTestCase):
    """Test that all ask_ai URLs resolve correctly."""

    def test_ask_ai_question_resolves(self):
        """Test ask AI question URL resolves."""
        url = reverse("ask-ai-question")
        resolved = resolve(url)
        assert resolved.view_name == "ask-ai-question"

    def test_transcribe_audio_resolves(self):
        """Test transcribe audio URL resolves."""
        url = reverse("ask-ai-transcribe")
        resolved = resolve(url)
        assert resolved.view_name == "ask-ai-transcribe"


class Test_AskAIURLAccess(TransactionTestCase):
    """Test access patterns for ask_ai URLs."""

    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
    ]

    def setUp(self):
        from django.contrib.auth.models import User

        self.client = Client()
        self.user = User.objects.create_user(username="testuser", password="testpass", email="test@test.com")

    def test_ask_ai_question_anonymous_rejected(self):
        """Test anonymous access to ask AI question is rejected."""
        response = self.client.get(reverse("ask-ai-question"))
        assert response.status_code in [302, 403, 405]

    def test_transcribe_audio_anonymous_rejected(self):
        """Test anonymous access to transcribe audio is rejected."""
        response = self.client.get(reverse("ask-ai-transcribe"))
        assert response.status_code in [302, 403, 405]


class Test_AskAIURLPOST(TransactionTestCase):
    """Test POST endpoints for ask_ai URLs."""

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

    def test_ask_ai_question_post(self):
        """Test POST to ask AI question."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.post(
            reverse("ask-ai-question"),
            {"question": "What is this story about?", "story_hash": "1:abc123", "model": "gpt-4"},
        )
        # Will return error because story doesn't exist, but endpoint should be accessible
        assert response.status_code in [200, 302, 400, 404]

    def test_ask_ai_question_missing_params(self):
        """Test POST to ask AI question with missing parameters."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.post(reverse("ask-ai-question"), {})
        assert response.status_code in [200, 302, 400]

    def test_transcribe_audio_post(self):
        """Test POST to transcribe audio."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.post(reverse("ask-ai-transcribe"), {"audio_url": "http://example.com/audio.mp3"})
        assert response.status_code in [200, 302, 400]
