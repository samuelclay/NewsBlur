"""Story loading and search tools."""

from newsblur_mcp.client import NewsBlurClient
from newsblur_mcp.server import mcp, get_client
from newsblur_mcp.transforms import transform_story, paginate, html_to_text
from newsblur_mcp.settings import DEFAULT_STORIES_PER_PAGE, MAX_STORIES_PER_PAGE


async def _get_stories(
    client: NewsBlurClient,
    feed_ids: list[int] | None = None,
    folder: str | None = None,
    read_filter: str = "unread",
    include_hidden: bool = False,
    query: str | None = None,
    order: str = "newest",
    page: int = 1,
    limit: int = DEFAULT_STORIES_PER_PAGE,
) -> dict:
    """Load stories from feeds, folders, or all subscriptions."""
    limit = min(limit, MAX_STORIES_PER_PAGE)

    resolved_feed_ids = feed_ids
    if folder and not feed_ids:
        feeds_resp = await client.get_feeds()
        flat_folders = feeds_resp.get("flat_folders", {})
        resolved_feed_ids = flat_folders.get(folder, [])
        if not resolved_feed_ids:
            return {"error": f"Folder '{folder}' not found or empty"}

    params = {
        "page": page,
        "limit": limit,
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

    stories = [transform_story(s) for s in resp.get("stories", [])][:limit]
    return paginate(stories, page, has_more=len(resp.get("stories", [])) >= limit)


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
        return await _get_stories(client, feed_ids, folder, read_filter, include_hidden, query, order, page, limit)
    finally:
        await client.close()


async def _get_saved_stories(
    client: NewsBlurClient,
    tag: str | None = None,
    query: str | None = None,
    order: str = "newest",
    page: int = 1,
    limit: int = DEFAULT_STORIES_PER_PAGE,
) -> dict:
    """Retrieve saved/starred stories, optionally filtered by tag."""
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
        return await _get_saved_stories(client, tag, query, order, page, limit)
    finally:
        await client.close()


async def _get_read_stories(
    client: NewsBlurClient,
    feed_ids: list[int] | None = None,
    folder: str | None = None,
    query: str | None = None,
    order: str = "newest",
    page: int = 1,
    limit: int = DEFAULT_STORIES_PER_PAGE,
    date_filter_start: str | None = None,
    date_filter_end: str | None = None,
) -> dict:
    """Retrieve previously read stories, optionally filtered."""
    limit = min(limit, MAX_STORIES_PER_PAGE)

    resolved_feed_ids = feed_ids
    if folder and not feed_ids:
        feeds_resp = await client.get_feeds()
        flat_folders = feeds_resp.get("flat_folders", {})
        resolved_feed_ids = flat_folders.get(folder, [])
        if not resolved_feed_ids:
            return {"error": f"Folder '{folder}' not found or empty"}

    params = {"page": page, "order": order, "limit": limit}
    if query:
        params["query"] = query
    if date_filter_start:
        params["date_filter_start"] = date_filter_start
    if date_filter_end:
        params["date_filter_end"] = date_filter_end
    if resolved_feed_ids:
        params["feed_id"] = resolved_feed_ids

    resp = await client.get("/reader/read_stories", params=params)

    stories = [transform_story(s) for s in resp.get("stories", [])]
    return paginate(stories, page, has_more=len(stories) >= limit)


@mcp.tool()
async def newsblur_get_read_stories(
    feed_ids: list[int] | None = None,
    folder: str | None = None,
    query: str | None = None,
    order: str = "newest",
    page: int = 1,
    limit: int = DEFAULT_STORIES_PER_PAGE,
    date_filter_start: str | None = None,
    date_filter_end: str | None = None,
) -> dict:
    """Browse your reading history -- stories you've already read.

    Use this to find a story you read recently but can't quite remember.
    Describe what you recall and use the query parameter, or browse
    chronologically. Combine with feed or folder filters to narrow scope.

    Args:
        feed_ids: Limit to stories from specific feed IDs.
        folder: Limit to stories from feeds in this folder (e.g. "Tech").
        query: Full-text search within read stories (premium feature).
        order: Sort order - "newest" (default) or "oldest".
        page: Page number for pagination (starts at 1).
        limit: Stories per page (default 12, max 50).
        date_filter_start: Start date for date range filter (YYYY-MM-DD, Archive tier).
        date_filter_end: End date for date range filter (YYYY-MM-DD, Archive tier).
    """
    client = get_client()
    try:
        return await _get_read_stories(
            client, feed_ids, folder, query, order, page, limit,
            date_filter_start, date_filter_end,
        )
    finally:
        await client.close()


async def _search_stories(
    client: NewsBlurClient,
    query: str,
    feed_ids: list[int] | None = None,
    folder: str | None = None,
    page: int = 1,
    limit: int = DEFAULT_STORIES_PER_PAGE,
) -> dict:
    """Search across all stories in subscribed feeds by keyword."""
    limit = min(limit, MAX_STORIES_PER_PAGE)

    resolved_feed_ids = feed_ids
    if folder and not feed_ids:
        feeds_resp = await client.get_feeds()
        flat_folders = feeds_resp.get("flat_folders", {})
        resolved_feed_ids = flat_folders.get(folder, [])

    params = {"query": query, "page": page, "order": "newest"}
    if resolved_feed_ids:
        params["feeds"] = resolved_feed_ids

    resp = await client.post("/reader/river_stories", data=params)
    stories = [transform_story(s) for s in resp.get("stories", [])]
    return paginate(stories, page, has_more=len(stories) >= limit)


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
        return await _search_stories(client, query, feed_ids, folder, page, limit)
    finally:
        await client.close()


async def _get_infrequent_stories(
    client: NewsBlurClient,
    stories_per_month: int = 30,
    read_filter: str = "unread",
    include_hidden: bool = False,
    order: str = "newest",
    page: int = 1,
    limit: int = DEFAULT_STORIES_PER_PAGE,
) -> dict:
    """Load stories from infrequently-publishing feeds."""
    limit = min(limit, MAX_STORIES_PER_PAGE)

    feeds_resp = await client.get_feeds()
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
        "limit": limit,
        "order": order,
        "read_filter": read_filter,
    }
    if include_hidden:
        params["include_hidden"] = "true"

    resp = await client.post("/reader/river_stories", data=params)

    stories = [transform_story(s) for s in resp.get("stories", [])][:limit]
    return paginate(stories, page, has_more=len(resp.get("stories", [])) >= limit)


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
        return await _get_infrequent_stories(client, stories_per_month, read_filter, include_hidden, order, page, limit)
    finally:
        await client.close()


async def _get_original_text(client: NewsBlurClient, story_hash: str) -> dict:
    """Fetch the full original text of a story from the source website."""
    resp = await client.get("/rss_feeds/original_text", params={"story_hash": story_hash})

    original_html = resp.get("original_text", "")
    return {
        "story_hash": story_hash,
        "original_text": html_to_text(original_html),
    }


@mcp.tool()
async def newsblur_get_original_text(story_hash: str) -> dict:
    """Fetch the full original text of a story from the source website.

    Use this when story content is truncated or you need the complete article.

    Args:
        story_hash: The story hash identifier (e.g. "123:abcdef").
    """
    client = get_client()
    try:
        return await _get_original_text(client, story_hash)
    finally:
        await client.close()
