import os

NEWSBLUR_BASE_URL = os.environ.get("NEWSBLUR_BASE_URL", "http://nb.com:8000")
MCP_PORT = int(os.environ.get("MCP_PORT", "8099"))
MCP_HOST = os.environ.get("MCP_HOST", "0.0.0.0")

NEWSBLUR_PUBLIC_URL = os.environ.get("NEWSBLUR_PUBLIC_URL", "https://newsblur.com")

# Content limits for AI-friendly responses
MAX_STORY_CONTENT_LENGTH = 2000
DEFAULT_STORIES_PER_PAGE = 12
MAX_STORIES_PER_PAGE = 50

# HTTP client settings
REQUEST_TIMEOUT = 30.0

# Redis for shared OAuth client/token storage across MCP instances
MCP_REDIS_URL = os.environ.get("MCP_REDIS_URL", "redis://localhost:6579/5")

# OAuth settings for upstream Django OAuth2 proxy
MCP_OAUTH_CLIENT_ID = os.environ.get("MCP_OAUTH_CLIENT_ID", "newsblur-mcp-server")
MCP_OAUTH_CLIENT_SECRET = os.environ.get("MCP_OAUTH_CLIENT_SECRET", "newsblur-mcp-dev-secret")

# Public URL where MCP server is accessible (used for OAuth metadata/callbacks)
MCP_OAUTH_BASE_URL = os.environ.get("MCP_OAUTH_BASE_URL", NEWSBLUR_PUBLIC_URL + "/mcp")

# Browser-facing URL for OAuth authorization redirects (user sees this)
MCP_OAUTH_UPSTREAM_URL = os.environ.get("MCP_OAUTH_UPSTREAM_URL", NEWSBLUR_BASE_URL)

# Internal URL for server-to-server calls (token exchange, verification)
# Bypasses TLS to avoid self-signed cert issues in dev
MCP_OAUTH_INTERNAL_URL = os.environ.get("MCP_OAUTH_INTERNAL_URL", NEWSBLUR_BASE_URL)
