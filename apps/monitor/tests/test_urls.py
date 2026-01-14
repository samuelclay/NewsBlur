"""
URL tests for the monitor app.

Tests URL resolution and basic access patterns for all monitor endpoints.
"""

import pytest
from django.test import Client, TransactionTestCase
from django.urls import resolve, reverse


class Test_MonitorURLResolution(TransactionTestCase):
    """Test that all monitor URLs resolve correctly."""

    def test_app_servers_resolves(self):
        """Test app servers URL resolves."""
        url = reverse("app_servers")
        resolved = resolve(url)
        assert resolved.view_name == "app_servers"

    def test_app_times_resolves(self):
        """Test app times URL resolves."""
        url = reverse("app_times")
        resolved = resolve(url)
        assert resolved.view_name == "app_times"

    def test_ask_ai_monitor_resolves(self):
        """Test ask AI monitor URL resolves."""
        url = reverse("ask_ai")
        resolved = resolve(url)
        assert resolved.view_name == "ask_ai"

    def test_classifiers_resolves(self):
        """Test classifiers URL resolves."""
        url = reverse("classifiers")
        resolved = resolve(url)
        assert resolved.view_name == "classifiers"

    def test_db_times_resolves(self):
        """Test db times URL resolves."""
        url = reverse("db_times")
        resolved = resolve(url)
        assert resolved.view_name == "db_times"

    def test_errors_resolves(self):
        """Test errors URL resolves."""
        url = reverse("errors")
        resolved = resolve(url)
        assert resolved.view_name == "errors"

    def test_feed_counts_resolves(self):
        """Test feed counts URL resolves."""
        url = reverse("feed_counts")
        resolved = resolve(url)
        assert resolved.view_name == "feed_counts"

    def test_feed_sizes_resolves(self):
        """Test feed sizes URL resolves."""
        url = reverse("feed_sizes")
        resolved = resolve(url)
        assert resolved.view_name == "feed_sizes"

    def test_feeds_resolves(self):
        """Test feeds URL resolves."""
        url = reverse("feeds")
        resolved = resolve(url)
        assert resolved.view_name == "feeds"

    def test_load_times_resolves(self):
        """Test load times URL resolves."""
        url = reverse("load_times")
        resolved = resolve(url)
        assert resolved.view_name == "load_times"

    def test_stories_resolves(self):
        """Test stories URL resolves."""
        url = reverse("stories")
        resolved = resolve(url)
        assert resolved.view_name == "stories"

    def test_task_codes_resolves(self):
        """Test task codes URL resolves."""
        url = reverse("task_codes")
        resolved = resolve(url)
        assert resolved.view_name == "task_codes"

    def test_task_pipeline_resolves(self):
        """Test task pipeline URL resolves."""
        url = reverse("task_pipeline")
        resolved = resolve(url)
        assert resolved.view_name == "task_pipeline"

    def test_task_servers_resolves(self):
        """Test task servers URL resolves."""
        url = reverse("task_servers")
        resolved = resolve(url)
        assert resolved.view_name == "task_servers"

    def test_task_times_resolves(self):
        """Test task times URL resolves."""
        url = reverse("task_times")
        resolved = resolve(url)
        assert resolved.view_name == "task_times"

    def test_updates_resolves(self):
        """Test updates URL resolves."""
        url = reverse("updates")
        resolved = resolve(url)
        assert resolved.view_name == "updates"

    def test_users_resolves(self):
        """Test users URL resolves."""
        url = reverse("users")
        resolved = resolve(url)
        assert resolved.view_name == "users"

    def test_user_searches_resolves(self):
        """Test user searches URL resolves."""
        url = reverse("user_searches")
        resolved = resolve(url)
        assert resolved.view_name == "user_searches"

    def test_trending_feeds_resolves(self):
        """Test trending feeds URL resolves."""
        url = reverse("trending_feeds")
        resolved = resolve(url)
        assert resolved.view_name == "trending_feeds"

    def test_trending_subscriptions_resolves(self):
        """Test trending subscriptions URL resolves."""
        url = reverse("trending_subscriptions")
        resolved = resolve(url)
        assert resolved.view_name == "trending_subscriptions"


class Test_MonitorURLAccess(TransactionTestCase):
    """Test access patterns for monitor URLs."""

    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
    ]

    def setUp(self):
        self.client = Client()

    def test_app_servers_access(self):
        """Test access to app servers."""
        response = self.client.get(reverse("app_servers"))
        assert response.status_code in [200, 302, 403]

    def test_app_times_access(self):
        """Test access to app times."""
        response = self.client.get(reverse("app_times"))
        assert response.status_code in [200, 302, 403]

    def test_db_times_access(self):
        """Test access to db times."""
        response = self.client.get(reverse("db_times"))
        assert response.status_code in [200, 302, 403]

    def test_errors_access(self):
        """Test access to errors."""
        response = self.client.get(reverse("errors"))
        assert response.status_code in [200, 302, 403]

    def test_feeds_access(self):
        """Test access to feeds."""
        response = self.client.get(reverse("feeds"))
        assert response.status_code in [200, 302, 403]

    def test_stories_access(self):
        """Test access to stories."""
        response = self.client.get(reverse("stories"))
        assert response.status_code in [200, 302, 403]

    def test_users_access(self):
        """Test access to users."""
        response = self.client.get(reverse("users"))
        assert response.status_code in [200, 302, 403]

    def test_updates_access(self):
        """Test access to updates."""
        response = self.client.get(reverse("updates"))
        assert response.status_code in [200, 302, 403]

    def test_trending_feeds_access(self):
        """Test access to trending feeds."""
        response = self.client.get(reverse("trending_feeds"))
        assert response.status_code in [200, 302, 403]

    def test_trending_subscriptions_access(self):
        """Test access to trending subscriptions."""
        response = self.client.get(reverse("trending_subscriptions"))
        assert response.status_code in [200, 302, 403]
