"""NewsBlur MCP Server.

Exposes NewsBlur's feeds, stories, and classifiers to AI agents
via the Model Context Protocol (MCP).
"""

import functools
import logging
import time

import httpx
import sentry_sdk
from fastmcp import FastMCP
from fastmcp.server.dependencies import get_http_request

from newsblur_mcp.auth import NewsBlurOAuthProvider
from newsblur_mcp.client import ArchiveRequiredError, NewsBlurClient
from newsblur_mcp.log import log_request
from newsblur_mcp.metrics import record_mcp_usage
from newsblur_mcp.settings import MCP_HOST, MCP_PORT, SENTRY_DSN

logger = logging.getLogger(__name__)


def _before_send(event, hint):
    """Filter out noisy uvicorn warnings that aren't real errors."""
    message = (event.get("logentry") or {}).get("message", "")
    if "ASGI callable returned without completing response" in message:
        return None
    return event


if SENTRY_DSN:
    sentry_sdk.init(
        dsn=SENTRY_DSN,
        traces_sample_rate=0.01,
        send_default_pii=True,
        before_send=_before_send,
    )

# Configure root logger so MCP log output is visible
logging.basicConfig(
    level=logging.INFO,
    format="%(message)s",
)

mcp = FastMCP(
    "NewsBlur",
    instructions=(
        "Connect AI agents to NewsBlur for reading feeds, managing stories, "
        "training classifiers, and organizing subscriptions."
    ),
)


def _get_user_info():
    """Extract user ID, username, and premium indicator from the authenticated request."""
    try:
        request = get_http_request()
        user = request.scope.get("user")
        if user and hasattr(user, "access_token"):
            claims = user.access_token.claims or {}
            user_id = claims.get("sub", "")
            username = claims.get("username", "")
            if claims.get("is_archive"):
                premium = "^"
            elif claims.get("is_premium"):
                premium = "*"
            else:
                premium = ""
            return user_id, username, premium
    except Exception:
        pass
    return "", "", ""


def _record_usage(user_id):
    try:
        record_mcp_usage(user_id)
    except Exception:
        logger.warning("Unable to record MCP usage metric", exc_info=True)


# Patch mcp.tool to wrap every tool function with request logging
_original_tool = mcp.tool


def _logged_tool(*args, **kwargs):
    original_decorator = _original_tool(*args, **kwargs)

    def http_status_error_payload(error: httpx.HTTPStatusError) -> dict:
        response = error.response
        status_code = response.status_code
        reason = response.reason_phrase
        path = error.request.url.path
        return {
            "code": "newsblur_api_error",
            "error": f"NewsBlur API returned {status_code} {reason} for {path}",
            "status_code": status_code,
        }

    def wrapper(func):
        @functools.wraps(func)
        async def logged(*fargs, **fkwargs):
            start = time.time()
            user_id, username, premium = _get_user_info()
            try:
                return await func(*fargs, **fkwargs)
            except ArchiveRequiredError as e:
                return {"code": "archive_required", "error": str(e)}
            except httpx.HTTPStatusError as e:
                return http_status_error_payload(e)
            finally:
                elapsed = time.time() - start
                log_request(username, premium, elapsed, func.__name__)
                _record_usage(user_id or username)

        return original_decorator(logged)

    return wrapper


mcp.tool = _logged_tool


# Patch mcp.resource to count read-only resource usage as MCP usage too.
_original_resource = mcp.resource


def _logged_resource(*args, **kwargs):
    original_decorator = _original_resource(*args, **kwargs)

    def wrapper(func):
        @functools.wraps(func)
        async def logged(*fargs, **fkwargs):
            user_id, username, _ = _get_user_info()
            try:
                return await func(*fargs, **fkwargs)
            finally:
                _record_usage(user_id or username)

        return original_decorator(logged)

    return wrapper


mcp.resource = _logged_resource


def get_client() -> NewsBlurClient:
    """Extract the bearer token from the MCP request context and create a client.

    With OAuth proxy enabled, the auth middleware validates the bearer token
    via NewsBlurTokenVerifier and stores the result as an AuthenticatedUser
    in request.scope["user"]. The AccessToken on that user object holds
    the upstream Django OAuth token in its .token attribute.

    The token verifier already checks is_archive via /oauth/user/info/,
    so we pass it directly to skip the redundant /profile/is_premium call
    and avoid the shared disk cache (which is not per-user on the server).
    """
    request = get_http_request()
    token = None
    is_archive = None

    # Primary: get the upstream Django token from the authenticated user
    user = request.scope.get("user")
    if user and hasattr(user, "access_token"):
        token = user.access_token.token
        claims = user.access_token.claims or {}
        is_archive = bool(claims.get("is_archive"))

    # Fallback: direct bearer token from Authorization header (e.g., for testing)
    if not token:
        auth_header = request.headers.get("authorization", "")
        if auth_header.startswith("Bearer "):
            token = auth_header[7:]

    if not token:
        raise ValueError(
            "No authorization token provided. "
            "Connect to NewsBlur via OAuth at https://newsblur.com/oauth/authorize"
        )

    return NewsBlurClient(bearer_token=token, is_archive=is_archive)


import newsblur_mcp.prompts.prompts  # noqa: F401, E402

# Import resources and prompts
import newsblur_mcp.resources.resources  # noqa: F401, E402
import newsblur_mcp.tools.account  # noqa: F401, E402
import newsblur_mcp.tools.actions  # noqa: F401, E402
import newsblur_mcp.tools.briefing  # noqa: F401, E402
import newsblur_mcp.tools.classifiers  # noqa: F401, E402
import newsblur_mcp.tools.discovery  # noqa: F401, E402
import newsblur_mcp.tools.feeds  # noqa: F401, E402
import newsblur_mcp.tools.notifications  # noqa: F401, E402

# Import tools to register them with the mcp instance
import newsblur_mcp.tools.stories  # noqa: F401, E402


def main():
    mcp.auth = NewsBlurOAuthProvider()
    mcp.run(
        transport="streamable-http",
        host=MCP_HOST,
        port=MCP_PORT,
        path="/",
    )
