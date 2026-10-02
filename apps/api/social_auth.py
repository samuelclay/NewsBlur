"""Native onboarding authentication; provider identities never link on email alone."""

import hashlib
import secrets
from urllib.parse import urlencode

import jwt
import requests
from django import forms
from django.conf import settings
from django.contrib.auth import authenticate, login
from django.contrib.auth.models import User
from django.core.cache import cache
from django.db import IntegrityError, transaction
from django.http import HttpResponseRedirect, JsonResponse
from django.views.decorators.cache import never_cache
from django.views.decorators.http import require_GET, require_POST

from apps.profile.models import SocialIdentity
from apps.reader.forms import SignupForm
from utils.ip_rate_tracker import _get_client_ip

APPLE_KEYS = jwt.PyJWKClient("https://appleid.apple.com/auth/keys", timeout=10)
GOOGLE_KEYS = jwt.PyJWKClient("https://www.googleapis.com/oauth2/v3/certs", timeout=10)
TTL = 600


class AppRedirect(HttpResponseRedirect):
    allowed_schemes = ["newsblur-auth"]


def failure(message, status=400, **extra):
    return JsonResponse(dict(code=-1, message=message, **extra), status=status)


def remember(kind, value):
    token = secrets.token_urlsafe(32)
    cache.set("social:%s:%s" % (kind, token), value, TTL)
    return token


def consume(kind, token):
    key = "social:%s:%s" % (kind, token)
    if not token or len(token) > 128 or not cache.add(key + ":used", True, TTL):
        return None
    value = cache.get(key)
    cache.delete(key)
    return value


def rate_limited(request):
    # social_auth.py shares ip_rate_tracker.py's trusted HAProxy/Nginx address extraction.
    address = _get_client_ip(request)
    key = "social:rate:" + hashlib.sha256(address.encode()).hexdigest()
    if cache.add(key, 1, 60):
        return False
    try:
        return cache.incr(key) > 30
    except ValueError:
        # social_auth.py tolerates a window expiring between add and incr.
        cache.add(key, 1, 60)
        return False


def verified_claims(provider, token, nonce):
    client_ids = (
        settings.SOCIAL_APPLE_CLIENT_IDS if provider == "apple" else [settings.SOCIAL_GOOGLE_CLIENT_ID]
    )
    keys = APPLE_KEYS if provider == "apple" else GOOGLE_KEYS
    issuer = (
        "https://appleid.apple.com"
        if provider == "apple"
        else ["https://accounts.google.com", "accounts.google.com"]
    )
    key = keys.get_signing_key_from_jwt(token).key
    claims = jwt.decode(
        token,
        key,
        algorithms=["RS256"],
        audience=client_ids,
        issuer=issuer,
        options={"require": ["sub", "exp", "iat", "aud", "iss", "nonce"]},
    )
    if not secrets.compare_digest(str(claims["nonce"]), nonce):
        raise ValueError("Nonce mismatch")
    if not claims.get("email") or claims.get("email_verified") not in (True, "true"):
        raise ValueError("A verified email address is required")
    return {"provider": provider, "subject": claims["sub"], "email": claims["email"]}


@never_cache
@require_POST
def start(request):
    if rate_limited(request):
        return failure("Please wait a minute before trying again.", 429)
    provider = request.POST.get("provider")
    if provider not in ("apple", "google"):
        return failure("Unknown sign-in provider.")
    if provider == "google" and not (
        settings.SOCIAL_GOOGLE_CLIENT_ID and settings.SOCIAL_GOOGLE_CLIENT_SECRET
    ):
        return failure("Google sign-in is not configured on this server yet.", 503)
    challenge = request.POST.get("challenge", "")
    if len(challenge) != 64 or any(c not in "0123456789abcdef" for c in challenge):
        return failure("Invalid sign-in challenge.")
    nonce = secrets.token_urlsafe(32)
    state = remember("state", dict(provider=provider, nonce=nonce, challenge=challenge))
    result = dict(code=1, state=state, nonce=nonce)
    if provider == "google":
        result["url"] = "https://accounts.google.com/o/oauth2/v2/auth?" + urlencode(
            dict(
                client_id=settings.SOCIAL_GOOGLE_CLIENT_ID,
                redirect_uri=settings.SOCIAL_GOOGLE_REDIRECT_URI,
                response_type="code",
                scope="openid email",
                state=state,
                nonce=nonce,
                prompt="select_account",
            )
        )
    return JsonResponse(result)


@never_cache
@require_POST
def apple(request):
    state = consume("state", request.POST.get("state", ""))
    if not state or state["provider"] != "apple":
        return failure("Sign-in expired. Please try again.")
    try:
        identity = verified_claims("apple", request.POST.get("id_token", ""), state["nonce"])
    except (jwt.PyJWTError, ValueError):
        return failure("Apple could not verify your account. Please try again.")
    ticket = remember("ticket", dict(identity=identity, challenge=state["challenge"]))
    return JsonResponse(dict(code=1, ticket=ticket))


@never_cache
@require_GET
def google_callback(request):
    state = consume("state", request.GET.get("state", ""))
    if not state or state["provider"] != "google":
        return failure("Sign-in expired. Return to NewsBlur and try again.")
    target = "newsblur-auth://complete?"
    if request.GET.get("error"):
        return AppRedirect(target + urlencode(dict(error="Google sign-in was cancelled.")))
    try:
        response = requests.post(
            "https://oauth2.googleapis.com/token",
            timeout=15,
            data=dict(
                code=request.GET.get("code", ""),
                client_id=settings.SOCIAL_GOOGLE_CLIENT_ID,
                client_secret=settings.SOCIAL_GOOGLE_CLIENT_SECRET,
                redirect_uri=settings.SOCIAL_GOOGLE_REDIRECT_URI,
                grant_type="authorization_code",
            ),
        )
        response.raise_for_status()
        identity = verified_claims("google", response.json()["id_token"], state["nonce"])
    except (requests.RequestException, jwt.PyJWTError, ValueError, KeyError):
        return AppRedirect(
            target + urlencode(dict(error="Google could not verify your account. Please try again."))
        )
    ticket = remember("ticket", dict(identity=identity, challenge=state["challenge"]))
    return AppRedirect(target + urlencode(dict(ticket=ticket)))


@never_cache
@require_POST
def complete(request):
    if rate_limited(request):
        return failure("Please wait a minute before trying again.", 429)
    ticket = consume("ticket", request.POST.get("ticket", ""))
    verifier = request.POST.get("verifier", "")
    if not ticket or not secrets.compare_digest(
        ticket["challenge"], hashlib.sha256(verifier.encode()).hexdigest()
    ):
        return failure("Sign-in expired. Please try again.")
    identity = ticket["identity"]
    existing = (
        SocialIdentity.objects.filter(provider=identity["provider"], subject=identity["subject"])
        .select_related("user")
        .first()
    )
    created = False
    if existing:
        user = existing.user
    else:
        matches = list(User.objects.filter(email__iexact=identity["email"])[:2])
        if matches:
            # social_auth.py deliberately bypasses LoginForm's legacy blank-password fallback.
            identifier = request.POST.get("username", "").strip().casefold()
            matched = matches[0] if len(matches) == 1 else None
            username = (
                matched.username
                if matched and identifier in (matched.username.casefold(), matched.email.casefold())
                else ""
            )
            user = (
                authenticate(username=username, password=request.POST.get("password", ""))
                if username
                else None
            )
            if not user or len(matches) != 1 or user.pk != matches[0].pk:
                return failure(
                    "Sign in to your existing NewsBlur account to connect this provider.",
                    link_required=True,
                    ticket=remember("ticket", ticket),
                )
        else:
            username = request.POST.get("username", "").strip()
            if not username:
                return failure(
                    "Choose your NewsBlur username.",
                    username_required=True,
                    ticket=remember("ticket", ticket),
                )
            form = SignupForm(
                data=dict(username=username, email=identity["email"], password=secrets.token_urlsafe(48))
            )
            if not form.is_valid():
                return failure(
                    " ".join(str(error) for errors in form.errors.values() for error in errors),
                    username_required=True,
                    ticket=remember("ticket", ticket),
                )
            try:
                with transaction.atomic():
                    # Serialize creation per provider subject before invoking SignupForm side effects.
                    from django.db import connection

                    lock = int.from_bytes(
                        hashlib.sha256((identity["provider"] + ":" + identity["subject"]).encode()).digest()[
                            :8
                        ],
                        "big",
                        signed=True,
                    )
                    with connection.cursor() as cursor:
                        cursor.execute("SELECT pg_advisory_xact_lock(%s)", [lock])
                    if SocialIdentity.objects.filter(
                        provider=identity["provider"], subject=identity["subject"]
                    ).exists():
                        return failure("Your account was just connected. Please sign in again.")
                    user = form.save()
                    user.set_unusable_password()
                    user.save(update_fields=["password"])
                    SocialIdentity.objects.create(user=user, **identity)
                    created = True
            except (IntegrityError, forms.ValidationError):
                return failure("That account was just updated. Please sign in again.")
        if not created:
            try:
                SocialIdentity.objects.create(user=user, **identity)
            except IntegrityError:
                return failure("That account was just connected. Please sign in again.")
    if not user.is_active:
        return failure("This account is inactive. Please contact NewsBlur support.", 403)
    login(request, user, backend="django.contrib.auth.backends.ModelBackend")
    return JsonResponse(dict(code=1, created=created, username=user.username))
