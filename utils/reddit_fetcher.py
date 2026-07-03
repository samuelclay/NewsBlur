"""Fetch subreddit, user, and individual-post Reddit feeds through Reddit's API.

Reddit rate-limits unauthenticated .rss requests aggressively (HTTP 429), so this
module fetches subreddit/user listings and individual-post comment threads through
Reddit's OAuth2 app-only API instead and renders them into an Atom feed that the
normal feedparser pipeline can ingest. Individual-post feeds (/comments/<id>/.rss)
render the submission followed by its comments as entries.

Two pieces of shared coordination live in Redis (settings.REDIS_FEED_UPDATE_POOL),
so every celery fetch worker cooperates:

  * the OAuth2 app-only access token is cached and reused until shortly before it
    expires, so we only hit the token endpoint about once a day, and
  * a fixed one-minute-window counter keeps the whole fleet under Reddit's free-tier
    budget of ~100 requests/minute. When the budget for the current minute is spent,
    fetch() returns None and sets self.rate_limited, so utils/feed_fetcher.py records a
    429 in fetch history and the feed simply backs off until the next cycle. This is
    expected backpressure, so it is a return flag rather than a raised exception.

Credentials come from settings.REDDIT_CLIENT_ID / settings.REDDIT_CLIENT_SECRET.
See utils/reddit_fetcher.py.
"""

import datetime
import html
import urllib.parse

import redis
import requests
from django.conf import settings
from django.utils import feedgenerator

from utils import log as logging

# Reddit's free OAuth tier averages ~100 requests/minute per client. We cap the
# shared budget a little below that to leave headroom for the occasional token
# refresh and for the discover_subreddits batch job, which shares the same client.
REDDIT_REQUESTS_PER_MINUTE = getattr(settings, "REDDIT_API_REQUESTS_PER_MINUTE", 95)

# Redis keys (settings.REDIS_FEED_UPDATE_POOL, db 4) shared across all fetch workers.
TOKEN_CACHE_KEY = "reddit_api:access_token"
RATE_LIMIT_KEY = "reddit_api:ratelimit"

# How many posts to pull per fetch, matching the size of Reddit's default .rss page.
LISTING_LIMIT = 25

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


class RedditFetcher:
    def __init__(self, feed, options=None):
        self.feed = feed
        self.options = options or {}
        self.address = self.feed.feed_address or self.feed.feed_link or ""
        # Set True when a fetch is skipped because the shared per-minute Reddit budget
        # is spent (locally or per Reddit's own 429). This is expected backpressure,
        # not an error, so the caller reads the flag instead of catching an exception
        # and records a 429 in fetch history to back the feed off. See utils/feed_fetcher.py.
        self.rate_limited = False

    def fetch(self):
        """Return an Atom feed string for this Reddit feed, or None if unfetchable.

        When the shared minute budget is spent, returns None and sets self.rate_limited
        so the caller can record a 429 and back off. See utils/feed_fetcher.py.
        """
        if self.should_fetch_original_rss():
            return self.fetch_original_rss()

        # Individual-post feeds (/comments/<id>/) render the submission and its thread,
        # so they take a different API endpoint than subreddit/user listings.
        article_id = self.extract_article_id()
        if article_id:
            return self.fetch_comments_feed(article_id)

        listing_path, sort, query_params = self.extract_listing_request()
        if not listing_path:
            logging.debug(
                "   ***> [%-30s] ~FRReddit feed has no subreddit/user: %s"
                % (self.feed.log_title[:30], self.address)
            )
            return None

        children = self.fetch_listing(listing_path, sort, query_params=query_params)
        if children is None:
            return None

        return self.build_feed(listing_path, children)

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

        The OAuth app-only listing API cannot reproduce these public but personalized
        feeds, whose identity lives in the ?feed= token. Fetch the original RSS URL
        instead of rewriting it to r/popular.
        """
        return bool(self.first_query_value(self.query_params(), "feed"))

    def fetch_original_rss(self):
        """Fetch a tokenized Reddit RSS URL without converting it through OAuth."""
        try:
            resp = requests.get(self.address, headers={"User-Agent": USER_AGENT}, timeout=15)
        except requests.RequestException as e:
            logging.debug(
                "   ***> [%-30s] ~FRReddit original RSS request failed: %s: %s"
                % (self.feed.log_title[:30], self.address, e)
            )
            return None

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
        """Fetch a single submission and its comment thread as an Atom feed string.

        Returns None on failure. When throttled (locally or by Reddit) it also sets
        self.rate_limited so the caller can record a 429. See utils/reddit_fetcher.py.
        """
        if not self.reserve_rate_limit_slot():
            self.rate_limited = True
            return None

        token = self.access_token()
        if not token:
            return None

        url = "https://oauth.reddit.com/comments/%s" % article_id
        params = {"limit": MAX_COMMENTS, "raw_json": 1, "sort": self.comment_sort()}
        headers = {"Authorization": f"Bearer {token}", "User-Agent": USER_AGENT}
        try:
            resp = requests.get(url, params=params, headers=headers, timeout=15)
        except requests.RequestException as e:
            logging.debug(
                "   ***> [%-30s] ~FRReddit comments request failed: %s: %s"
                % (self.feed.log_title[:30], self.address, e)
            )
            return None

        if resp.status_code == 429:
            # Reddit disagrees with our local counter (clock skew, shared client); treat
            # it as backpressure too so the feed backs off.
            self.rate_limited = True
            return None
        if resp.status_code == 401:
            self.clear_cached_token()
            logging.debug(
                "   ***> [%-30s] ~FRReddit auth rejected (401): %s" % (self.feed.log_title[:30], self.address)
            )
            return None
        if resp.status_code != 200:
            logging.debug(
                "   ***> [%-30s] ~FRReddit comments HTTP %s: %s"
                % (self.feed.log_title[:30], resp.status_code, self.address)
            )
            return None

        try:
            payload = resp.json()
            post = payload[0]["data"]["children"][0]["data"]
            comment_children = payload[1]["data"]["children"]
        except (ValueError, IndexError, KeyError, TypeError):
            logging.debug(
                "   ***> [%-30s] ~FRReddit comments unexpected payload: %s"
                % (self.feed.log_title[:30], self.address)
            )
            return None

        return self.build_comments_feed(post, comment_children)

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
        rss = feedgenerator.Atom1Feed(**data)

        # Lead with the submission itself so the feed always carries the OP for context,
        # even before any comments arrive.
        op = self.story_data(post, skip_stickied=False)
        if op:
            rss.add_item(**op)

        comments = []
        self.flatten_comments(comment_children, comments)
        for comment in comments:
            item = self.comment_story_data(comment)
            if item:
                rss.add_item(**item)

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
        body_html = comment.get("body_html") or ""
        body = html.unescape(body_html) if body_html else ""

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

    def fetch_listing(self, listing_path, sort, query_params=None):
        """Fetch a Reddit listing through the OAuth API, returning its children list.

        Returns the list of post objects, or None on failure. When throttled (locally
        or by Reddit) it also sets self.rate_limited so the caller can record a 429.
        """
        if not self.reserve_rate_limit_slot():
            self.rate_limited = True
            return None

        token = self.access_token()
        if not token:
            return None

        params = {"limit": LISTING_LIMIT, "raw_json": 1}
        if query_params:
            params.update(query_params)

        # User listings take the sort as a query param; subreddit listings as a path.
        if listing_path.startswith("user/"):
            url = f"https://oauth.reddit.com/{listing_path}"
            params["sort"] = sort
        else:
            url = f"https://oauth.reddit.com/{listing_path}/{sort}"

        headers = {"Authorization": f"Bearer {token}", "User-Agent": USER_AGENT}
        try:
            resp = requests.get(url, params=params, headers=headers, timeout=15)
        except requests.RequestException as e:
            logging.debug(
                "   ***> [%-30s] ~FRReddit request failed: %s: %s"
                % (self.feed.log_title[:30], self.address, e)
            )
            return None

        if resp.status_code == 429:
            # Reddit disagrees with our local counter (clock skew, shared client).
            # Treat it the same as a local budget miss so the feed backs off.
            self.rate_limited = True
            return None
        if resp.status_code == 401:
            # The cached token is no longer valid; drop it so the next fetch re-auths.
            self.clear_cached_token()
            logging.debug(
                "   ***> [%-30s] ~FRReddit auth rejected (401): %s" % (self.feed.log_title[:30], self.address)
            )
            return None
        if resp.status_code != 200:
            logging.debug(
                "   ***> [%-30s] ~FRReddit HTTP %s: %s"
                % (self.feed.log_title[:30], resp.status_code, self.address)
            )
            return None

        try:
            children = resp.json().get("data", {}).get("children", [])
        except ValueError:
            logging.debug(
                "   ***> [%-30s] ~FRReddit returned non-JSON: %s" % (self.feed.log_title[:30], self.address)
            )
            return None

        return children

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
        rss = feedgenerator.Atom1Feed(**data)

        for child in children:
            if child.get("kind") != "t3":
                continue
            story = self.story_data(child.get("data") or {})
            if story:
                rss.add_item(**story)

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
        # Link posts point at the external article; self posts point at their permalink.
        link = post.get("url") or permalink

        categories = []
        flair = post.get("link_flair_text")
        if flair:
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

        We request listings with raw_json=1, so selftext_html already contains real
        HTML rather than entity-escaped markup. Images are reattached from the post's
        media (galleries, direct image, preview, or thumbnail) because Reddit's own
        .rss omits them. See utils/reddit_fetcher.py.
        """
        body = ""
        selftext_html = post.get("selftext_html")
        if selftext_html:
            body += html.unescape(selftext_html)

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

    # --- Shared Redis coordination (token cache + rate limiter) ------------------

    def redis_connection(self):
        return redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)

    def reserve_rate_limit_slot(self):
        """Atomically claim one slot in the shared per-minute Reddit API budget.

        Uses a fixed one-minute window: the first request of a window sets a 60s TTL,
        and at most REDDIT_REQUESTS_PER_MINUTE claims succeed before the window rolls
        over. Returns True if a slot was claimed, False if the budget is spent.
        See utils/reddit_fetcher.py.
        """
        r = self.redis_connection()
        count = r.incr(RATE_LIMIT_KEY)
        if count == 1:
            r.expire(RATE_LIMIT_KEY, 60)
        elif r.ttl(RATE_LIMIT_KEY) < 0:
            # Guard the rare case where the window key lost its expiry (e.g. a worker
            # crashed between INCR and EXPIRE) so the limiter can never wedge shut.
            r.expire(RATE_LIMIT_KEY, 60)
        return count <= REDDIT_REQUESTS_PER_MINUTE

    def access_token(self):
        """Return a cached OAuth2 app-only token, fetching a new one when needed."""
        r = self.redis_connection()
        token = r.get(TOKEN_CACHE_KEY)
        if token:
            return token

        client_id = getattr(settings, "REDDIT_CLIENT_ID", None)
        client_secret = getattr(settings, "REDDIT_CLIENT_SECRET", None)
        if not client_id or not client_secret:
            logging.debug("   ***> ~FRReddit API credentials are not configured")
            return None

        try:
            resp = requests.post(
                "https://www.reddit.com/api/v1/access_token",
                auth=(client_id, client_secret),
                data={"grant_type": "client_credentials"},
                headers={"User-Agent": USER_AGENT},
                timeout=10,
            )
        except requests.RequestException as e:
            logging.debug("   ***> ~FRReddit auth request failed: %s" % e)
            return None

        if resp.status_code != 200:
            logging.debug("   ***> ~FRReddit auth failed: HTTP %s" % resp.status_code)
            return None

        payload = resp.json()
        token = payload.get("access_token")
        if not token:
            return None

        # Cache until 10 minutes before Reddit says the token expires.
        ttl = max(int(payload.get("expires_in", 3600)) - 600, 60)
        r.set(TOKEN_CACHE_KEY, token, ex=ttl)
        return token

    def clear_cached_token(self):
        self.redis_connection().delete(TOKEN_CACHE_KEY)
