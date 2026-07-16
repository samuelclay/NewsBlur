import datetime
import time

import redis
from django.conf import settings
from django.shortcuts import render
from django.views import View

from utils.domain_fetch_limiter import (
    RATE_LIMIT_KEY_PREFIX,
    THROTTLE_STATS_KEY_PREFIX,
    host_budget_per_minute,
)

# Cap the number of hosts exported per scrape to keep Prometheus label cardinality
# bounded: ~88k hosts get fetched per hour but only the hottest few dozen ever
# approach a budget. See utils/domain_fetch_limiter.py.
TOP_HOSTS = 30


class DomainFetch(View):
    def get(self, request):
        """
        Prometheus metrics endpoint for the per-domain fetch budget in
        utils/domain_fetch_limiter.py: current one-minute window attempts vs budget
        per host, plus deferral counts from the daily throttle stats hash.
        """
        start_time = time.time()

        chart_name = "domain_fetch"
        chart_type = "gauge"
        formatted_data = {}

        r = redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)

        def decoded(value):
            return value.decode() if isinstance(value, bytes) else value

        # Current one-minute window: attempts per host, hottest first
        attempts = []
        for key in r.scan_iter(match=RATE_LIMIT_KEY_PREFIX + "*", count=1000):
            host = decoded(key)[len(RATE_LIMIT_KEY_PREFIX) :]
            count = int(r.get(key) or 0)
            attempts.append((count, host))
        attempts.sort(reverse=True)

        for count, host in attempts[:TOP_HOSTS]:
            formatted_data[f"attempts_{host}"] = f'{chart_name}{{metric="attempts",host="{host}"}} {count}'
            formatted_data[
                f"budget_{host}"
            ] = f'{chart_name}{{metric="budget",host="{host}"}} {host_budget_per_minute(host)}'

        # Today's deferrals per host. These reset to zero at midnight UTC, which
        # PromQL rate()/increase() treat as a counter reset.
        today = datetime.datetime.utcnow().strftime("%Y%m%d")
        throttled = {decoded(k): int(v) for k, v in r.hgetall(THROTTLE_STATS_KEY_PREFIX + today).items()}
        ranked = sorted(throttled.items(), key=lambda kv: kv[1], reverse=True)
        for host, count in ranked[:TOP_HOSTS]:
            formatted_data[
                f"throttled_{host}"
            ] = f'{chart_name}{{metric="throttled_today",host="{host}"}} {count}'
            if f"budget_{host}" not in formatted_data:
                formatted_data[
                    f"budget_{host}"
                ] = f'{chart_name}{{metric="budget",host="{host}"}} {host_budget_per_minute(host)}'

        formatted_data[
            "total_throttled_today"
        ] = f'{chart_name}{{metric="total_throttled_today"}} {sum(throttled.values())}'
        formatted_data[
            "hosts_throttled_today"
        ] = f'{chart_name}{{metric="hosts_throttled_today"}} {len(throttled)}'
        formatted_data["active_domains"] = f'{chart_name}{{metric="active_domains"}} {len(attempts)}'

        elapsed_ms = (time.time() - start_time) * 1000
        formatted_data["scrape_duration"] = f'{chart_name}{{metric="scrape_duration_ms"}} {elapsed_ms:.1f}'

        context = {
            "data": formatted_data,
            "chart_name": chart_name,
            "chart_type": chart_type,
        }
        return render(request, "monitor/prometheus_data.html", context, content_type="text/plain")
