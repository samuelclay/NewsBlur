from django.shortcuts import render
from django.views import View

from apps.statistics.rclustering_usage import RClusteringUsage


class Clustering(View):
    def get(self, request):
        """
        Prometheus metrics endpoint for story clustering usage.

        Tracks:
        - Unique clusters (daily/weekly/monthly/alltime) - deduplicated via Redis SETs
        - Unique stories clustered (daily/weekly/monthly/alltime) - deduplicated via Redis SETs
        - Cluster mark-read expanded stories (daily/weekly/monthly/alltime)
        - Average clustering time in ms (daily/weekly/monthly/alltime)
        """
        daily_stats = RClusteringUsage.get_period_stats(days=1)
        weekly_stats = RClusteringUsage.get_period_stats(days=7)
        monthly_stats = RClusteringUsage.get_period_stats(days=30)
        alltime_stats = RClusteringUsage.get_alltime_stats()

        chart_name = "clustering"
        chart_type = "gauge"

        formatted_data = {}

        for metric in RClusteringUsage.METRICS:
            formatted_data[f"{metric}_daily"] = (
                f'{chart_name}{{metric="{metric}",period="daily"}} {daily_stats[metric]}'
            )
            formatted_data[f"{metric}_weekly"] = (
                f'{chart_name}{{metric="{metric}",period="weekly"}} {weekly_stats[metric]}'
            )
            formatted_data[f"{metric}_monthly"] = (
                f'{chart_name}{{metric="{metric}",period="monthly"}} {monthly_stats[metric]}'
            )
            formatted_data[f"{metric}_alltime"] = (
                f'{chart_name}{{metric="{metric}",period="alltime"}} {alltime_stats[metric]}'
            )

        timing_metric = "cluster_time_avg_ms"
        for period, stats in [("daily", daily_stats), ("weekly", weekly_stats), ("monthly", monthly_stats), ("alltime", alltime_stats)]:
            formatted_data[f"{timing_metric}_{period}"] = (
                f'{chart_name}{{metric="{timing_metric}",period="{period}"}} {stats[timing_metric]}'
            )

        context = {
            "data": formatted_data,
            "chart_name": chart_name,
            "chart_type": chart_type,
        }
        return render(request, "monitor/prometheus_data.html", context, content_type="text/plain")
