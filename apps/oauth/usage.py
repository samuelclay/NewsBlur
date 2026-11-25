"""Registered application traffic for the NewsBlur OAuth Grafana dashboard."""

import hmac
from datetime import timedelta
from pathlib import Path

from django.conf import settings
from django.http import HttpResponse
from django.utils import timezone
from oauth2_provider.models import get_application_model
from prometheus_client import CollectorRegistry, generate_latest
from prometheus_client.core import CounterMetricFamily, GaugeMetricFamily
from prometheus_client.exposition import CONTENT_TYPE_LATEST

from apps.oauth.access import SELF_SERVICE_LAUNCH, owner_has_active_pro
from apps.oauth.traffic import application_usage, recorded_application_ids


class ApplicationMetrics:
    def collect(self):
        requests = CounterMetricFamily(
            "newsblur_oauth_requests",
            "Requests authenticated using an application access token.",
            labels=["app_id"],
        )
        readers = GaugeMetricFamily(
            "newsblur_oauth_readers_week",
            "Estimated distinct readers in the current and previous six UTC days.",
            labels=["app_id"],
        )
        last_used = GaugeMetricFamily(
            "newsblur_oauth_last_request_timestamp_seconds",
            "Unix timestamp of the last authenticated request by the application.",
            labels=["app_id"],
        )
        names = GaugeMetricFamily(
            "newsblur_oauth_application_info", "Current application name.", labels=["app_id", "app_name"]
        )
        applications = get_application_model().objects
        cutoff = timezone.now() - timedelta(days=1)
        new = applications.filter(created__gte=cutoff).count()
        apps = dict(applications.filter(pk__in=recorded_application_ids()).values_list("pk", "name"))
        usage = application_usage(list(apps))
        active = 0
        for pk, name in apps.items():
            app_id = str(pk)
            names.add_metric([app_id, name], 1)
            readers.add_metric([app_id], usage[pk]["readers"])
            requests.add_metric([app_id], usage[pk]["requests"])
            last_request = usage[pk]["last_used"]
            if last_request is not None:
                last_used.add_metric([app_id], last_request)
            if (last_request or 0) >= int(cutoff.timestamp()):
                active += 1
        inventory = GaugeMetricFamily(
            "newsblur_oauth_legacy_application_needs_pro",
            "Pre-launch applications that would lose access if their owners needed active Premium Pro.",
            labels=["app_id", "app_name", "owner"],
        )
        legacy_apps = (
            applications.filter(created__lt=SELF_SERVICE_LAUNCH, user__is_active=True)
            .select_related("user__profile")
            .only(
                "pk",
                "name",
                "created",
                "user__username",
                "user__is_active",
                "user__profile__is_pro",
                "user__profile__is_premium",
                "user__profile__is_premium_trial",
                "user__profile__premium_expire",
            )
        )
        for app in legacy_apps:
            if not owner_has_active_pro(app):
                inventory.add_metric([str(app.pk), app.name, app.user.username], 1)
        yield inventory
        yield names
        yield last_used
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
