"""
Redis-based LLM cost statistics.

Provides fast aggregation for Prometheus metrics by maintaining
counters in Redis that are updated in real-time when API calls are made.

Key structure:
- LLM:{date}:{provider}:{feature}:tokens - total tokens for the day
- LLM:{date}:{provider}:{feature}:cost - total cost (USD * 1000000 for precision)
- LLM:{date}:{provider}:{feature}:requests - request count
- LLM:{date}:{model}:tokens - tokens by model
- LLM:{date}:{model}:cost - cost by model
- LLM:{date}:{model}:requests - requests by model
- LLM:{date}:users - set of user IDs who made requests

Keys expire after 60 days.
"""

import datetime

import redis
from django.conf import settings


class RLLMCosts:
    KEY_PREFIX = "LLM"
    KEY_EXPIRY_DAYS = 60

    @classmethod
    def _get_redis(cls):
        return redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)

    @classmethod
    def _date_key(cls, date=None):
        """Get date string for key."""
        if date is None:
            date = datetime.date.today()
        return date.strftime("%Y-%m-%d")

    @classmethod
    def _expiry_timestamp(cls, date=None):
        """Get expiry timestamp for keys."""
        if date is None:
            date = datetime.date.today()
        expiry = date + datetime.timedelta(days=cls.KEY_EXPIRY_DAYS)
        return int(expiry.strftime("%s"))

    @classmethod
    def record(cls, provider, model, feature, input_tokens, output_tokens, cost_usd, user_id=None):
        """
        Record an LLM API call in Redis.

        Args:
            provider: Provider name (anthropic, openai, google, xai)
            model: Model identifier
            feature: Feature name (archive_assistant, ask_ai, etc.)
            input_tokens: Number of input tokens
            output_tokens: Number of output tokens
            cost_usd: Cost in USD (float)
            user_id: Optional user ID for tracking unique users
        """
        r = cls._get_redis()
        date_key = cls._date_key()
        expiry = cls._expiry_timestamp()
        total_tokens = input_tokens + output_tokens
        # Store cost as integer (micro-dollars) for precision with INCRBY
        cost_micro = int(cost_usd * 1_000_000)

        pipe = r.pipeline()

        # Provider + Feature breakdown
        pf_prefix = f"{cls.KEY_PREFIX}:{date_key}:{provider}:{feature}"
        pipe.incrby(f"{pf_prefix}:tokens", total_tokens)
        pipe.incrby(f"{pf_prefix}:cost", cost_micro)
        pipe.incr(f"{pf_prefix}:requests")
        pipe.expireat(f"{pf_prefix}:tokens", expiry)
        pipe.expireat(f"{pf_prefix}:cost", expiry)
        pipe.expireat(f"{pf_prefix}:requests", expiry)

        # Model breakdown (sanitize model name for Redis key)
        model_safe = model.replace("-", "_").replace(".", "_")
        model_prefix = f"{cls.KEY_PREFIX}:{date_key}:model:{model_safe}"
        pipe.incrby(f"{model_prefix}:tokens", total_tokens)
        pipe.incrby(f"{model_prefix}:cost", cost_micro)
        pipe.incr(f"{model_prefix}:requests")
        pipe.expireat(f"{model_prefix}:tokens", expiry)
        pipe.expireat(f"{model_prefix}:cost", expiry)
        pipe.expireat(f"{model_prefix}:requests", expiry)

        # Provider-only totals
        p_prefix = f"{cls.KEY_PREFIX}:{date_key}:provider:{provider}"
        pipe.incrby(f"{p_prefix}:tokens", total_tokens)
        pipe.incrby(f"{p_prefix}:cost", cost_micro)
        pipe.incr(f"{p_prefix}:requests")
        pipe.expireat(f"{p_prefix}:tokens", expiry)
        pipe.expireat(f"{p_prefix}:cost", expiry)
        pipe.expireat(f"{p_prefix}:requests", expiry)

        # Feature-only totals
        f_prefix = f"{cls.KEY_PREFIX}:{date_key}:feature:{feature}"
        pipe.incrby(f"{f_prefix}:tokens", total_tokens)
        pipe.incrby(f"{f_prefix}:cost", cost_micro)
        pipe.incr(f"{f_prefix}:requests")
        pipe.expireat(f"{f_prefix}:tokens", expiry)
        pipe.expireat(f"{f_prefix}:cost", expiry)
        pipe.expireat(f"{f_prefix}:requests", expiry)

        # Daily totals
        daily_prefix = f"{cls.KEY_PREFIX}:{date_key}:total"
        pipe.incrby(f"{daily_prefix}:tokens", total_tokens)
        pipe.incrby(f"{daily_prefix}:cost", cost_micro)
        pipe.incr(f"{daily_prefix}:requests")
        pipe.expireat(f"{daily_prefix}:tokens", expiry)
        pipe.expireat(f"{daily_prefix}:cost", expiry)
        pipe.expireat(f"{daily_prefix}:requests", expiry)

        # Track unique users
        if user_id:
            user_key = f"{cls.KEY_PREFIX}:{date_key}:users"
            pipe.sadd(user_key, user_id)
            pipe.expireat(user_key, expiry)

        pipe.execute()

    # Known dimensions for direct key lookups (avoid scan_iter)
    PROVIDERS = ["anthropic", "openai", "google", "xai"]
    FEATURES = [
        "archive_assistant",
        "ask_ai",
        "story_classification",
        "transcription",
        "search_story_embedding",
        "search_query_embedding",
        "search_feed_embedding",
    ]
    METRICS = ["tokens", "cost", "requests"]

    @classmethod
    def get_daily_stats(cls, date=None, include_models=False):
        """
        Get all stats for a specific date using direct key lookups.

        Returns dict with keys like:
            'total': {'tokens': N, 'cost_usd': N, 'requests': N}
            'provider:anthropic': {'tokens': N, 'cost_usd': N, 'requests': N}
            'feature:archive_assistant': {'tokens': N, 'cost_usd': N, 'requests': N}
            'model:claude_sonnet_4_20250514': {'tokens': N, 'cost_usd': N, 'requests': N}
            'unique_users': N

        Args:
            date: Date to get stats for (default: today)
            include_models: If True, scan for model keys (slower). Only use for daily stats.
        """
        r = cls._get_redis()
        date_key = cls._date_key(date)
        prefix = f"{cls.KEY_PREFIX}:{date_key}"

        # Build list of known keys to fetch directly (no scanning)
        keys_to_fetch = []
        key_categories = []

        # Total stats
        for metric in cls.METRICS:
            keys_to_fetch.append(f"{prefix}:total:{metric}")
            key_categories.append(("total", metric))

        # Provider stats
        for provider in cls.PROVIDERS:
            for metric in cls.METRICS:
                keys_to_fetch.append(f"{prefix}:provider:{provider}:{metric}")
                key_categories.append((f"provider:{provider}", metric))

        # Feature stats
        for feature in cls.FEATURES:
            for metric in cls.METRICS:
                keys_to_fetch.append(f"{prefix}:feature:{feature}:{metric}")
                key_categories.append((f"feature:{feature}", metric))

        # Fetch all known keys in one MGET call
        values = r.mget(keys_to_fetch)

        # Parse results into stats dict
        stats = {}
        for i, value in enumerate(values):
            if value is not None:
                category, metric = key_categories[i]
                if category not in stats:
                    stats[category] = {"tokens": 0, "cost_usd": 0.0, "requests": 0}

                val = int(value)
                if metric == "cost":
                    stats[category]["cost_usd"] = val / 1_000_000
                else:
                    stats[category][metric] = val

        # Get unique users count
        user_count = r.scard(f"{prefix}:users")
        if user_count:
            stats["unique_users"] = user_count

        # Only scan for models on daily stats (to get dynamic model names)
        if include_models:
            model_pattern = f"{prefix}:model:*"
            model_keys = list(r.scan_iter(match=model_pattern))
            if model_keys:
                model_values = r.mget(model_keys)
                for i, key in enumerate(model_keys):
                    if model_values[i] is not None:
                        key_str = key.decode() if isinstance(key, bytes) else key
                        # Extract model:name:metric from key
                        parts = key_str.replace(f"{prefix}:", "").rsplit(":", 1)
                        if len(parts) == 2:
                            category, metric = parts
                            if category not in stats:
                                stats[category] = {"tokens": 0, "cost_usd": 0.0, "requests": 0}
                            val = int(model_values[i])
                            if metric == "cost":
                                stats[category]["cost_usd"] = val / 1_000_000
                            else:
                                stats[category][metric] = val

        return stats

    @classmethod
    def get_period_stats(cls, days=1):
        """
        Get aggregated stats for the last N days using batch fetching.

        Args:
            days: Number of days to aggregate (1=today, 7=last week, 30=last month)

        Returns dict with same structure as get_daily_stats but aggregated.
        """
        r = cls._get_redis()
        today = datetime.date.today()

        # Build all keys for all days at once
        all_keys = []
        key_metadata = []  # (category, metric) for each key

        for day_offset in range(days):
            date = today - datetime.timedelta(days=day_offset)
            date_key = cls._date_key(date)
            prefix = f"{cls.KEY_PREFIX}:{date_key}"

            # Total stats
            for metric in cls.METRICS:
                all_keys.append(f"{prefix}:total:{metric}")
                key_metadata.append(("total", metric))

            # Provider stats
            for provider in cls.PROVIDERS:
                for metric in cls.METRICS:
                    all_keys.append(f"{prefix}:provider:{provider}:{metric}")
                    key_metadata.append((f"provider:{provider}", metric))

            # Feature stats
            for feature in cls.FEATURES:
                for metric in cls.METRICS:
                    all_keys.append(f"{prefix}:feature:{feature}:{metric}")
                    key_metadata.append((f"feature:{feature}", metric))

        # Fetch ALL keys across all days in ONE mget call
        values = r.mget(all_keys)

        # Aggregate results
        aggregated = {}
        for i, value in enumerate(values):
            if value is not None:
                category, metric = key_metadata[i]
                if category not in aggregated:
                    aggregated[category] = {"tokens": 0, "cost_usd": 0.0, "requests": 0}

                val = int(value)
                if metric == "cost":
                    aggregated[category]["cost_usd"] += val / 1_000_000
                else:
                    aggregated[category][metric] += val

        # For daily stats only, include models (requires scan)
        if days == 1:
            date_key = cls._date_key()
            prefix = f"{cls.KEY_PREFIX}:{date_key}"
            model_pattern = f"{prefix}:model:*"
            model_keys = list(r.scan_iter(match=model_pattern))
            if model_keys:
                model_values = r.mget(model_keys)
                for i, key in enumerate(model_keys):
                    if model_values[i] is not None:
                        key_str = key.decode() if isinstance(key, bytes) else key
                        parts = key_str.replace(f"{prefix}:", "").rsplit(":", 1)
                        if len(parts) == 2:
                            category, metric = parts
                            if category not in aggregated:
                                aggregated[category] = {"tokens": 0, "cost_usd": 0.0, "requests": 0}
                            val = int(model_values[i])
                            if metric == "cost":
                                aggregated[category]["cost_usd"] += val / 1_000_000
                            else:
                                aggregated[category][metric] += val

        return aggregated

    @classmethod
    def get_unique_users_for_period(cls, days=1):
        """
        Get unique user count for a period using set union.

        More accurate than summing daily counts.
        """
        r = cls._get_redis()
        today = datetime.date.today()

        if days == 1:
            # Just get today's count
            key = f"{cls.KEY_PREFIX}:{cls._date_key()}:users"
            return r.scard(key)

        # Build all user set keys
        keys = []
        for day_offset in range(days):
            date = today - datetime.timedelta(days=day_offset)
            keys.append(f"{cls.KEY_PREFIX}:{cls._date_key(date)}:users")

        # Use SUNION directly (returns the union without storing)
        # This avoids checking existence and temp key creation
        try:
            union_result = r.sunion(*keys)
            return len(union_result) if union_result else 0
        except Exception:
            return 0
