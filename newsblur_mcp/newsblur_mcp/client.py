"""Async HTTP client for the NewsBlur REST API.

Forwards the user's OAuth bearer token on every request.
Checks premium status and gates access for free users.
"""

import httpx

from newsblur_mcp.settings import NEWSBLUR_BASE_URL, NEWSBLUR_PUBLIC_URL, REQUEST_TIMEOUT


class PremiumRequiredError(Exception):
    pass


class NewsBlurClient:
    """Stateless async client that proxies requests to NewsBlur's REST API."""

    def __init__(self, bearer_token: str, base_url: str | None = None):
        self.bearer_token = bearer_token
        self._is_premium: bool | None = None
        self._http = httpx.AsyncClient(
            base_url=base_url or NEWSBLUR_BASE_URL,
            headers={"Authorization": f"Bearer {bearer_token}"},
            timeout=REQUEST_TIMEOUT,
        )

    async def close(self):
        await self._http.aclose()

    async def check_premium(self) -> bool:
        """Check and cache whether the authenticated user has a premium subscription."""
        if self._is_premium is not None:
            return self._is_premium
        resp = await self._http.get("/profile/is_premium", params={"retries": 0})
        resp.raise_for_status()
        data = resp.json()
        self._is_premium = bool(data.get("is_premium"))
        return self._is_premium

    async def require_premium(self):
        """Raise PremiumRequiredError if the user is not premium."""
        if not await self.check_premium():
            raise PremiumRequiredError(
                "MCP access requires a NewsBlur Premium subscription. "
                f"Upgrade at {NEWSBLUR_PUBLIC_URL}/pricing"
            )

    async def get(self, path: str, params: dict | None = None) -> dict:
        await self.require_premium()
        resp = await self._http.get(path, params=params)
        resp.raise_for_status()
        return resp.json()

    async def get_unprotected(self, path: str, params: dict | None = None) -> dict:
        """GET without premium check. Use for endpoints any user needs (e.g. account info)."""
        resp = await self._http.get(path, params=params)
        resp.raise_for_status()
        return resp.json()

    async def post(self, path: str, data: dict | None = None) -> dict:
        await self.require_premium()
        resp = await self._http.post(path, data=data)
        resp.raise_for_status()
        return resp.json()

    async def delete(self, path: str, data: dict | None = None) -> dict:
        await self.require_premium()
        resp = await self._http.delete(path, params=data)
        resp.raise_for_status()
        return resp.json()
