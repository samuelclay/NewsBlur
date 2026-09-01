"""Tests for Reading Archive tools."""

import pytest

from newsblur_mcp.tools import archive


class FakeArchiveClient:
    def __init__(self, get_responses=None, post_responses=None):
        self.gets = []
        self.posts = []
        self._get_responses = get_responses or {}
        self._post_responses = post_responses or {}

    async def get(self, path, params=None):
        self.gets.append((path, params))
        response = self._get_responses.get(path, {})
        if callable(response):
            return response()
        return response

    async def post(self, path, data=None):
        self.posts.append((path, data))
        return self._post_responses.get(path, {})

    async def close(self):
        pass


@pytest.mark.asyncio
class Test_archive:
    async def test_search_archive_passes_params_and_transforms(self, monkeypatch):
        client = FakeArchiveClient(
            get_responses={
                "/api/archive/list": {
                    "code": 0,
                    "archives": [
                        {
                            "id": "abc123",
                            "title": "A 4K Webcam Review",
                            "url": "https://example.com/webcam",
                            "domain": "example.com",
                            "author": "Reviewer",
                            "first_visited": "2026-07-01T00:00:00Z",
                            "last_visited": "2026-07-02T00:00:00Z",
                            "visit_count": 2,
                            "ai_categories": ["Shopping"],
                            "highlights": ["a <em>4K webcam</em> for the Mac"],
                            "content_z_should_not_leak": "binary",
                        }
                    ],
                    "total": 1,
                    "has_more": False,
                }
            }
        )
        monkeypatch.setattr(archive, "get_client", lambda: client)
        monkeypatch.setitem(archive.newsblur_search_archive.__globals__, "log_request", lambda *args: None)

        result = await archive.newsblur_search_archive(query="4K webcam", domain="example.com")

        assert client.gets == [
            (
                "/api/archive/list",
                {"limit": 12, "offset": 0, "search": "4K webcam", "domain": "example.com"},
            )
        ]
        assert result["total"] == 1
        assert result["has_more"] is False
        item = result["items"][0]
        assert item["title"] == "A 4K Webcam Review"
        assert item["highlights"] == ["a <em>4K webcam</em> for the Mac"]
        assert "content_z_should_not_leak" not in item

    async def test_search_archive_paginates_offset(self, monkeypatch):
        client = FakeArchiveClient(get_responses={"/api/archive/list": {"code": 0, "archives": []}})
        monkeypatch.setattr(archive, "get_client", lambda: client)
        monkeypatch.setitem(archive.newsblur_search_archive.__globals__, "log_request", lambda *args: None)

        await archive.newsblur_search_archive(page=3, limit=20)

        assert client.gets == [("/api/archive/list", {"limit": 20, "offset": 40})]

    async def test_ask_archive_polls_until_response(self, monkeypatch):
        conversation_states = iter(
            [
                {"queries": [{"id": "q1", "query_text": "what camera?", "response": None}]},
                {
                    "queries": [
                        {
                            "id": "q1",
                            "query_text": "what camera?",
                            "response": "You read about the Razer Kiyo V2.",
                            "model": "claude-sonnet-4-5",
                            "duration_ms": 1234,
                        }
                    ]
                },
            ]
        )
        client = FakeArchiveClient(
            get_responses={"/archive-assistant/conversation/conv1": lambda: next(conversation_states)},
            post_responses={
                "/archive-assistant/query": {"code": 0, "query_id": "q1", "conversation_id": "conv1"}
            },
        )
        monkeypatch.setattr(archive, "get_client", lambda: client)
        monkeypatch.setattr(archive, "ASSISTANT_POLL_INTERVAL_SECONDS", 0.001)
        monkeypatch.setitem(archive.newsblur_ask_archive.__globals__, "log_request", lambda *args: None)

        result = await archive.newsblur_ask_archive(question="what camera?")

        assert client.posts == [("/archive-assistant/query", {"query": "what camera?"})]
        assert result["answer"] == "You read about the Razer Kiyo V2."
        assert result["conversation_id"] == "conv1"

    async def test_ask_archive_returns_query_error(self, monkeypatch):
        client = FakeArchiveClient(
            get_responses={
                "/archive-assistant/conversation/conv1": {
                    "queries": [{"id": "q1", "error": "Model unavailable"}]
                }
            },
            post_responses={
                "/archive-assistant/query": {"code": 0, "query_id": "q1", "conversation_id": "conv1"}
            },
        )
        monkeypatch.setattr(archive, "get_client", lambda: client)
        monkeypatch.setattr(archive, "ASSISTANT_POLL_INTERVAL_SECONDS", 0.001)
        monkeypatch.setitem(archive.newsblur_ask_archive.__globals__, "log_request", lambda *args: None)

        result = await archive.newsblur_ask_archive(question="what camera?")

        assert result["error"] == "Model unavailable"

    async def test_ask_archive_times_out(self, monkeypatch):
        client = FakeArchiveClient(
            get_responses={"/archive-assistant/conversation/conv1": {"queries": []}},
            post_responses={
                "/archive-assistant/query": {"code": 0, "query_id": "q1", "conversation_id": "conv1"}
            },
        )
        monkeypatch.setattr(archive, "get_client", lambda: client)
        monkeypatch.setattr(archive, "ASSISTANT_POLL_INTERVAL_SECONDS", 1)
        monkeypatch.setattr(archive, "ASSISTANT_TIMEOUT_SECONDS", 0)
        monkeypatch.setitem(archive.newsblur_ask_archive.__globals__, "log_request", lambda *args: None)

        result = await archive.newsblur_ask_archive(question="what camera?")

        assert "Timed out" in result["error"]
        assert result["conversation_id"] == "conv1"

    async def test_get_archive_stats(self, monkeypatch):
        client = FakeArchiveClient(
            get_responses={
                "/api/archive/stats": {
                    "code": 0,
                    "stats": {"total_archived": 5658, "archives_this_week": 70},
                }
            }
        )
        monkeypatch.setattr(archive, "get_client", lambda: client)
        monkeypatch.setitem(archive.newsblur_get_archive_stats.__globals__, "log_request", lambda *args: None)

        result = await archive.newsblur_get_archive_stats()

        assert result == {"total_archived": 5658, "archives_this_week": 70}
