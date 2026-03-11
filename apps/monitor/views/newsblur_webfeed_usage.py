import time

from django.shortcuts import render
from django.views import View

from apps.statistics.rtrending_webfeeds import RTrendingWebFeed
from apps.webfeed.models import MWebFeedConfig


class WebFeedUsage(View):
    def get(self, request):
        """
        Prometheus metrics endpoint for web feed usage.

        Tracks analyses, subscriptions, hint refinements, variant selections,
        success/failure rates, and overall funnel conversion.
        """
        start_time = time.time()

        formatted_data = {}
        chart_name = "webfeed_usage"
        chart_type = "gauge"

        stats = RTrendingWebFeed.get_stats_for_prometheus()

        # Simple counters
        for key in [
            "analyses_today",
            "analyses_with_hint_today",
            "reanalyses_today",
            "subscriptions_today",
            "unique_urls_analyzed_today",
            "unique_urls_subscribed_today",
            "unique_users_analyzing_today",
            "unique_users_subscribing_today",
            "analysis_success_today",
            "analysis_fail_today",
            "conversion_rate_pct",
        ]:
            formatted_data[key] = f'{chart_name}{{metric="{key}"}} {stats[key]}'

        # Variant choices
        for variant_idx in range(5):
            count = stats["variant_choices"].get(str(variant_idx), 0)
            formatted_data[
                f"variant_{variant_idx}"
            ] = f'{chart_name}{{metric="variant_choice",variant="{variant_idx}"}} {count}'

        # Daily totals for 7-day chart
        daily_totals = RTrendingWebFeed.get_daily_totals(days=7)
        for date_str, analyses, subscriptions, unique_users in daily_totals:
            formatted_data[
                f"daily_analyses_{date_str}"
            ] = f'{chart_name}{{metric="daily_analyses",date="{date_str}"}} {analyses}'
            formatted_data[
                f"daily_subs_{date_str}"
            ] = f'{chart_name}{{metric="daily_subscriptions",date="{date_str}"}} {subscriptions}'
            formatted_data[
                f"daily_users_{date_str}"
            ] = f'{chart_name}{{metric="daily_unique_users",date="{date_str}"}} {unique_users}'

        # MongoDB counts for total active web feeds
        try:
            total_active = MWebFeedConfig.objects.count()
            needs_reanalysis = MWebFeedConfig.objects.filter(needs_reanalysis=True).count()
        except Exception:
            total_active = 0
            needs_reanalysis = 0

        formatted_data[
            "total_active_webfeeds"
        ] = f'{chart_name}{{metric="total_active_webfeeds"}} {total_active}'
        formatted_data[
            "webfeeds_needing_reanalysis"
        ] = f'{chart_name}{{metric="webfeeds_needing_reanalysis"}} {needs_reanalysis}'

        elapsed_ms = (time.time() - start_time) * 1000
        formatted_data["scrape_duration"] = f'{chart_name}{{metric="scrape_duration_ms"}} {elapsed_ms:.1f}'

        context = {
            "data": formatted_data,
            "chart_name": chart_name,
            "chart_type": chart_type,
        }
        return render(request, "monitor/prometheus_data.html", context, content_type="text/plain")
