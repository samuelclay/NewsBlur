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
        return render(request, 'monitor/prometheus_data.html', {"data": data})

