"""Bluesky feed enrichment via the AT Protocol public API.

Bluesky's built-in RSS feeds (bsky.app/profile/X/rss) are text-only with no
images, video thumbnails, or titles. This module enriches parsed RSS entries
with image/video data from the unauthenticated AT Protocol API.
"""

import re

import requests

from utils import log as logging

BLUESKY_FEED_RE = re.compile(r"https?://bsky\.app/profile/([^/]+)/rss")
BSKY_API_BASE = "https://public.api.bsky.app/xrpc"
TITLE_MAX_LENGTH = 80


def is_bluesky_feed(feed_address):
    return bool(BLUESKY_FEED_RE.match(feed_address))


def extract_actor(feed_address):
    match = BLUESKY_FEED_RE.match(feed_address)
    if match:
        return match.group(1)
    return None


def fetch_bluesky_api_posts(actor, limit=30):
    url = f"{BSKY_API_BASE}/app.bsky.feed.getAuthorFeed"
    params = {"actor": actor, "limit": limit, "filter": "posts_no_replies"}
    try:
        resp = requests.get(url, params=params, timeout=15)
        resp.raise_for_status()
        return resp.json().get("feed", [])
    except Exception as e:
        logging.debug(f"   ---> ~FRBluesky API fetch failed for {actor}: {e}")
        return []


def build_embed_html(post_data):
    """Build HTML for embedded images/video from a Bluesky API post."""
    embed = post_data.get("embed")
    if not embed:
        return ""

    embed_type = embed.get("$type", "")
    html_parts = []

    if "images" in embed_type:
        for image in embed.get("images", []):
            fullsize = image.get("fullsize", "")
            alt = image.get("alt", "")
            if fullsize:
                html_parts.append(f'<img src="{fullsize}" alt="{alt}" />')

    elif "video" in embed_type:
        thumbnail = embed.get("thumbnail", "")
        if thumbnail:
            playlist = embed.get("playlist", "")
            html_parts.append(f'<img src="{thumbnail}" />')
            if playlist:
                html_parts.append(
                    f'<video controls preload="none" poster="{thumbnail}">'
                    f'<source src="{playlist}" type="application/x-mpegURL" />'
                    f"</video>"
                )

    elif "external" in embed_type:
        external = embed.get("external", {})
        thumb = external.get("thumb", "")
        if thumb:
            html_parts.append(f'<img src="{thumb}" />')

    elif "record" in embed_type and "media" in embed_type:
        media = embed.get("media", {})
        media_type = media.get("$type", "")
        if "images" in media_type:
            for image in media.get("images", []):
                fullsize = image.get("fullsize", "")
                alt = image.get("alt", "")
                if fullsize:
                    html_parts.append(f'<img src="{fullsize}" alt="{alt}" />')

    return "<br><br>".join(html_parts)


def extract_title_from_text(text):
    """Extract a title from the first line of post text."""
    if not text:
        return ""
    first_line = text.split("\n")[0].strip()
    if len(first_line) > TITLE_MAX_LENGTH:
        truncated = first_line[:TITLE_MAX_LENGTH].rsplit(" ", 1)[0]
        return truncated + "\u2026"
    return first_line


def enrich_bluesky_entries(feed_address, entries):
    """Enrich feedparser entries with Bluesky API data (images, titles).

    Modifies entries in-place. Each entry's guid contains the AT URI
    which maps to the API response's post.uri field.
    """
    actor = extract_actor(feed_address)
    if not actor:
        return

    api_posts = fetch_bluesky_api_posts(actor)
    if not api_posts:
        return

    # Build mapping from AT URI to API post data
    post_map = {}
    for item in api_posts:
        post = item.get("post", {})
        uri = post.get("uri", "")
        if uri:
            post_map[uri] = post

    enriched_count = 0
    for entry in entries:
        at_uri = entry.get("id", "") or entry.get("guid", "")
        post = post_map.get(at_uri)
        if not post:
            continue

        record = post.get("record", {})
        text = record.get("text", "")

        # Set title from first line of text if no title exists
        if not entry.get("title"):
            entry["title"] = extract_title_from_text(text)

        # Build image/video HTML from embed data
        embed_html = build_embed_html(post)
        if embed_html:
            existing = entry.get("summary", "") or ""
            entry["summary"] = embed_html + "<br><br>" + existing if existing else embed_html
            if "summary_detail" in entry:
                entry["summary_detail"]["value"] = entry["summary"]
                entry["summary_detail"]["type"] = "text/html"
            enriched_count += 1

    if enriched_count:
        logging.debug(
            f"   ---> ~FBBluesky: enriched ~SB{enriched_count}~SN/{len(entries)} entries with images for {actor}"
        )
