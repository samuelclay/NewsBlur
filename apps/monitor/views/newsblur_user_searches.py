from django.shortcuts import render
from django.views import View

from apps.search.models import MUserSearch


class UserSearches(View):
    def get(self, request):
        data = {
            "total": MUserSearch.objects.count(),
            "subscriptions_indexed": MUserSearch.objects.filter(subscriptions_indexed=True).count(),
            "subscriptions_indexing": MUserSearch.objects.filter(subscriptions_indexing=True).count(),
            "discover_indexed": MUserSearch.objects.filter(discover_indexed=True).count(),
            "discover_indexing": MUserSearch.objects.filter(discover_indexing=True).count(),
        }

        chart_name = "user_searches"
        chart_type = "counter"

        formatted_data = {}
        for k, v in data.items():
            formatted_data[k] = f'{chart_name}{{status="{k}"}} {v}'

        context = {
            "data": formatted_data,
            "chart_name": chart_name,
            "chart_type": chart_type,
        }
        return render(request, "monitor/prometheus_data.html", context, content_type="text/plain")
