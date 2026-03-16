"""Tests for response transformers."""

from newsblur_mcp.transforms import html_to_text, truncate_content, transform_story, transform_feed, paginate


class Test_html_to_text:
    def test_basic_html(self):
        result = html_to_text("<p>Hello <b>world</b></p>")
        assert "Hello" in result
        assert "world" in result

    def test_strips_scripts(self):
        assert html_to_text("<p>Text</p><script>alert(1)</script>") == "Text"

    def test_strips_styles(self):
        assert html_to_text("<style>.x{}</style><p>Text</p>") == "Text"

    def test_empty_string(self):
        assert html_to_text("") == ""

    def test_none(self):
        assert html_to_text(None) == ""

    def test_collapses_newlines(self):
        result = html_to_text("<p>A</p><p></p><p></p><p>B</p>")
        assert "\n\n\n" not in result


class Test_truncate_content:
    def test_short_text_not_truncated(self):
        result = truncate_content("short", max_length=100)
        assert result["truncated"] is False
        assert result["text"] == "short"

    def test_long_text_truncated(self):
        result = truncate_content("x" * 200, max_length=100)
        assert result["truncated"] is True
        assert len(result["text"]) == 103  # 100 + "..."
        assert result["full_length"] == 200


class Test_transform_story:
    def test_basic_transform(self, sample_story):
        result = transform_story(sample_story)
        assert result["story_hash"] == "123:abcdef"
        assert result["title"] == "Test Story Title"
        assert result["author"] == "Test Author"
        assert result["url"] == "https://example.com/story"
        assert "test" in result["content"].lower()
        assert "story" in result["content"].lower()

    def test_strips_html_from_content(self, sample_story):
        result = transform_story(sample_story)
        assert "<p>" not in result["content"]
        assert "<b>" not in result["content"]


class Test_transform_feed:
    def test_basic_transform(self, sample_feed):
        result = transform_feed(sample_feed)
        assert result["id"] == 42
        assert result["title"] == "Test Feed"
        assert result["unread_neutral"] == 5
        assert result["unread_positive"] == 2


class Test_paginate:
    def test_pagination_metadata(self):
        items = [1, 2, 3]
        result = paginate(items, page=2, has_more=True)
        assert result["items"] == [1, 2, 3]
        assert result["page"] == 2
        assert result["has_more"] is True
        assert result["count"] == 3
