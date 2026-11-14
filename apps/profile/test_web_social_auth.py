"""Browser and account boundaries for apps/profile/web_social_auth.py."""

import hashlib
import re
import time
from types import SimpleNamespace
from unittest.mock import Mock, patch
from urllib.parse import parse_qs, urlparse

import jwt
from cryptography.hazmat.primitives.asymmetric import rsa
from django.conf import settings
from django.contrib.auth.models import User
from django.core.cache import cache
from django.template.loader import render_to_string
from django.test import Client, RequestFactory, TransactionTestCase, override_settings

from apps.api import social_auth
from apps.profile import web_social_auth
from apps.profile.models import SocialIdentity


@override_settings(
    CACHES={"default": {"BACKEND": "django.core.cache.backends.locmem.LocMemCache"}},
    AUTO_ENABLE_NEW_USERS=True,
    AUTO_PREMIUM_NEW_USERS=False,
    SOCIAL_WEB_ENABLED=True,
    SOCIAL_GOOGLE_CLIENT_ID="google-client",
    SOCIAL_GOOGLE_CLIENT_SECRET="google-secret",
    SOCIAL_APPLE_WEB_CLIENT_ID="com.newsblur.web",
    SOCIAL_APPLE_TEAM_ID="team",
    SOCIAL_APPLE_KEY_ID="key",
    SOCIAL_APPLE_PRIVATE_KEY_PATH="/not-a-real-key",
)
class Test_WebSocialAuthentication(TransactionTestCase):
    def setUp(self):
        cache.clear()
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
        self.identity = dict(provider="google", subject="subject", email="reader@example.com")

    def start(self, provider="google", **data):
        response = self.client.post("/account/social/start", dict(provider=provider, **data))
        self.assertEqual(response.status_code, 302, response.content)
        return parse_qs(urlparse(response.url).query)

    def callback(self, params, provider="google", client=None, **data):
        client = client or self.client
        method = client.post if provider == "apple" else client.get
        return method(
            "/account/social/%s/callback" % provider,
            dict(state=params["state"][0], code="authorization-code", **data),
        )

    def verify(self, response, provider="google"):
        token_response = Mock()
        token_response.json.return_value = {"id_token": "signed-token"}
        with patch.object(
            web_social_auth.requests, "post", return_value=token_response
        ) as exchange, patch.object(
            social_auth, "verified_claims", return_value=dict(self.identity, provider=provider)
        ) as verify, patch.object(
            social_auth, "apple_client_secret", return_value="apple-secret"
        ):
            finished = self.client.get(response.url)
        self.assertEqual(finished.status_code, 302, finished.content)
        self.assertEqual(finished.url, "/account/social/continue")
        self.assertEqual(
            verify.call_args.kwargs["expected_audience"],
            "com.newsblur.web" if provider == "apple" else "google-client",
        )
        self.assertIn("/account/social/", exchange.call_args.kwargs["data"]["redirect_uri"])
        return self.client.get(finished.url)

    def test_new_account_chooses_username_and_returns_to_original_page(self):
        params = self.start(next="/folder/Technology")
        response = self.verify(self.callback(params))
        self.assertContains(response, "Choose your username")
        self.assertNotIn("_auth_user_id", self.client.session)
        self.assertContains(self.client.get("/account/social/continue"), "Choose your username")
        response = self.client.post("/account/social/continue", {"username": "reader"})
        self.assertEqual(response.url, "/folder/Technology")
        user = User.objects.get(username="reader")
        self.assertFalse(user.has_usable_password())
        self.assertEqual(SocialIdentity.objects.get(subject="subject").user_id, user.pk)
        self.assertEqual(int(self.client.session["_auth_user_id"]), user.pk)
        self.assertEqual(response.cookies["nb_last_social_provider"].value, "google")
        self.assertNotIn("web_social_pending", self.client.session)

    def connect_google(self):
        return self.verify(self.callback(self.start(purpose="connect_account")))

    def test_account_connection_requires_login_and_csrf(self):
        self.assertEqual(
            self.client.post(
                "/account/social/start", dict(provider="google", purpose="connect_account")
            ).status_code,
            401,
        )
        user = User.objects.create_user("owner", "owner@example.com", "password")
        client = Client(enforce_csrf_checks=True)
        client.force_login(user)
        self.assertEqual(
            client.post(
                "/account/social/start", dict(provider="google", purpose="connect_account")
            ).status_code,
            403,
        )
        account = client.get("/api/social/account")
        token = account.cookies["csrftoken"].value
        response = client.post(
            "/account/social/start",
            dict(provider="google", purpose="connect_account", csrfmiddlewaretoken=token),
        )
        self.assertEqual(response.status_code, 302)

    def test_connecting_from_account_preserves_owner_email_and_session_for_both_providers(self):
        user = User.objects.create_user("owner", "owner@example.com", "password")
        self.client.force_login(user)
        session_key = self.client.session.session_key
        response = self.connect_google()
        self.assertEqual(response.url, "/?next=account")
        params = self.start("apple", purpose="connect_account")
        claims = self.apple_claims(params)
        callback = self.callback(params, "apple", id_token=self.sign_apple(claims))
        finished, _ = self.finish_apple(callback, self.sign_apple(claims))
        self.assertEqual(self.client.get(finished.url).url, "/?next=account")
        self.assertEqual(set(user.social_identities.values_list("provider", flat=True)), {"apple", "google"})
        self.assertEqual(User.objects.count(), 1)
        user.refresh_from_db()
        self.assertEqual(user.email, "owner@example.com")
        self.assertTrue(user.check_password("password"))
        self.assertEqual(self.client.session.session_key, session_key)
        self.assertEqual(int(self.client.session["_auth_user_id"]), user.pk)

    def test_connection_rejects_other_owner_without_switching_accounts(self):
        other = User.objects.create_user("other", "other@example.com", "password")
        identity = SocialIdentity.objects.create(user=other, **self.identity)
        owner = User.objects.create_user("owner", "owner@example.com", "password")
        self.client.force_login(owner)
        response = self.connect_google()
        self.assertContains(response, "already connected to another NewsBlur account", status_code=409)
        self.assertContains(response, "Back to account", status_code=409)
        self.assertNotContains(response, "Sign in with Google", status_code=409)
        identity.refresh_from_db()
        self.assertEqual(identity.user_id, other.pk)
        self.assertEqual(int(self.client.session["_auth_user_id"]), owner.pk)

    def test_connecting_same_provider_identity_is_idempotent(self):
        owner = User.objects.create_user("owner", "owner@example.com", "password")
        self.client.force_login(owner)
        self.assertEqual(self.connect_google().url, "/?next=account")
        self.assertEqual(self.connect_google().url, "/?next=account")
        self.assertEqual(SocialIdentity.objects.count(), 1)

    def test_connecting_rejects_rotated_session_before_exchange(self):
        owner = User.objects.create_user("owner", "owner@example.com", "password")
        self.client.force_login(owner)
        callback = self.callback(self.start(purpose="connect_account"))
        session = self.client.session
        session.cycle_key()
        session.save()
        self.client.cookies[settings.SESSION_COOKIE_NAME] = session.session_key
        with patch.object(web_social_auth.requests, "post") as exchange:
            self.assertEqual(self.client.get(callback.url).status_code, 403)
        exchange.assert_not_called()
        self.assertFalse(SocialIdentity.objects.exists())

    def test_connection_ticket_cannot_attach_after_account_changes(self):
        owner = User.objects.create_user("owner", "owner@example.com", "password")
        other = User.objects.create_user("other", "other@example.com", "password")
        self.client.force_login(owner)
        params = self.start(purpose="connect_account")
        callback = self.callback(params)
        token_response = Mock()
        token_response.json.return_value = {"id_token": "signed-token"}
        with patch.object(web_social_auth.requests, "post", return_value=token_response), patch.object(
            social_auth, "verified_claims", return_value=self.identity
        ):
            finished = self.client.get(callback.url)
        session = self.client.session
        session["_auth_user_id"] = str(other.pk)
        session["_auth_user_hash"] = other.get_session_auth_hash()
        session.save()
        self.assertEqual(self.client.get(finished.url).status_code, 403)
        self.assertFalse(SocialIdentity.objects.exists())

    def test_connection_cancellation_returns_to_account_without_mutating_it(self):
        owner = User.objects.create_user("owner", "owner@example.com", "password")
        self.client.force_login(owner)
        callback = self.callback(self.start(purpose="connect_account"), error="access_denied")
        response = self.client.get(callback.url)
        self.assertContains(response, "Back to account", status_code=400)
        self.assertFalse(SocialIdentity.objects.exists())
        self.assertEqual(int(self.client.session["_auth_user_id"]), owner.pk)

    def test_disconnect_then_connect_to_another_account_full_loop(self):
        first = User.objects.create_user("first", "first@example.com", "password")
        second = User.objects.create_user("second", "second@example.com", "password")
        self.client.force_login(first)
        self.assertEqual(self.connect_google().status_code, 302)
        identity = SocialIdentity.objects.get()
        self.client.force_login(second)
        self.assertEqual(
            self.client.post("/account/social/disconnect", {"identity_id": identity.pk}).status_code, 404
        )
        self.assertEqual(self.connect_google().status_code, 409)
        self.client.force_login(first)
        self.assertEqual(
            self.client.post("/account/social/disconnect", {"identity_id": identity.pk}).json()["code"], 1
        )
        self.client.force_login(second)
        self.assertEqual(self.connect_google().url, "/?next=account")
        self.assertEqual(SocialIdentity.objects.get().user_id, second.pk)
        self.assertEqual(User.objects.count(), 2)

    def test_disconnect_protects_last_signin_method_and_keeps_other_connections(self):
        owner = User.objects.create_user("owner", "owner@example.com")
        self.client.force_login(owner)
        first = SocialIdentity.objects.create(user=owner, **self.identity)
        response = self.client.post("/account/social/disconnect", {"identity_id": first.pk})
        self.assertEqual(response.status_code, 409)
        self.assertTrue(SocialIdentity.objects.filter(pk=first.pk).exists())
        second = SocialIdentity.objects.create(
            user=owner, provider="apple", subject="apple-subject", email="personal@example.com"
        )
        self.assertEqual(
            self.client.post("/account/social/disconnect", {"identity_id": first.pk}).status_code, 200
        )
        self.assertEqual(
            self.client.post("/account/social/disconnect", {"identity_id": second.pk}).status_code, 409
        )
        self.assertTrue(SocialIdentity.objects.filter(pk=second.pk).exists())

    def test_disconnect_requires_post_login_and_csrf(self):
        self.assertEqual(self.client.get("/account/social/disconnect").status_code, 405)
        self.assertEqual(self.client.post("/account/social/disconnect", {"identity_id": 1}).status_code, 401)
        owner = User.objects.create_user("owner", "owner@example.com", "password")
        identity = SocialIdentity.objects.create(user=owner, **self.identity)
        client = Client(enforce_csrf_checks=True)
        client.force_login(owner)
        self.assertEqual(
            client.post("/account/social/disconnect", {"identity_id": identity.pk}).status_code, 403
        )
        account = client.get("/api/social/account")
        self.assertEqual(
            client.post(
                "/account/social/disconnect",
                {"identity_id": identity.pk, "csrfmiddlewaretoken": account.cookies["csrftoken"].value},
            ).status_code,
            200,
        )
        self.assertFalse(SocialIdentity.objects.exists())

    def test_native_identity_signs_in_without_another_account(self):
        user = User.objects.create_user("reader", "reader@example.com")
        SocialIdentity.objects.create(user=user, **self.identity)
        response = self.verify(self.callback(self.start()))
        self.assertEqual(response.url, "/")
        self.assertEqual(User.objects.count(), 1)
        self.assertEqual(int(self.client.session["_auth_user_id"]), user.pk)

    def test_web_account_signs_into_ios_and_android_without_duplicate_accounts(self):
        self.verify(self.callback(self.start()))
        self.client.post("/account/social/continue", {"username": "reader"})
        user = User.objects.get(username="reader")
        token_response = Mock()
        token_response.json.return_value = {"id_token": "signed-token"}
        for platform, scheme in [
            ("ios", "newsblur-auth"),
            ("android", "newsblur-auth-android"),
            ("android-alpha", "newsblur-auth-android-alpha"),
        ]:
            with self.subTest(platform=platform):
                client = Client()
                started = client.post(
                    "/api/social/start",
                    dict(
                        provider="google",
                        platform=platform,
                        challenge=hashlib.sha256(b"mobile-verifier").hexdigest(),
                    ),
                )
                self.assertEqual(started.status_code, 200)
                with patch.object(social_auth.requests, "post", return_value=token_response), patch.object(
                    social_auth, "verified_claims", return_value=self.identity
                ):
                    callback = Client().get(
                        "/api/social/google/callback",
                        dict(state=started.json()["state"], code="authorization-code"),
                    )
                self.assertEqual(urlparse(callback.url).scheme, scheme)
                ticket = parse_qs(urlparse(callback.url).query)["ticket"][0]
                completed = client.post(
                    "/api/social/complete", dict(ticket=ticket, verifier="mobile-verifier")
                )
                self.assertEqual(completed.json()["code"], 1)
                self.assertEqual(int(client.session["_auth_user_id"]), user.pk)
                self.assertEqual(User.objects.count(), 1)
                self.assertEqual(SocialIdentity.objects.count(), 1)

    def test_existing_account_requires_password_and_allows_retry(self):
        user = User.objects.create_user("reader", "reader@example.com", "existing-password")
        response = self.verify(self.callback(self.start()))
        self.assertContains(response, "Connect your account")
        self.assertNotContains(response, "Create a new account instead")
        self.assertNotContains(self.client.get("/account/social/continue"), "Create a new account instead")
        response = self.client.post(
            "/account/social/continue",
            dict(action="choose_username", username="reader", password="existing-password"),
        )
        self.assertContains(response, "Connect your account")
        self.assertNotContains(response, "Create a new account instead")
        self.assertNotIn("_auth_user_id", self.client.session)
        self.assertFalse(SocialIdentity.objects.exists())
        response = self.client.post("/account/social/continue", dict(username="reader", password="wrong"))
        self.assertContains(response, "Connect your account")
        self.assertNotIn("_auth_user_id", self.client.session)
        response = self.client.post(
            "/account/social/continue", dict(username="reader", password="existing-password")
        )
        self.assertEqual(response.status_code, 302)
        self.assertEqual(SocialIdentity.objects.get().user_id, user.pk)

    def test_username_collision_can_be_corrected(self):
        User.objects.create_user("taken", "other@example.com", "password")
        self.verify(self.callback(self.start()))
        response = self.client.post("/account/social/continue", {"username": "taken"})
        self.assertContains(response, "Connect your account")
        self.assertContains(response, "This account already exists. Log in to connect it to Google.")
        self.assertContains(response, 'value="taken"')
        self.assertContains(response, 'name="password"')
        self.assertContains(response, "Create a new account instead")
        self.assertContains(self.client.get("/account/social/continue"), "Create a new account instead")
        self.assertFalse(SocialIdentity.objects.exists())
        response = self.client.post("/account/social/continue", {"action": ["link", "choose_username"]})
        self.assertContains(response, "Choose your username")
        self.assertNotContains(self.client.get("/account/social/continue"), 'value="taken"')
        response = self.client.post("/account/social/continue", {"username": "available"})
        self.assertEqual(response.status_code, 302)
        self.assertEqual(SocialIdentity.objects.get().user.username, "available")

    def test_taken_username_opens_link_form_and_keeps_username_on_refresh(self):
        user = User.objects.create_user("existing", "other@example.com", "existing-password")
        params = self.start("apple")
        claims = self.apple_claims(params)
        callback = self.callback(params, "apple", id_token=self.sign_apple(claims))
        finished, _ = self.finish_apple(callback, self.sign_apple(claims))
        self.assertEqual(finished.status_code, 302)
        self.client.get(finished.url)
        response = self.client.post("/account/social/continue", {"username": "EXISTING"})
        self.assertContains(response, "This account already exists. Log in to connect it to Apple.")
        self.assertContains(response, 'name="action" value="link"')
        refreshed = self.client.get("/account/social/continue")
        self.assertContains(refreshed, 'value="EXISTING"')
        self.assertFalse(SocialIdentity.objects.exists())
        response = self.client.post(
            "/account/social/continue",
            dict(action="link", username="EXISTING", password="wrong"),
        )
        self.assertContains(response, "Connect your account")
        self.assertNotIn("_auth_user_id", self.client.session)
        response = self.client.post(
            "/account/social/continue",
            dict(action="link", username="EXISTING", password="existing-password"),
        )
        self.assertEqual(response.status_code, 302)
        self.assertEqual(SocialIdentity.objects.get().user_id, user.pk)
        user.refresh_from_db()
        self.assertEqual(user.email, "other@example.com")

    def test_new_provider_email_can_switch_to_existing_account_link_and_retry(self):
        user = User.objects.create_user("reader", "account@example.com", "existing-password")
        response = self.verify(self.callback(self.start()))
        self.assertContains(response, "Connect an existing account")
        response = self.client.post("/account/social/continue", {"action": "link"})
        self.assertContains(response, "Connect your account")
        self.assertContains(response, "Create a new account instead")
        self.assertContains(self.client.get("/account/social/continue"), "Create a new account instead")
        self.assertContains(response, 'name="action" value="link"')
        self.assertFalse(SocialIdentity.objects.exists())
        for password in ("", "wrong"):
            response = self.client.post(
                "/account/social/continue", dict(action="link", username="reader", password=password)
            )
            self.assertContains(response, "Connect your account")
            self.assertContains(response, "Create a new account instead")
            self.assertContains(self.client.get("/account/social/continue"), "Create a new account instead")
            self.assertNotIn("_auth_user_id", self.client.session)
            self.assertFalse(SocialIdentity.objects.exists())
        response = self.client.post(
            "/account/social/continue",
            dict(action="link", username="reader", password="existing-password"),
        )
        self.assertEqual(response.status_code, 302)
        self.assertEqual(SocialIdentity.objects.get().user_id, user.pk)
        self.assertEqual(User.objects.get().email, "account@example.com")

    def test_auth_pages_do_not_block_parsing_on_external_font_stylesheets(self):
        # test_web_social_auth.py reproduces stalled typography CSS blocking base.html's body script.
        for path in ("/account/login", "/account/social/continue"):
            with self.subTest(path=path):
                response = self.client.get(path)
                html = response.content.decode()
                fallbacks = re.findall(r"<noscript\b[^>]*>(.*?)</noscript>", html, re.DOTALL)
                scripted_html = re.sub(r"<noscript\b[^>]*>.*?</noscript>", "", html, flags=re.DOTALL)
                links = re.findall(r"<link\b[^>]*>", scripted_html)
                font_links = [link for link in links if "cloud.typography.com" in link]
                self.assertTrue(font_links)
                for link in font_links:
                    self.assertNotRegex(link, r'\brel="stylesheet"')
                    self.assertIn('rel="preload"', link)
                    self.assertIn('as="style"', link)
                    self.assertIn("this.rel='stylesheet'", link)
                    href = re.search(r'href="([^"]+)"', link).group(1)
                    fallback_links = re.findall(r"<link\b[^>]*>", "".join(fallbacks))
                    self.assertTrue(
                        any(
                            'rel="stylesheet"' in fallback and href in fallback for fallback in fallback_links
                        )
                    )

    def test_apple_post_without_session_cookie_returns_to_initiating_browser(self):
        params = self.start("apple")
        self.assertEqual(params["response_mode"], ["form_post"])
        claims = self.apple_claims(params)
        callback = self.callback(
            params, "apple", Client(enforce_csrf_checks=True), id_token=self.sign_apple(claims)
        )
        self.assertEqual(callback.status_code, 303)
        self.assertNotIn("sessionid", callback.cookies)
        finished, exchange = self.finish_apple(callback, self.sign_apple(claims))
        self.assertEqual(finished.status_code, 302)
        self.assertContains(self.client.get(finished.url), "Choose your username")

    def apple_claims(self, params):
        self.apple_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        return dict(
            sub="apple-subject",
            aud="com.newsblur.web",
            iss="https://appleid.apple.com",
            iat=int(time.time()),
            exp=int(time.time()) + 300,
            nonce=params["nonce"][0],
            email="apple-reader@example.com",
            email_verified=True,
        )

    def sign_apple(self, claims, key=None):
        return jwt.encode(claims, key or self.apple_key, algorithm="RS256", headers={"kid": "fixture"})

    def finish_apple(self, callback, exchange_token, client=None):
        token_response = Mock()
        token_response.json.return_value = {"id_token": exchange_token}
        # test_web_social_auth.py stubs transport/key discovery, never either JWT verification function.
        with patch.object(
            social_auth.APPLE_KEYS,
            "get_signing_key_from_jwt",
            return_value=SimpleNamespace(key=self.apple_key.public_key()),
        ), patch.object(
            web_social_auth.requests, "post", return_value=token_response
        ) as exchange, patch.object(
            social_auth, "apple_client_secret", return_value="apple-secret"
        ):
            finished = (client or self.client).get(callback.url)
        return finished, exchange

    def test_apple_requests_hybrid_authorization_while_google_keeps_code_flow(self):
        self.assertEqual(self.start("apple")["response_type"], ["code id_token"])
        self.assertEqual(self.start("google")["response_type"], ["code"])

    def test_production_and_staging_keep_browser_and_mobile_callback_hosts_separate(self):
        for host in ("www.newsblur.com", "staging.newsblur.com"):
            callbacks = {
                f"SOCIAL_{provider.upper()}{'_WEB' if browser else ''}_REDIRECT_URI": f"https://{host}/{'account' if browser else 'api'}/social/{provider}/callback"
                for provider in ("apple", "google")
                for browser in (False, True)
            }
            with self.subTest(host=host), override_settings(**callbacks):
                for provider in ("apple", "google"):
                    expected = callbacks["SOCIAL_%s_WEB_REDIRECT_URI" % provider.upper()]
                    params = self.start(provider, redirect_uri="https://attacker.example/callback")
                    self.assertEqual(params["redirect_uri"], [expected])
                    if provider == "apple":
                        claims = self.apple_claims(params)
                        callback = self.callback(params, provider, id_token=self.sign_apple(claims))
                        finished, exchange = self.finish_apple(callback, self.sign_apple(claims))
                        self.assertEqual(finished.status_code, 302)
                    else:
                        callback = self.callback(params)
                        token_response = Mock()
                        token_response.json.return_value = {"id_token": "signed-token"}
                        with patch.object(
                            web_social_auth.requests, "post", return_value=token_response
                        ) as exchange, patch.object(
                            social_auth, "verified_claims", return_value=self.identity
                        ):
                            self.assertEqual(self.client.get(callback.url).status_code, 302)
                    self.assertEqual(exchange.call_args.kwargs["data"]["redirect_uri"], expected)
                    native = self.client.post(
                        "/api/social/start",
                        dict(provider=provider, platform="android", challenge="a" * 64),
                    )
                    self.assertEqual(native.status_code, 200, native.content)
                    self.assertEqual(
                        parse_qs(urlparse(native.json()["url"]).query)["redirect_uri"],
                        [callbacks["SOCIAL_%s_REDIRECT_URI" % provider.upper()]],
                    )

    def test_apple_signed_authorization_allows_exchange_without_nonce_or_email(self):
        for include_nonce in (False, True):
            with self.subTest(include_nonce=include_nonce):
                params = self.start("apple")
                claims = self.apple_claims(params)
                authorization_token = self.sign_apple(claims)
                exchange_claims = {
                    k: v for k, v in claims.items() if k not in ("email", "email_verified", "nonce")
                }
                if include_nonce:
                    exchange_claims["nonce"] = claims["nonce"]
                exchange_token = self.sign_apple(exchange_claims)
                callback = self.callback(params, "apple", Client(), id_token=authorization_token)
                finished, exchange = self.finish_apple(callback, exchange_token)
                self.assertEqual(finished.status_code, 302)
                self.assertEqual(finished.url, "/account/social/continue")
                self.assertEqual(
                    exchange.call_args.kwargs["data"],
                    dict(
                        code="authorization-code",
                        client_id="com.newsblur.web",
                        client_secret="apple-secret",
                        redirect_uri=web_social_auth.configuration("apple")[1],
                        grant_type="authorization_code",
                    ),
                )
                pending = self.client.session["web_social_pending"]
                ticket = social_auth.consume("ticket", pending["ticket"])
                self.assertEqual(
                    ticket["identity"], dict(provider="apple", subject=claims["sub"], email=claims["email"])
                )
                for token in (authorization_token, exchange_token):
                    for value in (
                        callback.url,
                        callback.content.decode(),
                        finished.url,
                        finished.content.decode(),
                        str(pending),
                        str(ticket),
                    ):
                        self.assertFalse(token in value, "Apple token leaked outside the callback cache")
                self.assertNotIn("authorization_token", pending)
                self.assertNotIn("authorization_token", ticket)
                self.assertNotIn("authorization_code", pending)
                replay, repeated_exchange = self.finish_apple(callback, exchange_token)
                self.assertEqual(replay.status_code, 400)
                repeated_exchange.assert_not_called()

    def test_apple_rejects_signed_exchange_for_other_subject_audience_nonce_or_key(self):
        for change in (
            dict(sub="other-user"),
            dict(aud="com.newsblur.NewsBlur"),
            dict(nonce="other-attempt"),
            dict(signature="wrong-key"),
        ):
            with self.subTest(change=change):
                params = self.start("apple")
                claims = self.apple_claims(params)
                callback = self.callback(params, "apple", id_token=self.sign_apple(claims))
                key = (
                    rsa.generate_private_key(public_exponent=65537, key_size=2048)
                    if "signature" in change
                    else None
                )
                exchange_token = self.sign_apple(dict(claims, **change), key=key)
                finished, exchange = self.finish_apple(callback, exchange_token)
                self.assertEqual(finished.status_code, 400)
                self.assertFalse(exchange_token in finished.content.decode(), "Apple token leaked into HTML")
                exchange.assert_called_once()
                self.assertNotIn("web_social_pending", self.client.session)
                self.assertNotIn("_auth_user_id", self.client.session)
                self.assertFalse(SocialIdentity.objects.exists())

    def test_apple_rejects_unverified_authorization_before_exchanging_code(self):
        for invalid in ("missing-token", "missing-nonce", "wrong-nonce", "wrong-audience", "wrong-key"):
            with self.subTest(invalid=invalid):
                params = self.start("apple")
                claims = self.apple_claims(params)
                posted_claims = dict(claims)
                key = None
                if invalid == "missing-nonce":
                    posted_claims.pop("nonce")
                elif invalid == "wrong-nonce":
                    posted_claims["nonce"] = "other-attempt"
                elif invalid == "wrong-audience":
                    posted_claims["aud"] = "com.newsblur.NewsBlur"
                elif invalid == "wrong-key":
                    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
                token = "" if invalid == "missing-token" else self.sign_apple(posted_claims, key=key)
                callback = self.callback(params, "apple", id_token=token)
                finished, exchange = self.finish_apple(callback, self.sign_apple(claims))
                self.assertEqual(finished.status_code, 400)
                if token:
                    self.assertFalse(token in finished.content.decode(), "Apple token leaked into HTML")
                exchange.assert_not_called()
                self.assertNotIn("web_social_pending", self.client.session)
                self.assertFalse(SocialIdentity.objects.exists())

    def test_apple_browser_binding_precedes_token_validation_and_exchange(self):
        params = self.start("apple")
        claims = self.apple_claims(params)
        callback = self.callback(params, "apple", Client(), id_token=self.sign_apple(claims))
        with patch.object(social_auth.APPLE_KEYS, "get_signing_key_from_jwt") as keys, patch.object(
            web_social_auth.requests, "post"
        ) as exchange:
            response = Client().get(callback.url)
        self.assertEqual(response.status_code, 400)
        keys.assert_not_called()
        exchange.assert_not_called()
        response, exchange = self.finish_apple(callback, self.sign_apple(claims))
        self.assertEqual(response.status_code, 400)
        exchange.assert_not_called()

    def test_other_browser_cannot_complete_or_exchange_code(self):
        callback = self.callback(self.start())
        with patch.object(web_social_auth.requests, "post") as exchange:
            response = Client().get(callback.url)
        self.assertEqual(response.status_code, 400)
        exchange.assert_not_called()
        self.assertFalse(SocialIdentity.objects.exists())

    def test_callback_state_is_single_use_and_provider_bound(self):
        params = self.start()
        response = self.callback(params, "apple")
        self.assertEqual(response.status_code, 400)
        self.assertEqual(self.callback(params).status_code, 400)
        params = self.start()
        self.assertEqual(self.callback(params).status_code, 303)
        self.assertEqual(self.callback(params).status_code, 400)

    def test_cancellation_and_exchange_failure_leave_password_login_available(self):
        callback = self.callback(self.start(), error="access_denied")
        response = self.client.get(callback.url)
        self.assertContains(response, "cancelled", status_code=400)
        self.assertContains(response, "Back to login", status_code=400)
        callback = self.callback(self.start())
        with patch.object(web_social_auth.requests, "post", side_effect=web_social_auth.requests.Timeout):
            response = self.client.get(callback.url)
        self.assertContains(response, "could not verify", status_code=400)
        self.assertNotIn("_auth_user_id", self.client.session)

    def test_csrf_is_required_for_start_and_account_confirmation(self):
        client = Client(enforce_csrf_checks=True)
        self.assertEqual(client.post("/account/social/start", {"provider": "google"}).status_code, 403)
        self.assertEqual(client.post("/account/social/continue", {"username": "reader"}).status_code, 403)

    def test_provider_start_from_each_entry_page_sets_a_matching_csrf_cookie(self):
        for path in ["/welcome", "/", "/account/signup", "/reader/signup", "/account/login"]:
            with self.subTest(path=path):
                client = Client(enforce_csrf_checks=True, HTTP_USER_AGENT="Mozilla/5.0")
                page = client.get(path)
                self.assertEqual(page.status_code, 200)
                token = re.search(r'name="csrfmiddlewaretoken" value="([^"]+)"', page.content.decode()).group(
                    1
                )
                response = client.post(
                    "/account/social/start",
                    {"provider": "google", "csrfmiddlewaretoken": token},
                    HTTP_REFERER="http://testserver" + path,
                )
                self.assertEqual(response.status_code, 302, response.content)
                # test_web_social_auth.py also covers a returning visitor with an existing CSRF cookie.
                page = client.get(path)
                token = re.search(r'name="csrfmiddlewaretoken" value="([^"]+)"', page.content.decode()).group(
                    1
                )
                response = client.post(
                    "/account/social/start",
                    {"provider": "google", "csrfmiddlewaretoken": token},
                    HTTP_REFERER="http://testserver" + path,
                )
                self.assertEqual(response.status_code, 302, response.content)

    def test_external_return_url_is_rejected(self):
        for target in ["https://evil.example/", "//evil.example/", "javascript:alert(1)"]:
            with self.subTest(target=target):
                params = self.start(next=target)
                context = social_auth.consume("web-state", params["state"][0])
                self.assertEqual(context["next"], "/")

    def test_expired_ticket_cannot_create_an_account(self):
        self.verify(self.callback(self.start()))
        cache.clear()
        response = self.client.post("/account/social/continue", {"username": "reader"})
        self.assertContains(response, "expired", status_code=400)
        self.assertFalse(User.objects.exists())

    def test_referral_and_gift_survive_provider_redirect(self):
        referrer = User.objects.create_user("friend", "friend@example.com", "password")
        self.verify(self.callback(self.start(referrer="friend", gift_code="gift")))
        with patch.object(web_social_auth.MReferral, "create_referral") as referral, patch.object(
            web_social_auth.MGiftCode, "objects"
        ) as gifts, patch.object(web_social_auth.MRedeemedCode, "redeem") as redeem:
            gifts.filter.return_value.first.return_value = Mock(redeemed_date=None)
            response = self.client.post("/account/social/continue", {"username": "reader"})
        user = User.objects.get(username="reader")
        referral.assert_called_once_with(referrer.pk, user.pk, "reader")
        redeem.assert_called_once_with(user=user, gift_code="gift")
        self.assertEqual(response.cookies["nb_gift_code"]["max-age"], 0)

    def test_buttons_render_on_all_three_surfaces_and_escape_return_values(self):
        request = RequestFactory().get('/?next="><script>alert(1)</script>')
        request.COOKIES["nb_last_social_provider"] = "apple"
        for template in ["accounts/login.html", "accounts/signup.html", "reader/welcome.xhtml"]:
            with self.subTest(template=template):
                html = render_to_string(template, {}, request=request)
                self.assertIn("Sign in with Apple", html)
                self.assertIn("Sign in with Google", html)
                self.assertIn("Last used", html)
                self.assertNotIn('"><script>alert(1)</script>', html)

    @override_settings(SOCIAL_WEB_ENABLED=False)
    def test_disabled_web_signin_hides_configured_providers_and_blocks_browser_starts(self):
        for path in ["/welcome", "/", "/account/signup", "/reader/signup", "/account/login"]:
            with self.subTest(path=path):
                response = self.client.get(path, HTTP_USER_AGENT="Mozilla/5.0")
                self.assertEqual(response.status_code, 200)
                self.assertNotContains(response, "Sign in with Apple")
                self.assertNotContains(response, "Sign in with Google")
                self.assertContains(response, 'type="password"')
        for provider in ["apple", "google"]:
            with self.subTest(provider=provider):
                response = self.client.post("/account/social/start", {"provider": provider})
                self.assertEqual(response.status_code, 503)
                self.assertNotIn("Location", response)
                self.assertNotIn("web_social_verifier", self.client.session)
        for platform, provider in [("ios", "google"), ("android", "google"), ("android", "apple")]:
            with self.subTest(platform=platform, provider=provider):
                response = self.client.post(
                    "/api/social/start",
                    dict(
                        provider=provider,
                        platform=platform,
                        challenge=hashlib.sha256(b"verifier").hexdigest(),
                    ),
                )
                self.assertEqual(response.status_code, 200, response.content)
        user = User.objects.create_user("reader", "reader@example.com", "password")
        self.client.force_login(user)
        self.assertEqual(self.client.get("/api/social/account").json()["connect_providers"], [])
        for provider in ["apple", "google"]:
            response = self.client.post(
                "/account/social/start", dict(provider=provider, purpose="connect_account")
            )
            self.assertEqual(response.status_code, 503)
            self.assertContains(response, "Back to account", status_code=503)

    def test_account_connect_only_offers_configured_providers(self):
        user = User.objects.create_user("reader", "reader@example.com", "password")
        self.client.force_login(user)
        self.assertEqual(
            self.client.get("/api/social/account").json()["connect_providers"], ["apple", "google"]
        )
        with override_settings(SOCIAL_APPLE_WEB_CLIENT_ID=""):
            self.assertEqual(self.client.get("/api/social/account").json()["connect_providers"], ["google"])

    @override_settings(SOCIAL_GOOGLE_CLIENT_ID="", SOCIAL_APPLE_WEB_CLIENT_ID="")
    def test_unconfigured_providers_are_hidden_and_cannot_start(self):
        request = RequestFactory().get("/account/login")
        html = render_to_string("accounts/login.html", {}, request=request)
        self.assertNotIn("Sign in with Apple", html)
        self.assertNotIn("Sign in with Google", html)
        response = self.client.post("/account/social/start", {"provider": "google"})
        self.assertEqual(response.status_code, 503)
