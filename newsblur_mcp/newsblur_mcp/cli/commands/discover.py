"""Discovery commands: search, similar, trending."""

from __future__ import annotations

from typing import Optional

import typer
from rich.console import Console

from newsblur_mcp.cli.output import render, render_discover_results
from newsblur_mcp.cli.runner import async_command, get_authenticated_client

console = Console(stderr=True)
from newsblur_mcp.cli import CONTEXT_SETTINGS

app = typer.Typer(context_settings=CONTEXT_SETTINGS)


@app.command("search")
@async_command
async def discover_search(
    ctx: typer.Context,
    query: str = typer.Argument(..., help="Search query to find feeds"),
):
    """Search for new feeds by topic or keyword."""
    client = get_authenticated_client()
    try:
        from newsblur_mcp.tools.discovery import _discover_feeds

        result = await _discover_feeds(
            client,
            action="search",
            query=query,
            feed_id=None,
            page=1,
        )
        render(ctx, result, render_discover_results)
    finally:
        await client.close()


@app.command("similar")
@async_command
async def discover_similar(
    ctx: typer.Context,
    feed_id: int = typer.Argument(..., help="Find feeds similar to this feed ID"),
):
    """Find feeds similar to one you already follow."""
    client = get_authenticated_client()
    try:
        from newsblur_mcp.tools.discovery import _discover_feeds

        result = await _discover_feeds(
            client,
            action="similar",
            query=None,
            feed_id=feed_id,
            page=1,
        )
        render(ctx, result, render_discover_results)
    finally:
        await client.close()


@app.command("trending")
@async_command
async def discover_trending(
    ctx: typer.Context,
    page: int = typer.Option(1, "--page", "-p", help="Page number"),
):
    """Browse trending feeds."""
    client = get_authenticated_client()
    try:
        from newsblur_mcp.tools.discovery import _discover_feeds

        result = await _discover_feeds(
            client,
            action="trending",
            query=None,
            feed_id=None,
            page=page,
        )
        render(ctx, result, render_discover_results)
    finally:
        await client.close()
