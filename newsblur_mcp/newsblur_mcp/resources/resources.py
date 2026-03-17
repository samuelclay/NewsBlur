"""MCP Resources - read-only data at stable URIs."""

from fastmcp import Context

from newsblur_mcp.server import mcp, get_client
from newsblur_mcp.transforms import transform_feed


@mcp.resource("newsblur://feeds")
async def feeds_resource(context: Context) -> dict:
    """All subscribed feeds with unread counts, organized by folder."""
    client = get_client(context)
    try:
        resp = await client.get("/reader/feeds", params={"flat": "true"})
        feeds = {fid: transform_feed(f) for fid, f in resp.get("feeds", {}).items()}
        return {"feeds": feeds, "folders": resp.get("flat_folders", {})}
    finally:
        await client.close()


@mcp.resource("newsblur://feeds/{feed_id}")
async def feed_resource(context: Context, feed_id: int) -> dict:
    """Single feed metadata and statistics."""
    client = get_client(context)
    try:
        resp = await client.get(f"/reader/feed/{feed_id}")
        return transform_feed(resp.get("feed", {}))
    finally:
        await client.close()


@mcp.resource("newsblur://folders")
async def folders_resource(context: Context) -> dict:
    """Folder tree structure."""
    client = get_client(context)
    try:
        resp = await client.get("/reader/feeds", params={"flat": "true"})
        return {"folders": resp.get("flat_folders", {})}
    finally:
        await client.close()


@mcp.resource("newsblur://saved/tags")
async def saved_tags_resource(context: Context) -> dict:
    """List of all saved story tags with counts."""
    client = get_client(context)
    try:
        resp = await client.get("/reader/starred_counts")
        return {"tags": resp.get("starred_counts", []), "total": resp.get("starred_count", 0)}
    finally:
        await client.close()


@mcp.resource("newsblur://classifiers")
async def classifiers_resource(context: Context) -> dict:
    """All trained classifiers organized by feed."""
    client = get_client(context)
    try:
        resp = await client.get("/reader/all_classifiers")
        return {"classifiers": resp.get("classifiers", {})}
    finally:
        await client.close()


@mcp.resource("newsblur://profile")
async def profile_resource(context: Context) -> dict:
    """Current user profile, tier, and preferences."""
    client = get_client(context)
    try:
        resp = await client.get("/profile/get_preferences")
        user = resp.get("user", {})
        tier = "free"
        if user.get("is_pro"):
            tier = "pro"
        elif user.get("is_archive"):
            tier = "archive"
        elif user.get("is_premium"):
            tier = "premium"
        return {
            "username": user.get("username", ""),
            "tier": tier,
            "feed_count": user.get("feed_count", 0),
        }
    finally:
        await client.close()
