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


def transform_briefing(briefing: dict, section_definitions: dict | None = None) -> dict:
    """Transform a raw briefing object into an AI-friendly format."""
    curated_stories = [transform_story(s) for s in briefing.get("curated_stories", [])]

    # Add feed_title from briefing story data (briefing stories carry it)
    for story, raw in zip(curated_stories, briefing.get("curated_stories", [])):
        if raw.get("feed_title"):
            story["feed_title"] = raw["feed_title"]

    # Convert section summaries from HTML to text
    section_summaries = {}
    for key, html in (briefing.get("section_summaries") or {}).items():
        display_name = (section_definitions or {}).get(key, key)
        section_summaries[display_name] = html_to_text(html) if html else ""

    # Map curated sections (section_key -> story_hashes) to display names
    curated_sections = {}
    for key, hashes in (briefing.get("curated_sections") or {}).items():
        display_name = (section_definitions or {}).get(key, key)
        curated_sections[display_name] = hashes

    result = {
        "briefing_date": briefing.get("briefing_date", ""),
        "period_start": briefing.get("period_start", ""),
        "frequency": briefing.get("frequency", ""),
        "curated_stories": curated_stories,
        "sections": curated_sections,
        "section_summaries": section_summaries,
    }

    if briefing.get("summary_story"):
        result["summary_story"] = transform_story(briefing["summary_story"])

    return result


def paginate(items: list, page: int, has_more: bool) -> dict:
    """Wrap items with pagination metadata."""
    return {
        "items": items,
        "page": page,
        "has_more": has_more,
        "count": len(items),
    }
