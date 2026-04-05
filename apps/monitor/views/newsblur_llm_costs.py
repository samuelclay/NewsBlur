from django.contrib.auth.models import User
from django.shortcuts import render
from django.views import View

from apps.statistics.rllm_costs import RLLMCosts

# Markup applied to raw LLM costs for usage-based billing revenue
COST_MARKUP = 1.5


class LLMCosts(View):
    def get(self, request):
        """
        Prometheus metrics endpoint for LLM cost tracking.

        Reads from Redis for fast aggregation (no MongoDB queries).
        Uses get_all_periods_stats() to fetch all periods in 2 Redis
        round-trips instead of 6+ (which caused Prometheus scrape timeouts
        due to scan_iter on 150K+ keys in db=3).
        """
        all_stats = RLLMCosts.get_all_periods_stats()
        daily_stats = all_stats["daily"]
        weekly_stats = all_stats["weekly"]
        monthly_stats = all_stats["monthly"]
        daily_users = all_stats["daily_users"]
        weekly_users = all_stats["weekly_users"]
        monthly_users = all_stats["monthly_users"]
        daily_billing_users = all_stats["daily_billing_users"]
        weekly_billing_users = all_stats["weekly_billing_users"]
        monthly_billing_users = all_stats["monthly_billing_users"]

        # Per-user billing stats (aggregated over the Grafana time range, default 30 days)
        billing_user_stats = RLLMCosts.get_billing_user_stats(days=30)

        # Define the dimensions we track (use centralized lists from RLLMCosts)
        providers = RLLMCosts.PROVIDERS
        features = RLLMCosts.FEATURES
        classifier_features = RLLMCosts.CLASSIFIER_FEATURES

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

        # === Classifier Billing (usage-billing users only) ===
        for period_name, stats in [
            ("daily", daily_stats),
            ("weekly", weekly_stats),
            ("monthly", monthly_stats),
        ]:
            for feature in classifier_features:
                s = get_stats(stats, f"billing:{feature}")
                data[f"billing_{feature}_{period_name}_tokens"] = s["tokens"]
                data[f"billing_{feature}_{period_name}_cost_usd"] = s["cost_usd"]
                data[f"billing_{feature}_{period_name}_requests"] = s["requests"]

        data["daily_billing_users"] = daily_billing_users
        data["weekly_billing_users"] = weekly_billing_users
        data["monthly_billing_users"] = monthly_billing_users

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

        # Classifier billing metrics (usage-billing users only)
        for feature in classifier_features:
            for period in ["daily", "weekly", "monthly"]:
                tokens_key = f"billing_{feature}_{period}_tokens"
                cost_key = f"billing_{feature}_{period}_cost_usd"
                requests_key = f"billing_{feature}_{period}_requests"

                formatted_data[
                    f"billing_{tokens_key}"
                ] = f'{chart_name}{{metric="tokens",billing="usage",feature="{feature}",period="{period}"}} {data[tokens_key]}'
                formatted_data[
                    f"billing_{cost_key}"
                ] = f'{chart_name}{{metric="cost_usd",billing="usage",feature="{feature}",period="{period}"}} {data[cost_key]:.6f}'
                formatted_data[
                    f"billing_{requests_key}"
                ] = f'{chart_name}{{metric="requests",billing="usage",feature="{feature}",period="{period}"}} {data[requests_key]}'

        # Billing users
        for period in ["daily", "weekly", "monthly"]:
            formatted_data[
                f"{period}_billing_users"
            ] = f'{chart_name}{{metric="billing_users",period="{period}"}} {data[f"{period}_billing_users"]}'

        # Per-user billing breakdown (for Grafana table panel)
        if billing_user_stats:
            # Look up usernames in one query
            user_ids = list(billing_user_stats.keys())
            usernames = dict(User.objects.filter(pk__in=user_ids).values_list("pk", "username"))

            for user_id, features in billing_user_stats.items():
                username = usernames.get(user_id, str(user_id))
                # Aggregate across text + vision features for this user
                total_cost = 0.0
                total_requests = 0
                text_requests = 0
                vision_requests = 0
                for feature, stats in features.items():
                    total_cost += stats["cost_usd"]
                    total_requests += stats["requests"]
                    if feature == "story_classification":
                        text_requests = stats["requests"]
                    elif feature == "vision_classification":
                        vision_requests = stats["requests"]

                revenue = total_cost * COST_MARKUP
                formatted_data[
                    f"billing_user_{user_id}_cost"
                ] = f'{chart_name}{{metric="cost_usd",billing="user",username="{username}"}} {total_cost:.6f}'
                formatted_data[
                    f"billing_user_{user_id}_revenue"
                ] = f'{chart_name}{{metric="revenue_usd",billing="user",username="{username}"}} {revenue:.6f}'
                formatted_data[
                    f"billing_user_{user_id}_text_requests"
                ] = f'{chart_name}{{metric="text_requests",billing="user",username="{username}"}} {text_requests}'
                formatted_data[
                    f"billing_user_{user_id}_vision_requests"
                ] = f'{chart_name}{{metric="vision_requests",billing="user",username="{username}"}} {vision_requests}'
                formatted_data[
                    f"billing_user_{user_id}_total_requests"
                ] = f'{chart_name}{{metric="total_stories",billing="user",username="{username}"}} {total_requests}'

        context = {
            "data": formatted_data,
            "chart_name": chart_name,
            "chart_type": chart_type,
        }
        return render(request, "monitor/prometheus_data.html", context, content_type="text/plain")
