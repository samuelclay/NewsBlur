"""Auth commands: login, logout, and status."""

from __future__ import annotations

import typer
from rich.console import Console

from newsblur_mcp.cli.auth import delete_token, get_auth_status, get_readonly, login_flow, set_readonly

console = Console(stderr=True)
from newsblur_mcp.cli import CONTEXT_SETTINGS

app = typer.Typer(context_settings=CONTEXT_SETTINGS)


@app.command("login")
def login(
    server: str = typer.Option(
        None, "--server", "-s",
        help="NewsBlur server URL (e.g. https://newsblur.com or https://nb.example.com for self-hosted)",
    ),
):
    """Log in to NewsBlur via OAuth (opens your browser)."""
    from newsblur_mcp.cli.auth import get_server_url

    target = server or get_server_url()
    console.print(f"[bold]Logging in to {target}...[/bold]")
    console.print("Opening your browser for authentication.\n")
    try:
        token_data = login_flow(server=server)
        console.print("[green]Login successful![/green]")
        if token_data.get("access_token"):
            console.print(f"[dim]Token stored securely. Server: {target}[/dim]")
    except RuntimeError as e:
        console.print(f"[red]Login failed:[/red] {e}")
        raise typer.Exit(1)


@app.command("logout")
def logout(
    force: bool = typer.Option(False, "--force", "-f", help="Skip confirmation prompt"),
):
    """Log out and remove stored credentials."""
    if not force:
        confirm = typer.confirm("Are you sure you want to log out?")
        if not confirm:
            console.print("[dim]Cancelled.[/dim]")
            raise typer.Exit(0)

    delete_token()
    console.print("[green]Logged out.[/green] Stored credentials removed.")


@app.command("readonly")
def readonly(
    on: bool = typer.Option(False, "--on", help="Enable readonly mode (block all write operations)"),
    off: bool = typer.Option(False, "--off", help="Disable readonly mode (requires re-login)"),
):
    """Enable or disable readonly mode.

    Readonly mode blocks all write operations (save, share, train, subscribe, etc.).
    This is useful when giving an AI agent access to your NewsBlur without
    allowing it to modify anything.

    Disabling readonly mode requires re-authentication. This is intentional:
    it prevents an AI agent from silently turning off readonly and making
    changes without your knowledge.
    """
    if on and off:
        console.print("[red]Cannot use both --on and --off.[/red]")
        raise typer.Exit(1)
    if not on and not off:
        # Show current state
        if get_readonly():
            console.print("[yellow]Readonly mode is ON[/yellow]")
            console.print("  Write operations are blocked.")
            console.print("  Disable with: [bold]newsblur auth readonly --off[/bold]")
        else:
            console.print("Readonly mode is [green]off[/green]")
            console.print("  Enable with: [bold]newsblur auth readonly --on[/bold]")
        return

    if on:
        set_readonly(True)
        console.print("[yellow]Readonly mode enabled.[/yellow]")
        console.print("  All write operations are now blocked.")
        console.print("  Your login session is still active for read operations.")
    else:
        set_readonly(False)
        console.print("[green]Readonly mode disabled.[/green]")
        console.print("  You have been logged out and must re-authenticate.")
        console.print("  Run [bold]newsblur auth login[/bold] to log back in.")


@app.command("status")
def status():
    """Show current authentication status."""
    info = get_auth_status()

    if info["authenticated"]:
        console.print("[green]Authenticated[/green]")
        if info.get("username"):
            console.print(f"  Username: [bold]{info['username']}[/bold]")
        if info.get("email"):
            console.print(f"  Email:    {info['email']}")
        # Premium tier
        if info.get("is_pro"):
            console.print("  Tier:     [magenta]Pro[/magenta]")
        elif info.get("is_archive"):
            console.print("  Tier:     [blue]Archive[/blue]")
        elif info.get("is_premium"):
            console.print("  Tier:     [green]Premium[/green]")
        else:
            console.print("  Tier:     [dim]Free[/dim]")
        if "feed_count" in info:
            console.print(f"  Feeds:    {info['feed_count']}")
        if get_readonly():
            console.print("  Readonly: [yellow]ON[/yellow] (write operations blocked)")
        if info.get("server"):
            console.print(f"  Server:   {info['server']}")
        if info.get("expires_at"):
            from datetime import datetime

            expiry = datetime.fromtimestamp(info["expires_at"])
            console.print(f"  Expires:  {expiry.strftime('%Y-%m-%d %H:%M')}")
        console.print(f"  Token:    {info['token_path']}")
    else:
        console.print("[red]Not authenticated[/red]")
        if info.get("expired"):
            console.print("  Token expired. Run [bold]newsblur auth login[/bold] to re-authenticate.")
        else:
            console.print("  Run [bold]newsblur auth login[/bold] to get started.")
