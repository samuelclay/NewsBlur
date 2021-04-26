from django.http import JsonResponse
from django.views import View

from apps.statistics.models import MStatistics

class Errors(View):

    def get(self, request):
        statistics = MStatistics.all()
    
        return JsonResponse({
            'feed_success': statistics['feeds_fetched'],
        })

