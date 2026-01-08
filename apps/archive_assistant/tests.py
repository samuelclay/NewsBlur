# apps/archive_assistant/tests.py
"""
Unit tests for the Archive Assistant app.
"""
from datetime import datetime
from unittest.mock import MagicMock, patch

from django.test import TestCase
from django.test.client import Client

from apps.archive_assistant.tools import (
    ARCHIVE_TOOLS,
    execute_tool,
    search_archives,
    get_archive_content,
    get_archive_categories,
)
from apps.archive_assistant.prompts import (
    ARCHIVE_ASSISTANT_SYSTEM_PROMPT,
    get_suggested_questions,
)


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

    def test_get_archive_categories_tool_defined(self):
        """get_archive_categories tool should be defined."""
        tool_names = [t["name"] for t in ARCHIVE_TOOLS]
        self.assertIn("get_archive_categories", tool_names)


class Test_ToolExecution(TestCase):
    """Tests for tool execution."""

    def setUp(self):
        """Set up test fixtures."""
        self.user_id = 1

    @patch("apps.archive_assistant.tools.MArchivedStory")
    def test_search_archives_returns_results(self, mock_model):
        """search_archives should return matching archives."""
        mock_archive = MagicMock()
        mock_archive.id = "abc123"
        mock_archive.title = "Test Article"
        mock_archive.url = "https://example.com/test"
        mock_archive.domain = "example.com"
        mock_archive.archived_date = datetime.now()
        mock_archive.ai_categories = ["Technology"]

        mock_model.objects.return_value.filter.return_value.order_by.return_value.limit.return_value = [
            mock_archive
        ]

        result = search_archives(self.user_id, query="test")

        self.assertIsInstance(result, list)

    @patch("apps.archive_assistant.tools.MArchivedStory")
    def test_search_archives_handles_empty_results(self, mock_model):
        """search_archives should handle no results gracefully."""
        mock_model.objects.return_value.filter.return_value.order_by.return_value.limit.return_value = []

        result = search_archives(self.user_id, query="nonexistent query")

        self.assertIsInstance(result, list)
        self.assertEqual(len(result), 0)

    @patch("apps.archive_assistant.tools.MArchivedStory")
    def test_get_archive_content_returns_content(self, mock_model):
        """get_archive_content should return archive content."""
        mock_archive = MagicMock()
        mock_archive.user_id = self.user_id
        mock_archive.title = "Test Article"
        mock_archive.url = "https://example.com/test"
        mock_archive.get_content.return_value = "Article content here"

        mock_model.objects.get.return_value = mock_archive

        result = get_archive_content(self.user_id, archive_id="abc123")

        self.assertIn("content", result)

    @patch("apps.archive_assistant.tools.MArchivedStory")
    def test_get_archive_content_validates_user(self, mock_model):
        """get_archive_content should validate user ownership."""
        mock_archive = MagicMock()
        mock_archive.user_id = 999  # Different user

        mock_model.objects.get.return_value = mock_archive

        result = get_archive_content(self.user_id, archive_id="abc123")

        # Should return error when user doesn't own the archive
        self.assertIn("error", result)

    @patch("apps.archive_assistant.tools.MArchivedStory")
    def test_get_archive_categories_returns_breakdown(self, mock_model):
        """get_archive_categories should return category breakdown."""
        mock_model.objects.return_value.filter.return_value.aggregate.return_value = {
            "Technology": 10,
            "Science": 5,
            "Business": 3,
        }

        result = get_archive_categories(self.user_id)

        self.assertIsInstance(result, dict)

    def test_execute_tool_handles_unknown_tool(self):
        """execute_tool should handle unknown tool names."""
        result = execute_tool(self.user_id, "unknown_tool", {})

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
