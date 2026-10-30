"""Tests for MCP OAuth well-known metadata (apps/mcp/views.py).

Strict OAuth clients (Codex's rmcp) exact-match these URLs during discovery:
the RFC 8414 path-insertion form derives an expected issuer with no trailing
slash, so every identity URL served here (resource, authorization_servers,
issuer) must use the canonical no-trailing-slash form https://host/mcp.
See https://forum.newsblur.com/t/13801 for the failure both variants hit.
"""

import json

from django.test import TestCase, override_settings


class Test_MCPOAuthMetadata(TestCase):
    def get_json(self, path):
        response = self.client.get(path)
        self.assertEqual(response.status_code, 200)
        return json.loads(response.content)

    def test_protected_resource_uses_canonical_url_without_trailing_slash(self):
        for path in [
            "/.well-known/oauth-protected-resource/mcp",
            "/.well-known/oauth-protected-resource/mcp/",
        ]:
            metadata = self.get_json(path)
            self.assertEqual(metadata["resource"], "https://testserver/mcp")
            self.assertEqual(metadata["authorization_servers"], ["https://testserver/mcp"])

    def test_authorization_server_issuer_matches_rfc8414_path_insertion(self):
        # rmcp derives the expected issuer from the discovery URL
        # /.well-known/oauth-authorization-server/mcp -> https://host/mcp (no slash)
        # and rejects the metadata unless the issuer matches exactly.
        for path in [
            "/.well-known/oauth-authorization-server/mcp",
            "/.well-known/oauth-authorization-server/mcp/",
        ]:
            metadata = self.get_json(path)
            self.assertEqual(metadata["issuer"], "https://testserver/mcp")
            self.assertEqual(metadata["authorization_endpoint"], "https://testserver/mcp/authorize")
            self.assertEqual(metadata["token_endpoint"], "https://testserver/mcp/token")
            self.assertEqual(metadata["registration_endpoint"], "https://testserver/mcp/register")

    def test_resource_and_issuer_are_consistent_across_documents(self):
        resource_metadata = self.get_json("/.well-known/oauth-protected-resource/mcp")
        server_metadata = self.get_json("/.well-known/oauth-authorization-server/mcp")
        self.assertEqual(resource_metadata["resource"], server_metadata["issuer"])
        self.assertEqual(resource_metadata["authorization_servers"], [server_metadata["issuer"]])

    def test_root_discovery_serves_the_mcp_oauth_endpoints(self):
        # Clients on the 2025-03-26 MCP auth spec (Littlebird, forum #13806) drop
        # the /mcp path and only look at the origin root. When that 404s they
        # skip OAuth entirely and report the server as rejecting an API token.
        root_server_metadata = self.get_json("/.well-known/oauth-authorization-server")
        self.assertEqual(root_server_metadata, self.get_json("/.well-known/oauth-authorization-server/mcp"))
        self.assertEqual(root_server_metadata["registration_endpoint"], "https://testserver/mcp/register")

        root_resource_metadata = self.get_json("/.well-known/oauth-protected-resource")
        self.assertEqual(root_resource_metadata, self.get_json("/.well-known/oauth-protected-resource/mcp"))

    def test_resource_satisfies_strict_clients_for_both_configured_variants(self):
        # Codex accepts the advertised resource only if it equals the configured
        # URL or is a prefix of it on a path-segment boundary. The no-slash form
        # passes for both documented configs; the slashed form fails the first.
        metadata = self.get_json("/.well-known/oauth-protected-resource/mcp")
        resource = metadata["resource"]
        for configured in ["https://testserver/mcp", "https://testserver/mcp/"]:
            self.assertTrue(
                configured == resource
                or (configured.startswith(resource) and configured[len(resource)] == "/"),
                f"resource {resource!r} would be rejected for configured URL {configured!r}",
            )


@override_settings(TEST_DEBUG=False)
class Test_MCPOAuthMetadataWithoutUserAgent(TestCase):
    """apps/profile/middleware.py:UserAgentBanMiddleware 403s requests with no
    User-Agent. The Python MCP SDK builds its discovery requests without one, so
    server-side MCP clients (Littlebird, forum #13806) were refused every
    discovery document, gave up on OAuth and fell back to asking for an API token.
    """

    DISCOVERY_PATHS = [
        "/.well-known/oauth-protected-resource/mcp/",
        "/.well-known/oauth-protected-resource/mcp",
        "/.well-known/oauth-protected-resource",
        "/.well-known/oauth-authorization-server/mcp",
        "/.well-known/oauth-authorization-server",
    ]

    def test_discovery_documents_serve_clients_without_a_user_agent(self):
        for path in self.DISCOVERY_PATHS:
            response = self.client.get(path)
            self.assertEqual(response.status_code, 200, f"{path} returned {response.content!r}")

    def test_missing_user_agent_is_still_banned_elsewhere(self):
        response = self.client.get("/reader/feeds")
        self.assertEqual(response.status_code, 403)
