"""Rich output formatting for the NewsBlur CLI.

Supports three output modes:
- Default: Rich-formatted panels, tables, and trees
- --json: Raw JSON output (machine-readable)
- --raw: Plain unformatted text
"""

from __future__ import annotations

import json
from datetime import datetime

import typer
from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.text import Text
from rich.tree import Tree

console = Console()


def _flag(ctx: typer.Context, name: str) -> bool:
    """Check a flag in both the parent (global) and current command context."""
    if (ctx.obj or {}).get(name):
        return True
    return ctx.params.get(f"{name}_output", False)


def render(ctx: typer.Context, data, renderer=None):
    """Route output to the appropriate formatter based on CLI flags."""
    if _flag(ctx, "json"):
        render_json(data)
    elif _flag(ctx, "raw"):
        render_raw(data)
    elif renderer:
        renderer(data)
    else:
        render_json(data)


def render_json(data) -> None:
    """Print data as indented JSON."""
    console.print_json(json.dumps(data, default=str, indent=2))


def render_raw(data) -> None:
    """Print data as plain unformatted text."""
    if isinstance(data, dict):
        _print_dict_raw(data)
    elif isinstance(data, list):
        for item in data:
            _print_dict_raw(item)
            typer.echo("---")
    else:
        typer.echo(str(data))


def _print_dict_raw(d: dict, indent: int = 0) -> None:
    """Recursively print a dict as key: value plain text."""
    prefix = "  " * indent
    for key, value in d.items():
        if isinstance(value, dict):
            typer.echo(f"{prefix}{key}:")
            _print_dict_raw(value, indent + 1)
        elif isinstance(value, list):
            typer.echo(f"{prefix}{key}:")
            for item in value:
                if isinstance(item, dict):
                    _print_dict_raw(item, indent + 1)
                    typer.echo(f"{prefix}  ---")
                else:
                    typer.echo(f"{prefix}  {item}")
        else:
            typer.echo(f"{prefix}{key}: {value}")


def _intelligence_dot(score: int) -> str:
    """Return a colored dot representing an intelligence score."""
    if score > 0:
        return "[green]+[/green]"
    elif score < 0:
        return "[red]-[/red]"
    return "[dim].[/dim]"


def _intelligence_summary(intel: dict) -> str:
    """Build a compact intelligence indicator string."""
    parts = []
    for key in ("feed", "author", "tags", "title"):
        score = intel.get(key, 0)
        parts.append(_intelligence_dot(score))
    return " ".join(parts)


def render_stories(data: dict) -> None:
    """Render paginated story results as Rich Panels."""
    stories = data.get("items", data.get("stories", []))
    if not stories:
        console.print("[dim]No stories found.[/dim]")
        return

    for story in stories:
        title = story.get("title", "Untitled")
        author = story.get("author", "")
        date = story.get("date", "")
        feed_title = story.get("feed_title", "")
        story_hash = story.get("story_hash", "")
        content = story.get("content", "")

        # Build subtitle line
        meta_parts = []
        if author:
            meta_parts.append(author)
        if date:
            meta_parts.append(date)
        if feed_title:
            meta_parts.append(feed_title)
        subtitle = " | ".join(meta_parts)

        # Intelligence scores
        intel = story.get("intelligence", {})
        intel_str = _intelligence_summary(intel)

        # Status indicators
        indicators = []
        if story.get("starred"):
            indicators.append("[yellow]*[/yellow]")
        if story.get("shared"):
            indicators.append("[blue]s[/blue]")
        if story.get("read_status"):
            indicators.append("[dim]read[/dim]")
        indicator_str = " ".join(indicators)

        # Content preview (first ~300 chars)
        preview = content[:300]
        if len(content) > 300:
            preview += "..."

        body = Text()
        body_str = f"{subtitle}\n"
        if preview:
            body_str += f"\n{preview}\n"
        body_str += f"\n{story_hash}"

        panel_title = f"[bold]{title}[/bold]"
        if indicator_str:
            panel_title += f"  {indicator_str}"

        panel = Panel(
            body_str,
            title=panel_title,
            title_align="left",
            subtitle=f"Intelligence: {intel_str}",
            subtitle_align="right",
            border_style="dim",
            padding=(0, 1),
        )
        console.print(panel)

    # Pagination info
    page = data.get("page", 1)
    has_more = data.get("has_more", False)
    count = data.get("count", len(stories))
    if has_more:
        console.print(f"\n[dim]Page {page} ({count} stories) -- more available, use --page {page + 1}[/dim]")
    else:
        console.print(f"\n[dim]Page {page} ({count} stories)[/dim]")


def render_feeds_table(data: dict) -> None:
    """Render feeds as a Rich Table."""
    feeds = data.get("feeds", {})
    if not feeds:
        console.print("[dim]No feeds found.[/dim]")
        return

    table = Table(title="Feeds", show_lines=False)
    table.add_column("ID", style="dim", width=8)
    table.add_column("Title", style="bold", min_width=20)
    table.add_column("Unread", justify="right", width=8)
    table.add_column("Focus", justify="right", style="green", width=8)
    table.add_column("Updated", style="dim", min_width=12)

    feed_list = feeds.values() if isinstance(feeds, dict) else feeds
    for feed in feed_list:
        feed_id = str(feed.get("id", ""))
        title = feed.get("title", "")
        unread = feed.get("unread_neutral", 0) + feed.get("unread_positive", 0)
        focus = feed.get("unread_positive", 0)
        updated = feed.get("updated", "")

        table.add_row(feed_id, title, str(unread), str(focus), updated)

    console.print(table)
    console.print(f"\n[dim]{data.get('feed_count', len(feeds))} feeds total, "
                  f"{data.get('starred_count', 0)} saved stories[/dim]")


def render_folders(data: dict) -> None:
    """Render folder hierarchy as a Rich Tree."""
    folders = data.get("folders", [])
    if not folders:
        console.print("[dim]No folders found.[/dim]")
        return

    # If folders is a list (from _list_folders)
    if isinstance(folders, list):
        tree = Tree("[bold]Folders[/bold]")
        for folder in folders:
            name = folder.get("name", "")
            feed_count = folder.get("feed_count", 0)
            unread = folder.get("unread_count", 0)
            focus = folder.get("focus_count", 0)
            label = f"[bold]{name}[/bold] ({feed_count} feeds)"
            if unread:
                label += f" [yellow]{unread} unread[/yellow]"
            if focus:
                label += f" [green]{focus} focus[/green]"
            tree.add(label)
        console.print(tree)

    # If folders is a dict (from _list_folders_with_feeds)
    elif isinstance(folders, dict):
        tree = Tree("[bold]Folders[/bold]")
        for folder_name, folder_feeds in folders.items():
            branch = tree.add(f"[bold]{folder_name}[/bold] ({len(folder_feeds)} feeds)")
            for feed in folder_feeds:
                title = feed.get("title", "")
                unread = feed.get("unread_neutral", 0) + feed.get("unread_positive", 0)
                label = f"{title}"
                if unread:
                    label += f" [yellow]({unread})[/yellow]"
                branch.add(label)
        console.print(tree)

    console.print(f"\n[dim]{data.get('folder_count', len(folders))} folders[/dim]")


def render_account(data: dict) -> None:
    """Render account info as a Rich Panel."""
    username = data.get("username", "unknown")
    tier = data.get("tier", "free")
    feed_count = data.get("feed_count", 0)
    feed_limit = data.get("feed_limit", 64)
    email = data.get("email", "")
    expire = data.get("premium_expire_date", "")

    tier_badges = {
        "free": "[dim]Free[/dim]",
        "premium": "[green]Premium[/green]",
        "archive": "[blue]Archive[/blue]",
        "pro": "[magenta]Pro[/magenta]",
    }
    tier_badge = tier_badges.get(tier, tier)

    lines = [
        f"Username:  [bold]{username}[/bold]",
        f"Email:     {email}",
        f"Tier:      {tier_badge}",
        f"Feeds:     {feed_count} / {feed_limit}",
    ]
    if expire:
        lines.append(f"Expires:   {expire}")

    body = "\n".join(lines)
    console.print(Panel(body, title="[bold]Account[/bold]", border_style="blue", padding=(1, 2)))


def render_briefing(data: dict) -> None:
    """Render daily briefing data with Rich Panels."""
    briefings = data.get("items", [])
    if not briefings:
        console.print("[dim]No briefings available.[/dim]")
        return

    for briefing in briefings:
        briefing_date = briefing.get("briefing_date", "")
        frequency = briefing.get("frequency", "")
        # Parse the date for a cleaner display
        date_display = briefing_date
        try:
            dt = datetime.fromisoformat(briefing_date.replace("Z", "+00:00"))
            date_display = dt.strftime("%B %-d, %Y")
        except (ValueError, AttributeError):
            pass
        header = f"Daily Briefing — {date_display}"

        sections = briefing.get("sections", {})
        stories = briefing.get("curated_stories", [])

        # Build a story hash -> story lookup
        story_lookup = {s.get("story_hash"): s for s in stories}

        body_parts = []

        for section_name, section_hashes in sections.items():
            if body_parts:
                body_parts.append("")
            body_parts.append(f"[bold]{section_name}[/bold]")

            for sh in section_hashes:
                story = story_lookup.get(sh)
                if story:
                    title = story.get("title", "Untitled")
                    feed_title = story.get("feed_title", "")
                    author = story.get("author", "")
                    # Build attribution: "author, feed" or just "feed"
                    # Skip author if it matches the feed title
                    attribution_parts = []
                    if author and author.lower() != feed_title.lower():
                        attribution_parts.append(author)
                    if feed_title:
                        attribution_parts.append(feed_title)
                    attribution = ", ".join(attribution_parts)

                    label = f"  [green]•[/green] {title}"
                    if attribution:
                        label += f"  [dim]— {attribution}[/dim]"
                    body_parts.append(label)

        body = "\n".join(body_parts).strip()
        if not body:
            body = "[dim]No content in this briefing.[/dim]"

        console.print(Panel(body, title=f"[bold]{header}[/bold]", border_style="cyan", padding=(1, 2)))

    # Pagination
    page = data.get("page", 1)
    has_more = data.get("has_more", False)
    if has_more:
        console.print(f"\n[dim]Page {page} — more available, use --page {page + 1}[/dim]")


def render_classifiers(data: dict) -> None:
    """Render classifiers as a Rich Table."""
    classifiers = data.get("classifiers", {})
    feed_id = data.get("feed_id")

    table = Table(title=f"Classifiers{f' (feed {feed_id})' if feed_id else ''}")
    table.add_column("Type", style="bold", width=10)
    table.add_column("Value", min_width=20)
    table.add_column("Score", justify="center", width=8)

    has_rows = False

    for classifier_type in ("titles", "authors", "tags", "feeds"):
        items = classifiers.get(classifier_type, [])
        if isinstance(items, list):
            for item in items:
                if isinstance(item, dict):
                    for value, score in item.items():
                        score_display = _score_display(score)
                        table.add_row(classifier_type.rstrip("s"), value, score_display)
                        has_rows = True
        elif isinstance(items, dict):
            for value, score in items.items():
                score_display = _score_display(score)
                table.add_row(classifier_type.rstrip("s"), value, score_display)
                has_rows = True

    if not has_rows:
        console.print("[dim]No classifiers trained.[/dim]")
        return

    console.print(table)


def _score_display(score) -> str:
    """Format a classifier score with color."""
    try:
        score = int(score)
    except (ValueError, TypeError):
        return str(score)
    if score > 0:
        return "[green]like[/green]"
    elif score < 0:
        return "[red]dislike[/red]"
    return "[dim]neutral[/dim]"


def render_discover_results(data: dict) -> None:
    """Render discovered feeds as a Rich Table."""
    feeds = data.get("feeds", [])
    if not feeds:
        console.print("[dim]No feeds found.[/dim]")
        return

    table = Table(title="Discovered Feeds")
    table.add_column("Title", style="bold", min_width=20)
    table.add_column("URL", min_width=30)
    table.add_column("Subscribers", justify="right", width=12)

    for feed in feeds:
        title = feed.get("title", "")
        url = feed.get("url", "") or feed.get("link", "")
        subscribers = str(feed.get("subscribers", 0))
        table.add_row(title, url, subscribers)

    console.print(table)
    console.print(f"\n[dim]{data.get('count', len(feeds))} feeds found[/dim]")
