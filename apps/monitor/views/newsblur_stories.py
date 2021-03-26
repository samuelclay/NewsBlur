from django.http import JsonResponse
from django.views import View
from apps.rss_feeds.models import MStory, MStarredStory

class Stories(View):

    def calculate_metrics(self, request):
        from apps.rss_feeds.models import MStory, MStarredStory

        return JsonResponse({
            'stories': MStory.objects.count(),
            'starred_stories': MStarredStory.objects.count(),
        })
