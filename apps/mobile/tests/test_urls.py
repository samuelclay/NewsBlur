"""
URL tests for the mobile app.

Tests URL resolution and basic access patterns for all mobile endpoints.
"""

import pytest
from django.test import Client, TransactionTestCase
from django.urls import resolve, reverse


class Test_MobileURLResolution(TransactionTestCase):
    """Test that all mobile URLs resolve correctly."""

    def test_mobile_index_resolves(self):
        """Test mobile index URL resolves."""
        url = reverse("mobile-index")
        resolved = resolve(url)
        assert resolved.view_name == "mobile-index"

    def test_mobile_path_resolves(self):
        """Test /mobile/ path resolves."""
        resolved = resolve("/mobile/")
        assert resolved.func.__name__ == "index"

    def test_m_path_resolves(self):
        """Test /m/ path resolves."""
        resolved = resolve("/m/")
        assert resolved.func.__name__ == "index"


class Test_MobileURLAccess(TransactionTestCase):
    """Test access patterns for mobile URLs."""

    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
    ]

    def setUp(self):
        from django.contrib.auth.models import User

        self.client = Client()
        self.user = User.objects.create_user(username="testuser", password="testpass", email="test@test.com")

    def test_mobile_index_anonymous(self):
        """Test anonymous access to mobile index."""
        response = self.client.get(reverse("mobile-index"))
        assert response.status_code in [200, 302]

    def test_mobile_index_authenticated(self):
        """Test authenticated access to mobile index."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("mobile-index"))
        assert response.status_code in [200, 302]
