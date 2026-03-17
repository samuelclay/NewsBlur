"""NewsBlur MCP Server.

Exposes NewsBlur's feeds, stories, and classifiers to AI agents
via the Model Context Protocol (MCP).
"""

from fastmcp import FastMCP

from newsblur_mcp.auth import NewsBlurOAuthProvider
from newsblur_mcp.client import NewsBlurClient, PremiumRequiredError
from newsblur_mcp.settings import MCP_HOST, MCP_PORT

auth = NewsBlurOAuthProvider()

mcp = FastMCP(
    "NewsBlur",
    instructions=(
        "Connect AI agents to NewsBlur for reading feeds, managing stories, "
        "training classifiers, and organizing subscriptions."
    ),
    auth=auth,
)


def get_client(context) -> NewsBlurClient:
    """Extract the bearer token from the MCP request context and create a client.

    With OAuth proxy enabled, the auth middleware validates the FastMCP JWT
    and resolves it to the upstream Django access token. The validated
    AccessToken (with .token set to the Django token) is stored in
    request.scope["auth"] by the middleware.
    """
    token = None
    if hasattr(context, "request") and context.request:
        # Primary: get the upstream Django token from the auth middleware
        auth_context = context.request.scope.get("auth")
        if auth_context and hasattr(auth_context, "token"):
            token = auth_context.token

        # Fallback: direct bearer token (e.g., for testing)
        if not token:
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
    mcp.run(
        transport="streamable-http",
        host=MCP_HOST,
        port=MCP_PORT,
        path="/",
    )


if __name__ == "__main__":
    main()
