"""
Tool definitions for the Archive Assistant.

These tools allow Claude to search and retrieve content from:
- User's browsing archive (from browser extension)
- Starred/saved RSS stories
- Feed stories via search
"""

from datetime import datetime, timedelta

from apps.archive_extension.models import MArchivedStory
from apps.archive_extension.search import SearchArchive
from apps.archive_extension.utils import format_datetime_utc
from apps.reader.models import UserSubscription
from apps.rss_feeds.models import Feed, MStarredStory, MStarredStoryCounts
from apps.search.models import SearchStory
from utils import log as logging

# Tool definitions for Claude API
ARCHIVE_TOOLS = [
    {
        "name": "search_archives",
        "description": "Search the user's browsing archive by keyword, date range, domain, or category. Returns a list of matching archived pages with titles, URLs, excerpts, and dates. Use this to find relevant content before answering questions.",
        "input_schema": {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "Search query to match against titles and content. Can be keywords, phrases, or topics.",
                },
                "date_from": {
                    "type": "string",
                    "description": "Start date for filtering (ISO format: YYYY-MM-DD). Only return archives from this date onwards.",
                },
                "date_to": {
                    "type": "string",
                    "description": "End date for filtering (ISO format: YYYY-MM-DD). Only return archives up to this date.",
                },
                "domains": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Filter to only these domains (e.g., ['nytimes.com', 'bbc.com'])",
                },
                "categories": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Filter by AI-generated categories (e.g., ['Research', 'Shopping', 'News'])",
                },
                "limit": {
                    "type": "integer",
                    "description": "Maximum number of results to return (default: 10, max: 50)",
                },
            },
            "required": [],
        },
    },
    {
        "name": "get_archive_content",
        "description": "Retrieve the full content of a specific archived page by its ID. Use this to read the complete text of an article when you need more detail than the search excerpt provides.",
        "input_schema": {
            "type": "object",
            "properties": {
                "archive_id": {
                    "type": "string",
                    "description": "The ID of the archived page to retrieve (from search results)",
                }
            },
            "required": ["archive_id"],
        },
    },
    {
        "name": "get_archive_summary",
        "description": "Get a summary of the user's archive - total count, category breakdown, top domains, and recent activity. Use this to understand the scope of their archive before searching.",
        "input_schema": {
            "type": "object",
            "properties": {},
            "required": [],
        },
    },
    {
        "name": "get_recent_archives",
        "description": "Get the most recently archived pages. Use this when the user asks about recent reading or browsing activity.",
        "input_schema": {
            "type": "object",
            "properties": {
                "limit": {
                    "type": "integer",
                    "description": "Number of recent archives to return (default: 10, max: 30)",
                },
                "days": {
                    "type": "integer",
                    "description": "Only return archives from the last N days (default: 7)",
                },
            },
            "required": [],
        },
    },
    # RSS Feed Story Tools
    {
        "name": "search_starred_stories",
        "description": "Search the user's saved/starred RSS stories. These are stories they explicitly saved from their RSS feeds with optional tags, notes, and highlights. Use this when asking about saved articles, reading lists, or stories they've bookmarked.",
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
                    "description": "Filter by user-assigned tags (e.g., ['to-read', 'research', 'recipes'])",
                },
                "feed_title": {
                    "type": "string",
                    "description": "Filter to stories from feeds matching this title",
                },
                "date_from": {
                    "type": "string",
                    "description": "Start date (ISO format: YYYY-MM-DD)",
                },
                "date_to": {
                    "type": "string",
                    "description": "End date (ISO format: YYYY-MM-DD)",
                },
                "limit": {
                    "type": "integer",
                    "description": "Maximum results (default: 10, max: 50)",
                },
            },
            "required": [],
        },
    },
    {
        "name": "get_starred_story_content",
        "description": "Get the full content of a specific starred story by its hash. Use this to read the complete article text including user notes and highlights.",
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
    },
    {
        "name": "get_starred_summary",
        "description": "Get a summary of the user's starred stories - total count, their tags, top feeds, and recent saves. Use this to understand what they've saved before searching.",
        "input_schema": {
            "type": "object",
            "properties": {},
            "required": [],
        },
    },
    {
        "name": "search_feed_stories",
        "description": "Search across all stories from the user's subscribed RSS feeds using full-text search. This searches their entire reading history, not just saved stories. Use this for broad searches about what they've read.",
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
    },
    {
        "name": "get_feed_story_content",
        "description": "Get the full content of a specific feed story by its hash. Use this to read the complete article text when you need more detail than the search excerpt provides.",
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
    },
    {
        "name": "search_shared_stories",
        "description": "Search stories shared by people the user follows (their social feed/blurblogs). These are stories that friends and followed users have shared with comments. Use this to find what people in the user's network are talking about or recommending.",
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
    },
]


def execute_tool(tool_name, tool_input, user_id):
    """
    Execute a tool call and return the result.

    Args:
        tool_name: Name of the tool to execute
        tool_input: Dictionary of tool input parameters
        user_id: User ID to scope the query

    Returns:
        dict: Tool result with content
    """
    # Browsing archive tools
    if tool_name == "search_archives":
        return _search_archives(user_id, **tool_input)
    elif tool_name == "get_archive_content":
        return _get_archive_content(user_id, tool_input.get("archive_id"))
    elif tool_name == "get_archive_summary":
        return _get_archive_summary(user_id)
    elif tool_name == "get_recent_archives":
        return _get_recent_archives(user_id, **tool_input)
    # RSS feed story tools
    elif tool_name == "search_starred_stories":
        return _search_starred_stories(user_id, **tool_input)
    elif tool_name == "get_starred_story_content":
        return _get_starred_story_content(user_id, tool_input.get("story_hash"))
    elif tool_name == "get_starred_summary":
        return _get_starred_summary(user_id)
    elif tool_name == "search_feed_stories":
        return _search_feed_stories(user_id, **tool_input)
    elif tool_name == "get_feed_story_content":
        return _get_feed_story_content(user_id, tool_input.get("story_hash"))
    elif tool_name == "search_shared_stories":
        return _search_shared_stories(user_id, **tool_input)
    else:
        return {"error": f"Unknown tool: {tool_name}"}


def _search_archives(
    user_id, query=None, date_from=None, date_to=None, domains=None, categories=None, limit=10
):
    """Search user's archives with filters using Elasticsearch for full-text search."""
    limit = min(limit or 10, 50)

    # Parse date filters
    parsed_date_from = None
    parsed_date_to = None
    if date_from:
        try:
            parsed_date_from = datetime.fromisoformat(date_from)
        except ValueError:
            pass
    if date_to:
        try:
            parsed_date_to = datetime.fromisoformat(date_to)
        except ValueError:
            pass

    archive_ids = []

    # Use Elasticsearch for text search if query is provided
    if query:
        # Use domain filter (single domain for ES)
        domain_filter = domains[0] if domains and len(domains) == 1 else None

        archive_ids = SearchArchive.query(
            user_id=user_id,
            query=query,
            limit=limit,
            domain=domain_filter,
            categories=categories,
            date_from=parsed_date_from,
            date_to=parsed_date_to,
        )

        if not archive_ids:
            # Fallback to MongoDB title search if ES returns no results
            mongo_query = {"user_id": user_id, "deleted": False, "title__icontains": query}
            if parsed_date_from:
                mongo_query["archived_date__gte"] = parsed_date_from
            if parsed_date_to:
                mongo_query["archived_date__lte"] = parsed_date_to
            if domains:
                mongo_query["domain__in"] = domains
            if categories:
                mongo_query["ai_categories__in"] = categories
            archives = MArchivedStory.objects(**mongo_query).limit(limit)
            archive_ids = [str(a.id) for a in archives]
    else:
        # No text query, just filter with MongoDB
        mongo_query = {"user_id": user_id, "deleted": False}
        if parsed_date_from:
            mongo_query["archived_date__gte"] = parsed_date_from
        if parsed_date_to:
            mongo_query["archived_date__lte"] = parsed_date_to
        if domains:
            mongo_query["domain__in"] = domains
        if categories:
            mongo_query["ai_categories__in"] = categories

        archives = MArchivedStory.objects(**mongo_query).order_by("-archived_date").limit(limit)
        archive_ids = [str(a.id) for a in archives]

    # Fetch the actual archive documents
    results = []
    for archive_id in archive_ids:
        try:
            archive = MArchivedStory.objects.get(id=archive_id, user_id=user_id, deleted=False)
            content = archive.get_content()
            excerpt = content[:500] + "..." if len(content) > 500 else content

            results.append(
                {
                    "id": str(archive.id),
                    "title": archive.title,
                    "url": archive.url,
                    "domain": archive.domain,
                    "excerpt": excerpt,
                    "archived_date": format_datetime_utc(archive.archived_date),
                    "categories": archive.ai_categories or [],
                    "visit_count": archive.visit_count,
                }
            )
        except MArchivedStory.DoesNotExist:
            continue

    return {
        "count": len(results),
        "archives": results,
        "query": query,
        "filters": {
            "date_from": date_from,
            "date_to": date_to,
            "domains": domains,
            "categories": categories,
        },
    }


def _get_archive_content(user_id, archive_id):
    """Get full content of a specific archive."""
    if not archive_id:
        return {"error": "archive_id is required"}

    try:
        archive = MArchivedStory.objects.get(id=archive_id, user_id=user_id, deleted=False)
    except MArchivedStory.DoesNotExist:
        return {"error": f"Archive not found: {archive_id}"}

    content = archive.get_content()

    return {
        "id": str(archive.id),
        "title": archive.title,
        "url": archive.url,
        "domain": archive.domain,
        "content": content,
        "content_length": len(content),
        "archived_date": format_datetime_utc(archive.archived_date),
        "first_visited": format_datetime_utc(archive.first_visited),
        "last_visited": format_datetime_utc(archive.last_visited),
        "visit_count": archive.visit_count,
        "categories": archive.ai_categories or [],
        "matched_to_feed": archive.matched_story_hash is not None,
    }


def _get_archive_summary(user_id):
    """Get summary statistics of user's archive."""
    total = MArchivedStory.objects(user_id=user_id, deleted=False).count()

    if total == 0:
        return {
            "total_archives": 0,
            "message": "No archived pages yet. Start browsing with the Archive Extension to build your archive.",
        }

    # Get category breakdown
    categories = MArchivedStory.get_category_breakdown(user_id)

    # Get domain breakdown
    domains = MArchivedStory.get_domain_breakdown(user_id, limit=10)

    # Get date range
    oldest = MArchivedStory.objects(user_id=user_id, deleted=False).order_by("archived_date").first()
    newest = MArchivedStory.objects(user_id=user_id, deleted=False).order_by("-archived_date").first()

    # Get recent activity
    week_ago = datetime.now() - timedelta(days=7)
    recent_count = MArchivedStory.objects(user_id=user_id, deleted=False, archived_date__gte=week_ago).count()

    return {
        "total_archives": total,
        "archives_this_week": recent_count,
        "categories": [{"name": c["_id"], "count": c["count"]} for c in categories[:10]],
        "top_domains": [{"domain": d["_id"], "count": d["count"]} for d in domains],
        "date_range": {
            "oldest": format_datetime_utc(oldest.archived_date) if oldest else None,
            "newest": format_datetime_utc(newest.archived_date) if newest else None,
        },
    }


def _get_recent_archives(user_id, limit=10, days=7):
    """Get most recently archived pages."""
    limit = min(limit or 10, 30)
    days = min(days or 7, 30)

    cutoff = datetime.now() - timedelta(days=days)

    archives = (
        MArchivedStory.objects(user_id=user_id, deleted=False, archived_date__gte=cutoff)
        .order_by("-archived_date")
        .limit(limit)
    )

    results = []
    for archive in archives:
        content = archive.get_content()
        excerpt = content[:300] + "..." if len(content) > 300 else content

        results.append(
            {
                "id": str(archive.id),
                "title": archive.title,
                "url": archive.url,
                "domain": archive.domain,
                "excerpt": excerpt,
                "archived_date": format_datetime_utc(archive.archived_date),
                "categories": archive.ai_categories or [],
            }
        )

    return {
        "count": len(results),
        "days": days,
        "archives": results,
    }


# RSS Feed Story Tools


def _search_starred_stories(
    user_id, query=None, tags=None, feed_title=None, date_from=None, date_to=None, limit=10
):
    """Search user's starred/saved RSS stories."""
    limit = min(limit or 10, 50)

    # Build query
    mongo_query = {"user_id": user_id}

    # Date filters
    if date_from:
        try:
            mongo_query["starred_date__gte"] = datetime.fromisoformat(date_from)
        except ValueError:
            pass
    if date_to:
        try:
            mongo_query["starred_date__lte"] = datetime.fromisoformat(date_to)
        except ValueError:
            pass

    # Tag filter
    if tags:
        mongo_query["user_tags__in"] = tags

    # Text search in title
    if query:
        mongo_query["story_title__icontains"] = query

    # Feed filter - need to look up feed IDs
    if feed_title:
        matching_feeds = Feed.objects.filter(feed_title__icontains=feed_title).values_list("id", flat=True)[
            :20
        ]
        if matching_feeds:
            mongo_query["story_feed_id__in"] = list(matching_feeds)

    stories = MStarredStory.objects(**mongo_query).order_by("-starred_date").limit(limit)

    results = []
    for story in stories:
        # Get content from compressed field if available
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

        # Get feed title
        feed_title_str = ""
        try:
            feed = Feed.objects.get(pk=story.story_feed_id)
            feed_title_str = feed.feed_title
        except Feed.DoesNotExist:
            pass

        results.append(
            {
                "story_hash": story.story_hash,
                "feed_id": story.story_feed_id,
                "title": story.story_title,
                "url": story.story_permalink,
                "feed": feed_title_str,
                "author": story.story_author_name,
                "excerpt": excerpt,
                "starred_date": format_datetime_utc(story.starred_date),
                "story_date": format_datetime_utc(story.story_date) if story.story_date else None,
                "user_tags": story.user_tags or [],
                "user_notes": story.user_notes or "",
                "has_highlights": bool(story.highlights),
            }
        )

    return {
        "count": len(results),
        "total": MStarredStory.objects(user_id=user_id).count(),
        "stories": results,
        "filters": {
            "query": query,
            "tags": tags,
            "feed_title": feed_title,
            "date_from": date_from,
            "date_to": date_to,
        },
    }


def _get_starred_story_content(user_id, story_hash):
    """Get full content of a specific starred story."""
    if not story_hash:
        return {"error": "story_hash is required"}

    try:
        story = MStarredStory.objects.get(user_id=user_id, story_hash=story_hash)
    except MStarredStory.DoesNotExist:
        return {"error": f"Starred story not found: {story_hash}"}

    # Get content from compressed field if available
    content = ""
    if story.story_content:
        content = story.story_content
    elif story.story_content_z:
        import zlib

        try:
            content = zlib.decompress(story.story_content_z).decode("utf-8")
        except Exception:
            content = ""

    # Try original text if available
    if not content and story.original_text_z:
        import zlib

        try:
            content = zlib.decompress(story.original_text_z).decode("utf-8")
        except Exception:
            pass

    # Get feed title
    feed_title = ""
    try:
        feed = Feed.objects.get(pk=story.story_feed_id)
        feed_title = feed.feed_title
    except Feed.DoesNotExist:
        pass

    return {
        "story_hash": story.story_hash,
        "feed_id": story.story_feed_id,
        "title": story.story_title,
        "url": story.story_permalink,
        "feed": feed_title,
        "author": story.story_author_name,
        "content": content,
        "content_length": len(content),
        "starred_date": format_datetime_utc(story.starred_date),
        "story_date": format_datetime_utc(story.story_date) if story.story_date else None,
        "user_tags": story.user_tags or [],
        "user_notes": story.user_notes or "",
        "highlights": story.highlights or [],
        "story_tags": story.story_tags or [],
    }


def _get_starred_summary(user_id):
    """Get summary of user's starred stories."""
    total = MStarredStory.objects(user_id=user_id).count()

    if total == 0:
        return {
            "total_starred": 0,
            "message": "No starred stories yet. Star stories in NewsBlur to save them.",
        }

    # Get tag counts (filter out None and empty string tags)
    from mongoengine.queryset.visitor import Q

    tag_counts = (
        MStarredStoryCounts.objects(user_id=user_id)
        .filter(Q(tag__ne=None) & Q(tag__ne=""))
        .order_by("-count")[:15]
    )
    tags = [{"name": tc.tag, "count": tc.count} for tc in tag_counts]

    # Get feed counts
    feed_counts = MStarredStoryCounts.objects(user_id=user_id, feed_id__ne=None, tag=None).order_by("-count")[
        :10
    ]
    feeds = []
    for fc in feed_counts:
        try:
            feed = Feed.objects.get(pk=fc.feed_id)
            feeds.append({"name": feed.feed_title, "count": fc.count, "feed_id": fc.feed_id})
        except Feed.DoesNotExist:
            pass

    # Get date range
    oldest = MStarredStory.objects(user_id=user_id).order_by("starred_date").first()
    newest = MStarredStory.objects(user_id=user_id).order_by("-starred_date").first()

    # Recent activity
    week_ago = datetime.now() - timedelta(days=7)
    recent_count = MStarredStory.objects(user_id=user_id, starred_date__gte=week_ago).count()

    # Count with highlights
    with_highlights = MStarredStory.objects(user_id=user_id, highlights__ne=[]).count()

    # Count with notes
    with_notes = (
        MStarredStory.objects(user_id=user_id).filter(Q(user_notes__ne=None) & Q(user_notes__ne="")).count()
    )

    return {
        "total_starred": total,
        "starred_this_week": recent_count,
        "with_highlights": with_highlights,
        "with_notes": with_notes,
        "user_tags": tags,
        "top_feeds": feeds,
        "date_range": {
            "oldest": format_datetime_utc(oldest.starred_date) if oldest else None,
            "newest": format_datetime_utc(newest.starred_date) if newest else None,
        },
    }


def _search_feed_stories(user_id, query, feed_ids=None, limit=10):
    """Search user's feed stories using Elasticsearch."""
    limit = min(limit or 10, 30)

    if not query:
        return {"error": "query is required for feed story search"}

    # Get the user's subscribed feed IDs if not provided
    if not feed_ids:
        feed_ids = list(UserSubscription.objects.filter(user_id=user_id).values_list("feed_id", flat=True))

    if not feed_ids:
        return {
            "count": 0,
            "stories": [],
            "query": query,
            "message": "No subscribed feeds to search.",
        }

    try:
        # SearchStory.query signature: (feed_ids, query, order, offset, limit, strip=False)
        story_hashes = SearchStory.query(
            feed_ids=feed_ids,
            query=query,
            order="newest",
            offset=0,
            limit=limit,
        )
    except Exception as e:
        logging.error(f"Feed story search error: {e}")
        return {"error": f"Search failed: {str(e)}", "count": 0, "stories": []}

    if not story_hashes:
        return {
            "count": 0,
            "stories": [],
            "query": query,
            "message": "No matching stories found in your feeds.",
        }

    # Fetch story details
    from apps.rss_feeds.models import MStory

    results = []
    for story_hash in story_hashes:
        try:
            story = MStory.objects.get(story_hash=story_hash)
            # Get content
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

            # Get feed title
            feed_title = ""
            try:
                feed = Feed.objects.get(pk=story.story_feed_id)
                feed_title = feed.feed_title
            except Feed.DoesNotExist:
                pass

            results.append(
                {
                    "story_hash": story.story_hash,
                    "feed_id": story.story_feed_id,
                    "title": story.story_title,
                    "url": story.story_permalink,
                    "feed": feed_title,
                    "author": story.story_author_name,
                    "excerpt": excerpt,
                    "story_date": format_datetime_utc(story.story_date),
                    "tags": story.story_tags or [],
                }
            )
        except MStory.DoesNotExist:
            continue

    return {
        "count": len(results),
        "stories": results,
        "query": query,
    }


def _get_feed_story_content(user_id, story_hash):
    """Get full content of a specific feed story."""
    from apps.rss_feeds.models import MStory

    if not story_hash:
        return {"error": "story_hash is required"}

    try:
        story = MStory.objects.get(story_hash=story_hash)
    except MStory.DoesNotExist:
        return {"error": f"Story not found: {story_hash}"}

    # Get content from compressed field if available
    content = ""
    if story.story_content:
        content = story.story_content
    elif story.story_content_z:
        import zlib

        try:
            content = zlib.decompress(story.story_content_z).decode("utf-8")
        except Exception:
            content = ""

    # Get feed title
    feed_title = ""
    try:
        feed = Feed.objects.get(pk=story.story_feed_id)
        feed_title = feed.feed_title
    except Feed.DoesNotExist:
        pass

    return {
        "story_hash": story.story_hash,
        "feed_id": story.story_feed_id,
        "title": story.story_title,
        "url": story.story_permalink,
        "feed": feed_title,
        "author": story.story_author_name,
        "content": content,
        "content_length": len(content),
        "story_date": format_datetime_utc(story.story_date),
        "tags": story.story_tags or [],
    }


def _search_shared_stories(user_id, query=None, limit=10):
    """Search stories shared by people the user follows."""
    from apps.social.models import MSharedStory, MSocialProfile

    limit = min(limit or 10, 30)

    # Get the user's social profile to find who they follow
    try:
        social_profile = MSocialProfile.get_user(user_id)
        following_ids = social_profile.following_user_ids or []
    except Exception as e:
        logging.error(f"Error getting social profile: {e}")
        return {
            "count": 0,
            "stories": [],
            "message": "Could not access social profile.",
        }

    if not following_ids:
        return {
            "count": 0,
            "stories": [],
            "message": "Not following anyone yet.",
        }

    # Query shared stories from followed users
    try:
        shared_stories = MSharedStory.objects.filter(user_id__in=following_ids).order_by("-shared_date")

        # If query provided, filter by title/content/comments
        if query:
            query_lower = query.lower()
            filtered_stories = []
            for story in shared_stories:
                title_match = query_lower in (story.story_title or "").lower()
                content = ""
                if story.story_content:
                    content = story.story_content
                elif story.story_content_z:
                    import zlib

                    try:
                        content = zlib.decompress(story.story_content_z).decode("utf-8")
                    except Exception:
                        content = ""
                content_match = query_lower in content.lower()
                comments_match = query_lower in (story.comments or "").lower()

                if title_match or content_match or comments_match:
                    filtered_stories.append(story)
                    if len(filtered_stories) >= limit:
                        break
            shared_stories = filtered_stories
        else:
            shared_stories = list(shared_stories[:limit])

    except Exception as e:
        logging.error(f"Error searching shared stories: {e}")
        return {"error": f"Search failed: {str(e)}", "count": 0, "stories": []}

    if not shared_stories:
        return {
            "count": 0,
            "stories": [],
            "query": query,
            "message": "No shared stories found.",
        }

    # Build results
    results = []
    for story in shared_stories:
        # Get content for excerpt
        content = ""
        if story.story_content:
            content = story.story_content
        elif story.story_content_z:
            import zlib

            try:
                content = zlib.decompress(story.story_content_z).decode("utf-8")
            except Exception:
                content = ""

        excerpt = content[:300] + "..." if len(content) > 300 else content

        # Get sharer's username
        sharer_name = ""
        try:
            sharer_profile = MSocialProfile.get_user(story.user_id)
            sharer_name = sharer_profile.user.username if sharer_profile.user else ""
        except Exception:
            pass

        results.append(
            {
                "story_hash": story.story_hash,
                "feed_id": story.story_feed_id,
                "title": story.story_title,
                "url": story.story_permalink,
                "author": story.story_author_name,
                "sharer": sharer_name,
                "sharer_comments": story.comments or "",
                "excerpt": excerpt,
                "shared_date": format_datetime_utc(story.shared_date),
                "story_date": format_datetime_utc(story.story_date) if story.story_date else None,
            }
        )

    return {
        "count": len(results),
        "stories": results,
        "query": query,
        "following_count": len(following_ids),
    }
