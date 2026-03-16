"""Response transformers for AI-friendly output.

Strips HTML to plain text, truncates long content, and adds pagination metadata.
"""

import re

from bs4 import BeautifulSoup

from newsblur_mcp.settings import MAX_STORY_CONTENT_LENGTH


def html_to_text(html: str) -> str:
    """Convert HTML to readable plain text."""
    if not html:
        return ""
    soup = BeautifulSoup(html, "html.parser")
    for tag in soup(["script", "style"]):
        tag.decompose()
    text = soup.get_text(separator="\n")
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def truncate_content(text: str, max_length: int = MAX_STORY_CONTENT_LENGTH) -> dict:
    """Truncate text and indicate if it was truncated."""
    if len(text) <= max_length:
        return {"text": text, "truncated": False}
    return {
        "text": text[:max_length] + "...",
        "truncated": True,
        "full_length": len(text),
    }


def transform_story(story: dict) -> dict:
    """Transform a raw NewsBlur story into an AI-friendly format."""
    content = story.get("story_content") or story.get("story_content_z") or ""
    text = html_to_text(content)
    content_info = truncate_content(text)

    return {
        "story_hash": story.get("story_hash", ""),
        "title": story.get("story_title", ""),
        "author": story.get("story_authors") or story.get("story_author_name", ""),
        "url": story.get("story_permalink", ""),
        "date": story.get("story_date") or story.get("short_parsed_date", ""),
        "feed_id": story.get("story_feed_id"),
        "content": content_info["text"],
        "content_truncated": content_info["truncated"],
        "tags": story.get("story_tags", []),
        "user_tags": story.get("user_tags", []),
        "user_notes": story.get("user_notes", ""),
        "highlights": story.get("highlights", []),
        "intelligence": {
            "feed": story.get("intelligence", {}).get("feed", 0),
            "author": story.get("intelligence", {}).get("author", 0),
            "tags": story.get("intelligence", {}).get("tags", 0),
            "title": story.get("intelligence", {}).get("title", 0),
        },
        "read_status": story.get("read_status", 0),
        "starred": story.get("starred", False),
        "shared": story.get("shared", False),
        "image_urls": story.get("image_urls", []),
    }


def transform_feed(feed: dict) -> dict:
    """Transform a raw NewsBlur feed into an AI-friendly format."""
    return {
        "id": feed.get("id"),
        "title": feed.get("feed_title", ""),
        "url": feed.get("feed_address", ""),
        "link": feed.get("feed_link", ""),
        "subscribers": feed.get("num_subscribers", 0),
        "active": feed.get("active", True),
        "unread_neutral": feed.get("nt", 0),
        "unread_positive": feed.get("ps", 0),
        "unread_negative": feed.get("ng", 0),
        "updated": feed.get("last_story_date", ""),
        "favicon_color": feed.get("favicon_color", ""),
    }


def paginate(items: list, page: int, has_more: bool) -> dict:
    """Wrap items with pagination metadata."""
    return {
        "items": items,
        "page": page,
        "has_more": has_more,
        "count": len(items),
    }
