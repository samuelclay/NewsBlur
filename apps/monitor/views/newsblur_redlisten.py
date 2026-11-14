import json

import redis
from django.conf import settings
from django.shortcuts import render
from django.views import View

from utils.redlisten import POLLER, SPEND_KINDS, RedListenBudget
from utils.redlisten_poller import LAST_POLL_KEY

# Fields of the latest poll summary (utils/redlisten_poller.py) exported as gauges.
POLL_FIELDS = (
    "targets",
    "polled_targets",
    "capped_targets",
    "batches",
    "polled_batches",
    "result_budget",
    "request_budget",
    "set_aside_requests",
    "set_aside_results",
    "expected_results",
    "spent_results",
    "spent_requests",
    "scheduled_feeds",
    "seconds",
)


class RedListen(View):
    def get(self, request):
        """
        Prometheus metrics for the RedListen Reddit budget (utils/redlisten.py): this
        month's requests and results against the plan and the 99% background cap,
        today's and the last 24 hours' spend by the poller, scheduled feed fetches and
        one-offs, the month-end projection at that pace, and the latest hourly poll
        (utils/redlisten_poller.py).
        """
        chart_name = "redlisten"
        formatted_data = {}

        r = redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)
        budget = RedListenBudget(r=r)
        usage = budget.usage()
        # The poller and scheduled feed fetches share the background cap.
        background_requests, background_results = budget.caps(POLLER, usage)
        monthly = {
            "requests_used": usage["requests"],
            "results_used": usage["results"],
            "requests_limit": usage["request_limit"],
            "results_limit": usage["result_limit"],
            "requests_background_cap": background_requests,
            "results_background_cap": background_results,
        }
        for name, value in monthly.items():
            formatted_data[name] = f'{chart_name}{{metric="{name}"}} {value}'

        spend = budget.spend()
        for kind in SPEND_KINDS:
            for unit in ("requests", "results"):
                value = spend["%s_%s" % (kind, unit)]
                formatted_data[
                    f"today_{kind}_{unit}"
                ] = f'{chart_name}{{metric="today_{unit}",kind="{kind}"}} {value}'
            # Rolling 24 hours, the pace the poller sets aside for (utils/redlisten_poller.py).
            last_day_requests, last_day_results = budget.last_day_spend(kind)
            formatted_data[
                f"last_day_{kind}_requests"
            ] = f'{chart_name}{{metric="last_day_requests",kind="{kind}"}} {last_day_requests:.0f}'
            formatted_data[
                f"last_day_{kind}_results"
            ] = f'{chart_name}{{metric="last_day_results",kind="{kind}"}} {last_day_results:.0f}'

        projected_requests, projected_results = budget.projected_month()
        formatted_data[
            "projected_month_requests"
        ] = f'{chart_name}{{metric="projected_month_requests"}} {projected_requests:.0f}'
        formatted_data[
            "projected_month_results"
        ] = f'{chart_name}{{metric="projected_month_results"}} {projected_results:.0f}'

        try:
            last_poll = json.loads(r.get(LAST_POLL_KEY) or "{}")
        except ValueError:
            last_poll = {}
        for field in POLL_FIELDS:
            if field in last_poll:
                formatted_data[f"poll_{field}"] = f'{chart_name}{{metric="poll_{field}"}} {last_poll[field]}'
        if "polled_at" in last_poll:
            formatted_data[
                "poll_polled_at"
            ] = f'{chart_name}{{metric="poll_polled_at"}} {last_poll["polled_at"]}'

        context = {
            "data": formatted_data,
            "chart_name": chart_name,
            "chart_type": "gauge",
        }
        return render(request, "monitor/prometheus_data.html", context, content_type="text/plain")
