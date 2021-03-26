from django.views import View
from django.http import JsonResponse
from apps.analyzer.models import MClassifierFeed, MClassifierAuthor, MClassifierTag, MClassifierTitle


class Classifiers(View):

    def get(self, request):
        return JsonResponse({
            'feeds': MClassifierFeed.objects.count(),
            'authors': MClassifierAuthor.objects.count(),
            'tags': MClassifierTag.objects.count(),
            'titles': MClassifierTitle.objects.count(),
        })

