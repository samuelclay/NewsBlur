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

        # Register model name for fast lookup (avoids scan_iter on 150K+ keys)
        pipe.sadd(f"{cls.KEY_PREFIX}:known_models", model_safe)

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

        # Look up model stats using known_models set (avoids slow scan_iter on 150K+ keys)
        if include_models:
            known_models = r.smembers(f"{cls.KEY_PREFIX}:known_models")
            if known_models:
                model_keys = []
                model_meta = []
                for model_name in known_models:
                    for metric in cls.METRICS:
                        model_keys.append(f"{prefix}:model:{model_name}:{metric}")
                        model_meta.append((f"model:{model_name}", metric))
                model_values = r.mget(model_keys)
                for i, value in enumerate(model_values):
                    if value is not None:
                        category, metric = model_meta[i]
                        if category not in stats:
                            stats[category] = {"tokens": 0, "cost_usd": 0.0, "requests": 0}
                        val = int(value)
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

        # For daily stats only, include models using known_models set
        if days == 1:
            date_key = cls._date_key()
            prefix = f"{cls.KEY_PREFIX}:{date_key}"
            known_models = r.smembers(f"{cls.KEY_PREFIX}:known_models")
            if known_models:
                model_keys = []
                model_meta = []
                for model_name in known_models:
                    for metric in cls.METRICS:
                        model_keys.append(f"{prefix}:model:{model_name}:{metric}")
                        model_meta.append((f"model:{model_name}", metric))
                model_values = r.mget(model_keys)
                for i, value in enumerate(model_values):
                    if value is not None:
                        category, metric = model_meta[i]
                        if category not in aggregated:
                            aggregated[category] = {"tokens": 0, "cost_usd": 0.0, "requests": 0}
                        val = int(value)
                        if metric == "cost":
                            aggregated[category]["cost_usd"] += val / 1_000_000
                        else:
                            aggregated[category][metric] += val

        return aggregated

    @classmethod
    def get_all_periods_stats(cls):
        """
        Get daily, weekly, and monthly stats in minimal Redis round-trips.

        Instead of calling get_period_stats 3 times (3 MGETs with overlapping keys)
        and get_unique_users_for_period 3 times, this fetches all 30 days once
        and partitions results. Reduces round-trips from thousands (due to scan_iter
        on 150K+ keys in db=3) to 2.

        Returns dict with keys: daily, weekly, monthly, daily_users, weekly_users, monthly_users
        """
        r = cls._get_redis()
        today = datetime.date.today()

        # Build all 30 days of keys at once
        all_keys = []
        key_metadata = []  # (day_offset, category, metric)

        for day_offset in range(30):
            date = today - datetime.timedelta(days=day_offset)
            date_key = cls._date_key(date)
            prefix = f"{cls.KEY_PREFIX}:{date_key}"

            for metric in cls.METRICS:
                all_keys.append(f"{prefix}:total:{metric}")
                key_metadata.append((day_offset, "total", metric))

            for provider in cls.PROVIDERS:
                for metric in cls.METRICS:
                    all_keys.append(f"{prefix}:provider:{provider}:{metric}")
                    key_metadata.append((day_offset, f"provider:{provider}", metric))

            for feature in cls.FEATURES:
                for metric in cls.METRICS:
                    all_keys.append(f"{prefix}:feature:{feature}:{metric}")
                    key_metadata.append((day_offset, f"feature:{feature}", metric))

        # Build user set keys for all 30 days
        user_keys = []
        for day_offset in range(30):
            date = today - datetime.timedelta(days=day_offset)
            user_keys.append(f"{cls.KEY_PREFIX}:{cls._date_key(date)}:users")

        # Pipeline: 1 MGET + known models set + user operations = 1 round-trip
        pipe = r.pipeline()
        pipe.mget(all_keys)
        pipe.smembers(f"{cls.KEY_PREFIX}:known_models")
        pipe.scard(user_keys[0])
        pipe.sunion(*user_keys[:7])
        pipe.sunion(*user_keys[:30])
        results = pipe.execute()

        values = results[0]
        known_models = results[1]
        daily_users = results[2]
        weekly_users_set = results[3]
        monthly_users_set = results[4]

        # Partition metrics into daily/weekly/monthly buckets
        daily = {}
        weekly = {}
        monthly = {}

        for i, value in enumerate(values):
            if value is not None:
                day_offset, category, metric = key_metadata[i]
                val = int(value)

                if category not in monthly:
                    monthly[category] = {"tokens": 0, "cost_usd": 0.0, "requests": 0}
                if metric == "cost":
                    monthly[category]["cost_usd"] += val / 1_000_000
                else:
                    monthly[category][metric] += val

                if day_offset < 7:
                    if category not in weekly:
                        weekly[category] = {"tokens": 0, "cost_usd": 0.0, "requests": 0}
                    if metric == "cost":
                        weekly[category]["cost_usd"] += val / 1_000_000
                    else:
                        weekly[category][metric] += val

                if day_offset == 0:
                    if category not in daily:
                        daily[category] = {"tokens": 0, "cost_usd": 0.0, "requests": 0}
                    if metric == "cost":
                        daily[category]["cost_usd"] += val / 1_000_000
                    else:
                        daily[category][metric] += val

        # Fetch model stats for today using known_models set (no scan_iter needed)
        if known_models:
            today_prefix = f"{cls.KEY_PREFIX}:{cls._date_key()}"
            model_keys = []
            model_meta = []
            for model_name in known_models:
                for metric in cls.METRICS:
                    model_keys.append(f"{today_prefix}:model:{model_name}:{metric}")
                    model_meta.append((f"model:{model_name}", metric))

            if model_keys:
                model_values = r.mget(model_keys)
                for i, value in enumerate(model_values):
                    if value is not None:
                        category, metric = model_meta[i]
                        if category not in daily:
                            daily[category] = {"tokens": 0, "cost_usd": 0.0, "requests": 0}
                        val = int(value)
                        if metric == "cost":
                            daily[category]["cost_usd"] += val / 1_000_000
                        else:
                            daily[category][metric] += val

        return {
            "daily": daily,
            "weekly": weekly,
            "monthly": monthly,
            "daily_users": daily_users,
            "weekly_users": len(weekly_users_set) if weekly_users_set else 0,
            "monthly_users": len(monthly_users_set) if monthly_users_set else 0,
        }

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
