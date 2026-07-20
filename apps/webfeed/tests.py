import hashlib
from unittest.mock import MagicMock, patch

from django.contrib.auth.models import User
from django.test import TestCase
from django.test.client import Client
from django.urls import reverse

from apps.webfeed.models import MWebFeedConfig, is_degenerate_container_xpath
from apps.webfeed.prompts import get_analysis_messages
from apps.webfeed.tasks import (
    choose_better_attempt,
    extract_image_url,
    extract_preview_stories,
    filter_degenerate_variants,
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

    def test_link_free_story_uses_source_page_permalink(self):
        fetcher = WebFeedFetcher.__new__(WebFeedFetcher)
        fetcher.feed = MagicMock()
        fetcher.url = "https://example.com/releases"

        fpf = fetcher._to_feedparser_format(
            [
                {
                    "title": "Version 1.2.3",
                    "link": None,
                    "guid": "release-1.2.3",
                    "content": "Release notes",
                }
            ]
        )

        self.assertEqual(fpf.entries[0]["link"], "https://example.com/releases")


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


class Test_DegenerateContainerXPaths(TestCase):
    """A container XPath pinned to specific item ids can only ever re-match the
    analysis-time items, so the feed never finds a new story. See
    is_degenerate_container_xpath in apps/webfeed/models.py."""

    def test_hardcoded_item_ids_are_degenerate(self):
        # The exact pattern that froze a production AbeBooks web feed.
        xpath = (
            "//li[@data-test-id='listing-item-32438580283' or "
            "@data-test-id='listing-item-32414887644' or "
            "@data-test-id='listing-item-32297928829' or "
            "@data-test-id='listing-item-32283704996']"
        )
        self.assertTrue(is_degenerate_container_xpath(xpath))

    def test_single_item_id_is_degenerate(self):
        self.assertTrue(is_degenerate_container_xpath("//div[@id='post-84721']"))

    def test_long_or_chain_is_degenerate(self):
        xpath = "//li[@data-name='alpha' or @data-name='beta' or " "@data-name='gamma' or @data-name='delta']"
        self.assertTrue(is_degenerate_container_xpath(xpath))

    def test_generic_containers_are_fine(self):
        for xpath in [
            "//li[contains(@class, 'result-item')]",
            "//div[contains(@class, 'post')]",
            "//li[contains(@class, 'result-item') or @data-srp-item-role='listing']"
            " | //ul[@id='srp-search-results-list']/li",
            "//li[starts-with(@data-test-id, 'listing-item-')]",
            "//article",
        ]:
            self.assertFalse(is_degenerate_container_xpath(xpath), xpath)

    def test_empty_is_not_degenerate(self):
        self.assertFalse(is_degenerate_container_xpath(""))
        self.assertFalse(is_degenerate_container_xpath(None))

    def test_filter_drops_only_degenerate_variants(self):
        variants = [
            {"story_container": "//li[contains(@class, 'result-item')]", "title": ".//a/text()"},
            {"story_container": "//li[@data-test-id='listing-item-32438580283']", "title": ".//a/text()"},
        ]
        kept = filter_degenerate_variants(variants)
        self.assertEqual(len(kept), 1)
        self.assertEqual(kept[0]["story_container"], "//li[contains(@class, 'result-item')]")


class Test_WebFeedNotifiesSubscribers(TestCase):
    """New webfeed stories must run the same subscriber notification steps as the
    regular fetch pipeline, or unread counts never update until the user opens the
    feed by hand. See Feed.update_webfeed in apps/rss_feeds/models.py."""

    def make_feed(self):
        from apps.rss_feeds.models import Feed

        return Feed(
            pk=101,
            feed_title="AbeBooks search",
            feed_address="webfeed:https://example.com/search",
            archive_subscribers=1,
        )

    @patch("utils.feed_fetcher.FeedFetcherWorker")
    @patch("utils.feed_fetcher.ProcessFeed")
    @patch("utils.webfeed_fetcher.WebFeedFetcher")
    def test_new_stories_notify_subscribers(self, MockFetcher, MockProcess, MockWorker):
        feed = self.make_feed()
        MockFetcher.return_value.fetch.return_value = MagicMock()
        MockProcess.return_value.process.return_value = (0, {"new": 3, "updated": 0, "same": 9})

        feed.update_webfeed()

        worker = MockWorker.return_value
        worker.publish_to_subscribers.assert_called_once_with(feed, 3)
        worker.count_unreads_for_subscribers.assert_called_once_with(feed, new_story_count=3)

    @patch("utils.feed_fetcher.FeedFetcherWorker")
    @patch("utils.feed_fetcher.ProcessFeed")
    @patch("utils.webfeed_fetcher.WebFeedFetcher")
    def test_no_new_stories_skips_notification(self, MockFetcher, MockProcess, MockWorker):
        feed = self.make_feed()
        MockFetcher.return_value.fetch.return_value = MagicMock()
        MockProcess.return_value.process.return_value = (0, {"new": 0, "updated": 2, "same": 10})

        feed.update_webfeed()

        MockWorker.assert_not_called()

    @patch("utils.feed_fetcher.FeedFetcherWorker")
    @patch("utils.feed_fetcher.ProcessFeed")
    @patch("utils.webfeed_fetcher.WebFeedFetcher")
    def test_failed_fetch_skips_processing(self, MockFetcher, MockProcess, MockWorker):
        feed = self.make_feed()
        MockFetcher.return_value.fetch.return_value = None

        feed.update_webfeed()

        MockProcess.assert_not_called()
        MockWorker.assert_not_called()


class Test_HashedUtilityClassXPaths(TestCase):
    """AbeBooks' hashed atomic-CSS classes (d_fc, d_fa, d_hr) churn on every site
    rebuild, so containers matched on them die at the next deploy. The July 19
    analyses produced d_hr containers that never extracted a story."""

    def test_hashed_atomic_class_is_degenerate(self):
        self.assertTrue(is_degenerate_container_xpath("//li[contains(@class, 'd_hr')]"))
        self.assertTrue(is_degenerate_container_xpath("//li[contains(@class, 'd_fc')]"))
        self.assertTrue(is_degenerate_container_xpath("//ul[@id='srp-results']/li[contains(@class, 'a_b1')]"))

    def test_semantic_tokens_are_fine(self):
        for xpath in [
            "//li[contains(@class, 'result-item')]",
            "//div[contains(@class, 'story_card')]",
            "//article[contains(@class, 'post')]",
        ]:
            self.assertFalse(is_degenerate_container_xpath(xpath), xpath)


class Test_EmptySearchResults(TestCase):
    """A results page that says the search matched nothing is a healthy feed with
    zero stories: it must not count toward reanalysis or flag exception 590."""

    def make_fetcher(self, html):
        from apps.rss_feeds.models import Feed

        feed = Feed(
            pk=202,
            feed_title="Empty search",
            feed_address="webfeed:https://example.com/search?q=rare",
            archive_subscribers=1,
        )
        config = MagicMock()
        config.story_container_xpath = "//li[contains(@class, 'result-item')]"
        with patch.object(MWebFeedConfig, "get_config", return_value=config):
            fetcher = WebFeedFetcher(feed)
        fetcher.config = config
        fetcher._fetch_html = lambda: html
        return fetcher, config, feed

    def test_no_results_page_records_success_not_failure(self):
        html = "<html><body><h2>No exact matches</h2><p>Try a new search.</p></body></html>"
        fetcher, config, feed = self.make_fetcher(html)
        feed.has_feed_exception = True
        feed.exception_code = 590
        with patch.object(type(feed), "save") as mock_save:
            result = fetcher.fetch()
        self.assertIsNone(result)
        config.record_success.assert_called_once()
        config.record_failure.assert_not_called()
        self.assertFalse(feed.has_feed_exception)
        mock_save.assert_called_once()

    def test_zero_extraction_without_marker_still_counts_as_failure(self):
        html = "<html><body><div class='totally-different-markup'>listings here</div></body></html>"
        fetcher, config, feed = self.make_fetcher(html)
        config.needs_reanalysis = False
        result = fetcher.fetch()
        self.assertIsNone(result)
        config.record_failure.assert_called_once()
        config.record_success.assert_not_called()


class Test_InitialFetchIsForced(TestCase):
    """The first fetch after subscribing must bypass the per-domain fetch budget:
    a deferred initial fetch leaves a brand-new feed empty for an hour or more on
    a saturated domain, which reads as a broken subscription."""

    @patch("apps.webfeed.tasks.redis.Redis")
    @patch("apps.webfeed.tasks.User")
    def test_fetch_webfeed_forces_update(self, MockUser, MockRedis):
        from apps.webfeed.tasks import FetchWebFeed

        feed = MagicMock()
        with patch("apps.rss_feeds.models.Feed.get_by_id", return_value=feed):
            FetchWebFeed(feed_id=101, user_id=1)
        feed.update.assert_called_once_with(force=True)
