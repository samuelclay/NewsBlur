"""Async bridge and authenticated client factory for the CLI."""

from __future__ import annotations

import asyncio
from functools import wraps

import typer
from rich.console import Console

from newsblur_mcp.client import ArchiveRequiredError, NewsBlurClient

console = Console(stderr=True)


class ReadonlyError(Exception):
    """Raised when a write operation is attempted in readonly mode."""
    pass


def require_writable() -> None:
    """Raise ReadonlyError if readonly mode is enabled.

    Call this at the top of any command that modifies data.
    """
    from newsblur_mcp.cli.auth import get_readonly

    if get_readonly():
        raise ReadonlyError(
            "Readonly mode is enabled. Disable it with: newsblur auth readonly --off"
        )


def async_command(f):
    """Decorator that runs an async Typer command synchronously via asyncio.run().

    Also injects --json and --raw options so they work on every subcommand
    (not just as global flags before the subcommand name).
    """
    # Add --json and --raw as typer options via function annotations
    import inspect

    sig = inspect.signature(f)
    params = list(sig.parameters.values())
    if "json_output" not in sig.parameters:
        params.append(
            inspect.Parameter(
                "json_output",
                inspect.Parameter.KEYWORD_ONLY,
                default=typer.Option(False, "--json", is_flag=True, help="Output as JSON"),
                annotation=bool,
            )
        )
    if "raw_output" not in sig.parameters:
        params.append(
            inspect.Parameter(
                "raw_output",
                inspect.Parameter.KEYWORD_ONLY,
                default=typer.Option(False, "--raw", is_flag=True, help="Output unformatted text"),
                annotation=bool,
            )
        )
    f.__signature__ = sig.replace(parameters=params)

    @wraps(f)
    def wrapper(*args, **kwargs):
        # Remove injected kwargs before passing to the actual function
        kwargs.pop("json_output", None)
        kwargs.pop("raw_output", None)
        try:
            return asyncio.run(f(*args, **kwargs))
        except ReadonlyError as e:
            console.print(f"[yellow]Readonly mode:[/yellow] {e}")
            raise typer.Exit(1)
        except ArchiveRequiredError as e:
            console.print(f"[red]Premium Archive required:[/red] {e}")
            raise typer.Exit(1)
        except KeyboardInterrupt:
            console.print("\n[dim]Interrupted.[/dim]")
            raise typer.Exit(130)
        except Exception as e:
            console.print(f"[red]Error:[/red] {e}")
            raise typer.Exit(1)

    return wrapper


def get_authenticated_client() -> NewsBlurClient:
    """Load the stored OAuth token and create an authenticated NewsBlurClient.

    Uses the server URL from config (set via --server or `newsblur auth login --server`).
    Prints an error and exits if no token is found.
    """
    from newsblur_mcp.cli.auth import get_server_url, load_token

    token = load_token()
    if not token:
        console.print(
            "[red]Not logged in.[/red] Run [bold]newsblur auth login[/bold] to authenticate."
        )
        raise typer.Exit(1)
    return NewsBlurClient(bearer_token=token, base_url=get_server_url())
