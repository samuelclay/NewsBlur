"""Tests for MCP tool error handling."""

import httpx
import pytest

from newsblur_mcp.client import ArchiveRequiredError
from newsblur_mcp.tools import feeds, stories


class ArchiveRequiredClient:
    async def get_feeds(self):
        raise ArchiveRequiredError(
            "MCP access requires a NewsBlur Premium Archive subscription. "
            "Upgrade at https://newsblur.com/pricing"
        )

    async def close(self):
        pass


class MissingFeedClient:
    async def get(self, path, params=None):
        request = httpx.Request("GET", f"http://newsblur_web:8000{path}")
        response = httpx.Response(404, request=request)
        raise httpx.HTTPStatusError("Feed not found", request=request, response=response)

    async def close(self):
        pass


class SearchTimeoutClient:
    async def post(self, path, data=None):
        request = httpx.Request("POST", f"http://newsblur_web:8000{path}")
        response = httpx.Response(500, request=request)
        raise httpx.HTTPStatusError("Elasticsearch timeout", request=request, response=response)

    async def close(self):
        pass


@pytest.mark.asyncio
class Test_tool_errors:
    async def test_archive_required_errors_return_tool_payload(self, monkeypatch):
        monkeypatch.setattr(feeds, "get_client", ArchiveRequiredClient)
        monkeypatch.setitem(
            feeds.newsblur_list_folders_with_feeds.__globals__, "log_request", lambda *args: None
        )

        result = await feeds.newsblur_list_folders_with_feeds()

        assert result == {
            "code": "archive_required",
            "error": (
                "MCP access requires a NewsBlur Premium Archive subscription. "
                "Upgrade at https://newsblur.com/pricing"
            ),
        }

    async def test_http_404_errors_return_tool_payload(self, monkeypatch):
        monkeypatch.setattr(feeds, "get_client", MissingFeedClient)
        monkeypatch.setitem(feeds.newsblur_get_feed_info.__globals__, "log_request", lambda *args: None)

        result = await feeds.newsblur_get_feed_info(feed_id=625358)

        assert result == {
            "code": "newsblur_api_error",
            "error": "NewsBlur API returned 404 Not Found for /reader/feed/625358",
            "status_code": 404,
        }

    async def test_http_500_errors_return_tool_payload(self, monkeypatch):
        monkeypatch.setattr(stories, "get_client", lambda: SearchTimeoutClient())
        monkeypatch.setitem(stories.newsblur_search_stories.__globals__, "log_request", lambda *args: None)

        result = await stories.newsblur_search_stories(query="ai")

        assert result == {
            "code": "newsblur_api_error",
            "error": "NewsBlur API returned 500 Internal Server Error for /reader/river_stories",
            "status_code": 500,
        }
