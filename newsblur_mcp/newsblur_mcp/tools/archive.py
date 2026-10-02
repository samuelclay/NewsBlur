"""Reading Archive tools: search the browser-extension reading archive and ask its AI assistant.

The Reading Archive is populated by the NewsBlur browser extension, which captures
pages the user reads in their normal web browser and syncs them into NewsBlur.
These tools expose that archive (apps/archive_extension) and the Archive Assistant
agent (apps/archive_assistant) over MCP.
"""

import asyncio

from newsblur_mcp.client import NewsBlurClient
from newsblur_mcp.server import get_client, mcp

DEFAULT_ARCHIVES_PER_PAGE = 12
MAX_ARCHIVES_PER_PAGE = 50

# The Archive Assistant runs asynchronously in a Celery task, so we poll the
# conversation endpoint until the submitted query has a response or an error.
ASSISTANT_POLL_INTERVAL_SECONDS = 2
ASSISTANT_TIMEOUT_SECONDS = 120


def _transform_archive(archive: dict) -> dict:
    """Trim an archive record from /api/archive/list to the fields agents need."""
    result = {
        "id": archive.get("id"),
        "title": archive.get("title"),
        "url": archive.get("url"),
        "domain": archive.get("domain"),
        "author": archive.get("author"),
        "first_visited": archive.get("first_visited"),
        "last_visited": archive.get("last_visited"),
        "visit_count": archive.get("visit_count"),
        "categories": archive.get("ai_categories") or [],
    }
    if archive.get("highlights"):
        result["highlights"] = archive["highlights"]
    if archive.get("content_preview"):
        result["content_preview"] = archive["content_preview"]
    return result


async def _search_archive(
    client: NewsBlurClient,
    query: str | None = None,
    domain: str | None = None,
    category: str | None = None,
    date_from: str | None = None,
    date_to: str | None = None,
    page: int = 1,
    limit: int = DEFAULT_ARCHIVES_PER_PAGE,
) -> dict:
    """Search or browse the reading archive via /api/archive/list."""
    limit = min(limit, MAX_ARCHIVES_PER_PAGE)
    params = {
        "limit": limit,
        "offset": (page - 1) * limit,
    }
    if query:
        params["search"] = query
    if domain:
        params["domain"] = domain
    if category:
        params["category"] = category
    if date_from:
        params["date_from"] = date_from
    if date_to:
        params["date_to"] = date_to

    resp = await client.get("/api/archive/list", params=params)
    if resp.get("code", 0) < 0:
        return {"error": resp.get("message", "Archive request failed")}

    archives = [_transform_archive(a) for a in resp.get("archives", [])]
    return {
        "items": archives,
        "page": page,
        "has_more": resp.get("has_more", False),
        "total": resp.get("total", len(archives)),
    }


@mcp.tool()
async def newsblur_search_archive(
    query: str | None = None,
    domain: str | None = None,
    category: str | None = None,
    date_from: str | None = None,
    date_to: str | None = None,
    page: int = 1,
    limit: int = DEFAULT_ARCHIVES_PER_PAGE,
) -> dict:
    """Search your Reading Archive -- pages you browsed in your web browser.

    The Reading Archive is synced by the NewsBlur browser extension from your
    normal web browsing, so it covers pages beyond NewsBlur stories. Full-text
    search returns highlighted matches; omit the query to browse chronologically.

    Args:
        query: Full-text search across archived page content and titles.
        domain: Limit to one domain (e.g. "macrumors.com").
        category: Limit to an AI-assigned category (e.g. "Shopping").
        date_from / date_to: Archived date range (ISO 8601).
        page: Page number for pagination (starts at 1).
        limit: Results per page (default 12, max 50).
    """
    client = get_client()
    try:
        return await _search_archive(client, query, domain, category, date_from, date_to, page, limit)
    finally:
        await client.close()


@mcp.tool()
async def newsblur_get_archive_stats() -> dict:
    """Get statistics about your Reading Archive.

    Returns total archived pages, matched stories, distinct domains, archives
    today/this week, and the most recent archive date. Useful for checking
    whether the browser extension is actively syncing.
    """
    client = get_client()
    try:
        resp = await client.get("/api/archive/stats")
        if resp.get("code", 0) < 0:
            return {"error": resp.get("message", "Archive stats request failed")}
        return resp.get("stats", {})
    finally:
        await client.close()


async def _ask_archive(
    client: NewsBlurClient,
    question: str,
    conversation_id: str | None = None,
) -> dict:
    """Submit a question to the Archive Assistant and wait for its answer."""
    data = {"query": question}
    if conversation_id:
        data["conversation_id"] = conversation_id

    resp = await client.post("/archive-assistant/query", data=data)
    if resp.get("code", 0) < 0:
        return {"error": resp.get("message", "Archive Assistant query failed")}

    query_id = resp.get("query_id")
    conversation_id = resp.get("conversation_id")

    # The assistant answers asynchronously; poll the conversation until our
    # query has a response or an error, or we hit the timeout.
    elapsed = 0
    while elapsed < ASSISTANT_TIMEOUT_SECONDS:
        await asyncio.sleep(ASSISTANT_POLL_INTERVAL_SECONDS)
        elapsed += ASSISTANT_POLL_INTERVAL_SECONDS

        conversation = await client.get(f"/archive-assistant/conversation/{conversation_id}")
        for q in conversation.get("queries", []):
            if q.get("id") != query_id:
                continue
            if q.get("error"):
                return {
                    "conversation_id": conversation_id,
                    "query_id": query_id,
                    "error": q["error"],
                }
            if q.get("response"):
                return {
                    "conversation_id": conversation_id,
                    "query_id": query_id,
                    "question": q.get("query_text"),
                    "answer": q["response"],
                    "model": q.get("model"),
                    "duration_ms": q.get("duration_ms"),
                }

    return {
        "conversation_id": conversation_id,
        "query_id": query_id,
        "error": f"Timed out after {ASSISTANT_TIMEOUT_SECONDS}s waiting for the Archive Assistant. "
        "Retrieve the answer later by asking a follow-up with this conversation_id.",
    }


@mcp.tool()
async def newsblur_ask_archive(
    question: str,
    conversation_id: str | None = None,
) -> dict:
    """Ask the Archive Assistant a question about your Reading Archive.

    The Archive Assistant is an AI agent over your full browsing archive.
    It answers questions like "what was that camera review I read last month?"
    or "summarize what I've been reading about home automation".

    Args:
        question: The question to ask (max 4096 characters).
        conversation_id: Conversation ID from a previous answer, for follow-ups.
    """
    client = get_client()
    try:
        return await _ask_archive(client, question, conversation_id)
    finally:
        await client.close()
