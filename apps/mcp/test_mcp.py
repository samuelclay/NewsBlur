"""Tests for MCP OAuth well-known metadata (apps/mcp/views.py).

Strict OAuth clients (Codex's rmcp) exact-match these URLs during discovery:
the RFC 8414 path-insertion form derives an expected issuer with no trailing
slash, so every identity URL served here (resource, authorization_servers,
issuer) must use the canonical no-trailing-slash form https://host/mcp.
See https://forum.newsblur.com/t/13801 for the failure both variants hit.
"""

import json

from django.test import TestCase


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
