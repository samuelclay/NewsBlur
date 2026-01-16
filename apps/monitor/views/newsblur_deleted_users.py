import datetime

from django.shortcuts import render
from django.views import View

from apps.profile.models import MDeletedUser


class DeletedUsers(View):
    def get(self, request):
        now = datetime.datetime.utcnow()
        last_day = now - datetime.timedelta(days=1)
        last_week = now - datetime.timedelta(days=7)
        last_month = now - datetime.timedelta(days=30)

        # Total counts
        total = MDeletedUser.objects.count()
        daily = MDeletedUser.objects.filter(date_deleted__gte=last_day).count()
        weekly = MDeletedUser.objects.filter(date_deleted__gte=last_week).count()
        monthly = MDeletedUser.objects.filter(date_deleted__gte=last_month).count()

        # Premium breakdown
        premium_total = MDeletedUser.objects.filter(is_premium=True).count()

        data = {
            "total": total,
            "daily": daily,
            "weekly": weekly,
            "monthly": monthly,
            "premium": premium_total,
        }

        chart_name = "deleted_users"
        chart_type = "gauge"

        formatted_data = {}
        for k, v in data.items():
            formatted_data[k] = f'{chart_name}{{category="{k}"}} {v}'

        # Add individual deleted user entries (last 20)
        recent_users = MDeletedUser.objects.order_by("-date_deleted")[:20]
        for i, user in enumerate(recent_users):
            tier = "free"
            if user.is_pro:
                tier = "pro"
            elif user.is_archive:
                tier = "archive"
            elif user.is_premium and user.is_premium_trial:
                tier = "premium trial"
            elif user.is_premium:
                tier = "premium"

            def format_date(dt):
                if dt:
                    return dt.strftime("%Y-%m-%d %H:%M")
                return ""

            def escape_label(val):
                if val is None:
                    return ""
                return str(val).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")

            def format_duration(joined, deleted):
                if not joined or not deleted:
                    return "", 0
                delta = deleted - joined
                days = delta.days
                if days < 1:
                    hours = delta.seconds // 3600
                    return f"{hours} hours", days
                elif days < 7:
                    return f"{days} days", days
                elif days < 30:
                    weeks = days // 7
                    return f"{weeks} weeks", days
                elif days < 365:
                    months = days // 30
                    return f"{months} months", days
                else:
                    years = days // 365
                    remaining_months = (days % 365) // 30
                    if remaining_months > 0:
                        return f"{years}y {remaining_months}m", days
                    return f"{years} years", days

            duration_str, days_active = format_duration(user.date_joined, user.date_deleted)

            labels = [
                f'username="{escape_label(user.username)}"',
                f'email="{escape_label(user.email)}"',
                f'date_joined="{format_date(user.date_joined)}"',
                f'date_deleted="{format_date(user.date_deleted)}"',
                f'duration="{duration_str}"',
                f'days_active="{days_active}"',
                f'last_seen="{format_date(user.last_seen_on)}"',
                f'tier="{tier}"',
                f'feeds="{user.feeds_count or 0}"',
                f'stories_read="{user.read_story_count or 0}"',
                f'starred="{user.starred_stories_count or 0}"',
                f'shared="{user.shared_stories_count or 0}"',
                f'payments="{user.total_payments or 0}"',
                f'payment_count="{user.payment_count or 0}"',
                f'followers="{user.follower_count or 0}"',
                f'following="{user.following_count or 0}"',
            ]
            formatted_data[f"user_{i}"] = f'deleted_user_entry{{{",".join(labels)}}} 1'

        context = {
            "data": formatted_data,
            "chart_name": chart_name,
            "chart_type": chart_type,
        }
        return render(request, "monitor/prometheus_data.html", context, content_type="text/plain")
