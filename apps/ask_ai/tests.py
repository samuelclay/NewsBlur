from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from django.test import SimpleTestCase, override_settings

from apps.ask_ai import providers


class OpenAICompatibleProviderTest(SimpleTestCase):
    @override_settings(
        OPENROUTER_API_KEY="openrouter-key",
        ASK_AI_MODELS={
            "openrouter-auto": {
                "provider": "openai_compatible",
                "model_id": "openrouter/auto",
                "display_name": "OpenRouter Auto",
                "vendor": "openrouter",
                "vendor_display": "OpenRouter",
                "api_key_setting": "OPENROUTER_API_KEY",
                "base_url": "https://openrouter.ai/api/v1",
                "default_headers": {
                    "HTTP-Referer": "https://newsblur.example",
                    "X-Title": "NewsBlur Self Hosted",
                },
                "stream_options": {"include_usage": True},
                "max_tokens_parameter": "max_tokens",
                "max_tokens_multiplier": 1,
                "extra_body": {"provider": {"order": ["openai"]}},
            },
        },
    )
    def test_custom_openrouter_model_uses_openai_compatible_client_config(self):
        models = providers._load_models()
        with patch.object(providers, "MODELS", models), patch.object(
            providers, "VALID_MODELS", list(models.keys())
        ), patch.object(providers, "MODEL_VENDORS", {key: m["vendor"] for key, m in models.items()}):
            provider, model_id, _thinking_config = providers.get_provider("openrouter-auto")

            self.assertIsInstance(provider, providers.OpenAICompatibleProvider)
            self.assertEqual(model_id, "openrouter/auto")
            self.assertTrue(provider.is_configured())
            self.assertEqual(providers.MODEL_VENDORS["openrouter-auto"], "openrouter")

            client = MagicMock()
            response = MagicMock()
            response.usage = SimpleNamespace(prompt_tokens=3, completion_tokens=5)
            response.choices = [SimpleNamespace(message=SimpleNamespace(content="ok"))]
            client.chat.completions.create.return_value = response

            with patch("apps.ask_ai.providers.openai.OpenAI", return_value=client) as openai_client:
                result = provider.generate([{"role": "user", "content": "hello"}], model_id, max_tokens=100)

            self.assertEqual(result, "ok")
            openai_client.assert_called_once_with(
                api_key="openrouter-key",
                base_url="https://openrouter.ai/api/v1",
                default_headers={
                    "HTTP-Referer": "https://newsblur.example",
                    "X-Title": "NewsBlur Self Hosted",
                },
            )
            client.chat.completions.create.assert_called_once_with(
                model="openrouter/auto",
                messages=[{"role": "user", "content": "hello"}],
                max_tokens=100,
                extra_body={"provider": {"order": ["openai"]}},
            )

    @override_settings(
        BRIEFING_MODELS={
            "local": {
                "provider": "openai_compatible",
                "model_id": "local-model",
                "display_name": "Local Model",
                "api_key": "local-key",
                "base_url": "http://localhost:8080/v1",
                "stream_options": False,
                "max_tokens_parameter": "max_tokens",
                "max_tokens_multiplier": 1,
            },
        },
    )
    def test_custom_briefing_local_model_omits_stream_options_and_uses_max_tokens(self):
        briefing_models = providers._load_briefing_models()
        with patch.object(providers, "BRIEFING_MODELS", briefing_models):
            provider, model_id = providers.get_briefing_provider("local")

            self.assertIsInstance(provider, providers.OpenAICompatibleProvider)
            self.assertEqual(model_id, "local-model")
            self.assertTrue(provider.is_configured())

            client = MagicMock()
            chunk = SimpleNamespace(
                usage=SimpleNamespace(prompt_tokens=7, completion_tokens=11),
                choices=[SimpleNamespace(delta=SimpleNamespace(content="chunk"))],
            )
            client.chat.completions.create.return_value = iter([chunk])

            with patch("apps.ask_ai.providers.openai.OpenAI", return_value=client) as openai_client:
                chunks = list(provider.stream_response([{"role": "user", "content": "hello"}], model_id))

                self.assertEqual(chunks, ["chunk"])
                openai_client.assert_called_once_with(api_key="local-key", base_url="http://localhost:8080/v1")
                client.chat.completions.create.assert_called_once_with(
                    model="local-model",
                    messages=[{"role": "user", "content": "hello"}],
                    stream=True,
                )

                client.chat.completions.create.reset_mock()
                response = MagicMock()
                response.usage = None
                response.choices = [SimpleNamespace(message=SimpleNamespace(content="done"))]
                client.chat.completions.create.return_value = response

                result = provider.generate([{"role": "user", "content": "hello"}], model_id, max_tokens=123)

                self.assertEqual(result, "done")
                client.chat.completions.create.assert_called_once_with(
                    model="local-model",
                    messages=[{"role": "user", "content": "hello"}],
                    max_tokens=123,
                )

    @override_settings(
        ASK_AI_MODELS={
            "openrouter-auto": {
                "provider": "openai_compatible",
                "model_id": "openrouter/auto",
                "display_name": "OpenRouter Auto",
                "vendor": "openrouter",
                "vendor_display": "OpenRouter",
                "api_key": "secret",
                "api_key_setting": "OPENROUTER_API_KEY",
                "base_url": "https://openrouter.ai/api/v1",
                "default_headers": {"X-Title": "NewsBlur"},
            },
        },
    )
    def test_frontend_model_serialization_does_not_expose_transport_config(self):
        models = providers._load_models()
        with patch.object(providers, "MODELS", models):
            serialized = providers.get_models_for_frontend()

        self.assertEqual(
            serialized,
            [
                {
                    "key": "openrouter-auto",
                    "display_name": "OpenRouter Auto",
                    "vendor": "openrouter",
                    "vendor_display": "OpenRouter",
                }
            ],
        )

    @override_settings(
        ASK_AI_MODELS={
            "unknown": {
                "provider": "unknown",
                "model_id": "unknown-model",
                "display_name": "Unknown",
            },
        },
    )
    def test_unknown_provider_slugs_fall_back_to_defaults(self):
        self.assertIs(providers._load_models(), providers._DEFAULT_MODELS)
