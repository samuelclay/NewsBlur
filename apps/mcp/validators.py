"""Custom OAuth2 validator that implements RFC 8252 loopback redirect URI matching.

RFC 8252 Section 7.3 specifies that for loopback redirect URIs (127.0.0.1 or [::1]),
the port should be excluded from the redirect URI comparison. This allows CLI tools
to bind to a random available port for the OAuth callback.
"""

from urllib.parse import urlparse

from oauth2_provider.oauth2_validators import OAuth2Validator

LOOPBACK_HOSTS = {"127.0.0.1", "[::1]"}


class RFC8252OAuth2Validator(OAuth2Validator):
    def validate_redirect_uri(self, client_id, redirect_uri, request, *args, **kwargs):
        # First try exact match (handles non-loopback URIs)
        if super().validate_redirect_uri(client_id, redirect_uri, request, *args, **kwargs):
            return True

        # RFC 8252: for loopback redirect URIs, ignore the port
        parsed = urlparse(redirect_uri)
        if parsed.hostname not in LOOPBACK_HOSTS:
            return False

        # Strip the port and compare against registered URIs
        portless = parsed._replace(netloc=parsed.hostname).geturl()
        for allowed_uri in request.client.redirect_uris.split():
            allowed_parsed = urlparse(allowed_uri)
            if allowed_parsed.hostname in LOOPBACK_HOSTS:
                allowed_portless = allowed_parsed._replace(netloc=allowed_parsed.hostname).geturl()
                if portless == allowed_portless:
                    return True

        return False
