from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import httpx
import openai
from django.test import SimpleTestCase

from apps.ask_ai.providers import DEFAULT_MODEL
from apps.ask_ai.tasks import AskAIQuestion


def _xai_error(error_class, status_code, message):
    request = httpx.Request("POST", "https://api.x.ai/v1/chat/completions")
    response = httpx.Response(status_code, request=request)
    return error_class(message, response=response, body={"error": message})


def _failing_stream(error):
    def stream_response(messages, model_id, thinking_config=None):
        raise error
        yield  # stream_response is a generator, so the error surfaces on the first chunk

    return stream_response


class Test_AskAIRefusalFallback(SimpleTestCase):
    """AskAIQuestion in apps/ask_ai/tasks.py when the chosen provider refuses the account."""

    def setUp(self):
        self.user = SimpleNamespace(pk=1, username="tester")
        self.story = SimpleNamespace(
            story_title="A story", original_text_str="Story text.", original_text_z=None
        )
        self.published = []

        self._patch("apps.ask_ai.tasks.User.objects.get", return_value=self.user)
        self._patch("apps.ask_ai.tasks.logging.user")
        self._patch("apps.ask_ai.tasks.MStory.find_story", return_value=(self.story, None))
        self._patch("apps.ask_ai.tasks.get_full_prompt", return_value="Summarize this.")
        responses = self._patch("apps.ask_ai.tasks.MAskAIResponse")
        responses.get_cached_response.return_value = None
        usage = self._patch("apps.ask_ai.tasks.AskAIUsageTracker")
        usage.return_value.get_usage_message.return_value = None
        mock_redis = self._patch("apps.ask_ai.tasks.redis.Redis")
        mock_redis.return_value.publish.side_effect = lambda channel, message: self.published.append(message)
        self.record_usage = self._patch("apps.ask_ai.tasks.LLMCostTracker.record_usage")

    def _patch(self, target, **kwargs):
        patcher = patch(target, **kwargs)
        self.addCleanup(patcher.stop)
        return patcher.start()

    def _default_provider(self):
        provider = MagicMock()
        provider.is_configured.return_value = True
        provider.stream_response.return_value = iter(["Hello ", "world"])
        provider.get_last_usage.return_value = (10, 5)
        return provider

    def _event_types(self):
        return [message.split('"type": "')[1].split('"')[0] for message in self.published]

    @patch("apps.ask_ai.tasks.get_provider")
    def test_grok_out_of_credits_answers_with_the_default_model(self, mock_get_provider):
        """SpaceXSI answers 403 once the account's credits run out; Ask AI should still answer."""
        refused = _xai_error(
            openai.PermissionDeniedError, 403, "Your team has either used all available credits"
        )
        grok = MagicMock()
        grok.is_configured.return_value = True
        grok.stream_response.side_effect = _failing_stream(refused)
        grok.format_error.return_value = "SpaceXSI API access denied."
        default = self._default_provider()
        mock_get_provider.side_effect = [
            (grok, "grok-4.7", None),
            (default, "claude-sonnet-5-5", None),
        ]

        result = AskAIQuestion(user_id=1, story_hash="1:abc123", question_id="sentence", model="xai")

        self.assertEqual(result["code"], 1)
        self.assertEqual([c.args[0] for c in mock_get_provider.call_args_list], ["xai", DEFAULT_MODEL])
        self.assertNotIn("error", self._event_types())
        self.assertEqual(self._event_types().count("chunk"), 2)
        cost = self.record_usage.call_args.kwargs
        self.assertEqual(cost["model"], "claude-sonnet-5-5")
        self.assertEqual(cost["provider"], "anthropic")

    @patch("apps.ask_ai.tasks.get_provider")
    def test_bad_request_from_grok_is_reported_not_retried(self, mock_get_provider):
        """A 400 is a bug in our request, not the account being refused, so it isn't hidden."""
        bad_request = _xai_error(openai.BadRequestError, 400, "Invalid request")
        grok = MagicMock()
        grok.is_configured.return_value = True
        grok.stream_response.side_effect = _failing_stream(bad_request)
        grok.format_error.return_value = "SpaceXSI API error: Invalid request"
        mock_get_provider.side_effect = [(grok, "grok-4.7", None)]

        result = AskAIQuestion(user_id=1, story_hash="1:abc123", question_id="sentence", model="xai")

        self.assertEqual(result["code"], -1)
        self.assertEqual(mock_get_provider.call_count, 1)
        self.assertIn("error", self._event_types())
        self.record_usage.assert_not_called()
