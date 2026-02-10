from abc import ABC, abstractmethod
from typing import Generator, Optional

import anthropic
import openai
from django.conf import settings

from utils import log as logging
from google import genai
from google.genai import errors as genai_errors
from google.genai import types as genai_types


class LLMProvider(ABC):
    """Abstract base class for LLM providers."""

    def __init__(self):
        # Track usage from the last API call
        self._last_input_tokens = 0
        self._last_output_tokens = 0

    @abstractmethod
    def is_configured(self) -> bool:
        """Check if the provider's API key is configured."""
        pass

    @abstractmethod
    def stream_response(self, messages: list, model_id: str, thinking_config: Optional[dict] = None) -> Generator[str, None, None]:
        """Stream response chunks from the LLM."""
        pass

    @abstractmethod
    def generate(self, messages: list, model_id: str, max_tokens: int = 4096) -> str:
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
        return bool(getattr(settings, "ANTHROPIC_API_KEY", None))

    def stream_response(self, messages: list, model_id: str, thinking_config: Optional[dict] = None) -> Generator[str, None, None]:
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

    def generate(self, messages: list, model_id: str, max_tokens: int = 4096) -> str:
        client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)
        system_msg = next((m["content"] for m in messages if m["role"] == "system"), None)
        user_messages = [m for m in messages if m["role"] != "system"]

        response = client.messages.create(
            model=model_id,
            max_tokens=max_tokens,
            system=system_msg,
            messages=user_messages,
        )

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
        return bool(getattr(settings, "OPENAI_API_KEY", None))

    def stream_response(self, messages: list, model_id: str, thinking_config: Optional[dict] = None) -> Generator[str, None, None]:
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

    def generate(self, messages: list, model_id: str, max_tokens: int = 4096) -> str:
        client = openai.OpenAI(api_key=settings.OPENAI_API_KEY)
        # providers.py: OpenAI reasoning models (gpt-5-*) include internal reasoning
        # tokens in max_completion_tokens, so we need a much higher limit to leave
        # room for actual content output after reasoning.
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
            return "OpenAI API timeout"
        if isinstance(error, openai.APIStatusError):
            if error.status_code == 401:
                return "OpenAI API key is invalid. Please check your OPENAI_API_KEY setting."
            if error.status_code == 403:
                return "OpenAI API access denied. Your API key may be invalid or lack permissions. Please check your OPENAI_API_KEY setting."
            if error.status_code == 429:
                return "OpenAI API rate limit exceeded. Please try again later."
        return f"OpenAI API error: {str(error)}"


class XAIProvider(LLMProvider):
    """xAI/Grok provider implementation (OpenAI-compatible API)."""

    def is_configured(self) -> bool:
        return bool(getattr(settings, "XAI_GROK_API_KEY", None))

    def stream_response(self, messages: list, model_id: str, thinking_config: Optional[dict] = None) -> Generator[str, None, None]:
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

    def generate(self, messages: list, model_id: str, max_tokens: int = 4096) -> str:
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
            return "xAI API timeout"
        if isinstance(error, openai.APIStatusError):
            if error.status_code == 401:
                return "xAI API key is invalid. Please check your XAI_GROK_API_KEY setting."
            if error.status_code == 403:
                return "xAI API access denied. Your API key may be invalid or lack permissions. Please check your XAI_GROK_API_KEY setting."
            if error.status_code == 429:
                return "xAI API rate limit exceeded. Please try again later."
        return f"xAI API error: {str(error)}"


class GeminiProvider(LLMProvider):
    """Google Gemini provider implementation."""

    def is_configured(self) -> bool:
        return bool(getattr(settings, "GOOGLE_GEMINI_API_KEY", None))

    def stream_response(self, messages: list, model_id: str, thinking_config: Optional[dict] = None) -> Generator[str, None, None]:
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

    def generate(self, messages: list, model_id: str, max_tokens: int = 4096) -> str:
        client = genai.Client(api_key=settings.GOOGLE_GEMINI_API_KEY)

        system_msg = next((m["content"] for m in messages if m["role"] == "system"), None)
        config_kwargs = {}
        if system_msg:
            config_kwargs["system_instruction"] = system_msg
        config_kwargs["max_output_tokens"] = max_tokens
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

# Provider classes by vendor slug, used for settings override resolution
PROVIDER_CLASSES = {
    "anthropic": AnthropicProvider,
    "openai": OpenAIProvider,
    "google": GeminiProvider,
    "xai": XAIProvider,
}

# Model registry: single source of truth for all model configuration.
# Each entry contains everything needed by both backend and frontend.
# To add/update a model, only change this dict — frontend dropdowns are populated from it.
_DEFAULT_MODELS = {
    "opus": {
        "provider_class": AnthropicProvider,
        "model_id": "claude-opus-4-6",
        "display_name": "Claude Opus 4.6",
        "vendor": "anthropic",
        "vendor_display": "Anthropic",
        "order": 1,
        "thinking_config": {
            "thinking": {"type": "enabled", "budget_tokens": 10000},
            "max_tokens": 16384,
        },
    },
    "gpt-5.2": {
        "provider_class": OpenAIProvider,
        "model_id": "gpt-5.2",
        "display_name": "GPT 5.2",
        "vendor": "openai",
        "vendor_display": "OpenAI",
        "order": 2,
        "thinking_config": {
            "reasoning_effort": "high",
        },
    },
    "gemini-3": {
        "provider_class": GeminiProvider,
        "model_id": "gemini-3-pro-preview",
        "display_name": "Gemini 3 Pro",
        "vendor": "google",
        "vendor_display": "Google",
        "order": 3,
        "thinking_config": {
            "thinking_budget": -1,
        },
    },
    "grok-4.1": {
        "provider_class": XAIProvider,
        "model_id": "grok-4-1-fast-non-reasoning",
        "display_name": "Grok 4.1 Fast",
        "vendor": "xai",
        "vendor_display": "xAI",
        "order": 4,
        "thinking_model_id": "grok-4-1-fast-reasoning",
    },
}


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
            "vendor": provider_slug,
            "vendor_display": cfg.get("vendor_display", provider_slug.title()),
            "order": cfg.get("order", 99),
        }
        if "thinking_config" in cfg:
            entry["thinking_config"] = cfg["thinking_config"]
        if "thinking_model_id" in cfg:
            entry["thinking_model_id"] = cfg["thinking_model_id"]
        models[key] = entry
    return models if models else _DEFAULT_MODELS


MODELS = _load_models()
VALID_MODELS = list(MODELS.keys())
DEFAULT_MODEL = getattr(settings, "ASK_AI_MODEL", "opus")

# MODEL_VENDORS includes both current and historical models for metrics tracking.
# When retiring a model, remove it from MODELS above but keep it here.
MODEL_VENDORS = {
    **{key: m["vendor"] for key, m in MODELS.items()},
    # Historical models (kept for metrics)
    "gpt-5.1": "openai",
    "gpt-4.1": "openai",
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
    if model_name not in MODELS:
        model_name = DEFAULT_MODEL

    model = MODELS[model_name]
    if thinking:
        model_id = model.get("thinking_model_id", model["model_id"])
        thinking_config = model.get("thinking_config")
    else:
        model_id = model["model_id"]
        thinking_config = None
    return model["provider_class"](), model_id, thinking_config


# Briefing model registry: cheap models optimized for daily briefing generation.
# Separate from the Ask AI models (which use flagship models).
_DEFAULT_BRIEFING_MODELS = {
    "haiku": {
        "provider_class": AnthropicProvider,
        "model_id": "claude-haiku-4-5",
        "display_name": "Claude Haiku",
        "vendor": "anthropic",
        "vendor_display": "Anthropic",
        "order": 1,
    },
    "gpt-5-mini": {
        "provider_class": OpenAIProvider,
        "model_id": "gpt-5-mini",
        "display_name": "GPT 5 Mini",
        "vendor": "openai",
        "vendor_display": "OpenAI",
        "order": 2,
    },
    "gemini-flash-lite": {
        "provider_class": GeminiProvider,
        "model_id": "gemini-2.5-flash-lite",
        "display_name": "Gemini Flash Lite",
        "vendor": "google",
        "vendor_display": "Google",
        "order": 3,
    },
    "grok-4.1-fast": {
        "provider_class": XAIProvider,
        "model_id": "grok-4-1-fast-non-reasoning",
        "display_name": "Grok 4.1 Fast",
        "vendor": "xai",
        "vendor_display": "xAI",
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
        models[key] = {
            "provider_class": provider_class,
            "model_id": cfg["model_id"],
            "display_name": cfg.get("display_name", key),
            "vendor": provider_slug,
            "vendor_display": cfg.get("vendor_display", provider_slug.title()),
            "order": cfg.get("order", 99),
        }
    return models if models else _DEFAULT_BRIEFING_MODELS


BRIEFING_MODELS = _load_briefing_models()
VALID_BRIEFING_MODELS = list(BRIEFING_MODELS.keys())
DEFAULT_BRIEFING_MODEL = getattr(settings, "BRIEFING_MODEL", "haiku")


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


def get_briefing_provider(model_name: str) -> tuple[LLMProvider, str]:
    """Get a provider instance and model ID for the given briefing model name."""
    if not model_name or model_name not in BRIEFING_MODELS:
        model_name = DEFAULT_BRIEFING_MODEL
    model = BRIEFING_MODELS[model_name]
    return model["provider_class"](), model["model_id"]
