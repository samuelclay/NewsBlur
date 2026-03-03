from django.test import TestCase

from apps.clustering.models import (
    SEMANTIC_MIN_TITLE_INTERSECTION,
    _simple_stem,
    find_title_clusters,
    merge_clusters,
    normalize_title,
    title_significant_words,
    title_words_excluding_feed,
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


class Test_SemanticClusterFalsePositive(TestCase):
    """Tests that semantic clustering rejects false positives with insufficient title overlap."""

    def _make_stories(self):
        return [
            {
                "story_hash": "100:aaa",
                "story_feed_id": 1,
                "story_title": "Apple Launches New 'Sales Coach' App",
                "story_date": 1000,
            },
            {
                "story_hash": "200:bbb",
                "story_feed_id": 2,
                "story_title": "Rivian owners will soon be able to access Apple Watch apps from their cars",
                "story_date": 999,
            },
            {
                "story_hash": "300:ccc",
                "story_feed_id": 3,
                "story_title": "Rivian Releases Apple Watch App",
                "story_date": 998,
            },
        ]

    def test_title_words_for_apple_stories(self):
        """Verify the word intersection counts that drive the threshold decision."""
        w1 = title_significant_words("Apple Launches New 'Sales Coach' App")
        w2 = title_significant_words(
            "Rivian owners will soon be able to access Apple Watch apps from their cars"
        )
        w3 = title_significant_words("Rivian Releases Apple Watch App")

        # Sales Coach vs either Rivian story: only 'apple' and 'app'
        self.assertEqual(len(w1 & w2), 2)
        self.assertEqual(len(w1 & w3), 2)
        # Rivian vs Rivian: 'apple', 'app', 'rivian', 'watch'
        self.assertEqual(len(w2 & w3), 4)
        self.assertGreaterEqual(len(w2 & w3), SEMANTIC_MIN_TITLE_INTERSECTION)
        self.assertLess(len(w1 & w2), SEMANTIC_MIN_TITLE_INTERSECTION)

    def test_merge_rejects_semantic_false_positive(self):
        """Sales Coach story should not merge with Rivian Apple Watch stories
        when semantic clustering falsely matches them on shared 'apple'/'app' terms."""
        stories = self._make_stories()
        story_title_map = {s["story_hash"]: s["story_title"] for s in stories}
        story_feed_map = {s["story_hash"]: s["story_feed_id"] for s in stories}

        # Title clusters correctly group only Rivian stories
        title_clusters = find_title_clusters(stories)

        # Simulate ES semantic false positive: Sales Coach matched with Rivian story
        semantic_clusters = {"100:aaa": ["100:aaa", "200:bbb"]}

        merged = merge_clusters(
            title_clusters,
            semantic_clusters,
            story_feed_map=story_feed_map,
            story_title_map=story_title_map,
        )

        # Sales Coach should NOT be in the same cluster as Rivian stories
        for members in merged.values():
            self.assertFalse(
                "100:aaa" in members and ("200:bbb" in members or "300:ccc" in members),
                "Sales Coach story should not merge with Rivian Apple Watch stories",
            )

    def test_merge_preserves_valid_rivian_cluster(self):
        """Rivian Apple Watch stories should remain clustered together."""
        stories = self._make_stories()
        story_title_map = {s["story_hash"]: s["story_title"] for s in stories}
        story_feed_map = {s["story_hash"]: s["story_feed_id"] for s in stories}

        title_clusters = find_title_clusters(stories)
        semantic_clusters = {"100:aaa": ["100:aaa", "200:bbb"]}

        merged = merge_clusters(
            title_clusters,
            semantic_clusters,
            story_feed_map=story_feed_map,
            story_title_map=story_title_map,
        )

        # Rivian stories should still be clustered together
        rivian_clustered = any("200:bbb" in members and "300:ccc" in members for members in merged.values())
        self.assertTrue(rivian_clustered, "Rivian Apple Watch stories should remain clustered")

    def test_merge_without_title_map_unions_everything(self):
        """Without story_title_map, merge_clusters should behave as before (union all)."""
        stories = self._make_stories()
        story_feed_map = {s["story_hash"]: s["story_feed_id"] for s in stories}

        semantic_clusters = {"100:aaa": ["100:aaa", "200:bbb"]}

        merged = merge_clusters(
            {},
            semantic_clusters,
            story_feed_map=story_feed_map,
            story_title_map=None,
        )

        # Without title validation, the false positive union is allowed
        found_both = any("100:aaa" in members and "200:bbb" in members for members in merged.values())
        self.assertTrue(found_both, "Without title map, all semantic matches should union")


class Test_TitleWordsExcludingFeed(TestCase):
    def test_strips_feed_title_words(self):
        """Feed title words should be removed from significant words."""
        words = title_words_excluding_feed(
            "Saturday Morning Breakfast Cereal - Cow",
            "Saturday Morning Breakfast Cereal",
        )
        self.assertEqual(words, frozenset({"cow"}))

    def test_no_feed_title(self):
        """Without feed title, all significant words are kept."""
        words = title_words_excluding_feed("Saturday Morning Breakfast Cereal - Cow", "")
        self.assertEqual(words, title_significant_words("Saturday Morning Breakfast Cereal - Cow"))

    def test_feed_title_words_not_in_story(self):
        """When feed title words don't appear in story, nothing is stripped."""
        words = title_words_excluding_feed(
            "Trump Signs Executive Order on Artificial Intelligence",
            "New York Times",
        )
        expected = title_significant_words("Trump Signs Executive Order on Artificial Intelligence")
        self.assertEqual(words, expected)


class Test_FeedTitleStripping(TestCase):
    def _smbc_stories(self):
        """SMBC-style stories: shared feed-name prefix, unique single-word suffix."""
        return [
            {
                "story_hash": "785:aaa",
                "story_feed_id": 1,
                "story_title": "Saturday Morning Breakfast Cereal - Cow",
                "story_date": 1000,
            },
            {
                "story_hash": "6165:bbb",
                "story_feed_id": 2,
                "story_title": "Saturday Morning Breakfast Cereal - Ant",
                "story_date": 999,
            },
            {
                "story_hash": "785:ccc",
                "story_feed_id": 1,
                "story_title": "Saturday Morning Breakfast Cereal - Out",
                "story_date": 998,
            },
            {
                "story_hash": "6165:ddd",
                "story_feed_id": 2,
                "story_title": "Saturday Morning Breakfast Cereal - Never",
                "story_date": 997,
            },
            {
                "story_hash": "785:eee",
                "story_feed_id": 1,
                "story_title": "Saturday Morning Breakfast Cereal - Nantucket",
                "story_date": 996,
            },
            {
                "story_hash": "6165:fff",
                "story_feed_id": 2,
                "story_title": "Saturday Morning Breakfast Cereal - Nantucket",
                "story_date": 995,
            },
        ]

    def _feed_title_map(self):
        return {1: "Saturday Morning Breakfast Cereal", 2: "Saturday Morning Breakfast Cereal"}

    def test_smbc_not_clustered_with_feed_title_map(self):
        """SMBC-style stories should NOT fuzzy-match when feed title is stripped."""
        stories = self._smbc_stories()
        feed_title_map = self._feed_title_map()
        clusters = find_title_clusters(stories, feed_title_map=feed_title_map)
        # Only exact title match "Nantucket" should cluster (785:eee + 6165:fff)
        self.assertEqual(len(clusters), 1)
        cluster = list(clusters.values())[0]
        self.assertIn("785:eee", cluster)
        self.assertIn("6165:fff", cluster)
        # Other stories should NOT be in any cluster
        all_clustered = set()
        for members in clusters.values():
            all_clustered.update(members)
        self.assertNotIn("785:aaa", all_clustered)
        self.assertNotIn("6165:bbb", all_clustered)

    def test_smbc_falsely_clustered_without_feed_title_map(self):
        """Without feed_title_map, SMBC stories WOULD fuzzy-match (demonstrating the bug)."""
        stories = self._smbc_stories()
        clusters = find_title_clusters(stories)
        # Without the fix, fuzzy matching chains everything together
        all_clustered = set()
        for members in clusters.values():
            all_clustered.update(members)
        # All 6 stories end up clustered
        self.assertEqual(len(all_clustered), 6)

    def test_legitimate_cluster_still_works_with_feed_title_map(self):
        """Normal news stories should still cluster when feed title is stripped."""
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
        feed_title_map = {1: "New York Times", 2: "Techmeme"}
        clusters = find_title_clusters(stories, feed_title_map=feed_title_map)
        self.assertEqual(len(clusters), 1)
        cluster = list(clusters.values())[0]
        self.assertIn("111:aaa", cluster)
        self.assertIn("222:bbb", cluster)
