from django.shortcuts import render
from django.views import View

class LoadTimes(View):

    def get(self, request):
        from apps.statistics.models import MStatistics
        
        data = {
            'feed_loadtimes_1min': MStatistics.get('last_1_min_time_taken'),
            'feed_loadtimes_avg_hour': MStatistics.get('latest_avg_time_taken'),
            'feeds_loaded_hour': MStatistics.get('latest_sites_loaded'),
        }
        chart_name = "load_times"
        chart_type = "counter"

        formatted_data = {}
        for k, v in data.items():
            formatted_data[k] = f'{chart_name}{{category="{k}"}} {v}'

        context = {
            "data": formatted_data,
            "chart_name": chart_name,
            "chart_type": chart_type,
        }
        return render(request, 'monitor/prometheus_data.html', context, content_type="text/plain")

