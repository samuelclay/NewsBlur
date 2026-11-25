import logging
from urllib.parse import urlsplit

import redis
from django import forms
from django.conf import settings
from django.contrib.auth import SESSION_KEY
from django.contrib.auth.decorators import login_required
from django.core.exceptions import ValidationError
from django.db import transaction
from django.db.models import Count, Q
from django.http import HttpResponseRedirect, JsonResponse
from django.shortcuts import render
from django.utils import timezone
from django.utils.translation import gettext
from django.views.decorators.cache import never_cache
from django.views.decorators.csrf import csrf_protect
from django.views.decorators.http import require_GET, require_http_methods
from oauth2_provider.models import Application

from apps.oauth.models import ApplicationWebsite
from apps.oauth.traffic import application_usage

logger = logging.getLogger(__name__)


def owner_subscription_error():
    return gettext("The owner of this OAuth application needs an active NewsBlur Premium Pro subscription.")


class RegistrationForm(forms.Form):
    name = forms.CharField(max_length=255)
    website = forms.URLField(max_length=2048)
    redirect_uri = forms.URLField(max_length=2048)

    def clean_website(self):
        website = self.cleaned_data["website"]
        if urlsplit(website).scheme not in ("https", "http"):
            raise forms.ValidationError(gettext("Enter an HTTP or HTTPS website address."))
        return website

    def clean_redirect_uri(self):
        uri = self.cleaned_data["redirect_uri"]
        parsed = urlsplit(uri)
        loopback = parsed.hostname in ("localhost", "127.0.0.1", "::1")
        if parsed.scheme != "https" and not (parsed.scheme == "http" and loopback):
            raise forms.ValidationError(gettext("Use HTTPS for the redirect URL, or HTTP on localhost."))
        if parsed.fragment or parsed.username is not None or "*" in uri or any(c.isspace() for c in uri):
            raise forms.ValidationError(
                gettext("Enter a single redirect URL without credentials, wildcards, or a fragment.")
            )
        return uri


@never_cache
@require_GET
def owned_applications(request):
    if not request.user.is_authenticated or request.session.get(SESSION_KEY) != str(request.user.pk):
        return JsonResponse({"error": gettext("Sign in to view your OAuth applications.")}, status=403)

    apps = list(
        Application.objects.filter(user=request.user)
        .values("id", "name", "client_id", "redirect_uris", "applicationwebsite__website")
        .annotate(
            connected=Count(
                "accesstoken__user_id", distinct=True, filter=Q(accesstoken__expires__gt=timezone.now())
            )
        )
        .order_by("-id")
    )
    try:
        traffic = application_usage([app["id"] for app in apps])
    except redis.RedisError:
        logger.warning("OAuth application usage is unavailable", exc_info=True)
        traffic = {}
    for app in apps:
        app["website"] = app.pop("applicationwebsite__website")
        app["usage"] = traffic.get(app["id"])
    return JsonResponse({"applications": apps})


@never_cache
@login_required
@require_GET
def preview_application(request):
    return render(
        request,
        "oauth2_provider/authorize.html",
        {
            "preview": True,
            "application": {
                "name": request.GET.get("name", "")[:255] or gettext("Your app name"),
                "applicationwebsite": {"website": request.GET.get("website", "")[:2048]},
            },
            "scopes_descriptions": [settings.OAUTH2_PROVIDER["SCOPES"]["read"]],
        },
    )


@never_cache
@csrf_protect
@require_http_methods(["GET", "POST"])
def register_application(request):
    if request.method == "GET":
        return HttpResponseRedirect("/?next=create-oauth-application")
    profile = getattr(request.user, "profile", None)
    if not request.session.get(SESSION_KEY) or not profile or not profile.can_register_oauth_application:
        return JsonResponse(
            {"error": gettext("Creating OAuth applications requires NewsBlur Premium Pro.")}, status=403
        )

    origin = request.headers.get("Origin")
    host = request.get_host()
    if origin and origin != f"https://{host}" and not (settings.DEBUG and origin == f"http://{host}"):
        return JsonResponse({"error": gettext("Open NewsBlur to register your application.")}, status=403)

    form = RegistrationForm(request.POST)
    if not form.is_valid():
        return JsonResponse(
            {"error": " ".join(str(e) for errors in form.errors.values() for e in errors)}, status=400
        )

    application = Application(
        user=request.user,
        name=form.cleaned_data["name"],
        redirect_uris=form.cleaned_data["redirect_uri"],
        client_type=Application.CLIENT_CONFIDENTIAL,
        authorization_grant_type=Application.GRANT_AUTHORIZATION_CODE,
    )
    try:
        application.full_clean()
    except ValidationError as exc:
        return JsonResponse({"error": " ".join(exc.messages)}, status=400)
    secret = application.client_secret
    with transaction.atomic():
        application.save()
        ApplicationWebsite.objects.create(application=application, website=form.cleaned_data["website"])
    return JsonResponse({"client_id": application.client_id, "client_secret": secret}, status=201)
