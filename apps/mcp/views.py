"""MCP OAuth well-known endpoints.

RFC 8414 requires OAuth discovery at /.well-known/oauth-authorization-server/{path}
at the origin root. Since HAProxy only routes /mcp/* to the MCP server, these
Django views serve the discovery metadata directly so clients can find the
OAuth endpoints.

The same documents are also served at the bare origin root
(/.well-known/oauth-authorization-server, /.well-known/oauth-protected-resource)
because clients on the 2025-03-26 MCP auth spec drop the /mcp path and look
only there. Without it they never find the registration endpoint, skip OAuth,
and report a rejected API token (Littlebird, forum #13806). The root copy keeps
issuer https://host/mcp rather than the bare origin, which RFC 8414 section 3.3
would want: those older clients don't check it, and the issuer has to match the
tokens FastMCP issues. If a strict client ever reports an issuer mismatch at
the root URL, this is why.

The identity URLs here (resource, authorization_servers, issuer) must use the
canonical no-trailing-slash form https://host/mcp: strict clients (Codex's rmcp)
derive the expected issuer from the path-insertion discovery URL without a
trailing slash and exact-match it, and the FastMCP server's own metadata at
/mcp/.well-known/oauth-authorization-server already advertises the no-slash
issuer (MCP_OAUTH_BASE_URL). See apps/mcp/test_mcp.py for the contract.
"""

import json

from django.conf import settings
from django.http import HttpResponse


def _get_base_url(request):
    # Check X-Forwarded-Proto, fall back to request scheme, default to https in production
    scheme = request.META.get("HTTP_X_FORWARDED_PROTO", "")
    if scheme not in ("http", "https"):
        scheme = "https" if not settings.DEBUG else request.scheme
    host = request.get_host()  # includes port if non-standard
    return f"{scheme}://{host}/mcp"


def _json_response(data):
    response = HttpResponse(json.dumps(data), content_type="application/json")
    response["Access-Control-Allow-Origin"] = "*"
    response["Access-Control-Allow-Methods"] = "GET, OPTIONS"
    response["Access-Control-Allow-Headers"] = "Authorization, Content-Type"
    response["Cache-Control"] = "public, max-age=3600"
    return response


def oauth_authorization_server_metadata(request):
    """RFC 8414: OAuth Authorization Server Metadata for the MCP server."""
    base_url = _get_base_url(request)
    return _json_response(
        {
            "issuer": base_url,
            "authorization_endpoint": f"{base_url}/authorize",
            "token_endpoint": f"{base_url}/token",
            "registration_endpoint": f"{base_url}/register",
            "scopes_supported": ["read", "write", "mcp"],
            "response_types_supported": ["code"],
            "grant_types_supported": ["authorization_code", "refresh_token"],
            "token_endpoint_auth_methods_supported": ["client_secret_post", "client_secret_basic"],
            "code_challenge_methods_supported": ["S256"],
        }
    )


def oauth_protected_resource_metadata(request):
    """RFC 9728: OAuth Protected Resource Metadata for the MCP endpoint."""
    base_url = _get_base_url(request)
    return _json_response(
        {
            "resource": base_url,
            "authorization_servers": [base_url],
            "scopes_supported": ["read", "write", "mcp"],
        }
    )
