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

import feedparser
import requests
from django.utils.html import strip_tags

from apps.rss_feeds.models import DuplicateFeed, Feed
from utils import feedfinder_forman, urlnorm
from utils.feed_functions import timelimit
from utils.url_safety import UnsafeUrlError, safe_requests_get, validate_public_url

# apps/describe/web_preview.py: headlines kept per previewed site, and how much of a feed is parsed.
PREVIEW_STORIES = 5
MAX_FEED_BYTES = 2 * 1024 * 1024


def preview_site(url):
    """Return what the pipeline needs to show `url`, or None when it has no readable feed.

    {"feed": Feed} when NewsBlur already has the feed. Otherwise
    {"feed": None, "feed_address", "feed_title", "feed_link", "tagline", "stories"}
    read straight from the site, with nothing written to the database.
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

    try:
        addresses = find_feed_addresses(url)
    except TimeoutError:
        addresses = []
    if not addresses:
        return None
    address = addresses[0]

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
        "feed_title": clean_text(channel.get("title"), 255) or address,
        "feed_link": channel.get("link") or url,
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
    """The first MAX_FEED_BYTES of a feed, or None when it cannot be fetched.

    Streamed, so a huge or never-ending response is cut off at the limit
    instead of being buffered whole into the worker's memory.
    """
    try:
        response = safe_requests_get(address, timeout=10, stream=True)
    except (UnsafeUrlError, requests.RequestException):
        return None
    try:
        if response.status_code != 200:
            return None
        body = b""
        for chunk in response.iter_content(chunk_size=64 * 1024):
            body += chunk
            if len(body) >= MAX_FEED_BYTES:
                break
        return body[:MAX_FEED_BYTES]
    except requests.RequestException:
        return None
    finally:
        response.close()


def clean_text(value, limit):
    """Plain text from a feed's own title or tagline. Tags are dropped: these strings reach
    add_site_view.js, which inserts card text as HTML, and nothing has sanitized an unsaved feed."""
    return " ".join(strip_tags(html.unescape(value or "")).split())[:limit]


def existing_feed(address):
    """The feed NewsBlur already stores at this address, following merged duplicates."""
    feed = (
        Feed.objects.filter(branch_from_feed=None, feed_address=address).order_by("-num_subscribers").first()
    )
    if feed:
        return feed
    duplicate = DuplicateFeed.objects.filter(duplicate_address=address).select_related("feed").first()
    return duplicate.feed if duplicate else None


@timelimit(10)
def find_feed_addresses(url):
    return feedfinder_forman.find_feeds(url)


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
