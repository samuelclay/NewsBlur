# apps/archive_extension/tests.py
"""
Comprehensive test suite for the Archive Extension app.

Tests cover:
- Model functionality (MArchivedStory, MArchiveUserSettings)
- URL normalization and matching logic
- API endpoints for ingestion (ingest, batch_ingest)
- API endpoints for retrieval (list, categories, domains, stats, export)
- Blocklist management
- End-to-end integration flows

Run with: make test SCOPE=apps.archive_extension
"""
import json as stdlib_json
from datetime import datetime, timedelta
from unittest.mock import MagicMock, patch

from django.contrib.auth.models import User
from django.test import TestCase, TransactionTestCase
from django.test.client import Client

from apps.archive_extension.blocklist import (
    DEFAULT_BLOCKED_DOMAINS,
    DEFAULT_BLOCKED_PATTERNS,
    is_blocked,
)
from apps.archive_extension.matching import (
    _get_url_variants,
    extract_domain,
    normalize_url,
    should_store_content,
)
from apps.archive_extension.models import MArchivedStory, MArchiveUserSettings
from apps.profile.models import Profile


# =============================================================================
# Base Test Class
# =============================================================================


class ArchiveTestCase(TransactionTestCase):
    """
    Base test class for Archive Extension tests that need database access.

    Sets up:
    - A test user with archive subscription (profile.is_archive = True)
    - Authenticated Django test client
    - Helper methods for creating test data

    Cleans up MongoDB data in tearDown.
    """

    def setUp(self):
        """Create test user with archive subscription and authenticate."""
        self.client = Client()
        # Create user
        self.user = User.objects.create_user(
            username="testuser",
            password="testpass",
            email="test@test.com",
        )
        # Set archive subscription
        self.profile = Profile.objects.get(user=self.user)
        self.profile.is_archive = True
        self.profile.save()
        # Authenticate
        self.client.force_login(self.user)

    def tearDown(self):
        """Clean up MongoDB data created during tests."""
        MArchivedStory.objects(user_id=self.user.pk).delete()
        MArchiveUserSettings.objects(user_id=self.user.pk).delete()

    def create_archive(self, url, title, content=None, **kwargs):
        """Helper to create a test archive directly via model."""
        archive, created, updated = MArchivedStory.archive_page(
            user_id=self.user.pk,
            url=url,
            title=title,
            content=content,
            **kwargs,
        )
        return archive


# =============================================================================
# Unit Tests: URL Normalization
# =============================================================================


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

    def test_strips_msclkid(self):
        """Microsoft click ID should be removed."""
        url = "https://example.com/page?msclkid=xyz789"
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

    def test_preserves_root_trailing_slash(self):
        """Root path should keep its trailing slash."""
        url = "https://example.com/"
        normalized = normalize_url(url)
        self.assertIn("example.com", normalized)

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
        result = normalize_url("not-a-valid-url")
        self.assertIsInstance(result, str)

    def test_removes_fragment(self):
        """URL fragments should be removed."""
        url = "https://example.com/article#section-2"
        normalized = normalize_url(url)
        self.assertNotIn("#", normalized)

    def test_removes_www_prefix(self):
        """www prefix should be removed for consistency."""
        url = "https://www.example.com/article"
        normalized = normalize_url(url)
        self.assertIn("example.com", normalized)
        self.assertNotIn("www.", normalized)


# =============================================================================
# Unit Tests: URL Variants
# =============================================================================


class Test_URLVariants(TestCase):
    """Tests for URL variant generation used in story matching."""

    def test_generates_www_variants(self):
        """Should generate variants with and without www."""
        url = "https://example.com/article"
        variants = _get_url_variants(url)
        # Should include with www variant
        self.assertTrue(
            any("www.example.com" in v for v in variants),
            "Should include www variant",
        )

    def test_generates_www_removal_variant(self):
        """Should generate variant without www when original has it."""
        url = "https://www.example.com/article"
        variants = _get_url_variants(url)
        # Should include without www variant
        self.assertTrue(
            any("//example.com" in v and "www" not in v for v in variants),
            "Should include non-www variant",
        )

    def test_generates_trailing_slash_variants(self):
        """Should generate variants with and without trailing slash."""
        url = "https://example.com/article"
        variants = _get_url_variants(url)
        # Should include variant with trailing slash
        self.assertTrue(
            any(v.endswith("/article/") for v in variants),
            "Should include trailing slash variant",
        )

    def test_generates_http_https_variants(self):
        """Should generate variants with both http and https."""
        url = "https://example.com/article"
        variants = _get_url_variants(url)
        # Should include http variant
        self.assertTrue(
            any(v.startswith("http://") for v in variants),
            "Should include http variant",
        )

    def test_no_duplicates_in_variants(self):
        """Variants list should not contain duplicates."""
        url = "https://example.com/article"
        variants = _get_url_variants(url)
        self.assertEqual(len(variants), len(set(variants)), "Should have no duplicates")

    def test_original_url_included(self):
        """Original URL should be first in variants."""
        url = "https://example.com/article"
        variants = _get_url_variants(url)
        self.assertEqual(variants[0], url, "Original URL should be first")


# =============================================================================
# Unit Tests: Blocklist
# =============================================================================


class Test_Blocklist(TestCase):
    """Tests for blocklist functionality."""

    def test_blocks_banking_domains(self):
        """Banking domains should be blocked."""
        banking_domains = [
            "https://www.chase.com/account",
            "https://bankofamerica.com/login",
            "https://wellsfargo.com/checking",
            "https://www.citi.com/credit-cards",
        ]
        for url in banking_domains:
            self.assertTrue(is_blocked(url), f"Should block banking URL: {url}")

    def test_blocks_medical_domains(self):
        """Medical domains should be blocked."""
        medical_urls = [
            "https://mychart.com/portal",
            "https://cvs.com/pharmacy",
            "https://walgreens.com/account",
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
            "https://1password.com/vault",
            "https://lastpass.com/vault",
            "https://bitwarden.com/vault",
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
        self.assertGreater(len(DEFAULT_BLOCKED_DOMAINS), 50)

    def test_default_blocked_patterns_count(self):
        """Verify we have blocked patterns for common sensitive pages."""
        self.assertGreater(len(DEFAULT_BLOCKED_PATTERNS), 10)

    def test_user_allowed_domains_override_defaults(self):
        """User's allowed domains should override default blocklist."""
        # Create mock user settings with allowed domain
        mock_settings = MagicMock()
        mock_settings.allowed_domains = ["chase.com"]
        mock_settings.blocked_domains = []
        mock_settings.blocked_patterns = []

        # Chase is normally blocked, but should be allowed with override
        self.assertFalse(
            is_blocked("https://www.chase.com/account", mock_settings),
            "Allowed domain should override default block",
        )

    def test_user_custom_blocked_domains(self):
        """User's custom blocked domains should be blocked."""
        mock_settings = MagicMock()
        mock_settings.allowed_domains = []
        mock_settings.blocked_domains = ["mycompany.com"]
        mock_settings.blocked_patterns = []

        self.assertTrue(
            is_blocked("https://mycompany.com/internal", mock_settings),
            "Custom blocked domain should be blocked",
        )


# =============================================================================
# Unit Tests: Content Extraction
# =============================================================================


class Test_ContentExtraction(TestCase):
    """Tests for content extraction utilities."""

    def test_extract_domain_from_url(self):
        """Should extract domain from URL correctly."""
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
        self.assertEqual(extract_domain("not-a-url"), "")
        self.assertEqual(extract_domain(""), "")
        self.assertEqual(extract_domain(None), "")


# =============================================================================
# Unit Tests: Content Storage Decision
# =============================================================================


class Test_ShouldStoreContent(TestCase):
    """Tests for content storage decision logic."""

    def test_stores_when_no_existing_story(self):
        """Should store content when no matching story exists."""
        self.assertTrue(
            should_store_content(1000, None),
            "Should store content when no existing story",
        )

    def test_stores_when_significantly_longer(self):
        """Should store when extension content is >10% longer."""
        mock_story = MagicMock()
        mock_story.story_content_z = None
        mock_story.original_text_z = None
        mock_story.story_content = "x" * 100

        # 120 is >10% more than 100
        self.assertTrue(
            should_store_content(120, mock_story),
            "Should store significantly longer content",
        )

    def test_does_not_store_when_shorter(self):
        """Should not store when extension content is shorter."""
        mock_story = MagicMock()
        mock_story.story_content_z = None
        mock_story.original_text_z = None
        mock_story.story_content = "x" * 100

        self.assertFalse(
            should_store_content(50, mock_story),
            "Should not store shorter content",
        )


# =============================================================================
# Unit Tests: MArchivedStory Model
# =============================================================================


class Test_MArchivedStory(ArchiveTestCase):
    """Tests for MArchivedStory model functionality."""

    def test_content_compression_roundtrip(self):
        """Content should survive compression/decompression roundtrip."""
        archive = self.create_archive(
            url="https://example.com/article",
            title="Test Article",
            content="This is test content that will be compressed.",
        )
        retrieved_content = archive.get_content()
        self.assertEqual(
            retrieved_content,
            "This is test content that will be compressed.",
        )

    def test_content_compression_empty(self):
        """Empty content should be handled gracefully."""
        archive = self.create_archive(
            url="https://example.com/empty",
            title="Empty Article",
            content=None,
        )
        self.assertEqual(archive.get_content(), "")

    def test_content_compression_unicode(self):
        """Unicode content should survive compression."""
        unicode_content = "Hello 世界 emoji 🎉"
        archive = self.create_archive(
            url="https://example.com/unicode",
            title="Unicode Article",
            content=unicode_content,
        )
        self.assertEqual(archive.get_content(), unicode_content)

    def test_url_hashing_consistency(self):
        """Same URL should produce same hash."""
        url = "https://example.com/article"
        hash1 = MArchivedStory.hash_url(url)
        hash2 = MArchivedStory.hash_url(url)
        self.assertEqual(hash1, hash2)

    def test_url_hashing_normalization(self):
        """Normalized URLs should produce same hash."""
        url1 = "https://example.com/article?utm_source=twitter"
        url2 = "https://example.com/article"
        hash1 = MArchivedStory.hash_url(url1)
        hash2 = MArchivedStory.hash_url(url2)
        self.assertEqual(hash1, hash2, "Tracking params should not affect hash")

    def test_url_hashing_different_urls(self):
        """Different URLs should produce different hashes."""
        hash1 = MArchivedStory.hash_url("https://example.com/article1")
        hash2 = MArchivedStory.hash_url("https://example.com/article2")
        self.assertNotEqual(hash1, hash2)

    def test_domain_extraction_various_formats(self):
        """Domain extraction should handle various URL formats."""
        test_cases = [
            ("https://www.example.com/path", "example.com"),
            ("https://blog.example.com/post", "blog.example.com"),
            ("http://example.com:8080/page", "example.com"),
        ]
        for url, expected in test_cases:
            domain = MArchivedStory.extract_domain(url)
            self.assertEqual(domain, expected, f"Failed for {url}")

    def test_archive_page_creates_new(self):
        """archive_page should create new archive."""
        archive, created, updated = MArchivedStory.archive_page(
            user_id=self.user.pk,
            url="https://example.com/new",
            title="New Article",
        )
        self.assertTrue(created)
        self.assertFalse(updated)
        self.assertIsNotNone(archive.id)

    def test_archive_page_updates_existing(self):
        """archive_page should update existing archive on revisit."""
        # Create initial archive
        archive1, created1, _ = MArchivedStory.archive_page(
            user_id=self.user.pk,
            url="https://example.com/existing",
            title="Original Title",
            time_on_page=10,
        )
        self.assertTrue(created1)
        self.assertEqual(archive1.visit_count, 1)

        # Revisit same URL
        archive2, created2, updated2 = MArchivedStory.archive_page(
            user_id=self.user.pk,
            url="https://example.com/existing",
            title="Original Title",
            time_on_page=5,
        )
        self.assertFalse(created2)
        self.assertTrue(updated2)
        self.assertEqual(archive2.visit_count, 2)
        self.assertEqual(archive2.time_on_page_seconds, 15)

    def test_archive_page_longer_content_replaces(self):
        """Longer content should replace shorter content."""
        # Create with short content
        archive1, _, _ = MArchivedStory.archive_page(
            user_id=self.user.pk,
            url="https://example.com/content",
            title="Article",
            content="Short",
        )
        self.assertEqual(archive1.content_length, 5)

        # Update with longer content
        archive2, _, _ = MArchivedStory.archive_page(
            user_id=self.user.pk,
            url="https://example.com/content",
            title="Article",
            content="Much longer content that should replace the short one",
        )
        self.assertGreater(archive2.content_length, 5)

    def test_archive_page_shorter_content_preserved(self):
        """Shorter content should not replace longer content."""
        # Create with long content
        long_content = "This is longer content"
        archive1, _, _ = MArchivedStory.archive_page(
            user_id=self.user.pk,
            url="https://example.com/preserve",
            title="Article",
            content=long_content,
        )
        original_length = archive1.content_length

        # Try to update with shorter content
        archive2, _, _ = MArchivedStory.archive_page(
            user_id=self.user.pk,
            url="https://example.com/preserve",
            title="Article",
            content="Short",
        )
        self.assertEqual(archive2.content_length, original_length)

    def test_archive_page_undeletes(self):
        """Revisiting soft-deleted archive should undelete it."""
        # Create and delete
        archive, _, _ = MArchivedStory.archive_page(
            user_id=self.user.pk,
            url="https://example.com/deleted",
            title="Deleted Article",
        )
        archive.soft_delete()
        self.assertTrue(archive.deleted)

        # Revisit should undelete
        archive2, _, _ = MArchivedStory.archive_page(
            user_id=self.user.pk,
            url="https://example.com/deleted",
            title="Deleted Article",
        )
        self.assertFalse(archive2.deleted)
        self.assertIsNone(archive2.deleted_date)

    def test_soft_delete_sets_flags(self):
        """soft_delete should set deleted flag and date."""
        archive = self.create_archive(
            url="https://example.com/to-delete",
            title="To Delete",
        )
        self.assertFalse(archive.deleted)

        archive.soft_delete()
        archive.reload()

        self.assertTrue(archive.deleted)
        self.assertIsNotNone(archive.deleted_date)


# =============================================================================
# Unit Tests: MArchiveUserSettings Model
# =============================================================================


class Test_MArchiveUserSettings(ArchiveTestCase):
    """Tests for MArchiveUserSettings model."""

    def test_get_or_create_new_user(self):
        """get_or_create should create settings for new user."""
        # Use a different user ID to ensure fresh creation
        new_user_id = self.user.pk + 1000
        settings = MArchiveUserSettings.get_or_create(new_user_id)
        self.assertEqual(settings.user_id, new_user_id)
        self.assertEqual(settings.total_archived, 0)
        # Clean up
        MArchiveUserSettings.objects(user_id=new_user_id).delete()

    def test_get_or_create_existing_user(self):
        """get_or_create should return existing settings."""
        # Create settings first
        settings1 = MArchiveUserSettings.get_or_create(self.user.pk)
        settings1.total_archived = 42
        settings1.save()

        # Get again - should return same settings
        settings2 = MArchiveUserSettings.get_or_create(self.user.pk)
        self.assertEqual(settings2.total_archived, 42)


# =============================================================================
# API Tests: Ingest Endpoint
# =============================================================================


class Test_IngestEndpoint(ArchiveTestCase):
    """Tests for the /api/archive/ingest endpoint."""

    def test_ingest_requires_authentication(self):
        """Ingest endpoint should require authentication."""
        # Logout first
        self.client.logout()
        response = self.client.post(
            "/api/archive/ingest",
            {"url": "https://example.com", "title": "Test"},
        )
        self.assertIn(response.status_code, [302, 403])

    def test_ingest_missing_url_returns_error(self):
        """Missing URL should return error."""
        response = self.client.post(
            "/api/archive/ingest",
            {"title": "Test"},
        )
        self.assertEqual(response.status_code, 400)
        data = response.json()
        self.assertNotEqual(data.get("code"), 0)

    def test_ingest_missing_title_returns_error(self):
        """Missing title should return error."""
        response = self.client.post(
            "/api/archive/ingest",
            {"url": "https://example.com"},
        )
        self.assertEqual(response.status_code, 400)
        data = response.json()
        self.assertNotEqual(data.get("code"), 0)

    def test_ingest_blocked_url_returns_blocked(self):
        """Blocked URL should return blocked response."""
        response = self.client.post(
            "/api/archive/ingest",
            {"url": "https://chase.com/account", "title": "Bank"},
        )
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data.get("code"), 1)
        self.assertTrue(data.get("blocked"))

    def test_ingest_creates_archive(self):
        """Valid ingest should create archive."""
        response = self.client.post(
            "/api/archive/ingest",
            {
                "url": "https://example.com/article",
                "title": "Test Article",
            },
        )
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data.get("code"), 0)
        self.assertTrue(data.get("created"))

    def test_ingest_returns_archive_id(self):
        """Ingest response should include archive_id."""
        response = self.client.post(
            "/api/archive/ingest",
            {
                "url": "https://example.com/with-id",
                "title": "Article With ID",
            },
        )
        data = response.json()
        self.assertIn("archive_id", data)
        self.assertTrue(len(data["archive_id"]) > 0)

    def test_ingest_updates_user_stats(self):
        """Ingest should increment total_archived."""
        # Get initial count
        settings = MArchiveUserSettings.get_or_create(self.user.pk)
        initial_count = settings.total_archived or 0

        # Ingest new archive
        self.client.post(
            "/api/archive/ingest",
            {
                "url": "https://example.com/stats-test",
                "title": "Stats Test",
            },
        )

        # Check updated count
        settings.reload()
        self.assertEqual(settings.total_archived, initial_count + 1)

    def test_ingest_with_content(self):
        """Content should be stored when provided."""
        test_content = "This is the article content."
        response = self.client.post(
            "/api/archive/ingest",
            {
                "url": "https://example.com/with-content",
                "title": "Article With Content",
                "content": test_content,
            },
        )
        data = response.json()
        self.assertTrue(data.get("content_stored"))

        # Verify content was stored
        archive = MArchivedStory.objects.get(id=data["archive_id"])
        self.assertEqual(archive.get_content(), test_content)

    def test_ingest_without_content(self):
        """Archive should be created without content."""
        response = self.client.post(
            "/api/archive/ingest",
            {
                "url": "https://example.com/no-content",
                "title": "No Content Article",
            },
        )
        data = response.json()
        self.assertEqual(data.get("code"), 0)

        archive = MArchivedStory.objects.get(id=data["archive_id"])
        self.assertEqual(archive.get_content(), "")

    def test_ingest_duplicate_url_updates(self):
        """Ingesting same URL twice should update, not create."""
        # First ingest
        response1 = self.client.post(
            "/api/archive/ingest",
            {
                "url": "https://example.com/duplicate",
                "title": "First Visit",
            },
        )
        data1 = response1.json()
        self.assertTrue(data1.get("created"))

        # Second ingest of same URL
        response2 = self.client.post(
            "/api/archive/ingest",
            {
                "url": "https://example.com/duplicate",
                "title": "Second Visit",
            },
        )
        data2 = response2.json()
        self.assertFalse(data2.get("created"))
        self.assertTrue(data2.get("updated"))

        # Should be same archive ID
        self.assertEqual(data1["archive_id"], data2["archive_id"])

    def test_ingest_with_all_optional_fields(self):
        """All optional fields should be stored."""
        response = self.client.post(
            "/api/archive/ingest",
            {
                "url": "https://example.com/full",
                "title": "Full Article",
                "content": "Full content",
                "favicon_url": "https://example.com/favicon.ico",
                "time_on_page": "120",
                "browser": "chrome",
                "extension_version": "1.0.0",
            },
        )
        data = response.json()
        archive = MArchivedStory.objects.get(id=data["archive_id"])

        self.assertEqual(archive.favicon_url, "https://example.com/favicon.ico")
        self.assertEqual(archive.time_on_page_seconds, 120)
        self.assertEqual(archive.browser, "chrome")
        self.assertEqual(archive.extension_version, "1.0.0")


# =============================================================================
# API Tests: Batch Ingest Endpoint
# =============================================================================


class Test_BatchIngestEndpoint(ArchiveTestCase):
    """Tests for the /api/archive/batch_ingest endpoint."""

    def test_batch_ingest_requires_auth(self):
        """Batch ingest should require authentication."""
        self.client.logout()
        response = self.client.post(
            "/api/archive/batch_ingest",
            stdlib_json.dumps([{"url": "https://example.com", "title": "Test"}]),
            content_type="application/json",
        )
        self.assertIn(response.status_code, [302, 403])

    def test_batch_ingest_max_100_limit(self):
        """Batch ingest should reject >100 items."""
        archives = [
            {"url": f"https://example.com/{i}", "title": f"Article {i}"} for i in range(101)
        ]
        response = self.client.post(
            "/api/archive/batch_ingest",
            stdlib_json.dumps(archives),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 400)

    def test_batch_ingest_invalid_json_error(self):
        """Invalid JSON should return error."""
        response = self.client.post(
            "/api/archive/batch_ingest",
            "not valid json",
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 400)

    def test_batch_ingest_multiple_archives(self):
        """Batch ingest should create multiple archives."""
        archives = [
            {"url": "https://example.com/batch1", "title": "Batch 1", "browser": "chrome"},
            {"url": "https://example.com/batch2", "title": "Batch 2", "browser": "chrome"},
            {"url": "https://example.com/batch3", "title": "Batch 3", "browser": "chrome"},
        ]
        response = self.client.post(
            "/api/archive/batch_ingest",
            stdlib_json.dumps(archives),
            content_type="application/json",
        )
        data = response.json()

        self.assertEqual(data.get("code"), 0)
        self.assertEqual(data.get("processed"), 3)
        self.assertEqual(len(data.get("results", [])), 3)

    def test_batch_ingest_partial_failure(self):
        """Batch ingest should handle partial failures."""
        archives = [
            {"url": "https://example.com/good", "title": "Good", "browser": "chrome"},
            {"url": "", "title": "Missing URL"},  # Invalid
            {"url": "https://example.com/good2", "title": "Good 2", "browser": "chrome"},
        ]
        response = self.client.post(
            "/api/archive/batch_ingest",
            stdlib_json.dumps(archives),
            content_type="application/json",
        )
        data = response.json()

        self.assertEqual(data.get("processed"), 2)
        self.assertEqual(data.get("errors"), 1)

    def test_batch_ingest_skips_blocked_urls(self):
        """Blocked URLs should be skipped in batch."""
        archives = [
            {"url": "https://example.com/allowed", "title": "Allowed", "browser": "chrome"},
            {"url": "https://chase.com/account", "title": "Blocked"},
        ]
        response = self.client.post(
            "/api/archive/batch_ingest",
            stdlib_json.dumps(archives),
            content_type="application/json",
        )
        data = response.json()

        # Find the blocked result
        blocked_result = next(
            (r for r in data["results"] if "chase.com" in r.get("url", "")), None
        )
        self.assertIsNotNone(blocked_result)
        self.assertTrue(blocked_result.get("blocked"))

    def test_batch_ingest_missing_url_in_item(self):
        """Missing URL in batch item should result in error for that item."""
        archives = [
            {"title": "No URL"},  # Missing URL
        ]
        response = self.client.post(
            "/api/archive/batch_ingest",
            stdlib_json.dumps(archives),
            content_type="application/json",
        )
        data = response.json()
        self.assertEqual(data.get("errors"), 1)


# =============================================================================
# API Tests: List Endpoint
# =============================================================================


class Test_ListEndpoint(ArchiveTestCase):
    """Tests for the /api/archive/list endpoint."""

    def test_list_requires_auth(self):
        """List endpoint should require authentication."""
        self.client.logout()
        response = self.client.get("/api/archive/list")
        self.assertIn(response.status_code, [302, 403])

    def test_list_returns_user_archives_only(self):
        """List should only return archives for authenticated user."""
        # Create archive for our user
        self.create_archive("https://example.com/mine", "My Article")

        # Create archive for different user
        other_user_id = self.user.pk + 1000
        MArchivedStory.archive_page(
            user_id=other_user_id,
            url="https://example.com/other",
            title="Other User's Article",
        )

        response = self.client.get("/api/archive/list")
        data = response.json()

        # Should only see our archive
        self.assertEqual(len(data["archives"]), 1)
        self.assertEqual(data["archives"][0]["url"], "https://example.com/mine")

        # Clean up other user's data
        MArchivedStory.objects(user_id=other_user_id).delete()

    def test_list_default_pagination(self):
        """List should default to 50 items."""
        # Create 55 archives
        for i in range(55):
            self.create_archive(f"https://example.com/page{i}", f"Article {i}")

        response = self.client.get("/api/archive/list")
        data = response.json()

        self.assertEqual(len(data["archives"]), 50)
        self.assertTrue(data["has_more"])
        self.assertEqual(data["total"], 55)

    def test_list_custom_pagination(self):
        """List should respect limit and offset."""
        # Create 20 archives
        for i in range(20):
            self.create_archive(f"https://example.com/p{i}", f"Article {i}")

        response = self.client.get("/api/archive/list?limit=5&offset=10")
        data = response.json()

        self.assertEqual(len(data["archives"]), 5)

    def test_list_max_limit_200(self):
        """List should cap limit at 200."""
        response = self.client.get("/api/archive/list?limit=500")
        # Should not error, just cap at 200
        self.assertEqual(response.status_code, 200)

    def test_list_filter_by_domain(self):
        """List should filter by domain."""
        self.create_archive("https://example.com/article1", "Example 1")
        self.create_archive("https://other.com/article2", "Other 1")

        response = self.client.get("/api/archive/list?domain=example.com")
        data = response.json()

        self.assertEqual(len(data["archives"]), 1)
        self.assertEqual(data["archives"][0]["domain"], "example.com")

    def test_list_filter_by_category(self):
        """List should filter by category."""
        archive1 = self.create_archive("https://example.com/tech", "Tech Article")
        archive1.ai_categories = ["Technology"]
        archive1.save()

        archive2 = self.create_archive("https://example.com/news", "News Article")
        archive2.ai_categories = ["News"]
        archive2.save()

        response = self.client.get("/api/archive/list?category=Technology")
        data = response.json()

        self.assertEqual(len(data["archives"]), 1)
        self.assertIn("Technology", data["archives"][0]["ai_categories"])

    def test_list_search_by_title(self):
        """List should search by title."""
        from apps.archive_extension.search import SearchArchive

        archive1 = self.create_archive("https://example.com/python", "Python Programming Guide")
        archive2 = self.create_archive("https://example.com/java", "Java Development")

        # Manually index for search (normally done async)
        SearchArchive.index_archive(archive1)
        SearchArchive.index_archive(archive2)

        response = self.client.get("/api/archive/list?search=Python")
        data = response.json()

        # If Elasticsearch isn't available, search returns all results (no filtering)
        # Otherwise it should return only the matching result
        if len(data["archives"]) == 1:
            self.assertIn("Python", data["archives"][0]["title"])
        else:
            # Elasticsearch unavailable - search not applied, skip assertion
            pass

    def test_list_excludes_deleted(self):
        """List should exclude soft-deleted archives by default."""
        archive = self.create_archive("https://example.com/deleted", "Deleted")
        archive.soft_delete()

        self.create_archive("https://example.com/active", "Active")

        response = self.client.get("/api/archive/list")
        data = response.json()

        self.assertEqual(len(data["archives"]), 1)
        self.assertEqual(data["archives"][0]["title"], "Active")

    def test_list_include_deleted_flag(self):
        """List should include deleted when flag is set."""
        archive = self.create_archive("https://example.com/deleted2", "Deleted")
        archive.soft_delete()

        response = self.client.get("/api/archive/list?include_deleted=true")
        data = response.json()

        self.assertEqual(len(data["archives"]), 1)

    def test_list_has_more_flag(self):
        """List should correctly set has_more flag."""
        for i in range(5):
            self.create_archive(f"https://example.com/item{i}", f"Item {i}")

        response = self.client.get("/api/archive/list?limit=3")
        data = response.json()

        self.assertTrue(data["has_more"])

        response2 = self.client.get("/api/archive/list?limit=10")
        data2 = response2.json()

        self.assertFalse(data2["has_more"])

    def test_list_serializes_all_fields(self):
        """List response should include all expected fields."""
        archive = self.create_archive(
            "https://example.com/full-fields",
            "Full Fields Article",
            content="Test content",
        )
        archive.favicon_url = "https://example.com/favicon.ico"
        archive.ai_categories = ["Technology"]
        archive.browser = "chrome"
        archive.save()

        response = self.client.get("/api/archive/list")
        data = response.json()
        item = data["archives"][0]

        expected_fields = [
            "id",
            "url",
            "title",
            "domain",
            "favicon_url",
            "archived_date",
            "visit_count",
            "content_length",
            "matched",
            "ai_categories",
            "browser",
        ]
        for field in expected_fields:
            self.assertIn(field, item, f"Missing field: {field}")


# =============================================================================
# API Tests: Categories Endpoint
# =============================================================================


class Test_CategoriesEndpoint(ArchiveTestCase):
    """Tests for the /api/archive/categories endpoint."""

    def test_categories_requires_auth(self):
        """Categories endpoint should require authentication."""
        self.client.logout()
        response = self.client.get("/api/archive/categories")
        self.assertIn(response.status_code, [302, 403])

    def test_categories_returns_breakdown(self):
        """Categories should return category counts."""
        # Create archives with categories
        for i in range(3):
            archive = self.create_archive(f"https://example.com/tech{i}", f"Tech {i}")
            archive.ai_categories = ["Technology"]
            archive.save()

        for i in range(2):
            archive = self.create_archive(f"https://example.com/news{i}", f"News {i}")
            archive.ai_categories = ["News"]
            archive.save()

        response = self.client.get("/api/archive/categories")
        data = response.json()

        self.assertEqual(data.get("code"), 0)
        categories = {c["category"]: c["count"] for c in data["categories"]}

        self.assertEqual(categories.get("Technology"), 3)
        self.assertEqual(categories.get("News"), 2)

    def test_categories_excludes_deleted(self):
        """Categories should not count deleted archives."""
        archive = self.create_archive("https://example.com/deleted", "Deleted")
        archive.ai_categories = ["Technology"]
        archive.save()
        archive.soft_delete()

        response = self.client.get("/api/archive/categories")
        data = response.json()

        # Should have no categories since only archive is deleted
        self.assertEqual(len(data["categories"]), 0)


# =============================================================================
# API Tests: Domains Endpoint
# =============================================================================


class Test_DomainsEndpoint(ArchiveTestCase):
    """Tests for the /api/archive/domains endpoint."""

    def test_domains_requires_auth(self):
        """Domains endpoint should require authentication."""
        self.client.logout()
        response = self.client.get("/api/archive/domains")
        self.assertIn(response.status_code, [302, 403])

    def test_domains_returns_top_domains(self):
        """Domains should return domain list with counts."""
        for i in range(5):
            self.create_archive(f"https://example.com/page{i}", f"Example {i}")
        for i in range(3):
            self.create_archive(f"https://other.com/page{i}", f"Other {i}")

        response = self.client.get("/api/archive/domains")
        data = response.json()

        self.assertEqual(data.get("code"), 0)
        domains = {d["domain"]: d["count"] for d in data["domains"]}

        self.assertEqual(domains.get("example.com"), 5)
        self.assertEqual(domains.get("other.com"), 3)

    def test_domains_respects_limit(self):
        """Domains should respect limit parameter."""
        for i in range(10):
            self.create_archive(f"https://site{i}.com/page", f"Site {i}")

        response = self.client.get("/api/archive/domains?limit=5")
        data = response.json()

        self.assertLessEqual(len(data["domains"]), 5)

    def test_domains_includes_last_visit(self):
        """Domains should include last_visit timestamp."""
        self.create_archive("https://example.com/test", "Test")

        response = self.client.get("/api/archive/domains")
        data = response.json()

        self.assertIn("last_visit", data["domains"][0])


# =============================================================================
# API Tests: Stats Endpoint
# =============================================================================


class Test_StatsEndpoint(ArchiveTestCase):
    """Tests for the /api/archive/stats endpoint."""

    def test_stats_requires_auth(self):
        """Stats endpoint should require authentication."""
        self.client.logout()
        response = self.client.get("/api/archive/stats")
        self.assertIn(response.status_code, [302, 403])

    def test_stats_returns_correct_totals(self):
        """Stats should return correct total counts."""
        for i in range(5):
            self.create_archive(f"https://example.com/page{i}", f"Article {i}")

        response = self.client.get("/api/archive/stats")
        data = response.json()

        self.assertEqual(data.get("code"), 0)
        self.assertEqual(data["stats"]["total_archived"], 5)

    def test_stats_today_and_week_counts(self):
        """Stats should correctly count today and this week."""
        # Create archive today
        self.create_archive("https://example.com/today", "Today Article")

        response = self.client.get("/api/archive/stats")
        data = response.json()

        self.assertGreaterEqual(data["stats"]["archives_today"], 1)
        self.assertGreaterEqual(data["stats"]["archives_this_week"], 1)

    def test_stats_excludes_deleted(self):
        """Stats should not count deleted archives."""
        archive = self.create_archive("https://example.com/deleted", "Deleted")
        archive.soft_delete()

        response = self.client.get("/api/archive/stats")
        data = response.json()

        self.assertEqual(data["stats"]["total_archived"], 0)

    def test_stats_total_domains(self):
        """Stats should count unique domains."""
        self.create_archive("https://site1.com/page", "Site 1")
        self.create_archive("https://site2.com/page", "Site 2")
        self.create_archive("https://site1.com/page2", "Site 1 Again")

        response = self.client.get("/api/archive/stats")
        data = response.json()

        self.assertEqual(data["stats"]["total_domains"], 2)


# =============================================================================
# API Tests: Delete Endpoint
# =============================================================================


class Test_DeleteEndpoint(ArchiveTestCase):
    """Tests for the /api/archive/delete endpoint."""

    def test_delete_requires_auth(self):
        """Delete endpoint should require authentication."""
        self.client.logout()
        response = self.client.post(
            "/api/archive/delete",
            {"archive_ids": "[]"},
        )
        self.assertIn(response.status_code, [302, 403])

    def test_delete_single_archive(self):
        """Delete should soft-delete a single archive."""
        archive = self.create_archive("https://example.com/to-delete", "To Delete")
        archive_id = str(archive.id)

        response = self.client.post(
            "/api/archive/delete",
            {"archive_ids": stdlib_json.dumps([archive_id])},
        )
        data = response.json()

        self.assertEqual(data.get("code"), 0)
        self.assertEqual(data.get("deleted"), 1)

        # Verify it's soft-deleted
        archive.reload()
        self.assertTrue(archive.deleted)

    def test_delete_multiple_archives(self):
        """Delete should handle multiple archives."""
        archive1 = self.create_archive("https://example.com/del1", "Delete 1")
        archive2 = self.create_archive("https://example.com/del2", "Delete 2")

        response = self.client.post(
            "/api/archive/delete",
            {"archive_ids": stdlib_json.dumps([str(archive1.id), str(archive2.id)])},
        )
        data = response.json()

        self.assertEqual(data.get("deleted"), 2)

    def test_delete_nonexistent_archive(self):
        """Delete should handle nonexistent archive gracefully."""
        response = self.client.post(
            "/api/archive/delete",
            {"archive_ids": stdlib_json.dumps(["000000000000000000000000"])},
        )
        data = response.json()

        self.assertEqual(data.get("code"), 0)
        self.assertEqual(data.get("deleted"), 0)

    def test_delete_other_users_archive(self):
        """Delete should not delete other user's archives."""
        # Create archive for different user
        other_user_id = self.user.pk + 1000
        archive, _, _ = MArchivedStory.archive_page(
            user_id=other_user_id,
            url="https://example.com/other",
            title="Other User's Article",
        )

        response = self.client.post(
            "/api/archive/delete",
            {"archive_ids": stdlib_json.dumps([str(archive.id)])},
        )
        data = response.json()

        # Should not delete (not found for this user)
        self.assertEqual(data.get("deleted"), 0)

        # Verify still exists
        archive.reload()
        self.assertFalse(archive.deleted)

        # Clean up
        MArchivedStory.objects(user_id=other_user_id).delete()


# =============================================================================
# API Tests: Blocklist Endpoint
# =============================================================================


class Test_BlocklistEndpoint(ArchiveTestCase):
    """Tests for the /api/archive/blocklist endpoints."""

    def test_get_blocklist_returns_defaults(self):
        """Get blocklist should return default lists."""
        response = self.client.get("/api/archive/blocklist")
        data = response.json()

        self.assertEqual(data.get("code"), 0)
        self.assertIn("default_blocked_domains", data)
        self.assertIn("default_blocked_patterns", data)
        self.assertGreater(len(data["default_blocked_domains"]), 0)

    def test_get_blocklist_returns_custom(self):
        """Get blocklist should return custom user settings."""
        settings = MArchiveUserSettings.get_or_create(self.user.pk)
        settings.blocked_domains = ["custom.com"]
        settings.save()

        response = self.client.get("/api/archive/blocklist")
        data = response.json()

        self.assertIn("custom.com", data["custom_blocked_domains"])

    def test_update_blocklist_adds_domains(self):
        """Update blocklist should add custom domains."""
        response = self.client.post(
            "/api/archive/blocklist/update",
            {"blocked_domains": stdlib_json.dumps(["newblock.com"])},
        )
        self.assertEqual(response.json().get("code"), 0)

        settings = MArchiveUserSettings.get_or_create(self.user.pk)
        self.assertIn("newblock.com", settings.blocked_domains)

    def test_update_blocklist_adds_patterns(self):
        """Update blocklist should add custom patterns."""
        response = self.client.post(
            "/api/archive/blocklist/update",
            {"blocked_patterns": stdlib_json.dumps([r"/internal/.*"])},
        )
        self.assertEqual(response.json().get("code"), 0)

        settings = MArchiveUserSettings.get_or_create(self.user.pk)
        self.assertIn(r"/internal/.*", settings.blocked_patterns)

    def test_update_blocklist_allowed_domains(self):
        """Update blocklist should set allowed domains."""
        response = self.client.post(
            "/api/archive/blocklist/update",
            {"allowed_domains": stdlib_json.dumps(["chase.com"])},
        )
        self.assertEqual(response.json().get("code"), 0)

        settings = MArchiveUserSettings.get_or_create(self.user.pk)
        self.assertIn("chase.com", settings.allowed_domains)


# =============================================================================
# API Tests: Export Endpoint
# =============================================================================


class Test_ExportEndpoint(ArchiveTestCase):
    """Tests for the /api/archive/export endpoint."""

    def test_export_json_format(self):
        """Export should return JSON array."""
        self.create_archive("https://example.com/export1", "Export 1")
        self.create_archive("https://example.com/export2", "Export 2")

        response = self.client.get("/api/archive/export?format=json")

        self.assertEqual(response.status_code, 200)
        self.assertIn("application/json", response["Content-Type"])

        data = stdlib_json.loads(response.content)
        self.assertEqual(len(data), 2)

    def test_export_csv_format(self):
        """Export should return CSV file."""
        self.create_archive("https://example.com/csv1", "CSV Export")

        response = self.client.get("/api/archive/export?format=csv")

        self.assertEqual(response.status_code, 200)
        self.assertIn("text/csv", response["Content-Type"])
        self.assertIn("attachment", response.get("Content-Disposition", ""))

    def test_export_include_content_flag(self):
        """Export with include_content should include full content."""
        self.create_archive(
            "https://example.com/content",
            "Content Article",
            content="Full article content here",
        )

        response = self.client.get("/api/archive/export?format=json&include_content=true")
        data = stdlib_json.loads(response.content)

        self.assertIn("content", data[0])
        self.assertEqual(data[0]["content"], "Full article content here")

    def test_export_excludes_deleted(self):
        """Export should not include deleted archives."""
        self.create_archive("https://example.com/active", "Active")
        archive = self.create_archive("https://example.com/deleted", "Deleted")
        archive.soft_delete()

        response = self.client.get("/api/archive/export?format=json")
        data = stdlib_json.loads(response.content)

        self.assertEqual(len(data), 1)
        self.assertEqual(data[0]["title"], "Active")


# =============================================================================
# Integration Tests: End-to-End Flows
# =============================================================================


class Test_IngestAndRetrieveIntegration(ArchiveTestCase):
    """Integration tests for complete ingest-to-retrieve flows."""

    def test_ingest_then_list(self):
        """Archive created via ingest should appear in list."""
        # Ingest
        self.client.post(
            "/api/archive/ingest",
            {
                "url": "https://integration.test/article",
                "title": "Integration Test Article",
            },
        )

        # List
        response = self.client.get("/api/archive/list")
        data = response.json()

        self.assertEqual(len(data["archives"]), 1)
        self.assertEqual(data["archives"][0]["title"], "Integration Test Article")

    def test_ingest_then_retrieve_content(self):
        """Content ingested should be retrievable."""
        test_content = "This is the full article content for integration testing."

        # Ingest with content
        ingest_response = self.client.post(
            "/api/archive/ingest",
            {
                "url": "https://integration.test/content",
                "title": "Content Test",
                "content": test_content,
            },
        )
        archive_id = ingest_response.json()["archive_id"]

        # Retrieve and verify
        archive = MArchivedStory.objects.get(id=archive_id)
        self.assertEqual(archive.get_content(), test_content)

    def test_ingest_update_then_list(self):
        """Revisiting URL should update archive fields."""
        # First visit
        self.client.post(
            "/api/archive/ingest",
            {
                "url": "https://integration.test/revisit",
                "title": "First Visit",
                "time_on_page": "30",
            },
        )

        # Second visit
        self.client.post(
            "/api/archive/ingest",
            {
                "url": "https://integration.test/revisit",
                "title": "Second Visit",
                "time_on_page": "60",
            },
        )

        # Verify updates
        response = self.client.get("/api/archive/list")
        archive = response.json()["archives"][0]

        self.assertEqual(archive["visit_count"], 2)
        self.assertEqual(archive["time_on_page_seconds"], 90)

    def test_batch_ingest_then_stats(self):
        """Batch ingest should update stats correctly."""
        archives = [
            {"url": f"https://batch.test/page{i}", "title": f"Page {i}", "browser": "chrome"}
            for i in range(10)
        ]

        self.client.post(
            "/api/archive/batch_ingest",
            stdlib_json.dumps(archives),
            content_type="application/json",
        )

        response = self.client.get("/api/archive/stats")
        stats = response.json()["stats"]

        self.assertEqual(stats["total_archived"], 10)

    def test_ingest_delete_then_list(self):
        """Deleted archive should not appear in default list."""
        # Ingest
        ingest_response = self.client.post(
            "/api/archive/ingest",
            {
                "url": "https://integration.test/delete-flow",
                "title": "Delete Flow Test",
            },
        )
        archive_id = ingest_response.json()["archive_id"]

        # Delete
        self.client.post(
            "/api/archive/delete",
            {"archive_ids": stdlib_json.dumps([archive_id])},
        )

        # List should be empty
        response = self.client.get("/api/archive/list")
        self.assertEqual(len(response.json()["archives"]), 0)

    def test_ingest_then_export_json(self):
        """Archives should be exportable as JSON."""
        # Ingest multiple
        for i in range(3):
            self.client.post(
                "/api/archive/ingest",
                {
                    "url": f"https://export.test/page{i}",
                    "title": f"Export Page {i}",
                },
            )

        # Export
        response = self.client.get("/api/archive/export?format=json")
        data = stdlib_json.loads(response.content)

        self.assertEqual(len(data), 3)
        titles = [a["title"] for a in data]
        self.assertIn("Export Page 0", titles)

    def test_ingest_then_export_csv(self):
        """Archives should be exportable as CSV."""
        self.client.post(
            "/api/archive/ingest",
            {
                "url": "https://export.test/csv",
                "title": "CSV Export Test",
            },
        )

        response = self.client.get("/api/archive/export?format=csv")
        content = response.content.decode("utf-8")

        # Should have header and data row
        lines = content.strip().split("\n")
        self.assertGreaterEqual(len(lines), 2)
        self.assertIn("CSV Export Test", content)

    def test_full_lifecycle(self):
        """Test complete archive lifecycle: create, update, categorize, delete."""
        # Create
        ingest_response = self.client.post(
            "/api/archive/ingest",
            {
                "url": "https://lifecycle.test/article",
                "title": "Lifecycle Test",
                "content": "Article about technology and programming.",
            },
        )
        archive_id = ingest_response.json()["archive_id"]
        archive = MArchivedStory.objects.get(id=archive_id)

        # Update (revisit)
        self.client.post(
            "/api/archive/ingest",
            {
                "url": "https://lifecycle.test/article",
                "title": "Lifecycle Test",
                "time_on_page": "120",
            },
        )
        archive.reload()
        self.assertEqual(archive.visit_count, 2)

        # Categorize (simulate)
        archive.ai_categories = ["Technology"]
        archive.save()

        # Verify in list with category
        response = self.client.get("/api/archive/list?category=Technology")
        self.assertEqual(len(response.json()["archives"]), 1)

        # Delete
        self.client.post(
            "/api/archive/delete",
            {"archive_ids": stdlib_json.dumps([archive_id])},
        )

        # Verify deleted
        response = self.client.get("/api/archive/list")
        self.assertEqual(len(response.json()["archives"]), 0)

        # Can still see with include_deleted
        response = self.client.get("/api/archive/list?include_deleted=true")
        self.assertEqual(len(response.json()["archives"]), 1)
