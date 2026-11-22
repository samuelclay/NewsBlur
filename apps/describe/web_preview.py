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
import time
from urllib.parse import urljoin

import feedparser
import requests
from bs4 import BeautifulSoup
from django.utils.html import escape, strip_tags

from apps.describe.models import safe_http_url
from apps.rss_feeds.models import DuplicateFeed, Feed
from utils import feedfinder_forman, urlnorm
from utils.url_safety import UnsafeUrlError, safe_requests_get, validate_public_url

# apps/describe/web_preview.py: headlines kept per previewed site, and how much of a feed is parsed.
PREVIEW_STORIES = 5
MAX_FEED_BYTES = 2 * 1024 * 1024

# apps/describe/web_preview.py: limits on reading one site. Every response, discovery's included, stops
# at MAX_FEED_BYTES. Discovery starts no request after DISCOVERY_SECONDS and makes at most
# DISCOVERY_REQUESTS of them (the page and the addresses it points to); the feed itself then gets
# FEED_READ_SECONDS. A request whose server goes quiet gives up after REQUEST_TIMEOUT_SECONDS.
DISCOVERY_SECONDS = 10
DISCOVERY_REQUESTS = 10
FEED_READ_SECONDS = 10
REQUEST_TIMEOUT_SECONDS = 10
READ_CHUNK_BYTES = 16 * 1024
DISCOVERY_HEADERS = {"User-Agent": "NewsBlur Feed Finder"}

# apps/describe/web_preview.py: the <link type> values and guessed paths utils/feedfinder_forman.py
# find_feeds checks.
FEED_LINK_TYPES = (
    "application/rss+xml",
    "text/xml",
    "application/atom+xml",
    "application/x.atom+xml",
    "application/x-atom+xml",
    "application/json",
)
GUESSED_FEED_PATHS = (
    "atom.xml",
    "index.atom",
    "index.rdf",
    "rss.xml",
    "index.xml",
    "index.rss",
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
    """The first MAX_FEED_BYTES of a feed, or None when it cannot be fetched."""
    return read_body(address, deadline=time.monotonic() + FEED_READ_SECONDS)


def read_body(url, deadline, headers=None):
    """The start of the response body at `url`, or None when it cannot be fetched or time is up.

    Streamed, so a huge or never-ending response is cut off at MAX_FEED_BYTES
    instead of being buffered whole into the worker's memory. Reading also stops
    at `deadline` (a time.monotonic() value) with whatever has arrived.
    """
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        return None
    try:
        response = safe_requests_get(
            url, headers=headers, timeout=min(REQUEST_TIMEOUT_SECONDS, remaining), stream=True
        )
    except (UnsafeUrlError, requests.RequestException):
        return None
    try:
        if response.status_code != 200:
            return None
        body = bytearray()
        for chunk in response.iter_content(chunk_size=READ_CHUNK_BYTES):
            body += chunk
            if len(body) >= MAX_FEED_BYTES or time.monotonic() >= deadline:
                break
        return bytes(body[:MAX_FEED_BYTES])
    except requests.RequestException:
        return None
    finally:
        response.close()


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
    response through read_body, so none is held past MAX_FEED_BYTES and none
    starts or keeps reading once DISCOVERY_SECONDS have passed. It runs in the
    caller's thread, so when it returns nothing is still downloading. find_feeds
    buffers whole responses, and under utils/feed_functions.py timelimit it kept
    fetching in a daemon thread after the search had moved on.
    """
    deadline = time.monotonic() + DISCOVERY_SECONDS
    finder = feedfinder_forman.FeedFinder()
    url = feedfinder_forman.coerce_url(url)
    page = read_text(url, deadline)
    if page is None:
        return []
    if finder.is_feed_data(page):
        return [url]
    for candidate in feed_candidates(url, page, finder)[: DISCOVERY_REQUESTS - 1]:
        text = read_text(candidate, deadline)
        if text and finder.is_feed_data(text):
            return [candidate]
    return []


def read_text(url, deadline):
    body = read_body(url, deadline, headers=DISCOVERY_HEADERS)
    if body is None:
        return None
    return body.decode("utf-8", errors="replace")


def feed_candidates(url, page, finder):
    """Addresses on `page` that may be the site's feed, in the order find_feeds checks them.

    <link> tags first, then relative <a> links ending like a feed, then any feed-like
    <a> link, then guessed paths. Within each group the likeliest address comes first.
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
        guesses = [urljoin(url, path) for path in GUESSED_FEED_PATHS]

    candidates = []
    for group in (links, local, remote, guesses):
        for candidate in sorted(group, key=feedfinder_forman.url_feed_prob, reverse=True):
            if candidate != url and candidate not in candidates:
                candidates.append(candidate)
    return candidates


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
