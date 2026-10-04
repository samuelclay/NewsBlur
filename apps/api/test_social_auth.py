"""Security boundaries for apps/api/social_auth.py's native sign-in protocol."""
import hashlib
import json
import time
from types import SimpleNamespace
from unittest.mock import Mock, mock_open, patch
from urllib.parse import parse_qs, urlparse

import jwt
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec, rsa
from django.core.cache import cache
from django.db import IntegrityError, transaction
from django.test import (
    Client,
    RequestFactory,
    SimpleTestCase,
    TransactionTestCase,
    override_settings,
)

from apps.api import social_auth
from newsblur_web import settings as base_settings


@override_settings(
    CACHES={"default": {"BACKEND": "django.core.cache.backends.locmem.LocMemCache"}},
    SOCIAL_APPLE_CLIENT_IDS=["com.newsblur.NewsBlur"],
    SOCIAL_GOOGLE_CLIENT_ID="google-client",
    SOCIAL_GOOGLE_CLIENT_SECRET="fixture-secret",
)
class Test_SocialAuthentication(SimpleTestCase):
    def setUp(self):
        cache.clear()
        self.factory = RequestFactory()
        self.key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        self.claims = dict(
            sub="provider-subject",
            email="reader@example.com",
            email_verified=True,
            nonce="nonce",
            aud="com.newsblur.NewsBlur",
            iss="https://appleid.apple.com",
            iat=int(time.time()),
            exp=int(time.time()) + 300,
        )

    def verify(self, changes=None, key=None):
        token = jwt.encode(
            dict(self.claims, **(changes or {})),
            key or self.key,
            algorithm="RS256",
            headers={"kid": "fixture"},
        )
        with patch.object(
            social_auth.APPLE_KEYS,
            "get_signing_key_from_jwt",
            return_value=SimpleNamespace(key=self.key.public_key()),
        ):
            return social_auth.verified_claims("apple", token, "nonce")

    def test_signed_verified_identity(self):
        self.assertEqual(self.verify()["subject"], "provider-subject")

    def test_web_apple_token_requires_the_services_id_audience(self):
        token = jwt.encode(dict(self.claims, aud="com.newsblur.web"), self.key, algorithm="RS256")
        with patch.object(
            social_auth.APPLE_KEYS,
            "get_signing_key_from_jwt",
            return_value=SimpleNamespace(key=self.key.public_key()),
        ):
            self.assertEqual(
                social_auth.verified_claims("apple", token, "nonce", expected_audience="com.newsblur.web")[
                    "subject"
                ],
                "provider-subject",
            )
            with self.assertRaises(jwt.InvalidAudienceError):
                social_auth.verified_claims("apple", token, "nonce")

    @override_settings(SOCIAL_APPLE_CLIENT_IDS=base_settings.SOCIAL_APPLE_CLIENT_IDS)
    def test_alpha_apple_identity_is_accepted_without_allowing_other_app_audiences(self):
        self.assertEqual(self.verify(dict(aud="com.newsblur.NB-Alpha"))["subject"], "provider-subject")
        with self.assertRaises(jwt.InvalidAudienceError):
            self.verify(dict(aud="com.newsblur.untrusted"))

    def test_rejects_wrong_audience_issuer_nonce_expiry_and_unverified_email(self):
        for change in [
            dict(aud="another-app"),
            dict(iss="https://attacker.example"),
            dict(nonce="replayed"),
            dict(exp=int(time.time()) - 10),
            dict(email_verified=False),
            dict(email=""),
        ]:
            with self.subTest(change=change), self.assertRaises((jwt.PyJWTError, ValueError)):
                self.verify(change)

    def test_rejects_token_signed_by_another_key(self):
        with self.assertRaises(jwt.InvalidSignatureError):
            self.verify(key=rsa.generate_private_key(public_exponent=65537, key_size=2048))

    def test_state_is_single_use_and_bound_to_provider(self):
        token = social_auth.remember("state", dict(provider="google", nonce="nonce", challenge="a" * 64))
        request = self.factory.post("/api/social/apple", dict(state=token, id_token="anything"))
        with patch.object(social_auth, "verified_claims") as verify:
            self.assertEqual(social_auth.apple(request).status_code, 400)
            verify.assert_not_called()
        self.assertIsNone(social_auth.consume("state", token))

    def test_ticket_requires_app_verifier_and_cannot_replay(self):
        token = social_auth.remember(
            "ticket", dict(challenge=hashlib.sha256(b"original").hexdigest(), identity={})
        )
        for verifier in ["attacker", "original"]:
            response = social_auth.complete(
                self.factory.post("/api/social/complete", dict(ticket=token, verifier=verifier))
            )
            self.assertEqual(response.status_code, 400)

    def test_complete_rejects_cross_site_browser_posts_before_consuming_valid_ticket(self):
        headers = [
            {"HTTP_ORIGIN": "https://attacker.example"},
            {"HTTP_ORIGIN": "null"},
            {"HTTP_ORIGIN": ""},
            {"HTTP_ORIGIN": "https://newsblur.com.attacker.example"},
            {"HTTP_ORIGIN": "https://newsblur.com@attacker.example"},
            {"HTTP_ORIGIN": "https://attacker.example@newsblur.com"},
            {"HTTP_ORIGIN": "https://newsblur.com:444"},
            {"HTTP_ORIGIN": "http://newsblur.com"},
            {"HTTP_ORIGIN": "https://newsblur.com/path"},
            {"HTTP_ORIGIN": "https://newsblur.com\n"},
            {"HTTP_ORIGIN": "https://newsblur.com:invalid"},
            {"HTTP_SEC_FETCH_SITE": "cross-site"},
            {"HTTP_SEC_FETCH_SITE": "same-site"},
            {"HTTP_SEC_FETCH_SITE": "none"},
            {"HTTP_SEC_FETCH_SITE": "unexpected"},
            {"HTTP_REFERER": "https://attacker.example/form"},
            {"HTTP_REFERER": "http://newsblur.com/form"},
            {"HTTP_REFERER": "/relative"},
            {"HTTP_ORIGIN": "null", "HTTP_REFERER": "https://newsblur.com/form"},
            {"HTTP_ORIGIN": "https://attacker.example", "HTTP_SEC_FETCH_SITE": "same-origin"},
            {"HTTP_ORIGIN": "https://newsblur.com", "HTTP_SEC_FETCH_SITE": "cross-site"},
            {"HTTP_ORIGIN": "https://newsblur.com", "HTTP_REFERER": "https://attacker.example"},
        ]
        for metadata in headers:
            with self.subTest(metadata=metadata):
                ticket = social_auth.remember(
                    "ticket",
                    dict(
                        challenge=hashlib.sha256(b"attacker-proof").hexdigest(),
                        identity=dict(provider="google", subject="attacker", email="attacker@example.com"),
                    ),
                )
                request = self.factory.post(
                    "/api/social/complete",
                    dict(ticket=ticket, verifier="attacker-proof"),
                    secure=True,
                    HTTP_HOST="newsblur.com",
                    **metadata,
                )
                with patch.object(social_auth.SocialIdentity, "objects") as identities, patch.object(
                    social_auth, "login"
                ) as login:
                    identities.filter.return_value.select_related.return_value.first.return_value = (
                        SimpleNamespace(user=SimpleNamespace(is_active=True, username="attacker"))
                    )
                    response = social_auth.complete(request)
                    self.assertEqual(response.status_code, 403)
                    login.assert_not_called()
                    identities.filter.assert_not_called()
                    self.assertIsNotNone(social_auth.consume("ticket", ticket))

    def test_complete_preserves_native_and_same_origin_browser_posts(self):
        for metadata in (
            {},
            {"HTTP_ORIGIN": "https://newsblur.com"},
            {"HTTP_ORIGIN": "https://newsblur.com:443"},
            {"HTTP_SEC_FETCH_SITE": "same-origin"},
            {"HTTP_REFERER": "https://newsblur.com/account/login?next=/reader"},
            {"HTTP_ORIGIN": "https://newsblur.com", "HTTP_SEC_FETCH_SITE": "same-origin"},
        ):
            with self.subTest(metadata=metadata):
                ticket = social_auth.remember(
                    "ticket",
                    dict(
                        challenge=hashlib.sha256(b"proof").hexdigest(),
                        identity=dict(provider="google", subject="reader", email="reader@example.com"),
                    ),
                )
                request = self.factory.post(
                    "/api/social/complete",
                    dict(ticket=ticket, verifier="proof"),
                    secure=True,
                    HTTP_HOST="newsblur.com",
                    **metadata,
                )
                with patch.object(social_auth.SocialIdentity, "objects") as identities, patch.object(
                    social_auth, "login"
                ) as login:
                    identities.filter.return_value.select_related.return_value.first.return_value = (
                        SimpleNamespace(user=SimpleNamespace(is_active=True, username="reader"))
                    )
                    response = social_auth.complete(request)
                    self.assertEqual(response.status_code, 200)
                    login.assert_called_once()
                    self.assertIsNone(social_auth.consume("ticket", ticket))

    @override_settings(
        USE_X_FORWARDED_HOST=False,
    )
    def test_complete_uses_only_configured_proxy_scheme_for_origin_checks(self):
        for proxy_setting, origin, status in (
            (("HTTP_X_FORWARDED_PROTO", "https"), "https://newsblur.com", 200),
            (("HTTP_X_FORWARDED_PROTO", "https"), "http://newsblur.com", 403),
            (None, "https://newsblur.com", 403),
            (None, "http://newsblur.com", 200),
            (("HTTP_X_FORWARDED_PROTO", "https"), "https://attacker.example", 403),
        ):
            with self.subTest(proxy_setting=proxy_setting, origin=origin), override_settings(
                SECURE_PROXY_SSL_HEADER=proxy_setting
            ):
                ticket = social_auth.remember(
                    "ticket",
                    dict(
                        challenge=hashlib.sha256(b"proof").hexdigest(),
                        identity=dict(provider="google", subject="reader", email="reader@example.com"),
                    ),
                )
                request = self.factory.post(
                    "/api/social/complete",
                    dict(ticket=ticket, verifier="proof"),
                    HTTP_HOST="newsblur.com",
                    HTTP_ORIGIN=origin,
                    HTTP_X_FORWARDED_PROTO="https",
                    HTTP_X_FORWARDED_HOST="attacker.example",
                )
                with patch.object(social_auth.SocialIdentity, "objects") as identities, patch.object(
                    social_auth, "login"
                ) as login:
                    identities.filter.return_value.select_related.return_value.first.return_value = (
                        SimpleNamespace(user=SimpleNamespace(is_active=True, username="reader"))
                    )
                    self.assertEqual(social_auth.complete(request).status_code, status)
                    self.assertEqual(login.call_count, int(status == 200))

    @override_settings(
        SOCIAL_APPLE_WEB_CLIENT_ID="com.newsblur.web",
        SOCIAL_APPLE_REDIRECT_URI="https://staging.newsblur.com/api/social/apple/callback",
    )
    def test_android_apple_deletion_exchange_retains_original_authorization_redirect(self):
        for platform in ("android", "android-alpha", "ios"):
            with self.subTest(platform=platform):
                user = Mock(pk=42, is_authenticated=True, is_active=True)
                user.social_identities.filter.return_value.exists.return_value = True
                request = self.factory.post(
                    "/api/social/start",
                    dict(
                        provider="apple",
                        platform=platform,
                        purpose="delete_account",
                        challenge=hashlib.sha256(b"proof").hexdigest(),
                        redirect_uri="https://attacker.example/ignored",
                    ),
                )
                request.user, request.session = user, SimpleNamespace(session_key="session")
                started = json.loads(social_auth.start(request).content)
                client_id = "com.newsblur.NewsBlur" if platform == "ios" else "com.newsblur.web"
                if platform != "ios":
                    redirect_uri = parse_qs(urlparse(started["url"]).query)["redirect_uri"][0]
                token = jwt.encode(
                    dict(self.claims, aud=client_id, nonce=started["nonce"]), self.key, algorithm="RS256"
                )
                exchange = Mock()
                exchange.json.return_value = {"id_token": token, "refresh_token": "refresh-token"}
                with override_settings(
                    SOCIAL_APPLE_REDIRECT_URI="https://changed.newsblur.com/api/social/apple/callback"
                ), patch.object(
                    social_auth.APPLE_KEYS,
                    "get_signing_key_from_jwt",
                    return_value=SimpleNamespace(key=self.key.public_key()),
                ), patch.object(
                    social_auth, "apple_client_secret", return_value="client-secret"
                ), patch.object(
                    social_auth.requests, "post", return_value=exchange
                ) as post, patch.object(
                    social_auth.SocialIdentity, "objects"
                ) as identities:
                    callback_request = self.factory.post(
                        "/api/social/apple" if platform == "ios" else "/api/social/apple/callback",
                        dict(
                            state=started["state"],
                            id_token=token,
                            code="authorization-code",
                            authorization_code="authorization-code",
                            redirect_uri="https://attacker.example/ignored",
                        ),
                    )
                    if platform == "ios":
                        ticket = json.loads(social_auth.apple(callback_request).content)["ticket"]
                    else:
                        callback = social_auth.apple_callback(callback_request)
                        ticket = parse_qs(urlparse(callback.url).query)["ticket"][0]
                    identities.filter.return_value.select_related.return_value.first.return_value = (
                        SimpleNamespace(user_id=42, pk=8)
                    )
                    complete = self.factory.post(
                        "/api/social/complete",
                        dict(
                            ticket=ticket, verifier="proof", redirect_uri="https://attacker.example/ignored"
                        ),
                    )
                    complete.user, complete.session = user, request.session
                    response = social_auth.complete(complete)
                    self.assertEqual(response.status_code, 200)
                    self.assertIn("delete_token", json.loads(response.content))
                    data = post.call_args.kwargs["data"]
                    self.assertEqual(data["client_id"], client_id)
                    if platform == "ios":
                        self.assertNotIn("redirect_uri", data)
                    else:
                        self.assertEqual(data.get("redirect_uri"), redirect_uri)

    @override_settings(SOCIAL_APPLE_WEB_CLIENT_ID="com.newsblur.web")
    def test_android_apple_callback_requires_web_audience_and_one_use_state(self):
        for audience, accepted in [("com.newsblur.NewsBlur", False), ("com.newsblur.web", True)]:
            response = social_auth.start(
                self.factory.post(
                    "/api/social/start", dict(provider="apple", platform="android-alpha", challenge="a" * 64)
                )
            )
            data = json.loads(response.content)
            query = parse_qs(urlparse(data["url"]).query)
            self.assertEqual(query["client_id"], ["com.newsblur.web"])
            self.assertEqual(query["response_mode"], ["form_post"])
            token = jwt.encode(
                dict(self.claims, aud=audience, nonce=data["nonce"]), self.key, algorithm="RS256"
            )
            request = self.factory.post(
                "/api/social/apple/callback", dict(state=data["state"], id_token=token)
            )
            with patch.object(
                social_auth.APPLE_KEYS,
                "get_signing_key_from_jwt",
                return_value=SimpleNamespace(key=self.key.public_key()),
            ):
                callback = social_auth.apple_callback(request)
            self.assertTrue(callback.url.startswith("newsblur-auth-android-alpha://complete?"))
            result = parse_qs(urlparse(callback.url).query)
            self.assertEqual("ticket" in result, accepted)
            self.assertEqual(social_auth.apple_callback(request).status_code, 400)
        # test_social_auth.py also proves native verification did not gain the browser audience.
        with self.assertRaises(jwt.InvalidAudienceError):
            self.verify(dict(aud="com.newsblur.web"))

    def test_platform_cannot_redirect_to_an_arbitrary_app(self):
        response = social_auth.start(
            self.factory.post(
                "/api/social/start",
                dict(provider="google", platform="attacker://callback", challenge="a" * 64),
            )
        )
        self.assertEqual(response.status_code, 400)
        data = json.loads(
            social_auth.start(
                self.factory.post(
                    "/api/social/start", dict(provider="google", platform="android", challenge="a" * 64)
                )
            ).content
        )
        cancelled = social_auth.google_callback(
            self.factory.get("/api/social/google/callback", dict(state=data["state"], error="access_denied"))
        )
        self.assertTrue(cancelled.url.startswith("newsblur-auth-android://complete?error="))

    @override_settings(SOCIAL_APPLE_WEB_CLIENT_ID="")
    def test_unconfigured_android_apple_fails_without_changing_native_signin(self):
        for platform, status in [("android", 503), ("ios", 200)]:
            response = social_auth.start(
                self.factory.post(
                    "/api/social/start", dict(provider="apple", platform=platform, challenge="a" * 64)
                )
            )
            self.assertEqual(response.status_code, status)

    def test_password_deletion_requires_confirmation_password_and_no_social_identity(self):
        user = Mock(pk=9, is_authenticated=True, is_active=True, username="reader")
        user.social_identities.exists.return_value = False
        with patch.object(social_auth, "authenticate", return_value=user) as authenticate, patch.object(
            social_auth, "logout"
        ):
            for fields in ({"confirm": "Delete", "password": ""}, {"confirm": "no", "password": "secret"}):
                request = self.factory.post("/api/social/delete_password_account", fields)
                request.user, request.session = user, SimpleNamespace(session_key="session")
                self.assertEqual(social_auth.delete_password_account(request).status_code, 400)
                user.profile.delete_user.assert_not_called()
            authenticate.assert_not_called()
            request = self.factory.post(
                "/api/social/delete_password_account", {"confirm": "Delete", "password": "secret"}
            )
            request.user, request.session = user, SimpleNamespace(session_key="session")
            user.social_identities.exists.return_value = True
            self.assertEqual(social_auth.delete_password_account(request).status_code, 403)
            authenticate.assert_not_called()
            user.social_identities.exists.return_value = False
            authenticate.return_value = None
            self.assertEqual(social_auth.delete_password_account(request).status_code, 403)
            user.profile.delete_user.assert_not_called()
            authenticate.return_value = user
            self.assertEqual(social_auth.delete_password_account(request).status_code, 200)
            user.profile.delete_user.assert_called_once_with(confirm=True)

    def test_google_start_requests_identity_only_and_nonce(self):
        response = social_auth.start(
            self.factory.post("/api/social/start", dict(provider="google", challenge="a" * 64))
        )
        from urllib.parse import parse_qs, urlparse

        data = json.loads(response.content)
        query = parse_qs(urlparse(data["url"]).query)
        self.assertEqual(query["scope"], ["openid email"])
        self.assertEqual(query["nonce"], [data["nonce"]])
        self.assertEqual(query["state"], [data["state"]])

    def test_rate_limit_separates_clients_and_ignores_spoofed_forwarded_prefix(self):
        for index in range(31):
            request = self.factory.post(
                "/api/social/start",
                HTTP_X_FORWARDED_FOR=f"spoofed-{index}, 203.0.113.7, spoofed-{index}",
                REMOTE_ADDR="10.0.0.1",
            )
            self.assertEqual(social_auth.rate_limited(request), index == 30)
        other = self.factory.post(
            "/api/social/start", HTTP_X_FORWARDED_FOR="203.0.113.8, 203.0.113.8", REMOTE_ADDR="10.0.0.1"
        )
        self.assertFalse(social_auth.rate_limited(other))

    def test_existing_email_does_not_link_without_existing_credentials(self):
        token = social_auth.remember(
            "ticket",
            dict(
                challenge=hashlib.sha256(b"proof").hexdigest(),
                identity=dict(provider="apple", subject="subject", email="reader@example.com"),
            ),
        )
        with patch.object(social_auth.SocialIdentity, "objects") as identities, patch.object(
            social_auth.User, "objects"
        ) as users, patch.object(social_auth, "authenticate", return_value=None), patch.object(
            social_auth, "login"
        ) as login:
            identities.filter.return_value.select_related.return_value.first.return_value = None
            users.filter.return_value.__getitem__.return_value = [
                SimpleNamespace(
                    pk=42, username="reader", email="reader@example.com", has_usable_password=lambda: True
                )
            ]
            result = social_auth.complete(
                self.factory.post("/api/social/complete", dict(ticket=token, verifier="proof"))
            )
            self.assertTrue(json.loads(result.content)["link_required"])
            identities.create.assert_not_called()
            login.assert_not_called()

    def test_linked_subject_survives_email_change(self):
        token = social_auth.remember(
            "ticket",
            dict(
                challenge=hashlib.sha256(b"proof").hexdigest(),
                identity=dict(provider="apple", subject="subject", email="changed@example.com"),
            ),
        )
        user = SimpleNamespace(is_active=True, username="reader")
        with patch.object(social_auth.SocialIdentity, "objects") as identities, patch.object(
            social_auth.User, "objects"
        ) as users, patch.object(social_auth, "login") as login:
            identities.filter.return_value.select_related.return_value.first.return_value = SimpleNamespace(
                user=user
            )
            result = social_auth.complete(
                self.factory.post("/api/social/complete", dict(ticket=token, verifier="proof"))
            )
            self.assertEqual(json.loads(result.content)["code"], 1)
            users.filter.assert_not_called()
            login.assert_called_once()

    def test_inactive_linked_account_cannot_sign_in(self):
        token = social_auth.remember(
            "ticket",
            dict(
                challenge=hashlib.sha256(b"proof").hexdigest(),
                identity=dict(provider="apple", subject="subject", email="reader@example.com"),
            ),
        )
        with patch.object(social_auth.SocialIdentity, "objects") as identities, patch.object(
            social_auth, "login"
        ) as login:
            identities.filter.return_value.select_related.return_value.first.return_value = SimpleNamespace(
                user=SimpleNamespace(is_active=False)
            )
            self.assertEqual(
                social_auth.complete(
                    self.factory.post("/api/social/complete", dict(ticket=token, verifier="proof"))
                ).status_code,
                403,
            )
            login.assert_not_called()

    def test_google_callback_returns_only_a_single_use_app_bound_ticket(self):
        state = social_auth.remember("state", dict(provider="google", nonce="nonce", challenge="c" * 64))
        claims = dict(self.claims, aud="google-client", iss="https://accounts.google.com")
        token = jwt.encode(claims, self.key, algorithm="RS256")
        response = Mock()
        response.json.return_value = {"id_token": token}
        with patch.object(social_auth.requests, "post", return_value=response), patch.object(
            social_auth.GOOGLE_KEYS,
            "get_signing_key_from_jwt",
            return_value=SimpleNamespace(key=self.key.public_key()),
        ):
            result = social_auth.google_callback(
                self.factory.get("/api/social/google/callback", dict(state=state, code="authorization-code"))
            )
        from urllib.parse import parse_qs, urlparse

        self.assertEqual(result.status_code, 302)
        url = urlparse(result["Location"])
        self.assertEqual((url.scheme, url.netloc), ("newsblur-auth", "complete"))
        query = parse_qs(url.query)
        self.assertEqual(set(query), {"ticket"})
        ticket = social_auth.consume("ticket", query["ticket"][0])
        self.assertEqual(ticket["challenge"], "c" * 64)
        self.assertEqual(ticket["identity"]["subject"], "provider-subject")
        self.assertIsNone(social_auth.consume("state", state))

    def test_new_social_user_must_choose_a_username_before_creation(self):
        ticket = social_auth.remember(
            "ticket",
            dict(
                challenge=hashlib.sha256(b"proof").hexdigest(),
                identity=dict(provider="apple", subject="subject", email="reader@example.com"),
            ),
        )
        with patch.object(social_auth.SocialIdentity, "objects") as identities, patch.object(
            social_auth.User, "objects"
        ) as users, patch.object(social_auth, "SignupForm") as form:
            identities.filter.return_value.select_related.return_value.first.return_value = None
            users.filter.return_value.__getitem__.return_value = []
            response = social_auth.complete(
                self.factory.post("/api/social/complete", dict(ticket=ticket, verifier="proof"))
            )
            self.assertTrue(json.loads(response.content)["username_required"])
            form.assert_not_called()

    def test_unusable_social_password_never_enters_legacy_blank_password_fallback(self):
        from apps.profile.models import blank_authenticate

        user = social_auth.User(username="provideronly")
        user.set_unusable_password()
        with patch("apps.profile.models.User.objects.get", return_value=user):
            self.assertIsNone(blank_authenticate(user.username))

    @override_settings(
        SOCIAL_APPLE_TEAM_ID="team",
        SOCIAL_APPLE_KEY_ID="key",
        SOCIAL_APPLE_PRIVATE_KEY_PATH="/private/signin.p8",
    )
    def test_apple_client_secret_is_short_lived_and_bound_to_native_client(self):
        key = ec.generate_private_key(ec.SECP256R1())
        pem = key.private_bytes(
            serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()
        ).decode()
        with patch("builtins.open", mock_open(read_data=pem)):
            token = social_auth.apple_client_secret("com.newsblur.NewsBlur")
        claims = jwt.decode(
            token, key.public_key(), algorithms=["ES256"], audience="https://appleid.apple.com"
        )
        self.assertEqual(claims["iss"], "team")
        self.assertEqual(claims["sub"], "com.newsblur.NewsBlur")
        self.assertLessEqual(claims["exp"] - claims["iat"], 600)
        self.assertEqual(jwt.get_unverified_header(token)["kid"], "key")

    def apple_exchange(self, changes=None, response=None, omit=(), key=None):
        claims = dict(self.claims, **(changes or {}))
        for name in omit:
            claims.pop(name, None)
        token = jwt.encode(claims, key or self.key, algorithm="RS256")
        response = response or Mock()
        response.json.return_value = {"id_token": token, "refresh_token": "private-refresh-token"}
        with patch.object(
            social_auth, "apple_client_secret", return_value="private-client-secret"
        ), patch.object(social_auth.requests, "post", return_value=response) as post, patch.object(
            social_auth.APPLE_KEYS,
            "get_signing_key_from_jwt",
            return_value=SimpleNamespace(key=self.key.public_key()),
        ):
            result = social_auth.prepare_apple_revocation(
                "private-authorization-code",
                "com.newsblur.NewsBlur",
                {"provider": "apple", "subject": "provider-subject", "email": "reader@example.com"},
                "nonce",
            )
        return result, post

    def test_apple_exchange_verifies_identity_before_retaining_revocation_token(self):
        result, post = self.apple_exchange()
        self.assertEqual(
            result,
            {
                "client_id": "com.newsblur.NewsBlur",
                "token": "private-refresh-token",
                "token_type_hint": "refresh_token",
            },
        )
        self.assertEqual(post.call_args.args[0], "https://appleid.apple.com/auth/token")
        self.assertEqual(post.call_args.kwargs["data"]["grant_type"], "authorization_code")
        self.assertEqual(post.call_args.kwargs["data"]["code"], "private-authorization-code")
        self.assertLessEqual(post.call_args.kwargs["timeout"], 10)

    def test_apple_exchange_accepts_missing_nonce_and_email_but_native_identity_requires_them(self):
        for omitted in (("nonce",), ("email", "email_verified"), ("nonce", "email", "email_verified")):
            with self.subTest(omitted=omitted):
                result, _ = self.apple_exchange(omit=omitted)
                self.assertIsNotNone(result)
                self.assertEqual(result["token"], "private-refresh-token")
                native_token = jwt.encode(
                    {key: value for key, value in self.claims.items() if key not in omitted},
                    self.key,
                    algorithm="RS256",
                )
                with patch.object(
                    social_auth.APPLE_KEYS,
                    "get_signing_key_from_jwt",
                    return_value=SimpleNamespace(key=self.key.public_key()),
                ), self.assertRaises((jwt.PyJWTError, ValueError)):
                    social_auth.verified_claims("apple", native_token, "nonce")

    def test_apple_exchange_rejects_wrong_signature_and_missing_required_claims(self):
        with self.assertLogs("apps.api.social_auth", level="WARNING"):
            result, _ = self.apple_exchange(
                key=rsa.generate_private_key(public_exponent=65537, key_size=2048)
            )
        self.assertIsNone(result)
        for missing in ("sub", "aud", "iss", "exp", "iat"):
            with self.subTest(missing=missing), self.assertLogs("apps.api.social_auth", level="WARNING"):
                result, _ = self.apple_exchange(omit=(missing, "nonce", "email", "email_verified"))
                self.assertIsNone(result)

    def test_apple_deletion_ticket_captures_code_and_verified_audience_without_polluting_identity(self):
        state = social_auth.remember(
            "state",
            dict(
                provider="apple",
                purpose="delete_account",
                nonce="nonce",
                challenge="a" * 64,
                user_id=42,
                session_key="session",
            ),
        )
        token = jwt.encode(self.claims, self.key, algorithm="RS256")
        with patch.object(
            social_auth.APPLE_KEYS,
            "get_signing_key_from_jwt",
            return_value=SimpleNamespace(key=self.key.public_key()),
        ):
            response = social_auth.apple(
                self.factory.post(
                    "/api/social/apple",
                    {
                        "state": state,
                        "id_token": token,
                        "authorization_code": "private-authorization-code",
                    },
                )
            )
        ticket = social_auth.consume("ticket", json.loads(response.content)["ticket"])
        self.assertEqual(ticket["apple_client_id"], "com.newsblur.NewsBlur")
        self.assertEqual(ticket["apple_authorization_code"], "private-authorization-code")
        self.assertNotIn("audience", ticket["identity"])

    @override_settings(SOCIAL_APPLE_TEAM_ID="", SOCIAL_APPLE_KEY_ID="", SOCIAL_APPLE_PRIVATE_KEY_PATH="")
    def test_apple_missing_configuration_and_exchange_failure_return_no_revocation_token(self):
        with patch.object(social_auth.requests, "post") as post, self.assertLogs(
            "apps.api.social_auth", level="WARNING"
        ):
            self.assertIsNone(
                social_auth.prepare_apple_revocation("code", "com.newsblur.NewsBlur", {}, "nonce")
            )
            post.assert_not_called()
        response = Mock()
        response.raise_for_status.side_effect = social_auth.requests.Timeout("private-authorization-code")
        with self.assertLogs("apps.api.social_auth", level="WARNING") as logs:
            result, _ = self.apple_exchange(response=response)
        self.assertIsNone(result)
        self.assertNotIn("private-", " ".join(logs.output))

    @override_settings(SOCIAL_APPLE_CLIENT_IDS=["com.newsblur.NewsBlur", "com.newsblur.NB-Alpha"])
    def test_apple_exchange_rejects_subject_audience_nonce_mixups_without_logging_secrets(self):
        for changes in (
            {"sub": "another-subject"},
            {"aud": "com.newsblur.NB-Alpha"},
            {"nonce": "another-nonce"},
            {"iss": "https://attacker.example"},
            {"exp": int(time.time()) - 10},
        ):
            with self.subTest(changes=changes), self.assertLogs(
                "apps.api.social_auth", level="WARNING"
            ) as logs:
                result, _ = self.apple_exchange(changes)
                self.assertIsNone(result)
            self.assertNotIn("private-", " ".join(logs.output))

    def test_apple_revocation_failure_is_sanitized_and_nonfatal(self):
        context = {
            "client_id": "com.newsblur.NewsBlur",
            "token": "private-refresh-token",
            "token_type_hint": "refresh_token",
        }
        with patch.object(
            social_auth, "apple_client_secret", return_value="private-client-secret"
        ), patch.object(
            social_auth.requests,
            "post",
            side_effect=social_auth.requests.Timeout("private-refresh-token private-client-secret"),
        ), self.assertLogs(
            "apps.api.social_auth", level="WARNING"
        ) as logs:
            self.assertFalse(social_auth.revoke_apple_token(context))
        self.assertNotIn("private-", " ".join(logs.output))
        with patch.object(social_auth, "apple_client_secret", return_value="client-secret"), patch.object(
            social_auth.requests, "post"
        ) as post:
            self.assertTrue(social_auth.revoke_apple_token(context))
            self.assertEqual(post.call_args.args[0], "https://appleid.apple.com/auth/revoke")
            self.assertEqual(post.call_args.kwargs["data"]["token"], context["token"])

    def test_apple_deletion_prepares_token_before_confirmation_and_revokes_only_on_delete(self):
        context = {
            "client_id": "com.newsblur.NewsBlur",
            "token": "refresh-token",
            "token_type_hint": "refresh_token",
        }
        ticket = social_auth.remember(
            "ticket",
            {
                "purpose": "delete_account",
                "user_id": 42,
                "session_key": "session",
                "challenge": hashlib.sha256(b"proof").hexdigest(),
                "nonce": "nonce",
                "apple_authorization_code": "code",
                "apple_client_id": "com.newsblur.NewsBlur",
                "identity": {
                    "provider": "apple",
                    "subject": "provider-subject",
                    "email": "reader@example.com",
                },
            },
        )
        user = Mock(pk=42, is_authenticated=True, is_active=True)
        request = self.factory.post("/api/social/complete", {"ticket": ticket, "verifier": "proof"})
        request.user, request.session = user, SimpleNamespace(session_key="session")
        with patch.object(social_auth.SocialIdentity, "objects") as identities, patch.object(
            social_auth, "prepare_apple_revocation", return_value=context
        ) as prepare, patch.object(
            social_auth, "revoke_apple_token", return_value=True
        ) as revoke, patch.object(
            social_auth, "logout"
        ):
            identities.filter.return_value.select_related.return_value.first.return_value = SimpleNamespace(
                user_id=42, pk=8
            )
            response = social_auth.complete(request)
            proof = json.loads(response.content)["delete_token"]
            prepare.assert_called_once_with(
                "code",
                "com.newsblur.NewsBlur",
                {"provider": "apple", "subject": "provider-subject", "email": "reader@example.com"},
                "nonce",
            )
            revoke.assert_not_called()
            cached = cache.get("social:delete-account:" + proof)
            self.assertEqual(cached["apple_revocation"], context)
            self.assertNotIn("apple_authorization_code", cached)
            delete = self.factory.post(
                "/api/social/delete_account", {"delete_token": proof, "confirm": "Delete"}
            )
            delete.user, delete.session = user, request.session
            result = social_auth.delete_account(delete)
            self.assertEqual(json.loads(result.content), {"code": 1})
            revoke.assert_called_once_with(context)
            user.profile.delete_user.assert_called_once_with(confirm=True)

    def test_apple_revocation_unavailable_still_deletes_and_returns_manual_guidance(self):
        user = Mock(pk=42, is_authenticated=True, is_active=True)
        proof = social_auth.remember(
            "delete-account",
            {
                "purpose": "delete_account",
                "user_id": 42,
                "session_key": "session",
                "identity_id": 8,
                "apple_revocation": None,
            },
        )
        request = self.factory.post(
            "/api/social/delete_account", {"delete_token": proof, "confirm": "Delete"}
        )
        request.user, request.session = user, SimpleNamespace(session_key="session")
        with patch.object(social_auth, "logout"):
            result = json.loads(social_auth.delete_account(request).content)
        self.assertEqual(result["code"], 1)
        self.assertTrue(result["apple_revocation_required"])
        self.assertEqual(result["apple_revocation_url"], "https://support.apple.com/en-us/102571")
        user.profile.delete_user.assert_called_once_with(confirm=True)


@override_settings(
    CACHES={"default": {"BACKEND": "django.core.cache.backends.locmem.LocMemCache"}},
    AUTO_ENABLE_NEW_USERS=True,
    AUTO_PREMIUM_NEW_USERS=False,
)
class Test_SocialAuthenticationDatabase(TransactionTestCase):
    def setUp(self):
        cache.clear()
        revocation = patch("apps.api.social_auth.prepare_apple_revocation", return_value=None)
        revocation.start()
        self.addCleanup(revocation.stop)
        # test_social_auth.py isolates external signup effects while exercising real users, identities and sessions.
        self.effects = {}
        for target in [
            "apps.profile.tasks.EmailNewPremiumTrial.delay",
            "apps.reader.forms.EmailNewUser.delay",
            "apps.reader.forms.RNewUserQueue.add_user",
            "apps.reader.forms.MActivity.new_signup",
            "apps.reader.forms.query",
            "apps.profile.models.Profile.activate_free",
        ]:
            patcher = patch(target)
            self.effects[target] = patcher.start()
            self.addCleanup(patcher.stop)

    def complete(self, username="reader", password="", provider="apple", **data):
        ticket = social_auth.remember(
            "ticket",
            dict(
                challenge=hashlib.sha256(b"proof").hexdigest(),
                identity=dict(provider=provider, subject="subject", email="reader@example.com"),
            ),
        )
        return self.client.post(
            "/api/social/complete",
            dict(ticket=ticket, verifier="proof", username=username, password=password, **data),
        )

    def test_explicit_link_accepts_different_provider_email_only_after_password_proof(self):
        user = social_auth.User.objects.create_user("reader", "account@example.com", "existing-password")
        for provider in ("apple", "google"):
            with self.subTest(provider=provider):
                self.client.logout()
                response = self.complete(provider=provider, action="link", password="wrong")
                self.assertTrue(response.json().get("link_required"), response.content)
                self.assertFalse(social_auth.SocialIdentity.objects.filter(provider=provider).exists())
                self.assertNotIn("_auth_user_id", self.client.session)
                response = self.complete(provider=provider, action="link", password="existing-password")
                self.assertEqual(response.status_code, 200, response.content)
                self.assertFalse(response.json()["created"])
                identity = social_auth.SocialIdentity.objects.get(provider=provider)
                self.assertEqual(identity.user_id, user.pk)
                self.assertEqual(identity.email, "reader@example.com")
                self.assertEqual(int(self.client.session["_auth_user_id"]), user.pk)
        user.refresh_from_db()
        self.assertEqual(user.email, "account@example.com")
        self.assertEqual(social_auth.User.objects.count(), 1)

    def test_explicit_link_never_creates_an_account_for_unknown_credentials(self):
        response = self.complete(username="missing", password="supplied-password", action="link")
        self.assertTrue(response.json().get("link_required"), response.content)
        self.assertFalse(social_auth.User.objects.exists())
        self.assertFalse(social_auth.SocialIdentity.objects.exists())

    def test_explicit_link_accepts_case_insensitive_username_or_unique_account_email(self):
        user = social_auth.User.objects.create_user("Reader", "Account@example.com", "existing-password")
        for provider, identifier in (("apple", " rEADER "), ("google", " ACCOUNT@EXAMPLE.COM ")):
            with self.subTest(identifier=identifier):
                self.client.logout()
                response = self.complete(
                    provider=provider, username=identifier, password="existing-password", action="link"
                )
                self.assertEqual(response.status_code, 200, response.content)
                self.assertFalse(response.json()["created"])
                self.assertEqual(social_auth.SocialIdentity.objects.get(provider=provider).user_id, user.pk)
                self.assertEqual(int(self.client.session["_auth_user_id"]), user.pk)
        user.refresh_from_db()
        self.assertEqual(user.email, "Account@example.com")
        self.assertEqual(social_auth.User.objects.count(), 1)

    def test_explicit_link_bad_credentials_are_generic_and_ticket_can_retry(self):
        user = social_auth.User.objects.create_user("reader", "account@example.com", "existing-password")
        for username, password in (
            ("reader", ""),
            ("reader", "wrong"),
            ("missing", "secret"),
            ("", "secret"),
        ):
            with self.subTest(username=username, password=password):
                response = self.complete(username=username, password=password, action="link")
                result = response.json()
                self.assertEqual(response.status_code, 400, response.content)
                self.assertEqual(
                    result["message"], "Sign in to your existing NewsBlur account to connect this provider."
                )
                self.assertTrue(result["link_required"])
                self.assertTrue(result["ticket"])
                self.assertFalse(result.get("username_required", False))
                self.assertFalse(social_auth.SocialIdentity.objects.exists())
                self.assertNotIn("_auth_user_id", self.client.session)
                self.assertEqual(social_auth.User.objects.count(), 1)
        response = self.client.post(
            "/api/social/complete",
            dict(
                ticket=result["ticket"],
                verifier="proof",
                username="reader",
                password="existing-password",
                action="link",
            ),
        )
        self.assertEqual(response.status_code, 200, response.content)
        self.assertEqual(social_auth.SocialIdentity.objects.get().user_id, user.pk)

    def test_explicit_link_rejects_inactive_and_passwordless_accounts(self):
        for username, password, active in (
            ("inactive", "existing-password", False),
            ("passwordless", None, True),
            ("blankpassword", "", True),
        ):
            with self.subTest(username=username):
                user = social_auth.User.objects.create_user(
                    username, username + "@example.com", password, is_active=active
                )
                original_password = user.password
                for supplied_password in ("", username, password or "wrong"):
                    response = self.complete(username=username, password=supplied_password, action="link")
                    result = response.json()
                    self.assertEqual(response.status_code, 400, response.content)
                    self.assertTrue(result["link_required"])
                    self.assertTrue(result["ticket"])
                    self.assertEqual(
                        result["message"],
                        "Sign in to your existing NewsBlur account to connect this provider.",
                    )
                    self.assertFalse(social_auth.SocialIdentity.objects.exists())
                    self.assertNotIn("_auth_user_id", self.client.session)
                user.refresh_from_db()
                self.assertEqual(user.password, original_password)
        self.assertEqual(social_auth.User.objects.count(), 3)

    def test_explicit_link_rejects_ambiguous_email_but_username_resolves_duplicate_provider_email(self):
        user = social_auth.User.objects.create_user("reader", "reader@example.com", "existing-password")
        social_auth.User.objects.create_user("other", "READER@example.com", "existing-password")
        response = self.complete(username="reader@example.com", password="existing-password", action="link")
        self.assertEqual(response.status_code, 400, response.content)
        self.assertTrue(response.json()["link_required"])
        self.assertTrue(response.json()["ticket"])
        self.assertFalse(social_auth.SocialIdentity.objects.exists())
        self.assertNotIn("_auth_user_id", self.client.session)
        response = self.complete(username="READER", password="existing-password", action="link")
        self.assertEqual(response.status_code, 200, response.content)
        self.assertEqual(social_auth.SocialIdentity.objects.get().user_id, user.pk)
        self.assertEqual(social_auth.User.objects.count(), 2)

    def test_explicit_link_rejects_ambiguous_case_insensitive_username(self):
        social_auth.User.objects.create_user("reader", "first@example.com", "first-password")
        social_auth.User.objects.create_user("Reader", "second@example.com", "second-password")
        response = self.complete(username="reader", password="first-password", action="link")
        self.assertEqual(response.status_code, 400, response.content)
        self.assertTrue(response.json()["link_required"])
        self.assertTrue(response.json()["ticket"])
        self.assertFalse(social_auth.SocialIdentity.objects.exists())
        self.assertNotIn("_auth_user_id", self.client.session)

    def test_explicit_link_ignores_provider_email_matching_another_account(self):
        user = social_auth.User.objects.create_user("reader", "account@example.com", "existing-password")
        social_auth.User.objects.create_user("other", "reader@example.com", "other-password")
        response = self.complete(password="existing-password", action="link")
        self.assertEqual(response.status_code, 200, response.content)
        self.assertEqual(social_auth.SocialIdentity.objects.get().user_id, user.pk)
        user.refresh_from_db()
        self.assertEqual(user.email, "account@example.com")

    def test_explicit_link_cannot_move_existing_provider_identity(self):
        owner = social_auth.User.objects.create_user("owner", "owner@example.com", "owner-password")
        social_auth.User.objects.create_user("reader", "account@example.com", "existing-password")
        for provider in ("apple", "google"):
            with self.subTest(provider=provider):
                self.client.logout()
                identity = social_auth.SocialIdentity.objects.create(
                    user=owner, provider=provider, subject="subject", email=owner.email
                )
                response = self.complete(provider=provider, password="existing-password", action="link")
                self.assertEqual(response.status_code, 200, response.content)
                self.assertFalse(response.json()["created"])
                self.assertEqual(int(self.client.session["_auth_user_id"]), owner.pk)
                identity.refresh_from_db()
                self.assertEqual(identity.user_id, owner.pk)
        self.assertEqual(social_auth.User.objects.count(), 2)

    def test_different_email_signup_does_not_implicitly_link_taken_username(self):
        user = social_auth.User.objects.create_user("reader", "account@example.com", "existing-password")
        response = self.complete(password="existing-password")
        self.assertTrue(response.json().get("link_required"), response.content)
        self.assertIn("This account already exists.", response.json()["message"])
        self.assertFalse(social_auth.SocialIdentity.objects.exists())
        self.assertNotIn("_auth_user_id", self.client.session)
        self.assertEqual(social_auth.User.objects.get().pk, user.pk)

    def test_creates_passwordless_account_and_reuses_identity_with_authenticated_session(self):
        result = self.complete()
        self.assertEqual(result.status_code, 200, result.content)
        self.assertTrue(result.json()["created"])
        user = social_auth.User.objects.get(username="reader")
        self.assertFalse(user.has_usable_password())
        self.assertEqual(social_auth.SocialIdentity.objects.get(subject="subject").user_id, user.pk)
        self.assertEqual(int(self.client.session["_auth_user_id"]), user.pk)
        self.client.logout()
        self.assertFalse(self.complete(username="").json()["created"])
        self.assertEqual(int(self.client.session["_auth_user_id"]), user.pk)

    def test_existing_account_links_only_after_password_proof(self):
        user = social_auth.User.objects.create_user("reader", "reader@example.com", "existing-password")
        self.assertTrue(self.complete(password="wrong-password").json()["link_required"])
        self.assertFalse(social_auth.SocialIdentity.objects.exists())
        self.assertNotIn("_auth_user_id", self.client.session)
        result = self.complete(password="existing-password")
        self.assertEqual(result.status_code, 200, result.content)
        self.assertFalse(result.json()["created"])
        self.assertEqual(social_auth.SocialIdentity.objects.get(subject="subject").user_id, user.pk)
        self.assertEqual(int(self.client.session["_auth_user_id"]), user.pk)

    def test_signup_external_effects_wait_for_commit_and_see_linked_identity(self):
        targets = [name for name in self.effects if name != "apps.reader.forms.query"]
        with transaction.atomic():
            self.assertEqual(self.complete().status_code, 200)
            for target in targets:
                self.effects[target].assert_not_called()
        user = social_auth.User.objects.get(username="reader")
        self.assertEqual(social_auth.SocialIdentity.objects.get(subject="subject").user_id, user.pk)
        for target in targets:
            self.effects[target].assert_called_once()

    def test_failed_identity_creation_rolls_back_user_without_external_signup_effects(self):
        with patch.object(
            social_auth.SocialIdentity.objects, "create", side_effect=IntegrityError("duplicate identity")
        ):
            self.assertEqual(self.complete().status_code, 400)
        self.assertFalse(social_auth.User.objects.filter(username="reader").exists())
        for target, effect in self.effects.items():
            if target != "apps.reader.forms.query":
                effect.assert_not_called()

    def test_passwordless_account_names_existing_provider_instead_of_requesting_missing_password(self):
        user = social_auth.User.objects.create_user("reader", "reader@example.com")
        social_auth.SocialIdentity.objects.create(
            user=user, provider="google", subject="google-subject", email=user.email
        )
        result = self.complete().json()
        self.assertEqual(result["code"], -1)
        self.assertFalse(result.get("link_required", False))
        self.assertIn("Sign in with Google", result["message"])
        self.assertIn("reset", result["message"].lower())
        self.assertFalse(social_auth.SocialIdentity.objects.filter(provider="apple").exists())

    def test_ambiguous_email_directs_existing_accounts_to_recovery_without_password_link_prompt(self):
        social_auth.User.objects.create_user("reader", "reader@example.com", "first-password")
        social_auth.User.objects.create_user("other", "reader@example.com", "second-password")
        result = self.complete(password="first-password").json()
        self.assertFalse(result.get("link_required", False))
        self.assertIn("support", result["message"].lower())
        self.assertFalse(social_auth.SocialIdentity.objects.exists())

    def deletion_ticket(self, client=None, identity=None):
        client = client or self.client
        start = client.post(
            "/api/social/start",
            {
                "provider": "apple",
                "challenge": hashlib.sha256(b"proof").hexdigest(),
                "purpose": "delete_account",
            },
        )
        self.assertEqual(start.status_code, 200, start.content)
        with patch.object(
            social_auth,
            "verified_claims",
            return_value=identity or dict(provider="apple", subject="subject", email="reader@example.com"),
        ):
            response = client.post(
                "/api/social/apple", {"state": start.json()["state"], "id_token": "signed-token"}
            )
        self.assertEqual(response.status_code, 200, response.content)
        return response.json()["ticket"]

    def complete_deletion(self, ticket, client=None):
        return (client or self.client).post("/api/social/complete", {"ticket": ticket, "verifier": "proof"})

    def test_social_account_lists_only_current_users_linked_providers(self):
        self.assertEqual(self.client.get("/api/social/account").status_code, 401)
        self.complete()
        user = social_auth.User.objects.get(username="reader")
        other = social_auth.User.objects.create_user("other", "other@example.com", "password")
        for owner, provider, subject, email in [
            (user, "google", "google-one", "personal@example.com"),
            (user, "google", "google-two", "work@example.com"),
            (other, "google", "other-google", "private@example.com"),
        ]:
            social_auth.SocialIdentity.objects.create(
                user=owner, provider=provider, subject=subject, email=email
            )
        self.assertEqual(
            self.client.get("/api/social/account").json(),
            {
                "code": 1,
                "providers": ["apple", "google"],
                "has_password": False,
                "connected_accounts": [
                    {"provider": "apple", "email": "reader@example.com"},
                    {"provider": "google", "email": "personal@example.com"},
                    {"provider": "google", "email": "work@example.com"},
                ],
            },
        )

    def test_social_account_without_connections_returns_empty_list(self):
        user = social_auth.User.objects.create_user("reader", "reader@example.com", "password")
        self.client.force_login(user)
        result = self.client.get("/api/social/account").json()
        self.assertEqual(result["connected_accounts"], [])
        self.assertEqual(result["providers"], [])
        self.assertTrue(result["has_password"])

    def test_deletion_start_requires_authenticated_user_and_linked_provider(self):
        data = {"provider": "apple", "challenge": "a" * 64, "purpose": "delete_account"}
        self.assertEqual(self.client.post("/api/social/start", data).status_code, 401)
        self.complete()
        self.assertEqual(
            self.client.post("/api/social/start", dict(data, provider="google")).status_code, 403
        )
        self.assertEqual(
            self.client.post("/api/social/start", dict(data, purpose="unknown")).status_code, 400
        )

    def test_social_signup_can_reauthenticate_and_delete_without_setting_password(self):
        self.complete()
        session_key = self.client.session.session_key
        ticket = self.deletion_ticket()
        response = self.complete_deletion(ticket)
        self.assertEqual(response.status_code, 200, response.content)
        self.assertEqual(set(response.json()), {"code", "delete_token"})
        self.assertEqual(self.client.session.session_key, session_key)
        self.assertFalse(social_auth.User.objects.get(username="reader").has_usable_password())
        self.assertEqual(self.complete_deletion(ticket).status_code, 400)
        token = response.json()["delete_token"]
        with patch("apps.profile.models.Profile.delete_user") as delete_user:
            result = self.client.post(
                "/api/social/delete_account", {"delete_token": token, "confirm": "Delete"}
            )
            self.assertEqual(result.json()["code"], 1)
            self.assertTrue(result.json()["apple_revocation_required"])
            delete_user.assert_called_once_with(confirm=True)
            self.assertNotIn("_auth_user_id", self.client.session)
            self.client.force_login(social_auth.User.objects.get(username="reader"))
            self.assertEqual(
                self.client.post(
                    "/api/social/delete_account", {"delete_token": token, "confirm": "Delete"}
                ).status_code,
                403,
            )
            delete_user.assert_called_once()

    def test_deletion_verification_rejects_other_identity_or_changed_session_without_linking(self):
        self.complete()
        user = social_auth.User.objects.get(username="reader")
        wrong_identity = dict(provider="apple", subject="different-subject", email=user.email)
        self.assertEqual(
            self.complete_deletion(self.deletion_ticket(identity=wrong_identity)).status_code, 403
        )
        ticket = self.deletion_ticket()
        self.client.logout()
        self.client.force_login(user)
        self.assertEqual(self.complete_deletion(ticket).status_code, 403)
        ticket = self.deletion_ticket()
        other = social_auth.User.objects.create_user("other", "other@example.com", "password")
        self.client.force_login(other)
        self.assertEqual(self.complete_deletion(ticket).status_code, 403)
        self.assertEqual(int(self.client.session["_auth_user_id"]), other.pk)
        self.assertEqual(social_auth.SocialIdentity.objects.count(), 1)

    def test_delete_requires_separate_proof_confirmation_and_unchanged_session(self):
        self.complete()
        user = social_auth.User.objects.get(username="reader")
        ordinary_ticket = social_auth.remember(
            "ticket",
            dict(
                challenge=hashlib.sha256(b"proof").hexdigest(),
                identity=dict(provider="apple", subject="subject", email=user.email),
            ),
        )
        with patch("apps.profile.models.Profile.delete_user") as delete_user:
            for invalid in ("", ordinary_ticket):
                self.assertEqual(
                    self.client.post(
                        "/api/social/delete_account", {"delete_token": invalid, "confirm": "Delete"}
                    ).status_code,
                    403,
                )
            token = self.complete_deletion(self.deletion_ticket()).json()["delete_token"]
            self.assertEqual(
                self.client.post(
                    "/api/social/delete_account", {"delete_token": token, "confirm": "Cancel"}
                ).status_code,
                400,
            )
            self.client.logout()
            self.client.force_login(user)
            self.assertEqual(
                self.client.post(
                    "/api/social/delete_account", {"delete_token": token, "confirm": "Delete"}
                ).status_code,
                403,
            )
            delete_user.assert_not_called()

    def test_delete_rejects_unlinked_identity_and_missing_authentication(self):
        self.complete()
        token = self.complete_deletion(self.deletion_ticket()).json()["delete_token"]
        social_auth.SocialIdentity.objects.all().delete()
        with patch("apps.profile.models.Profile.delete_user") as delete_user:
            self.assertEqual(
                self.client.post(
                    "/api/social/delete_account", {"delete_token": token, "confirm": "Delete"}
                ).status_code,
                403,
            )
            self.assertEqual(
                Client()
                .post("/api/social/delete_account", {"delete_token": token, "confirm": "Delete"})
                .status_code,
                401,
            )
            delete_user.assert_not_called()

    @override_settings(SOCIAL_GOOGLE_CLIENT_ID="google-client", SOCIAL_GOOGLE_CLIENT_SECRET="fixture-secret")
    def test_google_browser_callback_preserves_deletion_binding_without_browser_session(self):
        self.complete()
        user = social_auth.User.objects.get(username="reader")
        identity = dict(provider="google", subject="google-subject", email=user.email)
        social_auth.SocialIdentity.objects.create(user=user, **identity)
        data = {
            "provider": "google",
            "challenge": hashlib.sha256(b"proof").hexdigest(),
            "purpose": "delete_account",
        }
        self.assertEqual(self.client.post("/api/social/start", data).status_code, 403)
        user.social_identities.filter(provider="apple").delete()
        start = self.client.post("/api/social/start", data).json()
        self.assertEqual(parse_qs(urlparse(start["url"]).query)["prompt"], ["select_account"])
        browser = Client()
        token_response = Mock()
        token_response.json.return_value = {"id_token": "signed-token"}
        with patch.object(social_auth.requests, "post", return_value=token_response), patch.object(
            social_auth, "verified_claims", return_value=identity
        ):
            callback = browser.get(
                "/api/social/google/callback", {"state": start["state"], "code": "authorization"}
            )
        ticket = parse_qs(urlparse(callback["Location"]).query)["ticket"][0]
        self.assertIn("delete_token", self.complete_deletion(ticket).json())
        cancelled_start = self.client.post("/api/social/start", data).json()
        cancelled = browser.get(
            "/api/social/google/callback", {"state": cancelled_start["state"], "error": "access_denied"}
        )
        self.assertEqual(set(parse_qs(urlparse(cancelled["Location"]).query)), {"error"})

    def test_deletion_proof_expiry_and_other_account_never_delete(self):
        self.complete()
        expired = self.complete_deletion(self.deletion_ticket()).json()["delete_token"]
        cache.delete("social:delete-account:" + expired)
        valid = self.complete_deletion(self.deletion_ticket()).json()["delete_token"]
        other = social_auth.User.objects.create_user("other", "other@example.com", "password")
        other_client = Client()
        other_client.force_login(other)
        with patch("apps.profile.models.Profile.delete_user") as delete_user:
            self.assertEqual(
                self.client.post(
                    "/api/social/delete_account", {"delete_token": expired, "confirm": "Delete"}
                ).status_code,
                403,
            )
            self.assertEqual(
                other_client.post(
                    "/api/social/delete_account", {"delete_token": valid, "confirm": "Delete"}
                ).status_code,
                403,
            )
            delete_user.assert_not_called()
