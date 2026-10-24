from copy import deepcopy
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import httpx
import openai
from django.test import SimpleTestCase, override_settings

from apps.ask_ai import providers


def _completion(content="ok", usage=None):
    return SimpleNamespace(usage=usage, choices=[SimpleNamespace(message=SimpleNamespace(content=content))])


class Test_OpenAICompatibleProvider(SimpleTestCase):
    messages = [{"role": "user", "content": "Hello"}]

    def setUp(self):
        self.config = {
            "api_key": "unused-local-key",
            "base_url": "http://inference:8080/v1",
            "vendor_display": "Local",
        }
        self.provider = providers.OpenAICompatibleProvider(self.config)
        self.client = MagicMock()
        self.client.chat.completions.create.return_value = _completion()
        client_patch = patch("apps.ask_ai.providers.openai.OpenAI", return_value=self.client)
        self.openai_client = client_patch.start()
        self.addCleanup(client_patch.stop)

    @override_settings(OPENAI_COMPATIBLE_API_KEY="default-key", LOCAL_LLM_KEY="named-key")
    def test_key_precedence(self):
        for config, expected in (
            ({"api_key": "inline-key", "api_key_setting": "LOCAL_LLM_KEY"}, "inline-key"),
            ({"api_key_setting": "LOCAL_LLM_KEY"}, "named-key"),
            ({}, "default-key"),
        ):
            with self.subTest(config=config):
                self.openai_client.reset_mock()
                self.client.reset_mock()
                provider = providers.OpenAICompatibleProvider(config)
                self.assertTrue(provider.is_configured())
                provider.generate(self.messages, "local-model")
                self.openai_client.assert_called_once_with(api_key=expected)

    @override_settings(OPENAI_COMPATIBLE_API_KEY=None, OPENAI_API_KEY="sk-hosted-key")
    def test_missing_key_does_not_use_hosted_key(self):
        for key, expected in (
            (None, False),
            ("", False),
            ("XXXXXXXXXXXXXXXX", False),
            ("sk-XXXXXXXXXXXXXXXX", False),
            ("unused-local-key", True),
        ):
            with self.subTest(key=key):
                provider = providers.OpenAICompatibleProvider({"api_key": key})
                self.assertEqual(provider.is_configured(), expected)

    @override_settings(OPENAI_COMPATIBLE_API_KEY="default-key", LOCAL_LLM_KEY=None)
    def test_named_setting_does_not_fall_back_to_default_key(self):
        provider = providers.OpenAICompatibleProvider({"api_key_setting": "LOCAL_LLM_KEY"})
        self.assertFalse(provider.is_configured())

    def test_client_configuration(self):
        self.config["default_headers"] = {"HTTP-Referer": "https://newsblur.example"}
        self.assertTrue(self.provider.is_configured())
        self.provider.generate(self.messages, "local-model")
        self.openai_client.assert_called_once_with(
            api_key="unused-local-key",
            base_url="http://inference:8080/v1",
            default_headers={"HTTP-Referer": "https://newsblur.example"},
        )

    def test_streaming_text_and_final_usage(self):
        self.client.chat.completions.create.return_value = iter(
            [
                SimpleNamespace(usage=None, choices=[]),
                SimpleNamespace(usage=None, choices=[SimpleNamespace(delta=SimpleNamespace(content=None))]),
                SimpleNamespace(usage=None, choices=[SimpleNamespace(delta=SimpleNamespace(content="Hi"))]),
                SimpleNamespace(usage=None, choices=[SimpleNamespace(delta=SimpleNamespace(content="!"))]),
                SimpleNamespace(usage=SimpleNamespace(prompt_tokens=7, completion_tokens=2), choices=[]),
            ]
        )
        self.assertEqual(list(self.provider.stream_response(self.messages, "local-model")), ["Hi", "!"])
        self.assertEqual(self.provider.get_last_usage(), (7, 2))
        self.client.chat.completions.create.assert_called_once_with(
            model="local-model", messages=self.messages, stream=True, stream_options={"include_usage": True}
        )
        self.client.chat.completions.create.return_value = iter([SimpleNamespace(usage=None, choices=[])])
        self.assertEqual(list(self.provider.stream_response(self.messages, "local-model")), [])
        self.assertEqual(self.provider.get_last_usage(), (0, 0))

    def test_stream_options_can_be_changed_or_disabled(self):
        for options, expected in (
            (False, {}),
            ({}, {}),
            ({"include_usage": False}, {"stream_options": {"include_usage": False}}),
        ):
            with self.subTest(options=options):
                self.openai_client.reset_mock()
                self.client.reset_mock()
                self.config["stream_options"] = options
                self.client.chat.completions.create.return_value = iter([])
                list(self.provider.stream_response(self.messages, "local-model"))
                self.client.chat.completions.create.assert_called_once_with(
                    model="local-model", messages=self.messages, stream=True, **expected
                )

    def test_generate_text_and_usage(self):
        self.config["extra_body"] = {"temperature": 0.5}
        self.client.chat.completions.create.return_value = _completion(
            "Hello", SimpleNamespace(prompt_tokens=11, completion_tokens=3)
        )
        self.assertEqual(self.provider.generate(self.messages, "local-model"), "Hello")
        self.assertEqual(self.provider.get_last_usage(), (11, 3))
        self.client.chat.completions.create.assert_called_once_with(
            model="local-model", messages=self.messages, max_tokens=4096, extra_body={"temperature": 0.5}
        )
        self.client.chat.completions.create.return_value = _completion(content=None)
        self.assertEqual(self.provider.generate(self.messages, "local-model"), "")
        self.assertEqual(self.provider.get_last_usage(), (0, 0))

    def test_thinking_overrides_extra_body_without_mutating_config(self):
        self.config["extra_body"] = {"reasoning_effort": "low", "provider": {"order": ["local"]}}
        original = deepcopy(self.config["extra_body"])
        for streaming in (False, True):
            with self.subTest(streaming=streaming):
                self.openai_client.reset_mock()
                self.client.reset_mock()
                if streaming:
                    self.client.chat.completions.create.return_value = iter([])
                    list(
                        self.provider.stream_response(
                            self.messages, "local-model", thinking_config={"reasoning_effort": "high"}
                        )
                    )
                else:
                    self.client.chat.completions.create.return_value = _completion()
                    self.provider.generate(
                        self.messages, "local-model", thinking_config={"reasoning_effort": "high"}
                    )
                self.assertEqual(
                    self.client.chat.completions.create.call_args.kwargs["extra_body"],
                    {"reasoning_effort": "high", "provider": {"order": ["local"]}},
                )
                self.client.chat.completions.create.assert_called_once()
                self.assertEqual(self.config["extra_body"], original)

    def test_token_limit_configuration(self):
        for config, expected in (
            ({}, {"max_tokens": 100}),
            ({"max_tokens_parameter": "max_completion_tokens"}, {"max_completion_tokens": 100}),
            ({"max_tokens_multiplier": 5}, {"max_tokens": 500}),
            ({"max_tokens_minimum": 200}, {"max_tokens": 200}),
            ({"max_tokens_multiplier": 5, "max_tokens_minimum": 200}, {"max_tokens": 500}),
            (
                {
                    "max_tokens_parameter": "max_completion_tokens",
                    "max_tokens_multiplier": 2,
                    "max_tokens_minimum": 1000,
                },
                {"max_completion_tokens": 1000},
            ),
        ):
            with self.subTest(config=config):
                self.openai_client.reset_mock()
                self.client.reset_mock()
                provider = providers.OpenAICompatibleProvider({**self.config, **config})
                provider.generate(self.messages, "local-model", max_tokens=100)
                self.client.chat.completions.create.assert_called_once_with(
                    model="local-model", messages=self.messages, **expected
                )

    def test_provider_errors(self):
        request = httpx.Request("POST", "http://inference:8080/v1/chat/completions")
        timeout = openai.APITimeoutError(request=request)
        self.assertIn(type(timeout), self.provider.error_types)
        self.assertEqual(self.provider.format_error(timeout), "Local API timeout")
        for status, message in (
            (401, "API key is invalid"),
            (403, "API access denied"),
            (429, "rate limit"),
            (500, "API error"),
        ):
            with self.subTest(status=status):
                error = openai.APIStatusError(
                    "Request failed", response=httpx.Response(status, request=request), body=None
                )
                self.assertIsInstance(error, self.provider.error_types)
                self.assertIn(message, self.provider.format_error(error))
                self.assertTrue(self.provider.format_error(error).startswith("Local"))


class Test_ModelRegistry(SimpleTestCase):
    def setUp(self):
        self.config = {
            "provider": "openai_compatible",
            "model_id": "local-model",
            "display_name": "Local model",
            "vendor": "local",
            "vendor_display": "Local",
            "api_key": "secret-key",
            "api_key_setting": "LOCAL_LLM_KEY",
            "base_url": "http://inference:8080/v1",
            "default_headers": {"Authorization": "Bearer header-secret"},
            "stream_options": False,
            "extra_body": {"temperature": 0.5},
            "max_tokens_parameter": "max_completion_tokens",
            "max_tokens_multiplier": 2,
            "max_tokens_minimum": 1000,
            "thinking_config": {"reasoning_effort": "high"},
            "thinking_model_id": "local-thinking-model",
        }

    def test_custom_registries_keep_transport_config_private(self):
        variants = (
            ("ASK_AI_MODELS", providers._load_models, "MODELS", providers.get_models_for_frontend),
            (
                "BRIEFING_MODELS",
                providers._load_briefing_models,
                "BRIEFING_MODELS",
                providers.get_briefing_models_for_frontend,
            ),
        )
        for setting, loader, registry_name, serializer in variants:
            with self.subTest(setting=setting), override_settings(**{setting: {"local": self.config}}):
                registry = loader()
                self.assertEqual(list(registry), ["local"])
                self.assertIs(registry["local"]["provider_class"], providers.OpenAICompatibleProvider)
                for key, value in self.config.items():
                    if key != "provider":
                        self.assertEqual(registry["local"][key], value)
                with patch.object(providers, registry_name, registry):
                    self.assertEqual(
                        serializer(),
                        [
                            {
                                "key": "local",
                                "display_name": "Local model",
                                "vendor": "local",
                                "vendor_display": "Local",
                            }
                        ],
                    )

    def test_empty_or_unknown_provider_overrides_keep_defaults(self):
        for setting, loader, defaults in (
            ("ASK_AI_MODELS", providers._load_models, providers._DEFAULT_MODELS),
            ("BRIEFING_MODELS", providers._load_briefing_models, providers._DEFAULT_BRIEFING_MODELS),
        ):
            for override in (None, {}, {"invalid": {"provider": "unknown", "model_id": "unused"}}):
                with self.subTest(setting=setting, override=override), override_settings(
                    **{setting: override}
                ):
                    self.assertIs(loader(), defaults)

    @override_settings(OPENAI_API_KEY="sk-hosted-key", XAI_GROK_API_KEY="xai-hosted-key")
    @patch("apps.ask_ai.providers.openai.OpenAI")
    def test_hosted_factories_preserve_provider_classes_and_token_limits(self, mock_client):
        client = mock_client.return_value
        client.chat.completions.create.return_value = _completion()
        with patch.object(providers, "MODELS", providers._DEFAULT_MODELS), patch.object(
            providers, "BRIEFING_MODELS", providers._DEFAULT_BRIEFING_MODELS
        ):
            for factory in (providers.get_provider, providers.get_briefing_provider):
                for key, expected_class in (
                    ("anthropic", providers.AnthropicProvider),
                    ("openai", providers.OpenAIProvider),
                    ("google", providers.GeminiProvider),
                    ("xai", providers.XAIProvider),
                ):
                    with self.subTest(factory=factory.__name__, model=key):
                        mock_client.reset_mock()
                        provider, model_id = factory(key)[:2]
                        self.assertIsInstance(provider, expected_class)
                        if key in ("openai", "xai"):
                            provider.generate([], model_id, max_tokens=100)
                            client.chat.completions.create.assert_called_once_with(
                                model=model_id, messages=[], max_completion_tokens=16384
                            )

    def test_custom_factories_resolve_runtime_defaults_and_thinking(self):
        with override_settings(ASK_AI_MODELS={"local": self.config}, BRIEFING_MODELS={"local": self.config}):
            models = providers._load_models()
            briefing_models = providers._load_briefing_models()
        with patch.object(providers, "MODELS", models), patch.object(
            providers, "BRIEFING_MODELS", briefing_models
        ), patch.object(providers, "DEFAULT_MODEL", "local"), patch.object(
            providers, "DEFAULT_BRIEFING_MODEL", "missing"
        ):
            provider, model_id, thinking = providers.get_provider("missing")
            self.assertEqual((model_id, thinking), ("local-model", None))
            self.assertIsInstance(provider, providers.OpenAICompatibleProvider)
            self.assertEqual(provider.model_config, models["local"])
            self.assertTrue(provider.is_configured())
            provider, model_id, thinking = providers.get_provider("local", thinking=True)
            self.assertEqual((model_id, thinking), ("local-thinking-model", {"reasoning_effort": "high"}))
            self.assertEqual(provider.model_config, models["local"])
            for requested in (None, "missing"):
                with self.subTest(requested=requested):
                    provider, model_id = providers.get_briefing_provider(requested)
                    self.assertEqual(model_id, "local-model")
                    self.assertIsInstance(provider, providers.OpenAICompatibleProvider)
                    self.assertEqual(provider.model_config, briefing_models["local"])
                    self.assertTrue(provider.is_configured())
