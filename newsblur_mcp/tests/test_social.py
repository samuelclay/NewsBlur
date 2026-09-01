"""Tests for social and trending story tools."""

import pytest

from newsblur_mcp.tools import social


class FakeSocialClient:
    def __init__(self, response=None):
        self.gets = []
        self._response = response or {"stories": []}

    async def get(self, path, params=None):
        self.gets.append((path, params))
        return self._response

    async def close(self):
        pass


@pytest.mark.asyncio
class Test_social:
    async def test_shared_stories_global_river(self, monkeypatch):
        client = FakeSocialClient(
            response={
                "stories": [
                    {
                        "story_hash": "42:abc",
                        "story_title": "A Shared Story",
                        "story_permalink": "https://example.com/shared",
                        "story_feed_id": 42,
                        "share_count": 3,
                        "comment_count": 1,
                        "shared_by_public": [101, 102],
                        "comments": [{"user_id": 101, "comments": "Great read", "shared_date": "2026-08-25"}],
                    }
                ]
            }
        )
        monkeypatch.setattr(social, "get_client", lambda: client)
        monkeypatch.setitem(social.newsblur_get_shared_stories.__globals__, "log_request", lambda *args: None)

        result = await social.newsblur_get_shared_stories()

        assert client.gets == [
            (
                "/social/river_stories",
                {"page": 1, "limit": 12, "order": "newest", "read_filter": "all", "global_feed": "true"},
            )
        ]
        item = result["items"][0]
        assert item["title"] == "A Shared Story"
        assert item["share_count"] == 3
        assert item["shared_by_user_ids"] == [101, 102]
        assert item["comments"] == [{"user_id": 101, "comment": "Great read", "date": "2026-08-25"}]

    async def test_shared_stories_friends_river_with_sharers(self, monkeypatch):
        client = FakeSocialClient()
        monkeypatch.setattr(social, "get_client", lambda: client)
        monkeypatch.setitem(social.newsblur_get_shared_stories.__globals__, "log_request", lambda *args: None)

        await social.newsblur_get_shared_stories(global_feed=False, social_user_ids=[7, 8])

        path, params = client.gets[0]
        assert "global_feed" not in params
        assert params["social_user_ids"] == [7, 8]

    async def test_trending_stories_passes_type(self, monkeypatch):
        client = FakeSocialClient()
        monkeypatch.setattr(social, "get_client", lambda: client)
        monkeypatch.setitem(
            social.newsblur_get_trending_stories.__globals__, "log_request", lambda *args: None
        )

        result = await social.newsblur_get_trending_stories(trending_type="long_reads")

        assert client.gets == [
            (
                "/reader/trending_stories",
                {
                    "trending_type": "long_reads",
                    "page": 1,
                    "limit": 12,
                    "order": "newest",
                    "read_filter": "all",
                },
            )
        ]
        assert result["trending_type"] == "long_reads"

    async def test_trending_stories_rejects_bad_type(self, monkeypatch):
        client = FakeSocialClient()
        monkeypatch.setattr(social, "get_client", lambda: client)
        monkeypatch.setitem(
            social.newsblur_get_trending_stories.__globals__, "log_request", lambda *args: None
        )

        result = await social.newsblur_get_trending_stories(trending_type="hot_takes")

        assert "trending_type must be one of" in result["error"]
        assert client.gets == []
