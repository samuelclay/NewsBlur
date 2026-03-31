"""Account command: view account info."""

from __future__ import annotations

import typer
from rich.console import Console

from newsblur_mcp.cli.output import render, render_account
from newsblur_mcp.cli.runner import async_command, get_authenticated_client

console = Console(stderr=True)


@async_command
async def account_info(
    ctx: typer.Context,
):
    """View your NewsBlur account information."""
    client = get_authenticated_client()
    try:
        from newsblur_mcp.tools.account import _get_account_info

        result = await _get_account_info(client)
        render(ctx, result, render_account)
    finally:
        await client.close()
