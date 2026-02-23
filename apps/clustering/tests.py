from django.test import TestCase

from apps.clustering.models import (
    _simple_stem,
    find_title_clusters,
    normalize_title,
    title_significant_words,
)


class Test_NormalizeTitle(TestCase):
    def test_basic(self):
        self.assertEqual(normalize_title("  Breaking News!  "), "breaking news")

    def test_empty(self):
        self.assertEqual(normalize_title(""), "")

    def test_none(self):
        self.assertEqual(normalize_title(None), "")

    def test_hyphen_splits_words(self):
        self.assertEqual(normalize_title("Anthropic-backed"), "anthropic backed")

    def test_slash_splits_words(self):
        self.assertEqual(normalize_title("Kang/New York Times"), "kang new york times")

    def test_multiple_hyphens(self):
        self.assertEqual(normalize_title("well-known test-driven"), "well known test driven")


class Test_SimpleStem(TestCase):
    def test_plural(self):
        self.assertEqual(_simple_stem("regulations"), "regulation")

    def test_begins(self):
        self.assertEqual(_simple_stem("begins"), "begin")

    def test_short_word_preserved(self):
        self.assertEqual(_simple_stem("bus"), "bus")
        self.assertEqual(_simple_stem("gas"), "gas")
        self.assertEqual(_simple_stem("ios"), "ios")

    def test_double_s_preserved(self):
        self.assertEqual(_simple_stem("press"), "press")
        self.assertEqual(_simple_stem("class"), "class")

    def test_no_trailing_s(self):
        self.assertEqual(_simple_stem("anthropic"), "anthropic")


class Test_TitleSignificantWords(TestCase):
    def test_short_acronyms_included(self):
        words = title_significant_words("AI regulation in the EU")
        self.assertIn("ai", words)
        self.assertIn("eu", words)

    def test_stopwords_excluded(self):
        words = title_significant_words("he said she was going up")
        self.assertNotIn("he", words)
        self.assertNotIn("she", words)
        self.assertNotIn("up", words)

    def test_stemming_applied(self):
        words = title_significant_words("AI regulations and political ads")
        self.assertIn("regulation", words)
        # "ads" (3 chars) is NOT stemmed — stemmer only applies to len > 3
        # to avoid mangling short words like "bus", "gas"
        self.assertIn("ads", words)

    def test_hyphenated_words_split(self):
        words = title_significant_words("Anthropic-backed super PAC")
        self.assertIn("anthropic", words)
        self.assertIn("backed", words)


class Test_FindTitleClusters(TestCase):
    def test_aggregator_title_clusters(self):
        """The NYT/Techmeme case that motivated this fix."""
        stories = [
            {
                "story_hash": "111:aaa",
                "story_feed_id": 1,
                "story_title": "Backed by Anthropic, a Super PAC Begins an Ad Blitz in Support of A.I. Regulation",
                "story_date": 1000,
            },
            {
                "story_hash": "222:bbb",
                "story_feed_id": 2,
                "story_title": (
                    "Anthropic-backed super PAC Public First Action begins running ads urging AI"
                    " regulations in New Jersey; the PAC raised nearly $50M and now aims to raise"
                    " $75M (Cecilia Kang/New York Times)"
                ),
                "story_date": 999,
            },
        ]
        clusters = find_title_clusters(stories)
        self.assertEqual(len(clusters), 1)
        cluster_hashes = list(clusters.values())[0]
        self.assertIn("111:aaa", cluster_hashes)
        self.assertIn("222:bbb", cluster_hashes)

    def test_no_false_positive_on_shared_topic_word(self):
        """Stories sharing only 1-2 common words should NOT cluster."""
        stories = [
            {
                "story_hash": "111:aaa",
                "story_feed_id": 1,
                "story_title": "Apple Releases the New iPhone 17 with Better Camera",
                "story_date": 1000,
            },
            {
                "story_hash": "222:bbb",
                "story_feed_id": 2,
                "story_title": "Apple Releases New macOS Update with Security Fixes",
                "story_date": 999,
            },
        ]
        clusters = find_title_clusters(stories)
        self.assertEqual(len(clusters), 0)

    def test_same_feed_not_clustered(self):
        """Stories from the same feed should NOT form a cluster."""
        stories = [
            {
                "story_hash": "111:aaa",
                "story_feed_id": 1,
                "story_title": "Breaking: Major Event Unfolds in Washington Today",
                "story_date": 1000,
            },
            {
                "story_hash": "111:bbb",
                "story_feed_id": 1,
                "story_title": "Breaking: Major Event Unfolds in Washington Today",
                "story_date": 999,
            },
        ]
        clusters = find_title_clusters(stories)
        self.assertEqual(len(clusters), 0)

    def test_exact_title_match_across_feeds(self):
        """Identical titles from different feeds should cluster."""
        stories = [
            {
                "story_hash": "111:aaa",
                "story_feed_id": 1,
                "story_title": "Major Climate Agreement Reached at United Nations Summit",
                "story_date": 1000,
            },
            {
                "story_hash": "222:bbb",
                "story_feed_id": 2,
                "story_title": "Major Climate Agreement Reached at United Nations Summit",
                "story_date": 999,
            },
        ]
        clusters = find_title_clusters(stories)
        self.assertEqual(len(clusters), 1)
