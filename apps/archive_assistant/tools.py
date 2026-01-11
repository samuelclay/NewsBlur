"""
Tool definitions for the Archive Assistant.

These tools allow Claude to search and retrieve content from
the user's browsing archive.
"""

from datetime import datetime, timedelta

from apps.archive_extension.models import MArchivedStory
from apps.archive_extension.search import SearchArchive

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
    if tool_name == "search_archives":
        return _search_archives(user_id, **tool_input)
    elif tool_name == "get_archive_content":
        return _get_archive_content(user_id, tool_input.get("archive_id"))
    elif tool_name == "get_archive_summary":
        return _get_archive_summary(user_id)
    elif tool_name == "get_recent_archives":
        return _get_recent_archives(user_id, **tool_input)
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
                    "archived_date": (archive.archived_date.isoformat() + "Z") if archive.archived_date else None,
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
        "archived_date": (archive.archived_date.isoformat() + "Z") if archive.archived_date else None,
        "first_visited": (archive.first_visited.isoformat() + "Z") if archive.first_visited else None,
        "last_visited": (archive.last_visited.isoformat() + "Z") if archive.last_visited else None,
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
    recent_count = MArchivedStory.objects(
        user_id=user_id, deleted=False, archived_date__gte=week_ago
    ).count()

    return {
        "total_archives": total,
        "archives_this_week": recent_count,
        "categories": [{"name": c["_id"], "count": c["count"]} for c in categories[:10]],
        "top_domains": [{"domain": d["_id"], "count": d["count"]} for d in domains],
        "date_range": {
            "oldest": (oldest.archived_date.isoformat() + "Z") if oldest else None,
            "newest": (newest.archived_date.isoformat() + "Z") if newest else None,
        },
    }


def _get_recent_archives(user_id, limit=10, days=7):
    """Get most recently archived pages."""
    limit = min(limit or 10, 30)
    days = min(days or 7, 30)

    cutoff = datetime.now() - timedelta(days=days)

    archives = MArchivedStory.objects(
        user_id=user_id, deleted=False, archived_date__gte=cutoff
    ).order_by("-archived_date").limit(limit)

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
                "archived_date": (archive.archived_date.isoformat() + "Z") if archive.archived_date else None,
                "categories": archive.ai_categories or [],
            }
        )

    return {
        "count": len(results),
        "days": days,
        "archives": results,
    }
