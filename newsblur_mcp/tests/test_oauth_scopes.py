"""Tests for OAuth dynamic client registration scopes (newsblur_mcp/auth.py).

Clients that register via DCR without naming a scope must still end up allowed
to request the scopes we advertise in /.well-known/oauth-authorization-server.
ChatGPT does exactly this: it omits `scope` at registration, then asks for
`scope=read` at /authorize. Without a default the stored client scope is "",
and mcp.shared.auth.OAuthClientMetadata.validate_scope rejects the request with
"Client was not registered with scope read" (forum #13806).
"""

import pytest
from key_value.aio.stores.memory import MemoryStore
from fastmcp.server.auth.oauth_proxy.models import ProxyDCRClient
from mcp.shared.auth import InvalidScopeError, OAuthClientInformationFull
from pydantic import AnyUrl

from newsblur_mcp import auth as mcp_auth

ADVERTISED_SCOPES = ["read", "write", "mcp"]


@pytest.fixture
def provider(monkeypatch):
    """A provider backed by in-memory client storage instead of shared Redis."""
    monkeypatch.setattr(mcp_auth, "RedisStore", lambda url: MemoryStore())
    return mcp_auth.NewsBlurOAuthProvider(
        base_url="https://newsblur.test/mcp",
        upstream_url="https://newsblur.test",
        internal_url="https://newsblur.test",
        client_id="newsblur-mcp-server",
        client_secret="secret",
    )


def _client_info(client_id, scope=None):
    return OAuthClientInformationFull(
        client_id=client_id,
        client_secret=None,
        redirect_uris=[AnyUrl("https://chatgpt.com/connector_platform_oauth_redirect")],
        grant_types=["authorization_code", "refresh_token"],
        response_types=["code"],
        token_endpoint_auth_method="none",
        client_name="ChatGPT",
        scope=scope,
    )


@pytest.mark.asyncio
async def test_registration_without_scope_still_allows_advertised_scopes(provider):
    """A DCR request that omits `scope` must not lock the client out of every scope."""
    await provider.register_client(_client_info("no-scope-client"))

    stored = await provider.get_client("no-scope-client")
    assert stored is not None
    assert sorted(stored.scope.split()) == sorted(ADVERTISED_SCOPES)

    # The /authorize path that ChatGPT takes: request a subset of what we advertise.
    assert stored.validate_scope("read") == ["read"]
    assert stored.validate_scope("read write mcp") == ADVERTISED_SCOPES


@pytest.mark.asyncio
async def test_registration_with_explicit_scope_is_preserved(provider):
    """A client that does name its scopes keeps exactly what it asked for."""
    await provider.register_client(_client_info("scoped-client", scope="read mcp"))

    stored = await provider.get_client("scoped-client")
    assert stored.scope == "read mcp"
    assert stored.validate_scope("read") == ["read"]
    with pytest.raises(InvalidScopeError):
        stored.validate_scope("write")


@pytest.mark.asyncio
async def test_client_registered_before_the_fix_is_repaired_on_read(provider):
    """The 79 clients already stored with scope="" must recover without re-registering.

    Registrations live in shared Redis and survive restarts, so a deploy-time fix
    to register_client alone would leave every already-broken client broken.
    """
    await provider._client_store.put(
        key="legacy-client",
        value=ProxyDCRClient(
            client_id="legacy-client",
            client_secret=None,
            redirect_uris=[AnyUrl("https://chatgpt.com/connector_platform_oauth_redirect")],
            grant_types=["authorization_code", "refresh_token"],
            scope="",
            token_endpoint_auth_method="none",
        ),
    )

    stored = await provider.get_client("legacy-client")
    assert stored is not None
    assert stored.validate_scope("read") == ["read"]


@pytest.mark.asyncio
async def test_register_then_authorize_over_http(provider, monkeypatch):
    """End-to-end over the real handlers: the path ChatGPT actually walks.

    POST /register with no scope, then GET /authorize?scope=read. Before the fix
    the authorize step redirected back with
    error=invalid_scope&error_description=Client+was+not+registered+with+scope+read.
    """
    from starlette.applications import Starlette
    from starlette.testclient import TestClient

    app = Starlette(routes=provider.get_routes(mcp_path="/mcp"))

    with TestClient(app) as http:
        registration = http.post(
            "/register",
            json={
                "redirect_uris": ["https://chatgpt.com/connector_platform_oauth_redirect"],
                "client_name": "ChatGPT",
                "grant_types": ["authorization_code", "refresh_token"],
                "response_types": ["code"],
                "token_endpoint_auth_method": "none",
            },
        )
        assert registration.status_code == 201
        body = registration.json()
        # The client must be told which scopes it may request.
        assert sorted(body["scope"].split()) == sorted(ADVERTISED_SCOPES)

        authorize = http.get(
            "/authorize",
            params={
                "client_id": body["client_id"],
                "response_type": "code",
                "redirect_uri": "https://chatgpt.com/connector_platform_oauth_redirect",
                "scope": "read",
                "state": "xyz",
                "code_challenge": "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
                "code_challenge_method": "S256",
            },
            follow_redirects=False,
        )
        assert authorize.status_code == 302
        location = authorize.headers["location"]
        assert "error=invalid_scope" not in location
        # Hands off to NewsBlur's own OAuth screen, carrying the requested scope.
        assert location.startswith("https://newsblur.test/oauth/authorize/")
        assert "scope=read" in location
