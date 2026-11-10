"""NewsBlur OAuth provider for FastMCP.

Proxies authentication through Django's existing OAuth2 infrastructure
so that MCP clients (Claude Code, Codex, etc.) can authenticate via
standard OAuth flows without any manual token setup.
"""

from __future__ import annotations

import hashlib
import logging
import time

import httpx
from fastmcp.server.auth import TokenVerifier
from fastmcp.server.auth.auth import AccessToken
from fastmcp.server.auth.oauth_proxy import OAuthProxy
from key_value.aio.protocols import AsyncKeyValue
from key_value.aio.stores.redis import RedisStore
from pydantic import AnyHttpUrl

logger = logging.getLogger(__name__)

from newsblur_mcp.settings import (
    MCP_OAUTH_BASE_URL,
    MCP_OAUTH_CLIENT_ID,
    MCP_OAUTH_CLIENT_SECRET,
    MCP_OAUTH_INTERNAL_URL,
    MCP_OAUTH_UPSTREAM_URL,
    MCP_REDIS_URL,
)
from newsblur_mcp.ui import patch_fastmcp_ui

# Replace FastMCP's generic OAuth pages with NewsBlur-branded ones
patch_fastmcp_ui()

# The scopes advertised in /.well-known/oauth-authorization-server. Kept in one
# place because DCR defaults, valid_scopes, and issued tokens must all agree.
MCP_SCOPES = ["read", "write", "mcp"]

# Django's MCP tokens last ten years (newsblur_web/settings.py OAUTH2_PROVIDER) and
# its refresh tokens never expire. MCP connections should last as long.
MCP_TOKEN_LIFETIME_SECONDS = 60 * 60 * 24 * 365 * 10

# NewsBlurTokenVerifier's last good verification of each upstream token, keyed by
# the token's hash so the raw token never sits in Redis. It only has to outlast a
# Django outage, and every successful verification rewrites it, so 30 days covers
# any connection in use without keeping a key for every token ever issued.
VERIFIED_CLAIMS_COLLECTION = "mcp-verified-claims"
VERIFIED_CLAIMS_TTL_SECONDS = 60 * 60 * 24 * 30


def _token_key(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


class NewsBlurTokenVerifier(TokenVerifier):
    """Validates upstream Django OAuth tokens by calling NewsBlur's API.

    Only Django saying no (401 or 403) rejects a token. When Django can't answer at
    all, say newsblur_web restarting during a deploy, a timeout or a 5xx, the last
    successful verification of that token stands in. Otherwise a perfectly good
    token gets a 401 and the client has to refresh or sign in again.
    """

    def __init__(
        self, upstream_base_url: str, timeout_seconds: int = 10, claims_store: AsyncKeyValue | None = None
    ):
        super().__init__(required_scopes=None)
        self.upstream_base_url = upstream_base_url
        self.timeout_seconds = timeout_seconds
        self.claims_store = claims_store

    async def verify_token(self, token: str) -> AccessToken | None:
        """Verify a Django OAuth access token by calling the user info endpoint."""
        try:
            async with httpx.AsyncClient(timeout=self.timeout_seconds) as client:
                response = await client.get(
                    f"{self.upstream_base_url}/oauth/user/info/",
                    headers={"Authorization": f"Bearer {token}"},
                )
            if response.status_code in (401, 403):
                logger.warning(
                    "Django rejected token: status=%d url=%s", response.status_code, self.upstream_base_url
                )
                # A revoked token must stay dead, even through a later Django outage.
                await self._forget_claims(token)
                return None
            response.raise_for_status()
            user_info = response.json()
        except (httpx.HTTPError, ValueError) as e:
            logger.error("Django token verification error, using last verification: %s", e)
            return await self._remembered_access_token(token)

        data = user_info.get("data", user_info)
        claims = {
            "sub": str(data.get("user_id") or data.get("id", "")),
            "username": data.get("user_name") or data.get("name", "unknown"),
            "is_premium": bool(data.get("is_premium")),
            "is_archive": bool(data.get("is_archive")),
        }
        logger.info(
            "Token verified for user=%s premium=%s archive=%s",
            claims["username"],
            claims["is_premium"],
            claims["is_archive"],
        )
        await self._remember_claims(token, claims)
        return self._access_token(token, claims)

    def _access_token(self, token: str, claims: dict) -> AccessToken:
        return AccessToken(
            token=token,
            client_id=MCP_OAUTH_CLIENT_ID,
            scopes=MCP_SCOPES,
            expires_at=int(time.time()) + MCP_TOKEN_LIFETIME_SECONDS,
            claims=claims,
        )

    async def _remember_claims(self, token: str, claims: dict) -> None:
        if self.claims_store is None:
            return
        try:
            await self.claims_store.put(
                key=_token_key(token),
                value=claims,
                collection=VERIFIED_CLAIMS_COLLECTION,
                ttl=VERIFIED_CLAIMS_TTL_SECONDS,
            )
        except Exception as e:
            logger.warning("Couldn't remember verified token claims: %s", e)

    async def _forget_claims(self, token: str) -> None:
        if self.claims_store is None:
            return
        try:
            await self.claims_store.delete(key=_token_key(token), collection=VERIFIED_CLAIMS_COLLECTION)
        except Exception as e:
            logger.warning("Couldn't forget rejected token claims: %s", e)

    async def _remembered_access_token(self, token: str) -> AccessToken | None:
        if self.claims_store is None:
            return None
        try:
            claims = await self.claims_store.get(key=_token_key(token), collection=VERIFIED_CLAIMS_COLLECTION)
        except Exception as e:
            logger.warning("Couldn't read remembered token claims: %s", e)
            return None
        if claims is None:
            return None
        return self._access_token(token, claims)


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

        # Shared Redis store so client registrations survive restarts
        # and are consistent across multiple MCP server instances
        redis_store = RedisStore(url=MCP_REDIS_URL)

        token_verifier = NewsBlurTokenVerifier(upstream_base_url=internal_url, claims_store=redis_store)

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
            require_authorization_consent="external",
            forward_pkce=False,
            valid_scopes=MCP_SCOPES,
            client_storage=redis_store,
        )

        # RFC 7591 makes `scope` optional at registration, and FastMCP leaves the
        # DCR default unset. A client that omits it is then stored with scope=""
        # and mcp.shared.auth.OAuthClientMetadata.validate_scope rejects every
        # scope it later asks for at /authorize ("Client was not registered with
        # scope read"). ChatGPT registers exactly that way, so it could never
        # connect. Default omitted registrations to everything we advertise.
        # See forum #13806 and newsblur_mcp/tests/test_oauth_scopes.py.
        if self.client_registration_options is not None:
            self.client_registration_options.default_scopes = MCP_SCOPES
        self._default_scope_str = " ".join(MCP_SCOPES)

    async def exchange_authorization_code(self, client, authorization_code):
        """Keep the refresh token's JTI mapping for as long as the refresh token lives.

        FastMCP 3.2 stores that mapping with a hardcoded 30-day TTL at code exchange
        (fastmcp/server/auth/oauth_proxy/proxy.py), even when the refresh token itself
        lasts ten years. After 30 days the refresh token still verifies but maps to
        nothing, so the client has to sign in again. Refreshes already store the
        mapping with the real lifetime. See tests/test_token_lifetime.py.
        """
        tokens = await super().exchange_authorization_code(client, authorization_code)
        if tokens.refresh_token:
            refresh_claims = self.jwt_issuer.verify_token(tokens.refresh_token, expected_token_use="refresh")
            mapping = await self._jti_mapping_store.get(key=refresh_claims["jti"])
            if mapping is not None:
                await self._jti_mapping_store.put(
                    key=refresh_claims["jti"], value=mapping, ttl=refresh_claims["exp"] - time.time()
                )
        return tokens

    async def get_client(self, client_id: str):
        """Look up a registered client, healing ones stored without any scope.

        Registrations live in shared Redis and outlive deploys, so clients that
        registered before the default above existed would stay permanently
        unable to authorize. Backfill them the first time they come back.
        """
        client = await super().get_client(client_id)
        if client is not None and not client.scope:
            client.scope = self._default_scope_str
            await self._client_store.put(key=client_id, value=client)
            logger.info("Backfilled missing DCR scopes for client %s", client_id)
        return client
