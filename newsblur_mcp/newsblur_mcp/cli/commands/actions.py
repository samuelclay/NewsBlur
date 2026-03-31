"""Action commands: mark read, save, unsave, share."""

from __future__ import annotations

from typing import Optional

import typer
from rich.console import Console

from newsblur_mcp.cli.output import render
from newsblur_mcp.cli.runner import async_command, get_authenticated_client

console = Console(stderr=True)
app = typer.Typer()


@app.command("read")
@async_command
async def mark_read(
    ctx: typer.Context,
    story_hashes: Optional[list[str]] = typer.Argument(
        None, help="Story hashes to mark as read"
    ),
    feed_id: Optional[int] = typer.Option(
        None, "--feed", "-f", help="Mark all stories in this feed as read"
    ),
    folder: Optional[str] = typer.Option(
        None, "--folder", help="Mark all stories in this folder as read (use 'all' for everything)"
    ),
    older_than: Optional[int] = typer.Option(
        None, "--older-than", help="Only mark stories older than N days"
    ),
):
    """Mark stories as read by hash, feed, or folder."""
    client = get_authenticated_client()
    try:
        from newsblur_mcp.tools.actions import _mark_stories_read

        result = await _mark_stories_read(
            client,
            story_hashes=story_hashes,
            feed_id=feed_id,
            folder=folder,
            older_than_days=older_than,
        )
        render(ctx, result)
        if result.get("message"):
            console.print(f"[green]{result['message']}[/green]")
    finally:
        await client.close()


@app.command("save")
@async_command
async def save(
    ctx: typer.Context,
    story_hash: str = typer.Argument(..., help="Story hash to save (e.g. '123:abcdef')"),
    tag: Optional[list[str]] = typer.Option(None, "--tag", "-t", help="Tags to apply (repeatable)"),
    notes: Optional[str] = typer.Option(None, "--notes", "-n", help="Personal notes about the story"),
):
    """Save/star a story for later reference."""
    client = get_authenticated_client()
    try:
        from newsblur_mcp.tools.actions import _save_story

        result = await _save_story(
            client,
            story_hash=story_hash,
            tags=tag,
            notes=notes,
            highlights=None,
        )
        render(ctx, result)
        if result.get("message"):
            console.print(f"[green]{result['message']}[/green]")
    finally:
        await client.close()


@app.command("unsave")
@async_command
async def unsave(
    ctx: typer.Context,
    story_hash: str = typer.Argument(..., help="Story hash to unsave"),
):
    """Remove a story from saved/starred stories."""
    client = get_authenticated_client()
    try:
        from newsblur_mcp.tools.actions import _unsave_story

        result = await _unsave_story(client, story_hash=story_hash)
        render(ctx, result)
        if result.get("message"):
            console.print(f"[green]{result['message']}[/green]")
    finally:
        await client.close()


@app.command("share")
@async_command
async def share(
    ctx: typer.Context,
    story_hash: str = typer.Argument(..., help="Story hash to share"),
    feed_id: int = typer.Option(..., "--feed", "-f", help="Feed ID the story belongs to"),
    comments: Optional[str] = typer.Option(
        None, "--comments", "-c", help="Comments to include with the share"
    ),
):
    """Share a story to your Blurblog."""
    client = get_authenticated_client()
    try:
        from newsblur_mcp.tools.actions import _share_story

        result = await _share_story(
            client,
            story_hash=story_hash,
            feed_id=feed_id,
            comments=comments,
        )
        render(ctx, result)
        if result.get("message"):
            console.print(f"[green]{result['message']}[/green]")
    finally:
        await client.close()
