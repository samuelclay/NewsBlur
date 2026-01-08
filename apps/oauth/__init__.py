# Patch Django's HttpResponseRedirect to allow chrome-extension:// URLs
# This is needed for browser extension OAuth flows
from django.http import HttpResponseRedirect

# Add browser extension schemes to the allowed list
if "chrome-extension" not in HttpResponseRedirect.allowed_schemes:
    HttpResponseRedirect.allowed_schemes = list(HttpResponseRedirect.allowed_schemes) + [
        "chrome-extension",
        "moz-extension",
    ]
