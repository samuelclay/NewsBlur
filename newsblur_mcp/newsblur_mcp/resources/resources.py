"""MCP Resources - read-only data at stable URIs."""

from fastmcp import Context
from fastmcp.resources import ResourceContent, ResourceResult

from newsblur_mcp.server import get_client, mcp
from newsblur_mcp.transforms import transform_feed


def _json_resource(data: dict) -> ResourceResult:
    return ResourceResult([ResourceContent(data)])


@mcp.resource("newsblur://feeds")
async def feeds_resource(context: Context) -> ResourceResult:
    """All subscribed feeds with unread counts, organized by folder."""
    client = get_client()
    try:
        resp = await client.get_feeds()
        feeds = {fid: transform_feed(f) for fid, f in resp.get("feeds", {}).items()}
        return _json_resource({"feeds": feeds, "folders": resp.get("flat_folders", {})})
    finally:
        await client.close()


@mcp.resource("newsblur://feeds/{feed_id}")
async def feed_resource(context: Context, feed_id: int) -> ResourceResult:
    """Single feed metadata and statistics."""
    client = get_client()
    try:
        resp = await client.get(f"/reader/feed/{feed_id}")
        return _json_resource(transform_feed(resp.get("feed", {})))
    finally:
        await client.close()


@mcp.resource("newsblur://folders")
async def folders_resource(context: Context) -> ResourceResult:
    """Folder tree structure."""
    client = get_client()
    try:
        resp = await client.get_feeds()
        return _json_resource({"folders": resp.get("flat_folders", {})})
    finally:
        await client.close()


@mcp.resource("newsblur://saved/tags")
async def saved_tags_resource(context: Context) -> ResourceResult:
    """List of all saved story tags with counts."""
    client = get_client()
    try:
        resp = await client.get("/reader/starred_counts")
        return _json_resource({"tags": resp.get("starred_counts", []), "total": resp.get("starred_count", 0)})
    finally:
        await client.close()


@mcp.resource("newsblur://classifiers")
async def classifiers_resource(context: Context) -> ResourceResult:
    """All trained classifiers organized by feed."""
    client = get_client()
    try:
        resp = await client.get("/reader/all_classifiers")
        return _json_resource({"classifiers": resp.get("classifiers", {})})
    finally:
        await client.close()


@mcp.resource("newsblur://profile")
async def profile_resource(context: Context) -> ResourceResult:
    """Current user profile, tier, and preferences."""
    client = get_client()
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
        return _json_resource(
            {
                "username": user.get("username", ""),
                "tier": tier,
                "feed_count": user.get("feed_count", 0),
            }
        )
    finally:
        await client.close()
