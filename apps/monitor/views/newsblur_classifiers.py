from django.views import View
from django.shortcuts import render
from apps.analyzer.models import MClassifierFeed, MClassifierAuthor, MClassifierTag, MClassifierTitle


class Classifiers(View):

    def get(self, request):
        data = {
            'feeds': MClassifierFeed.objects._collection.count(),
            'authors': MClassifierAuthor.objects._collection.count(),
            'tags': MClassifierTag.objects._collection.count(),
            'titles': MClassifierTitle.objects._collection.count(),
        }

        chart_name = "classifiers"
        chart_type = "counter"

        formatted_data = {}
        for k, v in data.items():
            formatted_data[k] = f'{chart_name}{{classifier="{k}"}} {v}'
        context = {
            "data": formatted_data,
            "chart_name": chart_name,
            "chart_type": chart_type,
        }
        return render(request, 'monitor/prometheus_data.html', context, content_type="text/plain")

