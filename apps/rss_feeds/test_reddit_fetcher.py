"""Unit tests for utils/reddit_fetcher.py.

These avoid the database and the network: the feed is a small stub, Redis is
apps/rss_feeds/fake_redis.py, RedListen calls are patched, and only the personal
RSS path patches requests. See utils/reddit_fetcher.py.
"""

import datetime
import json
import time
from unittest.mock import MagicMock, patch

import feedparser
from django.test import SimpleTestCase, TestCase

from apps.rss_feeds.fake_redis import FakeRedis
from apps.rss_feeds.models import Feed, MStory
from utils.feed_fetcher import (
    FEED_ERRHTTP,
    FEED_OK,
    MAX_ENTRIES_HIGH_VOLUME,
    MAX_ENTRIES_TO_PROCESS,
    FetchFeed,
    ProcessFeed,
)
from utils.reddit_fetcher import (
    MAX_COMMENTS,
    SINGLE_FEED_FIRST_LIMIT,
    SINGLE_FEED_MAX_LIMIT,
    SINGLE_FEED_STATE_KEY,
    RedditFetcher,
    markdown_to_html,
    reddit_fetch_floor_minutes,
)
from utils.reddit_post_cache import MAX_POSTS_PER_TARGET, RedditPostCache
from utils.redlisten import (
    DENIED_BUDGET,
    DENIED_RATE_LIMIT,
    ONE_OFF,
    SCHEDULED,
    RedListenResult,
)


class StubFeedData:
    feed_tagline = "A subreddit feed"


def patched_redlisten(result):
    """Patch the RedListenClient utils/reddit_fetcher.py builds; returns (patcher, client)."""
    client = MagicMock()
    client.get.return_value = result
    return patch("utils.reddit_fetcher.RedListenClient", return_value=client), client


class Test_RedditHTTPHistory(SimpleTestCase):
    """utils/feed_fetcher.py must record what actually happened, not relabel it as 404."""

    def fetch_history(self, address, fake_redis=None):
        feed = Feed(pk=1, feed_address=address, feed_title="Reddit", last_update=datetime.datetime.now())
        feed.fetched_once = True
        fake_redis = fake_redis or FakeRedis()
        with patch.object(Feed, "get_by_id", return_value=feed), patch.object(
            Feed, "save", return_value=feed
        ), patch.object(Feed, "save_feed_history") as history, patch(
            "utils.feed_fetcher.validate_public_url"
        ), patch.object(
            RedditFetcher, "redis_connection", return_value=fake_redis
        ), patch(
            "utils.reddit_fetcher.RedditPostCache", return_value=RedditPostCache(r=fake_redis)
        ):
            result, parsed = FetchFeed(feed.pk, {}).fetch()
        self.assertEqual(result, FEED_ERRHTTP)
        self.assertIsNone(parsed)
        history.assert_called_once()
        return history.call_args.args

    def test_redlisten_http_errors_keep_their_status_in_history(self):
        for address in (
            "https://www.reddit.com/r/python/comments/abc123/title/.rss",
            "https://www.reddit.com/search.rss?q=newsblur",
        ):
            for status in (401, 403, 404, 503):
                with self.subTest(address=address, status=status):
                    patcher, _ = patched_redlisten(RedListenResult(status=status))
                    with patcher:
                        self.assertEqual(self.fetch_history(address), (status, "Reddit fetch failed"))

    def test_throttling_is_recorded_as_429(self):
        address = "https://www.reddit.com/r/python/comments/abc123/title/.rss"
        cases = (
            (RedListenResult(denied=DENIED_RATE_LIMIT), "Reddit API rate limit reached"),
            (RedListenResult(status=429), "Reddit API rate limit reached"),
            (RedListenResult(denied=DENIED_BUDGET), "Monthly Reddit budget reached"),
            (RedListenResult(status=429, error_code="items_quota_exceeded"), "Monthly Reddit budget reached"),
        )
        for result, message in cases:
            with self.subTest(message=message):
                patcher, _ = patched_redlisten(result)
                with patcher:
                    self.assertEqual(self.fetch_history(address), (429, message))

    def test_personal_rss_errors_keep_their_status(self):
        address = "https://www.reddit.com/.rss?feed=example-token&user=alice"
        with patch("utils.reddit_fetcher.requests.get", return_value=MagicMock(status_code=403)):
            self.assertEqual(self.fetch_history(address)[0], 403)

    def test_front_page_says_why_it_is_not_fetched(self):
        patcher, client = patched_redlisten(RedListenResult(status=200, payload={}))
        with patcher:
            status, message = self.fetch_history("https://www.reddit.com/.rss")
        self.assertEqual(status, 404)
        self.assertIn("Not a subreddit", message)
        client.get.assert_not_called()

    def test_invalid_payload_does_not_record_success(self):
        patcher, _ = patched_redlisten(RedListenResult(status=200, payload={"unexpected": True}))
        with patcher:
            history = self.fetch_history("https://www.reddit.com/r/python/comments/abc123/title/.rss")
        self.assertEqual(history, (404, "Reddit fetch failed"))


class StubFeed:
    """Minimal stand-in for a Feed model so the fetcher needs no database."""

    def __init__(self, feed_address, feed_link="", feed_title="r/python", pk=7, fetched_once=True):
        self.pk = pk
        self.feed_address = feed_address
        self.feed_link = feed_link
        self.feed_title = feed_title
        self.log_title = feed_title
        self.fetched_once = fetched_once
        self.data = StubFeedData()


def make_post(**overrides):
    post = {
        "id": "abc123",
        "title": "Hello world",
        "permalink": "/r/python/comments/abc123/hello_world/",
        "url": "https://example.com/article",
        "author": "someuser",
        "subreddit": "python",
        "subreddit_name_prefixed": "r/python",
        "is_self": False,
        "stickied": False,
        "created_utc": 1700000000,
        "selftext_html": None,
        "link_flair_text": "News",
    }
    post.update(overrides)
    return post


def child(post):
    return {"kind": "t3", "data": post}


def make_comment(**overrides):
    comment = {
        "id": "c1",
        "author": "commenter",
        "body": "This is a comment body",
        "body_html": "<div>This is a comment body</div>",
        "permalink": "/r/python/comments/abc123/t/c1/",
        "created_utc": 1700000100,
        "replies": "",
    }
    comment.update(overrides)
    return comment


def comment_child(comment):
    return {"kind": "t1", "data": comment}


def comments_payload(post, comment_children):
    """Shape of Reddit's /comments/<id> API response: [post listing, comments listing]."""
    return [
        {"data": {"children": [{"kind": "t3", "data": post}]}},
        {"data": {"children": comment_children}},
    ]


class TestExtractListingPathAndSort(SimpleTestCase):
    def _parse(self, address):
        return RedditFetcher(StubFeed(address)).extract_listing_path_and_sort()

    def test_subreddit_hot_default(self):
        self.assertEqual(self._parse("https://www.reddit.com/r/python/.rss"), ("r/python", "hot"))

    def test_subreddit_new(self):
        self.assertEqual(self._parse("https://www.reddit.com/r/python/new/.rss"), ("r/python", "new"))

    def test_subreddit_top_without_slash(self):
        self.assertEqual(self._parse("https://www.reddit.com/r/python/top.rss"), ("r/python", "top"))

    def test_subreddit_query_sort(self):
        self.assertEqual(
            self._parse("https://old.reddit.com/r/technology/.rss?sort=top&t=month"),
            ("r/technology", "top"),
        )

    def test_multireddit_passthrough(self):
        self.assertEqual(self._parse("https://www.reddit.com/r/a+b+c/.rss"), ("r/a+b+c", "hot"))

    def test_home_page(self):
        self.assertEqual(self._parse("https://reddit.com/.rss"), ("r/popular", "hot"))

    def test_user_feed_defaults_to_new(self):
        self.assertEqual(self._parse("https://www.reddit.com/user/foo/.rss"), ("user/foo/submitted", "new"))

    def test_user_short_form(self):
        self.assertEqual(self._parse("https://www.reddit.com/u/foo/.rss"), ("user/foo/submitted", "new"))

    def test_falls_back_to_feed_link(self):
        feed = StubFeed(feed_address="", feed_link="https://www.reddit.com/r/django/.rss")
        self.assertEqual(RedditFetcher(feed).extract_listing_path_and_sort(), ("r/django", "hot"))


class TestBuildFeed(SimpleTestCase):
    def test_renders_posts_into_atom(self):
        fetcher = RedditFetcher(StubFeed("https://www.reddit.com/r/python/.rss"))
        children = [
            child(make_post(id="p1", title="Link post", is_self=False)),
            child(
                make_post(
                    id="p2",
                    title="Self post",
                    is_self=True,
                    url="https://www.reddit.com/r/python/comments/p2/self/",
                    selftext_html="<div>Body text</div>",
                )
            ),
        ]
        xml = fetcher.build_feed("r/python", children)
        parsed = feedparser.parse(xml)

        self.assertEqual(len(parsed.entries), 2)
        titles = {e.title for e in parsed.entries}
        self.assertEqual(titles, {"Link post", "Self post"})
        # The self post's body should be carried through.
        self_entry = next(e for e in parsed.entries if e.title == "Self post")
        self.assertIn("Body text", self_entry.summary)
        # Every entry links to a comments permalink in its body.
        self.assertIn("[comments]", self_entry.summary)

    def test_skips_stickied_posts(self):
        fetcher = RedditFetcher(StubFeed("https://www.reddit.com/r/python/.rss"))
        children = [
            child(make_post(id="pinned", stickied=True)),
            child(make_post(id="real", stickied=False)),
        ]
        xml = fetcher.build_feed("r/python", children)
        parsed = feedparser.parse(xml)
        self.assertEqual(len(parsed.entries), 1)
        self.assertEqual(parsed.entries[0].id, "reddit_post:real")

    def test_ignores_non_post_children(self):
        fetcher = RedditFetcher(StubFeed("https://www.reddit.com/r/python/.rss"))
        children = [{"kind": "t1", "data": {"id": "comment"}}, child(make_post(id="real"))]
        xml = fetcher.build_feed("r/python", children)
        parsed = feedparser.parse(xml)
        self.assertEqual(len(parsed.entries), 1)

    def test_post_link_points_to_comments_permalink(self):
        fetcher = RedditFetcher(StubFeed("https://www.reddit.com/r/cincinnati/.rss"))
        post = make_post(
            id="photo",
            title="Photo thread",
            permalink="/r/cincinnati/comments/photo/photo_thread/",
            url="https://i.redd.it/photo.jpeg",
            post_hint="image",
        )
        xml = fetcher.build_feed("r/cincinnati", [child(post)])
        parsed = feedparser.parse(xml)

        self.assertEqual(
            parsed.entries[0].link,
            "https://www.reddit.com/r/cincinnati/comments/photo/photo_thread/",
        )
        self.assertIn("https://i.redd.it/photo.jpeg", parsed.entries[0].summary)

    def test_subreddit_category_is_rendered_as_story_tag(self):
        fetcher = RedditFetcher(StubFeed("https://old.reddit.com/r/worldnews/.rss"))
        post = make_post(
            id="world",
            subreddit="worldnews",
            subreddit_name_prefixed="r/worldnews",
            link_flair_text=None,
        )
        xml = fetcher.build_feed("r/worldnews", [child(post)])
        parsed = feedparser.parse(xml)

        tags = Feed().get_tags(parsed.entries[0])
        self.assertIn("worldnews", tags)


class FetcherTestCase(SimpleTestCase):
    """Runs a RedditFetcher against fake Redis, with RedListen patched per test."""

    def setUp(self):
        self.redis = FakeRedis()
        self.cache = RedditPostCache(r=self.redis)
        patches = [
            patch("utils.reddit_fetcher.RedditPostCache", return_value=self.cache),
            patch.object(RedditFetcher, "redis_connection", return_value=self.redis),
        ]
        for patcher in patches:
            patcher.start()
            self.addCleanup(patcher.stop)

    def fetcher(self, address, reader_requested=False, fetched_once=True, options=None):
        options = options if options is not None else {"reader_requested": reader_requested}
        return RedditFetcher(StubFeed(address, fetched_once=fetched_once), options)

    def redlisten(self, result):
        patcher, client = patched_redlisten(result)
        patcher.start()
        self.addCleanup(patcher.stop)
        return client


class TestListingFeedsReadThePollerCache(FetcherTestCase):
    def test_scheduled_fetch_reads_the_cache_without_spending(self):
        self.cache.add("r:python", [make_post(id="p1", title="First"), make_post(id="p2", title="Second")])
        client = self.redlisten(RedListenResult(status=200, payload={}))

        parsed = feedparser.parse(self.fetcher("https://www.reddit.com/r/python/top.rss?t=week").fetch())

        self.assertEqual({entry.title for entry in parsed.entries}, {"First", "Second"})
        client.get.assert_not_called()

    def test_multireddit_merges_its_subreddits_newest_first(self):
        self.cache.add("r:python", [make_post(id="py", created_utc=1700000100)])
        self.cache.add("r:golang", [make_post(id="go", subreddit="golang", created_utc=1700000200)])
        self.redlisten(RedListenResult(status=200, payload={}))

        parsed = feedparser.parse(self.fetcher("https://old.reddit.com/r/Python+golang/.rss").fetch())

        self.assertEqual([entry.id for entry in parsed.entries], ["reddit_post:go", "reddit_post:py"])

    def test_forced_fetch_asks_redlisten_as_a_one_off_and_caches(self):
        payload = {"data": {"children": [child(make_post(id="fresh", subreddit="Python"))]}}
        client = self.redlisten(RedListenResult(status=200, payload=payload, results=1))

        parsed = feedparser.parse(
            self.fetcher("https://www.reddit.com/r/python+golang/.rss", reader_requested=True).fetch()
        )

        self.assertEqual(parsed.entries[0].id, "reddit_post:fresh")
        path = client.get.call_args[0][0]
        self.assertEqual(path, "/r/python+golang/new.json")
        self.assertEqual(client.get.call_args[1]["kind"], ONE_OFF)
        self.assertEqual([post["id"] for post in self.cache.posts(["r:python"])], ["fresh"])

    def test_forced_user_fetch_reads_their_submissions(self):
        client = self.redlisten(RedListenResult(status=200, payload={"data": {"children": []}}))
        self.fetcher("https://www.reddit.com/user/Spez/.rss", reader_requested=True).fetch()
        self.assertEqual(client.get.call_args[0][0], "/user/spez/submitted.json")

    def test_first_fetch_of_a_new_feed_goes_live(self):
        client = self.redlisten(RedListenResult(status=200, payload={"data": {"children": []}}))
        self.fetcher("https://www.reddit.com/r/python/.rss", fetched_once=False).fetch()
        client.get.assert_called_once()

    def test_failed_one_off_falls_back_to_the_cache(self):
        self.cache.add("r:python", [make_post(id="cached")])
        self.redlisten(RedListenResult(denied=DENIED_BUDGET))
        fetcher = self.fetcher("https://www.reddit.com/r/python/.rss", reader_requested=True)

        parsed = feedparser.parse(fetcher.fetch())

        self.assertEqual(parsed.entries[0].id, "reddit_post:cached")
        self.assertFalse(fetcher.rate_limited)

    def test_failed_one_off_with_an_empty_cache_is_throttled(self):
        self.redlisten(RedListenResult(denied=DENIED_BUDGET))
        fetcher = self.fetcher("https://www.reddit.com/r/python/.rss", reader_requested=True)
        self.assertIsNone(fetcher.fetch())
        self.assertTrue(fetcher.rate_limited)
        self.assertEqual(fetcher.error_message, "Monthly Reddit budget reached")


class TestCachedBatchesReachFeeds(FetcherTestCase):
    def test_a_busy_hour_reaches_the_feed_whole(self):
        now = int(time.time())
        posts = [make_post(id="p%d" % i, created_utc=now - 60 * i) for i in range(60)]
        self.assertEqual(self.cache.add("r:python", posts), 60)
        self.redlisten(RedListenResult(status=200, payload={}))

        parsed = feedparser.parse(self.fetcher("https://www.reddit.com/r/python/.rss").fetch())

        self.assertEqual(len(parsed.entries), 60)

    def test_old_posts_beyond_the_newest_25_age_out(self):
        posts = [make_post(id="old%d" % i, created_utc=1700000000 - i) for i in range(40)]
        self.cache.add("r:python", posts)
        self.assertEqual(len(self.cache.posts(["r:python"])), 25)

    def test_edited_posts_replace_their_cached_copy(self):
        self.cache.add("r:python", [make_post(id="p1", selftext="first draft")])
        self.assertEqual(self.cache.add("r:python", [make_post(id="p1", selftext="edited")]), 0)
        self.assertEqual(self.cache.posts(["r:python"])[0]["selftext"], "edited")


class Test_ProcessFeedEntryLimit(SimpleTestCase):
    def limit(self, address, options=None):
        process = ProcessFeed(1, None, options or {})
        process.feed = Feed(feed_address=address, feed_title="Feed")
        return process.entry_limit()

    def test_reddit_listings_take_a_whole_poll_batch(self):
        self.assertEqual(self.limit("https://www.reddit.com/r/python/.rss"), MAX_POSTS_PER_TARGET)
        self.assertEqual(self.limit("https://old.reddit.com/user/spez/.rss"), MAX_POSTS_PER_TARGET)

    def test_other_feeds_keep_their_caps(self):
        self.assertEqual(
            self.limit("https://www.reddit.com/r/python/comments/abc123/t/.rss"), MAX_ENTRIES_TO_PROCESS
        )
        self.assertEqual(self.limit("https://example.com/feed"), MAX_ENTRIES_TO_PROCESS)
        self.assertEqual(self.limit("https://export.arxiv.org/rss/cs.AI"), MAX_ENTRIES_HIGH_VOLUME)
        self.assertEqual(self.limit("https://www.reddit.com/r/python/.rss", {"max_stories": 7}), 7)


class Test_RedditBatchIngestion(TestCase):
    @patch("apps.rss_feeds.models.Feed.save_feed_history")
    @patch("apps.rss_feeds.models.Feed.update_all_statistics")
    @patch("apps.rss_feeds.models.redis")
    def test_a_poll_batch_over_100_posts_is_all_stored(self, mock_redis, mock_statistics, mock_history):
        mock_redis.Redis.return_value.zrevrangebyscore.return_value = []
        feed = Feed.objects.create(
            feed_address="https://www.reddit.com/r/python/.rss",
            feed_link="https://www.reddit.com/r/python/",
            feed_title="r/python",
        )
        self.addCleanup(lambda: MStory.objects(story_feed_id=feed.pk).delete())
        now = int(time.time())
        children = [
            child(make_post(id="b%d" % i, title="Batch post %d" % i, created_utc=now - 30 * i))
            for i in range(150)
        ]
        fpf = feedparser.parse(RedditFetcher(StubFeed(feed.feed_address)).build_feed("r/python", children))

        process = ProcessFeed(feed.pk, fpf, {"verbose": False, "force": False, "updates_off": False})
        process.refresh_feed()
        result, counts = process.process()

        self.assertEqual(result, FEED_OK)
        self.assertEqual(counts["new"], 150)


class TestRandomlyForcedFetchesStayScheduled(FetcherTestCase):
    """utils/feed_fetcher.py forces a random 1% of scheduled fetches; those must not
    spend the one-off reserve."""

    def test_forced_but_not_reader_requested_listing_reads_the_cache(self):
        self.cache.add("r:python", [make_post(id="cached")])
        client = self.redlisten(RedListenResult(status=200, payload={}))
        self.fetcher("https://www.reddit.com/r/python/.rss", options={"force": True}).fetch()
        client.get.assert_not_called()

    def test_feed_fetcher_random_force_keeps_comment_fetches_scheduled(self):
        payload = comments_payload(make_post(id="abc123"), [])
        client = self.redlisten(RedListenResult(status=200, payload=payload))
        address = "https://www.reddit.com/r/python/comments/abc123/t/.rss"
        feed = Feed(pk=1, feed_address=address, feed_title="Reddit", last_update=datetime.datetime.now())
        with patch.object(Feed, "get_by_id", return_value=feed), patch.object(
            Feed, "save", return_value=feed
        ), patch.object(Feed, "save_feed_history"), patch("utils.feed_fetcher.validate_public_url"), patch(
            "utils.feed_fetcher.random.random", return_value=0.0
        ):
            fetch = FetchFeed(feed.pk, {})
            fetch.fetch()
        self.assertTrue(fetch.options["force"])
        self.assertEqual(client.get.call_args[1]["kind"], SCHEDULED)
        self.assertEqual(client.get.call_args[1]["params"]["limit"], SINGLE_FEED_FIRST_LIMIT)


class TestCommentThreadFeeds(FetcherTestCase):
    address = "https://www.reddit.com/r/python/comments/abc123/t/.rss"

    def thread(self, *comment_ids, created=1700000100):
        comments = [
            comment_child(make_comment(id=c, author="alice", created_utc=created)) for c in comment_ids
        ]
        return RedListenResult(
            status=200, payload=comments_payload(make_post(id="abc123", title="OP"), comments)
        )

    def test_scheduled_fetch_asks_for_a_small_page_of_newest_comments(self):
        client = self.redlisten(self.thread("c1"))

        parsed = feedparser.parse(self.fetcher(self.address).fetch())

        self.assertEqual(len(parsed.entries), 2)
        self.assertEqual(client.get.call_args[0][0], "/comments/abc123.json")
        kwargs = client.get.call_args[1]
        self.assertEqual(kwargs["params"], {"sort": "new", "limit": SINGLE_FEED_FIRST_LIMIT})
        self.assertEqual(kwargs["kind"], SCHEDULED)
        self.assertEqual(kwargs["max_results"], SINGLE_FEED_FIRST_LIMIT + 1)

    def test_forced_fetch_takes_a_full_page_on_the_reserve(self):
        client = self.redlisten(self.thread("c1"))
        self.fetcher(self.address, reader_requested=True).fetch()
        self.assertEqual(client.get.call_args[1]["params"]["limit"], SINGLE_FEED_MAX_LIMIT)
        self.assertEqual(client.get.call_args[1]["kind"], ONE_OFF)

    def test_quiet_threads_ask_for_less_next_time(self):
        self.redlisten(self.thread("c1"))
        self.fetcher(self.address).fetch()
        state = json.loads(self.redis.get(SINGLE_FEED_STATE_KEY % 7))
        # One new comment: ceil(1.5) + 3 = 5.
        self.assertEqual(state, {"limit": 5, "newest": 1700000100, "quiet": 0})

        # Nothing newer on the next fetch keeps it at the floor.
        self.redlisten(self.thread("c1"))
        self.fetcher(self.address).fetch()
        self.assertEqual(json.loads(self.redis.get(SINGLE_FEED_STATE_KEY % 7))["limit"], 5)

    def test_quiet_threads_back_off_and_new_comments_bring_them_back(self):
        floors = []
        for _ in range(6):
            self.redlisten(self.thread("c1"))
            self.fetcher(self.address).fetch()
            floors.append(reddit_fetch_floor_minutes(self.address, 7))
        # The first fetch found the comment; each fetch after it found nothing new.
        self.assertEqual(floors, [720, 1440, 2880, 5760, 10080, 10080])

        self.redlisten(self.thread("c1", "c2", created=1700000200))
        self.fetcher(self.address).fetch()
        self.assertEqual(reddit_fetch_floor_minutes(self.address, 7), 720)

    def test_busy_threads_take_a_full_page_next_time(self):
        self.redis.set(SINGLE_FEED_STATE_KEY % 7, json.dumps({"limit": 5, "newest": 1}))
        self.redlisten(self.thread("c1", "c2", "c3", "c4", "c5"))
        self.fetcher(self.address).fetch()
        self.assertEqual(
            json.loads(self.redis.get(SINGLE_FEED_STATE_KEY % 7))["limit"], SINGLE_FEED_MAX_LIMIT
        )

    def test_best_sort_reads_as_top(self):
        client = self.redlisten(self.thread("c1"))
        self.fetcher(self.address + "?sort=best").fetch()
        self.assertEqual(client.get.call_args[1]["params"]["sort"], "top")


class TestSearchFeeds(FetcherTestCase):
    def test_sitewide_search(self):
        payload = {"data": {"children": [child(make_post(id="s1", title="Match"))]}}
        client = self.redlisten(RedListenResult(status=200, payload=payload))

        parsed = feedparser.parse(
            self.fetcher("https://www.reddit.com/search.rss?q=newsblur&sort=new").fetch()
        )

        self.assertEqual(parsed.entries[0].title, "Match")
        self.assertEqual(client.get.call_args[0][0], "/search.json")
        self.assertEqual(
            client.get.call_args[1]["params"],
            {"q": "newsblur", "type": "link", "sort": "new", "limit": SINGLE_FEED_FIRST_LIMIT},
        )

    def test_restricted_subreddit_search_keeps_its_time_filter(self):
        client = self.redlisten(RedListenResult(status=200, payload={"data": {"children": []}}))
        self.fetcher("https://www.reddit.com/r/rss/search.rss?q=reader&restrict_sr=1&t=week").fetch()
        self.assertEqual(client.get.call_args[0][0], "/r/rss/search.json")
        self.assertEqual(client.get.call_args[1]["params"]["t"], "week")

    def test_unrestricted_subreddit_search_is_sitewide(self):
        fetcher = self.fetcher("https://www.reddit.com/r/rss/search.rss?q=reader")
        self.assertEqual(fetcher.extract_search_request(), ("/search.json", "reader", None))


class TestPersonalRSS(SimpleTestCase):
    @patch("utils.reddit_fetcher.requests.get")
    def test_tokenized_personalized_rss_fetches_original_url(self, mock_get):
        rss = """<?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0"><channel><title>reddit front page</title>
        <item><title>Personal post</title><link>https://www.reddit.com/r/example/comments/a/x/</link></item>
        </channel></rss>"""
        mock_get.return_value = MagicMock(status_code=200, text=rss)
        address = "https://www.reddit.com/.rss?feed=secret-token&user=alice"
        parsed = feedparser.parse(RedditFetcher(StubFeed(address)).fetch())

        self.assertEqual(parsed.feed.title, "reddit front page")
        self.assertEqual(parsed.entries[0].title, "Personal post")
        self.assertEqual(mock_get.call_args[0][0], address)


class TestFeedKindsAndScheduling(SimpleTestCase):
    def test_kinds_and_floors(self):
        cases = (
            ("https://www.reddit.com/r/python/.rss", "listing", ["r:python"], 60),
            ("https://old.reddit.com/r/Python+golang+all/top.rss", "listing", ["r:python", "r:golang"], 60),
            ("https://www.reddit.com/user/spez/.rss", "listing", ["u:spez"], 60),
            ("reddit.com/r/django/.rss", "listing", ["r:django"], 60),
            ("https://www.reddit.com/r/python/comments/abc123/t/.rss", "comments", [], 720),
            ("https://www.reddit.com/search.rss?q=newsblur", "search", [], 720),
            ("https://www.reddit.com/.rss?feed=token&user=alice", "personal_rss", [], None),
            ("https://www.reddit.com/.rss", "unsupported", [], None),
            ("https://www.reddit.com/r/all/.rss", "unsupported", [], None),
        )
        for address, kind, targets, floor in cases:
            with self.subTest(address=address):
                fetcher = RedditFetcher.for_address(address)
                self.assertEqual(fetcher.feed_kind(), kind)
                self.assertEqual(fetcher.poll_targets(), targets)
                self.assertEqual(reddit_fetch_floor_minutes(address), floor)
        self.assertIsNone(reddit_fetch_floor_minutes("https://example.com/r/python/.rss"))

    def test_floor_overrides_the_pro_boost(self):
        feed = Feed(
            feed_address="https://www.reddit.com/r/python/comments/abc123/t/.rss",
            stories_last_month=300,
            active_subscribers=20,
            active_premium_subscribers=20,
            pro_subscribers=1,
            num_subscribers=20,
            last_story_date=datetime.datetime.now(),
        )
        with patch("apps.notifications.models.MUserFeedNotification.objects") as notifications:
            notifications.filter.return_value.count.return_value = 0
            self.assertEqual(feed.get_next_scheduled_update(force=True, verbose=False), 720)


class TestMarkdownToHtml(SimpleTestCase):
    def test_paragraphs_breaks_and_emphasis(self):
        html_out = markdown_to_html("Hey **all** and *you*\nsecond line\n\nNew ~~old~~ paragraph")
        self.assertEqual(
            html_out,
            "<p>Hey <strong>all</strong> and <em>you</em><br>second line</p><p>New <del>old</del> paragraph</p>",
        )

    def test_links_bare_urls_and_code(self):
        html_out = markdown_to_html("See [docs](https://x.com/a?b=1&c=2), https://e.com/p. and `x*y*z`")
        self.assertIn('<a href="https://x.com/a?b=1&amp;c=2">docs</a>', html_out)
        self.assertIn('<a href="https://e.com/p">https://e.com/p</a>.', html_out)
        self.assertIn("<code>x*y*z</code>", html_out)

    def test_quotes_lists_code_blocks_and_headings(self):
        html_out = markdown_to_html(
            "> quoted\n> more\n\n- one\n- two\n\n1. first\n\n    code <b>\n\n## Title"
        )
        self.assertIn("<blockquote><p>quoted<br>more</p></blockquote>", html_out)
        self.assertIn("<ul><li>one</li><li>two</li></ul>", html_out)
        self.assertIn("<ol><li>first</li></ol>", html_out)
        self.assertIn("<pre><code>code &lt;b&gt;</code></pre>", html_out)
        self.assertIn("<p><strong>Title</strong></p>", html_out)

    def test_a_quote_cannot_leave_an_href(self):
        for text in ('[x](https://a.com/"onmouseover="alert(1))', 'https://a.com/"onmouseover="alert(1)'):
            with self.subTest(text=text):
                html_out = markdown_to_html(text)
                self.assertNotIn('"onmouseover', html_out)
                self.assertNotIn('" onmouseover', html_out)
        self.assertIn(
            '<a href="https://a.com/">https://a.com/</a>&quot;', markdown_to_html('https://a.com/"x')
        )

    def test_markup_in_the_post_is_escaped(self):
        html_out = markdown_to_html("<script>alert(1)</script> &amp; [x](javascript:alert(1))")
        self.assertNotIn("<script>", html_out)
        self.assertNotIn('href="javascript', html_out)
        self.assertIn("&amp;", html_out)

    def test_redlisten_selftext_and_comment_bodies_render(self):
        fetcher = RedditFetcher(StubFeed("https://www.reddit.com/r/python/.rss"))
        body = fetcher.story_content(make_post(is_self=True, selftext="**Bold** body"), "a", "https://p")
        self.assertIn("<strong>Bold</strong> body", body)
        comment = fetcher.comment_story_data(make_comment(body="*hi*", body_html=None))
        self.assertIn("<em>hi</em>", comment["description"])


class TestExtractArticleId(SimpleTestCase):
    def _aid(self, url):
        return RedditFetcher(StubFeed(url)).extract_article_id()

    def test_standard_comments_rss(self):
        self.assertEqual(
            self._aid("https://www.reddit.com/r/python/comments/abc123/some_title/.rss"), "abc123"
        )

    def test_index_rss_suffix(self):
        self.assertEqual(
            self._aid("https://www.reddit.com/r/python/comments/abc123/some_title/index.rss"), "abc123"
        )

    def test_index_xml_trailing_slash(self):
        self.assertEqual(self._aid("https://www.reddit.com/r/sub/comments/18cyhj5/x/index.xml/"), "18cyhj5")

    def test_old_reddit_host(self):
        self.assertEqual(self._aid("https://old.reddit.com/r/awesomewm/comments/1fx33ed/4k/.rss"), "1fx33ed")

    def test_user_comments(self):
        self.assertEqual(self._aid("https://www.reddit.com/user/foo/comments/yr79mr/x/index.xml/"), "yr79mr")

    def test_subreddit_feed_is_not_comments(self):
        self.assertIsNone(self._aid("https://www.reddit.com/r/python/.rss"))

    def test_home_is_not_comments(self):
        self.assertIsNone(self._aid("https://www.reddit.com/.rss"))


class TestCommentSort(SimpleTestCase):
    def _sort(self, url):
        return RedditFetcher(StubFeed(url)).comment_sort()

    def test_defaults_to_new(self):
        self.assertEqual(self._sort("https://www.reddit.com/r/p/comments/a/x/.rss"), "new")

    def test_honors_query_param(self):
        self.assertEqual(self._sort("https://www.reddit.com/r/p/comments/a/x/.rss?sort=top"), "top")

    def test_ignores_invalid_query(self):
        self.assertEqual(self._sort("https://www.reddit.com/r/p/comments/a/x/.rss?sort=bogus"), "new")


class TestBuildCommentsFeed(SimpleTestCase):
    def _fetcher(self):
        return RedditFetcher(
            StubFeed("https://www.reddit.com/r/python/comments/abc123/t/.rss", feed_title="")
        )

    def test_op_first_then_comments(self):
        post = make_post(id="abc123", title="OP Title", is_self=True, selftext_html="<div>OP body</div>")
        children = [comment_child(make_comment(id="c1", author="alice"))]
        parsed = feedparser.parse(self._fetcher().build_comments_feed(post, children))

        self.assertEqual(len(parsed.entries), 2)
        self.assertEqual(parsed.entries[0].title, "OP Title")
        self.assertEqual(parsed.entries[0].id, "reddit_post:abc123")
        self.assertTrue(parsed.entries[1].title.startswith("alice:"))
        self.assertEqual(parsed.entries[1].id, "reddit_comment:c1")

    def test_flattens_nested_replies(self):
        reply = comment_child(make_comment(id="c2", author="bob"))
        parent = make_comment(id="c1", author="alice", replies={"data": {"children": [reply]}})
        parsed = feedparser.parse(
            self._fetcher().build_comments_feed(make_post(id="abc123"), [comment_child(parent)])
        )
        ids = {e.id for e in parsed.entries}
        self.assertIn("reddit_comment:c1", ids)
        self.assertIn("reddit_comment:c2", ids)

    def test_skips_more_stubs(self):
        children = [comment_child(make_comment(id="c1")), {"kind": "more", "data": {"id": "x"}}]
        parsed = feedparser.parse(self._fetcher().build_comments_feed(make_post(id="abc123"), children))
        # OP + one real comment; the "more" stub is skipped.
        self.assertEqual(len(parsed.entries), 2)

    def test_caps_at_max_comments(self):
        children = [comment_child(make_comment(id="c%d" % i)) for i in range(MAX_COMMENTS + 20)]
        parsed = feedparser.parse(self._fetcher().build_comments_feed(make_post(id="abc123"), children))
        # OP + MAX_COMMENTS comments.
        self.assertEqual(len(parsed.entries), MAX_COMMENTS + 1)


class TestMediaHtml(SimpleTestCase):
    def _fetcher(self):
        return RedditFetcher(StubFeed("https://www.reddit.com/r/stainedglass/.rss"))

    def test_gallery_images_in_gallery_order(self):
        post = make_post(
            id="g1",
            is_self=False,
            is_gallery=True,
            url="https://www.reddit.com/gallery/g1",
            gallery_data={"items": [{"media_id": "m2"}, {"media_id": "m1"}]},
            media_metadata={
                "m1": {"status": "valid", "s": {"u": "https://preview.redd.it/m1.jpg?s=x"}},
                "m2": {"status": "valid", "s": {"u": "https://preview.redd.it/m2.jpg"}},
            },
        )
        out = self._fetcher().media_html(post)
        self.assertEqual(out.count("<img"), 2)
        # Ordering follows gallery_data (m2 before m1), not dict insertion.
        self.assertLess(out.index("m2.jpg"), out.index("m1.jpg"))

    def test_gallery_skips_non_valid_items(self):
        post = make_post(
            id="g2",
            is_gallery=True,
            gallery_data={"items": [{"media_id": "ok"}, {"media_id": "bad"}]},
            media_metadata={
                "ok": {"status": "valid", "s": {"u": "https://preview.redd.it/ok.jpg"}},
                "bad": {"status": "failed", "s": {}},
            },
        )
        self.assertEqual(self._fetcher().media_html(post).count("<img"), 1)

    def test_gallery_animated_uses_mp4_or_gif(self):
        post = make_post(
            id="g3",
            is_gallery=True,
            media_metadata={"a": {"status": "valid", "s": {"gif": "https://preview.redd.it/a.gif"}}},
        )
        self.assertIn("a.gif", self._fetcher().media_html(post))

    def test_direct_image_post(self):
        post = make_post(id="i1", is_self=False, post_hint="image", url="https://i.redd.it/abc.jpeg")
        self.assertIn('src="https://i.redd.it/abc.jpeg"', self._fetcher().media_html(post))

    def test_image_url_without_post_hint(self):
        post = make_post(id="i2", is_self=False, post_hint=None, url="https://i.redd.it/x.png")
        self.assertEqual(self._fetcher().media_html(post).count("<img"), 1)

    def test_preview_source_fallback(self):
        post = make_post(
            id="l1",
            is_self=False,
            url="https://example.com/article",
            preview={"images": [{"source": {"url": "https://preview.redd.it/p.jpg"}}]},
        )
        self.assertIn("preview.redd.it/p.jpg", self._fetcher().media_html(post))

    def test_thumbnail_fallback(self):
        post = make_post(
            id="t1",
            is_self=False,
            url="https://example.com/article",
            thumbnail="https://b.thumbs.redditmedia.com/x.jpg",
        )
        self.assertIn("thumbs.redditmedia.com/x.jpg", self._fetcher().media_html(post))

    def test_text_self_post_has_no_media(self):
        post = make_post(
            id="s1", is_self=True, url="https://www.reddit.com/r/x/comments/s1/", thumbnail="self"
        )
        self.assertEqual(self._fetcher().media_html(post), "")

    def test_unescapes_reddit_amp_entities(self):
        post = make_post(
            id="g4",
            is_gallery=True,
            media_metadata={
                "a": {"status": "valid", "s": {"u": "https://preview.redd.it/a.jpg?w=1&amp;s=2"}}
            },
        )
        out = self._fetcher().media_html(post)
        self.assertIn("w=1&s=2", out)
        self.assertNotIn("&amp;", out)

    def test_external_article_link_added(self):
        post = make_post(id="a1", is_self=False, url="https://example.com/article")
        body = self._fetcher().story_content(post, "auth", "https://reddit.com/perm")
        self.assertIn("https://example.com/article", body)

    def test_no_external_link_for_image_post(self):
        post = make_post(id="i3", is_self=False, post_hint="image", url="https://i.redd.it/x.jpg")
        body = self._fetcher().story_content(post, "auth", "https://reddit.com/perm")
        self.assertIn("<img", body)
        self.assertNotIn('<a href="https://i.redd.it/x.jpg">', body)

    def test_is_image_url(self):
        f = self._fetcher()
        self.assertTrue(f.is_image_url("https://i.redd.it/x.JPG?width=1"))
        self.assertFalse(f.is_image_url("https://www.reddit.com/gallery/x"))

    def test_is_reddit_internal_url(self):
        f = self._fetcher()
        self.assertTrue(f.is_reddit_internal_url("https://i.redd.it/x.jpg"))
        self.assertTrue(f.is_reddit_internal_url("https://www.reddit.com/gallery/x"))
        self.assertFalse(f.is_reddit_internal_url("https://example.com/a"))

    def test_redlisten_media_urls_keep_one_rendition_per_image(self):
        post = make_post(
            id="m1",
            is_self=False,
            url="https://example.com/article",
            media_urls=[
                "https://external-preview.redd.it/a.png?auto=webp&amp;s=1",
                "https://external-preview.redd.it/a.png?width=140&amp;height=78&amp;s=2",
                "https://v.redd.it/x/HLSPlaylist.m3u8",
                "https://preview.redd.it/b.jpg?s=3",
            ],
        )
        out = self._fetcher().media_html(post)
        self.assertEqual(out.count("<img"), 2)
        self.assertIn("a.png?auto=webp&s=1", out)
        self.assertNotIn("width=140", out)
        self.assertNotIn("m3u8", out)
