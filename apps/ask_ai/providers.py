from abc import ABC, abstractmethod
from typing import Generator

import anthropic
import openai
from django.conf import settings
from google import genai
from google.genai import errors as genai_errors
from google.genai import types as genai_types


class LLMProvider(ABC):
    """Abstract base class for LLM providers."""

    @abstractmethod
    def is_configured(self) -> bool:
        """Check if the provider's API key is configured."""
        pass

    @abstractmethod
    def stream_response(self, messages: list, model_id: str) -> Generator[str, None, None]:
        """Stream response chunks from the LLM."""
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


class AnthropicProvider(LLMProvider):
    """Anthropic/Claude provider implementation."""

    def is_configured(self) -> bool:
        return bool(getattr(settings, "ANTHROPIC_API_KEY", None))

    def stream_response(self, messages: list, model_id: str) -> Generator[str, None, None]:
        client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)

        # Extract system message and convert to Anthropic format
        system_msg = next((m["content"] for m in messages if m["role"] == "system"), None)
        user_messages = [m for m in messages if m["role"] != "system"]

        with client.messages.stream(
            model=model_id,
            max_tokens=4096,
            system=system_msg,
            messages=user_messages,
        ) as stream:
            for text in stream.text_stream:
                yield text

    @property
    def error_types(self) -> tuple:
        return (anthropic.APIConnectionError, anthropic.APIStatusError)

    def format_error(self, error: Exception) -> str:
        if isinstance(error, anthropic.APIConnectionError):
            return "Anthropic API connection error"
        return f"Anthropic API error: {str(error)}"


class OpenAIProvider(LLMProvider):
    """OpenAI provider implementation."""

    def is_configured(self) -> bool:
        return bool(getattr(settings, "OPENAI_API_KEY", None))

    def stream_response(self, messages: list, model_id: str) -> Generator[str, None, None]:
        client = openai.OpenAI(api_key=settings.OPENAI_API_KEY)
        response = client.chat.completions.create(model=model_id, messages=messages, stream=True)

        for chunk in response:
            if chunk.choices[0].delta.content:
                yield chunk.choices[0].delta.content

    @property
    def error_types(self) -> tuple:
        return (openai.APITimeoutError, openai.APIError)

    def format_error(self, error: Exception) -> str:
        if isinstance(error, openai.APITimeoutError):
            return "OpenAI API timeout"
        return f"OpenAI API error: {str(error)}"


class XAIProvider(LLMProvider):
    """xAI/Grok provider implementation (OpenAI-compatible API)."""

    def is_configured(self) -> bool:
        return bool(getattr(settings, "XAI_GROK_API_KEY", None))

    def stream_response(self, messages: list, model_id: str) -> Generator[str, None, None]:
        client = openai.OpenAI(
            api_key=settings.XAI_GROK_API_KEY,
            base_url="https://api.x.ai/v1",
        )
        response = client.chat.completions.create(model=model_id, messages=messages, stream=True)

        for chunk in response:
            if chunk.choices[0].delta.content:
                yield chunk.choices[0].delta.content

    @property
    def error_types(self) -> tuple:
        return (openai.APITimeoutError, openai.APIError)

    def format_error(self, error: Exception) -> str:
        if isinstance(error, openai.APITimeoutError):
            return "xAI API timeout"
        return f"xAI API error: {str(error)}"


class GeminiProvider(LLMProvider):
    """Google Gemini provider implementation."""

    def is_configured(self) -> bool:
        return bool(getattr(settings, "GOOGLE_GEMINI_API_KEY", None))

    def stream_response(self, messages: list, model_id: str) -> Generator[str, None, None]:
        client = genai.Client(api_key=settings.GOOGLE_GEMINI_API_KEY)

        # Extract system message for config
        system_msg = next((m["content"] for m in messages if m["role"] == "system"), None)
        config = genai_types.GenerateContentConfig(system_instruction=system_msg) if system_msg else None

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

        for chunk in response:
            if chunk.text:
                yield chunk.text

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

# Model registry: maps friendly names to (provider_class, model_id)
# Only top-tier models per provider
MODELS = {
    "opus": (AnthropicProvider, "claude-opus-4-5-20251101"),
    "gpt-5.1": (OpenAIProvider, "gpt-5.1"),
    "gemini-3": (GeminiProvider, "gemini-3-pro-preview"),
    "grok-4.1": (XAIProvider, "grok-4-1-fast-non-reasoning"),
}

VALID_MODELS = list(MODELS.keys())
DEFAULT_MODEL = "opus"
MODEL_VENDORS = {
    "opus": "anthropic",
    "gpt-5.1": "openai",
    "gemini-3": "google",
    "grok-4.1": "xai",
}


def get_provider(model_name: str) -> tuple[LLMProvider, str]:
    """
    Get a provider instance and model ID for the given model name.

    Returns:
        Tuple of (provider_instance, model_id)
    """
    if model_name not in MODELS:
        model_name = DEFAULT_MODEL

    provider_class, model_id = MODELS[model_name]
    return provider_class(), model_id
