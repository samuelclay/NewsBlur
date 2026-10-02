"""Security boundaries for apps/api/social_auth.py's native sign-in protocol."""
import hashlib
import json
import time
from types import SimpleNamespace
from unittest.mock import Mock, patch

import jwt
from cryptography.hazmat.primitives.asymmetric import rsa
from django.core.cache import cache
from django.test import RequestFactory, SimpleTestCase, TestCase, override_settings

from apps.api import social_auth


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
                SimpleNamespace(pk=42, username="reader", email="reader@example.com")
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
    CACHES={"default": {"BACKEND": "django.core.cache.backends.locmem.LocMemCache"}},
    AUTO_ENABLE_NEW_USERS=True,
    AUTO_PREMIUM_NEW_USERS=False,
)
class Test_SocialAuthenticationDatabase(TestCase):
    def setUp(self):
        cache.clear()
        # test_social_auth.py isolates external signup effects while exercising real users, identities and sessions.
        for target in [
            "apps.profile.tasks.EmailNewPremiumTrial.delay",
            "apps.reader.forms.EmailNewUser.delay",
            "apps.reader.forms.RNewUserQueue.add_user",
            "apps.reader.forms.MActivity.new_signup",
            "apps.reader.forms.query",
            "apps.profile.models.Profile.activate_free",
        ]:
            patcher = patch(target)
            patcher.start()
            self.addCleanup(patcher.stop)

    def complete(self, username="reader", password=""):
        ticket = social_auth.remember(
            "ticket",
            dict(
                challenge=hashlib.sha256(b"proof").hexdigest(),
                identity=dict(provider="apple", subject="subject", email="reader@example.com"),
            ),
        )
        return self.client.post(
            "/api/social/complete",
            dict(ticket=ticket, verifier="proof", username=username, password=password),
        )

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
