"""Notification management tools."""

from newsblur_mcp.client import NewsBlurClient
from newsblur_mcp.server import mcp, get_client


async def _manage_notifications(
    client: NewsBlurClient,
    action: str,
    feed_id: int | None = None,
    notification_types: list[str] | None = None,
    notification_filter: str | None = None,
) -> dict:
    """View or configure push notifications for specific feeds."""
    if action == "list":
        resp = await client.get("/notifications/")
        return {"notifications": resp.get("notifications", [])}

    elif action == "set":
        if not feed_id:
            return {"error": "feed_id is required for set action."}
        data = {"feed_id": feed_id}
        if notification_types:
            data["notification_types"] = notification_types
        if notification_filter:
            data["notification_filter"] = notification_filter
        resp = await client.post("/notifications/feed/", data=data)
        return {"code": resp.get("code"), "message": "Notification settings updated"}

    else:
        return {"error": f"Unknown action '{action}'. Use list or set."}


@mcp.tool()
async def newsblur_manage_notifications(
    action: str,
    feed_id: int | None = None,
    notification_types: list[str] | None = None,
    notification_filter: str | None = None,
) -> dict:
    """View or configure push notifications for specific feeds.

    Args:
        action: "list" to view all notification settings, or "set" to configure.
        feed_id: Feed ID to configure (required for "set" action).
        notification_types: List of types to enable: "web", "email", "ios", "android".
        notification_filter: Filter level: "unread" or "focus".
    """
    client = get_client()
    try:
        return await _manage_notifications(client, action, feed_id, notification_types, notification_filter)
    finally:
        await client.close()
