"""Account information tools."""

from newsblur_mcp.client import NewsBlurClient
from newsblur_mcp.server import mcp, get_client


async def _get_account_info(client: NewsBlurClient) -> dict:
    """Get information about the authenticated user's account."""
    resp = await client.get_unprotected("/profile/get_preferences")

    prefs = resp.get("preferences", {})
    user = resp.get("user", {})

    tier = "free"
    if user.get("is_pro"):
        tier = "pro"
    elif user.get("is_archive"):
        tier = "archive"
    elif user.get("is_premium"):
        tier = "premium"

    feed_limits = {"free": 64, "premium": 1024, "archive": 4096, "pro": 10000}

    return {
        "username": user.get("username", ""),
        "email": user.get("email", ""),
        "tier": tier,
        "is_premium": user.get("is_premium", False),
        "is_archive": user.get("is_archive", False),
        "is_pro": user.get("is_pro", False),
        "feed_count": user.get("feed_count", 0),
        "feed_limit": feed_limits.get(tier, 64),
        "premium_expire_date": user.get("premium_expire", ""),
    }


@mcp.tool()
async def newsblur_get_account_info() -> dict:
    """Get information about the authenticated user's account.

    Returns username, subscription tier (free/premium/archive/pro),
    feed count limits, and subscription stats. Use this to understand
    what features are available to the user.
    """
    client = get_client()
    try:
        return await _get_account_info(client)
    finally:
        await client.close()
