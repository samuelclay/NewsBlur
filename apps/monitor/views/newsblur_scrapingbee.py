import time

from django.shortcuts import render
from django.views import View

from apps.statistics.rscrapingbee import RScrapingBee


class ScrapingBeeUsage(View):
    def get(self, request):
        """
        Prometheus metrics endpoint for ScrapingBee proxy usage, backed by
        apps/statistics/rscrapingbee.py: today's requests by call site and result, credits
        charged, the hungriest target domains, a 7-day history, and the account's credits
        used vs plan from ScrapingBee's usage API so Grafana can show burn rate and the
        credits per day that are left before renewal.
        """
        start_time = time.time()

        formatted_data = {}
        chart_name = "scrapingbee_usage"
        chart_type = "gauge"

        stats = RScrapingBee.get_stats_for_prometheus()

        # Requests today by call site (feed, discovery, original_story, original_text, webfeed,
        # webfeed_preview) and result. Only 200 and 404 cost credits; 500 means the site blocked
        # the proxy too.
        for (source, status), count in sorted(stats["calls"].items()):
            formatted_data[
                f"calls_{source}_{status}"
            ] = f'{chart_name}{{metric="calls_today",source="{source}",status="{status}"}} {count}'
        formatted_data[
            "calls_today_total"
        ] = f'{chart_name}{{metric="calls_today_total"}} {stats["calls_today"]}'

        for source, credits in sorted(stats["credits"].items()):
            formatted_data[
                f"credits_{source}"
            ] = f'{chart_name}{{metric="credits_today",source="{source}"}} {credits}'
        formatted_data[
            "credits_today_total"
        ] = f'{chart_name}{{metric="credits_today_total"}} {stats["credits_today"]}'

        # Per-host daily credit cap and how many hosts have hit it, see RScrapingBee.host_over_budget
        formatted_data[
            "host_credit_cap"
        ] = f'{chart_name}{{metric="host_credit_cap"}} {stats["host_credit_cap"]}'
        formatted_data[
            "hosts_over_cap"
        ] = f'{chart_name}{{metric="hosts_over_cap"}} {stats["hosts_over_cap"]}'

        # Per-user share of the plan for this billing period, see RScrapingBee.user_period_budget
        formatted_data["user_budget"] = f'{chart_name}{{metric="user_budget"}} {stats["user_budget"]}'
        formatted_data[
            "users_charged_period"
        ] = f'{chart_name}{{metric="users_charged_period"}} {stats["users_charged_period"]}'
        formatted_data[
            "users_over_budget"
        ] = f'{chart_name}{{metric="users_over_budget"}} {stats["users_over_budget"]}'
        formatted_data[
            "users_charged_7d"
        ] = f'{chart_name}{{metric="users_charged_7d"}} {stats["users_charged_7d"]}'

        # Hungriest target hosts today, capped in RScrapingBee.TOP_DOMAINS to bound label cardinality
        for host, credits, requests_count in stats["top_domains"]:
            formatted_data[
                f"domain_credits_{host}"
            ] = f'{chart_name}{{metric="domain_credits",host="{host}"}} {credits}'
            formatted_data[
                f"domain_requests_{host}"
            ] = f'{chart_name}{{metric="domain_requests",host="{host}"}} {requests_count}'

        for date_str, calls, credits in RScrapingBee.get_daily_totals(days=7):
            formatted_data[
                f"daily_calls_{date_str}"
            ] = f'{chart_name}{{metric="daily_calls",date="{date_str}"}} {calls}'
            formatted_data[
                f"daily_credits_{date_str}"
            ] = f'{chart_name}{{metric="daily_credits",date="{date_str}"}} {credits}'

        # Account-level numbers from ScrapingBee's usage API (cached 5 minutes)
        usage = RScrapingBee.get_account_usage()
        if usage:
            formatted_data["credits_used"] = f'{chart_name}{{metric="credits_used"}} {usage["used"]}'
            formatted_data["credits_max"] = f'{chart_name}{{metric="credits_max"}} {usage["max"]}'
            formatted_data[
                "credits_remaining"
            ] = f'{chart_name}{{metric="credits_remaining"}} {usage["remaining"]}'
            formatted_data[
                "credits_used_pct"
            ] = f'{chart_name}{{metric="credits_used_pct"}} {usage["used_pct"]}'
            formatted_data[
                "days_to_renewal"
            ] = f'{chart_name}{{metric="days_to_renewal"}} {usage["days_to_renewal"]}'
            formatted_data["concurrency"] = f'{chart_name}{{metric="concurrency"}} {usage["concurrency"]}'
            # How many credits a day the plan can still afford until it renews
            days_to_renewal = usage.get("days_to_renewal") or 0
            credits_per_day = (
                int(usage["remaining"] / days_to_renewal) if days_to_renewal else usage["remaining"]
            )
            formatted_data[
                "credits_per_day_remaining"
            ] = f'{chart_name}{{metric="credits_per_day_remaining"}} {credits_per_day}'

        elapsed_ms = (time.time() - start_time) * 1000
        formatted_data["scrape_duration"] = f'{chart_name}{{metric="scrape_duration_ms"}} {elapsed_ms:.1f}'

        context = {
            "data": formatted_data,
            "chart_name": chart_name,
            "chart_type": chart_type,
        }
        return render(request, "monitor/prometheus_data.html", context, content_type="text/plain")
