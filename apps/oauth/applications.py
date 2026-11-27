import logging
from functools import wraps
from urllib.parse import urlsplit

import redis
from django import forms
from django.conf import settings
from django.contrib.auth import SESSION_KEY
from django.contrib.auth.decorators import login_required
from django.core.exceptions import PermissionDenied, ValidationError
from django.db import transaction
from django.db.models import Count, Q
from django.http import HttpResponseRedirect, JsonResponse
from django.shortcuts import get_object_or_404, redirect, render
from django.utils import timezone
from django.utils.translation import gettext
from django.views.decorators.cache import never_cache
from django.views.decorators.csrf import csrf_protect
from django.views.decorators.http import require_GET, require_http_methods
from oauth2_provider.models import Application

from apps.oauth.access import application_is_exempt
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
        return validate_callback(self.cleaned_data["redirect_uri"])


def validate_callback(uri):
    parsed = urlsplit(uri)
    loopback = parsed.hostname in ("localhost", "127.0.0.1", "::1")
    if parsed.scheme != "https" and not (parsed.scheme == "http" and loopback):
        raise forms.ValidationError(gettext("Use HTTPS for the redirect URL, or HTTP on localhost."))
    if parsed.fragment or parsed.username is not None or "*" in uri or any(c.isspace() for c in uri):
        raise forms.ValidationError(
            gettext("Enter a single redirect URL without credentials, wildcards, or a fragment.")
        )
    return uri


class ApplicationEditForm(forms.ModelForm):
    class Meta:
        model = Application
        fields = ("name", "redirect_uris")

    def clean_redirect_uris(self):
        uri = self.cleaned_data["redirect_uris"]
        if uri == self.instance.redirect_uris:
            # Keep native and multi-URL callbacks registered before self-service.
            return uri
        return validate_callback(forms.URLField(max_length=2048).clean(uri))


def browser_session_required(view):
    @wraps(view)
    def wrapped(request, *args, **kwargs):
        if not request.user.is_authenticated or request.session.get(SESSION_KEY) != str(request.user.pk):
            raise PermissionDenied
        return view(request, *args, **kwargs)

    return wrapped


@never_cache
@csrf_protect
@require_http_methods(["GET", "POST"])
@browser_session_required
def edit_application(request, pk):
    application = get_object_or_404(
        Application.objects.select_related("applicationexemption"), pk=pk, user=request.user
    )
    # Owners of exempt applications keep them up to date without Premium Pro (apps/oauth/access.py).
    if not (request.user.profile.can_register_oauth_application or application_is_exempt(application)):
        raise PermissionDenied
    form = ApplicationEditForm(request.POST if request.method == "POST" else None, instance=application)
    if request.method == "POST" and form.is_valid():
        if form.changed_data:
            application.save(update_fields=[*form.changed_data, "updated"])
        return redirect("oauth2_provider:detail", pk=pk)
    return render(
        request, "oauth2_provider/application_form.html", {"application": application, "form": form}
    )


@never_cache
@require_GET
def owned_applications(request):
    if not request.user.is_authenticated or request.session.get(SESSION_KEY) != str(request.user.pk):
        return JsonResponse({"error": gettext("Sign in to view your OAuth applications.")}, status=403)

    apps = list(
        Application.objects.filter(user=request.user)
        .values(
            "id",
            "name",
            "client_id",
            "redirect_uris",
            "applicationwebsite__website",
            "applicationexemption__id",
        )
        .annotate(
            connected=Count(
                "accesstoken__user_id", distinct=True, filter=Q(accesstoken__expires__gt=timezone.now())
            )
        )
        .order_by("-id")
    )
    # The signed-in owner's account is active, so an application works while the owner has Premium Pro or
    # staff exempted it, as application_is_active in apps/oauth/access.py decides.
    has_pro = request.user.profile.can_register_oauth_application
    try:
        traffic = application_usage([app["id"] for app in apps])
    except redis.RedisError:
        logger.warning("OAuth application usage is unavailable", exc_info=True)
        traffic = {}
    for app in apps:
        app["website"] = app.pop("applicationwebsite__website")
        app["usage"] = traffic.get(app["id"])
        # media/js/newsblur/reader/reader_oauth_applications.js warns the owner about paused applications.
        exempt = app.pop("applicationexemption__id") is not None
        app["paused"] = not (has_pro or exempt)
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
    if (
        request.session.get(SESSION_KEY) != str(request.user.pk)
        or not profile
        or not profile.can_register_oauth_application
    ):
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
