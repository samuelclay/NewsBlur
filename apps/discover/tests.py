from django.test import TestCase


class Test_DiscoverViews(TestCase):
    """Tests for discover app views."""

    def test_trending_sites_endpoint(self):
        """Test that trending sites endpoint returns valid response."""
        response = self.client.get("/discover/trending/")
        self.assertEqual(response.status_code, 200)

    def test_feed_autocomplete_endpoint(self):
        """Test that feed autocomplete endpoint returns valid response."""
        response = self.client.get("/discover/autocomplete/", {"term": "news"})
        self.assertEqual(response.status_code, 200)
