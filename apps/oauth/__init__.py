"""OAuth integration for extensions, IFTTT, and social account connections.

Provides OAuth2 endpoints for browser extensions and IFTTT, and handles
connecting user accounts to Twitter and Facebook. Also patches Django's
HttpResponseRedirect to allow browser extension schemes (chrome-extension://,
moz-extension://) for extension OAuth flows.
"""

from django.http import HttpResponseRedirect

# Add browser extension schemes to the allowed list
if "chrome-extension" not in HttpResponseRedirect.allowed_schemes:
    HttpResponseRedirect.allowed_schemes = list(HttpResponseRedirect.allowed_schemes) + [
        "chrome-extension",
        "moz-extension",
    ]
