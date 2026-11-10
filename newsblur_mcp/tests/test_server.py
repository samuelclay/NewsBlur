import pytest
from key_value.aio.stores.memory import MemoryStore
from starlette.applications import Starlette
from starlette.responses import JSONResponse
from starlette.routing import Route
from starlette.testclient import TestClient

from newsblur_mcp import auth as mcp_auth
from newsblur_mcp import server
from newsblur_mcp.server import mcp_http_middleware


async def protected_endpoint(request):
    return JSONResponse(
        {"error": "invalid_token"},
        status_code=401,
        headers={
            "WWW-Authenticate": (
                'Bearer resource_metadata="https://newsblur.com/.well-known/oauth-protected-resource/mcp/"'
            )
        },
    )


def test_mcp_cors_allows_browser_preflight():
    app = Starlette(
        routes=[Route("/", protected_endpoint, methods=["GET", "POST", "DELETE"])],
        middleware=mcp_http_middleware(),
    )
    client = TestClient(app)

    response = client.options(
        "/",
        headers={
            "Origin": "https://littlebird.ai",
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": (
                "Authorization, Content-Type, MCP-Protocol-Version"
            ),
        },
    )

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "*"
    assert "POST" in response.headers["access-control-allow-methods"]
    assert "Authorization" in response.headers["access-control-allow-headers"]


def test_mcp_cors_exposes_www_authenticate_header():
    app = Starlette(
        routes=[Route("/", protected_endpoint, methods=["GET", "POST", "DELETE"])],
        middleware=mcp_http_middleware(),
    )
    client = TestClient(app)

    response = client.get("/", headers={"Origin": "https://littlebird.ai"})

    assert response.status_code == 401
    assert response.headers["access-control-allow-origin"] == "*"
    assert "WWW-Authenticate" in response.headers["access-control-expose-headers"]
    assert "resource_metadata" in response.headers["www-authenticate"]


@pytest.fixture
def oauth_client(monkeypatch):
    """The real FastMCP HTTP app as main() builds it, with in-memory client storage."""
    monkeypatch.setattr(mcp_auth, "RedisStore", lambda url: MemoryStore())
    provider = mcp_auth.NewsBlurOAuthProvider(
        base_url="https://newsblur.test/mcp",
        upstream_url="https://newsblur.test",
        internal_url="https://newsblur.test",
        client_id="newsblur-mcp-server",
        client_secret="secret",
    )
    monkeypatch.setattr(server.mcp, "auth", provider)
    app = server.mcp.http_app(path="/", middleware=mcp_http_middleware())
    with TestClient(app, follow_redirects=False) as client:
        yield client


def test_oauth_route_list_matches_fastmcp(oauth_client):
    # server.OAUTH_ROUTE_PATHS has to name every slashless route FastMCP serves,
    # or a renamed route quietly goes back to redirecting.
    route_paths = {route.path for route in oauth_client.app.routes}
    assert server.OAUTH_ROUTE_PATHS <= route_paths


@pytest.mark.parametrize(
    "method,path",
    [
        ("GET", "/.well-known/oauth-authorization-server"),
        ("GET", "/authorize"),
        ("POST", "/token"),
        ("GET", "/auth/callback"),
        ("GET", "/consent"),
    ],
)
def test_oauth_routes_answer_with_and_without_trailing_slash(oauth_client, method, path):
    # HAProxy strips /mcp before the request arrives, so Starlette's slash
    # redirect for /mcp/token/ pointed at http://newsblur.com/token, a Django
    # 404 (forum #13806).
    without_slash = oauth_client.request(method, path)
    with_slash = oauth_client.request(method, path + "/")
    assert with_slash.status_code == without_slash.status_code
    assert "location" not in with_slash.headers


def test_client_registration_with_trailing_slash(oauth_client):
    registration = {
        "client_name": "Littlebird",
        "redirect_uris": ["https://littlebird.ai/oauth/callback"],
        "grant_types": ["authorization_code", "refresh_token"],
        "response_types": ["code"],
        "token_endpoint_auth_method": "none",
    }
    for path in ["/register", "/register/"]:
        response = oauth_client.post(path, json=registration)
        assert response.status_code == 201, (path, response.status_code, response.headers.get("location"))
        assert response.json()["scope"] == "read write mcp"
