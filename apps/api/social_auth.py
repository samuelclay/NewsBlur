"""Native onboarding authentication; provider identities never link on email alone."""

import hashlib
import logging
import secrets
import time
from urllib.parse import urlencode, urlsplit

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
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_GET, require_POST

from apps.profile.models import SocialIdentity
from apps.reader.forms import SignupForm
from utils.ip_rate_tracker import _get_client_ip

APPLE_KEYS = jwt.PyJWKClient("https://appleid.apple.com/auth/keys", timeout=10)
GOOGLE_KEYS = jwt.PyJWKClient("https://www.googleapis.com/oauth2/v3/certs", timeout=10)
TTL = 600
logger = logging.getLogger(__name__)


class AppRedirect(HttpResponseRedirect):
    allowed_schemes = ["newsblur-auth", "newsblur-auth-android", "newsblur-auth-android-alpha"]


def callback_target(state):
    # social_auth.py only accepts fixed app destinations, never a caller-supplied redirect URI.
    schemes = {
        "ios": "newsblur-auth",
        "android": "newsblur-auth-android",
        "android-alpha": "newsblur-auth-android-alpha",
    }
    return schemes[state.get("platform", "ios")] + "://complete?"


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


def verified_claims(provider, token, nonce, include_audience=False, expected_audience=None):
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
        audience=[expected_audience] if expected_audience is not None else client_ids,
        issuer=issuer,
        options={"require": ["sub", "exp", "iat", "aud", "iss", "nonce"]},
    )
    if not secrets.compare_digest(str(claims["nonce"]), nonce):
        raise ValueError("Nonce mismatch")
    if not claims.get("email") or claims.get("email_verified") not in (True, "true"):
        raise ValueError("A verified email address is required")
    identity = {"provider": provider, "subject": claims["sub"], "email": claims["email"]}
    if include_audience:
        identity["audience"] = claims["aud"]
    return identity


def apple_client_secret(client_id):
    if client_id not in settings.SOCIAL_APPLE_CLIENT_IDS + [settings.SOCIAL_APPLE_WEB_CLIENT_ID]:
        raise ValueError("Unknown Apple client")
    if not (
        settings.SOCIAL_APPLE_TEAM_ID
        and settings.SOCIAL_APPLE_KEY_ID
        and settings.SOCIAL_APPLE_PRIVATE_KEY_PATH
    ):
        raise ValueError("Apple signing key is not configured")
    with open(settings.SOCIAL_APPLE_PRIVATE_KEY_PATH, encoding="utf-8") as key_file:
        private_key = key_file.read()
    now = int(time.time())
    return jwt.encode(
        {
            "iss": settings.SOCIAL_APPLE_TEAM_ID,
            "iat": now,
            "exp": now + TTL,
            "aud": "https://appleid.apple.com",
            "sub": client_id,
        },
        private_key,
        algorithm="ES256",
        headers={"kid": settings.SOCIAL_APPLE_KEY_ID},
    )


def verify_apple_exchange_token(token, client_id, subject, nonce):
    # social_auth.py already verified the native identity; exchange tokens need not repeat email or nonce.
    key = APPLE_KEYS.get_signing_key_from_jwt(token).key
    claims = jwt.decode(
        token,
        key,
        algorithms=["RS256"],
        audience=client_id,
        issuer="https://appleid.apple.com",
        options={"require": ["sub", "exp", "iat", "aud", "iss"]},
    )
    if claims["sub"] != subject or claims["aud"] != client_id:
        raise ValueError("Apple authorization code does not match the verified identity")
    if "nonce" in claims and not secrets.compare_digest(str(claims["nonce"]), nonce):
        raise ValueError("Apple authorization code nonce mismatch")


def prepare_apple_revocation(authorization_code, client_id, identity, nonce, redirect_uri=None):
    # social_auth.py exchanges the short-lived code before the user pauses at deletion confirmation.
    try:
        if not authorization_code or not client_id:
            raise ValueError("Apple authorization code or client is missing")
        data = {
            "client_id": client_id,
            "client_secret": apple_client_secret(client_id),
            "code": authorization_code,
            "grant_type": "authorization_code",
        }
        # social_auth.py sends the original browser redirect URI; native iOS never supplied one.
        if redirect_uri is not None:
            data["redirect_uri"] = redirect_uri
        response = requests.post(
            "https://appleid.apple.com/auth/token",
            timeout=5,
            data=data,
        )
        response.raise_for_status()
        tokens = response.json()
        verify_apple_exchange_token(tokens["id_token"], client_id, identity["subject"], nonce)
        token_type = "refresh_token" if tokens.get("refresh_token") else "access_token"
        token = tokens[token_type]
        if not isinstance(token, str) or not token:
            raise ValueError("Apple returned no revocable token")
        return {"client_id": client_id, "token": token, "token_type_hint": token_type}
    except (requests.RequestException, jwt.PyJWTError, OSError, ValueError, KeyError, TypeError) as error:
        # social_auth.py never logs provider responses, credentials, token values, or signing key paths.
        logger.warning("Apple token exchange unavailable during account deletion (%s).", type(error).__name__)
        return None


def revoke_apple_token(context):
    if not context:
        return False
    try:
        response = requests.post(
            "https://appleid.apple.com/auth/revoke",
            timeout=5,
            data=dict(context, client_secret=apple_client_secret(context["client_id"])),
        )
        response.raise_for_status()
        return True
    except (requests.RequestException, jwt.PyJWTError, OSError, ValueError, KeyError, TypeError) as error:
        # social_auth.py follows TN3194: provider revocation problems must not block account deletion.
        logger.warning(
            "Apple token revocation unavailable during account deletion (%s).", type(error).__name__
        )
        return False


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
    connected_accounts = list(
        request.user.social_identities.filter(provider__in=["apple", "google"])
        .order_by("provider", "email")
        .values("provider", "email")
    )
    providers = list(dict.fromkeys(account["provider"] for account in connected_accounts))
    return JsonResponse(
        dict(
            code=1,
            providers=providers,
            connected_accounts=connected_accounts,
            has_password=request.user.has_usable_password(),
        )
    )


@never_cache
@require_POST
def start(request):
    if rate_limited(request):
        return failure("Please wait a minute before trying again.", 429)
    provider = request.POST.get("provider")
    if provider not in ("apple", "google"):
        return failure("Unknown sign-in provider.")
    platform = request.POST.get("platform", "ios")
    if platform not in ("ios", "android", "android-alpha"):
        return failure("Unknown sign-in platform.")
    if provider == "apple" and platform != "ios" and not settings.SOCIAL_APPLE_WEB_CLIENT_ID:
        return failure("Apple sign-in is not configured for Android on this server yet.", 503)
    purpose = request.POST.get("purpose", "signin")
    if purpose not in ("signin", "delete_account"):
        return failure("Unknown sign-in purpose.")
    context = {}
    if purpose == "delete_account":
        if not has_account_session(request):
            return failure("Please sign in before deleting your account.", 401)
        if not request.user.social_identities.filter(provider=provider).exists():
            return failure("Verify with a provider already connected to this NewsBlur account.", 403)
        if provider != "apple" and request.user.social_identities.filter(provider="apple").exists():
            return failure(
                "Verify with Apple to disconnect Sign in with Apple when deleting your account.", 403
            )
        context = dict(user_id=request.user.pk, session_key=request.session.session_key)
    if provider == "google" and not (
        settings.SOCIAL_GOOGLE_CLIENT_ID and settings.SOCIAL_GOOGLE_CLIENT_SECRET
    ):
        return failure("Google sign-in is not configured on this server yet.", 503)
    challenge = request.POST.get("challenge", "")
    if len(challenge) != 64 or any(c not in "0123456789abcdef" for c in challenge):
        return failure("Invalid sign-in challenge.")
    nonce = secrets.token_urlsafe(32)
    if provider == "apple" and platform != "ios":
        context["apple_redirect_uri"] = settings.SOCIAL_APPLE_REDIRECT_URI
    state = remember(
        "state",
        dict(
            provider=provider, nonce=nonce, challenge=challenge, purpose=purpose, platform=platform, **context
        ),
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
    if provider == "apple" and platform != "ios":
        result["url"] = "https://appleid.apple.com/auth/authorize?" + urlencode(
            dict(
                client_id=settings.SOCIAL_APPLE_WEB_CLIENT_ID,
                redirect_uri=context["apple_redirect_uri"],
                response_type="code id_token",
                response_mode="form_post",
                scope="email",
                state=state,
                nonce=nonce,
            )
        )
    return JsonResponse(result)


@never_cache
@require_POST
def apple(request):
    state = consume("state", request.POST.get("state", ""))
    if not state or state["provider"] != "apple" or state.get("platform", "ios") != "ios":
        return failure("Sign-in expired. Please try again.")
    try:
        identity = verified_claims(
            "apple",
            request.POST.get("id_token", ""),
            state["nonce"],
            include_audience=state.get("purpose") == "delete_account",
        )
    except (jwt.PyJWTError, ValueError):
        return failure("Apple could not verify your account. Please try again.")
    if state.get("purpose") == "delete_account":
        state["apple_client_id"] = identity.pop("audience", None)
        state["apple_authorization_code"] = request.POST.get("authorization_code", "")[:4096]
    ticket = remember("ticket", dict(state, identity=identity))
    return JsonResponse(dict(code=1, ticket=ticket))


@csrf_exempt
@never_cache
@require_POST
def apple_callback(request):
    # social_auth.py authenticates Apple's cross-site form POST with a one-use nonce-bound state.
    state = consume("state", request.POST.get("state", ""))
    if not state or state["provider"] != "apple" or state.get("platform") not in ("android", "android-alpha"):
        return failure("Sign-in expired. Return to NewsBlur and try again.")
    target = callback_target(state)
    if request.POST.get("error"):
        return AppRedirect(target + urlencode(dict(error="Apple sign-in was cancelled.")))
    try:
        identity = verified_claims(
            "apple",
            request.POST.get("id_token", ""),
            state["nonce"],
            expected_audience=settings.SOCIAL_APPLE_WEB_CLIENT_ID,
        )
    except (jwt.PyJWTError, ValueError):
        return AppRedirect(
            target + urlencode(dict(error="Apple could not verify your account. Please try again."))
        )
    if state.get("purpose") == "delete_account":
        state["apple_client_id"] = settings.SOCIAL_APPLE_WEB_CLIENT_ID
        state["apple_authorization_code"] = request.POST.get("code", "")[:4096]
    ticket = remember("ticket", dict(state, identity=identity))
    return AppRedirect(target + urlencode(dict(ticket=ticket)))


@never_cache
@require_GET
def google_callback(request):
    state = consume("state", request.GET.get("state", ""))
    if not state or state["provider"] != "google":
        return failure("Sign-in expired. Return to NewsBlur and try again.")
    target = callback_target(state)
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


def is_same_origin_completion(request):
    # social_auth.py accepts headerless native clients but rejects cross-origin browser login CSRF.
    # A valid attacker-owned ticket/verifier does not establish the browser's intent to sign in.
    fetch_site = request.META.get("HTTP_SEC_FETCH_SITE")
    if fetch_site is not None and fetch_site != "same-origin":
        return False

    def origin(value, allow_path=False):
        try:
            parsed = urlsplit(value)
            if (
                any(character.isspace() for character in value)
                or parsed.scheme not in ("http", "https")
                or not parsed.hostname
                or parsed.username is not None
                or parsed.password is not None
                or (not allow_path and (parsed.path or parsed.query or parsed.fragment))
            ):
                return None
            port = parsed.port if parsed.port is not None else (443 if parsed.scheme == "https" else 80)
            return parsed.scheme, parsed.hostname, port
        except ValueError:
            return None

    # social_auth.py uses Django's configured proxy trust, never raw forwarded host/protocol headers.
    expected = origin("%s://%s" % (request.scheme, request.get_host()))
    for header in ("HTTP_ORIGIN", "HTTP_REFERER"):
        if header in request.META:
            actual = origin(request.META[header], allow_path=header == "HTTP_REFERER")
            if actual is None or actual != expected:
                return False
    return True


@never_cache
@require_POST
def complete(request):
    if not is_same_origin_completion(request):
        return failure("Sign in from this NewsBlur site or the NewsBlur app.", 403)
    if rate_limited(request):
        return failure("Please wait a minute before trying again.", 429)
    ticket = consume("ticket", request.POST.get("ticket", ""))
    verifier = request.POST.get("verifier", "")
    return complete_ticket(request, ticket, verifier)


def complete_ticket(request, ticket, verifier):
    # web_social_auth.py shares native account creation and linking without exposing browser tickets.
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
        revocation = {}
        if identity["provider"] == "apple":
            exchange_options = (
                {"redirect_uri": ticket["apple_redirect_uri"]} if "apple_redirect_uri" in ticket else {}
            )
            revocation["apple_revocation"] = prepare_apple_revocation(
                ticket.get("apple_authorization_code"),
                ticket.get("apple_client_id"),
                identity,
                ticket.get("nonce"),
                **exchange_options,
            )
        proof = remember(
            "delete-account",
            dict(
                user_id=request.user.pk,
                session_key=request.session.session_key,
                identity_id=existing.pk,
                purpose="delete_account",
                **revocation,
            ),
        )
        return JsonResponse(dict(code=1, delete_token=proof))
    created = False
    if existing:
        user = existing.user
    else:
        if request.POST.get("action") == "choose_username":
            return failure(
                "Choose your NewsBlur username.",
                username_required=True,
                ticket=remember("ticket", ticket),
            )
        explicit_link = request.POST.get("action") == "link"
        identifier = request.POST.get("username", "").strip()
        if (
            not explicit_link
            and identifier
            and User.objects.filter(username__iexact=identifier)
            .exclude(email__iexact=identity["email"])
            .exists()
        ):
            # social_auth.py requires a separate link submission after a signup username collision.
            return failure(
                "This account already exists. Log in to connect it to %s." % identity["provider"].title(),
                link_required=True,
                ticket=remember("ticket", ticket),
            )
        if explicit_link:
            # social_auth.py resolves credentials before ModelBackend's exact username lookup.
            matches = list(User.objects.filter(username__iexact=identifier)[:2]) if identifier else []
            if identifier and not matches:
                matches = list(User.objects.filter(email__iexact=identifier)[:2])
        else:
            matches = list(User.objects.filter(email__iexact=identity["email"])[:2])
        if matches or explicit_link:
            if len(matches) > 1 and not explicit_link:
                return failure(
                    "More than one NewsBlur account uses this email. Sign in with your existing "
                    "username, or contact support@newsblur.com for help connecting this provider."
                )
            matched = matches[0] if len(matches) == 1 else None
            if not explicit_link and not matched.has_usable_password():
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
            identifier = identifier.casefold()
            username = (
                matched.username
                if matched and identifier in (matched.username.casefold(), matched.email.casefold())
                else ""
            )
            password = request.POST.get("password", "")
            user = authenticate(username=username, password=password) if username and password else None
            if not user or not user.is_active or len(matches) != 1 or user.pk != matches[0].pk:
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
    result = dict(code=1)
    if "apple_revocation" in proof and not revoke_apple_token(proof["apple_revocation"]):
        result.update(
            apple_revocation_required=True, apple_revocation_url="https://support.apple.com/en-us/102571"
        )
    logout(request)
    return JsonResponse(result)


@never_cache
@require_POST
def delete_password_account(request):
    # social_auth.py exposes JSON deletion for Android's native-password accounts without bypassing social proof.
    if not has_account_session(request):
        return failure("Please sign in before deleting your account.", 401)
    if rate_limited(request):
        return failure("Please wait a minute before trying again.", 429)
    if request.user.social_identities.exists():
        return failure(
            "Verify with your connected Apple or Google account before deleting your account.", 403
        )
    password = request.POST.get("password", "")
    if request.POST.get("confirm") != "Delete" or not password:
        return failure("Enter your password and type Delete to confirm.")
    user = authenticate(username=request.user.username, password=password)
    if not user or user.pk != request.user.pk:
        return failure("Your password does not match.", 403)
    request.user.profile.delete_user(confirm=True)
    logout(request)
    return JsonResponse(dict(code=1))
