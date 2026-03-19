"""Async bridge and authenticated client factory for the CLI."""

from __future__ import annotations

import asyncio
from functools import wraps

import typer
from rich.console import Console

from newsblur_mcp.client import NewsBlurClient, PremiumRequiredError

console = Console(stderr=True)


def async_command(f):
    """Decorator that runs an async Typer command synchronously via asyncio.run()."""

    @wraps(f)
    def wrapper(*args, **kwargs):
        try:
            return asyncio.run(f(*args, **kwargs))
        except PremiumRequiredError as e:
            console.print(f"[red]Premium required:[/red] {e}")
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
