"""
LLM Cost Tracking Utility.

Provides a centralized interface for recording and calculating LLM API costs
across all AI features in NewsBlur.

Usage:
    from utils.llm_costs import LLMCostTracker

    # Record usage after an API call
    LLMCostTracker.record_usage(
        provider="anthropic",
        model="claude-sonnet-4-20250514",
        feature="archive_assistant",
        input_tokens=1000,
        output_tokens=500,
        user_id=123,
        metadata={"tool_calls": 3}
    )

    # Calculate cost without recording
    cost = LLMCostTracker.calculate_cost("claude-sonnet-4-20250514", 1000, 500)
"""

from utils import log as logging

# Model pricing per 1M tokens (USD)
# Sources (Jan 2026):
# - Anthropic: https://platform.claude.com/docs/en/about-claude/pricing
# - OpenAI: https://openai.com/api/pricing/
# - Google: https://ai.google.dev/gemini-api/docs/pricing
# - xAI: https://docs.x.ai/docs/models
MODEL_PRICING = {
    # Anthropic Claude models (full IDs and short aliases)
    "claude-opus-4-6": {"input": 5.00, "output": 25.00},
    "claude-opus-4-5-20251101": {"input": 5.00, "output": 25.00},
    "claude-opus-4-5": {"input": 5.00, "output": 25.00},
    "claude-sonnet-4-20250514": {"input": 3.00, "output": 15.00},
    "claude-sonnet-4": {"input": 3.00, "output": 15.00},
    "claude-sonnet-4-5-20251022": {"input": 3.00, "output": 15.00},
    "claude-sonnet-4-5": {"input": 3.00, "output": 15.00},
    "claude-haiku-4-5-20251022": {"input": 1.00, "output": 5.00},
    "claude-haiku-4-5": {"input": 1.00, "output": 5.00},
    # OpenAI GPT models
    "gpt-5.2": {"input": 2.00, "output": 8.00},
    "gpt-5-mini": {"input": 0.30, "output": 1.20},
    "gpt-5-nano": {"input": 0.05, "output": 0.40},
    "gpt-5.1": {"input": 1.25, "output": 10.00},
    "gpt-5": {"input": 1.25, "output": 10.00},
    "gpt-4.1": {"input": 2.00, "output": 8.00},
    "gpt-4o": {"input": 2.50, "output": 10.00},
    "gpt-4o-mini": {"input": 0.15, "output": 0.60},
    "gpt-3.5-turbo": {"input": 0.50, "output": 1.50},
    # OpenAI Whisper (per minute, not per token)
    "whisper-1": {"per_minute": 0.006},
    # OpenAI Embedding models (input only, no output)
    "text-embedding-3-small": {"input": 0.02, "output": 0.0},
    "text-embedding-3-large": {"input": 0.13, "output": 0.0},
    "text-embedding-ada-002": {"input": 0.10, "output": 0.0},
    # Google Gemini models
    "gemini-3-pro-preview": {"input": 2.00, "output": 12.00},
    "gemini-2.5-pro": {"input": 1.25, "output": 10.00},
    "gemini-2.5-flash": {"input": 0.10, "output": 0.40},
    "gemini-2.5-flash-lite": {"input": 0.10, "output": 0.40},
    # xAI Grok models
    "grok-4-1-fast-non-reasoning": {"input": 0.20, "output": 0.50},
    "grok-4": {"input": 3.00, "output": 15.00},
    "grok-3-beta": {"input": 3.00, "output": 15.00},
}

# Provider mapping for models (full IDs and short aliases)
MODEL_PROVIDERS = {
    "claude-opus-4-6": "anthropic",
    "claude-opus-4-5-20251101": "anthropic",
    "claude-opus-4-5": "anthropic",
    "claude-sonnet-4-20250514": "anthropic",
    "claude-sonnet-4": "anthropic",
    "claude-sonnet-4-5-20251022": "anthropic",
    "claude-sonnet-4-5": "anthropic",
    "claude-haiku-4-5-20251022": "anthropic",
    "claude-haiku-4-5": "anthropic",
    "gpt-5.2": "openai",
    "gpt-5-mini": "openai",
    "gpt-5-nano": "openai",
    "gpt-5.1": "openai",
    "gpt-5": "openai",
    "gpt-4.1": "openai",
    "gpt-4o": "openai",
    "gpt-4o-mini": "openai",
    "gpt-3.5-turbo": "openai",
    "whisper-1": "openai",
    "text-embedding-3-small": "openai",
    "text-embedding-3-large": "openai",
    "text-embedding-ada-002": "openai",
    "gemini-3-pro-preview": "google",
    "gemini-2.5-pro": "google",
    "gemini-2.5-flash": "google",
    "gemini-2.5-flash-lite": "google",
    "grok-4-1-fast-non-reasoning": "xai",
    "grok-4": "xai",
    "grok-3-beta": "xai",
}


class LLMCostTracker:
    """
    Utility class for tracking LLM API costs.

    All methods are class methods for easy access without instantiation.
    """

    @classmethod
    def calculate_cost(cls, model, input_tokens=0, output_tokens=0, duration_minutes=0):
        """
        Calculate the cost for a given model and token counts.

        Args:
            model: Model identifier (e.g., "claude-sonnet-4-20250514")
            input_tokens: Number of input tokens
            output_tokens: Number of output tokens
            duration_minutes: For audio models like Whisper, the duration in minutes

        Returns:
            Cost in USD (float)
        """
        pricing = MODEL_PRICING.get(model)
        if not pricing:
            logging.warning(f"Unknown model for pricing: {model}")
            return 0.0

        # Handle audio models (charged per minute)
        if "per_minute" in pricing:
            return duration_minutes * pricing["per_minute"]

        # Handle text models (charged per token)
        input_cost = (input_tokens / 1_000_000) * pricing.get("input", 0)
        output_cost = (output_tokens / 1_000_000) * pricing.get("output", 0)

        return input_cost + output_cost

    @classmethod
    def get_provider(cls, model):
        """
        Get the provider name for a given model.

        Args:
            model: Model identifier

        Returns:
            Provider name (anthropic, openai, google, xai) or "unknown"
        """
        return MODEL_PROVIDERS.get(model, "unknown")

    @classmethod
    def record_usage(
        cls,
        provider,
        model,
        feature,
        input_tokens=0,
        output_tokens=0,
        duration_minutes=0,
        user_id=None,
        request_id=None,
        metadata=None,
    ):
        """
        Record LLM usage to MongoDB and Redis.

        Args:
            provider: Provider name (anthropic, openai, google, xai)
            model: Model identifier
            feature: Feature name (archive_assistant, ask_ai, story_classification, transcription)
            input_tokens: Number of input tokens
            output_tokens: Number of output tokens
            duration_minutes: For audio models, duration in minutes
            user_id: User ID (optional)
            request_id: Request correlation ID (optional)
            metadata: Additional context dict (optional)

        Returns:
            MLLMCost document instance
        """
        from apps.monitor.models import MLLMCost
        from apps.statistics.rllm_costs import RLLMCosts

        cost_usd = cls.calculate_cost(model, input_tokens, output_tokens, duration_minutes)
        total_tokens = input_tokens + output_tokens

        # Record to Redis for fast Prometheus metrics
        try:
            RLLMCosts.record(
                provider=provider,
                model=model,
                feature=feature,
                input_tokens=input_tokens,
                output_tokens=output_tokens,
                cost_usd=cost_usd,
                user_id=user_id,
            )
        except Exception as e:
            logging.error(f"Failed to record LLM cost to Redis: {e}")

        # Record to MongoDB for detailed historical analysis
        try:
            cost_record = MLLMCost(
                user_id=user_id,
                provider=provider,
                model=model,
                feature=feature,
                input_tokens=input_tokens,
                output_tokens=output_tokens,
                total_tokens=total_tokens,
                cost_usd=cost_usd,
                request_id=request_id,
                metadata=metadata or {},
            )
            cost_record.save()

            logging.debug(
                f"LLM cost recorded: {feature}/{model} - "
                f"{input_tokens}+{output_tokens} tokens = ${cost_usd:.6f}"
            )

            return cost_record

        except Exception as e:
            logging.error(f"Failed to record LLM cost to MongoDB: {e}")
            return None

    @classmethod
    def record_transcription(cls, duration_seconds, user_id=None, request_id=None, metadata=None):
        """
        Convenience method for recording Whisper transcription costs.

        Args:
            duration_seconds: Audio duration in seconds
            user_id: User ID (optional)
            request_id: Request correlation ID (optional)
            metadata: Additional context dict (optional)

        Returns:
            MLLMCost document instance
        """
        duration_minutes = duration_seconds / 60.0

        return cls.record_usage(
            provider="openai",
            model="whisper-1",
            feature="transcription",
            duration_minutes=duration_minutes,
            user_id=user_id,
            request_id=request_id,
            metadata=metadata,
        )

    @classmethod
    def record_embedding(
        cls, model, input_tokens, feature="search", user_id=None, request_id=None, metadata=None
    ):
        """
        Convenience method for recording embedding API costs.

        Embeddings only have input tokens (no output tokens).

        Args:
            model: Embedding model name (e.g., "text-embedding-3-small")
            input_tokens: Number of tokens embedded
            feature: Feature name (default: "search")
            user_id: User ID (optional)
            request_id: Request correlation ID (optional)
            metadata: Additional context dict (optional)

        Returns:
            MLLMCost document instance
        """
        return cls.record_usage(
            provider="openai",
            model=model,
            feature=feature,
            input_tokens=input_tokens,
            output_tokens=0,
            user_id=user_id,
            request_id=request_id,
            metadata=metadata,
        )
