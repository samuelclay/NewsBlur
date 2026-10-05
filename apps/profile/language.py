"""UI language negotiation and the account preference used by all three clients."""

import hashlib
import re
from functools import lru_cache

from django.contrib.auth.signals import user_logged_in
from django.dispatch import receiver
from django.http import (
    Http404,
    HttpRequest,
    HttpResponse,
    HttpResponseBadRequest,
    HttpResponseRedirect,
    JsonResponse,
)
from django.middleware.locale import LocaleMiddleware
from django.urls import reverse
from django.utils import translation
from django.utils.cache import get_conditional_response, patch_vary_headers
from django.utils.http import url_has_allowed_host_and_scheme
from django.utils.translation.trans_real import parse_accept_lang_header
from django.views.decorators.csrf import csrf_protect
from django.views.decorators.http import require_http_methods
from django.views.i18n import JavaScriptCatalog

from utils import json_functions as json
from utils.languages import LANGUAGES, match_language, normalize_language

COOKIE_NAME = "newsblur_language"
JAVASCRIPT_CATALOG_PATTERN = r"^jsi18n/(?P<language>[A-Za-z-]+)/(?P<version>[a-f0-9]{16})/$"


def preference(request):
    if request.user.is_authenticated:
        return normalize_language(json.decode(request.user.profile.preferences).get("language")) or "auto"
    return normalize_language(request.COOKIES.get(COOKIE_NAME)) or "auto"


def detect_language(header):
    # language.py bounds Django 3.1's cached parser input (CVE-2023-23969).
    if len(header) > 500:
        header = header[:500].rsplit(",", 1)[0] if "," in header[:500] else ""
    for code, quality in parse_accept_lang_header(header):
        language = match_language(code)
        if quality > 0 and language:
            return language
    return "en"


class NewsBlurLocaleMiddleware(LocaleMiddleware):
    def process_request(self, request):
        override = preference(request)
        language = (
            override if override != "auto" else detect_language(request.META.get("HTTP_ACCEPT_LANGUAGE", ""))
        )
        translation.activate(language.lower())
        request.LANGUAGE_CODE = language
        request.language_preference = override

    def process_response(self, request, response):
        response = super().process_response(request, response)
        if getattr(request, "language_choice_adopted", False):
            response.delete_cookie(COOKIE_NAME + "_pending")
        patch_vary_headers(response, ("Accept-Language", "Cookie"))
        return response


class LanguageCatalogMiddleware:
    """Serve public, versioned catalogs before session/auth middleware can add user-specific headers."""

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        match = re.fullmatch(JAVASCRIPT_CATALOG_PATTERN, request.path_info[1:])
        if match:
            return javascript_catalog(request, **match.groupdict())
        return self.get_response(request)


def language_context(request):
    language = getattr(request, "LANGUAGE_CODE", "en")
    _, version = javascript_catalog_data(language)
    return {
        "ui_languages": list(LANGUAGES.items()),
        "ui_language": getattr(request, "LANGUAGE_CODE", "en"),
        "ui_language_preference": getattr(request, "language_preference", "auto"),
        "ui_language_rtl": getattr(request, "LANGUAGE_CODE", "en") in ("ar", "he"),
        "ui_catalog_url": reverse("javascript-catalog", kwargs={"language": language, "version": version}),
    }


@lru_cache(maxsize=len(LANGUAGES))
def javascript_catalog_data(language):
    """Build once per locale per worker; the content hash changes when catalogs are deployed."""
    request = HttpRequest()
    request.method = "GET"
    with translation.override(language.lower()):
        content = JavaScriptCatalog.as_view()(request).content
    return content, hashlib.sha256(content).hexdigest()[:16]


@require_http_methods(["GET", "HEAD"])
def javascript_catalog(request, language, version):
    if language not in LANGUAGES:
        raise Http404
    content, current_version = javascript_catalog_data(language)
    etag = '"%s"' % current_version
    response = HttpResponse(content, content_type="text/javascript; charset=utf-8")
    # language.py tolerates mixed worker releases during a rolling deploy without caching mismatched bytes.
    response["Cache-Control"] = (
        "public, max-age=31536000, immutable" if version == current_version else "no-store"
    )
    response["ETag"] = etag
    response["Content-Language"] = language
    return get_conditional_response(request, etag=etag, response=response)


@csrf_protect
@require_http_methods(["GET", "POST"])
def language_preference(request):
    if request.method == "GET":
        return JsonResponse(
            {"code": 1, "language": preference(request), "resolved_language": request.LANGUAGE_CODE}
        )
    language = normalize_language(request.POST.get("language"))
    if language is None:
        return HttpResponseBadRequest("Unsupported language")
    if request.user.is_authenticated:
        profile = request.user.profile
        preferences = json.decode(profile.preferences)
        preferences["language"] = language
        profile.preferences = json.encode(preferences)
        profile.save(update_fields=["preferences"])
    next_url = request.POST.get("next")
    if next_url:
        if not url_has_allowed_host_and_scheme(
            next_url, {request.get_host()}, require_https=request.is_secure()
        ):
            next_url = "/"
        response = HttpResponseRedirect(next_url)
    else:
        response = JsonResponse({"code": 1, "language": language})
    if not request.user.is_authenticated:
        response.set_cookie(
            COOKIE_NAME + "_pending",
            "1",
            max_age=86400,
            secure=request.is_secure(),
            httponly=True,
            samesite="Lax",
        )
    response.set_cookie(
        COOKIE_NAME, language, max_age=31536000, secure=request.is_secure(), httponly=True, samesite="Lax"
    )
    return response


@receiver(user_logged_in)
def adopt_login_language(sender, request, user, **kwargs):
    """Carry an explicit choice on the login page into this account once."""
    if request is None or request.COOKIES.get(COOKIE_NAME + "_pending") != "1":
        return
    language = normalize_language(request.COOKIES.get(COOKIE_NAME))
    if language is None:
        return
    profile = user.profile
    preferences = json.decode(profile.preferences)
    preferences["language"] = language
    profile.preferences = json.encode(preferences)
    profile.save(update_fields=["preferences"])
    request.language_choice_adopted = True
