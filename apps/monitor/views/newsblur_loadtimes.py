from django.shortcuts import render
from django.views import View

class LoadTimes(View):

    def get(self, request):
        from apps.statistics.models import MStatistics
        
        data = {
            'feed_loadtimes_avg_hour': MStatistics.get('latest_avg_time_taken'),
            'feeds_loaded_hour': MStatistics.get('latest_sites_loaded'),
        }
        chart_name = "load_times"
        chart_type = "histogram"

        context = {
            "data": data,
            "chart_name": chart_name,
            "chart_type": chart_type,
        }
        return render(request, 'monitor/prometheus_data.html', context)

