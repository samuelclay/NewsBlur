"""NewsBlur CLI - read feeds, manage stories, and train classifiers from your terminal."""

from __future__ import annotations

import typer

app = typer.Typer(
    name="newsblur",
    help="NewsBlur CLI - read feeds, manage stories, and train classifiers from your terminal.",
    no_args_is_help=True,
)


@app.callback(invoke_without_command=True)
def main(
    ctx: typer.Context,
    json_output: bool = typer.Option(False, "--json", help="Output as JSON"),
    raw_output: bool = typer.Option(False, "--raw", help="Output unformatted text"),
    version: bool = typer.Option(False, "--version", "-v", help="Show version"),
    server: str = typer.Option(
        None, "--server", "-s",
        help="NewsBlur server URL (default: https://newsblur.com). Persisted to config.",
    ),
):
    """NewsBlur CLI - read feeds, manage stories, and train classifiers."""
    ctx.ensure_object(dict)
    ctx.obj["json"] = json_output
    ctx.obj["raw"] = raw_output
    if server:
        from newsblur_mcp.cli.auth import set_server_url
        set_server_url(server)
    if version:
        try:
            from importlib.metadata import version as get_version

            typer.echo(f"newsblur {get_version('newsblur-cli')}")
        except Exception:
            typer.echo("newsblur 0.1.0")
        raise typer.Exit()
    if ctx.invoked_subcommand is None:
        typer.echo(ctx.get_help())
        raise typer.Exit()


# Register all command groups
from newsblur_mcp.cli.commands import account as account_commands
from newsblur_mcp.cli.commands import actions as actions_commands
from newsblur_mcp.cli.commands import auth as auth_commands
from newsblur_mcp.cli.commands import discover as discover_commands
from newsblur_mcp.cli.commands import feeds as feeds_commands
from newsblur_mcp.cli.commands import intelligence as intelligence_commands
from newsblur_mcp.cli.commands import stories as stories_commands

app.add_typer(auth_commands.app, name="auth", help="Login, logout, and check auth status")
app.add_typer(stories_commands.app, name="stories", help="Read, search, and browse stories")
app.add_typer(feeds_commands.app, name="feeds", help="List, add, and manage feed subscriptions")
app.add_typer(
    actions_commands.app,
    name="actions",
    help="Mark read, save, unsave, share stories",
)
app.add_typer(
    intelligence_commands.app,
    name="train",
    help="View and train intelligence classifiers",
)
app.add_typer(discover_commands.app, name="discover", help="Find new feeds by topic or similarity")

# Top-level shortcuts for common actions
app.command("account")(account_commands.account_info)
app.command("briefing")(stories_commands.briefing)
app.command("read")(actions_commands.mark_read)
app.command("save")(actions_commands.save)
app.command("unsave")(actions_commands.unsave)
app.command("share")(actions_commands.share)
