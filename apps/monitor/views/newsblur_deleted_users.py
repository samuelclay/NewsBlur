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
        archive_total = MDeletedUser.objects.filter(is_archive=True).count()
        pro_total = MDeletedUser.objects.filter(is_pro=True).count()
        free_total = MDeletedUser.objects.filter(is_premium=False).count()

        # Average stats
        pipeline = [
            {
                "$group": {
                    "_id": None,
                    "avg_feeds": {"$avg": "$feeds_count"},
                    "avg_payments": {"$avg": "$total_payments"},
                    "avg_read_stories": {"$avg": "$read_story_count"},
                    "avg_starred": {"$avg": "$starred_stories_count"},
                    "total_revenue_lost": {"$sum": "$total_payments"},
                }
            }
        ]
        stats = list(MDeletedUser.objects.aggregate(pipeline))
        if stats:
            avg_feeds = stats[0].get("avg_feeds", 0) or 0
            avg_payments = stats[0].get("avg_payments", 0) or 0
            avg_read_stories = stats[0].get("avg_read_stories", 0) or 0
            avg_starred = stats[0].get("avg_starred", 0) or 0
            total_revenue_lost = stats[0].get("total_revenue_lost", 0) or 0
        else:
            avg_feeds = 0
            avg_payments = 0
            avg_read_stories = 0
            avg_starred = 0
            total_revenue_lost = 0

        data = {
            "total": total,
            "daily": daily,
            "weekly": weekly,
            "monthly": monthly,
            "premium": premium_total,
            "archive": archive_total,
            "pro": pro_total,
            "free": free_total,
            "avg_feeds": round(avg_feeds, 1),
            "avg_payments": round(avg_payments, 2),
            "avg_read_stories": round(avg_read_stories, 0),
            "avg_starred": round(avg_starred, 1),
            "total_revenue_lost": total_revenue_lost,
        }

        chart_name = "deleted_users"
        chart_type = "gauge"

        formatted_data = {}
        for k, v in data.items():
            formatted_data[k] = f'{chart_name}{{category="{k}"}} {v}'

        context = {
            "data": formatted_data,
            "chart_name": chart_name,
            "chart_type": chart_type,
        }
        return render(request, "monitor/prometheus_data.html", context, content_type="text/plain")
