"""Intelligence classifier commands: show, like, dislike."""

from __future__ import annotations

from typing import Optional

import typer
from rich.console import Console

from newsblur_mcp.cli.output import render, render_classifiers
from newsblur_mcp.cli.runner import async_command, get_authenticated_client

console = Console(stderr=True)
from newsblur_mcp.cli import CONTEXT_SETTINGS

app = typer.Typer(context_settings=CONTEXT_SETTINGS)


@app.command("show")
@async_command
async def show_classifiers(
    ctx: typer.Context,
    feed_id: Optional[int] = typer.Option(
        None, "--feed", "-f", help="Show classifiers for a specific feed only"
    ),
):
    """View all trained intelligence classifiers."""
    client = get_authenticated_client()
    try:
        from newsblur_mcp.tools.classifiers import _get_classifiers

        result = await _get_classifiers(client, feed_id=feed_id)
        render(ctx, result, render_classifiers)
    finally:
        await client.close()


@app.command("like")
@async_command
async def train_like(
    ctx: typer.Context,
    feed_id: int = typer.Option(..., "--feed", "-f", help="Feed ID to train on"),
    author: Optional[list[str]] = typer.Option(
        None, "--author", "-a", help="Author names to like (repeatable)"
    ),
    tag: Optional[list[str]] = typer.Option(
        None, "--tag", "-t", help="Story tags to like (repeatable)"
    ),
    title: Optional[list[str]] = typer.Option(
        None, "--title", help="Title keywords to like (repeatable)"
    ),
    feed_like: bool = typer.Option(
        False, "--feed-like", help="Like the entire feed (boost all its stories)"
    ),
):
    """Train the classifier to like (boost) stories matching criteria."""
    client = get_authenticated_client()
    try:
        from newsblur_mcp.tools.classifiers import _train_classifier

        result = await _train_classifier(
            client,
            feed_id=feed_id,
            like_title=title,
            dislike_title=None,
            like_author=author,
            dislike_author=None,
            like_tag=tag,
            dislike_tag=None,
            like_feed=feed_like or None,
            dislike_feed=None,
        )
        render(ctx, result)
        if result.get("message"):
            console.print(f"[green]{result['message']}[/green]")
    finally:
        await client.close()


@app.command("dislike")
@async_command
async def train_dislike(
    ctx: typer.Context,
    feed_id: int = typer.Option(..., "--feed", "-f", help="Feed ID to train on"),
    author: Optional[list[str]] = typer.Option(
        None, "--author", "-a", help="Author names to dislike (repeatable)"
    ),
    tag: Optional[list[str]] = typer.Option(
        None, "--tag", "-t", help="Story tags to dislike (repeatable)"
    ),
    title: Optional[list[str]] = typer.Option(
        None, "--title", help="Title keywords to dislike (repeatable)"
    ),
    feed_dislike: bool = typer.Option(
        False, "--feed-dislike", help="Dislike the entire feed (suppress all its stories)"
    ),
):
    """Train the classifier to dislike (suppress) stories matching criteria."""
    client = get_authenticated_client()
    try:
        from newsblur_mcp.tools.classifiers import _train_classifier

        result = await _train_classifier(
            client,
            feed_id=feed_id,
            like_title=None,
            dislike_title=title,
            like_author=None,
            dislike_author=author,
            like_tag=None,
            dislike_tag=tag,
            like_feed=None,
            dislike_feed=feed_dislike or None,
        )
        render(ctx, result)
        if result.get("message"):
            console.print(f"[green]{result['message']}[/green]")
    finally:
        await client.close()
