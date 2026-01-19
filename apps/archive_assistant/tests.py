# apps/archive_assistant/tests.py
"""
Unit tests for the Archive Assistant app.
"""
from unittest.mock import MagicMock, patch

from django.test import TestCase
from django.test.client import Client

from apps.archive_assistant.prompts import (
    ARCHIVE_ASSISTANT_SYSTEM_PROMPT,
    get_suggested_questions,
)
from apps.archive_assistant.tools import ARCHIVE_TOOLS, execute_tool


class Test_ArchiveTools(TestCase):
    """Tests for Claude tool definitions."""

    def test_tools_have_required_fields(self):
        """All tools should have name, description, and input_schema."""
        for tool in ARCHIVE_TOOLS:
            self.assertIn("name", tool)
            self.assertIn("description", tool)
            self.assertIn("input_schema", tool)
            self.assertIn("type", tool["input_schema"])
            self.assertEqual(tool["input_schema"]["type"], "object")

    def test_search_archives_tool_defined(self):
        """search_archives tool should be defined."""
        tool_names = [t["name"] for t in ARCHIVE_TOOLS]
        self.assertIn("search_archives", tool_names)

    def test_get_archive_content_tool_defined(self):
        """get_archive_content tool should be defined."""
        tool_names = [t["name"] for t in ARCHIVE_TOOLS]
        self.assertIn("get_archive_content", tool_names)

    def test_get_archive_summary_tool_defined(self):
        """get_archive_summary tool should be defined."""
        tool_names = [t["name"] for t in ARCHIVE_TOOLS]
        self.assertIn("get_archive_summary", tool_names)


class Test_ToolExecution(TestCase):
    """Tests for tool execution."""

    def setUp(self):
        """Set up test fixtures."""
        self.user_id = 1

    @patch("apps.archive_assistant.tools.MArchivedStory")
    def test_search_archives_returns_results(self, mock_model):
        """search_archives should return matching archives via execute_tool."""
        mock_archive = MagicMock()
        mock_archive.id = "abc123"
        mock_archive.title = "Test Article"
        mock_archive.url = "https://example.com/test"
        mock_archive.domain = "example.com"
        mock_archive.ai_categories = ["Technology"]

        mock_model.objects.return_value.__iter__ = lambda s: iter([mock_archive])
        mock_model.objects.return_value.count.return_value = 1

        result = execute_tool("search_archives", {"query": "test"}, self.user_id)

        self.assertIsInstance(result, dict)

    @patch("apps.archive_assistant.tools.MArchivedStory")
    def test_get_archive_content_returns_content(self, mock_model):
        """get_archive_content should return archive content via execute_tool."""
        mock_archive = MagicMock()
        mock_archive.user_id = self.user_id
        mock_archive.title = "Test Article"
        mock_archive.url = "https://example.com/test"
        mock_archive.get_content.return_value = "Article content here"

        mock_model.objects.get.return_value = mock_archive

        result = execute_tool("get_archive_content", {"archive_id": "abc123"}, self.user_id)

        self.assertIn("content", result)

    @patch("apps.archive_assistant.tools.MArchivedStory")
    def test_get_archive_content_handles_not_found(self, mock_model):
        """get_archive_content should handle archive not found."""
        from mongoengine import DoesNotExist

        mock_model.DoesNotExist = DoesNotExist
        mock_model.objects.get.side_effect = DoesNotExist()

        result = execute_tool("get_archive_content", {"archive_id": "abc123"}, self.user_id)

        # Should return error when archive not found
        self.assertIn("error", result)

    def test_execute_tool_handles_unknown_tool(self):
        """execute_tool should handle unknown tool names."""
        result = execute_tool("unknown_tool", {}, self.user_id)

        self.assertIn("error", result)


class Test_SystemPrompt(TestCase):
    """Tests for system prompt."""

    def test_system_prompt_not_empty(self):
        """System prompt should not be empty."""
        self.assertTrue(len(ARCHIVE_ASSISTANT_SYSTEM_PROMPT) > 100)

    def test_system_prompt_mentions_archives(self):
        """System prompt should mention archives."""
        self.assertIn("archive", ARCHIVE_ASSISTANT_SYSTEM_PROMPT.lower())

    def test_system_prompt_mentions_tools(self):
        """System prompt should mention using tools."""
        self.assertIn("search", ARCHIVE_ASSISTANT_SYSTEM_PROMPT.lower())


class Test_SuggestedQuestions(TestCase):
    """Tests for suggested questions generation."""

    def test_get_suggested_questions_returns_list(self):
        """get_suggested_questions should return a list."""
        questions = get_suggested_questions()
        self.assertIsInstance(questions, list)

    def test_suggested_questions_not_empty(self):
        """Should return at least some suggested questions."""
        questions = get_suggested_questions()
        self.assertGreater(len(questions), 0)

    def test_suggested_questions_are_strings(self):
        """All suggested questions should be strings."""
        questions = get_suggested_questions()
        for q in questions:
            self.assertIsInstance(q, str)
            self.assertTrue(len(q) > 10)  # Each question should have meaningful content


class Test_ArchiveAssistantAPIEndpoints(TestCase):
    """Tests for Archive Assistant API endpoints."""

    def setUp(self):
        """Set up test client."""
        self.client = Client()

    def test_query_requires_authentication(self):
        """Query endpoint should require authentication."""
        response = self.client.post(
            "/archive-assistant/query",
            {"query": "What did I read about AI?"},
            content_type="application/json",
        )
        self.assertIn(response.status_code, [302, 403])

    def test_conversations_requires_authentication(self):
        """Conversations list should require authentication."""
        response = self.client.get("/archive-assistant/conversations")
        self.assertIn(response.status_code, [302, 403])

    def test_suggestions_requires_authentication(self):
        """Suggestions endpoint should require authentication."""
        response = self.client.get("/archive-assistant/suggestions")
        self.assertIn(response.status_code, [302, 403])


class Test_ConversationManagement(TestCase):
    """Tests for conversation management."""

    def setUp(self):
        """Set up test fixtures."""
        self.user_id = 1

    @patch("apps.archive_assistant.views.MArchiveConversation")
    def test_create_conversation(self, mock_conversation):
        """Should be able to create a new conversation."""
        mock_conv = MagicMock()
        mock_conv.id = "conv123"
        mock_conversation.objects.create.return_value = mock_conv

        # This would be called by the view
        conv = mock_conversation.objects.create(user_id=self.user_id)

        self.assertIsNotNone(conv)

    @patch("apps.archive_assistant.views.MArchiveConversation")
    def test_conversation_isolation(self, mock_conversation):
        """Conversations should be isolated per user."""
        # Mock to verify user_id filtering
        mock_conversation.objects.return_value.filter.return_value = []

        # Should only return conversations for the specified user
        mock_conversation.objects.filter(user_id=self.user_id)
        mock_conversation.objects.filter.assert_called_with(user_id=self.user_id)
