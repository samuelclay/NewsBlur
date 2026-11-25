"""Registered application traffic for the NewsBlur OAuth Grafana dashboard."""

import hmac
import time
from datetime import timedelta
from pathlib import Path

from django.conf import settings
from django.http import HttpResponse
from django.utils import timezone
from oauth2_provider.models import get_application_model
from prometheus_client import CollectorRegistry, generate_latest
from prometheus_client.core import CounterMetricFamily, GaugeMetricFamily
from prometheus_client.exposition import CONTENT_TYPE_LATEST

from apps.oauth.traffic import application_usage


class ApplicationMetrics:
    def collect(self):
        requests = CounterMetricFamily(
            "newsblur_oauth_requests",
            "Requests authenticated using an application access token.",
            labels=["app_id", "app_name"],
        )
        cutoff = timezone.now() - timedelta(days=1)
        now = int(time.time())
        active = new = 0
        apps = list(get_application_model().objects.values_list("pk", "name", "created"))
        readers = GaugeMetricFamily(
            "newsblur_oauth_readers_week",
            "Estimated distinct readers in the current and previous six UTC days.",
            labels=["app_id", "app_name"],
        )
        usage = application_usage([pk for pk, _, _ in apps])
        for pk, name, created in apps:
            app_id = str(pk)
            readers.add_metric([app_id, name], usage[pk]["readers"])
            requests.add_metric([app_id, name], usage[pk]["requests"])
            if created >= cutoff:
                new += 1
            if (usage[pk]["last_used"] or 0) >= now - 86400:
                active += 1
        yield readers
        yield requests
        yield GaugeMetricFamily(
            "newsblur_oauth_applications_active_24h", "Apps used in the past day.", active
        )
        yield GaugeMetricFamily(
            "newsblur_oauth_applications_created_24h", "Apps created in the past day.", new
        )


def usage_metrics(request):
    token = getattr(settings, "OAUTH_METRICS_TOKEN", "")
    if not token:
        try:
            token = (Path(settings.BASE_DIR) / "config/secrets/oauth-metrics-token").read_text().strip()
        except FileNotFoundError:
            if settings.DEBUG and settings.DOCKERBUILD:
                token = "local-oauth-metrics"
    supplied = request.headers.get("Authorization", "").encode()
    if not token or not hmac.compare_digest(supplied, f"OAuthMetrics {token}".encode()):
        return HttpResponse(status=403)
    registry = CollectorRegistry()
    registry.register(ApplicationMetrics())
    return HttpResponse(generate_latest(registry), content_type=CONTENT_TYPE_LATEST)
