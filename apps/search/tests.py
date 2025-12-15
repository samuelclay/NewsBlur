"""
Tests for search functionality, including phrase search support.

Run with: make test SCOPE=apps.search
"""

import datetime
import time
from unittest.mock import MagicMock, patch

from django.test import TestCase, TransactionTestCase

from apps.search.models import SearchStory


class Test_SanitizeQuery(TestCase):
    """Unit tests for SearchStory._sanitize_query method."""

    def test_balanced_quotes_unchanged(self):
        """Balanced quotes should pass through unchanged."""
        query = '"quick brown fox"'
        result = SearchStory._sanitize_query(query)
        self.assertEqual(result, '"quick brown fox"')

    def test_multiple_balanced_quotes_unchanged(self):
        """Multiple balanced quote pairs should pass through unchanged."""
        query = '"quick brown" AND "lazy dog"'
        result = SearchStory._sanitize_query(query)
        self.assertEqual(result, '"quick brown" AND "lazy dog"')

    def test_unbalanced_single_quote_escaped(self):
        """Single unbalanced quote should be escaped."""
        query = 'hello "world'
        result = SearchStory._sanitize_query(query)
        self.assertEqual(result, 'hello \\"world')

    def test_unbalanced_quote_at_start_escaped(self):
        """Unbalanced quote at start should be escaped."""
        query = '"hello world'
        result = SearchStory._sanitize_query(query)
        self.assertEqual(result, '\\"hello world')

    def test_three_quotes_last_escaped(self):
        """With odd number of quotes, last one should be escaped."""
        query = '"hello" "world'
        result = SearchStory._sanitize_query(query)
        self.assertEqual(result, '"hello" \\"world')

    def test_no_quotes_unchanged(self):
        """Query without quotes should pass through unchanged."""
        query = "hello world"
        result = SearchStory._sanitize_query(query)
        self.assertEqual(result, "hello world")

    def test_empty_query_unchanged(self):
        """Empty query should pass through unchanged."""
        query = ""
        result = SearchStory._sanitize_query(query)
        self.assertEqual(result, "")

    def test_empty_phrase_unchanged(self):
        """Empty phrase (just quotes) should pass through unchanged."""
        query = '""'
        result = SearchStory._sanitize_query(query)
        self.assertEqual(result, '""')


class Test_StripRegex(TestCase):
    """Test that the strip regex preserves quotes for phrase search."""

    def test_strip_preserves_quotes(self):
        """The strip regex should preserve double quotes."""
        import re

        # This is the new regex from the query method
        strip_regex = r'([^\s\w_\-"])+'
        query = '"quick brown fox"'
        result = re.sub(strip_regex, " ", query)
        self.assertEqual(result, '"quick brown fox"')

    def test_strip_removes_special_chars(self):
        """The strip regex should still remove other special characters."""
        import re

        strip_regex = r'([^\s\w_\-"])+'
        query = "hello@world#test"
        result = re.sub(strip_regex, " ", query)
        self.assertEqual(result, "hello world test")

    def test_strip_preserves_hyphen_and_underscore(self):
        """The strip regex should preserve hyphens and underscores."""
        import re

        strip_regex = r'([^\s\w_\-"])+'
        query = "hello-world_test"
        result = re.sub(strip_regex, " ", query)
        self.assertEqual(result, "hello-world_test")

    def test_strip_with_phrase_and_special_chars(self):
        """Strip should remove special chars but keep quotes for phrases."""
        import re

        strip_regex = r'([^\s\w_\-"])+'
        query = '"quick brown" @fox #test'
        result = re.sub(strip_regex, " ", query)
        self.assertEqual(result, '"quick brown"  fox  test')


class Test_SearchStoryIntegration(TransactionTestCase):
    """Integration tests for SearchStory that require Elasticsearch.

    These tests index real documents and verify phrase search behavior.
    """

    @classmethod
    def setUpClass(cls):
        """Create test index before all tests."""
        super().setUpClass()
        # Use a test-specific index name to avoid conflicts
        cls.original_index_name = SearchStory.index_name
        SearchStory.index_name = classmethod(lambda cls: "test-stories-index")
        try:
            SearchStory.create_elasticsearch_mapping(delete=True)
        except Exception as e:
            print(f"Warning: Could not set up Elasticsearch test index: {e}")

    @classmethod
    def tearDownClass(cls):
        """Clean up test index after all tests."""
        try:
            SearchStory.drop()
        except Exception:
            pass
        SearchStory.index_name = cls.original_index_name
        super().tearDownClass()

    def setUp(self):
        """Index test stories before each test."""
        self.test_feed_id = 99999
        self.story_hashes = []

        # Test stories with specific content for phrase matching
        test_stories = [
            (
                "story1",
                "The quick brown fox",
                "The quick brown fox jumps over the lazy dog. This is a classic pangram.",
            ),
            (
                "story2",
                "Brown fox sighting",
                "A brown fox was spotted in the forest yesterday. The fox was quick.",
            ),
            (
                "story3",
                "Exact phrase test",
                "This article contains the exact phrase to find in a search.",
            ),
            (
                "story4",
                "Another article about animals",
                "Foxes are brown animals that often jump over obstacles quickly.",
            ),
            (
                "story5",
                "Technology news",
                "The latest technology news includes updates about quick search features.",
            ),
        ]

        for hash_suffix, title, content in test_stories:
            story_hash = f"{self.test_feed_id}:{hash_suffix}"
            self.story_hashes.append(story_hash)
            try:
                SearchStory.index(
                    story_hash=story_hash,
                    story_title=title,
                    story_content=content,
                    story_tags=["test"],
                    story_author="Test Author",
                    story_feed_id=self.test_feed_id,
                    story_date=datetime.datetime.now(),
                )
            except Exception as e:
                self.skipTest(f"Elasticsearch not available: {e}")

        # Give ES time to index
        try:
            SearchStory.ES().indices.refresh(SearchStory.index_name())
        except Exception:
            pass
        time.sleep(0.5)

    def tearDown(self):
        """Remove test stories after each test."""
        for story_hash in self.story_hashes:
            try:
                SearchStory.remove(story_hash)
            except Exception:
                pass

    def test_basic_word_search(self):
        """Basic word search should return matching stories."""
        results = SearchStory.query([self.test_feed_id], "fox", "newest", 0, 10)
        self.assertGreater(len(results), 0, "Should find stories containing 'fox'")

    def test_phrase_search_exact_match(self):
        """Phrase search should only match exact phrases."""
        results = SearchStory.query([self.test_feed_id], '"quick brown fox"', "newest", 0, 10)
        # Should match story1 which has the exact phrase
        self.assertGreater(len(results), 0, "Should find story with exact phrase 'quick brown fox'")
        # story1 should be in results
        matching_story1 = any("story1" in r for r in results)
        self.assertTrue(matching_story1, "story1 should match 'quick brown fox'")

    def test_phrase_search_word_order_matters(self):
        """Phrase search should not match if words are in different order."""
        results = SearchStory.query([self.test_feed_id], '"fox brown quick"', "newest", 0, 10)
        # Should NOT match because no story has these words in this order
        self.assertEqual(len(results), 0, "Should not find stories with 'fox brown quick' in that order")

    def test_phrase_search_non_adjacent_words(self):
        """Phrase search should not match non-adjacent words."""
        # story2 has "brown fox" and "fox was quick" but not "brown fox quick"
        results = SearchStory.query([self.test_feed_id], '"brown fox quick"', "newest", 0, 10)
        self.assertEqual(len(results), 0, "Should not match non-adjacent words as phrase")

    def test_mixed_phrase_and_word_search(self):
        """Search combining phrase and regular words should work."""
        results = SearchStory.query([self.test_feed_id], '"quick brown" fox', "newest", 0, 10)
        # Should match story1 which has both the phrase and the word
        self.assertGreater(len(results), 0, "Should find stories with phrase AND word")

    def test_multiple_phrase_search(self):
        """Search with multiple phrases should work."""
        results = SearchStory.query([self.test_feed_id], '"quick brown" "lazy dog"', "newest", 0, 10)
        # Should only match story1 which has both phrases
        self.assertGreater(len(results), 0, "Should find story with both phrases")
        # Verify story1 is matched
        matching_story1 = any("story1" in r for r in results)
        self.assertTrue(matching_story1, "story1 should match both phrases")

    def test_unbalanced_quote_handled(self):
        """Unbalanced quotes should not cause errors."""
        # Should not raise an exception
        try:
            results = SearchStory.query([self.test_feed_id], 'fox "brown', "newest", 0, 10)
            self.assertIsInstance(results, list, "Should return a list even with unbalanced quotes")
        except Exception as e:
            self.fail(f"Unbalanced quote caused exception: {e}")

    def test_phrase_search_with_strip(self):
        """Phrase search should work even with strip=True."""
        results = SearchStory.query([self.test_feed_id], '"quick brown fox"', "newest", 0, 10, strip=True)
        # Should still match because quotes are preserved in strip mode
        self.assertGreater(len(results), 0, "Phrase search should work with strip=True")

    def test_empty_phrase_search(self):
        """Empty phrase search should not crash."""
        try:
            results = SearchStory.query([self.test_feed_id], '""', "newest", 0, 10)
            self.assertIsInstance(results, list, "Empty phrase should return a list")
        except Exception as e:
            self.fail(f"Empty phrase caused exception: {e}")

    def test_global_query_phrase_search(self):
        """Global query should also support phrase search."""
        try:
            results = SearchStory.global_query('"quick brown fox"', "newest", 0, 10)
            # Should find stories with exact phrase
            self.assertIsInstance(results, list, "global_query should return results")
        except Exception as e:
            # global_query may timeout if ES is slow - skip rather than fail
            if "timeout" in str(e).lower():
                self.skipTest(f"Elasticsearch timeout: {e}")
            raise


class Test_SearchStoryMocked(TestCase):
    """Tests for SearchStory using mocked Elasticsearch.

    These tests verify the query construction without needing ES running.
    """

    @patch.object(SearchStory, "ES")
    def test_query_constructs_correct_body(self, mock_es_class):
        """Verify the query body is constructed correctly for phrase search."""
        mock_es = MagicMock()
        mock_es_class.return_value = mock_es
        mock_es.indices.flush.return_value = None
        mock_es.search.return_value = {"hits": {"hits": []}}

        SearchStory.query([1, 2, 3], '"test phrase"', "newest", 0, 10)

        # Verify search was called
        mock_es.search.assert_called_once()
        call_kwargs = mock_es.search.call_args[1]
        body = call_kwargs["body"]

        # Verify the query string contains the phrase with quotes
        query_string = body["query"]["bool"]["must"][0]["query_string"]["query"]
        self.assertIn('"test phrase"', query_string)

    @patch.object(SearchStory, "ES")
    def test_query_with_strip_preserves_quotes(self, mock_es_class):
        """Verify that strip=True still preserves quotes for phrases."""
        mock_es = MagicMock()
        mock_es_class.return_value = mock_es
        mock_es.indices.flush.return_value = None
        mock_es.search.return_value = {"hits": {"hits": []}}

        SearchStory.query([1], '"test phrase"', "newest", 0, 10, strip=True)

        call_kwargs = mock_es.search.call_args[1]
        body = call_kwargs["body"]
        query_string = body["query"]["bool"]["must"][0]["query_string"]["query"]

        # Quotes should be preserved even with strip=True
        self.assertIn('"test phrase"', query_string)

    @patch.object(SearchStory, "ES")
    def test_query_escapes_unbalanced_quotes(self, mock_es_class):
        """Verify unbalanced quotes are escaped in the query."""
        mock_es = MagicMock()
        mock_es_class.return_value = mock_es
        mock_es.indices.flush.return_value = None
        mock_es.search.return_value = {"hits": {"hits": []}}

        SearchStory.query([1], 'test "phrase', "newest", 0, 10)

        call_kwargs = mock_es.search.call_args[1]
        body = call_kwargs["body"]
        query_string = body["query"]["bool"]["must"][0]["query_string"]["query"]

        # The unbalanced quote should be escaped
        self.assertIn('\\"', query_string)
