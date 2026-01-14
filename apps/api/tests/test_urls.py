"""
URL tests for the api app.

Tests URL resolution and basic access patterns for all api endpoints.
"""

import pytest
from django.test import Client, TransactionTestCase
from django.urls import resolve, reverse


class Test_APIURLResolution(TransactionTestCase):
    """Test that all API URLs resolve correctly."""

    def test_api_logout_resolves(self):
        """Test API logout URL resolves."""
        url = reverse("api-logout")
        resolved = resolve(url)
        assert resolved.view_name == "api-logout"

    def test_api_login_resolves(self):
        """Test API login URL resolves."""
        url = reverse("api-login")
        resolved = resolve(url)
        assert resolved.view_name == "api-login"

    def test_api_signup_resolves(self):
        """Test API signup URL resolves."""
        url = reverse("api-signup")
        resolved = resolve(url)
        assert resolved.view_name == "api-signup"

    def test_api_add_site_load_script_resolves(self):
        """Test API add site load script URL resolves."""
        url = reverse("api-add-site-load-script", kwargs={"token": "abc123"})
        resolved = resolve(url)
        assert resolved.view_name == "api-add-site-load-script"

    def test_api_add_site_resolves(self):
        """Test API add site URL resolves."""
        url = reverse("api-add-site", kwargs={"token": "abc123"})
        resolved = resolve(url)
        assert resolved.view_name == "api-add-site"

    def test_api_add_site_authed_resolves(self):
        """Test API add site authed URL resolves."""
        url = reverse("api-add-site-authed")
        resolved = resolve(url)
        assert resolved.view_name == "api-add-site-authed"

    def test_api_check_share_on_site_resolves(self):
        """Test API check share on site URL resolves."""
        url = reverse("api-check-share-on-site", kwargs={"token": "abc123"})
        resolved = resolve(url)
        assert resolved.view_name == "api-check-share-on-site"

    def test_api_share_story_resolves(self):
        """Test API share story URL resolves."""
        url = reverse("api-share-story", kwargs={"token": "abc123"})
        resolved = resolve(url)
        assert resolved.view_name == "api-share-story"

    def test_api_save_story_resolves(self):
        """Test API save story URL resolves."""
        url = reverse("api-save-story", kwargs={"token": "abc123"})
        resolved = resolve(url)
        assert resolved.view_name == "api-save-story"


class Test_APIURLPaths(TransactionTestCase):
    """Test API URL paths resolve correctly."""

    def test_api_share_story_path_resolves(self):
        """Test /api/share_story path resolves."""
        resolved = resolve("/api/share_story")
        assert resolved.func.__name__ == "share_story"

    def test_api_save_story_path_resolves(self):
        """Test /api/save_story path resolves."""
        resolved = resolve("/api/save_story")
        assert resolved.func.__name__ == "save_story"

    def test_api_ip_addresses_path_resolves(self):
        """Test /api/ip_addresses path resolves."""
        resolved = resolve("/api/ip_addresses")
        assert resolved.func.__name__ == "ip_addresses"


class Test_APIURLAccess(TransactionTestCase):
    """Test access patterns for API URLs."""

    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
    ]

    def setUp(self):
        from django.contrib.auth.models import User

        self.client = Client()
        self.user = User.objects.create_user(username="testuser", password="testpass", email="test@test.com")

    def test_api_login_anonymous(self):
        """Test anonymous access to API login."""
        response = self.client.get(reverse("api-login"))
        assert response.status_code in [200, 302, 405]

    def test_api_signup_anonymous(self):
        """Test anonymous access to API signup."""
        response = self.client.get(reverse("api-signup"))
        assert response.status_code in [200, 302, 405]

    def test_api_logout_authenticated(self):
        """Test authenticated access to API logout."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("api-logout"))
        assert response.status_code in [200, 302]


class Test_APIURLPOST(TransactionTestCase):
    """Test POST endpoints for API URLs."""

    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
    ]

    def setUp(self):
        from django.contrib.auth.models import User

        self.client = Client()
        self.user = User.objects.create_user(username="testuser", password="testpass", email="test@test.com")

    def test_api_login_post(self):
        """Test POST to API login."""
        response = self.client.post(reverse("api-login"), {"username": "testuser", "password": "testpass"})
        assert response.status_code in [200, 302, 400]

    def test_api_signup_post(self):
        """Test POST to API signup."""
        response = self.client.post(
            reverse("api-signup"), {"username": "newuser", "password": "newpass", "email": "new@test.com"}
        )
        assert response.status_code in [200, 302, 400]

    def test_api_add_site_authed_post(self):
        """Test POST to API add site authed."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.post(reverse("api-add-site-authed"), {"url": "http://example.com/feed.xml"})
        assert response.status_code in [200, 302, 400]
