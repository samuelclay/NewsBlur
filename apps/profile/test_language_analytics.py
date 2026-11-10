import datetime
import hashlib
from unittest.mock import patch

from django.contrib.auth.models import AnonymousUser, User
from django.http import HttpResponse
from django.test import RequestFactory, TestCase, override_settings
from prometheus_client.parser import text_string_to_metric_families

from apps.monitor.views.newsblur_languages import Languages, language_metrics
from apps.profile.language import NewsBlurLocaleMiddleware, record_signup_language, save_account_language
from apps.profile.middleware import LastSeenMiddleware
from apps.profile.models import PaymentHistory, Profile
from apps.reader.forms import SignupForm
from utils import json_functions as json


@override_settings(LANGUAGE_ANALYTICS_COHORT_START="2026-10-16T12:00:00")
class Test_LanguageAnalytics(TestCase):
    def setUp(self):
        self.factory = RequestFactory()
        self.now = datetime.datetime(2026, 12, 1, 12)
        self.start = datetime.datetime(2026, 10, 16, 12)

    def user(self, name, language=None, choice="auto", active=True, joined=None, observed=None):
        user = User.objects.create(username=name, date_joined=joined or self.start)
        Profile.objects.filter(user=user).update(
            signup_language=language,
            preferences=json.encode({"language": choice}),
            last_read_language=observed,
            last_seen_on=self.now - datetime.timedelta(days=1 if active else 31),
        )
        user.profile.refresh_from_db()
        return user

    def payment(self, user, amount, when=None, refunded=None, provider="stripe"):
        return PaymentHistory.objects.create(
            user=user,
            payment_date=when or self.now,
            payment_amount=amount,
            payment_provider=provider,
            refunded=refunded,
        )

    def sample(self, body, name, **labels):
        matches = [
            sample.value
            for family in text_string_to_metric_families(body)
            for sample in family.samples
            if sample.name == name and sample.labels == labels
        ]
        self.assertEqual(len(matches), 1, (name, labels))
        return matches[0]

    def request(self, header="fr-CA", cookie=None):
        request = self.factory.post("/api/signup", HTTP_ACCEPT_LANGUAGE=header)
        request.user = AnonymousUser()
        if cookie:
            request.COOKIES["newsblur_language"] = cookie
        NewsBlurLocaleMiddleware(lambda request: None).process_request(request)
        return request

    def test_signup_records_negotiated_language_and_never_reassigns_existing_accounts(self):
        for name, header, cookie, expected in (
            ("french", "fr-CA", None, "fr"),
            ("override", "de", "es", "es"),
            ("english", "ja", "en", "en"),
            ("fallback", "xx", None, "en"),
            ("chinese", "zh-TW", None, "zh-Hant"),
        ):
            with self.subTest(name=name):
                form = SignupForm()
                form.cleaned_data = {"username": name, "password": "password", "email": ""}
                user = form.save(request=self.request(header, cookie))
                self.assertEqual(user.profile.signup_language, expected)
                save_account_language(user.profile, "ja")
                record_signup_language(user, self.request("de"))
                returned = form.save(request=self.request("de"))
                self.assertEqual(returned.pk, user.pk)
                user.profile.refresh_from_db()
                self.assertEqual(user.profile.signup_language, expected)

    def test_existing_account_using_signup_as_login_is_not_attributed(self):
        user = User.objects.create_user("existing", password="password")
        form = SignupForm()
        form.cleaned_data = {"username": user.username, "password": "password", "email": ""}
        form.save(request=self.request())
        user.profile.refresh_from_db()
        self.assertIsNone(user.profile.signup_language)

    @override_settings(ENFORCE_SIGNUP_CAPTCHA=False)
    @patch("apps.reader.forms.query")
    @patch("apps.profile.models.Profile.activate_free")
    def test_web_and_mobile_signup_routes_pass_language_to_form(self, activate, mx):
        for index, (path, prefix) in enumerate(
            (("/api/signup", ""), ("/reader/signup", "signup-"), ("/account/signup", "signup-"))
        ):
            with self.subTest(path=path):
                self.client.logout()
                name = "route%d" % index
                response = self.client.post(
                    path,
                    {
                        prefix + "username": name,
                        prefix + "password": "password",
                        prefix + "email": name + "@example.com",
                        "next": "/",
                    },
                    HTTP_ACCEPT_LANGUAGE="pt-BR",
                )
                self.assertIn(response.status_code, (200, 302), response.content)
                self.assertEqual(User.objects.get(username=name).profile.signup_language, "pt-BR")

    @override_settings(CACHES={"default": {"BACKEND": "django.core.cache.backends.locmem.LocMemCache"}})
    @patch("apps.reader.forms.query")
    def test_social_signup_keeps_signup_language_when_the_user_returns_in_another_language(self, mx):
        from apps.api.social_auth import remember

        def complete(language):
            ticket = remember(
                "ticket",
                {
                    "challenge": hashlib.sha256(b"proof").hexdigest(),
                    "identity": {
                        "provider": "google",
                        "subject": "language-test",
                        "email": "social@example.com",
                    },
                },
            )
            return self.client.post(
                "/api/social/complete",
                {"ticket": ticket, "verifier": "proof", "username": "social"},
                HTTP_ACCEPT_LANGUAGE=language,
            )

        response = complete("ja")
        self.assertEqual(response.status_code, 200, response.content)
        self.assertTrue(response.json()["created"])
        self.client.logout()
        response = complete("de")
        self.assertEqual(response.status_code, 200, response.content)
        self.assertFalse(response.json()["created"])
        self.assertEqual(User.objects.get(username="social").profile.signup_language, "ja")

    def test_last_seen_tracks_automatic_language_without_changing_signup_language(self):
        user = self.user("reader", language="es")
        Profile.objects.filter(user=user).update(last_seen_on=datetime.datetime.utcnow())
        request = self.factory.get("/reader/feeds", HTTP_ACCEPT_LANGUAGE="ja")
        request.user = user
        NewsBlurLocaleMiddleware(lambda request: None).process_request(request)
        LastSeenMiddleware().process_response(request, HttpResponse())
        user.profile.refresh_from_db()
        self.assertEqual(user.profile.last_read_language, "ja")
        self.assertEqual(user.profile.signup_language, "es")

    def test_script_without_language_header_preserves_last_observed_automatic_language(self):
        user = self.user("script", observed="fr")
        Profile.objects.filter(user=user).update(last_seen_on=datetime.datetime.utcnow())
        user.profile.refresh_from_db()
        request = self.factory.get("/reader/feeds")
        request.user = user
        NewsBlurLocaleMiddleware(lambda request: None).process_request(request)
        LastSeenMiddleware().process_response(request, HttpResponse())
        user.profile.refresh_from_db()
        self.assertEqual(user.profile.last_read_language, "fr")

    def test_preferences_activity_unknowns_and_legacy_nuls(self):
        self.user("auto_french", observed="fr")
        self.user("explicit_german", choice="de", observed="es")
        self.user("inactive_german", choice="de", active=False)
        self.user("auto_unknown")
        legacy = self.user("legacy")
        Profile.objects.filter(user=legacy).update(
            preferences=json.encode({"intro_page": "4\x00", "language": "es"})
        )
        body = language_metrics(self.now)
        self.assertEqual(
            self.sample(body, "newsblur_language_preferences", language="auto", activity="all"), 2
        )
        self.assertEqual(self.sample(body, "newsblur_language_preferences", language="de", activity="all"), 2)
        self.assertEqual(
            self.sample(body, "newsblur_language_preferences", language="de", activity="active_30d"), 1
        )
        self.assertEqual(
            self.sample(body, "newsblur_language_users", language="fr", activity="active_30d"), 1
        )
        self.assertEqual(self.sample(body, "newsblur_language_users", language="unknown", activity="all"), 1)
        self.assertEqual(self.sample(body, "newsblur_language_users", language="es", activity="all"), 1)
        self.assertEqual(self.sample(body, "newsblur_language_users", language="ja", activity="all"), 0)

    def test_revenue_uses_signup_language_excludes_old_accounts_and_counts_refunds_once(self):
        old = self.user("old", language="fr", joined=self.start - datetime.timedelta(seconds=1))
        new = self.user("new", language="fr", choice="de")
        unknown = self.user("unknown")
        self.payment(old, 999)
        self.payment(new, 36, self.start, refunded=True)
        self.payment(new, -36, refunded=True)
        self.payment(new, 36, provider="ios-subscription")
        self.payment(new, 29, provider="android-pro")
        self.payment(new, 999, self.now + datetime.timedelta(days=1))
        self.payment(unknown, 99)
        self.payment(new, 999, provider="newsblur-gift")
        self.payment(new, 999, provider="good-web-bundle")
        self.payment(new, 999, provider="referral credit")
        body = language_metrics(self.now)
        self.assertEqual(
            self.sample(body, "newsblur_language_payments_dollars", language="fr", period="since_start"), 65
        )
        self.assertEqual(
            self.sample(body, "newsblur_language_payments_dollars", language="fr", period="last_30d"), 29
        )
        self.assertEqual(
            self.sample(body, "newsblur_language_refunds_dollars", language="fr", period="since_start"), 36
        )
        self.assertEqual(
            self.sample(body, "newsblur_language_payments_dollars", language="de", period="since_start"), 0
        )
        self.assertEqual(
            self.sample(body, "newsblur_language_payments_dollars", language="unknown", period="since_start"),
            99,
        )
        self.assertEqual(self.sample(body, "newsblur_language_signups", language="fr", activity="all"), 1)

    def test_date_only_provider_history_on_signup_day_is_included(self):
        user = self.user("date_only", language="fr")
        self.payment(user, 36, self.start.replace(hour=0))
        body = language_metrics(self.now)
        self.assertEqual(
            self.sample(body, "newsblur_language_payments_dollars", language="fr", period="since_start"), 36
        )

    def test_endpoint_exports_valid_gauges_and_caches_aggregate(self):
        self.user("endpoint", language="ja")
        with patch("apps.monitor.views.newsblur_languages.MStatistics.get") as cache:
            cache.side_effect = lambda key, default, **kwargs: default(self.now)
            response = Languages.as_view()(self.factory.get("/monitor/languages"))
        self.assertEqual(response.status_code, 200)
        cache.assert_called_once()
        self.assertEqual(cache.call_args.kwargs["expiration_sec"], 300)
        families = list(text_string_to_metric_families(response.content.decode()))
        self.assertTrue(families)
        self.assertTrue(all(family.type == "gauge" for family in families))
