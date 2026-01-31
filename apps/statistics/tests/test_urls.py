"""
URL tests for the statistics app.

Tests URL resolution and basic access patterns for all statistics endpoints.
"""

import pytest
from django.test import Client, TransactionTestCase
from django.urls import resolve, reverse


class Test_StatisticsURLResolution(TransactionTestCase):
    """Test that all statistics URLs resolve correctly."""

    def test_dashboard_graphs_resolves(self):
        """Test dashboard graphs URL resolves."""
        url = reverse("statistics-graphs")
        resolved = resolve(url)
        assert resolved.view_name == "statistics-graphs"

    def test_feedback_table_resolves(self):
        """Test feedback table URL resolves."""
        url = reverse("feedback-table")
        resolved = resolve(url)
        assert resolved.view_name == "feedback-table"

    def test_revenue_resolves(self):
        """Test revenue URL resolves."""
        url = reverse("revenue")
        resolved = resolve(url)
        assert resolved.view_name == "revenue"

    def test_slow_resolves(self):
        """Test slow URL resolves."""
        url = reverse("slow")
        resolved = resolve(url)
        assert resolved.view_name == "slow"


class Test_StatisticsURLAccess(TransactionTestCase):
    """Test access patterns for statistics URLs."""

    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
    ]

    def setUp(self):
        from django.contrib.auth.models import User

        self.client = Client()
        self.user = User.objects.create_user(username="testuser", password="testpass", email="test@test.com")
        # Make user a superuser for admin-only statistics
        self.admin = User.objects.create_superuser(
            username="admin", password="adminpass", email="admin@test.com"
        )

    def test_dashboard_graphs_authenticated(self):
        """Test authenticated access to dashboard graphs."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("statistics-graphs"))
        # May require admin or premium
        assert response.status_code in [200, 302, 403]

    def test_dashboard_graphs_admin(self):
        """Test admin access to dashboard graphs."""
        self.client.login(username="admin", password="adminpass")
        response = self.client.get(reverse("statistics-graphs"))
        assert response.status_code in [200, 302]

    def test_feedback_table_authenticated(self):
        """Test authenticated access to feedback table."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("feedback-table"))
        assert response.status_code in [200, 302, 403]

    def test_feedback_table_admin(self):
        """Test admin access to feedback table."""
        self.client.login(username="admin", password="adminpass")
        response = self.client.get(reverse("feedback-table"))
        assert response.status_code in [200, 302]

    def test_revenue_authenticated(self):
        """Test authenticated access to revenue."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("revenue"))
        assert response.status_code in [200, 302, 403]

    def test_revenue_admin(self):
        """Test admin access to revenue."""
        self.client.login(username="admin", password="adminpass")
        response = self.client.get(reverse("revenue"))
        assert response.status_code in [200, 302]

    def test_slow_authenticated(self):
        """Test authenticated access to slow."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("slow"))
        assert response.status_code in [200, 302, 403]

    def test_slow_admin(self):
        """Test admin access to slow."""
        self.client.login(username="admin", password="adminpass")
        response = self.client.get(reverse("slow"))
        assert response.status_code in [200, 302]
