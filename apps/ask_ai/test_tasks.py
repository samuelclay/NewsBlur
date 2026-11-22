import importlib.util
import json
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import httpx
import openai
from django.test import SimpleTestCase, override_settings

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


LOCAL_MODEL = {
    "provider": "openai_compatible",
    "model_id": "qwen2.5:1.5b",
    "base_url": "http://ollama:11434/v1",
    "extra_body": {"top_k": 40},
}
ROUTER_MODEL = {
    "provider": "openai_compatible",
    "model_id": "meta-llama/llama-4-scout",
    "base_url": "https://router.example/api/v1",
    "api_key": "router-key",
}


def _stream_chunk(content=None, usage=None):
    choices = [SimpleNamespace(delta=SimpleNamespace(content=content))] if content else []
    return SimpleNamespace(usage=usage, choices=choices)


class AskAITaskTestCase(SimpleTestCase):
    """AskAIQuestion in apps/ask_ai/tasks.py with the user, story, Redis and usage stubbed out."""

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


class Test_AskAIRefusalFallback(AskAITaskTestCase):
    """AskAIQuestion in apps/ask_ai/tasks.py when the chosen provider refuses the account."""

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


class Test_AskAIOpenAICompatible(AskAITaskTestCase):
    """AskAIQuestion answering from a self-hosted "provider": "openai_compatible" model."""

    def setUp(self):
        super().setUp()
        self.openai_client = self._patch("apps.ask_ai.providers.openai.OpenAI")
        self.openai_client.return_value.chat.completions.create.return_value = iter(
            [
                _stream_chunk("Local "),
                _stream_chunk("answer"),
                _stream_chunk(usage=SimpleNamespace(prompt_tokens=42, completion_tokens=7)),
            ]
        )

    def _load_registry_from_settings(self):
        """Import apps/ask_ai/providers.py afresh under this test's settings, as a server does
        at startup, and point AskAIQuestion at that registry."""
        spec = importlib.util.find_spec("apps.ask_ai.providers")
        providers = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(providers)
        for name in ("MODELS", "MODEL_VENDORS", "DEFAULT_MODEL", "get_provider"):
            self._patch(f"apps.ask_ai.tasks.{name}", new=getattr(providers, name))
        return providers

    def _chunks(self):
        events = [json.loads(message.split(":", 1)[1]) for message in self.published]
        return [event["chunk"] for event in events if event["type"] == "chunk"]

    @override_settings(ASK_AI_MODELS={"local": {**LOCAL_MODEL, "api_key": "local-server-key"}})
    def test_answer_streams_from_the_configured_server(self):
        self._load_registry_from_settings()

        result = AskAIQuestion(user_id=1, story_hash="1:abc123", question_id="sentence", model="local")

        self.assertEqual(result["code"], 1)
        self.assertEqual(self._chunks(), ["Local ", "answer"])
        self.openai_client.assert_called_once_with(
            base_url="http://ollama:11434/v1", api_key="local-server-key"
        )
        request = self.openai_client.return_value.chat.completions.create.call_args.kwargs
        self.assertEqual(request["extra_body"], LOCAL_MODEL["extra_body"])
        cost = self.record_usage.call_args.kwargs
        self.assertEqual(
            (cost["model"], cost["input_tokens"], cost["output_tokens"]), ("qwen2.5:1.5b", 42, 7)
        )

    @override_settings(ASK_AI_MODEL="anthropic", ASK_AI_MODELS={"local": LOCAL_MODEL})
    def test_ask_ai_model_left_at_anthropic_answers_with_a_listed_model(self):
        """Listing only your own models in ASK_AI_MODELS, without also changing ASK_AI_MODEL,
        still answers."""
        self._load_registry_from_settings()

        result = AskAIQuestion(user_id=1, story_hash="1:abc123", question_id="sentence")

        self.assertEqual(result["code"], 1)
        request = self.openai_client.return_value.chat.completions.create.call_args.kwargs
        self.assertEqual(request["model"], "qwen2.5:1.5b")

    @override_settings(ASK_AI_MODEL="router", ASK_AI_MODELS={"local": LOCAL_MODEL, "router": ROUTER_MODEL})
    def test_web_reader_starts_on_the_configured_default_model(self):
        """The model list the web reader gets marks ASK_AI_MODEL, not the first listed model,
        as where a user who hasn't picked one starts."""
        providers = self._load_registry_from_settings()

        defaults = [model["key"] for model in providers.get_models_for_frontend() if model["is_default"]]

        self.assertEqual(defaults, ["router"])

    @override_settings(
        OPENAI_API_KEY="sk-hosted-openai-key",
        ASK_AI_MODELS={"local": LOCAL_MODEL, "router": ROUTER_MODEL},
        BRIEFING_MODELS={"local": LOCAL_MODEL, "router": ROUTER_MODEL},
    )
    def test_server_settings_stay_private(self):
        """A server without an api_key never receives the hosted OpenAI key, and no model's
        base_url or api_key reaches the browser."""
        providers = self._load_registry_from_settings()

        result = AskAIQuestion(user_id=1, story_hash="1:abc123", question_id="sentence", model="local")

        self.assertEqual(result["code"], 1)
        self.assertNotIn("sk-hosted-openai-key", str(self.openai_client.call_args))
        # test_tasks.py: Without a key the SDK reads OPENAI_API_KEY from the environment.
        self.assertTrue(self.openai_client.call_args.kwargs["api_key"])
        for frontend_models in (
            providers.get_models_for_frontend(),
            providers.get_briefing_models_for_frontend(),
        ):
            self.assertEqual([model["key"] for model in frontend_models], ["local", "router"])
            serialized = json.dumps(frontend_models)
            for private in ("ollama:11434", "router.example", "router-key", "top_k"):
                self.assertNotIn(private, serialized)
