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
