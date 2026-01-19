"""
Default blocklist for the Archive Extension.

These domains and URL patterns are blocked by default to protect user privacy.
Users can customize their blocklist via the extension settings.
"""

import re
from urllib.parse import urlparse

# Domains that are always blocked (privacy-sensitive)
DEFAULT_BLOCKED_DOMAINS = [
    # Banking & Finance
    "chase.com",
    "bankofamerica.com",
    "wellsfargo.com",
    "citi.com",
    "citibank.com",
    "capitalone.com",
    "usbank.com",
    "pnc.com",
    "schwab.com",
    "fidelity.com",
    "vanguard.com",
    "tdameritrade.com",
    "etrade.com",
    "robinhood.com",
    "coinbase.com",
    "binance.com",
    "kraken.com",
    "paypal.com",
    "venmo.com",
    "zelle.com",
    "stripe.com",
    "square.com",
    "ally.com",
    "discover.com",
    "americanexpress.com",
    "hsbc.com",
    "barclays.com",
    "goldmansachs.com",
    "morganstanley.com",
    # Medical & Health
    "mychart.com",
    "myhealth.va.gov",
    "healthgrades.com",
    "webmd.com",  # Contains personal health info when logged in
    "zocdoc.com",
    "teladoc.com",
    "mdlive.com",
    "betterhelp.com",
    "talkspace.com",
    "goodrx.com",
    "cvs.com",
    "walgreens.com",
    "express-scripts.com",
    "optumrx.com",
    "caremark.com",
    # Email Providers (webmail interfaces)
    "mail.google.com",
    "outlook.live.com",
    "outlook.office.com",
    "outlook.office365.com",
    "mail.yahoo.com",
    "protonmail.com",
    "proton.me",
    "fastmail.com",
    "tutanota.com",
    "zoho.com",
    "icloud.com",
    "aol.com",
    # Password Managers
    "1password.com",
    "lastpass.com",
    "bitwarden.com",
    "dashlane.com",
    "keeper.com",
    "nordpass.com",
    "roboform.com",
    # Social Media Direct Messages (specific subdomains/paths)
    "messages.google.com",
    "messenger.com",
    "web.whatsapp.com",
    "web.telegram.org",
    "discord.com",
    "slack.com",
    "teams.microsoft.com",
    # HR & Payroll Systems
    "workday.com",
    "adp.com",
    "paychex.com",
    "gusto.com",
    "bamboohr.com",
    "namely.com",
    "zenefits.com",
    "rippling.com",
    # Tax & Government
    "irs.gov",
    "ssa.gov",
    "turbotax.intuit.com",
    "hrblock.com",
    "taxact.com",
    "dmv.org",
    # Insurance
    "geico.com",
    "statefarm.com",
    "progressive.com",
    "allstate.com",
    "usaa.com",
    "libertymutual.com",
    "travelers.com",
    "nationwide.com",
    # Dating Apps
    "tinder.com",
    "bumble.com",
    "hinge.co",
    "match.com",
    "okcupid.com",
    "eharmony.com",
    "pof.com",
    # Internal/Development (localhost, etc.)
    "localhost",
    "127.0.0.1",
    "0.0.0.0",
]

# Domain suffixes to block (e.g., corporate intranets)
DEFAULT_BLOCKED_SUFFIXES = [
    ".internal",
    ".corp",
    ".local",
    ".lan",
    ".intranet",
    ".private",
]

# IP address ranges to block (private networks)
BLOCKED_IP_PREFIXES = [
    "192.168.",
    "10.",
    "172.16.",
    "172.17.",
    "172.18.",
    "172.19.",
    "172.20.",
    "172.21.",
    "172.22.",
    "172.23.",
    "172.24.",
    "172.25.",
    "172.26.",
    "172.27.",
    "172.28.",
    "172.29.",
    "172.30.",
    "172.31.",
]

# URL path patterns to block (compiled regexes)
DEFAULT_BLOCKED_PATTERNS = [
    # Shopping carts and checkout
    r"/cart",
    r"/checkout",
    r"/payment",
    r"/billing",
    r"/order-confirmation",
    r"/purchase",
    r"/basket",
    # Authentication pages
    r"/login",
    r"/signin",
    r"/sign-in",
    r"/signup",
    r"/sign-up",
    r"/register",
    r"/auth",
    r"/oauth",
    r"/sso",
    r"/forgot-password",
    r"/reset-password",
    r"/mfa",
    r"/2fa",
    r"/verify",
    # Account settings
    r"/account/settings",
    r"/account/security",
    r"/account/privacy",
    r"/settings/account",
    r"/settings/security",
    r"/settings/privacy",
    r"/profile/edit",
    r"/preferences",
    # Admin interfaces
    r"/admin",
    r"/wp-admin",
    r"/dashboard",
    r"/console",
    r"/manage",
    # Direct messages (generic patterns)
    r"/messages",
    r"/inbox",
    r"/dm",
    r"/direct",
    r"/conversations",
    r"/chat",
]

# Compile regex patterns
_compiled_patterns = [re.compile(pattern, re.IGNORECASE) for pattern in DEFAULT_BLOCKED_PATTERNS]


def is_blocked(url, user_settings=None):
    """
    Check if a URL should be blocked from archiving.

    Args:
        url: The URL to check
        user_settings: Optional MArchiveUserSettings for custom blocklist

    Returns:
        bool: True if URL should be blocked
    """
    try:
        parsed = urlparse(url)
        scheme = parsed.scheme.lower()
        domain = parsed.netloc.lower()
        path = parsed.path.lower()

        # Block non-http(s) URLs
        if scheme not in ("http", "https"):
            return True

        # Remove www. prefix for matching
        if domain.startswith("www."):
            domain = domain[4:]

        # Extract port if present
        if ":" in domain:
            domain = domain.split(":")[0]

        # Check user's explicit allowlist first
        if user_settings and domain in (user_settings.allowed_domains or []):
            return False

        # Check user's custom blocklist
        if user_settings:
            if domain in (user_settings.blocked_domains or []):
                return True
            for pattern in user_settings.blocked_patterns or []:
                try:
                    if re.search(pattern, url, re.IGNORECASE):
                        return True
                except re.error:
                    pass

        # Check default blocked domains
        if domain in DEFAULT_BLOCKED_DOMAINS:
            return True

        # Check blocked suffixes
        for suffix in DEFAULT_BLOCKED_SUFFIXES:
            if domain.endswith(suffix):
                return True

        # Check IP address ranges
        for prefix in BLOCKED_IP_PREFIXES:
            if domain.startswith(prefix):
                return True

        # Check URL path patterns
        for pattern in _compiled_patterns:
            if pattern.search(path):
                return True

        return False

    except Exception:
        # If URL parsing fails, block it to be safe
        return True


def get_blocked_domains():
    """Return the list of default blocked domains."""
    return DEFAULT_BLOCKED_DOMAINS.copy()


def get_blocked_patterns():
    """Return the list of default blocked URL patterns."""
    return DEFAULT_BLOCKED_PATTERNS.copy()
