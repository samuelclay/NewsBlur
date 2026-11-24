"""apps/describe/web_preview.py: look at a site the web hunt found without saving anything.

The hunt in apps/describe/pipeline.py asks Claude for sites NewsBlur may not
know. Most searches turn up a few, and most of those are never subscribed to,
so a site must not become a Feed row (fetched forever after) just because a
search mentioned it. `preview_site` finds the site's feed, reads it once in
memory, and returns enough to judge it and draw a card. The Feed is created
later by /reader/add_url when someone subscribes, or by
/discover/link_popular_feed when someone previews it.
"""

import datetime
import html
import re
import socket
import threading
import time
from urllib.parse import urljoin, urlsplit, urlunsplit

import feedparser
import requests
from bs4 import BeautifulSoup
from django.utils.html import escape, strip_tags

from apps.describe.models import safe_http_url
from apps.rss_feeds.models import DuplicateFeed, Feed
from utils import feedfinder_forman, urlnorm
from utils.url_safety import (
    MAX_REDIRECTS,
    UnsafeUrlError,
    safe_requests_get,
    validate_public_url,
)

# apps/describe/web_preview.py: headlines kept per previewed site, and how much of a feed is parsed.
PREVIEW_STORIES = 5
MAX_FEED_BYTES = 2 * 1024 * 1024

# apps/describe/web_preview.py: limits on reading one site. Every response stops at MAX_FEED_BYTES.
# Discovery starts no request or redirect after DISCOVERY_SECONDS and reads at most DISCOVERY_REQUESTS
# addresses (the page, the addresses it points to, and every retry; an address's redirects count with
# it); the feed itself then gets FEED_READ_SECONDS. A request whose server goes quiet gives up after
# REQUEST_TIMEOUT_SECONDS, or sooner when less time is left.
DISCOVERY_SECONDS = 10
DISCOVERY_REQUESTS = 10
FEED_READ_SECONDS = 10
REQUEST_TIMEOUT_SECONDS = 10
READ_CHUNK_BYTES = 16 * 1024
DISCOVERY_HEADERS = {"User-Agent": "NewsBlur Feed Finder"}

# apps/describe/web_preview.py: how much of a candidate address discovery reads. FeedFinder.is_feed_data
# decides from the start of a document: "<html" in its first 100 characters, a WordPress JSON array in
# its first 2,000, and the <rss, <rdf or <feed root element an XML feed opens with after a short prolog.
# The one feed this can miss is a JSON Feed that puts "version" (jsonfeed.org) after 256 KB of items.
# The page itself is still read to MAX_FEED_BYTES, so links far down it are seen.
DISCOVERY_CANDIDATE_BYTES = 256 * 1024
# apps/describe/web_preview.py: utils/feedfinder_forman.py FeedFinder.get_feed asks again with no
# User-Agent at all after one of these answers or an empty body; Discovery.read_text keeps that, but
# only for an empty body that came with a 2xx. requests drops a header set to None.
RETRY_STATUSES = (403, 204, 202)
NO_USER_AGENT_HEADERS = {"User-Agent": None}
# apps/describe/web_preview.py: a body of one of these types is neither a feed nor a page that links one.
NOT_FEED_CONTENT_TYPES = ("image/", "audio/", "video/", "font/")
CHARSET_RE = re.compile(r"charset=[\"']?([\w.:-]+)", re.IGNORECASE)

# apps/describe/web_preview.py: the <link type> values utils/feedfinder_forman.py find_feeds checks.
FEED_LINK_TYPES = (
    "application/rss+xml",
    "text/xml",
    "application/atom+xml",
    "application/x.atom+xml",
    "application/x-atom+xml",
    "application/json",
)
# apps/describe/web_preview.py: paths tried, in this order, after every address the page points to.
# WordPress serves its feed at feed/ (and feed), and 99percentinvisible.org, stratechery.com and
# arstechnica.com don't advertise it; unity.com/blog serves rss. Then come the paths find_feeds guesses,
# the common ones first (atom.xml, rss.xml, Hugo's index.xml), because the request budget can run out
# before the last of them.
GUESSED_FEED_PATHS = (
    "feed/",
    "feed",
    "rss",
    "atom.xml",
    "rss.xml",
    "index.xml",
    "index.atom",
    "index.rss",
    "index.rdf",
    "index.json",
)


def preview_site(url):
    """Return what the pipeline needs to show `url`, or None when it has no readable feed.

    {"feed": Feed} when NewsBlur already has the feed. Otherwise
    {"feed": None, "feed_address", "feed_title", "feed_link", "tagline", "stories"}
    read straight from the site, with nothing written to the database. Text in
    the snapshot is HTML-safe (see clean_text) and links are plain http(s).
    """
    url = urlnorm.normalize(url)
    if not url:
        return None
    try:
        validate_public_url(url)
    except UnsafeUrlError:
        return None

    feed = existing_feed(url)
    if feed:
        return {"feed": feed}

    addresses = find_feed_addresses(url)
    if not addresses:
        return None
    address = safe_http_url(addresses[0])
    if not address:
        return None

    feed = existing_feed(address)
    if feed:
        return {"feed": feed}

    body = fetch_feed_body(address)
    if not body:
        return None

    parsed = feedparser.parse(body)
    entries = [entry for entry in parsed.entries if entry.get("title")]
    if not entries:
        return None

    channel = parsed.feed
    return {
        "feed": None,
        "feed_address": address,
        "feed_title": clean_text(channel.get("title"), 255) or escape(address),
        "feed_link": safe_http_url(channel.get("link")) or safe_http_url(url),
        "tagline": clean_text(channel.get("subtitle"), 200),
        "stories": [
            {
                "story_title": clean_text(entry.get("title"), 255),
                "story_permalink": entry.get("link") or "",
                "story_date": entry_date(entry),
                "story_content": entry_content(entry),
                "image_urls": entry_images(entry),
            }
            for entry in entries[:PREVIEW_STORIES]
        ],
    }


def fetch_feed_body(address):
    """The first MAX_FEED_BYTES of a feed, or None when it cannot be fetched or does not answer 200."""
    response, body = read_response(
        address,
        deadline=time.monotonic() + FEED_READ_SECONDS,
        should_read=lambda response: response.status_code == 200,
    )
    return body


def read_response(url, deadline, headers=None, max_bytes=MAX_FEED_BYTES, should_read=None):
    """GET `url` and read the start of its body by `deadline` (a time.monotonic() value).

    Returns (response, body). response is None when no answer came, and body is
    None when should_read(response) turned the body down or reading it failed.
    The body is streamed, so a huge or never-ending response is cut off at
    max_bytes instead of being buffered whole into the worker's memory. Reading
    also stops at the deadline with whatever has arrived: between chunks by
    checking the clock, and inside one by SocketDeadline.
    """
    response = open_response(url, deadline, headers)
    if response is None:
        return None, None
    try:
        if should_read and not should_read(response):
            return response, None
        body = bytearray()
        with SocketDeadline(response, deadline) as socket_deadline:
            try:
                for chunk in response.iter_content(chunk_size=READ_CHUNK_BYTES):
                    body += chunk
                    if len(body) >= max_bytes or time.monotonic() >= deadline:
                        break
            except requests.RequestException:
                if not socket_deadline.fired:
                    return response, None
        return response, bytes(body[:max_bytes])
    finally:
        response.close()


def open_response(url, deadline, headers=None):
    """The streamed response at `url` after up to MAX_REDIRECTS redirects, or None.

    safe_requests_get still checks every hop against private networks, but the
    redirects are followed here instead of inside it, so no hop starts after
    `deadline` and each one waits no longer than the time left when it starts.
    """
    for _ in range(MAX_REDIRECTS + 1):
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            return None
        try:
            response = safe_requests_get(
                url,
                headers=headers,
                timeout=min(REQUEST_TIMEOUT_SECONDS, remaining),
                stream=True,
                allow_redirects=False,
            )
        except (UnsafeUrlError, requests.RequestException):
            return None
        if not response.is_redirect:
            return response
        url = urljoin(response.url or url, response.headers["Location"])
        response.close()
    return None


class SocketDeadline:
    """Shuts down a streamed response's socket at `deadline`, so a read waiting on it returns then.

    requests' timeout only limits how long one socket read waits, and iter_content
    keeps reading until it has a whole READ_CHUNK_BYTES, so a server that sends a
    byte every few seconds would hold the read open until Celery's time limit. A
    timer thread calls shutdown() on the socket at the deadline, which wakes a
    read blocked on it at once (close() from another thread does not reliably do
    that on Linux). The read then ends or raises a requests error, and `fired`
    tells read_response the deadline did it. The timer reaches the socket through
    its file descriptor, so it works the same under TLS, gzip and chunked transfer
    encoding, and the descriptor is let go before read_response closes the response,
    so a late timer can never shut down a socket that has reused that number.
    """

    def __init__(self, response, deadline):
        self.fired = False
        self.finished = False
        self.lock = threading.Lock()
        self.sock = response_socket(response)
        self.timer = None
        if self.sock is not None:
            self.timer = threading.Timer(max(0.0, deadline - time.monotonic()), self.shut_down)
            self.timer.daemon = True

    def __enter__(self):
        if self.timer:
            self.timer.start()
        return self

    def __exit__(self, *exc_info):
        with self.lock:
            self.finished = True
        if self.timer:
            self.timer.cancel()
        if self.sock is not None:
            # apps/describe/web_preview.py: detach, not close. The response owns the descriptor.
            self.sock.detach()
        return False

    def shut_down(self):
        with self.lock:
            if self.finished:
                return
            self.fired = True
            try:
                self.sock.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass


def response_socket(response):
    """A second handle on the socket a streamed response reads from, or None when it has none.

    A response whose connection is already closed, because there was nothing
    left to read, has no socket.
    """
    try:
        return socket.socket(fileno=response.raw.fileno())
    except (AttributeError, OSError, ValueError):
        return None


def clean_text(value, limit):
    """HTML-safe text from a feed's own title, tagline or headline.

    Tags are dropped and what is left is HTML-escaped, the way NewsBlur keeps
    feed and story titles: these strings reach add_site_view.js and
    story_title_view.js, which insert card text as HTML, and nothing else has
    sanitized an unsaved feed. Escaping matters even after strip_tags, which
    leaves a tag with no closing ">" (such as "<img src=x onerror=...") as is.
    The limit applies to the plain text, so an escaped entity is never cut in half.
    """
    return escape(" ".join(strip_tags(html.unescape(value or "")).split())[:limit])


def existing_feed(address):
    """The feed NewsBlur already stores at this address, following merged duplicates."""
    feed = (
        Feed.objects.filter(branch_from_feed=None, feed_address=address).order_by("-num_subscribers").first()
    )
    if feed:
        return feed
    duplicate = DuplicateFeed.objects.filter(duplicate_address=address).select_related("feed").first()
    return duplicate.feed if duplicate else None


def find_feed_addresses(url):
    """The site's feed address as a one-item list, or [] when none turns up within the limits.

    This follows utils/feedfinder_forman.py find_feeds (the page itself, then its
    <link> tags, feed-like <a> links and common feed paths) but reads every
    response through read_response, so none is held past MAX_FEED_BYTES and none
    starts or keeps reading once DISCOVERY_SECONDS have passed. It runs in the
    caller's thread, so when it returns nothing is still downloading. find_feeds
    buffers whole responses, and under utils/feed_functions.py timelimit it kept
    fetching in a daemon thread after the search had moved on.
    """
    discovery = Discovery()
    finder = feedfinder_forman.FeedFinder()
    url = feedfinder_forman.coerce_url(url)
    page, page_url = discovery.read_text(url, MAX_FEED_BYTES)
    if page is None:
        return []
    if finder.is_feed_data(page):
        return [url]
    for candidate in feed_candidates(page_url, page, finder):
        text, _ = discovery.read_text(candidate, DISCOVERY_CANDIDATE_BYTES)
        if text and finder.is_feed_data(text):
            return [candidate]
    return []


class Discovery:
    """The deadline and request budget that one site's feed discovery shares."""

    def __init__(self):
        self.deadline = time.monotonic() + DISCOVERY_SECONDS
        self.requests_left = DISCOVERY_REQUESTS
        self.user_agent_refused = False

    def read_text(self, url, max_bytes):
        """(text, final URL) for the start of the document at `url`, whatever status it came with.

        Both are None when nothing could be read. The final URL is where redirects
        ended, which relative links on the page and guessed paths resolve against.

        This reads the way utils/feedfinder_forman.py FeedFinder.get_feed did for
        find_feeds. Any status counts: smbc-comics.com serves its homepage with a
        500 and kalzumeus.com with a 206. An answer of 403, 204 or 202, or a 2xx
        with an empty body, is asked for again with no User-Agent, since nu.nl
        refuses the finder's. An empty 404 or other error is not: asking a missing
        address again never turns up a feed, and paying twice for every missing
        guess ran the budget out before the later ones. The retry spends a request
        like any other, because it costs the site and the deadline just as much.
        Once an address only answered to the retry, the site has refused the
        finder, so every later address is asked with no User-Agent straight away,
        one request each, and the budget reaches most of the guesses.
        """
        if self.user_agent_refused:
            response, body = self.read(url, NO_USER_AGENT_HEADERS, max_bytes)
        else:
            response, body = self.read(url, DISCOVERY_HEADERS, max_bytes)
            if body is not None and should_retry_without_user_agent(response, body):
                response, body = self.read(url, NO_USER_AGENT_HEADERS, max_bytes)
                self.user_agent_refused = body is not None and not should_retry_without_user_agent(
                    response, body
                )
        if body is None:
            return None, None
        return decode_text(body, response), response.url or url

    def read(self, url, headers, max_bytes):
        if self.requests_left <= 0:
            return None, None
        self.requests_left -= 1
        return read_response(
            url, self.deadline, headers=headers, max_bytes=max_bytes, should_read=could_hold_a_feed
        )


def should_retry_without_user_agent(response, body):
    """True for a refusal (403, 204, 202) or a 2xx with nothing in it, the answers a finder-blocking site gives."""
    if response.status_code in RETRY_STATUSES:
        return True
    return 200 <= response.status_code < 300 and not body.strip()


def could_hold_a_feed(response):
    """False when the Content-Type shows media, which is neither a feed nor a page that links one."""
    content_type = (response.headers.get("Content-Type") or "").strip().lower()
    return not content_type.startswith(NOT_FEED_CONTENT_TYPES)


def decode_text(body, response):
    """A discovery read as text, in the charset its Content-Type declares, else UTF-8."""
    declared = CHARSET_RE.search(response.headers.get("Content-Type") or "")
    if declared:
        try:
            return body.decode(declared.group(1), errors="replace")
        except LookupError:
            pass
    return body.decode("utf-8", errors="replace")


def feed_candidates(url, page, finder):
    """Addresses that may be the site's feed, from `page` as served at `url`, in the order to check them.

    As in find_feeds: <link> tags first, then relative <a> links ending like a feed,
    then any feed-like <a> link, each group with its likeliest address first. Then
    GUESSED_FEED_PATHS in their own order. `url` is where the page's redirects ended,
    since that is what a browser resolves the page's relative links against.
    """
    try:
        tree = BeautifulSoup(page, features="lxml")
    except ValueError:
        return []
    links = [
        urljoin(url, link.get("href", ""))
        for link in tree.find_all("link")
        if link.get("type") in FEED_LINK_TYPES
    ]
    local, remote = [], []
    for anchor in tree.find_all("a"):
        href = anchor.get("href")
        if href is None:
            continue
        if "://" not in href and finder.is_feed_url(href):
            local.append(urljoin(url, href))
        if finder.is_feedlike_url(href):
            remote.append(urljoin(url, href))
    guesses = []
    if not any(domain in url for domain in ("openrss", "feedburner")):
        guesses = [urljoin(guess_base(url), path) for path in GUESSED_FEED_PATHS]

    for group in (links, local, remote):
        group.sort(key=feedfinder_forman.url_feed_prob, reverse=True)
    candidates = []
    for candidate in links + local + remote + guesses:
        if candidate != url and candidate not in candidates:
            candidates.append(candidate)
    return candidates


def guess_base(url):
    """The address guessed feed paths are resolved against: the page's final URL, taken as a directory.

    blog.unity.com redirects to unity.com/blog, whose feed is unity.com/blog/rss, and
    urljoin alone would put "rss" in place of "blog". A last path segment with no dot
    is taken as a directory; one like index.html is still replaced.
    """
    scheme, netloc, path, query, fragment = urlsplit(url)
    last_segment = path.rsplit("/", 1)[-1]
    if last_segment and "." not in last_segment:
        path += "/"
    return urlunsplit((scheme, netloc, path or "/", "", ""))


def entry_content(entry):
    bodies = entry.get("content") or []
    if bodies and bodies[0].get("value"):
        return bodies[0]["value"]
    return entry.get("summary") or ""


def entry_images(entry):
    """Image URLs the feed declares for an entry (media:thumbnail, media:content, image enclosures)."""
    images = [item.get("url") for item in entry.get("media_thumbnail") or []]
    images += [
        item.get("url")
        for item in (entry.get("media_content") or []) + (entry.get("enclosures") or [])
        if (item.get("type") or "").startswith("image/") or item.get("medium") == "image"
    ]
    return [url for url in images if url]


def entry_date(entry):
    parsed = entry.get("published_parsed") or entry.get("updated_parsed")
    if not parsed:
        return None
    return datetime.datetime(*parsed[:6])
