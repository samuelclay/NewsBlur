"""Feed discovery tools."""

from newsblur_mcp.client import NewsBlurClient
from newsblur_mcp.server import mcp, get_client
from newsblur_mcp.transforms import transform_feed


async def _discover_feeds(
    client: NewsBlurClient,
    action: str,
    query: str | None = None,
    feed_id: int | None = None,
    page: int = 1,
) -> dict:
    """Discover new feeds by searching, finding similar feeds, or browsing trending."""
    if action == "search":
        if not query:
            return {"error": "Query is required for search action."}
        resp = await client.get("/discover/search_feed", params={"address": query})
        feeds = [transform_feed(f) for f in resp.get("feeds", [])]
        return {"feeds": feeds, "count": len(feeds)}

    elif action == "similar":
        if not feed_id:
            return {"error": "feed_id is required for similar action."}
        resp = await client.get(f"/discover/similar/{feed_id}")
        feeds = [transform_feed(f) for f in resp.get("feeds", [])]
        return {"feeds": feeds, "count": len(feeds)}

    elif action == "trending":
        resp = await client.get("/reader/trending_feeds", params={"page": page})
        feeds = [transform_feed(f) for f in resp.get("feeds", [])]
        return {"feeds": feeds, "count": len(feeds), "page": page}

    else:
        return {"error": f"Unknown action '{action}'. Use search, similar, or trending."}


@mcp.tool()
async def newsblur_discover_feeds(
    action: str,
    query: str | None = None,
    feed_id: int | None = None,
    page: int = 1,
) -> dict:
    """Discover new feeds by searching, finding similar feeds, or browsing trending.

    Use this to help users expand their reading.

    Args:
        action: One of "search", "similar", or "trending".
        query: Search query (required for "search" action).
        feed_id: Find feeds similar to this one (required for "similar" action).
        page: Page number for pagination.
    """
    client = get_client()
    try:
        return await _discover_feeds(client, action, query, feed_id, page)
    finally:
        await client.close()
