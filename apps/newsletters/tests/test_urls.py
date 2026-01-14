"""
URL tests for the newsletters app.

Tests URL resolution and basic access patterns for all newsletters endpoints.
"""

import pytest
from django.test import Client, TransactionTestCase
from django.urls import resolve, reverse


class Test_NewslettersURLResolution(TransactionTestCase):
    """Test that all newsletters URLs resolve correctly."""

    def test_newsletter_receive_resolves(self):
        """Test newsletter receive URL resolves."""
        url = reverse("newsletter-receive")
        resolved = resolve(url)
        assert resolved.view_name == "newsletter-receive"

    def test_newsletter_story_resolves(self):
        """Test newsletter story URL resolves."""
        url = reverse("newsletter-story", kwargs={"story_hash": "1:abc123"})
        resolved = resolve(url)
        assert resolved.view_name == "newsletter-story"


class Test_NewslettersURLAccess(TransactionTestCase):
    """Test access patterns for newsletters URLs."""

    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
    ]

    def setUp(self):
        from django.contrib.auth.models import User

        self.client = Client()
        self.user = User.objects.create_user(username="testuser", password="testpass", email="test@test.com")

    def test_newsletter_receive_anonymous(self):
        """Test anonymous access to newsletter receive."""
        response = self.client.get(reverse("newsletter-receive"))
        # This endpoint receives emails, so GET may not be allowed
        assert response.status_code in [200, 302, 403, 405]

    def test_newsletter_story_anonymous(self):
        """Test anonymous access to newsletter story."""
        response = self.client.get(reverse("newsletter-story", kwargs={"story_hash": "1:abc123"}))
        assert response.status_code in [200, 302, 404]


class Test_NewslettersURLPOST(TransactionTestCase):
    """Test POST endpoints for newsletters URLs."""

    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
    ]

    def setUp(self):
        from django.contrib.auth.models import User

        self.client = Client()
        self.user = User.objects.create_user(username="testuser", password="testpass", email="test@test.com")

    def test_newsletter_receive_post(self):
        """Test POST to newsletter receive."""
        response = self.client.post(
            reverse("newsletter-receive"),
            {
                "sender": "sender@example.com",
                "recipient": "test@newsletters.newsblur.com",
                "subject": "Test Newsletter",
                "body-plain": "Test content",
            },
        )
        assert response.status_code in [200, 302, 400, 406]
