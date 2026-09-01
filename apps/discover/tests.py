import datetime
import json

from django.contrib.auth.models import User
from django.test import TestCase
from django.test.client import Client

from apps.discover.models import PopularFeed
from apps.reader.models import UserSubscription
from apps.rss_feeds.models import Feed


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


class Test_DiscoverFilters(TestCase):
    """Tests for the Add Site / Discover staleness and exclude-subscribed filters."""

    def setUp(self):
        self.client = Client()
        now = datetime.datetime.now()

        # A feed that published recently and one that has been stale for ~3 years.
        self.fresh_feed = Feed.objects.create(
            feed_address="http://example.com/fresh.xml",
            feed_link="http://example.com/fresh",
            feed_title="Fresh Feed",
        )
        self.fresh_feed.last_story_date = now - datetime.timedelta(days=3)
        self.fresh_feed.save()

        self.stale_feed = Feed.objects.create(
            feed_address="http://example.com/stale.xml",
            feed_link="http://example.com/stale",
            feed_title="Stale Feed",
        )
        self.stale_feed.last_story_date = now - datetime.timedelta(days=3 * 365)
        self.stale_feed.save()

        for feed in (self.fresh_feed, self.stale_feed):
            PopularFeed.objects.create(
                feed=feed,
                feed_url=feed.feed_address,
                feed_type="rss",
                category="Test",
                title=feed.feed_title,
                is_active=True,
            )

    def _popular_titles(self, **params):
        params.setdefault("type", "rss")
        response = self.client.get("/discover/popular_feeds", params)
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.content)
        return set(entry["title"] for entry in data.get("feeds", []))

    def test_no_filter_returns_both_feeds(self):
        titles = self._popular_titles()
        self.assertIn("Fresh Feed", titles)
        self.assertIn("Stale Feed", titles)

    def test_staleness_year_hides_stale_feed(self):
        titles = self._popular_titles(staleness="year")
        self.assertIn("Fresh Feed", titles)
        self.assertNotIn("Stale Feed", titles)

    def test_staleness_month_hides_stale_feed(self):
        titles = self._popular_titles(staleness="month")
        self.assertIn("Fresh Feed", titles)
        self.assertNotIn("Stale Feed", titles)

    def test_staleness_any_is_a_no_op(self):
        titles = self._popular_titles(staleness="any")
        self.assertIn("Fresh Feed", titles)
        self.assertIn("Stale Feed", titles)

    def test_exclude_subscribed_hides_subscribed_feed(self):
        user = User.objects.create_user(username="discoverfilters", password="testpass", email="df@test.com")
        UserSubscription.objects.create(user=user, feed=self.fresh_feed)
        self.client.login(username="discoverfilters", password="testpass")

        titles = self._popular_titles(exclude_subscribed="true")
        self.assertNotIn("Fresh Feed", titles)
        self.assertIn("Stale Feed", titles)

    def test_exclude_subscribed_ignored_when_anonymous(self):
        # An anonymous request has no subscriptions, so the flag must not error.
        titles = self._popular_titles(exclude_subscribed="true")
        self.assertIn("Fresh Feed", titles)
        self.assertIn("Stale Feed", titles)

    def test_trending_endpoint_accepts_filter_params(self):
        response = self.client.get(
            "/discover/trending/", {"staleness": "month", "exclude_subscribed": "true"}
        )
        self.assertEqual(response.status_code, 200)

    def test_autocomplete_endpoint_accepts_filter_params(self):
        response = self.client.get(
            "/discover/autocomplete/",
            {"term": "fresh", "staleness": "year", "exclude_subscribed": "true"},
        )
        self.assertEqual(response.status_code, 200)
