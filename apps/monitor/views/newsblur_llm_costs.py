from django.shortcuts import render
from django.views import View

from apps.statistics.rllm_costs import RLLMCosts


class LLMCosts(View):
    def get(self, request):
        """
        Prometheus metrics endpoint for LLM cost tracking.

        Reads from Redis for fast aggregation (no MongoDB queries).

        Exports metrics for:
        - Token usage by provider, model, and feature
        - Cost in USD by provider, model, and feature
        - Request counts by provider, model, and feature
        - All metrics available for daily, weekly, monthly periods
        """
        # Get stats from Redis for each period
        daily_stats = RLLMCosts.get_period_stats(days=1)
        weekly_stats = RLLMCosts.get_period_stats(days=7)
        monthly_stats = RLLMCosts.get_period_stats(days=30)

        # Get accurate unique user counts
        daily_users = RLLMCosts.get_unique_users_for_period(days=1)
        weekly_users = RLLMCosts.get_unique_users_for_period(days=7)
        monthly_users = RLLMCosts.get_unique_users_for_period(days=30)

        # Define the dimensions we track (use centralized lists from RLLMCosts)
        providers = RLLMCosts.PROVIDERS
        features = RLLMCosts.FEATURES

        data = {}

        # Helper to extract stats
        def get_stats(stats_dict, key):
            return stats_dict.get(key, {"tokens": 0, "cost_usd": 0.0, "requests": 0})

        # === Overall Totals ===
        for period_name, stats in [
            ("daily", daily_stats),
            ("weekly", weekly_stats),
            ("monthly", monthly_stats),
        ]:
            total = get_stats(stats, "total")
            data[f"{period_name}_tokens"] = total["tokens"]
            data[f"{period_name}_cost_usd"] = total["cost_usd"]
            data[f"{period_name}_requests"] = total["requests"]

        # === By Provider ===
        for period_name, stats in [
            ("daily", daily_stats),
            ("weekly", weekly_stats),
            ("monthly", monthly_stats),
        ]:
            for provider in providers:
                s = get_stats(stats, f"provider:{provider}")
                data[f"provider_{provider}_{period_name}_tokens"] = s["tokens"]
                data[f"provider_{provider}_{period_name}_cost_usd"] = s["cost_usd"]
                data[f"provider_{provider}_{period_name}_requests"] = s["requests"]

        # === By Feature ===
        for period_name, stats in [
            ("daily", daily_stats),
            ("weekly", weekly_stats),
            ("monthly", monthly_stats),
        ]:
            for feature in features:
                s = get_stats(stats, f"feature:{feature}")
                data[f"feature_{feature}_{period_name}_tokens"] = s["tokens"]
                data[f"feature_{feature}_{period_name}_cost_usd"] = s["cost_usd"]
                data[f"feature_{feature}_{period_name}_requests"] = s["requests"]

        # === By Model (daily only) ===
        # Store model names separately to avoid key parsing issues
        model_names = []
        for key, value in daily_stats.items():
            if key.startswith("model:") and isinstance(value, dict):
                model_name = key.replace("model:", "")
                model_names.append(model_name)
                data[f"model_{model_name}_daily_tokens"] = value.get("tokens", 0)
                data[f"model_{model_name}_daily_cost_usd"] = value.get("cost_usd", 0.0)
                data[f"model_{model_name}_daily_requests"] = value.get("requests", 0)

        # === Unique Users ===
        data["daily_unique_users"] = daily_users
        data["weekly_unique_users"] = weekly_users
        data["monthly_unique_users"] = monthly_users

        # Format data for Prometheus
        chart_name = "llm_costs"
        chart_type = "gauge"

        formatted_data = {}

        # Period totals
        for period in ["daily", "weekly", "monthly"]:
            formatted_data[
                f"{period}_tokens"
            ] = f'{chart_name}{{metric="tokens",period="{period}"}} {data[f"{period}_tokens"]}'
            formatted_data[
                f"{period}_cost_usd"
            ] = f'{chart_name}{{metric="cost_usd",period="{period}"}} {data[f"{period}_cost_usd"]:.6f}'
            formatted_data[
                f"{period}_requests"
            ] = f'{chart_name}{{metric="requests",period="{period}"}} {data[f"{period}_requests"]}'

        # By provider
        for provider in providers:
            for period in ["daily", "weekly", "monthly"]:
                tokens_key = f"provider_{provider}_{period}_tokens"
                cost_key = f"provider_{provider}_{period}_cost_usd"
                requests_key = f"provider_{provider}_{period}_requests"

                formatted_data[
                    tokens_key
                ] = f'{chart_name}{{metric="tokens",provider="{provider}",period="{period}"}} {data[tokens_key]}'
                formatted_data[
                    cost_key
                ] = f'{chart_name}{{metric="cost_usd",provider="{provider}",period="{period}"}} {data[cost_key]:.6f}'
                formatted_data[
                    requests_key
                ] = f'{chart_name}{{metric="requests",provider="{provider}",period="{period}"}} {data[requests_key]}'

        # By feature
        for feature in features:
            for period in ["daily", "weekly", "monthly"]:
                tokens_key = f"feature_{feature}_{period}_tokens"
                cost_key = f"feature_{feature}_{period}_cost_usd"
                requests_key = f"feature_{feature}_{period}_requests"

                formatted_data[
                    tokens_key
                ] = f'{chart_name}{{metric="tokens",feature="{feature}",period="{period}"}} {data[tokens_key]}'
                formatted_data[
                    cost_key
                ] = f'{chart_name}{{metric="cost_usd",feature="{feature}",period="{period}"}} {data[cost_key]:.6f}'
                formatted_data[
                    requests_key
                ] = f'{chart_name}{{metric="requests",feature="{feature}",period="{period}"}} {data[requests_key]}'

        # By model (daily only) - use stored model_names to avoid key parsing issues
        for model_name in model_names:
            tokens_key = f"model_{model_name}_daily_tokens"
            cost_key = f"model_{model_name}_daily_cost_usd"
            requests_key = f"model_{model_name}_daily_requests"

            formatted_data[
                tokens_key
            ] = f'{chart_name}{{metric="tokens",model="{model_name}",period="daily"}} {data[tokens_key]}'
            formatted_data[
                cost_key
            ] = f'{chart_name}{{metric="cost_usd",model="{model_name}",period="daily"}} {data[cost_key]:.6f}'
            formatted_data[
                requests_key
            ] = f'{chart_name}{{metric="requests",model="{model_name}",period="daily"}} {data[requests_key]}'

        # Unique users
        for period in ["daily", "weekly", "monthly"]:
            formatted_data[
                f"{period}_unique_users"
            ] = f'{chart_name}{{metric="unique_users",period="{period}"}} {data[f"{period}_unique_users"]}'

        context = {
            "data": formatted_data,
            "chart_name": chart_name,
            "chart_type": chart_type,
        }
        return render(request, "monitor/prometheus_data.html", context, content_type="text/plain")
