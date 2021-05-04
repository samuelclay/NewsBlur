from django.views import View
from django.shortcuts import render
from apps.rss_feeds.models import MStory, MStarredStory
from apps.rss_feeds.models import MStory, MStarredStory
    
class Stories(View):

    def get(self, request):
        stories_count = MStatistics.get('munin:stories_count')
        if not stories_count:
            stories_count = MStory.objects.all().count()
            MStatistics.set('munin:stories_count', stories_count, 60*60*12)

        starred_stories_count = MStatistics.get('munin:starred_stories_count')
        if not starred_stories_count:
            starred_stories_count = MStarredStory.objects.all().count()
            MStatistics.set('munin:starred_stories_count', starred_stories_count, 60*60*12)

        data = {
            'stories': stories_count,
            'starred_stories': starred_stories_count,
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

