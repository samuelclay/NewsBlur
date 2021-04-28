from django.shortcuts import render
from django.views import View

from apps.statistics.models import MStatistics

class Errors(View):

    def get(self, request):
        statistics = MStatistics.all()
        data = {
            'feed_success': statistics['feeds_fetched'],
        }
        return render(request, 'monitor/prometheus_data.html', {"data": data})

