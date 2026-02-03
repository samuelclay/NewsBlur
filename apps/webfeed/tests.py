import hashlib
from unittest.mock import MagicMock, patch

from django.test import TestCase

from apps.webfeed.models import MWebFeedConfig
from apps.webfeed.tasks import extract_preview_stories
from utils.webfeed_fetcher import WebFeedFetcher


class Test_ExtractPreviewStories(TestCase):
    def setUp(self):
        self.html = """
        <html><body>
        <div class="post">
            <h2><a href="/article-1">First Article</a></h2>
            <p class="excerpt">This is the first article excerpt.</p>
        </div>
        <div class="post">
            <h2><a href="/article-2">Second Article</a></h2>
            <p class="excerpt">This is the second article excerpt.</p>
        </div>
        <div class="post">
            <h2><a href="/article-3">Third Article</a></h2>
            <p class="excerpt">This is the third article excerpt.</p>
        </div>
        </body></html>
        """

    def test_extract_stories_basic(self):
        variant = {
            "story_container": "//div[@class='post']",
            "title": ".//h2/a/text()",
            "link": ".//h2/a/@href",
            "content": ".//p[@class='excerpt']/text()",
        }
        stories = extract_preview_stories(self.html, variant, "https://example.com")
        self.assertEqual(len(stories), 3)
        self.assertEqual(stories[0]["title"], "First Article")
        self.assertEqual(stories[0]["link"], "https://example.com/article-1")
        self.assertEqual(stories[0]["content"], "This is the first article excerpt.")

    def test_extract_stories_relative_links(self):
        variant = {
            "story_container": "//div[@class='post']",
            "title": ".//h2/a/text()",
            "link": ".//h2/a/@href",
        }
        stories = extract_preview_stories(self.html, variant, "https://example.com")
        self.assertTrue(stories[0]["link"].startswith("https://"))

    def test_extract_stories_bad_xpath(self):
        variant = {
            "story_container": "//div[@class='nonexistent']",
            "title": ".//h2/a/text()",
            "link": ".//h2/a/@href",
        }
        stories = extract_preview_stories(self.html, variant, "https://example.com")
        self.assertEqual(len(stories), 0)

    def test_extract_stories_invalid_html(self):
        variant = {
            "story_container": "//div",
            "title": ".//h2/text()",
            "link": ".//a/@href",
        }
        stories = extract_preview_stories("", variant, "https://example.com")
        self.assertEqual(len(stories), 0)


class Test_GuidGeneration(TestCase):
    def test_guid_from_permalink(self):
        fetcher = MagicMock(spec=WebFeedFetcher)
        fetcher.feed = MagicMock()
        fetcher.feed.pk = 1
        fetcher._generate_guid = WebFeedFetcher._generate_guid.__get__(fetcher)

        guid = fetcher._generate_guid("https://example.com/article-1", "Article 1")
        expected = hashlib.sha256("https://example.com/article-1".encode("utf-8")).hexdigest()[:32]
        self.assertEqual(guid, expected)

    def test_guid_from_permalink_normalized(self):
        fetcher = MagicMock(spec=WebFeedFetcher)
        fetcher.feed = MagicMock()
        fetcher.feed.pk = 1
        fetcher._generate_guid = WebFeedFetcher._generate_guid.__get__(fetcher)

        guid1 = fetcher._generate_guid("https://example.com/article/", "Article")
        guid2 = fetcher._generate_guid("https://example.com/article", "Article")
        self.assertEqual(guid1, guid2)

    def test_guid_from_title_fallback(self):
        fetcher = MagicMock(spec=WebFeedFetcher)
        fetcher.feed = MagicMock()
        fetcher.feed.pk = 42
        fetcher._generate_guid = WebFeedFetcher._generate_guid.__get__(fetcher)

        guid = fetcher._generate_guid(None, "Some Title")
        expected = hashlib.sha256("42:some title".encode("utf-8")).hexdigest()[:32]
        self.assertEqual(guid, expected)

    def test_guid_length(self):
        fetcher = MagicMock(spec=WebFeedFetcher)
        fetcher.feed = MagicMock()
        fetcher.feed.pk = 1
        fetcher._generate_guid = WebFeedFetcher._generate_guid.__get__(fetcher)

        guid = fetcher._generate_guid("https://example.com/test", "Test")
        self.assertEqual(len(guid), 32)


class Test_MWebFeedConfig(TestCase):
    def test_record_failure_triggers_reanalysis(self):
        config = MWebFeedConfig(
            feed_id=99999,
            url="https://example.com",
            story_container_xpath="//div",
            title_xpath=".//h2/text()",
            link_xpath=".//a/@href",
        )
        config.save = MagicMock()

        config.record_failure()
        self.assertEqual(config.consecutive_failures, 1)
        self.assertFalse(config.needs_reanalysis)

        config.record_failure()
        self.assertEqual(config.consecutive_failures, 2)
        self.assertFalse(config.needs_reanalysis)

        config.record_failure()
        self.assertEqual(config.consecutive_failures, 3)
        self.assertTrue(config.needs_reanalysis)

    def test_record_success_resets_failures(self):
        config = MWebFeedConfig(
            feed_id=99999,
            url="https://example.com",
            story_container_xpath="//div",
            title_xpath=".//h2/text()",
            link_xpath=".//a/@href",
            consecutive_failures=5,
            needs_reanalysis=True,
        )
        config.save = MagicMock()

        config.record_success()
        self.assertEqual(config.consecutive_failures, 0)
        self.assertFalse(config.needs_reanalysis)
        self.assertIsNotNone(config.last_successful_extract)


class Test_FeedParserFormat(TestCase):
    def test_feedparser_result_structure(self):
        from utils.webfeed_fetcher import FeedParserResult

        fpf = FeedParserResult(
            entries=[{"title": "Test", "link": "https://example.com", "guid": "abc123"}],
            feed_title="Test Feed",
            feed_link="https://example.com",
        )
        self.assertEqual(len(fpf.entries), 1)
        self.assertEqual(fpf.encoding, "utf-8")
        self.assertEqual(fpf.feed.title, "Test Feed")
        self.assertEqual(fpf.status, 200)
        self.assertEqual(fpf.bozo, 0)
