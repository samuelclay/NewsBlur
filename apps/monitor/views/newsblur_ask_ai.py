import datetime

import pytz
from django.shortcuts import render
from django.views import View

from apps.ask_ai.models import MAITranscriptionUsage, MAskAIResponse, MAskAIUsage
from apps.ask_ai.usage import AskAIUsageTracker, TranscriptionUsageTracker
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

        def distinct_user_count(queryset):
            return len([uid for uid in queryset if uid is not None])

        # ===== Total Request Counts =====
        # Count total AI responses by question type
        question_counts = {}
        for question_id in [
            "sentence",
            "bullets",
            "paragraph",
            "context",
            "people",
            "arguments",
            "factcheck",
            "custom",
        ]:
            count = MAskAIResponse.objects(question_id=question_id).count()
            question_counts[question_id] = count

        # Total requests
        total_requests = MAskAIResponse.objects.count()
        data["requests_total"] = total_requests

        # Requests by question type
        for question_id, count in question_counts.items():
            data[f"requests_{question_id}"] = count

        # ===== Active Users by Time Period =====
        active_users_daily = distinct_user_count(
            MAskAIResponse.objects(created_at__gte=last_day).distinct("user_id")
        )
        active_users_weekly = distinct_user_count(
            MAskAIResponse.objects(created_at__gte=last_week).distinct("user_id")
        )
        active_users_monthly = distinct_user_count(
            MAskAIResponse.objects(created_at__gte=last_month).distinct("user_id")
        )

        data["active_users_daily"] = active_users_daily
        data["active_users_weekly"] = active_users_weekly
        data["active_users_monthly"] = active_users_monthly

        # ===== Usage by Subscription Tier =====
        # Get weekly counts for free users, daily counts for premium users
        usage_snapshot = AskAIUsageTracker.get_usage_snapshot()
        daily_counts = usage_snapshot.get("daily", {})
        weekly_counts = usage_snapshot.get("weekly", {})

        user_ids = set(daily_counts.keys()) | set(weekly_counts.keys())
        profiles_by_user = {}
        if user_ids:
            for profile in Profile.objects.filter(user__id__in=list(user_ids)):
                profiles_by_user[profile.user_id] = profile

        bucket_names = ["0-20", "20-40", "40-60", "60-80", "80-100"]
        buckets = {tier: {bucket: 0 for bucket in bucket_names} for tier in ["free", "premium", "archive"]}
        tier_stats = {
            "free": {"using": 0, "at_limit": 0},
            "premium": {"using": 0, "at_limit": 0},
            "archive": {"using": 0, "at_limit": 0},
        }

        def add_bucket(tier, count, limit):
            if count <= 0 or limit <= 0:
                return
            ratio = float(count) / float(limit)
            if ratio < 0.2:
                buckets[tier]["0-20"] += 1
            elif ratio < 0.4:
                buckets[tier]["20-40"] += 1
            elif ratio < 0.6:
                buckets[tier]["40-60"] += 1
            elif ratio < 0.8:
                buckets[tier]["60-80"] += 1
            else:
                buckets[tier]["80-100"] += 1

        # Process weekly counts for free users
        for user_id, count in weekly_counts.items():
            profile = profiles_by_user.get(user_id)
            if not profile or profile.is_premium or profile.is_archive or profile.is_pro:
                continue
            if count > 0:
                tier_stats["free"]["using"] += 1
            if count >= AskAIUsageTracker.WEEKLY_LIMIT_FREE:
                tier_stats["free"]["at_limit"] += 1
            add_bucket("free", count, AskAIUsageTracker.WEEKLY_LIMIT_FREE)

        # Process daily counts for premium users
        for user_id, count in daily_counts.items():
            profile = profiles_by_user.get(user_id)
            if not profile:
                continue
            if profile.is_archive or profile.is_pro:
                if count > 0:
                    tier_stats["archive"]["using"] += 1
                if count >= AskAIUsageTracker.DAILY_LIMIT_ARCHIVE:
                    tier_stats["archive"]["at_limit"] += 1
                add_bucket("archive", count, AskAIUsageTracker.DAILY_LIMIT_ARCHIVE)
            elif profile.is_premium:
                if count > 0:
                    tier_stats["premium"]["using"] += 1
                if count >= AskAIUsageTracker.DAILY_LIMIT_PREMIUM:
                    tier_stats["premium"]["at_limit"] += 1
                add_bucket("premium", count, AskAIUsageTracker.DAILY_LIMIT_PREMIUM)

        data["tier_free_using"] = tier_stats["free"]["using"]
        data["tier_free_at_limit"] = tier_stats["free"]["at_limit"]
        data["tier_premium_using"] = tier_stats["premium"]["using"]
        data["tier_premium_at_limit"] = tier_stats["premium"]["at_limit"]
        data["tier_archive_using"] = tier_stats["archive"]["using"]
        data["tier_archive_at_limit"] = tier_stats["archive"]["at_limit"]

        for tier in ["free", "premium", "archive"]:
            for bucket in bucket_names:
                data[f"limit_{tier}_{bucket}"] = buckets[tier][bucket]

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

        # ===== Over Quota (Denied Requests) Metrics =====
        # Count total denied requests (all time)
        denied_total = MAskAIUsage.objects(over_quota=True).count()
        data["denied_total"] = denied_total

        # Count denied requests in recent periods
        denied_daily = MAskAIUsage.objects(over_quota=True, created_at__gte=last_day).count()
        denied_weekly = MAskAIUsage.objects(over_quota=True, created_at__gte=last_week).count()
        denied_monthly = MAskAIUsage.objects(over_quota=True, created_at__gte=last_month).count()

        data["denied_daily"] = denied_daily
        data["denied_weekly"] = denied_weekly
        data["denied_monthly"] = denied_monthly

        # Count unique users who hit limits (all time)
        unique_denied_users = len(MAskAIUsage.objects(over_quota=True).distinct("user_id"))
        data["denied_unique_users"] = unique_denied_users

        # Count denied requests by tier (recent periods for better accuracy)
        # Get all denied requests from last month to categorize by tier
        denied_entries = MAskAIUsage.objects(over_quota=True, created_at__gte=last_month).only(
            "user_id", "plan_tier"
        )

        # Count by plan tier (using the recorded plan_tier field)
        denied_by_tier = {"free": 0, "premium": 0, "archive": 0}
        denied_users_by_tier = {"free": set(), "premium": set(), "archive": set()}

        for entry in denied_entries:
            tier = entry.plan_tier or "free"
            # Normalize tier names
            if tier in ["archive", "pro"]:
                tier = "archive"
            elif tier == "premium":
                tier = "premium"
            else:
                tier = "free"

            denied_by_tier[tier] += 1
            denied_users_by_tier[tier].add(entry.user_id)

        # Store tier-specific counts
        data["denied_free"] = denied_by_tier["free"]
        data["denied_premium"] = denied_by_tier["premium"]
        data["denied_archive"] = denied_by_tier["archive"]

        # Store unique user counts by tier
        data["denied_unique_free"] = len(denied_users_by_tier["free"])
        data["denied_unique_premium"] = len(denied_users_by_tier["premium"])
        data["denied_unique_archive"] = len(denied_users_by_tier["archive"])

        # ===== Transcription Metrics =====
        # Count total transcriptions (all time)
        transcriptions_total = MAITranscriptionUsage.objects.count()
        data["transcriptions_total"] = transcriptions_total

        # Count transcriptions in recent periods
        transcriptions_daily = MAITranscriptionUsage.objects(created_at__gte=last_day).count()
        transcriptions_weekly = MAITranscriptionUsage.objects(created_at__gte=last_week).count()
        transcriptions_monthly = MAITranscriptionUsage.objects(created_at__gte=last_month).count()

        data["transcriptions_daily"] = transcriptions_daily
        data["transcriptions_weekly"] = transcriptions_weekly
        data["transcriptions_monthly"] = transcriptions_monthly

        # Count transcriptions over quota
        transcriptions_overquota_total = MAITranscriptionUsage.objects(over_quota=True).count()
        transcriptions_overquota_daily = MAITranscriptionUsage.objects(
            over_quota=True, created_at__gte=last_day
        ).count()
        transcriptions_overquota_weekly = MAITranscriptionUsage.objects(
            over_quota=True, created_at__gte=last_week
        ).count()
        transcriptions_overquota_monthly = MAITranscriptionUsage.objects(
            over_quota=True, created_at__gte=last_month
        ).count()

        data["transcriptions_overquota_total"] = transcriptions_overquota_total
        data["transcriptions_overquota_daily"] = transcriptions_overquota_daily
        data["transcriptions_overquota_weekly"] = transcriptions_overquota_weekly
        data["transcriptions_overquota_monthly"] = transcriptions_overquota_monthly

        # Count unique users using transcriptions (all time and recent)
        unique_transcription_users = len(MAITranscriptionUsage.objects.distinct("user_id"))
        unique_transcription_users_daily = len(
            MAITranscriptionUsage.objects(created_at__gte=last_day).distinct("user_id")
        )
        unique_transcription_users_weekly = len(
            MAITranscriptionUsage.objects(created_at__gte=last_week).distinct("user_id")
        )
        unique_transcription_users_monthly = len(
            MAITranscriptionUsage.objects(created_at__gte=last_month).distinct("user_id")
        )

        data["transcriptions_unique_users"] = unique_transcription_users
        data["transcriptions_unique_users_daily"] = unique_transcription_users_daily
        data["transcriptions_unique_users_weekly"] = unique_transcription_users_weekly
        data["transcriptions_unique_users_monthly"] = unique_transcription_users_monthly

        # Count transcriptions by tier (recent month for better accuracy)
        transcription_entries = MAITranscriptionUsage.objects(created_at__gte=last_month).only(
            "user_id", "plan_tier", "over_quota"
        )

        transcriptions_by_tier = {"free": 0, "premium": 0, "archive": 0}
        transcriptions_overquota_by_tier = {"free": 0, "premium": 0, "archive": 0}
        transcription_users_by_tier = {"free": set(), "premium": set(), "archive": set()}

        for entry in transcription_entries:
            tier = entry.plan_tier or "free"
            # Normalize tier names
            if tier in ["archive", "pro"]:
                tier = "archive"
            elif tier == "premium":
                tier = "premium"
            else:
                tier = "free"

            transcriptions_by_tier[tier] += 1
            transcription_users_by_tier[tier].add(entry.user_id)

            if entry.over_quota:
                transcriptions_overquota_by_tier[tier] += 1

        # Store tier-specific counts
        data["transcriptions_free"] = transcriptions_by_tier["free"]
        data["transcriptions_premium"] = transcriptions_by_tier["premium"]
        data["transcriptions_archive"] = transcriptions_by_tier["archive"]

        data["transcriptions_overquota_free"] = transcriptions_overquota_by_tier["free"]
        data["transcriptions_overquota_premium"] = transcriptions_overquota_by_tier["premium"]
        data["transcriptions_overquota_archive"] = transcriptions_overquota_by_tier["archive"]

        # Store unique user counts by tier
        data["transcriptions_unique_free"] = len(transcription_users_by_tier["free"])
        data["transcriptions_unique_premium"] = len(transcription_users_by_tier["premium"])
        data["transcriptions_unique_archive"] = len(transcription_users_by_tier["archive"])

        # Calculate average transcription length (characters)
        transcription_lengths = []
        for entry in MAITranscriptionUsage.objects(created_at__gte=last_month).only("transcription_text"):
            if entry.transcription_text:
                transcription_lengths.append(len(entry.transcription_text))

        if transcription_lengths:
            avg_transcription_length = sum(transcription_lengths) / len(transcription_lengths)
        else:
            avg_transcription_length = 0

        data["transcriptions_avg_length"] = int(avg_transcription_length)

        # Format data for Prometheus
        chart_name = "ask_ai"
        chart_type = "counter"

        formatted_data = {}

        # Total requests
        formatted_data["requests_total"] = f'{chart_name}{{metric="requests_total"}} {data["requests_total"]}'

        # Requests by question type
        for question_id in [
            "sentence",
            "bullets",
            "paragraph",
            "context",
            "people",
            "arguments",
            "factcheck",
            "custom",
        ]:
            count = data[f"requests_{question_id}"]
            formatted_data[
                f"requests_{question_id}"
            ] = f'{chart_name}{{metric="requests",question_id="{question_id}"}} {count}'

        # Active users
        formatted_data[
            "active_users_daily"
        ] = f'{chart_name}{{metric="active_users",period="daily"}} {data["active_users_daily"]}'
        formatted_data[
            "active_users_weekly"
        ] = f'{chart_name}{{metric="active_users",period="weekly"}} {data["active_users_weekly"]}'
        formatted_data[
            "active_users_monthly"
        ] = f'{chart_name}{{metric="active_users",period="monthly"}} {data["active_users_monthly"]}'

        # Usage by tier
        for tier in ["free", "premium", "archive"]:
            formatted_data[
                f"tier_{tier}_using"
            ] = f'{chart_name}{{metric="tier_usage",tier="{tier}",status="using"}} {data[f"tier_{tier}_using"]}'
            formatted_data[
                f"tier_{tier}_at_limit"
            ] = f'{chart_name}{{metric="tier_usage",tier="{tier}",status="at_limit"}} {data[f"tier_{tier}_at_limit"]}'

        # Limit proximity distribution
        for tier in ["free", "premium", "archive"]:
            for bucket in ["0-20", "20-40", "40-60", "60-80", "80-100"]:
                key = f"limit_{tier}_{bucket}"
                formatted_data[
                    key
                ] = f'{chart_name}{{metric="limit_proximity",tier="{tier}",bucket="{bucket}"}} {data[key]}'

        # Request rate metrics
        formatted_data[
            "requests_daily"
        ] = f'{chart_name}{{metric="requests_rate",period="daily"}} {data["requests_daily"]}'
        formatted_data[
            "requests_weekly"
        ] = f'{chart_name}{{metric="requests_rate",period="weekly"}} {data["requests_weekly"]}'
        formatted_data[
            "requests_monthly"
        ] = f'{chart_name}{{metric="requests_rate",period="monthly"}} {data["requests_monthly"]}'

        # Over quota (denied) metrics
        formatted_data["denied_total"] = f'{chart_name}{{metric="denied_total"}} {data["denied_total"]}'
        formatted_data[
            "denied_daily"
        ] = f'{chart_name}{{metric="denied",period="daily"}} {data["denied_daily"]}'
        formatted_data[
            "denied_weekly"
        ] = f'{chart_name}{{metric="denied",period="weekly"}} {data["denied_weekly"]}'
        formatted_data[
            "denied_monthly"
        ] = f'{chart_name}{{metric="denied",period="monthly"}} {data["denied_monthly"]}'

        # Unique users hitting limits
        formatted_data[
            "denied_unique_users"
        ] = f'{chart_name}{{metric="denied_unique_users"}} {data["denied_unique_users"]}'

        # Denied by tier (monthly window)
        for tier in ["free", "premium", "archive"]:
            formatted_data[
                f"denied_{tier}"
            ] = f'{chart_name}{{metric="denied_by_tier",tier="{tier}"}} {data[f"denied_{tier}"]}'
            formatted_data[
                f"denied_unique_{tier}"
            ] = f'{chart_name}{{metric="denied_unique_by_tier",tier="{tier}"}} {data[f"denied_unique_{tier}"]}'

        # Transcription metrics
        formatted_data[
            "transcriptions_total"
        ] = f'{chart_name}{{metric="transcriptions_total"}} {data["transcriptions_total"]}'
        formatted_data[
            "transcriptions_daily"
        ] = f'{chart_name}{{metric="transcriptions",period="daily"}} {data["transcriptions_daily"]}'
        formatted_data[
            "transcriptions_weekly"
        ] = f'{chart_name}{{metric="transcriptions",period="weekly"}} {data["transcriptions_weekly"]}'
        formatted_data[
            "transcriptions_monthly"
        ] = f'{chart_name}{{metric="transcriptions",period="monthly"}} {data["transcriptions_monthly"]}'

        # Transcriptions over quota
        formatted_data[
            "transcriptions_overquota_total"
        ] = f'{chart_name}{{metric="transcriptions_overquota_total"}} {data["transcriptions_overquota_total"]}'
        formatted_data[
            "transcriptions_overquota_daily"
        ] = f'{chart_name}{{metric="transcriptions_overquota",period="daily"}} {data["transcriptions_overquota_daily"]}'
        formatted_data[
            "transcriptions_overquota_weekly"
        ] = f'{chart_name}{{metric="transcriptions_overquota",period="weekly"}} {data["transcriptions_overquota_weekly"]}'
        formatted_data[
            "transcriptions_overquota_monthly"
        ] = f'{chart_name}{{metric="transcriptions_overquota",period="monthly"}} {data["transcriptions_overquota_monthly"]}'

        # Unique transcription users
        formatted_data[
            "transcriptions_unique_users"
        ] = f'{chart_name}{{metric="transcriptions_unique_users"}} {data["transcriptions_unique_users"]}'
        formatted_data[
            "transcriptions_unique_users_daily"
        ] = f'{chart_name}{{metric="transcriptions_unique_users",period="daily"}} {data["transcriptions_unique_users_daily"]}'
        formatted_data[
            "transcriptions_unique_users_weekly"
        ] = f'{chart_name}{{metric="transcriptions_unique_users",period="weekly"}} {data["transcriptions_unique_users_weekly"]}'
        formatted_data[
            "transcriptions_unique_users_monthly"
        ] = f'{chart_name}{{metric="transcriptions_unique_users",period="monthly"}} {data["transcriptions_unique_users_monthly"]}'

        # Transcriptions by tier
        for tier in ["free", "premium", "archive"]:
            formatted_data[
                f"transcriptions_{tier}"
            ] = f'{chart_name}{{metric="transcriptions_by_tier",tier="{tier}"}} {data[f"transcriptions_{tier}"]}'
            formatted_data[
                f"transcriptions_overquota_{tier}"
            ] = f'{chart_name}{{metric="transcriptions_overquota_by_tier",tier="{tier}"}} {data[f"transcriptions_overquota_{tier}"]}'
            formatted_data[
                f"transcriptions_unique_{tier}"
            ] = f'{chart_name}{{metric="transcriptions_unique_by_tier",tier="{tier}"}} {data[f"transcriptions_unique_{tier}"]}'

        # Average transcription length
        formatted_data[
            "transcriptions_avg_length"
        ] = f'{chart_name}{{metric="transcriptions_avg_length"}} {data["transcriptions_avg_length"]}'

        context = {
            "data": formatted_data,
            "chart_name": chart_name,
            "chart_type": chart_type,
        }
        return render(request, "monitor/prometheus_data.html", context, content_type="text/plain")
