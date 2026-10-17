"""UI language negotiation and the account preference used by all three clients."""

import hashlib
import os
import re
from functools import lru_cache
from urllib.parse import urljoin

from django.conf import settings
from django.contrib.auth.signals import user_logged_in
from django.contrib.staticfiles import finders
from django.contrib.staticfiles.storage import staticfiles_storage
from django.core.exceptions import ObjectDoesNotExist
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
from django.utils.safestring import mark_safe
from django.utils.translation import gettext
from django.utils.translation.trans_real import DjangoTranslation, parse_accept_lang_header
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from django.views.i18n import JavaScriptCatalog
from pipeline.conf import settings as pipeline_settings
from pipeline.packager import Packager

# language.py imports pipeline_utils for its DEBUG_ASSETS glob expansion, so flipped source CSS
# is read in the same order that {% include_stylesheets %} links it.
import utils.pipeline_utils  # noqa: F401
from utils import json_functions as json
from utils import log as logging
from utils.languages import LANGUAGES, match_language, normalize_language
from utils.rtl_css import absolutize_urls, flip_stylesheet

COOKIE_NAME = "newsblur_language"
JAVASCRIPT_CATALOG_PATTERN = r"^jsi18n/(?P<language>[A-Za-z-]+)/(?P<version>[a-f0-9]{16})/$"
FLIPPED_STYLESHEET_PATTERN = r"^rtl/(?P<bundle>[a-z]+)/(?P<version>[a-f0-9]{16})\.css$"
# language.py mirrors only the bundles right-to-left pages link in place of their LTR CSS:
# "common" (templates/base.html and the pages that extend it) and "blurblog" (social_page.xhtml).
FLIPPED_STYLESHEET_BUNDLES = ("common", "blurblog")
UI_LANGUAGES = list(LANGUAGES.items())
# language.py sends the language chooser's own wording in every language, so the web grid previews a
# selected language before the page reloads into it (reader_language.js). These are djangojs msgids.
LANGUAGE_CHOOSER_MESSAGES = {
    "title": "Choose your language",
    "pick": "Pick the language you'd like NewsBlur to use. You can change this anytime in Preferences.",
    "use": "Use %(language)s",
}
SCRIPT_ESCAPES = {ord("<"): "\\u003C", ord(">"): "\\u003E", ord("&"): "\\u0026"}


def preference(request):
    if request.user.is_authenticated:
        # language.py runs on every request, so a missing profile or blank preferences falls back to auto.
        try:
            preferences = json.decode(request.user.profile.preferences) or {}
        except (ObjectDoesNotExist, ValueError):
            preferences = {}
        return normalize_language(preferences.get("language")) or "auto"
    return normalize_language(request.COOKIES.get(COOKIE_NAME)) or "auto"


def save_account_language(profile, language):
    preferences = json.decode(profile.preferences)
    preferences["language"] = language
    profile.preferences = json.encode(preferences)
    profile.save(update_fields=["preferences"])


def set_language_cookie(response, name, value, max_age):
    response.set_cookie(
        name,
        value,
        max_age=max_age,
        domain=settings.SESSION_COOKIE_DOMAIN,
        secure=settings.SESSION_COOKIE_SECURE,
        httponly=True,
        samesite="Lax",
    )


def detect_language(header):
    # language.py bounds Django 3.1's cached parser input (CVE-2023-23969).
    if len(header) > 500:
        header = header[:500].rsplit(",", 1)[0] if "," in header[:500] else ""
    for code, quality in parse_accept_lang_header(header):
        language = match_language(code)
        if quality > 0 and language:
            return language
    return "en"


def remember_device_language(request, detected):
    """language.py keeps the language an account's devices last asked for, so emails, which are sent without
    a request, reach Automatic users in it (utils/languages.py:account_language). It writes only when the
    language changes."""
    if not request.user.is_authenticated:
        return
    try:
        profile = request.user.profile
    except ObjectDoesNotExist:
        return
    if profile.last_seen_language == detected:
        return
    # language.py updates just this column; LastSeenMiddleware's later profile.save() keeps it too, since
    # both share request.user.profile.
    profile.last_seen_language = detected
    type(profile).objects.filter(pk=profile.pk).update(last_seen_language=detected)


def record_signup_language(user, request):
    """Called only for newly created accounts by apps/reader/forms.py, before login changes the user."""
    from apps.profile.models import Profile

    language = normalize_language(getattr(request, "LANGUAGE_CODE", None))
    if language is None or language == "auto":
        override = preference(request)
        language = (
            detect_language(request.META.get("HTTP_ACCEPT_LANGUAGE", "")) if override == "auto" else override
        )
    if Profile.objects.filter(user=user, signup_language__isnull=True).update(signup_language=language):
        user.profile.signup_language = language


class NewsBlurLocaleMiddleware(LocaleMiddleware):
    def process_request(self, request):
        override = preference(request)
        header = request.META.get("HTTP_ACCEPT_LANGUAGE", "")
        detected = detect_language(header)
        language = detected if override == "auto" else override
        translation.activate(language.lower())
        request.LANGUAGE_CODE = language
        request.detected_language = detected
        request.language_preference = override
        # Scripts and API clients that send no Accept-Language say nothing about the reader.
        if header.strip():
            remember_device_language(request, detected)

    def process_response(self, request, response):
        response = super().process_response(request, response)
        if getattr(request, "language_choice_adopted", False):
            response.delete_cookie(COOKIE_NAME + "_pending", domain=settings.SESSION_COOKIE_DOMAIN)
        patch_vary_headers(response, ("Accept-Language", "Cookie"))
        return response


class LanguageCatalogMiddleware:
    """Serve public, versioned catalogs and flipped RTL stylesheets before session/auth middleware can
    add user-specific headers."""

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        path = request.path_info[1:]
        match = re.fullmatch(JAVASCRIPT_CATALOG_PATTERN, path)
        if match:
            return javascript_catalog(request, **match.groupdict())
        match = re.fullmatch(FLIPPED_STYLESHEET_PATTERN, path)
        if match:
            return flipped_stylesheet(request, **match.groupdict())
        return self.get_response(request)


def language_context(request):
    language = getattr(request, "LANGUAGE_CODE", "en")
    detected = getattr(request, "detected_language", "en")
    rtl = language in ("ar", "he")
    _, version = javascript_catalog_data(language)
    # language.py labels Automatic in the language it resolves to, so someone who picked a language
    # they can't read still recognizes the way back.
    with translation.override(detected.lower()):
        auto_label = gettext("Automatic (device language)")
        auto_short = gettext("Auto")
    return {
        "ui_languages": UI_LANGUAGES,
        "ui_language": language,
        "ui_language_preference": getattr(request, "language_preference", "auto"),
        "ui_language_rtl": rtl,
        "ui_language_dir": "rtl" if rtl else "ltr",
        "ui_detected_language": detected,
        "ui_detected_language_name": LANGUAGES[detected],
        "ui_language_auto_label": auto_label,
        "ui_language_auto_short": auto_short,
        "ui_catalog_url": reverse("javascript-catalog", kwargs={"language": language, "version": version}),
        "ui_language_chooser_copy": language_chooser_copy_script(),
        # language.py: {% include_stylesheets %} (utils/templatetags/utils_tags.py) links these mirrored
        # bundles instead of the LTR ones. LTR pages get an empty mapping and never build a flip.
        "ui_flipped_stylesheets": FlippedStylesheetUrls() if rtl else {},
    }


class FlippedStylesheetUrls:
    """Versioned URLs of the mirrored bundles, built only when a right-to-left page links one."""

    def get(self, bundle):
        if bundle not in FLIPPED_STYLESHEET_BUNDLES:
            return ""
        try:
            _, version = flipped_stylesheet_data(bundle)
        except (OSError, ValueError, KeyError) as error:
            # language.py falls back to the LTR bundle rather than break the page when its CSS can't be read.
            logging.error(" ***> Couldn't flip the %s stylesheet for RTL: %s" % (bundle, error))
            return ""
        return reverse("flipped-stylesheet", kwargs={"bundle": bundle, "version": version})

    def __getitem__(self, bundle):
        return self.get(bundle)


def flipped_stylesheet_sources(bundle):
    """Return ((file path, URL), ...) for the CSS an LTR page links for this bundle, in link order."""
    if pipeline_settings.PIPELINE_ENABLED:
        # language.py reads the compiled bundle that collectstatic wrote, by its manifest name.
        name = staticfiles_storage.stored_name(pipeline_settings.STYLESHEETS[bundle]["output_filename"])
        return ((staticfiles_storage.path(name), urljoin(settings.STATIC_URL, name)),)
    package = Packager().package_for("css", bundle)
    return tuple(
        (finders.find(path) or os.path.join(settings.MEDIA_ROOT, path), urljoin(settings.MEDIA_URL, path))
        for path in package.paths
    )


def flipped_stylesheet_data(bundle):
    """Return (mirrored CSS bytes, content version), rebuilt when a source file changes."""
    sources = []
    for path, url in flipped_stylesheet_sources(bundle):
        stat = os.stat(path)
        sources.append((path, url, stat.st_mtime_ns, stat.st_size))
    return _flipped_stylesheet_build(tuple(sources))


@lru_cache(maxsize=len(FLIPPED_STYLESHEET_BUNDLES) * 2)
def _flipped_stylesheet_build(sources):
    """Flip once per bundle per worker; the file stamps in the key change when the CSS is redeployed."""
    stylesheets = []
    for path, url, _, _ in sources:
        with open(path, encoding="utf-8") as stylesheet:
            stylesheets.append(absolutize_urls(stylesheet.read(), url))
    content = flip_stylesheet("\n".join(stylesheets)).encode("utf-8")
    return content, hashlib.sha256(content).hexdigest()[:16]


@lru_cache(maxsize=1)
def language_chooser_copy():
    """Each language's title, prompt and button for the chooser, read from that language's djangojs catalog."""
    copy = {}
    for code, name in UI_LANGUAGES:
        if code == "en":
            messages = dict(LANGUAGE_CHOOSER_MESSAGES)
        else:
            catalog = DjangoTranslation(code.lower(), domain="djangojs")
            messages = {key: catalog.gettext(message) for key, message in LANGUAGE_CHOOSER_MESSAGES.items()}
        messages["use"] = messages["use"] % {"language": name}
        copy[code] = messages
    return copy


@lru_cache(maxsize=1)
def language_chooser_copy_script():
    """The chooser copy as a JavaScript literal that is safe inside templates/base.html's script block."""
    return mark_safe(json.encode(language_chooser_copy()).translate(SCRIPT_ESCAPES))


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


@require_http_methods(["GET", "HEAD"])
def flipped_stylesheet(request, bundle, version):
    if bundle not in FLIPPED_STYLESHEET_BUNDLES:
        raise Http404
    content, current_version = flipped_stylesheet_data(bundle)
    etag = '"%s"' % current_version
    response = HttpResponse(content, content_type="text/css; charset=utf-8")
    # language.py caches a version for good only when it matches, like javascript_catalog above.
    response["Cache-Control"] = (
        "public, max-age=31536000, immutable" if version == current_version else "no-store"
    )
    response["ETag"] = etag
    return get_conditional_response(request, etag=etag, response=response)


# language.py accepts the footer form from static pages, which never set a CSRF cookie. A cross-site post
# arrives without the SameSite=Lax session cookie, so it can only set an anonymous display language.
@csrf_exempt
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
        save_account_language(request.user.profile, language)
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
        set_language_cookie(response, COOKIE_NAME + "_pending", "1", max_age=86400)
    set_language_cookie(response, COOKIE_NAME, language, max_age=31536000)
    return response


@receiver(user_logged_in)
def adopt_login_language(sender, request, user, **kwargs):
    """Carry an explicit choice on the login page into this account once."""
    if request is None or request.COOKIES.get(COOKIE_NAME + "_pending") != "1":
        return
    language = normalize_language(request.COOKIES.get(COOKIE_NAME))
    if language is None:
        return
    save_account_language(user.profile, language)
    request.language_choice_adopted = True
