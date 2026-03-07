"""Tests for static pages: verify all static content pages load without errors."""

from django.test import Client, TransactionTestCase
from django.urls import reverse


class Test_StaticPageLoading(TransactionTestCase):
    """Test that all static content pages return 200 and render without errors."""

    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
    ]

    def setUp(self):
        self.client = Client(HTTP_USER_AGENT="Mozilla/5.0 (Test)")

    def test_about_page(self):
        response = self.client.get("/about")
        assert response.status_code == 200, f"/about returned {response.status_code}"

    def test_faq_page(self):
        response = self.client.get("/faq")
        assert response.status_code == 200, f"/faq returned {response.status_code}"

    def test_api_page(self):
        response = self.client.get("/api")
        assert response.status_code == 200, f"/api returned {response.status_code}"

    def test_press_page(self):
        response = self.client.get("/press")
        assert response.status_code == 200, f"/press returned {response.status_code}"

    def test_feedback_page(self):
        response = self.client.get("/feedback")
        assert response.status_code == 200, f"/feedback returned {response.status_code}"

    def test_privacy_page(self):
        response = self.client.get("/privacy")
        assert response.status_code == 200, f"/privacy returned {response.status_code}"

    def test_tos_page(self):
        response = self.client.get("/tos")
        assert response.status_code == 200, f"/tos returned {response.status_code}"

    def test_ios_page(self):
        response = self.client.get("/ios")
        assert response.status_code == 200, f"/ios returned {response.status_code}"

    def test_android_page(self):
        response = self.client.get("/android")
        assert response.status_code == 200, f"/android returned {response.status_code}"

    def test_ios_download_page(self):
        response = self.client.get("/ios/download")
        assert response.status_code == 200, f"/ios/download returned {response.status_code}"

    def test_health_check(self):
        response = self.client.get("/health-check")
        assert response.status_code == 200, f"/health-check returned {response.status_code}"

    def test_haproxy_check(self):
        response = self.client.get("/_haproxychk")
        assert response.status_code == 200, f"/_haproxychk returned {response.status_code}"

    def test_webmanifest(self):
        response = self.client.get("/manifest.webmanifest")
        assert response.status_code == 200, f"/manifest.webmanifest returned {response.status_code}"

    def test_apple_app_site_association(self):
        response = self.client.get("/.well-known/apple-app-site-association")
        assert response.status_code == 200, f"apple-app-site-association returned {response.status_code}"

    def test_apple_developer_merchantid(self):
        response = self.client.get("/.well-known/apple-developer-merchantid-domain-association")
        assert response.status_code == 200, (
            f"apple-developer-merchantid returned {response.status_code}"
        )

    def test_assetlinks(self):
        response = self.client.get("/.well-known/assetlinks.json")
        assert response.status_code == 200, f"assetlinks.json returned {response.status_code}"


class Test_StaticPageRouting(TransactionTestCase):
    """Test that static page URLs route to the correct views (not caught by other patterns)."""

    def test_feedback_routes_to_static_view(self):
        """Verify /feedback hits static feedback view, not social feed view."""
        from django.urls import resolve

        resolved = resolve("/feedback")
        assert resolved.func.__name__ == "feedback", (
            f"/feedback resolved to {resolved.func.__module__}.{resolved.func.__name__}, "
            f"expected apps.static.views.feedback"
        )

    def test_api_page_routes_to_static_view(self):
        """Verify /api hits static api view, not api app include."""
        from django.urls import resolve

        resolved = resolve("/api")
        assert resolved.func.__name__ == "api", (
            f"/api resolved to {resolved.func.__module__}.{resolved.func.__name__}, "
            f"expected apps.static.views.api"
        )

    def test_about_routes_to_static_view(self):
        from django.urls import resolve

        resolved = resolve("/about")
        assert resolved.func.__name__ == "about"

    def test_faq_routes_to_static_view(self):
        from django.urls import resolve

        resolved = resolve("/faq")
        assert resolved.func.__name__ == "faq"

    def test_press_routes_to_static_view(self):
        from django.urls import resolve

        resolved = resolve("/press")
        assert resolved.func.__name__ == "press"

    def test_privacy_routes_to_static_view(self):
        from django.urls import resolve

        resolved = resolve("/privacy")
        assert resolved.func.__name__ == "privacy"

    def test_tos_routes_to_static_view(self):
        from django.urls import resolve

        resolved = resolve("/tos")
        assert resolved.func.__name__ == "tos"
