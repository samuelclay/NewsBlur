import re
from abc import ABC, abstractmethod
from typing import Generator, Optional

import anthropic
import openai
from django.conf import settings
from google import genai
from google.genai import errors as genai_errors
from google.genai import types as genai_types

from utils import log as logging
from utils.llm_models import (
    ANTHROPIC_CHAT_MODEL,
    ANTHROPIC_CHAT_MODEL_DISPLAY,
    GOOGLE_MODEL,
    GOOGLE_MODEL_DISPLAY,
    OPENAI_MODEL,
    OPENAI_MODEL_DISPLAY,
    XAI_MODEL,
    XAI_MODEL_DISPLAY,
)


def _is_placeholder(key):
    """Check if a key is a placeholder (e.g. 'sk-ant-XXXXXXXX...' from settings template)."""
    return bool(re.match(r"^[\w-]*X{8,}$", key))


class LLMProvider(ABC):
    """Abstract base class for LLM providers."""

    def __init__(self, model_config: Optional[dict] = None):
        self.model_config = model_config or {}
        # Track usage from the last API call
        self._last_input_tokens = 0
        self._last_output_tokens = 0

    @abstractmethod
    def is_configured(self) -> bool:
        """Check if the provider's API key is configured."""
        pass

    @abstractmethod
    def stream_response(
        self, messages: list, model_id: str, thinking_config: Optional[dict] = None
    ) -> Generator[str, None, None]:
        """Stream response chunks from the LLM."""
        pass

    @abstractmethod
    def generate(
        self,
        messages: list,
        model_id: str,
        max_tokens: int = 4096,
        thinking_config: Optional[dict] = None,
    ) -> str:
        """Generate a complete (non-streaming) response from the LLM.

        Returns the full response text. Updates self._last_input_tokens
        and self._last_output_tokens for cost tracking.
        """
        pass

    @property
    @abstractmethod
    def error_types(self) -> tuple:
        """Return tuple of exception types this provider can raise."""
        pass

    @abstractmethod
    def format_error(self, error: Exception) -> str:
        """Format an error message for this provider."""
        pass

    def get_last_usage(self) -> tuple[int, int]:
        """
        Get token usage from the last API call.

        Returns:
            Tuple of (input_tokens, output_tokens)
        """
        return (self._last_input_tokens, self._last_output_tokens)


class AnthropicProvider(LLMProvider):
    """Anthropic/Claude provider implementation."""

    def is_configured(self) -> bool:
        key = getattr(settings, "ANTHROPIC_API_KEY", None)
        return bool(key) and key.startswith("sk-ant-") and not _is_placeholder(key)

    def stream_response(
        self, messages: list, model_id: str, thinking_config: Optional[dict] = None
    ) -> Generator[str, None, None]:
        client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)

        # Extract system message and convert to Anthropic format
        system_msg = next((m["content"] for m in messages if m["role"] == "system"), None)
        user_messages = [m for m in messages if m["role"] != "system"]

        kwargs = {
            "model": model_id,
            "max_tokens": 4096,
            "system": system_msg,
            "messages": user_messages,
        }
        if thinking_config:
            kwargs["thinking"] = thinking_config["thinking"]
            kwargs["max_tokens"] = thinking_config.get("max_tokens", 16384)

        with client.messages.stream(**kwargs) as stream:
            for text in stream.text_stream:
                yield text
            # Get usage after stream completes
            final_message = stream.get_final_message()
            if final_message and final_message.usage:
                self._last_input_tokens = final_message.usage.input_tokens
                self._last_output_tokens = final_message.usage.output_tokens

    def generate(
        self,
        messages: list,
        model_id: str,
        max_tokens: int = 4096,
        thinking_config: Optional[dict] = None,
    ) -> str:
        client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)
        system_msg = next((m["content"] for m in messages if m["role"] == "system"), None)
        user_messages = [m for m in messages if m["role"] != "system"]

        kwargs = {
            "model": model_id,
            "max_tokens": max_tokens,
            "system": system_msg,
            "messages": user_messages,
        }
        if thinking_config:
            kwargs["thinking"] = thinking_config["thinking"]
            kwargs["max_tokens"] = thinking_config.get("max_tokens", max_tokens)

        response = client.messages.create(**kwargs)

        if response.usage:
            self._last_input_tokens = response.usage.input_tokens
            self._last_output_tokens = response.usage.output_tokens

        return "".join(block.text for block in response.content if hasattr(block, "text"))

    @property
    def error_types(self) -> tuple:
        return (anthropic.APIConnectionError, anthropic.APIStatusError)

    def format_error(self, error: Exception) -> str:
        if isinstance(error, anthropic.APIConnectionError):
            return "Anthropic API connection error"
        if isinstance(error, anthropic.APIStatusError):
            # Check for common error types
            if error.status_code == 401:
                return "Anthropic API key is invalid. Please check your ANTHROPIC_API_KEY setting."
            if error.status_code == 403:
                return "Anthropic API access denied. Your API key may be invalid, expired, or lack permissions. Please check your ANTHROPIC_API_KEY setting."
            if error.status_code == 429:
                return "Anthropic API rate limit exceeded. Please try again later."
        return f"Anthropic API error: {str(error)}"


class OpenAIProvider(LLMProvider):
    """OpenAI provider implementation."""

    def is_configured(self) -> bool:
        key = getattr(settings, "OPENAI_API_KEY", None)
        return bool(key) and key.startswith("sk-") and not _is_placeholder(key)

    def stream_response(
        self, messages: list, model_id: str, thinking_config: Optional[dict] = None
    ) -> Generator[str, None, None]:
        client = openai.OpenAI(api_key=settings.OPENAI_API_KEY)
        kwargs = {
            "model": model_id,
            "messages": messages,
            "stream": True,
            "stream_options": {"include_usage": True},
        }
        if thinking_config and "reasoning_effort" in thinking_config:
            kwargs["extra_body"] = {"reasoning_effort": thinking_config["reasoning_effort"]}

        response = client.chat.completions.create(**kwargs)

        for chunk in response:
            # The final chunk contains usage info
            if chunk.usage:
                self._last_input_tokens = chunk.usage.prompt_tokens
                self._last_output_tokens = chunk.usage.completion_tokens
            if chunk.choices and chunk.choices[0].delta.content:
                yield chunk.choices[0].delta.content

    def generate(
        self,
        messages: list,
        model_id: str,
        max_tokens: int = 4096,
        thinking_config: Optional[dict] = None,
    ) -> str:
        client = openai.OpenAI(api_key=settings.OPENAI_API_KEY)
        # providers.py: OpenAI reasoning models (gpt-5-*) include internal reasoning
        # tokens in max_completion_tokens, so we need a much higher limit to leave
        # room for actual content output after reasoning.
        effective_max = max(max_tokens * 5, 16384)
        kwargs = {
            "model": model_id,
            "messages": messages,
            "max_completion_tokens": effective_max,
        }
        if thinking_config and "reasoning_effort" in thinking_config:
            kwargs["extra_body"] = {"reasoning_effort": thinking_config["reasoning_effort"]}

        response = client.chat.completions.create(**kwargs)

        if response.usage:
            self._last_input_tokens = response.usage.prompt_tokens
            self._last_output_tokens = response.usage.completion_tokens

        return response.choices[0].message.content or ""

    @property
    def error_types(self) -> tuple:
        return (openai.APITimeoutError, openai.APIError)

    def format_error(self, error: Exception) -> str:
        if isinstance(error, openai.APITimeoutError):
            return "OpenAI API timeout"
        if isinstance(error, openai.APIStatusError):
            if error.status_code == 401:
                return "OpenAI API key is invalid. Please check your OPENAI_API_KEY setting."
            if error.status_code == 403:
                return "OpenAI API access denied. Your API key may be invalid or lack permissions. Please check your OPENAI_API_KEY setting."
            if error.status_code == 429:
                return "OpenAI API rate limit exceeded. Please try again later."
        return f"OpenAI API error: {str(error)}"


class OpenAICompatibleProvider(LLMProvider):
    """Provider for OpenAI-compatible Chat Completions APIs.

    Supported provider-specific settings are:

    * ``base_url``: API endpoint, normally including ``/v1``.
    * ``api_key``: inline key, taking precedence over ``api_key_setting``.
    * ``api_key_setting``: Django setting containing the key. Defaults to
      ``OPENAI_COMPATIBLE_API_KEY``; there is no fallback to the hosted OpenAI
      key.
    * ``default_headers``: additional request headers.
    * ``stream_options``: defaults to ``{"include_usage": True}``; set to
      ``False`` or ``{}`` to omit them.
    * ``extra_body``: additional Chat Completions request fields.
    * ``max_tokens_parameter``: non-streaming token limit field, defaulting to
      ``max_tokens`` (some APIs use ``max_completion_tokens``).
    * ``max_tokens_multiplier``: multiply the requested non-streaming token limit
      by this value (defaults to 1).
    * ``max_tokens_minimum``: lower bound applied after multiplying the
      non-streaming limit, if set.
    * ``thinking_config``: ``reasoning_effort``, when supported; overrides the same
      field in `extra_body`.
    * ``thinking_model_id``: alternate model ID for Ask AI's thinking mode.

    Ask AI and Web Feed calls stream, so their requests do not use the
    non-streaming token-limit options. Servers need to support the configured
    Chat Completions fields; compatibility varies between implementations.

    For servers without authentication, supply a nonempty dummy key such as
    `unused-local-key`, distinct from the default value. The OpenAI SDK still
    needs a key and sends it in the Authorization header; the server must accept
    or ignore that header.
    """

    DEFAULT_API_KEY_SETTING = "OPENAI_COMPATIBLE_API_KEY"

    def _api_key_setting(self) -> str:
        return self.model_config.get("api_key_setting", self.DEFAULT_API_KEY_SETTING)

    def _api_key(self) -> Optional[str]:
        if self.model_config.get("api_key"):
            return self.model_config["api_key"]
        return getattr(settings, self._api_key_setting(), None)

    def is_configured(self) -> bool:
        key = self._api_key()
        return bool(key) and not _is_placeholder(key)

    def _client(self):
        kwargs = {"api_key": self._api_key()}
        if self.model_config.get("base_url"):
            kwargs["base_url"] = self.model_config["base_url"]
        if self.model_config.get("default_headers"):
            kwargs["default_headers"] = self.model_config["default_headers"]
        return openai.OpenAI(**kwargs)

    def _merged_extra_body(self, thinking_config: Optional[dict] = None) -> Optional[dict]:
        extra_body = dict(self.model_config.get("extra_body") or {})
        if thinking_config and "reasoning_effort" in thinking_config:
            extra_body["reasoning_effort"] = thinking_config["reasoning_effort"]
        return extra_body or None

    def _max_tokens_kwargs(self, max_tokens: int) -> dict:
        parameter = self.model_config.get("max_tokens_parameter", "max_tokens")
        multiplier = self.model_config.get("max_tokens_multiplier", 1)
        effective_max = max_tokens * multiplier
        minimum = self.model_config.get("max_tokens_minimum")
        if minimum:
            effective_max = max(effective_max, minimum)
        return {parameter: effective_max}

    def _chat_completion_kwargs(
        self,
        messages: list,
        model_id: str,
        *,
        stream: bool = False,
        max_tokens: Optional[int] = None,
        thinking_config: Optional[dict] = None,
    ) -> dict:
        kwargs = {
            "model": model_id,
            "messages": messages,
        }
        if stream:
            kwargs["stream"] = True
            stream_options = self.model_config.get(
                "stream_options",
                {"include_usage": True},
            )
            if stream_options:
                kwargs["stream_options"] = stream_options
        if max_tokens is not None:
            kwargs.update(self._max_tokens_kwargs(max_tokens))
        extra_body = self._merged_extra_body(thinking_config)
        if extra_body:
            kwargs["extra_body"] = extra_body
        return kwargs

    def stream_response(
        self, messages: list, model_id: str, thinking_config: Optional[dict] = None
    ) -> Generator[str, None, None]:
        self._last_input_tokens = 0
        self._last_output_tokens = 0
        client = self._client()
        kwargs = self._chat_completion_kwargs(
            messages,
            model_id,
            stream=True,
            thinking_config=thinking_config,
        )
        response = client.chat.completions.create(**kwargs)

        for chunk in response:
            # apps/ask_ai/providers.py: Some compatible servers omit usage entirely.
            if chunk.usage:
                self._last_input_tokens = chunk.usage.prompt_tokens
                self._last_output_tokens = chunk.usage.completion_tokens
            if chunk.choices and chunk.choices[0].delta.content:
                yield chunk.choices[0].delta.content

    def generate(
        self,
        messages: list,
        model_id: str,
        max_tokens: int = 4096,
        thinking_config: Optional[dict] = None,
    ) -> str:
        self._last_input_tokens = 0
        self._last_output_tokens = 0
        client = self._client()
        kwargs = self._chat_completion_kwargs(
            messages, model_id, max_tokens=max_tokens, thinking_config=thinking_config
        )
        response = client.chat.completions.create(**kwargs)

        if response.usage:
            self._last_input_tokens = response.usage.prompt_tokens
            self._last_output_tokens = response.usage.completion_tokens

        return response.choices[0].message.content or ""

    @property
    def error_types(self) -> tuple:
        return (openai.APITimeoutError, openai.APIError)

    def format_error(self, error: Exception) -> str:
        provider_name = self.model_config.get("vendor_display", "OpenAI-compatible")
        api_key_setting = self._api_key_setting()
        if isinstance(error, openai.APITimeoutError):
            return f"{provider_name} API timeout"
        if isinstance(error, openai.APIStatusError):
            if error.status_code == 401:
                return f"{provider_name} API key is invalid. Please check your {api_key_setting} setting."
            if error.status_code == 403:
                return f"{provider_name} API access denied. Your API key may be invalid or lack permissions. Please check your {api_key_setting} setting."
            if error.status_code == 429:
                return f"{provider_name} API rate limit exceeded. Please try again later."
        return f"{provider_name} API error: {str(error)}"


class XAIProvider(LLMProvider):
    """SpaceXSI (formerly xAI) Grok provider implementation (OpenAI-compatible API)."""

    def is_configured(self) -> bool:
        key = getattr(settings, "XAI_GROK_API_KEY", None)
        return bool(key) and key.startswith("xai-") and not _is_placeholder(key)

    def stream_response(
        self, messages: list, model_id: str, thinking_config: Optional[dict] = None
    ) -> Generator[str, None, None]:
        client = openai.OpenAI(
            api_key=settings.XAI_GROK_API_KEY,
            base_url="https://api.x.ai/v1",
        )
        response = client.chat.completions.create(
            model=model_id,
            messages=messages,
            stream=True,
            stream_options={"include_usage": True},
        )

        for chunk in response:
            # The final chunk contains usage info
            if chunk.usage:
                self._last_input_tokens = chunk.usage.prompt_tokens
                self._last_output_tokens = chunk.usage.completion_tokens
            if chunk.choices and chunk.choices[0].delta.content:
                yield chunk.choices[0].delta.content

    def generate(
        self,
        messages: list,
        model_id: str,
        max_tokens: int = 4096,
        thinking_config: Optional[dict] = None,
    ) -> str:
        client = openai.OpenAI(
            api_key=settings.XAI_GROK_API_KEY,
            base_url="https://api.x.ai/v1",
        )
        # providers.py: Use higher limit like OpenAI to handle potential reasoning models
        effective_max = max(max_tokens * 5, 16384)
        response = client.chat.completions.create(
            model=model_id,
            messages=messages,
            max_completion_tokens=effective_max,
        )

        if response.usage:
            self._last_input_tokens = response.usage.prompt_tokens
            self._last_output_tokens = response.usage.completion_tokens

        return response.choices[0].message.content or ""

    @property
    def error_types(self) -> tuple:
        return (openai.APITimeoutError, openai.APIError)

    def format_error(self, error: Exception) -> str:
        if isinstance(error, openai.APITimeoutError):
            return "SpaceXSI API timeout"
        if isinstance(error, openai.APIStatusError):
            if error.status_code == 401:
                return "SpaceXSI API key is invalid. Please check your XAI_GROK_API_KEY setting."
            if error.status_code == 403:
                return "SpaceXSI API access denied. The account may be out of credits, or your API key may be invalid or lack permissions. Please check your XAI_GROK_API_KEY setting."
            if error.status_code == 429:
                return "SpaceXSI API rate limit exceeded. Please try again later."
        return f"SpaceXSI API error: {str(error)}"


class GeminiProvider(LLMProvider):
    """Google Gemini provider implementation."""

    def is_configured(self) -> bool:
        key = getattr(settings, "GOOGLE_GEMINI_API_KEY", None)
        return bool(key) and len(key) > 20 and not _is_placeholder(key)

    def stream_response(
        self, messages: list, model_id: str, thinking_config: Optional[dict] = None
    ) -> Generator[str, None, None]:
        client = genai.Client(api_key=settings.GOOGLE_GEMINI_API_KEY)

        # Extract system message for config
        system_msg = next((m["content"] for m in messages if m["role"] == "system"), None)
        config_kwargs = {}
        if system_msg:
            config_kwargs["system_instruction"] = system_msg
        if thinking_config:
            config_kwargs["thinking_config"] = genai_types.ThinkingConfig(
                thinking_budget=thinking_config.get("thinking_budget", -1)
            )
        config = genai_types.GenerateContentConfig(**config_kwargs) if config_kwargs else None

        # Convert messages to Gemini format (user/model roles, not assistant)
        contents = []
        for m in messages:
            if m["role"] == "system":
                continue
            role = "model" if m["role"] == "assistant" else m["role"]
            contents.append(
                genai_types.Content(role=role, parts=[genai_types.Part.from_text(text=m["content"])])
            )

        response = client.models.generate_content_stream(model=model_id, contents=contents, config=config)

        last_chunk = None
        for chunk in response:
            last_chunk = chunk
            if chunk.text:
                yield chunk.text

        # Get usage from the last chunk's usage_metadata
        if last_chunk and hasattr(last_chunk, "usage_metadata") and last_chunk.usage_metadata:
            usage = last_chunk.usage_metadata
            self._last_input_tokens = getattr(usage, "prompt_token_count", 0) or 0
            self._last_output_tokens = getattr(usage, "candidates_token_count", 0) or 0

    def generate(
        self,
        messages: list,
        model_id: str,
        max_tokens: int = 4096,
        thinking_config: Optional[dict] = None,
    ) -> str:
        client = genai.Client(api_key=settings.GOOGLE_GEMINI_API_KEY)

        system_msg = next((m["content"] for m in messages if m["role"] == "system"), None)
        config_kwargs = {}
        if system_msg:
            config_kwargs["system_instruction"] = system_msg
        config_kwargs["max_output_tokens"] = max_tokens
        if thinking_config:
            config_kwargs["thinking_config"] = genai_types.ThinkingConfig(
                thinking_budget=thinking_config.get("thinking_budget", -1)
            )
        config = genai_types.GenerateContentConfig(**config_kwargs)

        contents = []
        for m in messages:
            if m["role"] == "system":
                continue
            role = "model" if m["role"] == "assistant" else m["role"]
            contents.append(
                genai_types.Content(role=role, parts=[genai_types.Part.from_text(text=m["content"])])
            )

        response = client.models.generate_content(model=model_id, contents=contents, config=config)

        if hasattr(response, "usage_metadata") and response.usage_metadata:
            self._last_input_tokens = getattr(response.usage_metadata, "prompt_token_count", 0) or 0
            self._last_output_tokens = getattr(response.usage_metadata, "candidates_token_count", 0) or 0

        return response.text or ""

    @property
    def error_types(self) -> tuple:
        return (genai_errors.APIError,)

    def format_error(self, error: Exception) -> str:
        if isinstance(error, genai_errors.ServerError):
            return "Google API server error"
        if isinstance(error, genai_errors.ClientError):
            return f"Google API client error: {str(error)}"
        return f"Google API error: {str(error)}"


# All LLM provider exception types for catching in task code
LLM_EXCEPTIONS = (
    anthropic.APIConnectionError,
    anthropic.APIStatusError,
    openai.APITimeoutError,
    openai.APIError,
    genai_errors.APIError,
)


def is_refused_llm_error(error):
    """
    Did the provider refuse to serve the account: a bad key, no credits left, a spending
    limit, or a rate limit? Retrying the same provider won't help, but another one can.
    SpaceXSI (formerly xAI) answers 403 once its credits run out. apps/ask_ai/providers.py
    """
    status_code = getattr(error, "status_code", None)
    if status_code is None:
        # providers.py: google-genai reports the HTTP status as `code` instead
        status_code = getattr(error, "code", None)
    return status_code in (401, 402, 403, 429)


# Provider classes by vendor slug, used for settings override resolution
PROVIDER_CLASSES = {
    "anthropic": AnthropicProvider,
    "openai": OpenAIProvider,
    "openai_compatible": OpenAICompatibleProvider,
    "google": GeminiProvider,
    "xai": XAIProvider,
}

OPENAI_COMPAT_CONFIG_KEYS = (
    "api_key",
    "api_key_setting",
    "base_url",
    "default_headers",
    "stream_options",
    "max_tokens_parameter",
    "max_tokens_multiplier",
    "max_tokens_minimum",
    "extra_body",
)


def _copy_openai_compat_config(entry: dict, cfg: dict):
    if entry.get("provider_class") != OpenAICompatibleProvider:
        return
    for config_key in OPENAI_COMPAT_CONFIG_KEYS:
        if config_key in cfg:
            entry[config_key] = cfg[config_key]


# Model registry: single source of truth for all model configuration.
# Registry keys are stable vendor slugs so model upgrades never rename keys —
# to upgrade a model, only change the IDs/display names in utils/llm_models.py.
# Frontend dropdowns are populated from this dict.
_DEFAULT_MODELS = {
    "anthropic": {
        "provider_class": AnthropicProvider,
        "model_id": ANTHROPIC_CHAT_MODEL,
        "display_name": ANTHROPIC_CHAT_MODEL_DISPLAY,
        "vendor": "anthropic",
        "vendor_display": "Anthropic",
        "order": 1,
        # Claude 5 models reject the old {"type": "enabled", "budget_tokens": N}
        # shape with a 400 — adaptive is the only on-mode, with depth controlled
        # by output_config.effort (defaults to "high" when omitted).
        "thinking_config": {
            "thinking": {"type": "adaptive"},
            "max_tokens": 16384,
        },
    },
    "openai": {
        "provider_class": OpenAIProvider,
        "model_id": OPENAI_MODEL,
        "display_name": OPENAI_MODEL_DISPLAY,
        "vendor": "openai",
        "vendor_display": "OpenAI",
        "order": 2,
        "thinking_config": {
            "reasoning_effort": "high",
        },
    },
    "google": {
        "provider_class": GeminiProvider,
        "model_id": GOOGLE_MODEL,
        "display_name": GOOGLE_MODEL_DISPLAY,
        "vendor": "google",
        "vendor_display": "Google",
        "order": 3,
        "thinking_config": {
            "thinking_budget": -1,
        },
    },
    "xai": {
        "provider_class": XAIProvider,
        "model_id": XAI_MODEL,
        "display_name": XAI_MODEL_DISPLAY,
        "vendor": "xai",
        "vendor_display": "SpaceXSI",
        "order": 4,
    },
}

# Legacy registry keys from before keys became vendor slugs (Aug 2026). Old
# mobile clients and stored user preferences still send these — resolve them
# instead of falling back to the default model. Never reuse these as new keys.
MODEL_ALIASES = {
    # Legacy Ask AI keys
    "opus": "anthropic",
    "gpt-5.2": "openai",
    "gemini-3": "google",
    "grok-4.1": "xai",
    # Legacy briefing keys
    # providers.py: "haiku" users picked the cheap Anthropic tier back when the
    # briefing's Claude option was Haiku. The "anthropic" registry entry is now
    # Sonnet-class (chat tier), so route them to the cheap default (Luna)
    # instead of silently upgrading them to a ~20x more expensive model.
    "haiku": "openai",
    "gpt-5-mini": "openai",
    "gemini-flash-lite": "google",
    "grok-4.1-fast": "xai",
}


def _resolve_key(model_name, registry):
    """Resolve a model key against a registry, mapping legacy keys via MODEL_ALIASES."""
    if model_name in registry:
        return model_name
    return MODEL_ALIASES.get(model_name, model_name)


def _load_models():
    """Load models, applying settings override if ASK_AI_MODELS is defined.

    Self-hosters can define ASK_AI_MODELS in settings as a dict of model configs:
        ASK_AI_MODELS = {
            "my-model": {
                "provider": "openai",  # one of: anthropic, openai, google, xai
                "model_id": "gpt-4o-mini",
                "display_name": "GPT-4o Mini",
                "order": 1,
            },
        }
    """
    custom = getattr(settings, "ASK_AI_MODELS", None)
    if not custom:
        return _DEFAULT_MODELS

    models = {}
    for key, cfg in custom.items():
        provider_slug = cfg.get("provider", cfg.get("vendor", ""))
        provider_class = PROVIDER_CLASSES.get(provider_slug)
        if not provider_class:
            continue
        entry = {
            "provider_class": provider_class,
            "model_id": cfg["model_id"],
            "display_name": cfg.get("display_name", key),
            "vendor": cfg.get("vendor", provider_slug),
            "vendor_display": cfg.get("vendor_display", cfg.get("vendor", provider_slug).title()),
            "order": cfg.get("order", 99),
        }
        if "thinking_config" in cfg:
            entry["thinking_config"] = cfg["thinking_config"]
        if "thinking_model_id" in cfg:
            entry["thinking_model_id"] = cfg["thinking_model_id"]
        _copy_openai_compat_config(entry, cfg)
        models[key] = entry
    return models if models else _DEFAULT_MODELS


MODELS = _load_models()
VALID_MODELS = list(MODELS.keys())
DEFAULT_MODEL = _resolve_key(getattr(settings, "ASK_AI_MODEL", "anthropic"), MODELS)

# MODEL_VENDORS includes both current and historical models for metrics tracking.
# When retiring a model, remove it from MODELS above but keep it here.
MODEL_VENDORS = {
    **{key: m["vendor"] for key, m in MODELS.items()},
    # Historical models (kept for metrics)
    "opus": "anthropic",
    "haiku": "anthropic",
    "gpt-5.2": "openai",
    "gpt-5-mini": "openai",
    "gpt-5.1": "openai",
    "gpt-4.1": "openai",
    "gemini-3": "google",
    "gemini-flash-lite": "google",
    "grok-4.1": "xai",
    "grok-4.1-fast": "xai",
    "grok-4": "xai",
}


def get_models_for_frontend() -> list:
    """Get model list for frontend JavaScript consumption.

    Returns a sorted list of dicts with key, display_name, vendor, vendor_display.
    Passed to the frontend via the template tag pipeline as NEWSBLUR.Globals.ask_ai_models.
    """
    return sorted(
        [
            {
                "key": key,
                "display_name": m["display_name"],
                "vendor": m["vendor"],
                "vendor_display": m["vendor_display"],
            }
            for key, m in MODELS.items()
        ],
        key=lambda x: MODELS[x["key"]].get("order", 99),
    )


def get_provider(model_name: str, thinking: bool = False) -> tuple[LLMProvider, str, Optional[dict]]:
    """
    Get a provider instance, model ID, and optional thinking config for the given model name.

    Returns:
        Tuple of (provider_instance, model_id, thinking_config)
    """
    model_name = _resolve_key(model_name, MODELS)
    if model_name not in MODELS:
        model_name = DEFAULT_MODEL

    model = MODELS[model_name]
    if thinking:
        model_id = model.get("thinking_model_id", model["model_id"])
        thinking_config = model.get("thinking_config")
    else:
        model_id = model["model_id"]
        thinking_config = None
    return model["provider_class"](model), model_id, thinking_config


# Briefing model registry: keys are the same stable vendor slugs as the Ask AI
# registry. Anthropic uses the chat tier (Sonnet-class) from utils/llm_models.py
# to match Ask AI; the other vendors stay on their cheap models.
_DEFAULT_BRIEFING_MODELS = {
    "anthropic": {
        "provider_class": AnthropicProvider,
        "model_id": ANTHROPIC_CHAT_MODEL,
        "display_name": ANTHROPIC_CHAT_MODEL_DISPLAY,
        "vendor": "anthropic",
        "vendor_display": "Anthropic",
        "order": 1,
    },
    "openai": {
        "provider_class": OpenAIProvider,
        "model_id": OPENAI_MODEL,
        "display_name": OPENAI_MODEL_DISPLAY,
        "vendor": "openai",
        "vendor_display": "OpenAI",
        "order": 2,
        "thinking_config": {
            "reasoning_effort": "medium",
        },
    },
    "google": {
        "provider_class": GeminiProvider,
        "model_id": GOOGLE_MODEL,
        "display_name": GOOGLE_MODEL_DISPLAY,
        "vendor": "google",
        "vendor_display": "Google",
        "order": 3,
    },
    "xai": {
        "provider_class": XAIProvider,
        "model_id": XAI_MODEL,
        "display_name": XAI_MODEL_DISPLAY,
        "vendor": "xai",
        "vendor_display": "SpaceXSI",
        "order": 4,
    },
}


def _load_briefing_models():
    """Load briefing models, applying settings override if BRIEFING_MODELS is defined.

    Self-hosters can define BRIEFING_MODELS in settings as a dict of model configs:
        BRIEFING_MODELS = {
            "my-model": {
                "provider": "openai",
                "model_id": "gpt-4o-mini",
                "display_name": "GPT-4o Mini",
                "order": 1,
            },
        }
    """
    custom = getattr(settings, "BRIEFING_MODELS", None)
    if not custom:
        return _DEFAULT_BRIEFING_MODELS

    models = {}
    for key, cfg in custom.items():
        provider_slug = cfg.get("provider", cfg.get("vendor", ""))
        provider_class = PROVIDER_CLASSES.get(provider_slug)
        if not provider_class:
            continue
        entry = {
            "provider_class": provider_class,
            "model_id": cfg["model_id"],
            "display_name": cfg.get("display_name", key),
            "vendor": cfg.get("vendor", provider_slug),
            "vendor_display": cfg.get("vendor_display", cfg.get("vendor", provider_slug).title()),
            "order": cfg.get("order", 99),
        }
        if "thinking_config" in cfg:
            entry["thinking_config"] = cfg["thinking_config"]
        if "thinking_model_id" in cfg:
            entry["thinking_model_id"] = cfg["thinking_model_id"]
        _copy_openai_compat_config(entry, cfg)
        models[key] = entry
    return models if models else _DEFAULT_BRIEFING_MODELS


BRIEFING_MODELS = _load_briefing_models()
VALID_BRIEFING_MODELS = list(BRIEFING_MODELS.keys())


def _valid_registry_default(model_name, registry, fallback="openai"):
    model_name = _resolve_key(model_name, registry)
    if model_name in registry:
        return model_name
    if fallback in registry:
        return fallback
    return next(iter(registry))


DEFAULT_BRIEFING_MODEL = _valid_registry_default(
    getattr(settings, "BRIEFING_MODEL", "openai"), BRIEFING_MODELS
)
DEFAULT_WEBFEED_MODEL = _valid_registry_default(getattr(settings, "WEBFEED_MODEL", "openai"), BRIEFING_MODELS)


def resolve_briefing_model_key(model_name: Optional[str]) -> Optional[str]:
    """Resolve a stored/POSTed briefing model key to a current registry key.

    Maps legacy keys via MODEL_ALIASES (e.g. "haiku" -> "openai", the cheap
    tier its users originally chose; "gpt-5-mini" -> "openai"). Returns None
    when the key isn't recognized so callers can fall back to the server default.
    """
    if not model_name:
        return None
    model_name = _resolve_key(model_name, BRIEFING_MODELS)
    return model_name if model_name in BRIEFING_MODELS else None


def get_briefing_models_for_frontend() -> list:
    """Get briefing model list for frontend JavaScript consumption.

    Returns a sorted list of dicts with key, display_name, vendor, vendor_display.
    """
    return sorted(
        [
            {
                "key": key,
                "display_name": m["display_name"],
                "vendor": m["vendor"],
                "vendor_display": m["vendor_display"],
            }
            for key, m in BRIEFING_MODELS.items()
        ],
        key=lambda x: BRIEFING_MODELS[x["key"]].get("order", 99),
    )


def get_briefing_model_config(model_name: Optional[str]) -> tuple[str, dict]:
    """Return the resolved briefing model key and config, falling back to the server default."""
    model_name = resolve_briefing_model_key(model_name) or DEFAULT_BRIEFING_MODEL
    if model_name not in BRIEFING_MODELS:
        model_name = _valid_registry_default(model_name, BRIEFING_MODELS)
    return model_name, BRIEFING_MODELS[model_name]


def get_briefing_provider(model_name: str) -> tuple[LLMProvider, str]:
    """Get a provider instance and model ID for the given briefing model name."""
    _, model = get_briefing_model_config(model_name)
    return model["provider_class"](model), model["model_id"]
