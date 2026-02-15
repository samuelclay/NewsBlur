import datetime
import json as stdlib_json
from unittest.mock import MagicMock, call, patch

import pytz
from django.contrib.auth.models import User
from django.test import TestCase
from django.test.client import Client
from django.urls import reverse

from apps.analyzer.models import (
    MClassifierAuthor,
    MClassifierFeed,
    MClassifierTag,
    MClassifierTitle,
)
from apps.briefing.activity import RUserActivity
from apps.briefing.models import (
    BRIEFING_SECTION_DEFINITIONS,
    DEFAULT_SECTIONS,
    MAX_CUSTOM_SECTIONS,
    VALID_SECTION_KEYS,
    MBriefing,
    MBriefingPreferences,
)
from apps.briefing.scoring import (
    _estimate_word_count,
    _find_duplicate_stories,
    _get_classifier_matches,
    _normalize_title,
)
from apps.briefing.summary import (
    _build_system_prompt,
    extract_section_story_hashes,
    extract_section_summaries,
    filter_disabled_sections,
    normalize_section_key,
)
from apps.reader.models import UserSubscription
from apps.rss_feeds.models import Feed, MStory
from utils import json_functions as json


def _make_sample_html(sections_dict):
    """
    Build valid briefing HTML with <h3 data-section="KEY"> tags.
    sections_dict maps section_key -> list of (story_hash, title) tuples.
    """
    parts = []
    for key, stories in sections_dict.items():
        parts.append('<h3 data-section="%s">Section %s</h3>' % (key, key))
        parts.append("<ul>")
        for story_hash, title in stories:
            parts.append(
                '<li><a class="NB-briefing-story-link" data-story-hash="%s">%s</a></li>' % (story_hash, title)
            )
        parts.append("</ul>")
    return '<div class="NB-briefing-summary">%s</div>' % "".join(parts)


class BriefingTestCase(TestCase):
    """Base class with shared setUp/tearDown and factory helpers for briefing tests."""

    _story_counter = 0

    def setUp(self):
        self.client = Client()
        self.user = User.objects.create_user(
            username="brieftest", password="testpass", email="brief@test.com"
        )
        self.user.is_staff = True
        self.user.save()
        # tests.py: Set profile to archive tier with New York timezone
        profile = self.user.profile
        profile.is_archive = True
        profile.timezone = "America/New_York"
        profile.save()

        self.client.login(username="brieftest", password="testpass")

        self.feed = Feed.objects.create(
            feed_address="http://test-feed-1.com/rss",
            feed_link="http://test-feed-1.com",
            feed_title="Test Feed 1",
            fetched_once=True,
            known_good=True,
        )
        self.feed2 = Feed.objects.create(
            feed_address="http://test-feed-2.com/rss",
            feed_link="http://test-feed-2.com",
            feed_title="Test Feed 2",
            fetched_once=True,
            known_good=True,
        )
        self.sub = UserSubscription.objects.create(user=self.user, feed=self.feed, active=True)
        self.sub2 = UserSubscription.objects.create(user=self.user, feed=self.feed2, active=True)

        self.now = datetime.datetime.utcnow()
        self.period_start = self.now - datetime.timedelta(days=1)

        self.stories = []
        for i, (feed, title, author, word_count) in enumerate(
            [
                (self.feed, "Breaking News About Tech", "Alice", 200),
                (self.feed, "Sports Update Today", "Bob", 150),
                (self.feed, "Long Read About Science", "Charlie", 900),
                (self.feed2, "Breaking News About Tech", "Dave", 180),
                (self.feed2, "World Economy Report", "Eve", 400),
                (self.feed2, "Art and Culture Review", "Frank", 300),
            ]
        ):
            story = self.make_story(
                feed,
                title,
                content="word " * word_count,
                date=self.now - datetime.timedelta(hours=i + 1),
                author=author,
            )
            self.stories.append(story)

    def tearDown(self):
        MBriefing.objects(user_id=self.user.pk).delete()
        MBriefingPreferences.objects(user_id=self.user.pk).delete()
        MStory.objects(story_feed_id__in=[self.feed.pk, self.feed2.pk]).delete()
        MClassifierFeed.objects(user_id=self.user.pk).delete()
        MClassifierAuthor.objects(user_id=self.user.pk).delete()
        MClassifierTag.objects(user_id=self.user.pk).delete()
        MClassifierTitle.objects(user_id=self.user.pk).delete()

    def make_story(self, feed, title, content="Test content", date=None, author=None, tags=None):
        BriefingTestCase._story_counter += 1
        story = MStory(
            story_feed_id=feed.pk,
            story_date=date or self.now,
            story_title=title,
            story_content=content,
            story_author_name=author or "TestAuthor",
            story_permalink="http://test.com/%s" % title.replace(" ", "-").lower(),
            story_guid="guid-%s-%s-%s"
            % (feed.pk, title.replace(" ", "-").lower(), BriefingTestCase._story_counter),
            story_tags=tags or [],
        )
        story.save()
        return story

    def make_scored_stories(self, stories, categories=None):
        result = []
        for i, story in enumerate(stories):
            cat = "trending_global"
            if categories and i < len(categories):
                cat = categories[i]
            result.append(
                {
                    "story_hash": story.story_hash,
                    "score": 1.0 - (i * 0.1),
                    "is_read": False,
                    "category": cat,
                    "content_word_count": len((story.story_content or "").split()),
                    "classifier_matches": [],
                }
            )
        return result

    def make_briefing(self, summary_html=None, curated_hashes=None, status="complete", **kwargs):
        defaults = {
            "user_id": self.user.pk,
            "briefing_feed_id": self.feed.pk,
            "summary_story_hash": None,
            "curated_story_hashes": curated_hashes or [],
            "briefing_date": kwargs.pop("briefing_date", self.now),
            "period_start": kwargs.pop("period_start", self.period_start),
            "generated_at": datetime.datetime.utcnow(),
            "status": status,
        }
        defaults.update(kwargs)
        briefing = MBriefing(**defaults)
        briefing.save()
        return briefing

    def make_prefs(self, **overrides):
        defaults = {
            "user_id": self.user.pk,
            "frequency": "daily",
            "enabled": True,
            "story_count": 5,
            "summary_length": "medium",
            "summary_style": "bullets",
        }
        defaults.update(overrides)
        try:
            prefs = MBriefingPreferences.objects.get(user_id=self.user.pk)
            for k, v in defaults.items():
                setattr(prefs, k, v)
            prefs.save()
        except MBriefingPreferences.DoesNotExist:
            prefs = MBriefingPreferences(**defaults)
            prefs.save()
        return prefs


# ---------------------------------------------------------------------------
# 1. Test_Summary — apps/briefing/summary.py
# ---------------------------------------------------------------------------


class Test_Summary(TestCase):
    """Tests for pure functions in apps/briefing/summary.py."""

    # --- normalize_section_key ---

    def test_normalize_exact_match(self):
        self.assertEqual(normalize_section_key("trending_unread"), "trending_unread")

    def test_normalize_hyphenated(self):
        self.assertEqual(normalize_section_key("trending-unread"), "trending_unread")

    def test_normalize_uppercase(self):
        self.assertEqual(normalize_section_key("TRENDING_UNREAD"), "trending_unread")

    def test_normalize_extra_underscores(self):
        self.assertEqual(normalize_section_key("trending__unread"), "trending_unread")

    def test_normalize_leading_trailing(self):
        self.assertEqual(normalize_section_key("_trending_unread_"), "trending_unread")

    def test_normalize_fuzzy_no_separator(self):
        self.assertEqual(normalize_section_key("trendingunread"), "trending_unread")

    def test_normalize_invalid_returns_none(self):
        self.assertIsNone(normalize_section_key("bogus_key"))

    def test_normalize_empty_returns_none(self):
        self.assertIsNone(normalize_section_key(""))

    def test_normalize_none_returns_none(self):
        self.assertIsNone(normalize_section_key(None))

    def test_normalize_custom_keys(self):
        for i in range(1, 6):
            self.assertEqual(normalize_section_key("custom_%d" % i), "custom_%d" % i)

    def test_normalize_custom_hyphenated(self):
        self.assertEqual(normalize_section_key("custom-3"), "custom_3")

    def test_normalize_whitespace(self):
        self.assertEqual(normalize_section_key("  trending_unread  "), "trending_unread")

    # --- _build_system_prompt ---

    def test_prompt_default_sections(self):
        prompt = _build_system_prompt()
        self.assertIn("trending_unread", prompt)
        self.assertIn("long_read", prompt)
        self.assertIn("classifier_match", prompt)
        self.assertIn("follow_up", prompt)
        self.assertIn("trending_global", prompt)
        self.assertIn("duplicates", prompt)
        self.assertIn("quick_catchup", prompt)
        self.assertIn("emerging_topics", prompt)
        self.assertIn("contrarian_views", prompt)

    def test_prompt_all_enabled(self):
        all_enabled = {s["key"]: True for s in BRIEFING_SECTION_DEFINITIONS}
        prompt = _build_system_prompt(sections=all_enabled)
        # tests.py: Check all 9 section prompts appear. Some prompts use CATEGORY: key,
        # others (emerging_topics, contrarian_views) use their display name instead.
        for defn in BRIEFING_SECTION_DEFINITIONS:
            self.assertIn(defn["name"], prompt)

    def test_prompt_none_enabled(self):
        none_enabled = {s["key"]: False for s in BRIEFING_SECTION_DEFINITIONS}
        prompt = _build_system_prompt(sections=none_enabled)
        self.assertIn("Include all stories in a single section", prompt)

    def test_prompt_custom_sections(self):
        sections = dict(DEFAULT_SECTIONS)
        sections["custom_1"] = True
        prompt = _build_system_prompt(sections=sections, custom_section_prompts=["Trump news"])
        self.assertIn("custom_1", prompt)
        self.assertIn("Trump news", prompt)

    def test_prompt_custom_disabled(self):
        sections = dict(DEFAULT_SECTIONS)
        sections["custom_1"] = False
        prompt = _build_system_prompt(sections=sections, custom_section_prompts=["Trump news"])
        self.assertNotIn("custom_1", prompt)

    def test_prompt_length_short(self):
        prompt = _build_system_prompt(summary_length="short")
        self.assertIn("Under 300 words", prompt)

    def test_prompt_length_detailed(self):
        prompt = _build_system_prompt(summary_length="detailed")
        self.assertIn("Up to 1000 words", prompt)

    def test_prompt_style_editorial(self):
        prompt = _build_system_prompt(summary_style="editorial")
        self.assertIn("narrative editorial style", prompt)

    # --- extract_section_summaries ---

    def test_extract_basic(self):
        html = _make_sample_html(
            {
                "trending_unread": [("hash1", "Story 1")],
                "long_read": [("hash2", "Story 2")],
                "trending_global": [("hash3", "Story 3")],
            }
        )
        sections = extract_section_summaries(html)
        self.assertEqual(len(sections), 3)
        self.assertIn("trending_unread", sections)
        self.assertIn("long_read", sections)
        self.assertIn("trending_global", sections)
        for key, section_html in sections.items():
            self.assertIn('class="NB-briefing-summary"', section_html)

    def test_extract_empty_html(self):
        self.assertEqual(extract_section_summaries(""), {})

    def test_extract_none_html(self):
        self.assertEqual(extract_section_summaries(None), {})

    def test_extract_no_h3_tags(self):
        self.assertEqual(extract_section_summaries("<p>No sections here</p>"), {})

    def test_extract_normalizes_keys(self):
        html = '<div class="NB-briefing-summary"><h3 data-section="TRENDING-UNREAD">Test</h3><p>Content</p></div>'
        sections = extract_section_summaries(html)
        self.assertIn("trending_unread", sections)
        self.assertNotIn("TRENDING-UNREAD", sections)

    def test_extract_rejects_invalid_keys(self):
        html = '<div class="NB-briefing-summary"><h3 data-section="bogus_invalid_key">Test</h3><p>Content</p></div>'
        sections = extract_section_summaries(html)
        self.assertEqual(len(sections), 0)

    def test_extract_h3_extra_attributes(self):
        """Regression test: h3 with class before data-section should still parse."""
        html = (
            '<div class="NB-briefing-summary">'
            '<h3 class="some-class" data-section="trending_unread">Test</h3>'
            "<p>Content</p></div>"
        )
        sections = extract_section_summaries(html)
        self.assertIn("trending_unread", sections)

    def test_extract_h3_style_before_data_section(self):
        """Regression test: h3 with style before data-section should still parse."""
        html = (
            '<div class="NB-briefing-summary">'
            '<h3 style="color:red" data-section="long_read">Test</h3>'
            "<p>Content</p></div>"
        )
        sections = extract_section_summaries(html)
        self.assertIn("long_read", sections)

    # --- extract_section_story_hashes ---

    def test_hashes_basic(self):
        section_summaries = {
            "trending_unread": '<div><a data-story-hash="h1">S1</a><a data-story-hash="h2">S2</a></div>',
            "long_read": '<div><a data-story-hash="h3">S3</a></div>',
        }
        result = extract_section_story_hashes(section_summaries)
        self.assertEqual(result["trending_unread"], ["h1", "h2"])
        self.assertEqual(result["long_read"], ["h3"])

    def test_hashes_empty(self):
        self.assertEqual(extract_section_story_hashes({}), {})

    def test_hashes_none(self):
        self.assertEqual(extract_section_story_hashes(None), {})

    def test_hashes_no_links(self):
        section_summaries = {"trending_unread": "<div><p>No story links here</p></div>"}
        result = extract_section_story_hashes(section_summaries)
        self.assertNotIn("trending_unread", result)

    # --- filter_disabled_sections ---

    def test_filter_removes_disabled(self):
        html = _make_sample_html(
            {
                "trending_unread": [("h1", "S1")],
                "long_read": [("h2", "S2")],
                "trending_global": [("h3", "S3")],
            }
        )
        active = {"trending_unread": True, "long_read": False, "trending_global": True}
        result = filter_disabled_sections(html, active)
        self.assertIn("trending_unread", result)
        self.assertNotIn("long_read", result)
        self.assertIn("trending_global", result)

    def test_filter_keeps_trending_global_always(self):
        html = _make_sample_html({"trending_global": [("h1", "S1")]})
        active = {"trending_global": False}
        result = filter_disabled_sections(html, active)
        self.assertIn("trending_global", result)

    def test_filter_empty_html(self):
        self.assertEqual(filter_disabled_sections("", {"trending_unread": True}), "")

    def test_filter_none_html(self):
        self.assertIsNone(filter_disabled_sections(None, {"trending_unread": True}))

    def test_filter_none_active_sections(self):
        html = _make_sample_html({"trending_unread": [("h1", "S1")]})
        self.assertEqual(filter_disabled_sections(html, None), html)

    def test_filter_all_disabled(self):
        html = _make_sample_html(
            {
                "trending_unread": [("h1", "S1")],
                "long_read": [("h2", "S2")],
                "trending_global": [("h3", "S3")],
            }
        )
        active = {"trending_unread": False, "long_read": False, "trending_global": False}
        result = filter_disabled_sections(html, active)
        # tests.py: trending_global is always kept
        self.assertIn("trending_global", result)
        self.assertNotIn("trending_unread", result)
        self.assertNotIn("long_read", result)

    def test_filter_custom_enabled_kept(self):
        html = _make_sample_html(
            {
                "custom_1": [("h1", "Custom Story")],
                "trending_global": [("h2", "S2")],
            }
        )
        active = {"custom_1": True, "trending_global": True}
        result = filter_disabled_sections(html, active)
        self.assertIn("custom_1", result)

    def test_filter_custom_disabled_removed(self):
        html = _make_sample_html(
            {
                "custom_1": [("h1", "Custom Story")],
                "trending_global": [("h2", "S2")],
            }
        )
        active = {"custom_1": False, "trending_global": True}
        result = filter_disabled_sections(html, active)
        self.assertNotIn("custom_1", result)
        self.assertIn("trending_global", result)

    # --- generate_briefing_summary (mocked LLM) ---

    def _make_summary_story(self, feed, title, content, guid):
        """Create a story and return it with its actual computed story_hash."""
        story = MStory(
            story_feed_id=feed.pk,
            story_date=datetime.datetime.utcnow(),
            story_title=title,
            story_content=content,
            story_guid=guid,
        )
        story.save()
        # tests.py: story_hash is computed on save from feed_id + guid_hash
        return story

    def _scored_from_story(self, story, category="trending_global", word_count=200):
        return {
            "story_hash": story.story_hash,
            "score": 0.8,
            "is_read": False,
            "category": category,
            "content_word_count": word_count,
            "classifier_matches": [],
        }

    @patch("apps.briefing.summary.LLMCostTracker")
    @patch("apps.ask_ai.providers.get_briefing_provider")
    def test_summary_returns_html_and_metadata(self, mock_get_provider, mock_cost):
        from apps.briefing.summary import generate_briefing_summary

        mock_provider = MagicMock()
        mock_provider.is_configured.return_value = True
        mock_provider.generate.return_value = '<div class="NB-briefing-summary"><h3 data-section="trending_global">Trending</h3><p>Content</p></div>'
        mock_provider.get_last_usage.return_value = (100, 50)
        mock_get_provider.return_value = (mock_provider, "claude-haiku")

        feed = Feed.objects.create(
            feed_address="http://summary-test.com/rss",
            feed_link="http://summary-test.com",
            feed_title="Summary Test Feed",
        )
        story = self._make_summary_story(feed, "Test Story", "Some content here", "summary-test-guid")
        scored = [self._scored_from_story(story)]

        try:
            result = generate_briefing_summary(self.id(), scored, datetime.datetime.utcnow())
            self.assertIsNotNone(result)
            html, metadata = result
            self.assertIn("NB-briefing-summary", html)
            self.assertEqual(metadata["input_tokens"], 100)
            self.assertEqual(metadata["output_tokens"], 50)
        finally:
            MStory.objects(story_hash=story.story_hash).delete()
            feed.delete()

    @patch("apps.briefing.summary.LLMCostTracker")
    @patch("apps.ask_ai.providers.get_briefing_provider")
    def test_summary_strips_code_fences(self, mock_get_provider, mock_cost):
        from apps.briefing.summary import generate_briefing_summary

        mock_provider = MagicMock()
        mock_provider.is_configured.return_value = True
        mock_provider.generate.return_value = (
            '```html\n<div class="NB-briefing-summary"><p>Content</p></div>\n```'
        )
        mock_provider.get_last_usage.return_value = (100, 50)
        mock_get_provider.return_value = (mock_provider, "claude-haiku")

        feed = Feed.objects.create(
            feed_address="http://fence-test.com/rss",
            feed_link="http://fence-test.com",
            feed_title="Fence Test Feed",
        )
        story = self._make_summary_story(feed, "Fence Test", "Content", "fence-test-guid")
        scored = [self._scored_from_story(story)]

        try:
            html, metadata = generate_briefing_summary(self.id(), scored, datetime.datetime.utcnow())
            self.assertNotIn("```", html)
            self.assertTrue(html.startswith("<div"))
        finally:
            MStory.objects(story_hash=story.story_hash).delete()
            feed.delete()

    def test_summary_empty_stories_returns_none(self):
        from apps.briefing.summary import generate_briefing_summary

        result = generate_briefing_summary(999, [], datetime.datetime.utcnow())
        self.assertIsNone(result)

    @patch("apps.briefing.summary.LLMCostTracker")
    @patch("apps.ask_ai.providers.get_briefing_provider")
    @patch(
        "apps.ask_ai.providers.BRIEFING_MODELS",
        {"nondefault": {"vendor": "test"}, "haiku": {"vendor": "anthropic"}},
    )
    def test_summary_provider_fallback(self, mock_get_provider, mock_cost):
        from apps.briefing.summary import generate_briefing_summary

        unconfigured = MagicMock()
        unconfigured.is_configured.return_value = False
        configured = MagicMock()
        configured.is_configured.return_value = True
        configured.generate.return_value = "<div>Fallback</div>"
        configured.get_last_usage.return_value = (10, 5)

        mock_get_provider.side_effect = [
            (unconfigured, "model-a"),
            (configured, "model-b"),
        ]

        feed = Feed.objects.create(
            feed_address="http://fallback-test.com/rss",
            feed_link="http://fallback-test.com",
            feed_title="Fallback Feed",
        )
        story = self._make_summary_story(feed, "Fallback Story", "Content", "fallback-guid")
        scored = [self._scored_from_story(story)]

        try:
            result = generate_briefing_summary(
                self.id(), scored, datetime.datetime.utcnow(), model="nondefault"
            )
            self.assertIsNotNone(result)
        finally:
            MStory.objects(story_hash=story.story_hash).delete()
            feed.delete()

    @patch("apps.ask_ai.providers.get_briefing_provider")
    def test_summary_all_unconfigured_returns_none(self, mock_get_provider):
        from apps.briefing.summary import generate_briefing_summary

        unconfigured = MagicMock()
        unconfigured.is_configured.return_value = False
        mock_get_provider.return_value = (unconfigured, "model-a")

        feed = Feed.objects.create(
            feed_address="http://unconf-test.com/rss",
            feed_link="http://unconf-test.com",
            feed_title="Unconf Feed",
        )
        story = self._make_summary_story(feed, "Unconf Story", "Content", "unconf-guid")
        scored = [self._scored_from_story(story)]

        try:
            result = generate_briefing_summary(self.id(), scored, datetime.datetime.utcnow())
            self.assertIsNone(result)
        finally:
            MStory.objects(story_hash=story.story_hash).delete()
            feed.delete()

    @patch("apps.briefing.summary.LLMCostTracker")
    @patch("apps.ask_ai.providers.get_briefing_provider")
    def test_summary_llm_exception_returns_none(self, mock_get_provider, mock_cost):
        import anthropic

        from apps.briefing.summary import generate_briefing_summary

        mock_provider = MagicMock()
        mock_provider.is_configured.return_value = True
        mock_provider.generate.side_effect = anthropic.APIConnectionError(request=MagicMock())
        mock_get_provider.return_value = (mock_provider, "claude-haiku")

        feed = Feed.objects.create(
            feed_address="http://err-test.com/rss",
            feed_link="http://err-test.com",
            feed_title="Error Feed",
        )
        story = self._make_summary_story(feed, "Error Story", "Content", "err-guid")
        scored = [self._scored_from_story(story)]

        try:
            result = generate_briefing_summary(self.id(), scored, datetime.datetime.utcnow())
            html, meta = result
            self.assertIsNone(html)
            self.assertIsNone(meta)
        finally:
            MStory.objects(story_hash=story.story_hash).delete()
            feed.delete()

    @patch("apps.briefing.summary.LLMCostTracker")
    @patch("apps.ask_ai.providers.get_briefing_provider")
    def test_summary_category_remapping(self, mock_get_provider, mock_cost):
        """Regression test: disabled section categories should become trending_global in LLM data."""
        from apps.briefing.summary import generate_briefing_summary

        mock_provider = MagicMock()
        mock_provider.is_configured.return_value = True
        mock_provider.generate.return_value = "<div>Result</div>"
        mock_provider.get_last_usage.return_value = (100, 50)
        mock_get_provider.return_value = (mock_provider, "claude-haiku")

        feed = Feed.objects.create(
            feed_address="http://remap-test.com/rss",
            feed_link="http://remap-test.com",
            feed_title="Remap Feed",
        )
        story = self._make_summary_story(feed, "Remap Story", "Content here", "remap-guid")
        scored = [self._scored_from_story(story, category="long_read", word_count=900)]

        try:
            sections = dict(DEFAULT_SECTIONS)
            sections["long_read"] = False
            generate_briefing_summary(
                self.id(),
                scored,
                datetime.datetime.utcnow(),
                sections=sections,
            )
            # tests.py: Check the user prompt sent to the LLM has trending_global not long_read
            call_args = mock_provider.generate.call_args
            self.assertIsNotNone(call_args, "provider.generate was never called")
            messages = call_args[0][0]
            user_msg = messages[1]["content"]
            self.assertIn("CATEGORY: trending_global", user_msg)
            self.assertNotIn("CATEGORY: long_read", user_msg)
        finally:
            MStory.objects(story_hash=story.story_hash).delete()
            feed.delete()

    # --- embed_briefing_icons ---

    def test_embed_none_html(self):
        from apps.briefing.summary import embed_briefing_icons

        result = embed_briefing_icons(None, [])
        self.assertIsNone(result)


# ---------------------------------------------------------------------------
# 2. Test_Scoring — apps/briefing/scoring.py
# ---------------------------------------------------------------------------


class Test_Scoring(BriefingTestCase):
    """Tests for apps/briefing/scoring.py."""

    # --- Pure helpers ---

    def test_normalize_title(self):
        self.assertEqual(_normalize_title("  Breaking News!  "), "breaking news")

    def test_normalize_title_empty(self):
        self.assertEqual(_normalize_title(""), "")

    def test_normalize_title_none(self):
        self.assertEqual(_normalize_title(None), "")

    def test_find_duplicates_basic(self):
        """Same title across 2 feeds should mark both as duplicates."""
        candidates = [
            {"story_hash": self.stories[0].story_hash, "feed_id": self.feed.pk},
            {"story_hash": self.stories[3].story_hash, "feed_id": self.feed2.pk},
        ]
        stories_by_hash = {s.story_hash: s for s in [self.stories[0], self.stories[3]]}
        dupes = _find_duplicate_stories(candidates, stories_by_hash)
        self.assertIn(self.stories[0].story_hash, dupes)
        self.assertIn(self.stories[3].story_hash, dupes)

    def test_find_duplicates_same_feed(self):
        """Same title in same feed should NOT be marked duplicate."""
        dup_story = self.make_story(self.feed, "Breaking News About Tech", content="Other content")
        candidates = [
            {"story_hash": self.stories[0].story_hash, "feed_id": self.feed.pk},
            {"story_hash": dup_story.story_hash, "feed_id": self.feed.pk},
        ]
        stories_by_hash = {s.story_hash: s for s in [self.stories[0], dup_story]}
        dupes = _find_duplicate_stories(candidates, stories_by_hash)
        self.assertEqual(len(dupes), 0)

    def test_find_duplicates_short_title(self):
        """Titles shorter than 10 chars after normalization should be ignored."""
        short1 = self.make_story(self.feed, "Hi")
        short2 = self.make_story(self.feed2, "Hi")
        candidates = [
            {"story_hash": short1.story_hash, "feed_id": self.feed.pk},
            {"story_hash": short2.story_hash, "feed_id": self.feed2.pk},
        ]
        stories_by_hash = {s.story_hash: s for s in [short1, short2]}
        dupes = _find_duplicate_stories(candidates, stories_by_hash)
        self.assertEqual(len(dupes), 0)

    def test_estimate_word_count(self):
        story = self.stories[0]
        count = _estimate_word_count(story)
        self.assertGreater(count, 100)

    def test_estimate_word_count_empty(self):
        story = self.make_story(self.feed, "Empty Story", content="")
        count = _estimate_word_count(story)
        self.assertEqual(count, 0)

    def test_classifier_matches_feed(self):
        cf = MClassifierFeed(user_id=self.user.pk, feed_id=self.feed.pk, social_user_id=0, score=1)
        cf.save()
        feed_title_map = {self.feed.pk: "Test Feed 1"}
        matches = _get_classifier_matches(self.stories[0], [cf], [], [], [], feed_title_map)
        self.assertIn("feed:Test Feed 1", matches)

    def test_classifier_matches_multiple(self):
        cf = MClassifierFeed(user_id=self.user.pk, feed_id=self.feed.pk, social_user_id=0, score=1)
        cf.save()
        ca = MClassifierAuthor(
            user_id=self.user.pk, author="Alice", feed_id=self.feed.pk, social_user_id=0, score=1
        )
        ca.save()
        feed_title_map = {self.feed.pk: "Test Feed 1"}
        matches = _get_classifier_matches(self.stories[0], [cf], [ca], [], [], feed_title_map)
        self.assertIn("feed:Test Feed 1", matches)
        self.assertIn("author:Alice", matches)

    # --- select_briefing_stories (mocked Redis) ---

    @patch("apps.briefing.scoring.redis.Redis")
    def test_select_empty_no_subs(self, mock_redis_cls):
        from apps.briefing.scoring import select_briefing_stories

        # tests.py: Use a user with no subscriptions
        user2 = User.objects.create_user(username="nosubs", password="testpass")
        result = select_briefing_stories(user2.pk, self.period_start, self.now)
        self.assertEqual(result, [])

    @patch("apps.briefing.scoring._get_feed_trending_times")
    @patch("apps.briefing.scoring._get_trending_scores")
    @patch("apps.briefing.scoring.redis.Redis")
    def test_select_empty_no_candidates(self, mock_redis_cls, mock_trending, mock_feed_trending):
        from apps.briefing.scoring import select_briefing_stories

        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_pipe = MagicMock()
        mock_r.pipeline.return_value = mock_pipe
        mock_pipe.execute.return_value = [[] for _ in range(2)]

        result = select_briefing_stories(self.user.pk, self.period_start, self.now)
        self.assertEqual(result, [])

    @patch("apps.briefing.scoring._get_feed_trending_times")
    @patch("apps.briefing.scoring._get_trending_scores")
    @patch("apps.briefing.scoring.redis.Redis")
    def test_select_basic_sorted_by_score(self, mock_redis_cls, mock_trending, mock_feed_trending):
        from apps.briefing.scoring import select_briefing_stories

        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_pipe = MagicMock()
        mock_r.pipeline.return_value = mock_pipe

        hashes = [s.story_hash.encode() for s in self.stories[:3]]
        mock_pipe.execute.side_effect = [
            [hashes[:2], [hashes[2]]],
            [False, False, False],
        ]
        mock_trending.return_value = {
            self.stories[0].story_hash: 100,
            self.stories[1].story_hash: 50,
            self.stories[2].story_hash: 10,
        }
        mock_feed_trending.return_value = {}

        result = select_briefing_stories(self.user.pk, self.period_start, self.now, max_stories=3)
        self.assertGreater(len(result), 0)
        scores = [s["score"] for s in result]
        self.assertEqual(scores, sorted(scores, reverse=True))

    @patch("apps.briefing.scoring._get_feed_trending_times")
    @patch("apps.briefing.scoring._get_trending_scores")
    @patch("apps.briefing.scoring.redis.Redis")
    def test_select_max_stories_limit(self, mock_redis_cls, mock_trending, mock_feed_trending):
        from apps.briefing.scoring import select_briefing_stories

        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_pipe = MagicMock()
        mock_r.pipeline.return_value = mock_pipe

        all_hashes = [s.story_hash.encode() for s in self.stories]
        mock_pipe.execute.side_effect = [
            [all_hashes[:3], all_hashes[3:]],
            [False] * 6,
        ]
        mock_trending.return_value = {}
        mock_feed_trending.return_value = {}

        result = select_briefing_stories(self.user.pk, self.period_start, self.now, max_stories=2)
        self.assertLessEqual(len(result), 2)

    @patch("apps.briefing.scoring._get_feed_trending_times")
    @patch("apps.briefing.scoring._get_trending_scores")
    @patch("apps.briefing.scoring.redis.Redis")
    def test_select_max_per_feed(self, mock_redis_cls, mock_trending, mock_feed_trending):
        from apps.briefing.scoring import select_briefing_stories

        # tests.py: Create 5 stories in one feed to test the max 3 per feed cap
        extra_stories = []
        for i in range(5):
            extra_stories.append(
                self.make_story(self.feed, "Extra Story %d in Feed 1" % i, content="word " * 100)
            )

        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_pipe = MagicMock()
        mock_r.pipeline.return_value = mock_pipe

        all_hashes = [s.story_hash.encode() for s in extra_stories]
        mock_pipe.execute.side_effect = [
            [all_hashes, []],
            [False] * len(all_hashes),
        ]
        trending_map = {s.story_hash: 100 - i for i, s in enumerate(extra_stories)}
        mock_trending.return_value = trending_map
        mock_feed_trending.return_value = {}

        result = select_briefing_stories(self.user.pk, self.period_start, self.now, max_stories=10)
        feed1_count = sum(1 for s in result if s["story_hash"].startswith("%s:" % self.feed.pk))
        self.assertLessEqual(feed1_count, 3)

    @patch("apps.briefing.scoring._get_feed_trending_times")
    @patch("apps.briefing.scoring._get_trending_scores")
    @patch("apps.briefing.scoring.redis.Redis")
    def test_select_unread_preferred(self, mock_redis_cls, mock_trending, mock_feed_trending):
        from apps.briefing.scoring import select_briefing_stories

        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_pipe = MagicMock()
        mock_r.pipeline.return_value = mock_pipe

        all_hashes = [s.story_hash.encode() for s in self.stories]
        # tests.py: Mark first 3 as read, last 3 as unread
        read_results = [True, True, True, False, False, False]
        mock_pipe.execute.side_effect = [
            [all_hashes[:3], all_hashes[3:]],
            read_results,
        ]
        mock_trending.return_value = {}
        mock_feed_trending.return_value = {}

        result = select_briefing_stories(self.user.pk, self.period_start, self.now, max_stories=5)
        # tests.py: With 3 unread stories (>= 3 threshold), all should be unread
        for s in result:
            self.assertFalse(s["is_read"])

    @patch("apps.briefing.scoring._get_feed_trending_times")
    @patch("apps.briefing.scoring._get_trending_scores")
    @patch("apps.briefing.scoring.redis.Redis")
    def test_select_fallback_to_read(self, mock_redis_cls, mock_trending, mock_feed_trending):
        from apps.briefing.scoring import select_briefing_stories

        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_pipe = MagicMock()
        mock_r.pipeline.return_value = mock_pipe

        all_hashes = [s.story_hash.encode() for s in self.stories]
        # tests.py: Mark all but 1 as read to trigger fallback
        read_results = [True, True, True, True, True, False]
        mock_pipe.execute.side_effect = [
            [all_hashes[:3], all_hashes[3:]],
            read_results,
        ]
        mock_trending.return_value = {}
        mock_feed_trending.return_value = {}

        result = select_briefing_stories(self.user.pk, self.period_start, self.now, max_stories=5)
        # tests.py: With only 1 unread (< 3 threshold), read stories should be included
        has_read = any(s["is_read"] for s in result)
        self.assertTrue(has_read)

    @patch("apps.briefing.scoring._get_feed_trending_times")
    @patch("apps.briefing.scoring._get_trending_scores")
    @patch("apps.briefing.scoring.redis.Redis")
    def test_select_category_long_read(self, mock_redis_cls, mock_trending, mock_feed_trending):
        from apps.briefing.scoring import select_briefing_stories

        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_pipe = MagicMock()
        mock_r.pipeline.return_value = mock_pipe

        # tests.py: stories[2] has 900 words — should be categorized as long_read
        long_story = self.stories[2]
        mock_pipe.execute.side_effect = [
            [[long_story.story_hash.encode()], []],
            [False],
        ]
        mock_trending.return_value = {}
        mock_feed_trending.return_value = {}

        result = select_briefing_stories(self.user.pk, self.period_start, self.now, max_stories=5)
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]["category"], "long_read")

    @patch("apps.briefing.scoring._get_feed_trending_times")
    @patch("apps.briefing.scoring._get_trending_scores")
    @patch("apps.briefing.scoring.redis.Redis")
    def test_select_category_trending_global(self, mock_redis_cls, mock_trending, mock_feed_trending):
        from apps.briefing.scoring import select_briefing_stories

        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_pipe = MagicMock()
        mock_r.pipeline.return_value = mock_pipe

        short_story = self.stories[1]
        mock_pipe.execute.side_effect = [
            [[short_story.story_hash.encode()], []],
            [False],
        ]
        mock_trending.return_value = {}
        mock_feed_trending.return_value = {}

        result = select_briefing_stories(self.user.pk, self.period_start, self.now, max_stories=5)
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]["category"], "trending_global")

    @patch("apps.briefing.scoring._get_feed_trending_times")
    @patch("apps.briefing.scoring._get_trending_scores")
    @patch("apps.briefing.scoring.redis.Redis")
    def test_select_focus_mode(self, mock_redis_cls, mock_trending, mock_feed_trending):
        from apps.briefing.scoring import select_briefing_stories

        # tests.py: Set up positive classifier for feed1 only
        cf = MClassifierFeed(user_id=self.user.pk, feed_id=self.feed.pk, social_user_id=0, score=1)
        cf.save()

        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_pipe = MagicMock()
        mock_r.pipeline.return_value = mock_pipe

        # tests.py: Only feed1 hashes should be queried in focus mode
        feed1_hashes = [s.story_hash.encode() for s in self.stories[:3]]
        mock_pipe.execute.side_effect = [
            [feed1_hashes],
            [False] * 3,
        ]
        mock_trending.return_value = {}
        mock_feed_trending.return_value = {}

        result = select_briefing_stories(
            self.user.pk,
            self.period_start,
            self.now,
            max_stories=5,
            read_filter="focus",
        )
        # tests.py: All results should be from feed1 only
        for s in result:
            story = MStory.objects.get(story_hash=s["story_hash"])
            self.assertEqual(story.story_feed_id, self.feed.pk)


# ---------------------------------------------------------------------------
# 3. Test_Models — apps/briefing/models.py
# ---------------------------------------------------------------------------


class Test_Models(BriefingTestCase):
    """Tests for apps/briefing/models.py."""

    # --- Constants ---

    def test_valid_section_keys_count(self):
        self.assertEqual(len(VALID_SECTION_KEYS), 14)

    def test_default_sections_values(self):
        self.assertTrue(DEFAULT_SECTIONS["trending_unread"])
        self.assertTrue(DEFAULT_SECTIONS["long_read"])
        self.assertTrue(DEFAULT_SECTIONS["classifier_match"])
        self.assertTrue(DEFAULT_SECTIONS["follow_up"])
        self.assertTrue(DEFAULT_SECTIONS["trending_global"])
        self.assertTrue(DEFAULT_SECTIONS["duplicates"])
        self.assertTrue(DEFAULT_SECTIONS["quick_catchup"])
        self.assertTrue(DEFAULT_SECTIONS["emerging_topics"])
        self.assertTrue(DEFAULT_SECTIONS["contrarian_views"])

    def test_max_custom_sections(self):
        self.assertEqual(MAX_CUSTOM_SECTIONS, 5)

    # --- MBriefing ---

    def test_create_and_retrieve(self):
        briefing = self.make_briefing(
            curated_hashes=["h1", "h2"],
            curated_sections={"trending_global": ["h1", "h2"]},
            section_summaries={"trending_global": "<div>Summary</div>"},
        )
        retrieved = MBriefing.objects.get(id=briefing.id)
        self.assertEqual(retrieved.user_id, self.user.pk)
        self.assertEqual(retrieved.curated_story_hashes, ["h1", "h2"])
        self.assertEqual(retrieved.curated_sections["trending_global"], ["h1", "h2"])

    def test_latest_for_user(self):
        self.make_briefing(briefing_date=self.now - datetime.timedelta(days=2))
        self.make_briefing(briefing_date=self.now - datetime.timedelta(days=1))
        self.make_briefing(briefing_date=self.now, status="failed")

        results = list(MBriefing.latest_for_user(self.user.pk, limit=10))
        # tests.py: Only "complete" briefings should be returned
        self.assertEqual(len(results), 2)
        # tests.py: Should be ordered by date desc
        self.assertGreater(results[0].briefing_date, results[1].briefing_date)

    def test_latest_for_user_empty(self):
        results = list(MBriefing.latest_for_user(self.user.pk))
        self.assertEqual(len(results), 0)

    def test_exists_for_period_true(self):
        self.make_briefing(briefing_date=self.now)
        self.assertTrue(
            MBriefing.exists_for_period(
                self.user.pk,
                self.now - datetime.timedelta(hours=1),
                self.now + datetime.timedelta(hours=1),
            )
        )

    def test_exists_for_period_false(self):
        self.assertFalse(
            MBriefing.exists_for_period(
                self.user.pk,
                self.now - datetime.timedelta(hours=1),
                self.now + datetime.timedelta(hours=1),
            )
        )

    # --- MBriefingPreferences ---

    def test_get_or_create_new(self):
        prefs = MBriefingPreferences.get_or_create(self.user.pk)
        self.assertEqual(prefs.user_id, self.user.pk)
        self.assertEqual(prefs.frequency, "daily")

    def test_get_or_create_existing(self):
        prefs1 = MBriefingPreferences.get_or_create(self.user.pk)
        prefs2 = MBriefingPreferences.get_or_create(self.user.pk)
        self.assertEqual(prefs1.id, prefs2.id)

    def test_default_values(self):
        prefs = MBriefingPreferences.get_or_create(self.user.pk)
        self.assertEqual(prefs.frequency, "daily")
        self.assertFalse(prefs.enabled)
        self.assertEqual(prefs.story_count, 5)

    # --- ensure_briefing_feed ---

    @patch("apps.briefing.models.redis.Redis")
    def test_creates_new_feed(self, mock_redis_cls):
        from apps.briefing.models import ensure_briefing_feed

        mock_redis_cls.return_value = MagicMock()
        feed = ensure_briefing_feed(self.user)
        self.assertEqual(feed.feed_address, "daily-briefing:%s" % self.user.pk)
        self.assertEqual(feed.feed_title, "Daily Briefing")

    @patch("apps.briefing.models.redis.Redis")
    def test_ensure_briefing_feed_idempotent(self, mock_redis_cls):
        from apps.briefing.models import ensure_briefing_feed

        mock_redis_cls.return_value = MagicMock()
        feed1 = ensure_briefing_feed(self.user)
        feed2 = ensure_briefing_feed(self.user)
        self.assertEqual(feed1.pk, feed2.pk)

    @patch("apps.briefing.models.redis.Redis")
    def test_creates_subscription(self, mock_redis_cls):
        from apps.briefing.models import ensure_briefing_feed

        mock_redis_cls.return_value = MagicMock()
        feed = ensure_briefing_feed(self.user)
        self.assertTrue(UserSubscription.objects.filter(user=self.user, feed=feed).exists())

    @patch("apps.briefing.models.redis.Redis")
    def test_updates_prefs_feed_id(self, mock_redis_cls):
        from apps.briefing.models import ensure_briefing_feed

        mock_redis_cls.return_value = MagicMock()
        feed = ensure_briefing_feed(self.user)
        prefs = MBriefingPreferences.get_or_create(self.user.pk)
        self.assertEqual(prefs.briefing_feed_id, feed.pk)

    # --- create_briefing_story ---

    @patch("apps.notifications.tasks.QueueNotifications")
    @patch("apps.notifications.models.MUserFeedNotification")
    @patch("apps.briefing.models.redis.Redis")
    def test_creates_new_story_and_briefing(self, mock_redis_cls, mock_notif, mock_queue):
        from apps.briefing.models import create_briefing_story

        mock_redis_cls.return_value = MagicMock()
        mock_notif.feed_has_users.return_value = 0

        briefing, story = create_briefing_story(
            self.feed,
            self.user,
            "<div>Summary</div>",
            self.now,
            ["h1", "h2"],
        )
        self.assertEqual(briefing.status, "complete")
        self.assertEqual(briefing.curated_story_hashes, ["h1", "h2"])
        self.assertIn("Daily Briefing", story.story_title)
        MStory.objects(story_hash=story.story_hash).delete()

    @patch("apps.notifications.tasks.QueueNotifications")
    @patch("apps.notifications.models.MUserFeedNotification")
    @patch("apps.briefing.models.redis.Redis")
    def test_morning_afternoon_evening_titles(self, mock_redis_cls, mock_notif, mock_queue):
        from apps.briefing.models import create_briefing_story

        mock_redis_cls.return_value = MagicMock()
        mock_notif.feed_has_users.return_value = 0

        tz = pytz.timezone("America/New_York")
        # tests.py: Test morning (6 AM ET = 11 AM UTC in winter)
        morning_utc = (
            tz.localize(datetime.datetime(2025, 1, 15, 6, 0)).astimezone(pytz.utc).replace(tzinfo=None)
        )
        briefing, story = create_briefing_story(self.feed, self.user, "<div>AM</div>", morning_utc, [])
        self.assertTrue(story.story_title.startswith("Morning"))
        MStory.objects(story_hash=story.story_hash).delete()

        # tests.py: Test afternoon (2 PM ET = 7 PM UTC in winter)
        afternoon_utc = (
            tz.localize(datetime.datetime(2025, 1, 15, 14, 0)).astimezone(pytz.utc).replace(tzinfo=None)
        )
        briefing2, story2 = create_briefing_story(self.feed, self.user, "<div>PM</div>", afternoon_utc, [])
        self.assertTrue(story2.story_title.startswith("Afternoon"))
        MStory.objects(story_hash=story2.story_hash).delete()

        # tests.py: Test evening (8 PM ET = 1 AM UTC next day in winter)
        evening_utc = (
            tz.localize(datetime.datetime(2025, 1, 15, 20, 0)).astimezone(pytz.utc).replace(tzinfo=None)
        )
        briefing3, story3 = create_briefing_story(self.feed, self.user, "<div>Eve</div>", evening_utc, [])
        self.assertTrue(story3.story_title.startswith("Evening"))
        MStory.objects(story_hash=story3.story_hash).delete()

    @patch("apps.notifications.tasks.QueueNotifications")
    @patch("apps.notifications.models.MUserFeedNotification")
    @patch("apps.briefing.models.redis.Redis")
    def test_sets_needs_unread_recalc(self, mock_redis_cls, mock_notif, mock_queue):
        from apps.briefing.models import create_briefing_story

        mock_redis_cls.return_value = MagicMock()
        mock_notif.feed_has_users.return_value = 0

        self.sub.needs_unread_recalc = False
        self.sub.save()

        create_briefing_story(self.feed, self.user, "<div>S</div>", self.now, [])
        self.sub.refresh_from_db()
        self.assertTrue(self.sub.needs_unread_recalc)
        MStory.objects(story_feed_id=self.feed.pk, story_author_name="NewsBlur").delete()


# ---------------------------------------------------------------------------
# 4. Test_Views — apps/briefing/views.py
# ---------------------------------------------------------------------------


class Test_Views(BriefingTestCase):
    """Tests for apps/briefing/views.py."""

    # --- load_briefing_stories ---

    def test_load_requires_staff(self):
        non_staff = User.objects.create_user(username="nostaff", password="testpass")
        c = Client()
        c.login(username="nostaff", password="testpass")
        response = c.get(reverse("load-briefing-stories"))
        data = json.decode(response.content)
        self.assertEqual(data["code"], -1)

    @patch("apps.briefing.views.redis.Redis")
    def test_load_empty_briefings(self, mock_redis_cls):
        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_pipe = MagicMock()
        mock_r.pipeline.return_value = mock_pipe
        mock_pipe.execute.return_value = []

        response = self.client.get(reverse("load-briefing-stories"))
        data = json.decode(response.content)
        self.assertEqual(data["briefings"], [])

    @patch("apps.briefing.views.redis.Redis")
    def test_load_returns_summary_story(self, mock_redis_cls):
        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_pipe = MagicMock()
        mock_r.pipeline.return_value = mock_pipe
        mock_pipe.execute.return_value = [False]

        story = self.make_story(self.feed, "Briefing Summary", content="<div>Summary content</div>")
        self.make_briefing(summary_story_hash=story.story_hash, curated_hashes=[story.story_hash])

        response = self.client.get(reverse("load-briefing-stories"))
        data = json.decode(response.content)
        self.assertEqual(len(data["briefings"]), 1)
        self.assertIsNotNone(data["briefings"][0]["summary_story"])
        self.assertEqual(data["briefings"][0]["summary_story"]["story_title"], "Briefing Summary")

    @patch("apps.briefing.views.redis.Redis")
    def test_non_premium_truncates(self, mock_redis_cls):
        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_pipe = MagicMock()
        mock_r.pipeline.return_value = mock_pipe
        mock_pipe.execute.return_value = [False] * 6

        # tests.py: Set user as non-premium
        profile = self.user.profile
        profile.is_archive = False
        profile.is_pro = False
        profile.save()

        hashes = [s.story_hash for s in self.stories]
        self.make_briefing(curated_hashes=hashes)

        response = self.client.get(reverse("load-briefing-stories"))
        data = json.decode(response.content)
        self.assertTrue(data["is_preview"])
        self.assertLessEqual(len(data["briefings"][0]["curated_story_hashes"]), 3)

    @patch("apps.briefing.views.redis.Redis")
    def test_premium_gets_all(self, mock_redis_cls):
        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_pipe = MagicMock()
        mock_r.pipeline.return_value = mock_pipe
        mock_pipe.execute.return_value = [False] * 7

        hashes = [s.story_hash for s in self.stories]
        self.make_briefing(curated_hashes=hashes)

        response = self.client.get(reverse("load-briefing-stories"))
        data = json.decode(response.content)
        self.assertFalse(data["is_preview"])
        self.assertEqual(len(data["briefings"][0]["curated_story_hashes"]), 6)

    @patch("apps.briefing.views.redis.Redis")
    def test_normalizes_section_keys(self, mock_redis_cls):
        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_pipe = MagicMock()
        mock_r.pipeline.return_value = mock_pipe
        mock_pipe.execute.return_value = [False]

        # tests.py: Store legacy hyphenated keys in the briefing
        self.make_briefing(
            curated_sections={"trending-unread": ["h1"]},
            section_summaries={"trending-unread": "<div>Test</div>"},
        )

        response = self.client.get(reverse("load-briefing-stories"))
        data = json.decode(response.content)
        b = data["briefings"][0]
        self.assertIn("trending_unread", b["curated_sections"])
        self.assertNotIn("trending-unread", b["curated_sections"])

    @patch("apps.briefing.views.redis.Redis")
    def test_includes_preferences_when_not_enabled(self, mock_redis_cls):
        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_pipe = MagicMock()
        mock_r.pipeline.return_value = mock_pipe
        mock_pipe.execute.return_value = []

        # tests.py: Make sure prefs are not enabled and no briefings exist
        self.make_prefs(enabled=False)

        response = self.client.get(reverse("load-briefing-stories"))
        data = json.decode(response.content)
        self.assertIn("preferences", data)
        self.assertIn("frequency", data["preferences"])

    # --- briefing_preferences ---

    def test_get_returns_defaults(self):
        response = self.client.get(reverse("briefing-preferences"))
        data = json.decode(response.content)
        self.assertEqual(data["frequency"], "daily")
        self.assertIn("sections", data)

    def test_post_frequency(self):
        self.make_prefs()
        response = self.client.post(reverse("briefing-preferences"), {"frequency": "weekly"})
        data = json.decode(response.content)
        self.assertEqual(data["frequency"], "weekly")

    def test_post_invalid_frequency_ignored(self):
        self.make_prefs()
        response = self.client.post(reverse("briefing-preferences"), {"frequency": "hourly"})
        data = json.decode(response.content)
        self.assertEqual(data["frequency"], "daily")

    def test_post_preferred_time_morning(self):
        self.make_prefs()
        response = self.client.post(reverse("briefing-preferences"), {"preferred_time": "morning"})
        data = json.decode(response.content)
        self.assertEqual(data["preferred_time"], "morning")
        prefs = MBriefingPreferences.objects.get(user_id=self.user.pk)
        self.assertEqual(prefs.preferred_time, "08:00")

    def test_post_preferred_time_auto(self):
        self.make_prefs(preferred_time="08:00")
        response = self.client.post(reverse("briefing-preferences"), {"preferred_time": "auto"})
        data = json.decode(response.content)
        self.assertEqual(data["preferred_time"], "morning")
        prefs = MBriefingPreferences.objects.get(user_id=self.user.pk)
        self.assertIsNone(prefs.preferred_time)

    def test_post_preferred_time_custom(self):
        self.make_prefs()
        response = self.client.post(reverse("briefing-preferences"), {"preferred_time": "14:30"})
        prefs = MBriefingPreferences.objects.get(user_id=self.user.pk)
        self.assertEqual(prefs.preferred_time, "14:30")

    def test_post_enabled(self):
        self.make_prefs(enabled=False)
        response = self.client.post(reverse("briefing-preferences"), {"enabled": "true"})
        data = json.decode(response.content)
        self.assertTrue(data["enabled"])

    def test_post_story_count_valid(self):
        self.make_prefs()
        response = self.client.post(reverse("briefing-preferences"), {"story_count": "10"})
        data = json.decode(response.content)
        self.assertEqual(data["story_count"], 10)

    def test_post_story_count_invalid(self):
        self.make_prefs(story_count=5)
        response = self.client.post(reverse("briefing-preferences"), {"story_count": "7"})
        data = json.decode(response.content)
        self.assertEqual(data["story_count"], 5)

    def test_post_sections_json(self):
        self.make_prefs()
        sections = {"trending_unread": True, "long_read": False, "bogus_key": True}
        response = self.client.post(
            reverse("briefing-preferences"),
            {"sections": stdlib_json.dumps(sections)},
        )
        prefs = MBriefingPreferences.objects.get(user_id=self.user.pk)
        self.assertTrue(prefs.sections["trending_unread"])
        self.assertFalse(prefs.sections["long_read"])
        self.assertNotIn("bogus_key", prefs.sections)

    def test_post_sections_invalid_json(self):
        self.make_prefs(sections={"trending_unread": True})
        response = self.client.post(
            reverse("briefing-preferences"),
            {"sections": "not-json"},
        )
        prefs = MBriefingPreferences.objects.get(user_id=self.user.pk)
        self.assertTrue(prefs.sections["trending_unread"])

    def test_post_custom_prompts(self):
        self.make_prefs()
        prompts = ["Trump news", "AI developments", "Sports scores"]
        response = self.client.post(
            reverse("briefing-preferences"),
            {"custom_section_prompts": stdlib_json.dumps(prompts)},
        )
        prefs = MBriefingPreferences.objects.get(user_id=self.user.pk)
        self.assertEqual(len(prefs.custom_section_prompts), 3)
        self.assertEqual(prefs.custom_section_prompts[0], "Trump news")

    def test_post_custom_prompts_empty_filtered(self):
        self.make_prefs()
        prompts = ["Trump news", "", "  ", "AI developments"]
        response = self.client.post(
            reverse("briefing-preferences"),
            {"custom_section_prompts": stdlib_json.dumps(prompts)},
        )
        prefs = MBriefingPreferences.objects.get(user_id=self.user.pk)
        self.assertEqual(len(prefs.custom_section_prompts), 2)

    @patch("apps.ask_ai.providers.VALID_BRIEFING_MODELS", ["haiku", "sonnet", "gemini"])
    def test_post_briefing_model_valid(self):
        self.make_prefs()
        response = self.client.post(reverse("briefing-preferences"), {"briefing_model": "haiku"})
        prefs = MBriefingPreferences.objects.get(user_id=self.user.pk)
        self.assertEqual(prefs.briefing_model, "haiku")

    def test_post_briefing_model_default_clears(self):
        self.make_prefs(briefing_model="haiku")
        response = self.client.post(reverse("briefing-preferences"), {"briefing_model": "default"})
        prefs = MBriefingPreferences.objects.get(user_id=self.user.pk)
        self.assertIsNone(prefs.briefing_model)

    def test_post_summary_style(self):
        self.make_prefs()
        response = self.client.post(reverse("briefing-preferences"), {"summary_style": "editorial"})
        data = json.decode(response.content)
        self.assertEqual(data["summary_style"], "editorial")

    def test_post_read_filter(self):
        self.make_prefs()
        response = self.client.post(reverse("briefing-preferences"), {"read_filter": "focus"})
        data = json.decode(response.content)
        self.assertEqual(data["read_filter"], "focus")

    def test_post_story_sources_folder(self):
        self.make_prefs()
        response = self.client.post(reverse("briefing-preferences"), {"story_sources": "folder:Tech"})
        prefs = MBriefingPreferences.objects.get(user_id=self.user.pk)
        self.assertEqual(prefs.story_sources, "folder:Tech")

    def test_migrates_focused_story_sources(self):
        self.make_prefs(story_sources="focused", read_filter="unread")
        response = self.client.get(reverse("briefing-preferences"))
        data = json.decode(response.content)
        self.assertEqual(data["story_sources"], "all")
        self.assertEqual(data["read_filter"], "focus")

    def test_time_display_mapping(self):
        self.make_prefs(preferred_time="13:00")
        response = self.client.get(reverse("briefing-preferences"))
        data = json.decode(response.content)
        self.assertEqual(data["preferred_time"], "afternoon")

    # --- briefing_status ---

    @patch("apps.briefing.views.RUserActivity")
    def test_status_returns_all_fields(self, mock_activity):
        mock_activity.get_typical_reading_hour.return_value = 9
        mock_activity.get_activity_histogram.return_value = {9: 15, 10: 8}
        mock_activity.get_briefing_generation_time.return_value = datetime.datetime(2025, 1, 15, 13, 30)

        self.make_prefs(enabled=True)
        response = self.client.get(reverse("briefing-status"))
        data = json.decode(response.content)
        self.assertIn("enabled", data)
        self.assertIn("frequency", data)
        self.assertIn("typical_reading_hour", data)
        self.assertIn("activity_histogram", data)
        self.assertIn("next_generation", data)

    @patch("apps.briefing.views.RUserActivity")
    def test_status_last_generated_from_briefing(self, mock_activity):
        mock_activity.get_typical_reading_hour.return_value = None
        mock_activity.get_activity_histogram.return_value = {}
        mock_activity.get_briefing_generation_time.return_value = None

        gen_time = datetime.datetime(2025, 1, 15, 10, 0, 0)
        self.make_briefing(generated_at=gen_time)
        self.make_prefs(enabled=False)

        response = self.client.get(reverse("briefing-status"))
        data = json.decode(response.content)
        self.assertIsNotNone(data["last_generated"])
        self.assertIn("2025-01-15", data["last_generated"])

    @patch("apps.briefing.views.RUserActivity")
    def test_status_next_generation_none_when_disabled(self, mock_activity):
        mock_activity.get_typical_reading_hour.return_value = None
        mock_activity.get_activity_histogram.return_value = {}

        self.make_prefs(enabled=False)
        response = self.client.get(reverse("briefing-status"))
        data = json.decode(response.content)
        self.assertIsNone(data["next_generation"])

    # --- generate_briefing ---

    @patch("apps.briefing.views.ensure_briefing_feed")
    @patch("apps.briefing.tasks.GenerateUserBriefing")
    def test_generate_requires_post(self, mock_task, mock_feed):
        response = self.client.get(reverse("generate-briefing"))
        data = json.decode(response.content)
        self.assertEqual(data["code"], -1)

    @patch("apps.briefing.views.ensure_briefing_feed")
    @patch("apps.briefing.tasks.GenerateUserBriefing")
    def test_generate_enables_briefing(self, mock_task, mock_feed):
        mock_feed.return_value = self.feed
        self.make_prefs(enabled=False)

        response = self.client.post(reverse("generate-briefing"))
        prefs = MBriefingPreferences.objects.get(user_id=self.user.pk)
        self.assertTrue(prefs.enabled)

    @patch("apps.briefing.views.ensure_briefing_feed")
    @patch("apps.briefing.tasks.GenerateUserBriefing")
    def test_generate_dispatches_task(self, mock_task, mock_feed):
        mock_feed.return_value = self.feed
        self.make_prefs()

        response = self.client.post(reverse("generate-briefing"))
        mock_task.delay.assert_called_once_with(self.user.pk, on_demand=True)

    @patch("apps.briefing.views.ensure_briefing_feed")
    @patch("apps.briefing.tasks.GenerateUserBriefing")
    def test_generate_returns_feed_id(self, mock_task, mock_feed):
        mock_feed.return_value = self.feed
        self.make_prefs()

        response = self.client.post(reverse("generate-briefing"))
        data = json.decode(response.content)
        self.assertEqual(data["briefing_feed_id"], self.feed.pk)


# ---------------------------------------------------------------------------
# 5. Test_Tasks — apps/briefing/tasks.py
# ---------------------------------------------------------------------------


class Test_Tasks(BriefingTestCase):
    """Tests for apps/briefing/tasks.py."""

    # --- GenerateBriefings ---

    @patch("apps.briefing.tasks.GenerateUserBriefing")
    @patch("redis.Redis")
    def test_generate_all_acquires_lock(self, mock_redis_cls, mock_user_task):
        from apps.briefing.tasks import GenerateBriefings

        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_r.set.return_value = True

        self.make_prefs(enabled=True)
        GenerateBriefings()
        mock_r.set.assert_called_once_with("briefing:generate_all_lock", "1", nx=True, ex=840)

    @patch("redis.Redis")
    def test_generate_all_skips_if_locked(self, mock_redis_cls):
        from apps.briefing.tasks import GenerateBriefings

        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_r.set.return_value = False

        GenerateBriefings()
        # tests.py: If lock is held, nothing else should happen

    @patch("apps.briefing.models.MBriefing")
    @patch("apps.briefing.tasks.GenerateUserBriefing")
    @patch("redis.Redis")
    def test_generate_all_dispatches_for_eligible(self, mock_redis_cls, mock_user_task, mock_mbriefing):
        from apps.briefing.tasks import GenerateBriefings

        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_r.set.return_value = True
        mock_mbriefing.exists_for_period.return_value = False

        self.make_prefs(enabled=True)
        GenerateBriefings()
        mock_user_task.delay.assert_called_with(self.user.pk)

    @patch("apps.briefing.tasks.GenerateUserBriefing")
    @patch("redis.Redis")
    def test_generate_all_skips_disabled(self, mock_redis_cls, mock_user_task):
        from apps.briefing.tasks import GenerateBriefings

        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_r.set.return_value = True

        self.make_prefs(enabled=False)
        GenerateBriefings()
        mock_user_task.delay.assert_not_called()

    # --- GenerateUserBriefing ---

    @patch("apps.briefing.models.create_briefing_story")
    @patch("apps.briefing.summary.embed_briefing_icons")
    @patch("apps.briefing.summary.filter_disabled_sections")
    @patch("apps.briefing.summary.extract_section_story_hashes")
    @patch("apps.briefing.summary.extract_section_summaries")
    @patch("apps.briefing.summary.generate_briefing_summary")
    @patch("apps.briefing.scoring.select_briefing_stories")
    @patch("apps.briefing.models.ensure_briefing_feed")
    @patch("redis.Redis")
    def test_user_briefing_full_pipeline(
        self,
        mock_redis_cls,
        mock_feed,
        mock_select,
        mock_summary,
        mock_extract_summaries,
        mock_extract_hashes,
        mock_filter,
        mock_embed,
        mock_create,
    ):
        from apps.briefing.tasks import GenerateUserBriefing

        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_r.set.return_value = True

        mock_feed.return_value = self.feed
        mock_select.return_value = self.make_scored_stories(self.stories[:5])
        mock_summary.return_value = (
            "<div>Summary</div>",
            {"display_name": "Haiku", "input_tokens": 100, "output_tokens": 50},
        )
        mock_extract_summaries.return_value = {"trending_global": "<div>S</div>"}
        mock_extract_hashes.return_value = {}
        mock_filter.return_value = "<div>Filtered</div>"
        mock_embed.return_value = "<div>Embedded</div>"
        mock_create.return_value = (MagicMock(), MagicMock(story_hash="test:hash"))

        self.make_prefs(enabled=True)
        GenerateUserBriefing(self.user.pk)

        mock_select.assert_called_once()
        mock_summary.assert_called_once()
        mock_create.assert_called_once()

    @patch("apps.briefing.scoring.select_briefing_stories")
    @patch("apps.briefing.models.ensure_briefing_feed")
    @patch("redis.Redis")
    def test_user_briefing_too_few_stories(self, mock_redis_cls, mock_feed, mock_select):
        from apps.briefing.tasks import GenerateUserBriefing

        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_r.set.return_value = True
        mock_feed.return_value = self.feed
        mock_select.return_value = self.make_scored_stories(self.stories[:2])

        self.make_prefs(enabled=True, frequency="daily")
        GenerateUserBriefing(self.user.pk)
        # tests.py: With only 2 stories and daily frequency (min 3), should skip

    @patch("apps.briefing.scoring.select_briefing_stories")
    @patch("apps.briefing.models.ensure_briefing_feed")
    @patch("redis.Redis")
    def test_user_briefing_twice_daily_lower_threshold(self, mock_redis_cls, mock_feed, mock_select):
        from apps.briefing.tasks import GenerateUserBriefing

        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_r.set.return_value = True
        mock_feed.return_value = self.feed
        # tests.py: Only 1 story — should be enough for twice_daily (min 1)
        mock_select.return_value = self.make_scored_stories(self.stories[:1])

        self.make_prefs(enabled=True, frequency="twice_daily")

        with patch("apps.briefing.summary.generate_briefing_summary") as mock_summary:
            mock_summary.return_value = (
                "<div>S</div>",
                {"display_name": "H", "input_tokens": 10, "output_tokens": 5},
            )
            with patch("apps.briefing.summary.extract_section_summaries") as mock_es:
                mock_es.return_value = {}
                with patch("apps.briefing.summary.extract_section_story_hashes") as mock_eh:
                    mock_eh.return_value = {}
                    with patch("apps.briefing.summary.embed_briefing_icons") as mock_ei:
                        mock_ei.return_value = "<div>S</div>"
                        with patch("apps.briefing.models.create_briefing_story") as mock_cs:
                            mock_cs.return_value = (MagicMock(), MagicMock(story_hash="t:h"))
                            GenerateUserBriefing(self.user.pk)
                            mock_summary.assert_called_once()

    @patch("apps.briefing.summary.generate_briefing_summary")
    @patch("apps.briefing.scoring.select_briefing_stories")
    @patch("apps.briefing.models.ensure_briefing_feed")
    @patch("redis.Redis")
    def test_user_briefing_summary_failure_exits(self, mock_redis_cls, mock_feed, mock_select, mock_summary):
        from apps.briefing.tasks import GenerateUserBriefing

        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_r.set.return_value = True
        mock_feed.return_value = self.feed
        mock_select.return_value = self.make_scored_stories(self.stories[:5])
        mock_summary.return_value = (None, None)

        self.make_prefs(enabled=True)
        GenerateUserBriefing(self.user.pk)
        # tests.py: No briefing should be created if summary fails

    @patch("redis.Redis")
    def test_user_briefing_acquires_per_user_lock(self, mock_redis_cls):
        from apps.briefing.tasks import GenerateUserBriefing

        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_r.set.return_value = False

        GenerateUserBriefing(self.user.pk)
        mock_r.set.assert_called_once_with("briefing:generate_user:%s" % self.user.pk, "1", nx=True, ex=840)

    @patch("redis.Redis")
    def test_user_briefing_user_not_found(self, mock_redis_cls):
        from apps.briefing.tasks import GenerateUserBriefing

        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_r.set.return_value = True

        # tests.py: Non-existent user ID should exit gracefully
        GenerateUserBriefing(999999)

    @patch("apps.briefing.models.create_briefing_story")
    @patch("apps.briefing.summary.embed_briefing_icons")
    @patch("apps.briefing.summary.extract_section_story_hashes")
    @patch("apps.briefing.summary.extract_section_summaries")
    @patch("apps.briefing.summary.filter_disabled_sections")
    @patch("apps.briefing.summary.generate_briefing_summary")
    @patch("apps.briefing.scoring.select_briefing_stories")
    @patch("apps.briefing.models.ensure_briefing_feed")
    @patch("redis.Redis")
    def test_user_briefing_filters_curated_sections(
        self,
        mock_redis_cls,
        mock_feed,
        mock_select,
        mock_summary,
        mock_filter,
        mock_extract_summaries,
        mock_extract_hashes,
        mock_embed,
        mock_create,
    ):
        """Regression test: disabled section keys should be remapped to trending_global in curated_sections."""
        from apps.briefing.tasks import GenerateUserBriefing

        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_r.set.return_value = True
        mock_feed.return_value = self.feed

        scored = self.make_scored_stories(
            self.stories[:3],
            categories=["long_read", "follow_up", "trending_global"],
        )
        mock_select.return_value = scored
        mock_summary.return_value = (
            "<div>S</div>",
            {"display_name": "H", "input_tokens": 10, "output_tokens": 5},
        )
        mock_filter.return_value = "<div>Filtered</div>"
        mock_extract_summaries.return_value = {"trending_global": "<div>T</div>"}
        mock_extract_hashes.return_value = {}
        mock_embed.return_value = "<div>Embedded</div>"
        mock_create.return_value = (MagicMock(), MagicMock(story_hash="test:hash"))

        # tests.py: Disable long_read and follow_up sections
        sections = dict(DEFAULT_SECTIONS)
        sections["long_read"] = False
        sections["follow_up"] = False
        self.make_prefs(enabled=True, sections=sections)

        GenerateUserBriefing(self.user.pk)

        # tests.py: Check curated_sections passed to create_briefing_story
        create_args = mock_create.call_args
        curated_sections = (
            create_args[1].get("curated_sections") or create_args[0][7]
            if len(create_args[0]) > 7
            else create_args[1].get("curated_sections")
        )
        # tests.py: long_read and follow_up should NOT be in curated_sections
        self.assertNotIn("long_read", curated_sections)
        self.assertNotIn("follow_up", curated_sections)
        # tests.py: Their stories should be remapped to trending_global
        self.assertIn("trending_global", curated_sections)

    @patch("apps.briefing.models.create_briefing_story")
    @patch("apps.briefing.summary.embed_briefing_icons")
    @patch("apps.briefing.summary.extract_section_story_hashes")
    @patch("apps.briefing.summary.extract_section_summaries")
    @patch("apps.briefing.summary.filter_disabled_sections")
    @patch("apps.briefing.summary.generate_briefing_summary")
    @patch("apps.briefing.scoring.select_briefing_stories")
    @patch("apps.briefing.models.ensure_briefing_feed")
    @patch("redis.Redis")
    def test_user_briefing_appends_debug_footer(
        self,
        mock_redis_cls,
        mock_feed,
        mock_select,
        mock_summary,
        mock_filter,
        mock_extract_summaries,
        mock_extract_hashes,
        mock_embed,
        mock_create,
    ):
        from apps.briefing.tasks import GenerateUserBriefing

        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_r.set.return_value = True
        mock_feed.return_value = self.feed
        mock_select.return_value = self.make_scored_stories(self.stories[:5])
        mock_summary.return_value = (
            "<div>S</div>",
            {"display_name": "Haiku 3.5", "input_tokens": 500, "output_tokens": 200},
        )
        mock_extract_summaries.return_value = {}
        mock_extract_hashes.return_value = {}
        mock_filter.return_value = "<div>Filtered</div>"

        mock_embed.side_effect = lambda html, stories: html
        mock_create.return_value = (MagicMock(), MagicMock(story_hash="test:hash"))

        self.make_prefs(enabled=True)
        GenerateUserBriefing(self.user.pk)

        # tests.py: Debug footer is appended after embed, so check create_briefing_story's 3rd arg (summary_html)
        create_call = mock_create.call_args
        html_arg = create_call[0][2]
        self.assertIn("NB-briefing-debug", html_arg)
        self.assertIn("Haiku 3.5", html_arg)

    @patch("apps.briefing.models.create_briefing_story")
    @patch("apps.briefing.summary.embed_briefing_icons")
    @patch("apps.briefing.summary.extract_section_story_hashes")
    @patch("apps.briefing.summary.extract_section_summaries")
    @patch("apps.briefing.summary.filter_disabled_sections")
    @patch("apps.briefing.summary.generate_briefing_summary")
    @patch("apps.briefing.scoring.select_briefing_stories")
    @patch("apps.briefing.models.ensure_briefing_feed")
    @patch("redis.Redis")
    def test_user_briefing_on_demand_deletes_lock(
        self,
        mock_redis_cls,
        mock_feed,
        mock_select,
        mock_summary,
        mock_filter,
        mock_extract_summaries,
        mock_extract_hashes,
        mock_embed,
        mock_create,
    ):
        from apps.briefing.tasks import GenerateUserBriefing

        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_r.set.return_value = True
        mock_feed.return_value = self.feed
        mock_select.return_value = self.make_scored_stories(self.stories[:5])
        mock_summary.return_value = (
            "<div>S</div>",
            {"display_name": "H", "input_tokens": 10, "output_tokens": 5},
        )
        mock_extract_summaries.return_value = {}
        mock_extract_hashes.return_value = {}
        mock_filter.return_value = "<div>F</div>"
        mock_embed.return_value = "<div>E</div>"
        mock_create.return_value = (MagicMock(), MagicMock(story_hash="test:hash"))

        self.make_prefs(enabled=True)
        GenerateUserBriefing(self.user.pk, on_demand=True)

        lock_key = "briefing:generate_user:%s" % self.user.pk
        mock_r.delete.assert_called_with(lock_key)

    @patch("apps.briefing.models.create_briefing_story")
    @patch("apps.briefing.summary.embed_briefing_icons")
    @patch("apps.briefing.summary.extract_section_story_hashes")
    @patch("apps.briefing.summary.extract_section_summaries")
    @patch("apps.briefing.summary.filter_disabled_sections")
    @patch("apps.briefing.summary.generate_briefing_summary")
    @patch("apps.briefing.scoring.select_briefing_stories")
    @patch("apps.briefing.models.ensure_briefing_feed")
    @patch("redis.Redis")
    def test_user_briefing_scheduled_keeps_lock(
        self,
        mock_redis_cls,
        mock_feed,
        mock_select,
        mock_summary,
        mock_filter,
        mock_extract_summaries,
        mock_extract_hashes,
        mock_embed,
        mock_create,
    ):
        from apps.briefing.tasks import GenerateUserBriefing

        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_r.set.return_value = True
        mock_feed.return_value = self.feed
        mock_select.return_value = self.make_scored_stories(self.stories[:5])
        mock_summary.return_value = (
            "<div>S</div>",
            {"display_name": "H", "input_tokens": 10, "output_tokens": 5},
        )
        mock_extract_summaries.return_value = {}
        mock_extract_hashes.return_value = {}
        mock_filter.return_value = "<div>F</div>"
        mock_embed.return_value = "<div>E</div>"
        mock_create.return_value = (MagicMock(), MagicMock(story_hash="test:hash"))

        self.make_prefs(enabled=True)
        GenerateUserBriefing(self.user.pk, on_demand=False)

        mock_r.delete.assert_not_called()

    @patch("apps.briefing.models.create_briefing_story")
    @patch("apps.briefing.summary.embed_briefing_icons")
    @patch("apps.briefing.summary.extract_section_story_hashes")
    @patch("apps.briefing.summary.extract_section_summaries")
    @patch("apps.briefing.summary.filter_disabled_sections")
    @patch("apps.briefing.summary.generate_briefing_summary")
    @patch("apps.briefing.scoring.select_briefing_stories")
    @patch("apps.briefing.models.ensure_briefing_feed")
    @patch("redis.Redis")
    def test_user_briefing_on_demand_publishes_events(
        self,
        mock_redis_cls,
        mock_feed,
        mock_select,
        mock_summary,
        mock_filter,
        mock_extract_summaries,
        mock_extract_hashes,
        mock_embed,
        mock_create,
    ):
        from apps.briefing.tasks import GenerateUserBriefing

        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_r.set.return_value = True
        mock_feed.return_value = self.feed
        mock_select.return_value = self.make_scored_stories(self.stories[:5])
        mock_summary.return_value = (
            "<div>S</div>",
            {"display_name": "H", "input_tokens": 10, "output_tokens": 5},
        )
        mock_extract_summaries.return_value = {}
        mock_extract_hashes.return_value = {}
        mock_filter.return_value = "<div>F</div>"
        mock_embed.return_value = "<div>E</div>"
        mock_create.return_value = (MagicMock(), MagicMock(story_hash="test:hash"))

        self.make_prefs(enabled=True)
        GenerateUserBriefing(self.user.pk, on_demand=True)

        # tests.py: Check pubsub events were published
        publish_calls = [c for c in mock_r.publish.call_args_list]
        published_messages = [c[0][1] for c in publish_calls]
        published_types = []
        for msg in published_messages:
            if isinstance(msg, str) and msg.startswith("briefing:"):
                import json as j

                payload = j.loads(msg[len("briefing:") :])
                published_types.append(payload["type"])
        self.assertIn("start", published_types)
        self.assertIn("complete", published_types)


# ---------------------------------------------------------------------------
# 6. Test_Activity — apps/briefing/activity.py
# ---------------------------------------------------------------------------


class Test_Activity(TestCase):
    """Tests for apps/briefing/activity.py (Redis-backed activity tracking)."""

    @patch("apps.briefing.activity.redis.Redis")
    def test_record_increments_correct_hour(self, mock_redis_cls):
        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r

        RUserActivity.record_activity(42, "America/New_York")
        mock_r.hincrby.assert_called_once()
        call_args = mock_r.hincrby.call_args[0]
        self.assertEqual(call_args[0], "uAct:42")
        self.assertTrue(call_args[1].startswith("hour_"))

    @patch("apps.briefing.activity.redis.Redis")
    def test_record_key_format(self, mock_redis_cls):
        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r

        RUserActivity.record_activity(123, "UTC")
        call_args = mock_r.hincrby.call_args[0]
        self.assertEqual(call_args[0], "uAct:123")

    @patch("apps.briefing.activity.redis.Redis")
    def test_histogram_basic(self, mock_redis_cls):
        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_r.hgetall.return_value = {
            b"hour_9": b"15",
            b"hour_10": b"8",
            b"hour_14": b"12",
        }

        histogram = RUserActivity.get_activity_histogram(42)
        self.assertEqual(histogram[9], 15)
        self.assertEqual(histogram[10], 8)
        self.assertEqual(histogram[14], 12)

    @patch("apps.briefing.activity.redis.Redis")
    def test_histogram_empty(self, mock_redis_cls):
        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_r.hgetall.return_value = {}

        histogram = RUserActivity.get_activity_histogram(42)
        self.assertEqual(histogram, {})

    @patch("apps.briefing.activity.redis.Redis")
    def test_typical_hour_returns_peak(self, mock_redis_cls):
        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_r.hgetall.return_value = {
            b"hour_8": b"5",
            b"hour_9": b"20",
            b"hour_10": b"3",
        }

        hour = RUserActivity.get_typical_reading_hour(42)
        self.assertEqual(hour, 9)

    @patch("apps.briefing.activity.redis.Redis")
    def test_typical_hour_insufficient_data(self, mock_redis_cls):
        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_r.hgetall.return_value = {b"hour_9": b"3"}

        hour = RUserActivity.get_typical_reading_hour(42)
        self.assertIsNone(hour)

    @patch("apps.briefing.activity.redis.Redis")
    def test_typical_hour_empty(self, mock_redis_cls):
        mock_r = MagicMock()
        mock_redis_cls.return_value = mock_r
        mock_r.hgetall.return_value = {}

        hour = RUserActivity.get_typical_reading_hour(42)
        self.assertIsNone(hour)

    @patch("apps.briefing.activity.RUserActivity.get_typical_reading_hour")
    @patch("apps.briefing.activity.redis.Redis")
    def test_generation_time_with_typical(self, mock_redis_cls, mock_typical):
        mock_typical.return_value = 9

        result = RUserActivity.get_briefing_generation_time(42, "America/New_York")
        # tests.py: Should be 30 min before 9 AM ET, converted to UTC
        self.assertIsInstance(result, datetime.datetime)
        self.assertIsNone(result.tzinfo)

    @patch("apps.briefing.activity.RUserActivity.get_typical_reading_hour")
    @patch("apps.briefing.activity.redis.Redis")
    def test_generation_time_default(self, mock_redis_cls, mock_typical):
        mock_typical.return_value = None

        result = RUserActivity.get_briefing_generation_time(42, "America/New_York")
        # tests.py: Should fall back to DEFAULT_HOUR (7 AM) minus 30 min
        self.assertIsInstance(result, datetime.datetime)

    @patch("apps.briefing.activity.RUserActivity.get_typical_reading_hour")
    @patch("apps.briefing.activity.redis.Redis")
    def test_generation_time_timezone(self, mock_redis_cls, mock_typical):
        mock_typical.return_value = 9

        result_ny = RUserActivity.get_briefing_generation_time(42, "America/New_York")
        result_tokyo = RUserActivity.get_briefing_generation_time(42, "Asia/Tokyo")
        # tests.py: Same local hour (9 AM) in different timezones should produce different UTC times
        self.assertNotEqual(result_ny, result_tokyo)
