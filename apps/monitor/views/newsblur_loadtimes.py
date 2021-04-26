from django.http import JsonResponse
from django.views import View

class LoadTimes(View):

    def get(self, request):
        from apps.statistics.models import MStatistics
        
        return JsonResponse({
            'feed_loadtimes_avg_hour': MStatistics.get('latest_avg_time_taken'),
            'feeds_loaded_hour': MStatistics.get('latest_sites_loaded'),
        })
