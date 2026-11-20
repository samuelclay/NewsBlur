import datetime
import json
from unittest.mock import patch

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


class Test_FeedAutocompleteUrlTerm(TestCase):
    """A feed URL term answers that feed, then its site, and falls back to word matching."""

    def setUp(self):
        self.feed = Feed.objects.create(
            feed_address="https://julesblom.com/rss.xml",
            feed_link="https://julesblom.com/",
            feed_title="JulesBlom.com",
            num_subscribers=3,
        )
        self.sibling = Feed.objects.create(
            feed_address="https://julesblom.com/notes.xml",
            feed_link="https://julesblom.com/notes",
            feed_title="Jules Notes",
            num_subscribers=40,
        )
        self.subdomain = Feed.objects.create(
            feed_address="https://feeds.julesblom.com/main",
            feed_link="https://www.julesblom.com/",
            feed_title="Jules Main",
            num_subscribers=20,
        )
        self.hosted = Feed.objects.create(
            feed_address="https://feeds.feedburner.com/julesblom",
            feed_link="https://julesblom.com/",
            feed_title="Jules via FeedBurner",
            num_subscribers=10,
        )
        self.other_host = Feed.objects.create(
            feed_address="https://example.com/julesblom.xml",
            feed_link="https://example.com/",
            feed_title="Jules Blom Fan Page",
            num_subscribers=900,
        )
        self.site_search_ids = [self.other_host.pk, self.hosted.pk, self.subdomain.pk, self.sibling.pk]

    def _autocomplete(self, term, search_ids):
        with patch.object(Feed, "autocomplete", return_value=search_ids) as autocomplete:
            response = self.client.get("/discover/autocomplete", {"term": term, "v": 2})
        self.assertEqual(response.status_code, 200)
        feeds = json.loads(response.content)["feeds"]
        return [feed["id"] for feed in feeds], autocomplete

    def test_feed_url_term_answers_the_feed_then_its_site(self):
        feed_ids, autocomplete = self._autocomplete("https://julesblom.com/rss.xml", self.site_search_ids)

        self.assertEqual(feed_ids, [self.feed.pk, self.sibling.pk, self.subdomain.pk, self.hosted.pk])
        autocomplete.assert_called_once_with("julesblom.com", limit=20, semantic=False)

    def test_feed_url_term_forms(self):
        terms = [
            "julesblom.com/rss.xml",
            "JulesBlom.com/rss.xml",
            "www.julesblom.com/rss.xml",
            "HTTPS://julesblom.com/rss.xml",
            "https://www.julesblom.com/rss.xml",
            "feed://julesblom.com/rss.xml",
            "feed:https://julesblom.com/rss.xml",
            "//julesblom.com/rss.xml",
            "  https://julesblom.com/rss.xml  ",
        ]
        for term in terms:
            with self.subTest(term=term):
                feed_ids, autocomplete = self._autocomplete(term, [])
                self.assertEqual(feed_ids, [self.feed.pk])
                autocomplete.assert_called_once_with("julesblom.com", limit=20, semantic=False)

    def test_bare_host_and_non_http_terms_stay_name_searches(self):
        for term in ["julesblom.com", "node.js", "ftp://julesblom.com/rss.xml"]:
            with self.subTest(term=term):
                feed_ids, autocomplete = self._autocomplete(term, [self.other_host.pk])
                self.assertEqual(feed_ids, [self.other_host.pk])
                autocomplete.assert_called_once()
                self.assertNotIn("semantic", autocomplete.call_args.kwargs)

    def test_feed_url_term_matches_other_scheme_and_trailing_slash(self):
        feed_ids, _ = self._autocomplete("http://julesblom.com/rss.xml/", [])

        self.assertEqual(feed_ids, [self.feed.pk])

    def test_site_url_term_answers_feeds_on_the_site(self):
        feed_ids, autocomplete = self._autocomplete("https://www.julesblom.com/", self.site_search_ids)

        self.assertEqual(feed_ids, [self.sibling.pk, self.subdomain.pk, self.hosted.pk])
        autocomplete.assert_called_once_with("julesblom.com", limit=20, semantic=False)

    def test_feed_url_term_without_match_falls_back_to_word_matching(self):
        feed_ids, autocomplete = self._autocomplete("https://unknown.example/feed.xml", [self.other_host.pk])

        self.assertEqual(feed_ids, [self.other_host.pk])
        autocomplete.assert_any_call("unknown.example", limit=20, semantic=False)
        autocomplete.assert_called_with("unknown.example feed.xml", limit=20)

    def test_name_term_keeps_word_matching(self):
        feed_ids, autocomplete = self._autocomplete("jules blom", [self.other_host.pk, self.feed.pk])

        self.assertEqual(feed_ids, [self.other_host.pk, self.feed.pk])
        autocomplete.assert_called_once_with("jules blom", limit=20)


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
