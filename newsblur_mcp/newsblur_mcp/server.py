"""NewsBlur MCP Server.

Exposes NewsBlur's feeds, stories, and classifiers to AI agents
via the Model Context Protocol (MCP).
"""

from contextlib import asynccontextmanager

from fastmcp import FastMCP

from newsblur_mcp.client import NewsBlurClient, PremiumRequiredError
from newsblur_mcp.settings import MCP_HOST, MCP_PORT


mcp = FastMCP(
    "NewsBlur",
    description=(
        "Connect AI agents to NewsBlur for reading feeds, managing stories, "
        "training classifiers, and organizing subscriptions."
    ),
)


def get_client(context) -> NewsBlurClient:
    """Extract the bearer token from the MCP request context and create a client."""
    # FastMCP provides the Authorization header via context
    # The token is passed through from the MCP client's OAuth flow
    token = None
    if hasattr(context, "request") and context.request:
        auth_header = context.request.headers.get("authorization", "")
        if auth_header.startswith("Bearer "):
            token = auth_header[7:]

    if not token:
        raise ValueError(
            "No authorization token provided. "
            "Connect to NewsBlur via OAuth at https://newsblur.com/oauth/authorize"
        )

    return NewsBlurClient(bearer_token=token)


# Import tools to register them with the mcp instance
import newsblur_mcp.tools.stories  # noqa: F401, E402
import newsblur_mcp.tools.feeds  # noqa: F401, E402
import newsblur_mcp.tools.account  # noqa: F401, E402
import newsblur_mcp.tools.actions  # noqa: F401, E402
import newsblur_mcp.tools.classifiers  # noqa: F401, E402
import newsblur_mcp.tools.discovery  # noqa: F401, E402
import newsblur_mcp.tools.notifications  # noqa: F401, E402

# Import resources and prompts
import newsblur_mcp.resources.resources  # noqa: F401, E402
import newsblur_mcp.prompts.prompts  # noqa: F401, E402


def main():
    mcp.run(transport="streamable-http", host=MCP_HOST, port=MCP_PORT)


if __name__ == "__main__":
    main()
