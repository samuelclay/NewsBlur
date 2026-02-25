"""
Tool definitions for Ask AI Deep Analysis mode.

Reuses tools from the Archive Assistant for cross-referencing content,
plus a new tool for fetching recent stories from the same feed.
"""

from apps.archive_assistant.tools import CODE_EXECUTION_TOOL, PTC_ALLOWED_CALLERS
from apps.archive_assistant.tools import execute_tool as archive_execute_tool
from apps.rss_feeds.models import Feed
from utils import log as logging

# Tools reused from Archive Assistant (subset relevant to Ask AI deep analysis)
ASK_AI_DEEP_TOOLS = [
    CODE_EXECUTION_TOOL,
    {
        "name": "search_feed_stories",
        "description": "Search across all stories from the user's subscribed RSS feeds using full-text search. Use this to find related coverage of topics mentioned in the current article.",
        "input_schema": {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "Search query for full-text search across feed stories",
                },
                "feed_ids": {
                    "type": "array",
                    "items": {"type": "integer"},
                    "description": "Optional: limit search to specific feed IDs",
                },
                "limit": {
                    "type": "integer",
                    "description": "Maximum results (default: 10, max: 30)",
                },
            },
            "required": ["query"],
        },
        "allowed_callers": PTC_ALLOWED_CALLERS,
    },
    {
        "name": "get_feed_story_content",
        "description": "Get the full content of a specific feed story by its hash. Use this to read the complete article text for cross-referencing or verification.",
        "input_schema": {
            "type": "object",
            "properties": {
                "story_hash": {
                    "type": "string",
                    "description": "The story hash ID (from search results)",
                }
            },
            "required": ["story_hash"],
        },
        "allowed_callers": PTC_ALLOWED_CALLERS,
    },
    {
        "name": "search_starred_stories",
        "description": "Search the user's saved/starred RSS stories. Use this to find saved articles that may provide context or corroborate claims.",
        "input_schema": {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "Search query to match against titles and content.",
                },
                "tags": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Filter by user-assigned tags",
                },
                "feed_title": {
                    "type": "string",
                    "description": "Filter to stories from feeds matching this title",
                },
                "limit": {
                    "type": "integer",
                    "description": "Maximum results (default: 10, max: 50)",
                },
            },
            "required": [],
        },
        "allowed_callers": PTC_ALLOWED_CALLERS,
    },
    {
        "name": "get_starred_story_content",
        "description": "Get the full content of a specific starred story by its hash.",
        "input_schema": {
            "type": "object",
            "properties": {
                "story_hash": {
                    "type": "string",
                    "description": "The story hash ID (from search results)",
                }
            },
            "required": ["story_hash"],
        },
        "allowed_callers": PTC_ALLOWED_CALLERS,
    },
    {
        "name": "search_shared_stories",
        "description": "Search stories shared by people the user follows. Use this to find what the user's network has said about this topic.",
        "input_schema": {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "Search query to match against titles, content, and comments.",
                },
                "limit": {
                    "type": "integer",
                    "description": "Maximum results (default: 10, max: 30)",
                },
            },
            "required": [],
        },
        "allowed_callers": PTC_ALLOWED_CALLERS,
    },
    {
        "name": "get_same_feed_recent",
        "description": "Get recent stories from a specific feed. Use this to find earlier or later coverage from the same source as the current article.",
        "input_schema": {
            "type": "object",
            "properties": {
                "feed_id": {
                    "type": "integer",
                    "description": "The feed ID to get recent stories from",
                },
                "limit": {
                    "type": "integer",
                    "description": "Number of recent stories to return (default: 10, max: 20)",
                },
            },
            "required": ["feed_id"],
        },
        "allowed_callers": PTC_ALLOWED_CALLERS,
    },
]


def execute_tool(tool_name, tool_input, user_id):
    """
    Execute a tool call for Ask AI deep analysis.

    Delegates most tools to the archive_assistant's execute_tool, with
    the addition of the get_same_feed_recent tool.
    """
    if tool_name == "get_same_feed_recent":
        return _get_same_feed_recent(user_id, **tool_input)

    # Delegate to archive assistant's tool executor for shared tools
    return archive_execute_tool(tool_name, tool_input, user_id)


def _get_same_feed_recent(user_id, feed_id, limit=10):
    """Get recent stories from a specific feed."""
    from apps.archive_extension.utils import format_datetime_utc
    from apps.rss_feeds.models import MStory

    limit = min(limit or 10, 20)

    try:
        feed = Feed.objects.get(pk=feed_id)
    except Feed.DoesNotExist:
        return {"error": f"Feed not found: {feed_id}"}

    stories = MStory.objects(story_feed_id=feed_id).order_by("-story_date").limit(limit)

    results = []
    for story in stories:
        content = ""
        if story.story_content:
            content = story.story_content
        elif story.story_content_z:
            import zlib

            try:
                content = zlib.decompress(story.story_content_z).decode("utf-8")
            except Exception:
                content = ""

        excerpt = content[:400] + "..." if len(content) > 400 else content

        results.append(
            {
                "story_hash": story.story_hash,
                "feed_id": story.story_feed_id,
                "title": story.story_title,
                "url": story.story_permalink,
                "feed": feed.feed_title,
                "author": story.story_author_name,
                "excerpt": excerpt,
                "story_date": format_datetime_utc(story.story_date),
                "tags": story.story_tags or [],
            }
        )

    return {
        "count": len(results),
        "feed_title": feed.feed_title,
        "feed_id": feed_id,
        "stories": results,
    }
