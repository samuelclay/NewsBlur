"""Tests for story tools."""

import pytest

from newsblur_mcp.tools import stories


class FakeStoriesClient:
    def __init__(self):
        self.posts = []

    async def post(self, path, data=None):
        self.posts.append((path, data))
        return {"stories": []}

    async def close(self):
        pass


@pytest.mark.asyncio
class Test_stories:
    async def test_get_stories_accepts_singular_feed_id(self, monkeypatch):
        client = FakeStoriesClient()
        monkeypatch.setattr(stories, "get_client", lambda: client)
        monkeypatch.setitem(stories.newsblur_get_stories.__globals__, "log_request", lambda *args: None)

        result = await stories.newsblur_get_stories(feed_id=9005709)

        assert result["items"] == []
        assert client.posts == [
            (
                "/reader/river_stories",
                {
                    "page": 1,
                    "limit": 12,
                    "order": "newest",
                    "read_filter": "unread",
                    "feeds": [9005709],
                },
            )
        ]
