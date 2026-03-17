"""Auth commands: login, logout, and status."""

from __future__ import annotations

import typer
from rich.console import Console

from newsblur_mcp.cli.auth import delete_token, get_auth_status, login_flow

console = Console(stderr=True)
app = typer.Typer()


@app.command("login")
def login():
    """Log in to NewsBlur via OAuth (opens your browser)."""
    console.print("[bold]Logging in to NewsBlur...[/bold]")
    console.print("Opening your browser for authentication.\n")
    try:
        token_data = login_flow()
        console.print("[green]Login successful![/green]")
        if token_data.get("access_token"):
            console.print("[dim]Token stored securely.[/dim]")
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


@app.command("status")
def status():
    """Show current authentication status."""
    info = get_auth_status()

    if info["authenticated"]:
        console.print("[green]Authenticated[/green]")
        if info.get("username"):
            console.print(f"  Username: [bold]{info['username']}[/bold]")
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
