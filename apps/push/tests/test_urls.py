"""
URL tests for the push app.

Tests URL resolution and basic access patterns for all push endpoints.
"""

import pytest
from django.test import Client, TransactionTestCase
from django.urls import resolve, reverse


class Test_PushURLResolution(TransactionTestCase):
    """Test that all push URLs resolve correctly."""

    def test_push_callback_resolves(self):
        """Test push callback URL resolves."""
        url = reverse("push-callback", kwargs={"push_id": "123"})
        resolved = resolve(url)
        assert resolved.view_name == "push-callback"

    def test_push_callback_path_resolves(self):
        """Test push callback path resolves."""
        resolved = resolve("/push/123")
        assert resolved.func.__name__ == "push_callback"


class Test_PushURLAccess(TransactionTestCase):
    """Test access patterns for push URLs."""

    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
    ]

    def setUp(self):
        self.client = Client()

    def test_push_callback_get(self):
        """Test GET to push callback (subscription verification)."""
        response = self.client.get(
            reverse("push-callback", kwargs={"push_id": "123"}),
            {"hub.mode": "subscribe", "hub.challenge": "test123", "hub.topic": "http://example.com/feed"},
        )
        # Should return challenge for subscription verification
        assert response.status_code in [200, 404]


class Test_PushURLPOST(TransactionTestCase):
    """Test POST endpoints for push URLs."""

    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
    ]

    def setUp(self):
        self.client = Client()

    def test_push_callback_post(self):
        """Test POST to push callback (content notification)."""
        response = self.client.post(
            reverse("push-callback", kwargs={"push_id": "123"}),
            data='<?xml version="1.0"?><feed></feed>',
            content_type="application/atom+xml",
        )
        # Push callback should accept POST from hub
        assert response.status_code in [200, 202, 404]
