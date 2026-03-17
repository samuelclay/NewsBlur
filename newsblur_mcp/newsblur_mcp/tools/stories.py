"""Story loading and search tools."""

from newsblur_mcp.server import mcp, get_client
from newsblur_mcp.transforms import transform_story, paginate
from newsblur_mcp.settings import DEFAULT_STORIES_PER_PAGE, MAX_STORIES_PER_PAGE


@mcp.tool()
async def newsblur_get_stories(
    feed_ids: list[int] | None = None,
    folder: str | None = None,
    read_filter: str = "unread",
    include_hidden: bool = False,
    query: str | None = None,
    order: str = "newest",
    page: int = 1,
    limit: int = DEFAULT_STORIES_PER_PAGE,
) -> dict:
    """Load stories from feeds, folders, or all subscriptions.

    Returns unread stories by default, with content suitable for summarization.
    Use this to read what's new, catch up on a topic, or scan a specific feed.

    Args:
        feed_ids: Specific feed IDs to load stories from. Omit for all feeds.
        folder: Folder name to load all stories from (e.g. "Tech").
        read_filter: Filter stories by read/intelligence state. Options:
            "unread" (default) - only unread stories,
            "all" - include already-read stories,
            "focus" - only stories with positive intelligence scores,
            "starred" - only saved/starred stories.
        include_hidden: Include stories scored negatively by classifiers (default: False).
        query: Full-text search query to filter stories.
        order: Sort order - "newest" or "oldest".
        page: Page number for pagination (starts at 1).
        limit: Stories per page (default 12, max 50).
    """
    client = get_client()
    try:
        limit = min(limit, MAX_STORIES_PER_PAGE)

        resolved_feed_ids = feed_ids
        if folder and not feed_ids:
            feeds_resp = await client.get("/reader/feeds", params={"flat": "true"})
            flat_folders = feeds_resp.get("flat_folders", {})
            resolved_feed_ids = flat_folders.get(folder, [])
            if not resolved_feed_ids:
                return {"error": f"Folder '{folder}' not found or empty"}

        params = {
            "page": page,
            "order": order,
            "read_filter": read_filter,
        }
        if include_hidden:
            params["include_hidden"] = "true"
        if query:
            params["query"] = query
        if resolved_feed_ids:
            params["feeds"] = resolved_feed_ids

        resp = await client.post("/reader/river_stories", data=params)

        stories = [transform_story(s) for s in resp.get("stories", [])]
        return paginate(stories, page, has_more=len(stories) >= limit)
    finally:
        await client.close()


@mcp.tool()
async def newsblur_get_saved_stories(
    tag: str | None = None,
    query: str | None = None,
    order: str = "newest",
    page: int = 1,
    limit: int = DEFAULT_STORIES_PER_PAGE,
) -> dict:
    """Retrieve your saved/starred stories, optionally filtered by tag.

    Use this to recall previously saved articles for reference, research, or analysis.

    Args:
        tag: Filter by saved story tag (e.g. "research", "ai").
        query: Full-text search within saved stories.
        order: Sort order - "newest" or "oldest".
        page: Page number for pagination (starts at 1).
        limit: Stories per page (default 12, max 50).
    """
    client = get_client()
    try:
        limit = min(limit, MAX_STORIES_PER_PAGE)
        params = {"page": page, "order": order}
        if tag:
            params["tag"] = tag
        if query:
            params["query"] = query

        resp = await client.get("/reader/starred_stories", params=params)

        stories = [transform_story(s) for s in resp.get("stories", [])]
        result = paginate(stories, page, has_more=len(stories) >= limit)

        if page == 1:
            counts_resp = await client.get("/reader/starred_counts")
            result["tags"] = counts_resp.get("starred_counts", [])

        return result
    finally:
        await client.close()


@mcp.tool()
async def newsblur_search_stories(
    query: str,
    feed_ids: list[int] | None = None,
    folder: str | None = None,
    page: int = 1,
    limit: int = DEFAULT_STORIES_PER_PAGE,
) -> dict:
    """Search across all stories in subscribed feeds by keyword.

    Premium feature. Returns matching stories with content excerpts.

    Args:
        query: Search query (required).
        feed_ids: Limit search to specific feed IDs.
        folder: Limit search to feeds in this folder.
        page: Page number for pagination.
        limit: Results per page (default 12, max 50).
    """
    client = get_client()
    try:
        limit = min(limit, MAX_STORIES_PER_PAGE)

        resolved_feed_ids = feed_ids
        if folder and not feed_ids:
            feeds_resp = await client.get("/reader/feeds", params={"flat": "true"})
            flat_folders = feeds_resp.get("flat_folders", {})
            resolved_feed_ids = flat_folders.get(folder, [])

        params = {"query": query, "page": page, "order": "newest"}
        if resolved_feed_ids:
            params["feeds"] = resolved_feed_ids

        resp = await client.post("/reader/river_stories", data=params)
        stories = [transform_story(s) for s in resp.get("stories", [])]
        return paginate(stories, page, has_more=len(stories) >= limit)
    finally:
        await client.close()


@mcp.tool()
async def newsblur_get_infrequent_stories(
    stories_per_month: int = 30,
    read_filter: str = "unread",
    include_hidden: bool = False,
    order: str = "newest",
    page: int = 1,
    limit: int = DEFAULT_STORIES_PER_PAGE,
) -> dict:
    """Load stories from infrequently-publishing feeds.

    Filters to only show stories from feeds that publish below a threshold,
    surfacing content from low-volume sites you might otherwise miss.

    Args:
        stories_per_month: Maximum average stories/month for a feed to qualify (default: 30).
        read_filter: Filter by read state - "unread", "all", "focus", or "starred".
        include_hidden: Include stories scored negatively by classifiers (default: False).
        order: Sort order - "newest" or "oldest".
        page: Page number for pagination (starts at 1).
        limit: Stories per page (default 12, max 50).
    """
    client = get_client()
    try:
        limit = min(limit, MAX_STORIES_PER_PAGE)

        feeds_resp = await client.get("/reader/feeds", params={"flat": "true"})
        flat_folders = feeds_resp.get("flat_folders", {})
        all_feed_ids = []
        for feed_ids_in_folder in flat_folders.values():
            all_feed_ids.extend(feed_ids_in_folder)

        if not all_feed_ids:
            return paginate([], page, has_more=False)

        params = {
            "feeds": all_feed_ids,
            "infrequent": stories_per_month,
            "page": page,
            "order": order,
            "read_filter": read_filter,
        }
        if include_hidden:
            params["include_hidden"] = "true"

        resp = await client.post("/reader/river_stories", data=params)

        stories = [transform_story(s) for s in resp.get("stories", [])]
        return paginate(stories, page, has_more=len(stories) >= limit)
    finally:
        await client.close()


@mcp.tool()
async def newsblur_get_original_text(story_hash: str) -> dict:
    """Fetch the full original text of a story from the source website.

    Use this when story content is truncated or you need the complete article.

    Args:
        story_hash: The story hash identifier (e.g. "123:abcdef").
    """
    client = get_client()
    try:
        resp = await client.get("/rss_feeds/original_text", params={"story_hash": story_hash})
        from newsblur_mcp.transforms import html_to_text

        original_html = resp.get("original_text", "")
        return {
            "story_hash": story_hash,
            "original_text": html_to_text(original_html),
        }
    finally:
        await client.close()
