import hashlib
from unittest.mock import MagicMock, patch

from django.contrib.auth.models import User
from django.test import TestCase
from django.test.client import Client
from django.urls import reverse

from apps.webfeed.models import MWebFeedConfig
from apps.webfeed.tasks import extract_image_url, extract_preview_stories
from utils import feedfinder_forman
from utils import json_functions as json
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

    def test_extract_stories_css_background_image(self):
        html = """
        <html><body>
        <div class="card">
            <div class="thumb" style="background-image: url(/images/photo1.webp); background-size: cover;"></div>
            <h2><a href="/article-1">First Article</a></h2>
        </div>
        <div class="card">
            <div class="thumb" style="background-image: url('/images/photo2.webp');"></div>
            <h2><a href="/article-2">Second Article</a></h2>
        </div>
        </body></html>
        """
        variant = {
            "story_container": "//div[@class='card']",
            "title": ".//h2/a/text()",
            "link": ".//h2/a/@href",
            "image": ".//div[@class='thumb']/@style",
        }
        stories = extract_preview_stories(html, variant, "https://example.com")
        self.assertEqual(len(stories), 2)
        self.assertEqual(stories[0]["image"], "https://example.com/images/photo1.webp")
        self.assertEqual(stories[1]["image"], "https://example.com/images/photo2.webp")


class Test_ExtractImageUrl(TestCase):
    def test_plain_url_passthrough(self):
        self.assertEqual(extract_image_url("/images/photo.jpg"), "/images/photo.jpg")

    def test_absolute_url_passthrough(self):
        self.assertEqual(extract_image_url("https://example.com/photo.jpg"), "https://example.com/photo.jpg")

    def test_css_background_image_unquoted(self):
        result = extract_image_url("background-image: url(/images/photo.jpg); background-size: cover;")
        self.assertEqual(result, "/images/photo.jpg")

    def test_css_background_image_single_quoted(self):
        result = extract_image_url("background-image: url('/images/photo.jpg')")
        self.assertEqual(result, "/images/photo.jpg")

    def test_css_background_image_double_quoted(self):
        result = extract_image_url('background-image: url("/images/photo.jpg")')
        self.assertEqual(result, "/images/photo.jpg")

    def test_none_input(self):
        self.assertIsNone(extract_image_url(None))

    def test_empty_string(self):
        self.assertIsNone(extract_image_url(""))

    def test_data_uri(self):
        result = extract_image_url("background-image: url(data:image/png;base64,ABC123)")
        self.assertEqual(result, "data:image/png;base64,ABC123")


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


class Test_UrlIsFeed(TestCase):
    """feedfinder_forman.url_is_feed answers the narrow question "is the document
    at this URL already a feed?" so the Web Feed page-monitoring flow can hand a
    real feed URL off to a normal (free) subscription. It must say yes for a URL
    that itself serves feed content, and no for a web *page* that merely links to
    a feed -- that referenced feed may not be what the user wants.
    apps/webfeed/tests.py
    """

    ATOM = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<feed xmlns="http://www.w3.org/2005/Atom"><title>Bubbles Briefing</title>'
        "<entry><title>An entry</title></entry></feed>"
    )
    RSS = (
        '<?xml version="1.0"?><rss version="2.0"><channel><title>X</title>'
        "<item><title>An item</title></item></channel></rss>"
    )
    JSON_FEED = '{"version":"https://jsonfeed.org/version/1","title":"X","items":[{"id":"1"}]}'
    HTML_WITH_FEED_LINK = (
        "<!doctype html><html><head>"
        '<link rel="alternate" type="application/rss+xml" href="/feed">'
        "</head><body><h1>A web page</h1></body></html>"
    )
    HTML_PLAIN = "<!doctype html><html><head><title>Hi</title></head><body><p>hello</p></body></html>"

    def _patch_fetch(self, text):
        return patch.object(feedfinder_forman.FeedFinder, "get_feed", return_value=text)

    def test_atom_url_is_feed(self):
        with self._patch_fetch(self.ATOM):
            self.assertTrue(feedfinder_forman.url_is_feed("https://bubbles.town/briefing/feed"))

    def test_rss_url_is_feed(self):
        with self._patch_fetch(self.RSS):
            self.assertTrue(feedfinder_forman.url_is_feed("https://example.com/rss.xml"))

    def test_json_feed_url_is_feed(self):
        with self._patch_fetch(self.JSON_FEED):
            self.assertTrue(feedfinder_forman.url_is_feed("https://example.com/feed.json"))

    def test_html_page_with_feed_link_is_not_feed(self):
        # The user explicitly wants the Web Feed flow left alone for a web page
        # that happens to reference an RSS feed.
        with self._patch_fetch(self.HTML_WITH_FEED_LINK):
            self.assertFalse(feedfinder_forman.url_is_feed("https://example.com/"))

    def test_plain_html_page_is_not_feed(self):
        with self._patch_fetch(self.HTML_PLAIN):
            self.assertFalse(feedfinder_forman.url_is_feed("https://example.com/"))

    def test_unfetchable_url_is_not_feed(self):
        with self._patch_fetch(None):
            self.assertFalse(feedfinder_forman.url_is_feed("https://example.com/"))


class Test_WebFeedAnalyzeRedirectsRealFeeds(TestCase):
    """Reproduces forum report "Cannot subscribe to rss feeds any more": pasting a
    real RSS/Atom feed URL into the Web Feed tab ran the Premium-Archive
    page-monitoring analysis instead of just subscribing. The analyze endpoint
    should short-circuit (code 2) when the URL is itself a feed, and only run the
    page analysis (code 1) for an actual web page.
    apps/webfeed/tests.py
    """

    def setUp(self):
        self.user = User.objects.create_user("webfeed_tester", "wf@example.com", "test")
        self.client = Client()
        self.client.force_login(self.user)

    @patch("apps.webfeed.views.AnalyzeWebFeedPage.apply_async")
    @patch("apps.webfeed.views.RTrendingWebFeed.record_analysis")
    @patch("utils.feedfinder_forman.url_is_feed", return_value=True)
    def test_real_feed_url_redirects_to_subscribe(self, mock_is_feed, mock_record, mock_task):
        response = self.client.post(reverse("webfeed-analyze"), {"url": "https://bubbles.town/briefing/feed"})
        data = json.decode(response.content)
        self.assertEqual(data["code"], 2)
        self.assertEqual(data["feed_address"], "https://bubbles.town/briefing/feed")
        # The expensive page-monitoring analysis must NOT run for a real feed.
        mock_task.assert_not_called()

    @patch("apps.webfeed.views.AnalyzeWebFeedPage.apply_async")
    @patch("apps.webfeed.views.RTrendingWebFeed.record_analysis")
    @patch("utils.feedfinder_forman.url_is_feed", return_value=False)
    def test_web_page_still_runs_analysis(self, mock_is_feed, mock_record, mock_task):
        response = self.client.post(reverse("webfeed-analyze"), {"url": "https://example.com/"})
        data = json.decode(response.content)
        self.assertEqual(data["code"], 1)
        # A real web page keeps the page-monitoring flow.
        mock_task.assert_called_once()
