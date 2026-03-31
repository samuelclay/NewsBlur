"""Feed management tools."""

from newsblur_mcp.client import NewsBlurClient
from newsblur_mcp.server import mcp, get_client
from newsblur_mcp.transforms import transform_feed


async def _list_feeds(
    client: NewsBlurClient,
    flat: bool = True,
    include_favicons: bool = False,
) -> dict:
    """List all subscribed feeds organized by folder with unread counts."""
    params = {"flat": "true" if flat else "false"}
    if include_favicons:
        params["include_favicons"] = "true"

    resp = await client.get("/reader/feeds", params=params)

    feeds = {}
    for feed_id, feed_data in resp.get("feeds", {}).items():
        feeds[feed_id] = transform_feed(feed_data)

    return {
        "feeds": feeds,
        "folders": resp.get("flat_folders", resp.get("folders", {})),
        "starred_count": resp.get("starred_count", 0),
        "feed_count": len(feeds),
    }


@mcp.tool()
async def newsblur_list_feeds(
    flat: bool = True,
    include_favicons: bool = False,
) -> dict:
    """List all subscribed feeds organized by folder with unread counts.

    Provides a complete view of the user's subscription structure.
    Use this to understand what feeds the user follows and where to find content.

    Args:
        flat: Return flat folder->feeds structure (default: True).
        include_favicons: Include base64 favicon data (default: False).
    """
    client = get_client()
    try:
        return await _list_feeds(client, flat, include_favicons)
    finally:
        await client.close()


async def _list_folders(
    client: NewsBlurClient,
    include_counts: bool = True,
) -> dict:
    """List all folder names in the user's subscription structure."""
    resp = await client.get("/reader/feeds", params={"flat": "true"})
    flat_folders = resp.get("flat_folders", {})
    feeds_data = resp.get("feeds", {})

    folders = []
    for folder_name, feed_ids in flat_folders.items():
        display_name = "Top Level" if folder_name.strip() == "" else folder_name
        folder_info = {"name": display_name, "feed_count": len(feed_ids)}

        if include_counts:
            unread_neutral = 0
            unread_positive = 0
            for fid in feed_ids:
                feed = feeds_data.get(str(fid), {})
                unread_neutral += feed.get("nt", 0)
                unread_positive += feed.get("ps", 0)
            folder_info["unread_count"] = unread_neutral + unread_positive
            folder_info["focus_count"] = unread_positive

        folders.append(folder_info)

    return {"folders": folders, "folder_count": len(folders)}


@mcp.tool()
async def newsblur_list_folders(
    include_counts: bool = True,
) -> dict:
    """List all folder names in the user's subscription structure.

    Returns a compact list of folders. Use this to understand how feeds are organized
    before loading stories from a specific folder.

    Args:
        include_counts: Include unread story counts per folder (default: True).
    """
    client = get_client()
    try:
        return await _list_folders(client, include_counts)
    finally:
        await client.close()


async def _list_folders_with_feeds(
    client: NewsBlurClient,
    include_favicons: bool = False,
) -> dict:
    """List all folders with their feeds and unread counts."""
    params = {"flat": "true"}
    if include_favicons:
        params["include_favicons"] = "true"

    resp = await client.get("/reader/feeds", params=params)
    flat_folders = resp.get("flat_folders", {})
    feeds_data = resp.get("feeds", {})

    folders = {}
    for folder_name, feed_ids in flat_folders.items():
        display_name = "Top Level" if folder_name.strip() == "" else folder_name
        folder_feeds = []
        for fid in feed_ids:
            feed = feeds_data.get(str(fid), {})
            if feed:
                folder_feeds.append(transform_feed(feed))
        folders[display_name] = folder_feeds

    return {"folders": folders, "folder_count": len(folders)}


@mcp.tool()
async def newsblur_list_folders_with_feeds(
    include_favicons: bool = False,
) -> dict:
    """List all folders with their feeds and unread counts.

    Returns the full subscription structure: each folder mapped to its feeds
    with titles, IDs, and unread counts. Use this for a complete overview.

    Args:
        include_favicons: Include base64 favicon data per feed (default: False).
    """
    client = get_client()
    try:
        return await _list_folders_with_feeds(client, include_favicons)
    finally:
        await client.close()


async def _get_feed_info(client: NewsBlurClient, feed_id: int) -> dict:
    """Get detailed information about a specific feed."""
    resp = await client.get(f"/reader/feed/{feed_id}")
    feed = resp.get("feed", {})
    result = transform_feed(feed)

    try:
        stats_resp = await client.get(f"/rss_feeds/statistics/{feed_id}")
        result["statistics"] = {
            "stories_last_month": stats_resp.get("stories_last_month", 0),
            "average_stories_per_month": stats_resp.get("average_stories_per_month", 0),
            "last_update": stats_resp.get("last_update", ""),
            "next_update": stats_resp.get("next_update", ""),
            "feed_fetch_history": stats_resp.get("feed_fetch_history", [])[:5],
        }
    except Exception:
        pass

    return result


@mcp.tool()
async def newsblur_get_feed_info(feed_id: int) -> dict:
    """Get detailed information about a specific feed.

    Includes title, URL, subscriber count, update frequency, and statistics.
    Use this before subscribing or to understand a feed's health.

    Args:
        feed_id: The feed ID to look up.
    """
    client = get_client()
    try:
        return await _get_feed_info(client, feed_id)
    finally:
        await client.close()


async def _subscribe(
    client: NewsBlurClient,
    url: str,
    folder: str | None = None,
) -> dict:
    """Subscribe to a new feed by URL."""
    data = {"url": url}
    if folder:
        data["folder"] = folder

    resp = await client.post("/reader/add_url", data=data)
    return {
        "code": resp.get("code"),
        "message": resp.get("message", ""),
        "feed": transform_feed(resp.get("feed", {})) if resp.get("feed") else None,
    }


@mcp.tool()
async def newsblur_subscribe(
    url: str,
    folder: str | None = None,
) -> dict:
    """Subscribe to a new feed by URL.

    Automatically discovers the RSS/Atom feed from a website URL.
    Optionally place the feed in a folder.

    Args:
        url: Website or feed URL to subscribe to.
        folder: Folder to add the feed to (created if it doesn't exist).
    """
    client = get_client()
    try:
        return await _subscribe(client, url, folder)
    finally:
        await client.close()


async def _unsubscribe(
    client: NewsBlurClient,
    feed_id: int,
    folder: str | None = None,
) -> dict:
    """Unsubscribe from a feed."""
    data = {"feed_id": feed_id}
    if folder:
        data["in_folder"] = folder

    resp = await client.post("/reader/delete_feed", data=data)
    return {"code": resp.get("code"), "message": resp.get("message", "")}


@mcp.tool()
async def newsblur_unsubscribe(
    feed_id: int,
    folder: str | None = None,
) -> dict:
    """Unsubscribe from a feed.

    Args:
        feed_id: Feed ID to unsubscribe from.
        folder: Folder the feed is in (needed if the feed appears in multiple folders).
    """
    client = get_client()
    try:
        return await _unsubscribe(client, feed_id, folder)
    finally:
        await client.close()


async def _organize_feed(
    client: NewsBlurClient,
    action: str,
    feed_id: int | None = None,
    from_folder: str | None = None,
    to_folder: str | None = None,
    new_name: str | None = None,
) -> dict:
    """Move a feed to a different folder, rename a feed, or rename a folder."""
    if action == "move_feed":
        data = {"feed_id": feed_id, "in_folder": from_folder or "", "to_folder": to_folder or ""}
        resp = await client.post("/reader/move_feed_to_folder", data=data)
    elif action == "rename_feed":
        data = {"feed_id": feed_id, "feed_title": new_name}
        resp = await client.post("/reader/rename_feed", data=data)
    elif action == "rename_folder":
        data = {"folder_name": from_folder, "new_folder_name": new_name, "in_folder": ""}
        resp = await client.post("/reader/rename_folder", data=data)
    else:
        return {"error": f"Unknown action '{action}'. Use move_feed, rename_feed, or rename_folder."}

    return {"code": resp.get("code"), "message": resp.get("message", "")}


@mcp.tool()
async def newsblur_organize_feed(
    action: str,
    feed_id: int | None = None,
    from_folder: str | None = None,
    to_folder: str | None = None,
    new_name: str | None = None,
) -> dict:
    """Move a feed to a different folder, rename a feed, or rename a folder.

    Args:
        action: One of "move_feed", "rename_feed", or "rename_folder".
        feed_id: Feed ID (required for move_feed and rename_feed).
        from_folder: Current folder name (for move_feed).
        to_folder: Destination folder (for move_feed, created if doesn't exist).
        new_name: New name (required for rename_feed and rename_folder).
    """
    client = get_client()
    try:
        return await _organize_feed(client, action, feed_id, from_folder, to_folder, new_name)
    finally:
        await client.close()
