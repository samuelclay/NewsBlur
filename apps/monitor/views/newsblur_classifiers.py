from django.views import View
from django.shortcuts import render
from apps.analyzer.models import MClassifierFeed, MClassifierAuthor, MClassifierTag, MClassifierTitle


class Classifiers(View):

    def get(self, request):
        data = {
            'feeds': MClassifierFeed.objects.count(),
            'authors': MClassifierAuthor.objects.count(),
            'tags': MClassifierTag.objects.count(),
            'titles': MClassifierTitle.objects.count(),
        }

        return render(request, 'monitor/prometheus_data.html', {"data": data})

