"""
URL tests for the newsblur_web main app.

Tests URL resolution and basic access patterns for all main endpoints.
"""

import pytest
from django.test import Client, TransactionTestCase
from django.urls import resolve, reverse


class Test_MainURLResolution(TransactionTestCase):
    """Test that all main URLs resolve correctly."""

    def test_index_resolves(self):
        """Test index URL resolves."""
        url = reverse("index")
        resolved = resolve(url)
        assert resolved.view_name == "index"

    def test_about_resolves(self):
        """Test about URL resolves."""
        url = reverse("about")
        resolved = resolve(url)
        assert resolved.view_name == "about"

    def test_faq_resolves(self):
        """Test FAQ URL resolves."""
        url = reverse("faq")
        resolved = resolve(url)
        assert resolved.view_name == "faq"

    def test_api_page_resolves(self):
        """Test API page URL resolves."""
        url = reverse("api")
        resolved = resolve(url)
        assert resolved.view_name == "api"

    def test_press_resolves(self):
        """Test press URL resolves."""
        url = reverse("press")
        resolved = resolve(url)
        assert resolved.view_name == "press"

    def test_feedback_resolves(self):
        """Test feedback URL resolves."""
        url = reverse("feedback")
        resolved = resolve(url)
        assert resolved.view_name == "feedback"

    def test_privacy_resolves(self):
        """Test privacy URL resolves."""
        url = reverse("privacy")
        resolved = resolve(url)
        assert resolved.view_name == "privacy"

    def test_tos_resolves(self):
        """Test TOS URL resolves."""
        url = reverse("tos")
        resolved = resolve(url)
        assert resolved.view_name == "tos"

    def test_webmanifest_resolves(self):
        """Test webmanifest URL resolves."""
        url = reverse("webmanifest")
        resolved = resolve(url)
        assert resolved.view_name == "webmanifest"

    def test_apple_app_site_assoc_resolves(self):
        """Test Apple app site association URL resolves."""
        url = reverse("apple-app-site-assoc")
        resolved = resolve(url)
        assert resolved.view_name == "apple-app-site-assoc"

    def test_apple_developer_merchantid_resolves(self):
        """Test Apple developer merchantid URL resolves."""
        url = reverse("apple-developer-merchantid")
        resolved = resolve(url)
        assert resolved.view_name == "apple-developer-merchantid"

    def test_ios_download_resolves(self):
        """Test iOS download URL resolves."""
        url = reverse("ios-download")
        resolved = resolve(url)
        assert resolved.view_name == "ios-download"

    def test_ios_download_plist_resolves(self):
        """Test iOS download plist URL resolves."""
        url = reverse("ios-download-plist")
        resolved = resolve(url)
        assert resolved.view_name == "ios-download-plist"

    def test_ios_download_ipa_resolves(self):
        """Test iOS download IPA URL resolves."""
        url = reverse("ios-download-ipa")
        resolved = resolve(url)
        assert resolved.view_name == "ios-download-ipa"

    def test_ios_static_resolves(self):
        """Test iOS static URL resolves."""
        url = reverse("ios-static")
        resolved = resolve(url)
        assert resolved.view_name == "ios-static"

    def test_android_static_resolves(self):
        """Test Android static URL resolves."""
        url = reverse("android-static")
        resolved = resolve(url)
        assert resolved.view_name == "android-static"

    def test_firefox_resolves(self):
        """Test Firefox URL resolves."""
        url = reverse("firefox")
        resolved = resolve(url)
        assert resolved.view_name == "firefox"

    def test_redeem_code_resolves(self):
        """Test redeem code URL resolves."""
        url = reverse("redeem-code")
        resolved = resolve(url)
        assert resolved.view_name == "redeem-code"

    def test_login_resolves(self):
        """Test login URL resolves."""
        url = reverse("login")
        resolved = resolve(url)
        assert resolved.view_name == "login"

    def test_signup_resolves(self):
        """Test signup URL resolves."""
        url = reverse("signup")
        resolved = resolve(url)
        assert resolved.view_name == "signup"

    def test_logout_resolves(self):
        """Test logout URL resolves."""
        url = reverse("logout")
        resolved = resolve(url)
        assert resolved.view_name == "logout"

    def test_health_check_resolves(self):
        """Test health check URL resolves."""
        url = reverse("health-check")
        resolved = resolve(url)
        assert resolved.view_name == "health-check"


class Test_MainURLPaths(TransactionTestCase):
    """Test URL path patterns resolve correctly."""

    def test_add_path_resolves(self):
        """Test /add path resolves."""
        resolved = resolve("/add")
        assert resolved.func.__name__ == "index"

    def test_try_path_resolves(self):
        """Test /try path resolves."""
        resolved = resolve("/try")
        assert resolved.func.__name__ == "index"

    def test_site_path_resolves(self):
        """Test /site/123 path resolves."""
        resolved = resolve("/site/123")
        assert resolved.func.__name__ == "index"

    def test_folder_path_resolves(self):
        """Test /folder/123 path resolves."""
        url = reverse("folder", kwargs={"folder_name": "123"})
        resolved = resolve(url)
        assert resolved.view_name == "folder"

    def test_saved_tag_path_resolves(self):
        """Test /saved/123 path resolves."""
        url = reverse("saved-stories-tag", kwargs={"tag_name": "123"})
        resolved = resolve(url)
        assert resolved.view_name == "saved-stories-tag"

    def test_saved_path_resolves(self):
        """Test /saved path resolves."""
        resolved = resolve("/saved")
        assert resolved.func.__name__ == "index"

    def test_read_path_resolves(self):
        """Test /read path resolves."""
        resolved = resolve("/read")
        assert resolved.func.__name__ == "index"

    def test_trending_path_resolves(self):
        """Test /trending path resolves."""
        resolved = resolve("/trending")
        assert resolved.func.__name__ == "index"

    def test_haproxy_check_resolves(self):
        """Test HAProxy check URL resolves."""
        resolved = resolve("/_haproxychk")
        assert resolved.func.__name__ == "haproxy_check"

    def test_dbcheck_postgres_resolves(self):
        """Test postgres DB check URL resolves."""
        resolved = resolve("/_dbcheck/postgres")
        assert resolved.func.__name__ == "postgres_check"

    def test_dbcheck_mongo_resolves(self):
        """Test mongo DB check URL resolves."""
        resolved = resolve("/_dbcheck/mongo")
        assert resolved.func.__name__ == "mongo_check"

    def test_dbcheck_redis_resolves(self):
        """Test redis DB check URL resolves."""
        resolved = resolve("/_dbcheck/redis")
        assert resolved.func.__name__ == "redis_check"

    def test_dbcheck_elasticsearch_resolves(self):
        """Test elasticsearch DB check URL resolves."""
        resolved = resolve("/_dbcheck/elasticsearch")
        assert resolved.func.__name__ == "elasticsearch_check"


class Test_MainURLAccess(TransactionTestCase):
    """Test access patterns for main URLs."""

    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
    ]

    def setUp(self):
        from django.contrib.auth.models import User

        self.client = Client(HTTP_USER_AGENT="Mozilla/5.0 (Test)")
        self.user = User.objects.create_user(username="testuser", password="testpass", email="test@test.com")

    def test_index_anonymous(self):
        """Test anonymous access to index renders without errors."""
        response = self.client.get(reverse("index"))
        assert response.status_code == 200, f"Expected 200, got {response.status_code}"
        # Verify the page actually rendered (not an error page)
        assert b"NewsBlur" in response.content, "Homepage should contain 'NewsBlur'"

    def test_about_anonymous(self):
        """Test anonymous access to about."""
        response = self.client.get(reverse("about"))
        assert response.status_code == 200

    def test_faq_anonymous(self):
        """Test anonymous access to FAQ."""
        response = self.client.get(reverse("faq"))
        assert response.status_code == 200

    def test_api_page_anonymous(self):
        """Test anonymous access to API page."""
        response = self.client.get(reverse("api"))
        assert response.status_code == 200

    def test_press_anonymous(self):
        """Test anonymous access to press."""
        response = self.client.get(reverse("press"))
        assert response.status_code == 200

    def test_feedback_anonymous(self):
        """Test anonymous access to feedback."""
        response = self.client.get(reverse("feedback"))
        assert response.status_code == 200

    def test_privacy_anonymous(self):
        """Test anonymous access to privacy."""
        response = self.client.get(reverse("privacy"))
        assert response.status_code == 200

    def test_tos_anonymous(self):
        """Test anonymous access to TOS."""
        response = self.client.get(reverse("tos"))
        assert response.status_code == 200

    def test_ios_static_anonymous(self):
        """Test anonymous access to iOS static page."""
        response = self.client.get(reverse("ios-static"))
        assert response.status_code == 200

    def test_android_static_anonymous(self):
        """Test anonymous access to Android static page."""
        response = self.client.get(reverse("android-static"))
        assert response.status_code == 200

    def test_firefox_anonymous(self):
        """Test anonymous access to Firefox page."""
        response = self.client.get(reverse("firefox"))
        assert response.status_code == 200

    def test_login_page_anonymous(self):
        """Test anonymous access to login page."""
        response = self.client.get(reverse("login"))
        assert response.status_code in [200, 302]

    def test_signup_page_anonymous(self):
        """Test anonymous access to signup page."""
        response = self.client.get(reverse("signup"))
        assert response.status_code in [200, 302]

    def test_health_check_anonymous(self):
        """Test anonymous access to health check."""
        response = self.client.get(reverse("health-check"))
        assert response.status_code == 200

    def test_haproxy_check_anonymous(self):
        """Test anonymous access to HAProxy check."""
        response = self.client.get("/_haproxychk")
        assert response.status_code == 200

    def test_index_authenticated(self):
        """Test authenticated access to index renders the main app."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("index"))
        assert response.status_code == 200, f"Expected 200, got {response.status_code}"
        # Verify the authenticated page rendered (should have the reader app)
        assert b"NewsBlur" in response.content, "Authenticated homepage should contain 'NewsBlur'"

    def test_logout_authenticated(self):
        """Test authenticated access to logout."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("logout"))
        assert response.status_code in [200, 302]


class Test_MainURLIncludes(TransactionTestCase):
    """Test that URL includes work correctly."""

    def test_reader_include(self):
        """Test reader URL include works."""
        resolved = resolve("/reader/feeds")
        assert resolved.func.__name__ == "load_feeds"

    def test_rss_feeds_include(self):
        """Test rss_feeds URL include works."""
        resolved = resolve("/rss_feeds/status")
        assert resolved.func.__name__ == "status"

    def test_analyzer_include(self):
        """Test analyzer URL include works."""
        resolved = resolve("/analyzer/")
        assert resolved.func.__name__ == "index"

    def test_classifier_include(self):
        """Test classifier URL include works."""
        resolved = resolve("/classifier/")
        assert resolved.func.__name__ == "index"

    def test_profile_include(self):
        """Test profile URL include works."""
        resolved = resolve("/profile/is_premium")
        assert resolved.func.__name__ == "profile_is_premium"

    def test_import_include(self):
        """Test import URL include works."""
        resolved = resolve("/import/opml_upload")
        assert resolved.func.__name__ == "opml_upload"

    def test_api_include(self):
        """Test api URL include works."""
        resolved = resolve("/api/login")
        assert resolved.func.__name__ == "login"

    def test_social_include(self):
        """Test social URL include works."""
        resolved = resolve("/social/profile")
        assert resolved.func.__name__ == "profile"

    def test_notifications_include(self):
        """Test notifications URL include works."""
        response = self.client.get("/notifications/")
        # Just check that the URL resolves (not 404)
        assert response.status_code in [200, 302, 403]

    def test_statistics_include(self):
        """Test statistics URL include works."""
        resolved = resolve("/statistics/dashboard_graphs")
        assert resolved.func.__name__ == "dashboard_graphs"

    def test_search_include(self):
        """Test search URL include works."""
        resolved = resolve("/search/more_like_this")
        assert resolved.func.__name__ == "more_like_this"

    def test_mobile_include(self):
        """Test mobile URL include works."""
        response = self.client.get("/mobile/")
        assert response.status_code in [200, 302, 404]

    def test_m_include(self):
        """Test /m/ URL include works."""
        response = self.client.get("/m/")
        assert response.status_code in [200, 302, 404]

    def test_categories_include(self):
        """Test categories URL include works."""
        response = self.client.get("/categories/")
        assert response.status_code in [200, 302, 403]

    def test_zebra_include(self):
        """Test zebra URL include works."""
        response = self.client.get("/zebra/webhooks/")
        assert response.status_code in [200, 302, 400, 405]
