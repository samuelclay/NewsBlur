"""NewsBlur OAuth provider for FastMCP.

Proxies authentication through Django's existing OAuth2 infrastructure
so that MCP clients (Claude Code, Codex, etc.) can authenticate via
standard OAuth flows without any manual token setup.
"""

from __future__ import annotations

import logging
import time

import httpx
from fastmcp.server.auth import TokenVerifier
from fastmcp.server.auth.auth import AccessToken
from fastmcp.server.auth.oauth_proxy import OAuthProxy
from pydantic import AnyHttpUrl

logger = logging.getLogger(__name__)

from newsblur_mcp.settings import (
    MCP_OAUTH_BASE_URL,
    MCP_OAUTH_CLIENT_ID,
    MCP_OAUTH_CLIENT_SECRET,
    MCP_OAUTH_INTERNAL_URL,
    MCP_OAUTH_UPSTREAM_URL,
)
from newsblur_mcp.ui import patch_fastmcp_ui

# Replace FastMCP's generic OAuth pages with NewsBlur-branded ones
patch_fastmcp_ui()


class NewsBlurTokenVerifier(TokenVerifier):
    """Validates upstream Django OAuth tokens by calling NewsBlur's API."""

    def __init__(self, upstream_base_url: str, timeout_seconds: int = 10):
        super().__init__(required_scopes=None)
        self.upstream_base_url = upstream_base_url
        self.timeout_seconds = timeout_seconds

    async def verify_token(self, token: str) -> AccessToken | None:
        """Verify a Django OAuth access token by calling the user info endpoint."""
        try:
            async with httpx.AsyncClient(timeout=self.timeout_seconds) as client:
                response = await client.get(
                    f"{self.upstream_base_url}/oauth/user/info/",
                    headers={"Authorization": f"Bearer {token}"},
                )

                if response.status_code != 200:
                    logger.warning("Django token verification failed: status=%d url=%s", response.status_code, self.upstream_base_url)
                    return None

                user_info = response.json()
                data = user_info.get("data", user_info)
                username = data.get("user_name") or data.get("name", "unknown")
                is_premium = bool(data.get("is_premium"))
                is_archive = bool(data.get("is_archive"))
                logger.info("Token verified for user=%s premium=%s archive=%s", username, is_premium, is_archive)

                return AccessToken(
                    token=token,
                    client_id=MCP_OAUTH_CLIENT_ID,
                    scopes=["read", "write", "mcp"],
                    expires_at=int(time.time()) + (60 * 60 * 24 * 365 * 10),
                    claims={
                        "sub": str(data.get("user_id") or data.get("id", "")),
                        "username": username,
                        "is_premium": is_premium,
                        "is_archive": is_archive,
                    },
                )
        except Exception as e:
            logger.error("Django token verification error: %s", e)
            return None


class NewsBlurOAuthProvider(OAuthProxy):
    """OAuth provider that proxies to Django's OAuth2 infrastructure."""

    def __init__(
        self,
        *,
        base_url: AnyHttpUrl | str | None = None,
        upstream_url: str | None = None,
        internal_url: str | None = None,
        client_id: str | None = None,
        client_secret: str | None = None,
    ):
        base_url = base_url or MCP_OAUTH_BASE_URL
        upstream_url = upstream_url or MCP_OAUTH_UPSTREAM_URL
        internal_url = internal_url or MCP_OAUTH_INTERNAL_URL
        client_id = client_id or MCP_OAUTH_CLIENT_ID
        client_secret = client_secret or MCP_OAUTH_CLIENT_SECRET

        token_verifier = NewsBlurTokenVerifier(upstream_base_url=internal_url)

        super().__init__(
            # Browser redirect — user sees this URL
            upstream_authorization_endpoint=f"{upstream_url}/oauth/authorize/",
            # Server-to-server — bypasses TLS for self-signed certs in dev
            upstream_token_endpoint=f"{internal_url}/oauth/token/",
            upstream_client_id=client_id,
            upstream_client_secret=client_secret,
            token_verifier=token_verifier,
            base_url=base_url,
            issuer_url=base_url,
            require_authorization_consent=False,
            forward_pkce=False,
            valid_scopes=["read", "write", "mcp"],
        )
