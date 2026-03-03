import datetime

from django.shortcuts import render
from django.views import View

from apps.media_player.models import MMediaPlaybackState


class MediaPlayer(View):
    def get(self, request):
        """
        Prometheus metrics endpoint for media player usage tracking.

        Three metric groups:
        - Cumulative total plays by type (always goes up)
        - Instantaneous active states (current row count)
        - Unique users by period (daily/weekly/monthly/alltime)
        """
        now = datetime.datetime.now()
        day_ago = now - datetime.timedelta(days=1)
        week_ago = now - datetime.timedelta(days=7)
        month_ago = now - datetime.timedelta(days=30)

        chart_name = "media_player"
        chart_type = "gauge"

        formatted_data = {}

        # Cumulative total plays by type (sum across all users)
        pipeline = [
            {
                "$group": {
                    "_id": None,
                    "audio": {"$sum": "$total_audio_plays"},
                    "video": {"$sum": "$total_video_plays"},
                    "youtube": {"$sum": "$total_youtube_plays"},
                }
            }
        ]
        result = list(MMediaPlaybackState.objects.aggregate(*pipeline))
        if result:
            totals = result[0]
        else:
            totals = {"audio": 0, "video": 0, "youtube": 0}

        formatted_data[
            "total_plays_audio"
        ] = f'{chart_name}{{metric="total_plays",type="audio"}} {totals.get("audio", 0)}'
        formatted_data[
            "total_plays_video"
        ] = f'{chart_name}{{metric="total_plays",type="video"}} {totals.get("video", 0)}'
        formatted_data[
            "total_plays_youtube"
        ] = f'{chart_name}{{metric="total_plays",type="youtube"}} {totals.get("youtube", 0)}'

        # Instantaneous: users with something currently loaded
        active_states = MMediaPlaybackState.objects.filter(current_media_url__ne="").count()
        formatted_data["active_states"] = f'{chart_name}{{metric="active_states"}} {active_states}'

        # Unique users by period
        daily_active = MMediaPlaybackState.objects.filter(updated_at__gte=day_ago).count()
        weekly_active = MMediaPlaybackState.objects.filter(updated_at__gte=week_ago).count()
        monthly_active = MMediaPlaybackState.objects.filter(updated_at__gte=month_ago).count()

        formatted_data[
            "active_users_daily"
        ] = f'{chart_name}{{metric="active_users",period="daily"}} {daily_active}'
        formatted_data[
            "active_users_weekly"
        ] = f'{chart_name}{{metric="active_users",period="weekly"}} {weekly_active}'
        formatted_data[
            "active_users_monthly"
        ] = f'{chart_name}{{metric="active_users",period="monthly"}} {monthly_active}'
        formatted_data[
            "active_users_alltime"
        ] = f'{chart_name}{{metric="active_users",period="alltime"}} {active_states}'

        context = {
            "data": formatted_data,
            "chart_name": chart_name,
            "chart_type": chart_type,
        }
        return render(request, "monitor/prometheus_data.html", context, content_type="text/plain")
