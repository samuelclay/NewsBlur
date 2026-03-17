"""Daily briefing tools."""

from newsblur_mcp.server import mcp, get_client
from newsblur_mcp.transforms import transform_briefing, paginate


@mcp.tool()
async def newsblur_get_daily_briefing(
    limit: int = 5,
    page: int = 1,
) -> dict:
    """Get your daily briefing with AI-curated story summaries and sections.

    Returns briefings organized by sections like top stories, infrequent site
    stories, long reads, classifier matches, and more. Each briefing includes
    curated stories with summaries.

    Args:
        limit: Number of briefings to return (default 5, max 50).
        page: Page number for pagination (starts at 1).
    """
    client = get_client()
    try:
        limit = min(limit, 50)
        resp = await client.get("/briefing/stories", params={
            "limit": limit,
            "page": page,
        })

        if resp.get("code") == -1:
            return {"error": resp.get("message", "Daily Briefing is not available.")}

        section_definitions = resp.get("section_definitions", {})
        briefings = [
            transform_briefing(b, section_definitions)
            for b in resp.get("briefings", [])
        ]

        result = paginate(briefings, page, has_more=resp.get("has_next_page", False))
        result["enabled"] = resp.get("enabled", False)
        result["is_preview"] = resp.get("is_preview", False)
        result["section_definitions"] = section_definitions
        return result
    finally:
        await client.close()
