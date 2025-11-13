import datetime

import pytz
from django.db.models import Count, Q
from django.shortcuts import render
from django.views import View

from apps.ask_ai.models import MAskAIResponse
from apps.profile.models import Profile


class AskAI(View):
    def get(self, request):
        """
        Metrics endpoint for Ask AI usage tracking.

        Tracks:
        - Total requests (cumulative and by type)
        - Requests by question type
        - Active users (daily/weekly/monthly)
        - Usage by subscription tier
        - Users approaching limits
        """
        now_utc = datetime.datetime.utcnow().replace(tzinfo=pytz.UTC)
        last_day = now_utc - datetime.timedelta(days=1)
        last_week = now_utc - datetime.timedelta(days=7)
        last_month = now_utc - datetime.timedelta(days=30)

        data = {}

        # ===== Total Request Counts =====
        # Count total AI responses by question type
        question_counts = {}
        for question_id in ["sentence", "bullets", "paragraph", "context", "people", "arguments", "factcheck", "custom"]:
            count = MAskAIResponse.objects(question_id=question_id).count()
            question_counts[question_id] = count

        # Total requests
        total_requests = MAskAIResponse.objects.count()
        data["requests_total"] = total_requests

        # Requests by question type
        for question_id, count in question_counts.items():
            data[f"requests_{question_id}"] = count

        # ===== Active Users by Time Period =====
        # Users who have used AI in the last day/week/month
        # We check both ask_ai_uses_count > 0 (free users) and ask_ai_daily_count > 0 (premium)
        active_users_daily = Profile.objects.filter(
            Q(ask_ai_last_daily_reset__gte=last_day) | Q(ask_ai_uses_count__gt=0)
        ).count()

        active_users_weekly = Profile.objects.filter(
            Q(ask_ai_last_daily_reset__gte=last_week) | Q(ask_ai_uses_count__gt=0)
        ).count()

        # For monthly, we look at MAskAIResponse creation dates
        users_with_responses_monthly = MAskAIResponse.objects(created_at__gte=last_month).distinct("user_id")
        active_users_monthly = len(users_with_responses_monthly)

        data["active_users_daily"] = active_users_daily
        data["active_users_weekly"] = active_users_weekly
        data["active_users_monthly"] = active_users_monthly

        # ===== Usage by Subscription Tier =====
        # Free users (not premium, not archive, not pro)
        free_users_with_usage = Profile.objects.filter(
            is_premium=False,
            is_archive=False,
            is_pro=False,
            ask_ai_uses_count__gt=0
        ).count()

        free_users_at_limit = Profile.objects.filter(
            is_premium=False,
            is_archive=False,
            is_pro=False,
            ask_ai_uses_count__gte=10  # Free limit is 10
        ).count()

        # Premium users (premium but not archive/pro)
        premium_users_with_usage = Profile.objects.filter(
            is_premium=True,
            is_archive=False,
            is_pro=False,
            ask_ai_daily_count__gt=0
        ).count()

        premium_users_at_limit = Profile.objects.filter(
            is_premium=True,
            is_archive=False,
            is_pro=False,
            ask_ai_daily_count__gte=3  # Premium daily limit is 3
        ).count()

        # Archive/Pro users
        archive_users_with_usage = Profile.objects.filter(
            Q(is_archive=True) | Q(is_pro=True),
            ask_ai_daily_count__gt=0
        ).count()

        archive_users_at_limit = Profile.objects.filter(
            Q(is_archive=True) | Q(is_pro=True),
            ask_ai_daily_count__gte=50  # Archive/Pro daily limit is 50
        ).count()

        data["tier_free_using"] = free_users_with_usage
        data["tier_free_at_limit"] = free_users_at_limit
        data["tier_premium_using"] = premium_users_with_usage
        data["tier_premium_at_limit"] = premium_users_at_limit
        data["tier_archive_using"] = archive_users_with_usage
        data["tier_archive_at_limit"] = archive_users_at_limit

        # ===== Limit Proximity Distribution =====
        # Free users: 0-20%, 20-40%, 40-60%, 60-80%, 80-100% of 10 limit
        free_limit = 10
        free_buckets = {
            "0-20": Profile.objects.filter(
                is_premium=False, is_archive=False, is_pro=False,
                ask_ai_uses_count__gt=0, ask_ai_uses_count__lt=free_limit * 0.2
            ).count(),
            "20-40": Profile.objects.filter(
                is_premium=False, is_archive=False, is_pro=False,
                ask_ai_uses_count__gte=free_limit * 0.2, ask_ai_uses_count__lt=free_limit * 0.4
            ).count(),
            "40-60": Profile.objects.filter(
                is_premium=False, is_archive=False, is_pro=False,
                ask_ai_uses_count__gte=free_limit * 0.4, ask_ai_uses_count__lt=free_limit * 0.6
            ).count(),
            "60-80": Profile.objects.filter(
                is_premium=False, is_archive=False, is_pro=False,
                ask_ai_uses_count__gte=free_limit * 0.6, ask_ai_uses_count__lt=free_limit * 0.8
            ).count(),
            "80-100": Profile.objects.filter(
                is_premium=False, is_archive=False, is_pro=False,
                ask_ai_uses_count__gte=free_limit * 0.8
            ).count(),
        }

        for bucket, count in free_buckets.items():
            data[f"limit_free_{bucket}"] = count

        # Premium users: 0-20%, 20-40%, 40-60%, 60-80%, 80-100% of 3 daily limit
        premium_limit = 3
        premium_buckets = {
            "0-20": Profile.objects.filter(
                is_premium=True, is_archive=False, is_pro=False,
                ask_ai_daily_count__gt=0, ask_ai_daily_count__lt=premium_limit * 0.2
            ).count(),
            "20-40": Profile.objects.filter(
                is_premium=True, is_archive=False, is_pro=False,
                ask_ai_daily_count__gte=premium_limit * 0.2, ask_ai_daily_count__lt=premium_limit * 0.4
            ).count(),
            "40-60": Profile.objects.filter(
                is_premium=True, is_archive=False, is_pro=False,
                ask_ai_daily_count__gte=premium_limit * 0.4, ask_ai_daily_count__lt=premium_limit * 0.6
            ).count(),
            "60-80": Profile.objects.filter(
                is_premium=True, is_archive=False, is_pro=False,
                ask_ai_daily_count__gte=premium_limit * 0.6, ask_ai_daily_count__lt=premium_limit * 0.8
            ).count(),
            "80-100": Profile.objects.filter(
                is_premium=True, is_archive=False, is_pro=False,
                ask_ai_daily_count__gte=premium_limit * 0.8
            ).count(),
        }

        for bucket, count in premium_buckets.items():
            data[f"limit_premium_{bucket}"] = count

        # Archive/Pro users: 0-20%, 20-40%, 40-60%, 60-80%, 80-100% of 50 daily limit
        archive_limit = 50
        archive_buckets = {
            "0-20": Profile.objects.filter(
                Q(is_archive=True) | Q(is_pro=True),
                ask_ai_daily_count__gt=0, ask_ai_daily_count__lt=archive_limit * 0.2
            ).count(),
            "20-40": Profile.objects.filter(
                Q(is_archive=True) | Q(is_pro=True),
                ask_ai_daily_count__gte=archive_limit * 0.2, ask_ai_daily_count__lt=archive_limit * 0.4
            ).count(),
            "40-60": Profile.objects.filter(
                Q(is_archive=True) | Q(is_pro=True),
                ask_ai_daily_count__gte=archive_limit * 0.4, ask_ai_daily_count__lt=archive_limit * 0.6
            ).count(),
            "60-80": Profile.objects.filter(
                Q(is_archive=True) | Q(is_pro=True),
                ask_ai_daily_count__gte=archive_limit * 0.6, ask_ai_daily_count__lt=archive_limit * 0.8
            ).count(),
            "80-100": Profile.objects.filter(
                Q(is_archive=True) | Q(is_pro=True),
                ask_ai_daily_count__gte=archive_limit * 0.8
            ).count(),
        }

        for bucket, count in archive_buckets.items():
            data[f"limit_archive_{bucket}"] = count

        # ===== Request Rate Metrics (from MAskAIResponse) =====
        # Count requests in the last day/week/month
        requests_daily = MAskAIResponse.objects(created_at__gte=last_day).count()
        requests_weekly = MAskAIResponse.objects(created_at__gte=last_week).count()
        requests_monthly = MAskAIResponse.objects(created_at__gte=last_month).count()

        data["requests_daily"] = requests_daily
        data["requests_weekly"] = requests_weekly
        data["requests_monthly"] = requests_monthly

        # Count follow-up questions (those with conversation_history in metadata)
        # We can infer follow-ups by checking if there are multiple responses for the same user/story
        # For now, we'll track custom questions separately
        custom_requests_total = question_counts.get("custom", 0)
        data["requests_custom_total"] = custom_requests_total

        # Format data for Prometheus
        chart_name = "ask_ai"
        chart_type = "counter"

        formatted_data = {}

        # Total requests
        formatted_data["requests_total"] = f'{chart_name}{{metric="requests_total"}} {data["requests_total"]}'

        # Requests by question type
        for question_id in ["sentence", "bullets", "paragraph", "context", "people", "arguments", "factcheck", "custom"]:
            count = data[f"requests_{question_id}"]
            formatted_data[f"requests_{question_id}"] = f'{chart_name}{{metric="requests",question_id="{question_id}"}} {count}'

        # Active users
        formatted_data["active_users_daily"] = f'{chart_name}{{metric="active_users",period="daily"}} {data["active_users_daily"]}'
        formatted_data["active_users_weekly"] = f'{chart_name}{{metric="active_users",period="weekly"}} {data["active_users_weekly"]}'
        formatted_data["active_users_monthly"] = f'{chart_name}{{metric="active_users",period="monthly"}} {data["active_users_monthly"]}'

        # Usage by tier
        for tier in ["free", "premium", "archive"]:
            formatted_data[f"tier_{tier}_using"] = f'{chart_name}{{metric="tier_usage",tier="{tier}",status="using"}} {data[f"tier_{tier}_using"]}'
            formatted_data[f"tier_{tier}_at_limit"] = f'{chart_name}{{metric="tier_usage",tier="{tier}",status="at_limit"}} {data[f"tier_{tier}_at_limit"]}'

        # Limit proximity distribution
        for tier in ["free", "premium", "archive"]:
            for bucket in ["0-20", "20-40", "40-60", "60-80", "80-100"]:
                key = f"limit_{tier}_{bucket}"
                formatted_data[key] = f'{chart_name}{{metric="limit_proximity",tier="{tier}",bucket="{bucket}"}} {data[key]}'

        # Request rate metrics
        formatted_data["requests_daily"] = f'{chart_name}{{metric="requests_rate",period="daily"}} {data["requests_daily"]}'
        formatted_data["requests_weekly"] = f'{chart_name}{{metric="requests_rate",period="weekly"}} {data["requests_weekly"]}'
        formatted_data["requests_monthly"] = f'{chart_name}{{metric="requests_rate",period="monthly"}} {data["requests_monthly"]}'

        context = {
            "data": formatted_data,
            "chart_name": chart_name,
            "chart_type": chart_type,
        }
        return render(request, "monitor/prometheus_data.html", context, content_type="text/plain")
