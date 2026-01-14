"""
URL tests for the categories app.

Tests URL resolution and basic access patterns for all categories endpoints.
"""

import pytest
from django.test import Client, TransactionTestCase
from django.urls import resolve, reverse


class Test_CategoriesURLResolution(TransactionTestCase):
    """Test that all categories URLs resolve correctly."""

    def test_all_categories_resolves(self):
        """Test all categories URL resolves."""
        url = reverse("all-categories")
        resolved = resolve(url)
        assert resolved.view_name == "all-categories"

    def test_categories_subscribe_resolves(self):
        """Test categories subscribe URL resolves."""
        url = reverse("categories-subscribe")
        resolved = resolve(url)
        assert resolved.view_name == "categories-subscribe"


class Test_CategoriesURLAccess(TransactionTestCase):
    """Test access patterns for categories URLs."""

    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
    ]

    def setUp(self):
        from django.contrib.auth.models import User

        self.client = Client()
        self.user = User.objects.create_user(username="testuser", password="testpass", email="test@test.com")

    def test_all_categories_authenticated(self):
        """Test authenticated access to all categories."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("all-categories"))
        assert response.status_code == 200

    def test_all_categories_anonymous(self):
        """Test anonymous access to all categories."""
        response = self.client.get(reverse("all-categories"))
        assert response.status_code in [200, 302, 403]


class Test_CategoriesURLPOST(TransactionTestCase):
    """Test POST endpoints for categories URLs."""

    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
    ]

    def setUp(self):
        from django.contrib.auth.models import User

        self.client = Client()
        self.user = User.objects.create_user(username="testuser", password="testpass", email="test@test.com")

    def test_categories_subscribe_post(self):
        """Test POST to subscribe to category."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.post(reverse("categories-subscribe"), {"category": "technology"})
        assert response.status_code in [200, 302, 400]
