"""Native onboarding authentication; provider identities never link on email alone."""

import hashlib
import secrets
from urllib.parse import urlencode

import jwt
import requests
from django import forms
from django.conf import settings
from django.contrib.auth import authenticate, login, logout
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


def has_account_session(request):
    user = getattr(request, "user", None)
    return bool(user and user.is_authenticated and user.is_active and request.session.session_key)


def matches_account_session(request, context):
    return (
        has_account_session(request)
        and context.get("user_id") == request.user.pk
        and secrets.compare_digest(context.get("session_key", ""), request.session.session_key)
    )


@never_cache
@require_GET
def account(request):
    if not has_account_session(request):
        return failure("Please sign in to manage your account.", 401)
    providers = list(
        request.user.social_identities.filter(provider__in=["apple", "google"])
        .order_by("provider")
        .values_list("provider", flat=True)
        .distinct()
    )
    return JsonResponse(dict(code=1, providers=providers, has_password=request.user.has_usable_password()))


@never_cache
@require_POST
def start(request):
    if rate_limited(request):
        return failure("Please wait a minute before trying again.", 429)
    provider = request.POST.get("provider")
    if provider not in ("apple", "google"):
        return failure("Unknown sign-in provider.")
    purpose = request.POST.get("purpose", "signin")
    if purpose not in ("signin", "delete_account"):
        return failure("Unknown sign-in purpose.")
    context = {}
    if purpose == "delete_account":
        if not has_account_session(request):
            return failure("Please sign in before deleting your account.", 401)
        if not request.user.social_identities.filter(provider=provider).exists():
            return failure("Verify with a provider already connected to this NewsBlur account.", 403)
        context = dict(user_id=request.user.pk, session_key=request.session.session_key)
    if provider == "google" and not (
        settings.SOCIAL_GOOGLE_CLIENT_ID and settings.SOCIAL_GOOGLE_CLIENT_SECRET
    ):
        return failure("Google sign-in is not configured on this server yet.", 503)
    challenge = request.POST.get("challenge", "")
    if len(challenge) != 64 or any(c not in "0123456789abcdef" for c in challenge):
        return failure("Invalid sign-in challenge.")
    nonce = secrets.token_urlsafe(32)
    state = remember(
        "state", dict(provider=provider, nonce=nonce, challenge=challenge, purpose=purpose, **context)
    )
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
    ticket = remember("ticket", dict(state, identity=identity))
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
    ticket = remember("ticket", dict(state, identity=identity))
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
    if ticket.get("purpose") == "delete_account":
        if (
            not matches_account_session(request, ticket)
            or not existing
            or existing.user_id != request.user.pk
        ):
            return failure(
                "Verify the Apple or Google account connected to your current NewsBlur account.", 403
            )
        proof = remember(
            "delete-account",
            dict(
                user_id=request.user.pk,
                session_key=request.session.session_key,
                identity_id=existing.pk,
                purpose="delete_account",
            ),
        )
        return JsonResponse(dict(code=1, delete_token=proof))
    created = False
    if existing:
        user = existing.user
    else:
        matches = list(User.objects.filter(email__iexact=identity["email"])[:2])
        if matches:
            if len(matches) > 1:
                return failure(
                    "More than one NewsBlur account uses this email. Sign in with your existing "
                    "username, or contact support@newsblur.com for help connecting this provider."
                )
            matched = matches[0]
            if not matched.has_usable_password():
                providers = set(matched.social_identities.values_list("provider", flat=True))
                provider_names = [
                    name for key, name in (("apple", "Apple"), ("google", "Google")) if key in providers
                ]
                existing_signin = (
                    "Sign in with " + " or ".join(provider_names)
                    if provider_names
                    else "Recover your existing NewsBlur account"
                )
                return failure(
                    existing_signin + ". To connect another provider, first reset your NewsBlur password "
                    "at newsblur.com/profile/forgot_password, then try again with that password."
                )
            # social_auth.py deliberately bypasses LoginForm's legacy blank-password fallback.
            identifier = request.POST.get("username", "").strip().casefold()
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
                    # social_auth.py serializes identity creation; SignupForm publishes only on commit.
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


@never_cache
@require_POST
def delete_account(request):
    if not has_account_session(request):
        return failure("Please sign in before deleting your account.", 401)
    if rate_limited(request):
        return failure("Please wait a minute before trying again.", 429)
    if request.POST.get("confirm") != "Delete":
        return failure("Confirm that you want to permanently delete your account.")
    proof = consume("delete-account", request.POST.get("delete_token", ""))
    if (
        not proof
        or proof.get("purpose") != "delete_account"
        or not matches_account_session(request, proof)
        or not request.user.social_identities.filter(pk=proof.get("identity_id")).exists()
    ):
        return failure("Account verification expired. Verify with Apple or Google again.", 403)
    # social_auth.py keeps provider verification separate from login, linking, and final deletion consent.
    request.user.profile.delete_user(confirm=True)
    logout(request)
    return JsonResponse(dict(code=1))
