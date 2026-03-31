"""Custom OAuth2 validator that implements RFC 8252 loopback redirect URI matching.

RFC 8252 Section 7.3 specifies that for loopback redirect URIs (127.0.0.1 or [::1]),
the port should be excluded from the redirect URI comparison. This allows CLI tools
to bind to a random available port for the OAuth callback.
"""

from urllib.parse import urlparse

from oauth2_provider.oauth2_validators import OAuth2Validator

LOOPBACK_HOSTS = {"127.0.0.1", "localhost", "[::1]"}


def _normalize_loopback_uri(parsed):
    """Normalize a loopback URI by stripping port and mapping localhost -> 127.0.0.1."""
    host = "127.0.0.1" if parsed.hostname == "localhost" else parsed.hostname
    return parsed._replace(netloc=host).geturl()


class RFC8252OAuth2Validator(OAuth2Validator):
    def validate_redirect_uri(self, client_id, redirect_uri, request, *args, **kwargs):
        # First try exact match (handles non-loopback URIs)
        if super().validate_redirect_uri(client_id, redirect_uri, request, *args, **kwargs):
            return True

        # RFC 8252: for loopback redirect URIs, ignore the port
        parsed = urlparse(redirect_uri)
        if parsed.hostname not in LOOPBACK_HOSTS:
            return False

        # Normalize: strip port, map localhost -> 127.0.0.1
        normalized = _normalize_loopback_uri(parsed)
        for allowed_uri in request.client.redirect_uris.split():
            allowed_parsed = urlparse(allowed_uri)
            if allowed_parsed.hostname in LOOPBACK_HOSTS:
                allowed_normalized = _normalize_loopback_uri(allowed_parsed)
                if normalized == allowed_normalized:
                    return True

        return False
