from django.views import View
from django.shortcuts import render
from apps.rss_feeds.models import MStory, MStarredStory
from apps.rss_feeds.models import MStory, MStarredStory
    
class Stories(View):

    def get(self, request):
        data = {
            'stories': MStory.objects._collection.count(),
            'starred_stories': MStarredStory.objects._collection.count(),
        }
        chart_name = "stories"
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

