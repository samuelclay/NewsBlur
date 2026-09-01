from starlette.applications import Starlette
from starlette.responses import JSONResponse
from starlette.routing import Route
from starlette.testclient import TestClient

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
