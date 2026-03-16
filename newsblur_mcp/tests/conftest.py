"""Test fixtures for NewsBlur MCP server."""

import pytest


@pytest.fixture
def sample_story():
    return {
        "story_hash": "123:abcdef",
        "story_title": "Test Story Title",
        "story_content": "<p>This is a <b>test</b> story with HTML content.</p>",
        "story_authors": "Test Author",
        "story_permalink": "https://example.com/story",
        "story_date": "2026-03-16 10:00:00",
        "story_feed_id": 42,
        "story_tags": ["tech", "ai"],
        "user_tags": [],
        "user_notes": "",
        "highlights": [],
        "intelligence": {"feed": 0, "author": 1, "tags": 0, "title": 0},
        "read_status": 0,
        "starred": False,
        "shared": False,
        "image_urls": [],
    }


@pytest.fixture
def sample_feed():
    return {
        "id": 42,
        "feed_title": "Test Feed",
        "feed_address": "https://example.com/feed.xml",
        "feed_link": "https://example.com",
        "num_subscribers": 100,
        "active": True,
        "nt": 5,
        "ps": 2,
        "ng": 0,
        "last_story_date": "2026-03-16",
        "favicon_color": "5A5A5A",
    }
