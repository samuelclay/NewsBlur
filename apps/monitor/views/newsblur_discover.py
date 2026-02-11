from django.shortcuts import render
from django.views import View

from apps.statistics.rdiscover_usage import RDiscoverUsage


class Discover(View):
    def get(self, request):
        """
        Prometheus metrics endpoint for discover usage tracking.

        Tracks discover feeds and discover stories requests
        with daily, weekly, monthly, and all-time counts plus unique users.
        """
        daily_stats = RDiscoverUsage.get_period_stats(days=1)
        weekly_stats = RDiscoverUsage.get_period_stats(days=7)
        monthly_stats = RDiscoverUsage.get_period_stats(days=30)
        alltime_stats = RDiscoverUsage.get_alltime_stats()

        chart_name = "discover"
        chart_type = "gauge"

        formatted_data = {}

        # Request counts by type and period
        for discover_type in ["feeds", "stories"]:
            daily = daily_stats[discover_type]["requests"]
            weekly = weekly_stats[discover_type]["requests"]
            monthly = monthly_stats[discover_type]["requests"]
            alltime = alltime_stats[discover_type]

            formatted_data[
                f"requests_{discover_type}_daily"
            ] = f'{chart_name}{{metric="requests",type="{discover_type}",period="daily"}} {daily}'
            formatted_data[
                f"requests_{discover_type}_weekly"
            ] = f'{chart_name}{{metric="requests",type="{discover_type}",period="weekly"}} {weekly}'
            formatted_data[
                f"requests_{discover_type}_monthly"
            ] = f'{chart_name}{{metric="requests",type="{discover_type}",period="monthly"}} {monthly}'
            formatted_data[
                f"requests_{discover_type}_alltime"
            ] = f'{chart_name}{{metric="requests",type="{discover_type}",period="alltime"}} {alltime}'

        # Unique users by type and period
        for discover_type in ["feeds", "stories"]:
            daily_users = RDiscoverUsage.get_unique_users_for_period(discover_type, days=1)
            weekly_users = RDiscoverUsage.get_unique_users_for_period(discover_type, days=7)
            monthly_users = RDiscoverUsage.get_unique_users_for_period(discover_type, days=30)
            alltime_users = RDiscoverUsage.get_alltime_unique_users(discover_type)

            formatted_data[
                f"unique_users_{discover_type}_daily"
            ] = f'{chart_name}{{metric="unique_users",type="{discover_type}",period="daily"}} {daily_users}'
            formatted_data[
                f"unique_users_{discover_type}_weekly"
            ] = f'{chart_name}{{metric="unique_users",type="{discover_type}",period="weekly"}} {weekly_users}'
            formatted_data[
                f"unique_users_{discover_type}_monthly"
            ] = f'{chart_name}{{metric="unique_users",type="{discover_type}",period="monthly"}} {monthly_users}'
            formatted_data[
                f"unique_users_{discover_type}_alltime"
            ] = f'{chart_name}{{metric="unique_users",type="{discover_type}",period="alltime"}} {alltime_users}'

        context = {
            "data": formatted_data,
            "chart_name": chart_name,
            "chart_type": chart_type,
        }
        return render(request, "monitor/prometheus_data.html", context, content_type="text/plain")
