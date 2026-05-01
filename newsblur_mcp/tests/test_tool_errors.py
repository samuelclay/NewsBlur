"""Tests for MCP tool error handling."""

import pytest

from newsblur_mcp.client import ArchiveRequiredError
from newsblur_mcp.tools import feeds


class ArchiveRequiredClient:
    async def get_feeds(self):
        raise ArchiveRequiredError(
            "MCP access requires a NewsBlur Premium Archive subscription. "
            "Upgrade at https://newsblur.com/pricing"
        )

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
