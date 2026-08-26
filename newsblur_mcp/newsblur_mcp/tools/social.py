"""Social and community story tools: shared story rivers and trending reads.

Exposes the Global Shared Stories river, the user's friends' shared stories
(blurblogs), and the permanent trending lists (widely-read stories, long
reads, and good reads) over MCP.
"""

from newsblur_mcp.client import NewsBlurClient
from newsblur_mcp.server import get_client, mcp
from newsblur_mcp.transforms import paginate, transform_story

DEFAULT_STORIES_PER_PAGE = 12
MAX_STORIES_PER_PAGE = 50

TRENDING_TYPES = ("well_read", "long_reads", "good_reads")


def _transform_shared_story(story: dict) -> dict:
    """Base story transform plus the social metadata shared rivers carry."""
    result = transform_story(story)
    for key in ("share_count", "comment_count"):
        if story.get(key):
            result[key] = story[key]
    shared_by = (story.get("shared_by_public") or []) + (story.get("shared_by_friends") or [])
    if shared_by:
        result["shared_by_user_ids"] = shared_by
    if story.get("comments"):
        result["comments"] = [
            {
                "user_id": c.get("user_id"),
                "comment": c.get("comments", ""),
                "date": c.get("shared_date", ""),
            }
            for c in story["comments"]
        ]
    return result


async def _get_shared_stories(
    client: NewsBlurClient,
    global_feed: bool = True,
    social_user_ids: list[int] | None = None,
    read_filter: str = "all",
    order: str = "newest",
    page: int = 1,
    limit: int = DEFAULT_STORIES_PER_PAGE,
) -> dict:
    """Load the global or friends' shared stories river via /social/river_stories."""
    limit = min(limit, MAX_STORIES_PER_PAGE)
    params = {
        "page": page,
        "limit": limit,
        "order": order,
        "read_filter": read_filter,
    }
    if global_feed:
        params["global_feed"] = "true"
    if social_user_ids:
        params["social_user_ids"] = social_user_ids

    resp = await client.get("/social/river_stories", params=params)
    if resp.get("code", 0) < 0:
        return {"error": resp.get("message", "Shared stories request failed")}

    stories = [_transform_shared_story(s) for s in resp.get("stories", [])]
    return paginate(stories, page, has_more=len(stories) >= limit)


@mcp.tool()
async def newsblur_get_shared_stories(
    global_feed: bool = True,
    social_user_ids: list[int] | None = None,
    read_filter: str = "all",
    order: str = "newest",
    page: int = 1,
    limit: int = DEFAULT_STORIES_PER_PAGE,
) -> dict:
    """Load shared stories -- the Global Shared Stories river or your friends' shares.

    Stories include share counts and public comments where present.

    Args:
        global_feed: True (default) for the site-wide Global Shared Stories
            river; False for shares from people you follow (blurblogs).
        social_user_ids: Limit the friends river to these sharer user IDs
            (only when global_feed is False).
        read_filter: "all" (default) or "unread".
        order: Sort order - "newest" (default) or "oldest".
        page: Page number for pagination (starts at 1).
        limit: Stories per page (default 12, max 50).
    """
    client = get_client()
    try:
        return await _get_shared_stories(
            client, global_feed, social_user_ids, read_filter, order, page, limit
        )
    finally:
        await client.close()


async def _get_trending_stories(
    client: NewsBlurClient,
    trending_type: str = "well_read",
    read_filter: str = "all",
    order: str = "newest",
    page: int = 1,
    limit: int = DEFAULT_STORIES_PER_PAGE,
) -> dict:
    """Load one of the permanent trending story lists via /reader/trending_stories."""
    if trending_type not in TRENDING_TYPES:
        return {"error": f"trending_type must be one of {', '.join(TRENDING_TYPES)}"}
    limit = min(limit, MAX_STORIES_PER_PAGE)

    resp = await client.get(
        "/reader/trending_stories",
        params={
            "trending_type": trending_type,
            "page": page,
            "limit": limit,
            "order": order,
            "read_filter": read_filter,
        },
    )
    if resp.get("code", 0) < 0:
        return {"error": resp.get("message", "Trending stories request failed")}

    stories = [_transform_shared_story(s) for s in resp.get("stories", [])]
    result = paginate(stories, page, has_more=len(stories) >= limit)
    result["trending_type"] = trending_type
    return result


@mcp.tool()
async def newsblur_get_trending_stories(
    trending_type: str = "well_read",
    read_filter: str = "all",
    order: str = "newest",
    page: int = 1,
    limit: int = DEFAULT_STORIES_PER_PAGE,
) -> dict:
    """Load NewsBlur's trending story lists: widely-read stories, long reads, or good reads.

    Service-wide rivers built from what NewsBlur readers actually spend time on.

    Args:
        trending_type: "well_read" (default, widely-read stories), "long_reads"
            (stories readers spent a long time with), or "good_reads"
            (strongest engagement signals).
        read_filter: "all" (default) or "unread" to hide stories you've read.
        order: Sort order - "newest" (default) or "oldest".
        page: Page number for pagination (starts at 1).
        limit: Stories per page (default 12, max 50).
    """
    client = get_client()
    try:
        return await _get_trending_stories(client, trending_type, read_filter, order, page, limit)
    finally:
        await client.close()
