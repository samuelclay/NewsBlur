"""Unit tests for utils/reddit_fetcher.py.

These avoid the database and the network: the feed is a small stub, Redis is a
MagicMock, and requests is patched. See utils/reddit_fetcher.py.
"""

from unittest.mock import MagicMock, patch

import feedparser
from django.test import SimpleTestCase

from utils.reddit_fetcher import MAX_COMMENTS, REDDIT_REQUESTS_PER_MINUTE, RedditFetcher


class StubFeedData:
    feed_tagline = "A subreddit feed"


class StubFeed:
    """Minimal stand-in for a Feed model so the fetcher needs no database."""

    def __init__(self, feed_address, feed_link="", feed_title="r/python"):
        self.feed_address = feed_address
        self.feed_link = feed_link
        self.feed_title = feed_title
        self.log_title = feed_title
        self.data = StubFeedData()


def make_post(**overrides):
    post = {
        "id": "abc123",
        "title": "Hello world",
        "permalink": "/r/python/comments/abc123/hello_world/",
        "url": "https://example.com/article",
        "author": "someuser",
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


class TestRateLimiter(SimpleTestCase):
    def _fetcher_with_redis(self, redis_mock):
        fetcher = RedditFetcher(StubFeed("https://www.reddit.com/r/python/.rss"))
        fetcher.redis_connection = MagicMock(return_value=redis_mock)
        return fetcher

    def test_reserves_until_limit(self):
        redis_mock = MagicMock()
        redis_mock.ttl.return_value = 30
        fetcher = self._fetcher_with_redis(redis_mock)

        # The Nth call returns N from INCR; allowed while N <= limit.
        redis_mock.incr.return_value = REDDIT_REQUESTS_PER_MINUTE
        self.assertTrue(fetcher.reserve_rate_limit_slot())

        redis_mock.incr.return_value = REDDIT_REQUESTS_PER_MINUTE + 1
        self.assertFalse(fetcher.reserve_rate_limit_slot())

    def test_sets_expiry_on_first_request_of_window(self):
        redis_mock = MagicMock()
        redis_mock.incr.return_value = 1
        fetcher = self._fetcher_with_redis(redis_mock)

        fetcher.reserve_rate_limit_slot()
        redis_mock.expire.assert_called_once()

    def test_repairs_missing_expiry(self):
        redis_mock = MagicMock()
        redis_mock.incr.return_value = 5
        redis_mock.ttl.return_value = -1  # key exists but has no expiry
        fetcher = self._fetcher_with_redis(redis_mock)

        fetcher.reserve_rate_limit_slot()
        redis_mock.expire.assert_called_once()

    def test_fetch_listing_flags_rate_limited_when_budget_spent(self):
        fetcher = RedditFetcher(StubFeed("https://www.reddit.com/r/python/.rss"))
        fetcher.reserve_rate_limit_slot = MagicMock(return_value=False)
        self.assertIsNone(fetcher.fetch_listing("r/python", "hot"))
        self.assertTrue(fetcher.rate_limited)


class TestFetchListing(SimpleTestCase):
    def _fetcher(self):
        fetcher = RedditFetcher(StubFeed("https://www.reddit.com/r/python/.rss"))
        fetcher.reserve_rate_limit_slot = MagicMock(return_value=True)
        fetcher.access_token = MagicMock(return_value="token123")
        return fetcher

    @patch("utils.reddit_fetcher.requests.get")
    def test_returns_children_on_200(self, mock_get):
        mock_get.return_value = MagicMock(
            status_code=200,
            json=MagicMock(return_value={"data": {"children": [child(make_post())]}}),
        )
        fetcher = self._fetcher()
        children = fetcher.fetch_listing("r/python", "hot")
        self.assertEqual(len(children), 1)
        # Subreddit sort goes in the path, not the query.
        called_url = mock_get.call_args[0][0]
        self.assertEqual(called_url, "https://oauth.reddit.com/r/python/hot")

    @patch("utils.reddit_fetcher.requests.get")
    def test_user_listing_uses_sort_param(self, mock_get):
        mock_get.return_value = MagicMock(
            status_code=200, json=MagicMock(return_value={"data": {"children": []}})
        )
        fetcher = self._fetcher()
        fetcher.fetch_listing("user/foo/submitted", "new")
        called_url = mock_get.call_args[0][0]
        self.assertEqual(called_url, "https://oauth.reddit.com/user/foo/submitted")
        self.assertEqual(mock_get.call_args[1]["params"]["sort"], "new")

    @patch("utils.reddit_fetcher.requests.get")
    def test_429_flags_rate_limited(self, mock_get):
        mock_get.return_value = MagicMock(status_code=429)
        fetcher = self._fetcher()
        self.assertIsNone(fetcher.fetch_listing("r/python", "hot"))
        self.assertTrue(fetcher.rate_limited)

    @patch("utils.reddit_fetcher.requests.get")
    def test_401_clears_token_and_returns_none(self, mock_get):
        mock_get.return_value = MagicMock(status_code=401)
        fetcher = self._fetcher()
        fetcher.clear_cached_token = MagicMock()
        self.assertIsNone(fetcher.fetch_listing("r/python", "hot"))
        fetcher.clear_cached_token.assert_called_once()


class TestFetchEndToEnd(SimpleTestCase):
    @patch("utils.reddit_fetcher.requests.get")
    def test_full_fetch_produces_parseable_feed(self, mock_get):
        mock_get.return_value = MagicMock(
            status_code=200,
            json=MagicMock(
                return_value={
                    "data": {
                        "children": [
                            child(make_post(id="p1", title="First")),
                            child(make_post(id="p2", title="Second")),
                        ]
                    }
                }
            ),
        )
        fetcher = RedditFetcher(StubFeed("https://www.reddit.com/r/python/new/.rss"))
        fetcher.reserve_rate_limit_slot = MagicMock(return_value=True)
        fetcher.access_token = MagicMock(return_value="token123")

        xml = fetcher.fetch()
        parsed = feedparser.parse(xml)
        self.assertEqual(len(parsed.entries), 2)
        # The /new sort should be reflected in the requested path.
        self.assertEqual(mock_get.call_args[0][0], "https://oauth.reddit.com/r/python/new")


class TestAccessToken(SimpleTestCase):
    @patch("utils.reddit_fetcher.requests.post")
    def test_caches_token_with_ttl(self, mock_post):
        mock_post.return_value = MagicMock(
            status_code=200,
            json=MagicMock(return_value={"access_token": "tok", "expires_in": 86400}),
        )
        redis_mock = MagicMock()
        redis_mock.get.return_value = None
        fetcher = RedditFetcher(StubFeed("https://www.reddit.com/r/python/.rss"))
        fetcher.redis_connection = MagicMock(return_value=redis_mock)

        with self.settings(REDDIT_CLIENT_ID="id", REDDIT_CLIENT_SECRET="secret"):
            token = fetcher.access_token()

        self.assertEqual(token, "tok")
        # Token cached just under the reported expiry (86400 - 600).
        _, kwargs = redis_mock.set.call_args
        self.assertEqual(kwargs["ex"], 86400 - 600)

    def test_returns_cached_token_without_network(self):
        redis_mock = MagicMock()
        redis_mock.get.return_value = "cached-token"
        fetcher = RedditFetcher(StubFeed("https://www.reddit.com/r/python/.rss"))
        fetcher.redis_connection = MagicMock(return_value=redis_mock)
        self.assertEqual(fetcher.access_token(), "cached-token")


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


class TestFetchCommentsEndToEnd(SimpleTestCase):
    def _fetcher(self):
        fetcher = RedditFetcher(StubFeed("https://www.reddit.com/r/python/comments/abc123/t/.rss"))
        fetcher.reserve_rate_limit_slot = MagicMock(return_value=True)
        fetcher.access_token = MagicMock(return_value="tok")
        return fetcher

    @patch("utils.reddit_fetcher.requests.get")
    def test_full_comments_fetch(self, mock_get):
        payload = comments_payload(
            make_post(id="abc123", title="OP"), [comment_child(make_comment(id="c1", author="alice"))]
        )
        mock_get.return_value = MagicMock(status_code=200, json=MagicMock(return_value=payload))
        parsed = feedparser.parse(self._fetcher().fetch())

        self.assertEqual(len(parsed.entries), 2)
        # Routed to the comments endpoint, not a subreddit listing.
        self.assertEqual(mock_get.call_args[0][0], "https://oauth.reddit.com/comments/abc123")

    @patch("utils.reddit_fetcher.requests.get")
    def test_comments_429_flags_rate_limited(self, mock_get):
        mock_get.return_value = MagicMock(status_code=429)
        fetcher = self._fetcher()
        self.assertIsNone(fetcher.fetch())
        self.assertTrue(fetcher.rate_limited)
