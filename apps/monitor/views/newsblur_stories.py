from django.views import View
from django.shortcuts import render
from apps.rss_feeds.models import MStory, MStarredStory
from apps.rss_feeds.models import MStory, MStarredStory
    
class Stories(View):

    def get(self, request):
        data = {
            'stories': MStory.objects.count(),
            'starred_stories': MStarredStory.objects.count(),
        }
        chart_name = "stories"
        chart_type = "counter"

        context = {
            "data": data,
            "chart_name": chart_name,
            "chart_type": chart_type,
        }
        return render(request, 'monitor/prometheus_data.html', context, content_type="text/plain")

