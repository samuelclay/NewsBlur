"""Tests for MCP resources."""

import json

import pytest
from fastmcp.resources import ResourceResult

from newsblur_mcp.resources import resources


class FakeResourceClient:
    async def get_feeds(self):
        return {
            "feeds": {
                "42": {
                    "id": 42,
                    "feed_title": "Example Feed",
                    "feed_address": "https://example.com/rss",
                    "feed_link": "https://example.com",
                    "num_subscribers": 10,
                    "active": True,
                    "nt": 1,
                    "ps": 2,
                    "ng": 0,
                }
            },
            "flat_folders": {"Tech": [42]},
        }

    async def get(self, path, params=None):
        if path == "/reader/feed/42":
            return {
                "feed": {
                    "id": 42,
                    "feed_title": "Example Feed",
                    "feed_address": "https://example.com/rss",
                    "feed_link": "https://example.com",
                    "num_subscribers": 10,
                    "active": True,
                    "nt": 1,
                    "ps": 2,
                    "ng": 0,
                }
            }
        if path == "/reader/starred_counts":
            return {"starred_counts": [{"tag": "research", "count": 3}], "starred_count": 3}
        if path == "/reader/all_classifiers":
            return {"classifiers": {"42": {"titles": [{"name": "AI", "score": 1}]}}}
        if path == "/profile/get_preferences":
            return {"user": {"username": "sam", "is_archive": True, "feed_count": 1}}
        raise AssertionError(f"Unexpected path: {path}")

    async def close(self):
        pass


def _as_resource_result(result):
    if isinstance(result, ResourceResult):
        return result
    return ResourceResult(result)


@pytest.mark.asyncio
class Test_resources:
    @pytest.mark.parametrize(
        "resource,args,expected_key",
        [
            (resources.feeds_resource, (), "feeds"),
            (resources.feed_resource, (42,), "id"),
            (resources.folders_resource, (), "folders"),
            (resources.saved_tags_resource, (), "tags"),
            (resources.classifiers_resource, (), "classifiers"),
            (resources.profile_resource, (), "username"),
        ],
    )
    async def test_resources_return_fastmcp_compatible_content(
        self, monkeypatch, resource, args, expected_key
    ):
        monkeypatch.setattr(resources, "get_client", FakeResourceClient)

        result = await resource(None, *args)
        resource_result = _as_resource_result(result)

        assert len(resource_result.contents) == 1
        assert resource_result.contents[0].mime_type == "application/json"
        assert expected_key in json.loads(resource_result.contents[0].content)
