from django.shortcuts import render
from django.views import View

from apps.statistics.rmcp_usage import RMCPUsage


class MCPUsage(View):
    def get(self, request):
        """
        Prometheus metrics endpoint for MCP usage tracking.

        Tracks total MCP tool/resource invocations and unique users with daily,
        weekly, and all-time counts.
        """
        daily_stats = RMCPUsage.get_period_stats(days=1)
        weekly_stats = RMCPUsage.get_period_stats(days=7)
        alltime_stats = RMCPUsage.get_alltime_stats()

        chart_name = "mcp_usage"
        chart_type = "gauge"

        formatted_data = {}

        for metric in RMCPUsage.METRICS:
            formatted_data[
                f"{metric}_daily"
            ] = f'{chart_name}{{metric="{metric}",period="daily"}} {daily_stats[metric]}'
            formatted_data[
                f"{metric}_weekly"
            ] = f'{chart_name}{{metric="{metric}",period="weekly"}} {weekly_stats[metric]}'
            formatted_data[
                f"{metric}_alltime"
            ] = f'{chart_name}{{metric="{metric}",period="alltime"}} {alltime_stats[metric]}'

        context = {
            "data": formatted_data,
            "chart_name": chart_name,
            "chart_type": chart_type,
        }
        return render(request, "monitor/prometheus_data.html", context, content_type="text/plain")
