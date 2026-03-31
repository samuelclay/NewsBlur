"""Async HTTP client for the NewsBlur REST API.

Forwards the user's OAuth bearer token on every request.
Checks premium status and gates access for free users.
"""

import httpx

from newsblur_mcp.settings import NEWSBLUR_BASE_URL, NEWSBLUR_PUBLIC_URL, REQUEST_TIMEOUT


class ArchiveRequiredError(Exception):
    pass


class NewsBlurClient:
    """Stateless async client that proxies requests to NewsBlur's REST API."""

    def __init__(self, bearer_token: str, base_url: str | None = None):
        self.bearer_token = bearer_token
        self._is_archive: bool | None = None
        self._feeds_cache: dict | None = None
        url = base_url or NEWSBLUR_BASE_URL
        self._http = httpx.AsyncClient(
            base_url=url,
            headers={"Authorization": f"Bearer {bearer_token}"},
            timeout=REQUEST_TIMEOUT,
            verify=not self._is_local(url),
        )

    @staticmethod
    def _is_local(url: str) -> bool:
        from urllib.parse import urlparse
        return urlparse(url).hostname in {"localhost", "127.0.0.1", "::1"}

    async def close(self):
        await self._http.aclose()

    async def check_archive(self) -> bool:
        """Check and cache whether the authenticated user has a premium archive subscription.

        Reads from a disk cache (~/.config/newsblur/premium.json) to avoid
        hitting /profile/is_premium on every CLI invocation. The cache is
        valid for 24 hours.
        """
        if self._is_archive is not None:
            return self._is_archive

        # Try disk cache first
        import json as _json
        import time
        from pathlib import Path

        cache_path = Path.home() / ".config" / "newsblur" / "premium.json"
        try:
            if cache_path.exists():
                cache = _json.loads(cache_path.read_text())
                if time.time() < cache.get("expires_at", 0):
                    self._is_archive = bool(cache.get("is_premium_archive"))
                    return self._is_archive
        except (OSError, _json.JSONDecodeError, KeyError):
            pass

        resp = await self._http.get("/profile/is_premium", params={"retries": 0})
        resp.raise_for_status()
        data = resp.json()
        self._is_archive = bool(data.get("is_premium_archive"))

        # Cache to disk for 24 hours
        try:
            cache_path.parent.mkdir(parents=True, exist_ok=True)
            cache_path.write_text(_json.dumps({
                "is_premium_archive": self._is_archive,
                "expires_at": time.time() + 86400,
            }))
        except OSError:
            pass

        return self._is_archive

    async def get_feeds(self) -> dict:
        """Get feeds with caching. Uses a 1-hour disk cache to avoid
        hitting /reader/feeds on every CLI invocation."""
        if self._feeds_cache is not None:
            return self._feeds_cache

        import json as _json
        import time
        from pathlib import Path

        cache_path = Path.home() / ".config" / "newsblur" / "feeds_cache.json"
        try:
            if cache_path.exists():
                cache = _json.loads(cache_path.read_text())
                if time.time() < cache.get("expires_at", 0):
                    self._feeds_cache = cache["data"]
                    return self._feeds_cache
        except (OSError, _json.JSONDecodeError, KeyError):
            pass

        self._feeds_cache = await self.get("/reader/feeds", params={"flat": "true"})

        try:
            cache_path.parent.mkdir(parents=True, exist_ok=True)
            cache_path.write_text(_json.dumps({
                "data": self._feeds_cache,
                "expires_at": time.time() + 3600,
            }))
        except OSError:
            pass

        return self._feeds_cache

    async def require_archive(self):
        """Raise ArchiveRequiredError if the user is not premium archive."""
        if not await self.check_archive():
            raise ArchiveRequiredError(
                "MCP access requires a NewsBlur Premium Archive subscription. "
                f"Upgrade at {NEWSBLUR_PUBLIC_URL}/pricing"
            )

    async def get(self, path: str, params: dict | None = None) -> dict:
        await self.require_archive()
        resp = await self._http.get(path, params=params)
        resp.raise_for_status()
        return resp.json()

    async def get_unprotected(self, path: str, params: dict | None = None) -> dict:
        """GET without premium check. Use for endpoints any user needs (e.g. account info)."""
        resp = await self._http.get(path, params=params)
        resp.raise_for_status()
        return resp.json()

    async def post(self, path: str, data: dict | None = None) -> dict:
        await self.require_archive()
        resp = await self._http.post(path, data=data)
        resp.raise_for_status()
        return resp.json()

    async def delete(self, path: str, data: dict | None = None) -> dict:
        await self.require_archive()
        resp = await self._http.delete(path, params=data)
        resp.raise_for_status()
        return resp.json()
