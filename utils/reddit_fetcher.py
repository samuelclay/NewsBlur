"""Render subreddit, user, comment-thread and search Reddit feeds from RedListen.

Reddit blocked NewsBlur's API client in October 2026 and retires its RSS feeds on
13 Nov 2026, so Reddit data comes from RedListen (utils/redlisten.py), on a monthly
budget of requests and results. Every Reddit feed is rendered into an Atom feed that
the normal feedparser pipeline ingests, and each kind of feed spends differently:

  * Subreddit, multireddit and user feeds read the posts the hourly poller
    (utils/redlisten_poller.py) cached in utils/reddit_post_cache.py, so a scheduled
    fetch spends nothing. A fetch a reader asked for (insta-fetch, refresh, retry:
    options["reader_requested"], set by Feed.update in apps/rss_feeds/models.py) or a
    brand-new feed's first fetch asks RedListen directly as a one-off.
  * Comment-thread feeds (/comments/<id>/) and search feeds (/search?q=) cannot be
    batched, so each fetch is its own request, sized by how many new items the feed's
    last fetch found. The scheduler fetches them at most every 12 hours
    (reddit_fetch_floor_minutes, used by apps/rss_feeds/models.py).

RedListen serves the newest posts for every listing sort, so hot and top feeds read
as new. Reddit's front page, r/all and r/popular are not served. When the budget or
the per-minute limit is spent, fetch() returns None and sets self.rate_limited, so
utils/feed_fetcher.py records a 429 and the feed backs off. That is expected
backpressure, so it is a return flag rather than a raised exception.
See utils/reddit_fetcher.py.
"""

import datetime
import html
import json
import math
import re
import urllib.parse

import redis
import requests
from django.conf import settings
from django.utils import feedgenerator

from utils import log as logging
from utils.reddit_post_cache import (
    MAX_POSTS_PER_TARGET,
    RedditPostCache,
    subreddit_target,
    user_target,
)
from utils.redlisten import DENIED_BUDGET, ONE_OFF, SCHEDULED, RedListenClient

# How many posts a one-off live listing fetch asks for, the size of Reddit's .rss page.
LISTING_LIMIT = 25

# Matches the Reddit addresses utils/feed_fetcher.py routes here. Also used as a Postgres
# iregex by utils/redlisten_poller.py, so it sticks to syntax both understand.
REDDIT_ADDRESS_PATTERN = r"^(https?://)?([a-z0-9]+\.)?reddit\.com/"
REDDIT_ADDRESS_RE = re.compile(REDDIT_ADDRESS_PATTERN, re.IGNORECASE)

# What kind of Reddit feed an address is. See RedditFetcher.feed_kind().
KIND_LISTING = "listing"  # subreddit, multireddit or user: served by the poller's cache
KIND_COMMENTS = "comments"  # one post's comment thread: its own request
KIND_SEARCH = "search"  # a search query: its own request
KIND_PERSONAL_RSS = "personal_rss"  # Reddit's own tokenized RSS from /prefs/feeds/
KIND_UNSUPPORTED = "unsupported"  # front page, r/all, r/popular

# Scheduling floors per kind (apps/rss_feeds/models.py get_next_scheduled_update). The
# poller schedules a listing feed as soon as new posts land, so fetching one more often
# than the hourly poll only re-reads the cache.
POLLED_FEED_FLOOR_MINUTES = 60
SINGLE_FEED_FLOOR_MINUTES = 12 * 60
# A comment-thread or search feed doubles its floor for each fetch in a row that found
# nothing new, up to a week, and drops back to SINGLE_FEED_FLOOR_MINUTES when something
# arrives: most threads go quiet within days and would otherwise spend two requests a day.
SINGLE_FEED_MAX_FLOOR_MINUTES = 7 * 24 * 60

# Subreddit and user names as Reddit allows them; anything else never reaches a URL.
SUBREDDIT_NAME_RE = re.compile(r"^[A-Za-z0-9_]{2,21}$")
USERNAME_RE = re.compile(r"^[A-Za-z0-9_-]{3,20}$")
# Listings RedListen does not serve, or that would be the whole site.
UNSERVED_SUBREDDITS = {"all", "popular", "friends", "mod", "random", "randnsfw"}

# A comment-thread or search fetch asks for about 1.5x the new items the feed's last
# fetch found, within these bounds, since every returned item is billed. The state
# lives in Redis per feed (settings.REDIS_FEED_UPDATE_POOL).
SINGLE_FEED_STATE_KEY = "redlisten:feed:%s"
SINGLE_FEED_STATE_TTL = 60 * 60 * 24 * 30
SINGLE_FEED_MIN_LIMIT = 5
SINGLE_FEED_MAX_LIMIT = 25
SINGLE_FEED_FIRST_LIMIT = 10

# RedListen sorts threads by new, old or top only.
REDLISTEN_COMMENT_SORTS = {"new": "new", "old": "old"}
REDLISTEN_SEARCH_TIME_FILTERS = {"hour", "day", "week", "month", "year"}

# Listing sorts Reddit exposes as URL path segments (e.g. /r/python/new/.rss). The
# bare /r/<sub>/.rss feed is "hot", so that is our default.
VALID_SORTS = {"hot", "new", "top", "rising", "best", "controversial"}
DEFAULT_SORT = "hot"
VALID_TIME_FILTERS = {"hour", "day", "week", "month", "year", "all"}

# Individual-post ("comments") feeds: /r/<sub>/comments/<id>/<slug>/.rss. Reddit serves
# the submission plus its comment thread; we render the post and each comment as entries.
# The sort is a ?sort= query param on these URLs, and we default to newest-first so the
# feed surfaces fresh comments. See utils/reddit_fetcher.py.
COMMENT_SORTS = {"top", "best", "new", "old", "controversial", "qa", "confidence"}
DEFAULT_COMMENT_SORT = "new"
MAX_COMMENTS = 100

USER_AGENT = "NewsBlur/1.0 (+https://www.newsblur.com)"

# XML 1.0 forbids the C0/C1 control characters below (tab, newline, and carriage
# return stay legal), plus the noncharacters. Reddit titles and comment bodies carry
# them now and then. Matches the same scrub in utils/twitter_fetcher.py.
INVALID_XML_CHARS = re.compile(r"[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F-\x84\x86-\x9F\uFDD0-\uFDEF\uFFFE\uFFFF]")


def scrub_control_chars(value):
    """Strip XML-unserializable control characters out of feed strings.

    feedgenerator's writeString raises UnserializableContentError on these, which
    took down the whole feed fetch. Applied to the feed and item kwargs, so lists
    (categories) are scrubbed element by element and everything else, including the
    pubdate datetimes, passes through untouched. See utils/reddit_fetcher.py.
    """
    if isinstance(value, str):
        return INVALID_XML_CHARS.sub("", value)
    if isinstance(value, list):
        return [scrub_control_chars(item) for item in value]
    if isinstance(value, dict):
        return {key: scrub_control_chars(item) for key, item in value.items()}
    return value


MARKDOWN_LINK_RE = re.compile(r"\[([^\]\n]+)\]\((https?://[^\s)]+)\)")
BARE_URL_RE = re.compile(r"\bhttps?://[^\s<]+")
# Where a bare URL ends: at an escaped quote or angle bracket, and before trailing punctuation.
URL_STOPS = ("&quot;", "&#x27;", "&lt;", "&gt;")
URL_TRAILING_PUNCTUATION = ".,;:!?)]"
LIST_ITEM_RE = re.compile(r"^\s*([*+-]|\d+[.)])\s+")
HEADING_RE = re.compile(r"^#{1,6}\s+")


def markdown_inline(text):
    """Links, emphasis and code spans for one line of already-escaped markdown."""
    placeholders = []

    def hold(markup):
        placeholders.append(markup)
        return "\x00%s\x00" % (len(placeholders) - 1)

    def bare_link(match):
        url = match.group(0)
        for stop in URL_STOPS:
            url = url.split(stop)[0]
        url = url.rstrip(URL_TRAILING_PUNCTUATION)
        if not url:
            return match.group(0)
        return hold('<a href="%s">%s</a>' % (url, url)) + match.group(0)[len(url) :]

    text = re.sub(r"`([^`\n]+)`", lambda m: hold("<code>%s</code>" % m.group(1)), text)
    text = MARKDOWN_LINK_RE.sub(lambda m: hold('<a href="%s">%s</a>' % (m.group(2), m.group(1))), text)
    text = BARE_URL_RE.sub(bare_link, text)
    text = re.sub(r"\*\*(?=\S)(.+?)(?<=\S)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"(?<![\w*])\*(?=\S)(.+?)(?<=\S)\*(?![\w*])", r"<em>\1</em>", text)
    text = re.sub(r"~~(?=\S)(.+?)(?<=\S)~~", r"<del>\1</del>", text)
    return re.sub(r"\x00(\d+)\x00", lambda m: placeholders[int(m.group(1))], text)


def markdown_to_html(text):
    """Render Reddit post and comment markdown as simple HTML.

    RedListen sends Reddit text as markdown only (selftext_html and body_html are
    null), and no markdown library ships in the image, so this covers what Reddit
    posts lean on: paragraphs, line breaks, links, emphasis, code, quotes, lists and
    headings. The text is escaped first, quotes included, so no markup from the post
    survives and a quote in a link cannot leave its href. See utils/reddit_fetcher.py.
    """
    if not text:
        return ""
    escaped = html.escape(html.unescape(text), quote=True)
    escaped = escaped.replace("\r\n", "\n").replace("&amp;#x200B;", "").replace("&#x200B;", "")
    blocks = []
    for block in re.split(r"\n[ \t]*\n", escaped.strip()):
        lines = [line for line in block.split("\n") if line.strip()]
        if not lines:
            continue
        if block.startswith("```") or all(line.startswith("    ") for line in lines):
            code = "\n".join(line[4:] if line.startswith("    ") else line for line in lines)
            blocks.append("<pre><code>%s</code></pre>" % code.strip("`").strip("\n"))
        elif all(line.lstrip().startswith("&gt;") for line in lines):
            quoted = [markdown_inline(line.lstrip()[4:].strip()) for line in lines]
            blocks.append("<blockquote><p>%s</p></blockquote>" % "<br>".join(quoted))
        elif all(LIST_ITEM_RE.match(line) for line in lines):
            tag = "ol" if re.match(r"^\s*\d", lines[0]) else "ul"
            items = "".join("<li>%s</li>" % markdown_inline(LIST_ITEM_RE.sub("", line)) for line in lines)
            blocks.append("<%s>%s</%s>" % (tag, items, tag))
        elif len(lines) == 1 and HEADING_RE.match(lines[0]):
            blocks.append("<p><strong>%s</strong></p>" % markdown_inline(HEADING_RE.sub("", lines[0])))
        elif len(lines) == 1 and re.match(r"^\s*([-*_])(\s*\1){2,}\s*$", lines[0]):
            blocks.append("<hr>")
        else:
            blocks.append("<p>%s</p>" % "<br>".join(markdown_inline(line.strip()) for line in lines))
    return "".join(blocks)


def listing_targets(listing_path):
    """Poller cache targets for a listing path: ["r:python", "r:golang"] for
    r/python+golang, ["u:spez"] for user/spez/submitted, [] for anything unserved."""
    if not listing_path:
        return []
    if listing_path.startswith("user/"):
        name = listing_path.split("/")[1]
        return [user_target(name)] if USERNAME_RE.match(name) else []
    if listing_path.startswith("r/"):
        names = []
        for name in listing_path[2:].split("+"):
            if SUBREDDIT_NAME_RE.match(name) and name.lower() not in UNSERVED_SUBREDDITS:
                names.append(subreddit_target(name))
        return list(dict.fromkeys(names))
    return []


def is_reddit_address(address):
    return bool(address and REDDIT_ADDRESS_RE.match(address.strip()))


def reddit_fetch_floor_minutes(address, feed_id=None):
    """The shortest interval the scheduler may fetch this Reddit feed at, or None for
    feeds that are not Reddit or that spend nothing extra. A quiet comment-thread or
    search feed (feed_id given) backs off further. See utils/reddit_fetcher.py."""
    if not is_reddit_address(address):
        return None
    kind = RedditFetcher.for_address(address).feed_kind()
    if kind in (KIND_COMMENTS, KIND_SEARCH):
        quiet_fetches = 0
        if feed_id:
            fetcher = RedditFetcher(AddressOnlyFeed(address, pk=feed_id))
            quiet_fetches = fetcher.single_feed_state().get("quiet") or 0
        return min(SINGLE_FEED_FLOOR_MINUTES * 2**quiet_fetches, SINGLE_FEED_MAX_FLOOR_MINUTES)
    if kind == KIND_LISTING:
        return POLLED_FEED_FLOOR_MINUTES
    return None


def reddit_max_entries(address):
    """How many entries ProcessFeed (utils/feed_fetcher.py) may take from one fetch of
    this feed, or None for its usual cap. A subreddit or user feed renders every post the
    poller cached, up to one poll's worth for a target, and each was paid for, so all of
    them are processed."""
    if not is_reddit_address(address):
        return None
    if RedditFetcher.for_address(address).feed_kind() == KIND_LISTING:
        return MAX_POSTS_PER_TARGET
    return None


class AddressOnlyFeed:
    """Stands in for a Feed when only its address needs parsing (the poller and the
    scheduler classify thousands of addresses without loading feeds)."""

    def __init__(self, address, pk=None):
        self.pk = pk
        self.feed_address = address
        self.feed_link = ""
        self.feed_title = ""
        self.log_title = address or ""
        self.fetched_once = True


class RedditFetcher:
    def __init__(self, feed, options=None):
        self.feed = feed
        self.options = options or {}
        self.address = self.feed.feed_address or self.feed.feed_link or ""
        # Set True when a fetch is skipped because the RedListen budget or per-minute
        # limit is spent (ours or RedListen's own 429). This is expected backpressure,
        # not an error, so the caller reads the flag instead of catching an exception
        # and records a 429 in fetch history to back the feed off. See utils/feed_fetcher.py.
        self.rate_limited = False
        # Preserve HTTP failures, and say why when it is not obvious, for fetch history
        # in utils/feed_fetcher.py.
        self.http_error_status = None
        self.error_message = None

    @classmethod
    def for_address(cls, address):
        return cls(AddressOnlyFeed(address))

    def fetch(self):
        """Return an Atom feed string for this Reddit feed, or None if unfetchable.

        When the RedListen budget or per-minute limit is spent, returns None and sets
        self.rate_limited so the caller can record a 429 and back off. See
        utils/feed_fetcher.py.
        """
        kind = self.feed_kind()
        if kind == KIND_PERSONAL_RSS:
            return self.fetch_original_rss()
        if kind == KIND_COMMENTS:
            return self.fetch_comments_feed(self.extract_article_id())
        if kind == KIND_SEARCH:
            return self.fetch_search_feed(*self.extract_search_request())
        if kind == KIND_LISTING:
            listing_path, _, _ = self.extract_listing_request()
            return self.fetch_listing_feed(listing_path)

        logging.debug(
            "   ***> [%-30s] ~FRReddit feed is not served by RedListen: %s"
            % (self.feed.log_title[:30], self.address)
        )
        self.http_error_status = 404
        self.error_message = "Not a subreddit, multireddit or user feed Reddit data can be read for"
        return None

    def feed_kind(self):
        """Which KIND_* this feed's address is. See utils/reddit_fetcher.py."""
        if self.should_fetch_original_rss():
            return KIND_PERSONAL_RSS
        if self.extract_article_id():
            return KIND_COMMENTS
        if self.extract_search_request():
            return KIND_SEARCH
        listing_path, _, _ = self.extract_listing_request()
        if listing_targets(listing_path):
            return KIND_LISTING
        return KIND_UNSUPPORTED

    def poll_targets(self):
        """The poller cache targets this feed reads, or [] when the poller does not
        serve it (comment threads, searches, personal RSS, the front page)."""
        if self.feed_kind() != KIND_LISTING:
            return []
        listing_path, _, _ = self.extract_listing_request()
        return listing_targets(listing_path)

    def reader_requested(self):
        """True for a fetch a reader asked for (insta-fetch, refresh, retry). Not the
        same as options["force"], which utils/feed_fetcher.py also sets on a random 1% of
        scheduled fetches; Feed.update records the caller's intent before that."""
        return bool(self.options.get("reader_requested"))

    def spend_kind(self):
        """A fetch a reader asked for may spend the reserved last 1%."""
        return ONE_OFF if self.reader_requested() else SCHEDULED

    def note_failure(self, result):
        """Carry a failed RedListen call into the flags utils/feed_fetcher.py reads."""
        if result.throttled:
            self.rate_limited = True
            if result.denied == DENIED_BUDGET or result.error_code in (
                "quota_exceeded",
                "items_quota_exceeded",
            ):
                self.error_message = "Monthly Reddit budget reached"
        elif result.status and result.status != 200:
            self.http_error_status = result.status

    def parsed_url(self):
        """Return a parsed URL, accepting stored Reddit addresses without a scheme."""
        address = (self.address or "").strip()
        if address and "://" not in address:
            address = "https://" + address.lstrip("/")
        return urllib.parse.urlparse(address)

    def normalized_listing_segments(self):
        """Return path segments for a Reddit listing URL with feed suffixes removed."""
        path = self.parsed_url().path
        path = path.rstrip("/")
        for suffix in (".rss", ".xml"):
            if path.endswith(suffix):
                path = path[: -len(suffix)]
                break
        path = path.strip("/")
        return [seg for seg in path.split("/") if seg]

    def query_params(self):
        return urllib.parse.parse_qs(self.parsed_url().query)

    def first_query_value(self, params, key):
        value = params.get(key)
        if not value:
            return None
        return value[0]

    def should_fetch_original_rss(self):
        """True for Reddit's tokenized personal RSS URLs from /prefs/feeds/.

        RedListen has no logged-in view, so it cannot reproduce these public but
        personalized feeds, whose identity lives in the ?feed= token. Fetch the original
        RSS URL from Reddit for as long as Reddit serves it (Reddit retires RSS on
        13 Nov 2026).
        """
        return bool(self.first_query_value(self.query_params(), "feed"))

    def fetch_original_rss(self):
        """Fetch a tokenized Reddit RSS URL straight from Reddit."""
        try:
            resp = requests.get(self.address, headers={"User-Agent": USER_AGENT}, timeout=15)
        except requests.RequestException as e:
            logging.debug(
                "   ***> [%-30s] ~FRReddit original RSS request failed: %s: %s"
                % (self.feed.log_title[:30], self.address, e)
            )
            return None

        if resp.status_code != 200:
            self.http_error_status = resp.status_code
        if resp.status_code == 429:
            self.rate_limited = True
            return None
        if resp.status_code != 200:
            logging.debug(
                "   ***> [%-30s] ~FRReddit original RSS HTTP %s: %s"
                % (self.feed.log_title[:30], resp.status_code, self.address)
            )
            return None

        return resp.text

    def extract_listing_path_and_sort(self):
        """Map a Reddit feed URL to an OAuth API listing path and sort.

        Examples:
            https://www.reddit.com/r/python/.rss          -> ("r/python", "hot")
            https://www.reddit.com/r/python/new/.rss      -> ("r/python", "new")
            https://www.reddit.com/r/a+b+c/top.rss        -> ("r/a+b+c", "top")
            https://www.reddit.com/user/foo/.rss          -> ("user/foo/submitted", "new")
            https://reddit.com/.rss                       -> ("r/popular", "hot")

        Returns (listing_path, sort) or (None, None) when the URL is unrecognized.
        See utils/reddit_fetcher.py.
        """
        listing_path, sort, _ = self.extract_listing_request()
        return listing_path, sort

    def extract_listing_request(self):
        """Map a Reddit feed URL to an OAuth API listing request.

        Returns (listing_path, sort, query_params). query_params contains the small
        allowlist of Reddit listing filters that survive the RSS-to-API conversion.
        """
        segments = self.normalized_listing_segments()
        query = self.query_params()

        listing_path = None
        sort = DEFAULT_SORT
        explicit_sort = False

        # Home page (reddit.com/.rss or reddit.com/) -> the "popular" subreddit.
        if not segments or segments[0] in VALID_SORTS:
            if segments and segments[0] in VALID_SORTS:
                sort = segments[0]
                explicit_sort = True
            listing_path = "r/popular"
        elif segments[0] == "r" and len(segments) >= 2:
            subreddit = segments[1]
            if len(segments) >= 3 and segments[2] in VALID_SORTS:
                sort = segments[2]
                explicit_sort = True
            listing_path = f"r/{subreddit}"
        elif segments[0] in ("u", "user") and len(segments) >= 2:
            user = segments[1]
            # A user's posts live under /user/<name>/submitted; default to newest first.
            sort = "new"
            if len(segments) >= 3 and segments[2] in VALID_SORTS:
                sort = segments[2]
                explicit_sort = True
            listing_path = f"user/{user}/submitted"
        elif segments:
            # Fall back to treating the first segment as a subreddit name.
            if len(segments) >= 2 and segments[1] in VALID_SORTS:
                sort = segments[1]
                explicit_sort = True
            listing_path = f"r/{segments[0]}"

        query_sort = self.first_query_value(query, "sort")
        if query_sort in VALID_SORTS and not explicit_sort:
            sort = query_sort

        return listing_path, sort, self.listing_query_params(query, sort)

    def extract_search_request(self):
        """Map a Reddit search feed URL to a RedListen search, or None.

        Examples:
            https://www.reddit.com/search.rss?q=newsblur          -> ("/search.json", "newsblur", None)
            https://www.reddit.com/r/rss/search.rss?q=x&restrict_sr=1&t=week
                                                                  -> ("/r/rss/search.json", "x", "week")

        A subreddit search only stays in its subreddit with restrict_sr, as on Reddit.
        """
        segments = self.normalized_listing_segments()
        if "search" not in segments:
            return None
        query = self.query_params()
        q = (self.first_query_value(query, "q") or "").strip()
        if not q:
            return None
        time_filter = self.first_query_value(query, "t")
        if time_filter not in REDLISTEN_SEARCH_TIME_FILTERS:
            time_filter = None
        path = "/search.json"
        restrict = self.first_query_value(query, "restrict_sr") in ("1", "on", "true")
        if (
            restrict
            and len(segments) >= 3
            and segments[0] == "r"
            and segments[2] == "search"
            and SUBREDDIT_NAME_RE.match(segments[1])
        ):
            path = "/r/%s/search.json" % segments[1]
        return path, q, time_filter

    def listing_query_params(self, query, sort):
        """Preserve supported Reddit listing query filters through the API rewrite."""
        params = {}
        time_filter = self.first_query_value(query, "t")
        if sort in ("top", "controversial") and time_filter in VALID_TIME_FILTERS:
            params["t"] = time_filter
        return params

    def extract_article_id(self):
        """Return the base36 post id for an individual-post (comments) feed, else None.

        Reddit serves a single submission's comment thread at URLs like
        /r/<sub>/comments/<id>/<slug>/.rss (also /index.rss, /index.xml, old.reddit.com,
        and /user/<name>/comments/<id>/...). The id is always the segment right after
        "comments". See utils/reddit_fetcher.py.
        """
        path = self.address.split("?")[0].split("#")[0]
        if "reddit.com/" in path:
            path = path.split("reddit.com/", 1)[1]
        elif "reddit.com" in path:
            path = path.split("reddit.com", 1)[1]
        segments = [seg for seg in path.split("/") if seg]
        if "comments" in segments:
            idx = segments.index("comments")
            if idx + 1 < len(segments):
                article_id = segments[idx + 1]
                if article_id.isalnum():
                    return article_id
        return None

    def comment_sort(self):
        """Read the ?sort= comment ordering off the feed URL, defaulting to newest."""
        query = urllib.parse.urlparse(self.address).query
        sort = urllib.parse.parse_qs(query).get("sort", [None])[0]
        if sort in COMMENT_SORTS:
            return sort
        return DEFAULT_COMMENT_SORT

    def fetch_comments_feed(self, article_id):
        """Fetch a single submission and its newest comments as an Atom feed string.

        Returns None on failure. When throttled it also sets self.rate_limited so the
        caller can record a 429. See utils/reddit_fetcher.py.
        """
        limit = self.single_feed_limit()
        sort = REDLISTEN_COMMENT_SORTS.get(self.comment_sort(), "top")
        result = RedListenClient().get(
            "/comments/%s.json" % article_id,
            params={"sort": sort, "limit": limit},
            kind=self.spend_kind(),
            max_results=limit + 1,
        )
        if not result.ok:
            self.note_failure(result)
            return None

        try:
            post = result.payload[0]["data"]["children"][0]["data"]
            comment_children = result.payload[1]["data"]["children"]
        except (IndexError, KeyError, TypeError):
            logging.debug(
                "   ***> [%-30s] ~FRReddit comments unexpected payload: %s"
                % (self.feed.log_title[:30], self.address)
            )
            return None

        comments = []
        self.flatten_comments(comment_children, comments)
        self.save_single_feed_state(limit, [comment.get("created_utc") for comment in comments])
        return self.build_comments_feed(post, comment_children)

    def fetch_search_feed(self, path, q, time_filter):
        """Fetch the newest posts matching a Reddit search as an Atom feed string."""
        limit = self.single_feed_limit()
        # Reddit's search sorts by relevance by default; a feed wants the newest.
        params = {"q": q, "type": "link", "sort": "new", "limit": limit}
        if time_filter:
            params["t"] = time_filter
        result = RedListenClient().get(path, params=params, kind=self.spend_kind(), max_results=limit)
        if not result.ok:
            self.note_failure(result)
            return None

        try:
            children = result.payload["data"]["children"]
        except (KeyError, TypeError):
            logging.debug(
                "   ***> [%-30s] ~FRReddit search unexpected payload: %s"
                % (self.feed.log_title[:30], self.address)
            )
            return None

        posts = [child.get("data") or {} for child in children if child.get("kind") == "t3"]
        self.save_single_feed_state(limit, [post.get("created_utc") for post in posts])
        return self.build_feed("search?%s" % urllib.parse.urlencode({"q": q}), children)

    def fetch_listing_feed(self, listing_path):
        """Render a subreddit, multireddit or user feed from the poller's cache.

        Every post the cache retains is rendered, so a busy subreddit's whole hourly batch
        reaches the feed. A fetch a reader asked for, or the first fetch of a feed the
        poller has not reached yet, asks RedListen directly as a one-off first. If that
        fails, the cache still serves whatever it has. See utils/reddit_post_cache.py.
        """
        targets = listing_targets(listing_path)
        cache = RedditPostCache()
        first_fetch = not getattr(self.feed, "fetched_once", True) and not cache.has_any(targets)
        live_failed = False
        if self.reader_requested() or first_fetch:
            live_failed = not self.fetch_live_listing(listing_path, targets, cache)

        posts = cache.posts(targets)
        if live_failed and not posts:
            return None
        # Served from the cache after all, so a failed live call is not this fetch's result.
        self.rate_limited = False
        self.http_error_status = None
        self.error_message = None
        return self.build_feed(listing_path, [{"kind": "t3", "data": post} for post in posts])

    def fetch_live_listing(self, listing_path, targets, cache):
        """Ask RedListen for a listing's newest posts as a one-off and cache them.
        Returns True when RedListen answered."""
        if listing_path.startswith("user/"):
            path = "/user/%s/submitted.json" % targets[0][2:]
        else:
            path = "/r/%s/new.json" % "+".join(target[2:] for target in targets)
        result = RedListenClient().get(
            path, params={"limit": LISTING_LIMIT}, kind=ONE_OFF, max_results=LISTING_LIMIT
        )
        if not result.ok:
            self.note_failure(result)
            return False

        by_target = {}
        for child in (result.payload.get("data") or {}).get("children") or []:
            post = child.get("data") or {}
            if child.get("kind") != "t3" or not post.get("id"):
                continue
            if listing_path.startswith("user/"):
                target = targets[0]
            else:
                target = subreddit_target(post.get("subreddit") or "")
            by_target.setdefault(target, []).append(post)
        for target, posts in by_target.items():
            if target in targets:
                cache.add(target, posts)
        return True

    def build_comments_feed(self, post, comment_children):
        """Render a submission and its comments into an Atom feed string."""
        data = {
            "title": self.feed.feed_title or post.get("title") or "Reddit comments",
            "link": "https://www.reddit.com%s" % post.get("permalink", ""),
            "description": self.feed_description(),
            "lastBuildDate": datetime.datetime.utcnow(),
            "generator": "NewsBlur Reddit API Decrapifier - %s" % settings.NEWSBLUR_URL,
            "docs": None,
            "feed_url": self.address,
        }
        rss = feedgenerator.Atom1Feed(**scrub_control_chars(data))

        # Lead with the submission itself so the feed always carries the OP for context,
        # even before any comments arrive.
        op = self.story_data(post, skip_stickied=False)
        if op:
            rss.add_item(**scrub_control_chars(op))

        comments = []
        self.flatten_comments(comment_children, comments)
        for comment in comments:
            item = self.comment_story_data(comment)
            if item:
                rss.add_item(**scrub_control_chars(item))

        return rss.writeString("utf-8")

    def flatten_comments(self, children, acc):
        """Depth-first collect comment ('t1') data dicts, descending into replies.

        Caps at MAX_COMMENTS so a busy thread can't produce an unbounded feed. "more"
        stubs (collapsed comment links) are skipped.
        """
        for child in children:
            if len(acc) >= MAX_COMMENTS:
                return
            if child.get("kind") != "t1":
                continue
            comment = child.get("data") or {}
            acc.append(comment)
            replies = comment.get("replies")
            if isinstance(replies, dict):
                reply_children = replies.get("data", {}).get("children", [])
                self.flatten_comments(reply_children, acc)

    def comment_story_data(self, comment):
        """Turn one Reddit comment into a feedgenerator item dict, or None."""
        comment_id = comment.get("id")
        if not comment_id:
            return None

        author = comment.get("author") or "[deleted]"
        permalink = "https://www.reddit.com%s" % comment.get("permalink", "")
        # RedListen sends markdown only, so render body when body_html is absent.
        body_html = comment.get("body_html") or ""
        body = html.unescape(body_html) if body_html else markdown_to_html(comment.get("body"))

        snippet = " ".join((comment.get("body") or "").split())[:100]
        title = ("%s: %s" % (author, snippet)) if snippet else "Comment by %s" % author

        footer = '<p><a href="%s">[context]</a></p>' % permalink
        description = (body + footer) if body else footer

        created = comment.get("created_utc") or 0
        return {
            "title": title,
            "link": permalink,
            "description": description,
            "author_name": author,
            "categories": [],
            "unique_id": "reddit_comment:%s" % comment_id,
            "pubdate": datetime.datetime.utcfromtimestamp(created),
        }

    def build_feed(self, listing_path, children):
        """Render Reddit listing children into an Atom feed string."""
        data = {
            "title": self.feed.feed_title or listing_path,
            "link": f"https://www.reddit.com/{listing_path}",
            "description": self.feed_description(),
            "lastBuildDate": datetime.datetime.utcnow(),
            "generator": "NewsBlur Reddit API Decrapifier - %s" % settings.NEWSBLUR_URL,
            "docs": None,
            "feed_url": self.address,
        }
        rss = feedgenerator.Atom1Feed(**scrub_control_chars(data))

        for child in children:
            if child.get("kind") != "t3":
                continue
            story = self.story_data(child.get("data") or {})
            if story:
                rss.add_item(**scrub_control_chars(story))

        return rss.writeString("utf-8")

    def feed_description(self):
        """Reuse the feed's stored tagline so we avoid an extra /about API call."""
        try:
            return self.feed.data.feed_tagline or ""
        except Exception:
            return ""

    def story_data(self, post, skip_stickied=True):
        """Turn one Reddit post (t3 data) into a feedgenerator item dict, or None.

        skip_stickied is True for subreddit listings (pinned mod posts repeat and
        aren't the content stream) but False when this post is the OP of a comments
        feed, where we always want to include it.
        """
        post_id = post.get("id")
        if not post_id:
            return None
        if skip_stickied and post.get("stickied"):
            return None

        author = post.get("author") or "[deleted]"
        permalink = "https://www.reddit.com%s" % post.get("permalink", "")
        link = permalink

        categories = []
        subreddit = post.get("subreddit")
        if subreddit:
            categories.append(subreddit)
        flair = post.get("link_flair_text")
        if flair and flair not in categories:
            categories.append(flair)

        created = post.get("created_utc") or 0

        return {
            "title": post.get("title") or "(no title)",
            "link": link,
            "description": self.story_content(post, author, permalink),
            "author_name": author,
            "categories": categories,
            "unique_id": "reddit_post:%s" % post_id,
            "pubdate": datetime.datetime.utcfromtimestamp(created),
        }

    def story_content(self, post, author, permalink):
        """Build the HTML body for a post: selftext, images, and a footer.

        RedListen sends selftext as markdown, rendered by markdown_to_html; a post
        that carries selftext_html is used as is. Images are reattached from the post's
        media (galleries, direct image, media_urls, preview, or thumbnail) because
        Reddit's own .rss omits them. See utils/reddit_fetcher.py.
        """
        body = ""
        selftext_html = post.get("selftext_html")
        if selftext_html:
            body += html.unescape(selftext_html)
        elif post.get("selftext"):
            # RedListen sends markdown only. See markdown_to_html.
            body += markdown_to_html(post["selftext"])

        body += self.media_html(post)

        # For true link posts (an external article), link out to the source. Image,
        # gallery, and other reddit-hosted URLs are already shown inline above.
        if not post.get("is_self"):
            external = post.get("url")
            if external and not self.is_reddit_internal_url(external) and not self.is_image_url(external):
                body += '<p><a href="%s">%s</a></p>' % (external, external)

        footer = (
            '<p>Posted by <a href="https://www.reddit.com/user/%s">u/%s</a> &middot; '
            '<a href="%s">[comments]</a></p>' % (author, author, permalink)
        )
        return (body + footer) if body else footer

    def media_html(self, post):
        """Return <img> tags for a post's images: gallery, direct image, or fallbacks.

        Reddit serves images several different ways, and its .rss strips all of them,
        so we reattach them from the API payload. See utils/reddit_fetcher.py.
        """
        urls = []
        if post.get("is_gallery") or post.get("gallery_data"):
            urls = self.gallery_image_urls(post)
        elif post.get("post_hint") == "image" or self.is_image_url(post.get("url")):
            if post.get("url"):
                urls = [post["url"]]

        # RedListen lists a post's images (gallery items, link previews) in media_urls.
        if not urls:
            urls = self.media_url_images(post)

        # Fall back to the preview source, then a real thumbnail, for anything else
        # that carries an image (e.g. link posts with a rich preview).
        if not urls:
            source = self.preview_source_url(post)
            if source:
                urls = [source]
        if not urls:
            thumb = post.get("thumbnail") or ""
            if thumb.startswith("http"):
                urls = [thumb]

        # Reddit media URLs are HTML-escaped (&amp;) even under raw_json=1.
        return "".join('<p><img src="%s" /></p>' % html.unescape(u) for u in urls if u)

    def gallery_image_urls(self, post):
        """Extract ordered image URLs from a Reddit gallery post's media_metadata."""
        media_metadata = post.get("media_metadata") or {}
        if not media_metadata:
            return []
        gallery_items = (post.get("gallery_data") or {}).get("items") or []
        # Honor the gallery's ordering when present; otherwise take whatever media exists.
        media_ids = [item.get("media_id") for item in gallery_items] or list(media_metadata.keys())

        urls = []
        for media_id in media_ids:
            meta = media_metadata.get(media_id) or {}
            if meta.get("status") and meta["status"] != "valid":
                continue
            source = meta.get("s") or {}
            # Animated gallery items expose gif/mp4 instead of a still under "u".
            url = source.get("u") or source.get("gif") or source.get("mp4")
            if url:
                urls.append(url)
        return urls

    def media_url_images(self, post):
        """Image URLs from RedListen's media_urls, one per image. RedListen lists the
        full-size image first and then smaller renditions of it (?width=140...), and
        streaming video manifests that an <img> cannot show."""
        urls = []
        seen_paths = set()
        for url in post.get("media_urls") or []:
            if not isinstance(url, str) or not url.startswith("http"):
                continue
            path = html.unescape(url).split("?")[0]
            if path in seen_paths or path.lower().endswith((".m3u8", ".mpd")):
                continue
            seen_paths.add(path)
            urls.append(url)
        return urls

    def preview_source_url(self, post):
        """Return the full-size Reddit preview image URL, if the post has one."""
        try:
            return post["preview"]["images"][0]["source"]["url"]
        except (KeyError, IndexError, TypeError):
            return None

    def is_image_url(self, url):
        """True when a URL points directly at an image file."""
        if not url:
            return False
        return url.split("?")[0].lower().endswith((".jpg", ".jpeg", ".png", ".gif", ".webp"))

    def is_reddit_internal_url(self, url):
        """True for reddit-hosted URLs (gallery pages, i.redd.it, permalinks)."""
        return bool(url) and ("reddit.com/" in url or "redd.it" in url)

    # --- Per-feed page sizing for comment-thread and search feeds ------------------

    def redis_connection(self):
        return redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)

    def single_feed_state(self):
        if not getattr(self.feed, "pk", None):
            return {}
        raw = self.redis_connection().get(SINGLE_FEED_STATE_KEY % self.feed.pk)
        try:
            return json.loads(raw) if raw else {}
        except ValueError:
            return {}

    def single_feed_limit(self):
        """How many items to ask for: every item returned is billed, so a thread that
        has gone quiet asks for a few and a busy one asks for more. A fetch a reader
        asked for always takes the full page."""
        if self.reader_requested():
            return SINGLE_FEED_MAX_LIMIT
        return self.single_feed_state().get("limit") or SINGLE_FEED_FIRST_LIMIT

    def save_single_feed_state(self, limit, created_times):
        """Size the next fetch from how many items this one found that the last one
        had not: about 1.5x that, or the full page when every item was new. Also count
        fetches in a row that found nothing new, which stretch the feed's scheduling floor
        (reddit_fetch_floor_minutes)."""
        if not getattr(self.feed, "pk", None):
            return
        created_times = [created for created in created_times if created]
        previous = self.single_feed_state()
        previous_newest = previous.get("newest") or 0
        new_count = sum(1 for created in created_times if created > previous_newest)
        if created_times and new_count >= limit:
            next_limit = SINGLE_FEED_MAX_LIMIT
        else:
            next_limit = math.ceil(new_count * 1.5) + 3
        next_limit = max(SINGLE_FEED_MIN_LIMIT, min(SINGLE_FEED_MAX_LIMIT, next_limit))
        quiet = 0 if new_count else (previous.get("quiet") or 0) + 1
        state = {"limit": next_limit, "newest": max(created_times + [previous_newest]), "quiet": quiet}
        self.redis_connection().set(
            SINGLE_FEED_STATE_KEY % self.feed.pk, json.dumps(state), ex=SINGLE_FEED_STATE_TTL
        )
