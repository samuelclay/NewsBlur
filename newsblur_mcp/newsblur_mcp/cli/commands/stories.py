"""Story commands: list, saved, search, infrequent, original, briefing."""

from __future__ import annotations

from typing import Optional

import typer
from rich.console import Console

from newsblur_mcp.cli.output import render, render_briefing, render_stories
from newsblur_mcp.cli.runner import async_command, get_authenticated_client

console = Console(stderr=True)
app = typer.Typer()


@app.command("list")
@async_command
async def stories_list(
    ctx: typer.Context,
    folder: Optional[str] = typer.Option(None, "--folder", "-f", help="Load stories from this folder"),
    feed: Optional[str] = typer.Option(
        None, "--feed", help="Comma-separated feed IDs to load stories from"
    ),
    filter: str = typer.Option(
        "unread", "--filter", help="Read filter: unread, all, focus, or starred"
    ),
    order: str = typer.Option("newest", "--order", "-o", help="Sort order: newest or oldest"),
    page: int = typer.Option(1, "--page", "-p", help="Page number"),
    limit: int = typer.Option(12, "--limit", "-l", help="Stories per page (max 50)"),
):
    """List stories from feeds, folders, or all subscriptions."""
    client = get_authenticated_client()
    try:
        feed_ids = [int(x.strip()) for x in feed.split(",")] if feed else None
        from newsblur_mcp.tools.stories import _get_stories

        result = await _get_stories(
            client,
            feed_ids=feed_ids,
            folder=folder,
            read_filter=filter,
            include_hidden=False,
            query=None,
            order=order,
            page=page,
            limit=limit,
        )
        render(ctx, result, render_stories)
    finally:
        await client.close()


@app.command("saved")
@async_command
async def stories_saved(
    ctx: typer.Context,
    tag: Optional[str] = typer.Option(None, "--tag", "-t", help="Filter by saved story tag"),
    query: Optional[str] = typer.Option(None, "--query", "-q", help="Search within saved stories"),
    order: str = typer.Option("newest", "--order", "-o", help="Sort order: newest or oldest"),
    page: int = typer.Option(1, "--page", "-p", help="Page number"),
    limit: int = typer.Option(12, "--limit", "-l", help="Stories per page (max 50)"),
):
    """View your saved/starred stories."""
    client = get_authenticated_client()
    try:
        from newsblur_mcp.tools.stories import _get_saved_stories

        result = await _get_saved_stories(
            client,
            tag=tag,
            query=query,
            order=order,
            page=page,
            limit=limit,
        )
        render(ctx, result, render_stories)
    finally:
        await client.close()


@app.command("search")
@async_command
async def stories_search(
    ctx: typer.Context,
    query: str = typer.Argument(..., help="Search query"),
    folder: Optional[str] = typer.Option(None, "--folder", "-f", help="Limit search to this folder"),
    feed: Optional[str] = typer.Option(
        None, "--feed", help="Comma-separated feed IDs to search within"
    ),
    page: int = typer.Option(1, "--page", "-p", help="Page number"),
    limit: int = typer.Option(12, "--limit", "-l", help="Results per page (max 50)"),
):
    """Search across all stories by keyword."""
    client = get_authenticated_client()
    try:
        feed_ids = [int(x.strip()) for x in feed.split(",")] if feed else None
        from newsblur_mcp.tools.stories import _search_stories

        result = await _search_stories(
            client,
            query=query,
            feed_ids=feed_ids,
            folder=folder,
            page=page,
            limit=limit,
        )
        render(ctx, result, render_stories)
    finally:
        await client.close()


@app.command("infrequent")
@async_command
async def stories_infrequent(
    ctx: typer.Context,
    threshold: int = typer.Option(
        30, "--threshold", "-t", help="Max stories/month for a feed to qualify"
    ),
    order: str = typer.Option("newest", "--order", "-o", help="Sort order: newest or oldest"),
    page: int = typer.Option(1, "--page", "-p", help="Page number"),
    limit: int = typer.Option(12, "--limit", "-l", help="Stories per page (max 50)"),
):
    """View stories from infrequently-publishing feeds."""
    client = get_authenticated_client()
    try:
        from newsblur_mcp.tools.stories import _get_infrequent_stories

        result = await _get_infrequent_stories(
            client,
            stories_per_month=threshold,
            read_filter="unread",
            include_hidden=False,
            order=order,
            page=page,
            limit=limit,
        )
        render(ctx, result, render_stories)
    finally:
        await client.close()


@app.command("original")
@async_command
async def stories_original(
    ctx: typer.Context,
    story_hash: str = typer.Argument(..., help="Story hash (e.g. '123:abcdef')"),
):
    """Fetch the full original text of a story from its source."""
    client = get_authenticated_client()
    try:
        from newsblur_mcp.tools.stories import _get_original_text

        result = await _get_original_text(client, story_hash=story_hash)
        render(ctx, result)
    finally:
        await client.close()


@async_command
async def briefing(
    ctx: typer.Context,
    limit: int = typer.Option(5, "--limit", "-l", help="Number of briefings to return"),
    page: int = typer.Option(1, "--page", "-p", help="Page number"),
):
    """View your daily briefing with AI-curated story summaries."""
    client = get_authenticated_client()
    try:
        from newsblur_mcp.tools.briefing import _get_daily_briefing

        result = await _get_daily_briefing(client, limit=limit, page=page)
        render(ctx, result, render_briefing)
    finally:
        await client.close()
