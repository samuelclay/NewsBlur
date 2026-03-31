"""Feed commands: list, info, add, remove, folders, organize."""

from __future__ import annotations

from typing import Optional

import typer
from rich.console import Console

from newsblur_mcp.cli.output import render, render_feeds_table, render_folders
from newsblur_mcp.cli.runner import async_command, get_authenticated_client

console = Console(stderr=True)
from newsblur_mcp.cli import CONTEXT_SETTINGS

app = typer.Typer(context_settings=CONTEXT_SETTINGS)


@app.command("list")
@async_command
async def feeds_list(
    ctx: typer.Context,
    flat: bool = typer.Option(True, "--flat/--tree", help="Flat folder structure (default) or tree"),
):
    """List all subscribed feeds with unread counts."""
    client = get_authenticated_client()
    try:
        from newsblur_mcp.tools.feeds import _list_feeds

        result = await _list_feeds(client, flat=flat, include_favicons=False)
        render(ctx, result, render_feeds_table)
    finally:
        await client.close()


@app.command("info")
@async_command
async def feeds_info(
    ctx: typer.Context,
    feed_id: int = typer.Argument(..., help="Feed ID to look up"),
):
    """Get detailed information about a specific feed."""
    client = get_authenticated_client()
    try:
        from newsblur_mcp.tools.feeds import _get_feed_info

        result = await _get_feed_info(client, feed_id=feed_id)
        render(ctx, result)
    finally:
        await client.close()


@app.command("add")
@async_command
async def feeds_add(
    ctx: typer.Context,
    url: str = typer.Argument(..., help="Website or feed URL to subscribe to"),
    folder: Optional[str] = typer.Option(None, "--folder", "-f", help="Folder to place the feed in"),
):
    """Subscribe to a new feed by URL."""
    client = get_authenticated_client()
    try:
        from newsblur_mcp.tools.feeds import _subscribe

        result = await _subscribe(client, url=url, folder=folder)
        render(ctx, result)
        if result.get("feed"):
            console.print(f"[green]Subscribed to {result['feed'].get('title', url)}[/green]")
    finally:
        await client.close()


@app.command("remove")
@async_command
async def feeds_remove(
    ctx: typer.Context,
    feed_id: int = typer.Argument(..., help="Feed ID to unsubscribe from"),
    folder: Optional[str] = typer.Option(
        None, "--folder", "-f", help="Folder the feed is in (if in multiple folders)"
    ),
):
    """Unsubscribe from a feed."""
    client = get_authenticated_client()
    try:
        from newsblur_mcp.tools.feeds import _unsubscribe

        result = await _unsubscribe(client, feed_id=feed_id, folder=folder)
        render(ctx, result)
    finally:
        await client.close()


@app.command("folders")
@async_command
async def folders_list(
    ctx: typer.Context,
):
    """List all folders with feed counts and unread counts."""
    client = get_authenticated_client()
    try:
        from newsblur_mcp.tools.feeds import _list_folders

        result = await _list_folders(client, include_counts=True)
        render(ctx, result, render_folders)
    finally:
        await client.close()


@app.command("organize")
@async_command
async def feeds_organize(
    ctx: typer.Context,
    action: str = typer.Argument(
        ..., help="Action: move_feed, rename_feed, or rename_folder"
    ),
    feed_id: Optional[int] = typer.Option(None, "--feed-id", help="Feed ID (for move/rename feed)"),
    from_folder: Optional[str] = typer.Option(
        None, "--from", help="Current folder name (for move_feed or rename_folder)"
    ),
    to_folder: Optional[str] = typer.Option(
        None, "--to", help="Destination folder (for move_feed)"
    ),
    name: Optional[str] = typer.Option(
        None, "--name", "-n", help="New name (for rename_feed or rename_folder)"
    ),
):
    """Move or rename feeds and folders."""
    client = get_authenticated_client()
    try:
        from newsblur_mcp.tools.feeds import _organize_feed

        result = await _organize_feed(
            client,
            action=action,
            feed_id=feed_id,
            from_folder=from_folder,
            to_folder=to_folder,
            new_name=name,
        )
        render(ctx, result)
    finally:
        await client.close()
