"""Tests that MCP connections don't expire or drop on their own (newsblur_mcp/auth.py).

Django issues MCP tokens that last ten years, but two things still forced people
to reconnect: Django hiccups turned into 401s for good tokens, and the refresh
token's JTI mapping expired after FastMCP's hardcoded 30 days.
"""

import time

import httpx
import pytest
import respx
from fastmcp.server.auth.oauth_proxy.models import ClientCode
from key_value.aio.stores.memory import MemoryStore
from mcp.server.auth.provider import AuthorizationCode
from mcp.shared.auth import OAuthClientInformationFull
from pydantic import AnyUrl

from newsblur_mcp import auth as mcp_auth

USER_INFO_URL = "https://newsblur.test/oauth/user/info/"
TEN_YEARS = 60 * 60 * 24 * 365 * 10
ONE_YEAR = 60 * 60 * 24 * 365
REDIRECT_URI = "http://localhost:33418/callback"

SAMUEL = {"data": {"id": 13, "name": "samuel", "is_premium": True, "is_archive": True}}


@pytest.fixture
def verifier():
    return mcp_auth.NewsBlurTokenVerifier(
        upstream_base_url="https://newsblur.test", claims_store=MemoryStore()
    )


@pytest.mark.asyncio
@respx.mock
async def test_verifier_keeps_good_tokens_working_while_django_is_unreachable(verifier):
    user_info = respx.get(USER_INFO_URL)
    user_info.mock(return_value=httpx.Response(200, json=SAMUEL))
    verified = await verifier.verify_token("good-token")
    assert verified.claims["username"] == "samuel"

    user_info.mock(side_effect=httpx.ConnectError("newsblur_web is restarting"))
    during_outage = await verifier.verify_token("good-token")
    assert during_outage is not None
    assert during_outage.claims == verified.claims

    user_info.mock(return_value=httpx.Response(502))
    assert (await verifier.verify_token("good-token")).claims == verified.claims


@pytest.mark.asyncio
@respx.mock
async def test_verifier_rejects_tokens_django_rejects(verifier):
    user_info = respx.get(USER_INFO_URL)
    user_info.mock(return_value=httpx.Response(200, json=SAMUEL))
    await verifier.verify_token("revoked-token")

    user_info.mock(return_value=httpx.Response(401, json={"message": "You must have a valid OAuth token."}))
    assert await verifier.verify_token("revoked-token") is None

    # Once Django has rejected it, an outage mustn't bring it back from the cache.
    user_info.mock(side_effect=httpx.ConnectError("newsblur_web is restarting"))
    assert await verifier.verify_token("revoked-token") is None


@pytest.mark.asyncio
@respx.mock
async def test_verifier_rejects_unknown_tokens_while_django_is_unreachable(verifier):
    respx.get(USER_INFO_URL).mock(side_effect=httpx.ConnectError("newsblur_web is restarting"))
    assert await verifier.verify_token("never-seen-token") is None


@pytest.fixture
def provider(monkeypatch):
    monkeypatch.setattr(mcp_auth, "RedisStore", lambda url: MemoryStore())
    provider = mcp_auth.NewsBlurOAuthProvider(
        base_url="https://newsblur.test/mcp",
        upstream_url="https://newsblur.test",
        internal_url="https://newsblur.test",
        client_id="newsblur-mcp-server",
        client_secret="secret",
    )
    # FastMCP sets up its JWT issuer when the routes are built.
    provider.get_routes(mcp_path="/")
    return provider


@pytest.mark.asyncio
async def test_refresh_token_mapping_lives_as_long_as_the_refresh_token(provider):
    client = OAuthClientInformationFull(
        client_id="littlebird",
        client_secret=None,
        redirect_uris=[AnyUrl(REDIRECT_URI)],
        grant_types=["authorization_code", "refresh_token"],
        response_types=["code"],
        token_endpoint_auth_method="none",
        scope="read write mcp",
    )
    # Django's token response, as apps/mcp/validators.py now sends it.
    await provider._code_store.put(
        key="code-1",
        value=ClientCode(
            code="code-1",
            client_id="littlebird",
            redirect_uri=REDIRECT_URI,
            code_challenge="challenge",
            code_challenge_method="S256",
            scopes=["read", "write", "mcp"],
            idp_tokens={
                "access_token": "upstream-access",
                "token_type": "Bearer",
                "expires_in": TEN_YEARS,
                "refresh_token": "upstream-refresh",
                "refresh_expires_in": TEN_YEARS,
                "scope": "read write mcp",
            },
            expires_at=time.time() + 300,
            created_at=time.time(),
        ),
        ttl=300,
    )
    authorization_code = AuthorizationCode(
        code="code-1",
        scopes=["read", "write", "mcp"],
        expires_at=time.time() + 300,
        client_id="littlebird",
        code_challenge="challenge",
        redirect_uri=AnyUrl(REDIRECT_URI),
        redirect_uri_provided_explicitly=True,
    )

    tokens = await provider.exchange_authorization_code(client, authorization_code)

    refresh_jti = provider.jwt_issuer.verify_token(tokens.refresh_token, expected_token_use="refresh")["jti"]
    mapping, ttl = await provider._jti_mapping_store.ttl(key=refresh_jti)
    assert mapping is not None
    assert ttl > ONE_YEAR
