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
        self._http = httpx.AsyncClient(
            base_url=base_url or NEWSBLUR_BASE_URL,
            headers={"Authorization": f"Bearer {bearer_token}"},
            timeout=REQUEST_TIMEOUT,
        )

    async def close(self):
        await self._http.aclose()

    async def check_archive(self) -> bool:
        """Check and cache whether the authenticated user has a premium archive subscription."""
        if self._is_archive is not None:
            return self._is_archive
        resp = await self._http.get("/profile/is_premium", params={"retries": 0})
        resp.raise_for_status()
        data = resp.json()
        self._is_archive = bool(data.get("is_premium_archive"))
        return self._is_archive

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
