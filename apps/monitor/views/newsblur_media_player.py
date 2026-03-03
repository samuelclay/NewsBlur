import datetime

from django.shortcuts import render
from django.views import View

from apps.media_player.models import MMediaPlaybackState


class MediaPlayer(View):
    def get(self, request):
        """
        Prometheus metrics endpoint for media player usage tracking.

        Queries MongoDB directly for:
        - Total media player states (= unique users ever)
        - Active users by period (daily/weekly/monthly)
        - Media type breakdown (audio/video/youtube)
        """
        now = datetime.datetime.now()
        day_ago = now - datetime.timedelta(days=1)
        week_ago = now - datetime.timedelta(days=7)
        month_ago = now - datetime.timedelta(days=30)

        chart_name = "media_player"
        chart_type = "gauge"

        formatted_data = {}

        total_states = MMediaPlaybackState.objects.count()
        formatted_data["total_states"] = f'{chart_name}{{metric="total_states"}} {total_states}'

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
        ] = f'{chart_name}{{metric="active_users",period="alltime"}} {total_states}'

        audio_count = MMediaPlaybackState.objects.filter(current_media_type="audio").count()
        video_count = MMediaPlaybackState.objects.filter(current_media_type="video").count()
        youtube_count = MMediaPlaybackState.objects.filter(current_media_type="youtube").count()

        formatted_data[
            "media_type_audio"
        ] = f'{chart_name}{{metric="media_type",type="audio"}} {audio_count}'
        formatted_data[
            "media_type_video"
        ] = f'{chart_name}{{metric="media_type",type="video"}} {video_count}'
        formatted_data[
            "media_type_youtube"
        ] = f'{chart_name}{{metric="media_type",type="youtube"}} {youtube_count}'

        context = {
            "data": formatted_data,
            "chart_name": chart_name,
            "chart_type": chart_type,
        }
        return render(request, "monitor/prometheus_data.html", context, content_type="text/plain")
