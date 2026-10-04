"""Browser and account boundaries for apps/profile/web_social_auth.py."""

import hashlib
import re
from unittest.mock import Mock, patch
from urllib.parse import parse_qs, urlparse

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
        self.assertContains(response, "Choose your username")
        response = self.client.post("/account/social/continue", {"username": "available"})
        self.assertEqual(response.status_code, 302)
        self.assertEqual(SocialIdentity.objects.get().user.username, "available")

    def test_apple_post_without_session_cookie_returns_to_initiating_browser(self):
        params = self.start("apple")
        self.assertEqual(params["response_mode"], ["form_post"])
        callback = self.callback(params, "apple", Client(enforce_csrf_checks=True))
        self.assertEqual(callback.status_code, 303)
        self.assertNotIn("sessionid", callback.cookies)
        self.assertContains(self.verify(callback, "apple"), "Choose your username")

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

    @override_settings(SOCIAL_GOOGLE_CLIENT_ID="", SOCIAL_APPLE_WEB_CLIENT_ID="")
    def test_unconfigured_providers_are_hidden_and_cannot_start(self):
        request = RequestFactory().get("/account/login")
        html = render_to_string("accounts/login.html", {}, request=request)
        self.assertNotIn("Sign in with Apple", html)
        self.assertNotIn("Sign in with Google", html)
        response = self.client.post("/account/social/start", {"provider": "google"})
        self.assertEqual(response.status_code, 503)
