"""Browser transport for apps/api/social_auth.py's shared account protocol."""

import hashlib
import json
import secrets
from urllib.parse import urlencode

import jwt
import requests
from django.conf import settings
from django.contrib.auth.models import User
from django.http import HttpResponseRedirect
from django.shortcuts import render
from django.urls import reverse
from django.utils.http import url_has_allowed_host_and_scheme
from django.views.decorators.cache import never_cache
from django.views.decorators.csrf import csrf_exempt, csrf_protect
from django.views.decorators.http import require_GET, require_http_methods, require_POST

from apps.api import social_auth
from apps.profile.models import MGiftCode, MRedeemedCode, MReferral


def available_providers():
    if not settings.SOCIAL_WEB_ENABLED:
        return {"apple": False, "google": False}
    return {
        "apple": bool(
            settings.SOCIAL_APPLE_WEB_CLIENT_ID
            and settings.SOCIAL_APPLE_TEAM_ID
            and settings.SOCIAL_APPLE_KEY_ID
            and settings.SOCIAL_APPLE_PRIVATE_KEY_PATH
        ),
        "google": bool(settings.SOCIAL_GOOGLE_CLIENT_ID and settings.SOCIAL_GOOGLE_CLIENT_SECRET),
    }


def page(request, message, status=400, **context):
    response = render(
        request, "accounts/social_continue.html", dict(message=message, **context), status=status
    )
    response["Referrer-Policy"] = "no-referrer"
    return response


def safe_next(request, target):
    if url_has_allowed_host_and_scheme(
        target, allowed_hosts={request.get_host()}, require_https=request.is_secure()
    ):
        return target
    return reverse("index")


def configuration(provider):
    if provider == "apple":
        return settings.SOCIAL_APPLE_WEB_CLIENT_ID, settings.SOCIAL_APPLE_WEB_REDIRECT_URI
    return settings.SOCIAL_GOOGLE_CLIENT_ID, settings.SOCIAL_GOOGLE_WEB_REDIRECT_URI


@never_cache
@csrf_protect
@require_POST
def start(request):
    if social_auth.rate_limited(request):
        return page(request, "Please wait a minute before trying again.", 429)
    provider = request.POST.get("provider")
    if provider not in ("apple", "google"):
        return page(request, "Unknown sign-in provider.")
    if not available_providers()[provider]:
        return page(request, "%s sign-in is not configured on this server yet." % provider.title(), 503)
    verifier = secrets.token_urlsafe(32)
    request.session["web_social_verifier"] = verifier
    request.session.pop("web_social_pending", None)
    context = dict(
        provider=provider,
        nonce=secrets.token_urlsafe(32),
        challenge=hashlib.sha256(verifier.encode()).hexdigest(),
        next=safe_next(request, request.POST.get("next", "")),
        referrer=request.COOKIES.get("nb_referrer") or request.POST.get("referrer", "")[:255],
        gift_code=request.COOKIES.get("nb_gift_code") or request.POST.get("gift_code", "")[:255],
    )
    state = social_auth.remember("web-state", context)
    client_id, redirect_uri = configuration(provider)
    params = dict(
        client_id=client_id,
        redirect_uri=redirect_uri,
        response_type="code",
        scope="email" if provider == "apple" else "openid email",
        state=state,
        nonce=context["nonce"],
    )
    if provider == "apple":
        params["response_type"] = "code id_token"
        params["response_mode"] = "form_post"
        endpoint = "https://appleid.apple.com/auth/authorize"
    else:
        params["prompt"] = "select_account"
        endpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    return HttpResponseRedirect(endpoint + "?" + urlencode(params))


@never_cache
@csrf_exempt
@require_http_methods(["GET", "POST"])
def callback(request, provider):
    # web_social_auth.py bridges Apple's cross-site POST to a same-site GET so Lax session cookies work.
    # Only this callback is CSRF-exempt; finish verifies the initiating browser before exchanging the code.
    if request.method != ("POST" if provider == "apple" else "GET"):
        return page(request, "Invalid sign-in callback.", 405)
    data = request.POST if provider == "apple" else request.GET
    context = social_auth.consume("web-state", data.get("state", ""))
    if not context or context["provider"] != provider:
        return page(request, "Sign-in expired. Please try again.")
    if provider == "apple":
        context["authorization_token"] = data.get("id_token", "")[:16384]
    result = social_auth.remember(
        "web-return",
        dict(context, authorization_code=data.get("code", "")[:4096], cancelled=bool(data.get("error"))),
    )
    response = HttpResponseRedirect(reverse("web-social-finish") + "?" + urlencode(dict(result=result)))
    response.status_code = 303
    response["Referrer-Policy"] = "no-referrer"
    return response


@never_cache
@require_GET
def finish(request):
    context = social_auth.consume("web-return", request.GET.get("result", ""))
    verifier = request.session.get("web_social_verifier", "")
    if (
        not context
        or not verifier
        or not secrets.compare_digest(context["challenge"], hashlib.sha256(verifier.encode()).hexdigest())
    ):
        return page(request, "Sign-in expired or started in another browser. Please try again.")
    provider = context["provider"]
    if context.pop("cancelled"):
        return page(
            request, "%s sign-in was cancelled. You can try again or use your password." % provider.title()
        )
    client_id, redirect_uri = configuration(provider)
    try:
        if provider == "apple":
            # web_social_auth.py verifies the nonce-bound authorization proof before exchanging the code.
            identity = social_auth.verified_claims(
                provider, context.pop("authorization_token"), context["nonce"], expected_audience=client_id
            )
        client_secret = (
            social_auth.apple_client_secret(client_id)
            if provider == "apple"
            else settings.SOCIAL_GOOGLE_CLIENT_SECRET
        )
        response = requests.post(
            "https://appleid.apple.com/auth/token"
            if provider == "apple"
            else "https://oauth2.googleapis.com/token",
            timeout=15,
            data=dict(
                code=context.pop("authorization_code"),
                client_id=client_id,
                client_secret=client_secret,
                redirect_uri=redirect_uri,
                grant_type="authorization_code",
            ),
        )
        response.raise_for_status()
        if provider == "apple":
            # web_social_auth.py binds the exchange to that identity; email/nonce may be absent here.
            social_auth.verify_apple_exchange_token(
                response.json()["id_token"], client_id, identity["subject"], context["nonce"]
            )
        else:
            identity = social_auth.verified_claims(
                provider, response.json()["id_token"], context["nonce"], expected_audience=client_id
            )
    except (requests.RequestException, jwt.PyJWTError, OSError, ValueError, KeyError, TypeError):
        return page(request, "%s could not verify your account. Please try again." % provider.title())
    ticket = social_auth.remember("ticket", dict(context, identity=identity))
    request.session["web_social_pending"] = dict(context, ticket=ticket)
    # web_social_auth.py drops the callback URL before rendering a form or loading third-party assets.
    return HttpResponseRedirect(reverse("web-social-continue"))


def finish_signup(request, context):
    # web_social_auth.py preserves the referral and gift behavior of profile/views.py's signup.
    referrer_username = context.get("referrer")
    if referrer_username:
        try:
            referrer = User.objects.get(username__iexact=referrer_username)
            if referrer.pk != request.user.pk:
                MReferral.create_referral(referrer.pk, request.user.pk, request.user.username)
        except User.DoesNotExist:
            pass
    gift_code = context.get("gift_code")
    if gift_code:
        gift = MGiftCode.objects.filter(gift_code__iexact=gift_code).first()
        if gift and not gift.redeemed_date:
            MRedeemedCode.redeem(user=request.user, gift_code=gift_code)


@never_cache
@csrf_protect
@require_http_methods(["GET", "POST"])
def continue_signin(request):
    context = request.session.get("web_social_pending")
    verifier = request.session.get("web_social_verifier", "")
    if not context or not verifier:
        return page(request, "Sign-in expired. Please try again.")
    if request.method == "GET" and context.get("step"):
        return page(
            request,
            context["message"],
            200,
            step=context["step"],
            provider=context["provider"],
            username=context.get("username", ""),
        )
    if social_auth.rate_limited(request):
        return page(request, "Please wait a minute before trying again.", 429)
    ticket = social_auth.consume("ticket", context["ticket"])
    response = social_auth.complete_ticket(request, ticket, verifier)
    result = json.loads(response.content)
    if result.get("code") == 1:
        request.session.pop("web_social_pending", None)
        request.session.pop("web_social_verifier", None)
        if result.get("created"):
            finish_signup(request, context)
        response = HttpResponseRedirect(safe_next(request, context["next"]))
        response.set_cookie(
            "nb_last_social_provider",
            context["provider"],
            max_age=365 * 86400,
            secure=request.is_secure(),
            httponly=True,
            samesite="Lax",
        )
        if result.get("created"):
            response.delete_cookie("nb_referrer")
            response.delete_cookie("nb_gift_code")
        return response
    step = "link" if result.get("link_required") else "username" if result.get("username_required") else None
    username = (
        ""
        if request.POST.get("action") == "choose_username"
        else request.POST.get("username", context.get("username", ""))
    )
    if step:
        request.session["web_social_pending"] = dict(
            context, ticket=result["ticket"], step=step, message=result["message"], username=username
        )
    else:
        request.session.pop("web_social_pending", None)
    return page(
        request,
        result["message"],
        200 if step else response.status_code,
        step=step,
        provider=context["provider"],
        username=username,
    )
