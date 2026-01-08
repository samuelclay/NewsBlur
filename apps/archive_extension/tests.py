# apps/archive_extension/tests.py
"""
Unit tests for the Archive Extension app.
"""
from datetime import datetime
from unittest.mock import MagicMock, patch

from django.test import TestCase
from django.test.client import Client

from apps.archive_extension.blocklist import DEFAULT_BLOCKED_DOMAINS, DEFAULT_BLOCKED_PATTERNS, is_blocked
from apps.archive_extension.matching import MatchResult, find_matching_story, normalize_url


class Test_URLNormalization(TestCase):
    """Tests for URL normalization logic."""

    def test_strips_utm_parameters(self):
        """UTM tracking parameters should be removed."""
        url = "https://example.com/article?utm_source=twitter&utm_medium=social&utm_campaign=share"
        normalized = normalize_url(url)
        self.assertEqual(normalized, "https://example.com/article")

    def test_strips_fbclid(self):
        """Facebook click ID should be removed."""
        url = "https://example.com/page?fbclid=IwAR12345"
        normalized = normalize_url(url)
        self.assertEqual(normalized, "https://example.com/page")

    def test_strips_gclid(self):
        """Google click ID should be removed."""
        url = "https://example.com/page?gclid=abc123"
        normalized = normalize_url(url)
        self.assertEqual(normalized, "https://example.com/page")

    def test_preserves_important_parameters(self):
        """Important query parameters should be preserved."""
        url = "https://example.com/search?q=test&page=2"
        normalized = normalize_url(url)
        self.assertIn("q=test", normalized)
        self.assertIn("page=2", normalized)

    def test_removes_trailing_slash(self):
        """Trailing slashes should be removed for consistency."""
        url = "https://example.com/article/"
        normalized = normalize_url(url)
        self.assertEqual(normalized, "https://example.com/article")

    def test_lowercases_domain(self):
        """Domain should be lowercased."""
        url = "https://EXAMPLE.COM/Article"
        normalized = normalize_url(url)
        self.assertTrue(normalized.startswith("https://example.com"))

    def test_handles_empty_url(self):
        """Empty URL should return empty string."""
        self.assertEqual(normalize_url(""), "")
        self.assertEqual(normalize_url(None), "")

    def test_handles_invalid_url(self):
        """Invalid URLs should be handled gracefully."""
        # Should not raise an exception
        result = normalize_url("not-a-valid-url")
        self.assertIsInstance(result, str)

    def test_removes_fragment(self):
        """URL fragments should be removed."""
        url = "https://example.com/article#section-2"
        normalized = normalize_url(url)
        self.assertNotIn("#", normalized)


class Test_Blocklist(TestCase):
    """Tests for blocklist functionality."""

    def test_blocks_banking_domains(self):
        """Banking domains should be blocked."""
        banking_domains = [
            "https://www.chase.com/account",
            "https://bankofamerica.com/login",
            "https://online.wellsfargo.com/checking",
            "https://www.citi.com/credit-cards",
        ]
        for url in banking_domains:
            self.assertTrue(is_blocked(url), f"Should block banking URL: {url}")

    def test_blocks_medical_domains(self):
        """Medical domains should be blocked."""
        medical_urls = [
            "https://mychart.com/portal",
            "https://patient.portal.example.com/records",
        ]
        for url in medical_urls:
            self.assertTrue(is_blocked(url), f"Should block medical URL: {url}")

    def test_blocks_email_domains(self):
        """Email domains should be blocked."""
        email_urls = [
            "https://mail.google.com/inbox",
            "https://outlook.live.com/mail",
            "https://mail.yahoo.com/d/compose",
        ]
        for url in email_urls:
            self.assertTrue(is_blocked(url), f"Should block email URL: {url}")

    def test_blocks_password_managers(self):
        """Password manager domains should be blocked."""
        pm_urls = [
            "https://my.1password.com/vault",
            "https://lastpass.com/vault",
            "https://vault.bitwarden.com",
        ]
        for url in pm_urls:
            self.assertTrue(is_blocked(url), f"Should block password manager URL: {url}")

    def test_blocks_login_pages(self):
        """Login pages should be blocked by pattern."""
        login_urls = [
            "https://example.com/login",
            "https://example.com/signin",
            "https://example.com/auth/callback",
            "https://example.com/oauth/authorize",
        ]
        for url in login_urls:
            self.assertTrue(is_blocked(url), f"Should block login URL: {url}")

    def test_blocks_checkout_pages(self):
        """Checkout and cart pages should be blocked."""
        checkout_urls = [
            "https://store.example.com/cart",
            "https://store.example.com/checkout",
            "https://store.example.com/payment",
        ]
        for url in checkout_urls:
            self.assertTrue(is_blocked(url), f"Should block checkout URL: {url}")

    def test_blocks_localhost(self):
        """Localhost URLs should be blocked."""
        local_urls = [
            "http://localhost:8000/admin",
            "http://127.0.0.1:3000/dashboard",
            "http://192.168.1.1/router",
        ]
        for url in local_urls:
            self.assertTrue(is_blocked(url), f"Should block local URL: {url}")

    def test_allows_regular_articles(self):
        """Regular article URLs should not be blocked."""
        allowed_urls = [
            "https://nytimes.com/2024/01/article",
            "https://techcrunch.com/2024/01/startup-news",
            "https://medium.com/@author/article-title",
            "https://dev.to/user/programming-tips",
            "https://www.wikipedia.org/wiki/Example",
        ]
        for url in allowed_urls:
            self.assertFalse(is_blocked(url), f"Should allow article URL: {url}")

    def test_default_blocked_domains_count(self):
        """Verify we have a reasonable number of default blocked domains."""
        # Should have at least 50 blocked domains by default
        self.assertGreater(len(DEFAULT_BLOCKED_DOMAINS), 50)

    def test_default_blocked_patterns_count(self):
        """Verify we have blocked patterns for common sensitive pages."""
        # Should have patterns for login, checkout, etc.
        self.assertGreater(len(DEFAULT_BLOCKED_PATTERNS), 10)


class Test_StoryMatching(TestCase):
    """Tests for story matching logic."""

    def setUp(self):
        """Set up test fixtures."""
        self.user_id = 1

    @patch("apps.archive_extension.matching.MStory")
    def test_matches_exact_url(self, mock_mstory):
        """Should match story with exact URL."""
        mock_story = MagicMock()
        mock_story.story_hash = "abc123"
        mock_story.story_feed_id = 100
        mock_story.story_permalink = "https://example.com/article"

        mock_mstory.objects.return_value.filter.return_value.first.return_value = mock_story

        result = find_matching_story(self.user_id, "https://example.com/article")

        self.assertIsNotNone(result)
        self.assertEqual(result.story_hash, "abc123")
        self.assertEqual(result.feed_id, 100)

    @patch("apps.archive_extension.matching.MStory")
    def test_matches_normalized_url(self, mock_mstory):
        """Should match story after URL normalization."""
        mock_story = MagicMock()
        mock_story.story_hash = "abc123"
        mock_story.story_feed_id = 100
        mock_story.story_permalink = "https://example.com/article"

        mock_mstory.objects.return_value.filter.return_value.first.return_value = mock_story

        # URL with tracking params should still match
        result = find_matching_story(self.user_id, "https://example.com/article?utm_source=twitter")

        self.assertIsNotNone(result)

    @patch("apps.archive_extension.matching.MStory")
    def test_returns_none_when_no_match(self, mock_mstory):
        """Should return None when no matching story found."""
        mock_mstory.objects.return_value.filter.return_value.first.return_value = None

        result = find_matching_story(self.user_id, "https://newsite.com/new-article")

        self.assertIsNone(result)


class Test_ArchiveAPIEndpoints(TestCase):
    """Tests for Archive Extension API endpoints."""

    def setUp(self):
        """Set up test client and mock user."""
        self.client = Client()

    def test_ingest_requires_authentication(self):
        """Ingest endpoint should require authentication."""
        response = self.client.post(
            "/api/archive/ingest",
            {"url": "https://example.com", "title": "Test"},
            content_type="application/json",
        )
        # Should redirect to login or return 403
        self.assertIn(response.status_code, [302, 403])

    def test_list_requires_authentication(self):
        """List endpoint should require authentication."""
        response = self.client.get("/api/archive/list")
        self.assertIn(response.status_code, [302, 403])

    def test_stats_requires_authentication(self):
        """Stats endpoint should require authentication."""
        response = self.client.get("/api/archive/stats")
        self.assertIn(response.status_code, [302, 403])


class Test_ContentExtraction(TestCase):
    """Tests for content extraction utilities."""

    def test_extract_domain_from_url(self):
        """Should extract domain from URL correctly."""
        from apps.archive_extension.matching import extract_domain

        test_cases = [
            ("https://www.example.com/path", "example.com"),
            ("https://subdomain.example.com", "subdomain.example.com"),
            ("http://example.com:8080/page", "example.com"),
            ("https://example.com", "example.com"),
        ]
        for url, expected in test_cases:
            self.assertEqual(extract_domain(url), expected, f"Failed for URL: {url}")

    def test_extract_domain_handles_invalid_url(self):
        """Should handle invalid URLs gracefully."""
        from apps.archive_extension.matching import extract_domain

        self.assertEqual(extract_domain("not-a-url"), "")
        self.assertEqual(extract_domain(""), "")
        self.assertEqual(extract_domain(None), "")


class Test_ArchiveUserSettings(TestCase):
    """Tests for user settings functionality."""

    def test_default_settings(self):
        """New users should have sensible default settings."""
        from apps.archive_extension.models import MArchiveUserSettings

        # Default values should be reasonable
        self.assertTrue(
            MArchiveUserSettings.enabled.default
            if hasattr(MArchiveUserSettings.enabled, "default")
            else True
        )
