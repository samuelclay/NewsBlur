import hashlib
from unittest.mock import MagicMock, patch

from django.contrib.auth.models import User
from django.test import TestCase
from django.test.client import Client
from django.urls import reverse

from apps.webfeed.models import MWebFeedConfig
from apps.webfeed.prompts import get_analysis_messages
from apps.webfeed.tasks import (
    choose_better_attempt,
    extract_image_url,
    extract_preview_stories,
    parse_variants_json,
    rank_variants_by_previews,
)
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


class Test_XPathBrittleness(TestCase):
    """Reproduces the csis.org failure report: an exact full-class XPath breaks
    the moment a site reorders its utility classes (or the LLM mis-copies the
    long class string), while contains() on a single stable token keeps working.

    csis.org is a Tailwind/utility-CSS site, so its story containers carry long
    class strings like "@container ts-card-slim relative". Matching the whole
    string with @class='...' is fragile both at generation time and across site
    deploys; matching contains(@class,'ts-card-slim') is not.
    """

    # The same two article cards in two layouts. HTML_REORDERED only shuffles
    # the order of the utility classes -- exactly what a front-end rebuild does.
    HTML_ORIGINAL = """
    <html><body><main>
    <article class="@container ts-card-slim relative">
        <h3 class="ts-card-slim__headline"><span>First Analysis</span></h3>
        <a class="card_overlay-link" href="/analysis/first"></a>
    </article>
    <article class="@container ts-card-slim relative">
        <h3 class="ts-card-slim__headline"><span>Second Analysis</span></h3>
        <a class="card_overlay-link" href="/analysis/second"></a>
    </article>
    </main></body></html>
    """
    HTML_REORDERED = """
    <html><body><main>
    <article class="relative ts-card-slim @container">
        <h3 class="ts-card-slim__headline"><span>First Analysis</span></h3>
        <a class="card_overlay-link" href="/analysis/first"></a>
    </article>
    <article class="relative ts-card-slim @container">
        <h3 class="ts-card-slim__headline"><span>Second Analysis</span></h3>
        <a class="card_overlay-link" href="/analysis/second"></a>
    </article>
    </main></body></html>
    """

    EXACT_VARIANT = {
        "story_container": "//article[@class='@container ts-card-slim relative']",
        "title": ".//h3/span/text()",
        "link": ".//a/@href",
    }
    CONTAINS_VARIANT = {
        "story_container": "//article[contains(@class,'ts-card-slim')]",
        "title": ".//h3/span/text()",
        "link": ".//a/@href",
    }

    def test_exact_class_match_works_on_original_layout(self):
        stories = extract_preview_stories(self.HTML_ORIGINAL, self.EXACT_VARIANT, "https://csis.org")
        self.assertEqual(len(stories), 2)

    def test_exact_class_match_breaks_when_classes_reorder(self):
        # The bug: a trivial utility-class reorder yields zero stories.
        stories = extract_preview_stories(self.HTML_REORDERED, self.EXACT_VARIANT, "https://csis.org")
        self.assertEqual(len(stories), 0)

    def test_contains_match_is_robust_to_reorder(self):
        # The fix: contains() on a stable token extracts in both layouts.
        original = extract_preview_stories(self.HTML_ORIGINAL, self.CONTAINS_VARIANT, "https://csis.org")
        reordered = extract_preview_stories(self.HTML_REORDERED, self.CONTAINS_VARIANT, "https://csis.org")
        self.assertEqual(len(original), 2)
        self.assertEqual(len(reordered), 2)
        self.assertEqual(original[0]["title"], "First Analysis")


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


class Test_ParseVariantsJson(TestCase):
    def test_plain_json_array(self):
        self.assertEqual(parse_variants_json('[{"a": 1}]'), [{"a": 1}])

    def test_strips_code_fences(self):
        self.assertEqual(parse_variants_json('```json\n[{"a": 1}]\n```'), [{"a": 1}])

    def test_invalid_json_returns_none(self):
        self.assertIsNone(parse_variants_json("not json at all"))

    def test_non_list_returns_none(self):
        self.assertIsNone(parse_variants_json('{"a": 1}'))

    def test_empty_list_returns_empty_list(self):
        self.assertEqual(parse_variants_json("[]"), [])


class Test_RankVariantsByPreviews(TestCase):
    def test_ranks_by_story_count_descending(self):
        variants = [
            {"label": "few", "preview_stories": [{"t": 1}]},
            {"label": "many", "preview_stories": [{"t": 1}, {"t": 2}, {"t": 3}]},
            {"label": "none", "preview_stories": []},
        ]
        ranked, usable = rank_variants_by_previews(variants)
        self.assertEqual([v["label"] for v in ranked], ["many", "few", "none"])
        self.assertEqual(usable, 2)
        # index is renumbered to match the new display order
        self.assertEqual([v["index"] for v in ranked], [0, 1, 2])

    def test_zero_usable_when_no_previews(self):
        ranked, usable = rank_variants_by_previews([{"preview_stories": []}, {"preview_stories": []}])
        self.assertEqual(usable, 0)

    def test_stable_order_for_ties(self):
        variants = [
            {"label": "a", "preview_stories": [{"t": 1}]},
            {"label": "b", "preview_stories": [{"t": 1}]},
        ]
        ranked, usable = rank_variants_by_previews(variants)
        self.assertEqual([v["label"] for v in ranked], ["a", "b"])
        self.assertEqual(usable, 2)


class Test_ChooseBetterAttempt(TestCase):
    def test_prefers_more_usable(self):
        first = ([{"x": 1}], 0, "ra")
        second = ([{"y": 1}], 2, "rb")
        self.assertIs(choose_better_attempt(first, second), second)

    def test_keeps_first_when_it_has_more(self):
        first = ([{"x": 1}], 3, "ra")
        second = ([{"y": 1}], 1, "rb")
        self.assertIs(choose_better_attempt(first, second), first)

    def test_falls_back_to_nonempty_when_both_zero(self):
        first = (None, 0, "ra")
        second = ([{"y": 1}], 0, "rb")
        self.assertIs(choose_better_attempt(first, second), second)

    def test_both_unparseable_returns_first(self):
        first = (None, 0, "ra")
        second = (None, 0, "rb")
        self.assertIs(choose_better_attempt(first, second), first)


class Test_AnalysisMessages(TestCase):
    def test_system_prompt_steers_to_contains_matching(self):
        msgs = get_analysis_messages("https://example.com", "<html></html>")
        system = msgs[0]["content"]
        self.assertIn("contains(@class", system)
        self.assertIn("NEVER match the whole class attribute", system)

    def test_retry_appends_nudge(self):
        base = get_analysis_messages("https://example.com", "<html></html>", retry=False)
        retried = get_analysis_messages("https://example.com", "<html></html>", retry=True)
        self.assertNotIn("RETRY NOTE", base[1]["content"])
        self.assertIn("RETRY NOTE", retried[1]["content"])


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
