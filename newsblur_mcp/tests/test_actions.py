"""Tests for story action tools."""

import pytest

from newsblur_mcp.tools.actions import _mark_stories_read


class FakeActionsClient:
    def __init__(self):
        self.posts = []
        self.feeds_response = {
            "feeds": {
                "1": {"nt": 3, "ps": 2, "ng": 1},
                "2": {"nt": 4, "ps": 0, "ng": 0},
                "3": {"nt": 7, "ps": 1, "ng": 0},
            },
            "flat_folders": {
                "test": [1, 2],
                "other": [3],
            },
        }

    async def get_feeds(self):
        return self.feeds_response

    async def post(self, path, data=None):
        self.posts.append((path, data))
        if path == "/reader/mark_story_hashes_as_read":
            return {"code": 1, "story_hashes": data["story_hash"]}
        return {"code": 1}


@pytest.mark.asyncio
class Test_actions:
    async def test_mark_folder_read_resolves_folder_to_feed_ids(self):
        client = FakeActionsClient()

        result = await _mark_stories_read(client, folder="test")

        assert client.posts == [
            (
                "/reader/mark_feed_as_read",
                {
                    "feed_id": [1, 2],
                },
            )
        ]
        assert result == {
            "code": 1,
            "message": "Stories marked as read",
            "marked_count": 10,
        }

    async def test_mark_folder_read_reports_missing_folder(self):
        client = FakeActionsClient()

        result = await _mark_stories_read(client, folder="missing")

        assert client.posts == []
        assert result == {"error": "Folder 'missing' not found or empty"}

    async def test_mark_feed_read_older_than_uses_cutoff_timestamp(self, monkeypatch):
        client = FakeActionsClient()
        monkeypatch.setattr("newsblur_mcp.tools.actions.time.time", lambda: 1_800_000_000)

        result = await _mark_stories_read(client, feed_id=1, older_than_days=3)

        assert client.posts == [
            (
                "/reader/mark_feed_as_read",
                {
                    "feed_id": 1,
                    "cutoff_timestamp": 1_799_740_800,
                },
            )
        ]
        assert result == {
            "code": 1,
            "message": "Stories marked as read",
            "marked_count": None,
        }

    async def test_mark_story_hashes_read_reports_marked_count(self):
        client = FakeActionsClient()

        result = await _mark_stories_read(client, story_hashes=["1:abc", "2:def"])

        assert result == {
            "code": 1,
            "message": "Stories marked as read",
            "marked_count": 2,
        }
