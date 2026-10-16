"""Emails reach each reader in their language: their explicit choice, else the language their devices last
asked for (apps/profile/language.py records it), else English (utils/languages.py:account_language)."""

import datetime
from types import SimpleNamespace
from unittest.mock import Mock, patch

from django.contrib.auth.models import User
from django.core import mail
from django.template import engines
from django.test import RequestFactory, SimpleTestCase, TestCase
from django.utils import translation
from django.utils.text import format_lazy
from django.utils.translation import gettext, ngettext

from apps.notifications.models import CLASSIFIER_MATCH_LABELS
from apps.profile.language import NewsBlurLocaleMiddleware
from apps.profile.models import Profile
from apps.profile.tasks import EmailGiftCreated, EmailNewUser, referral_credit_text
from apps.reader.forms import SignupForm
from utils import json_functions as json
from utils.languages import account_language


def stand_in_profile(language="auto", last_seen_language=None):
    # A fresh class per profile, since language.py updates the column through type(profile).objects.
    profile_class = type("Profile", (), {"objects": Mock()})
    profile = profile_class()
    profile.pk = 7
    profile.preferences = json.encode({"language": language})
    profile.last_seen_language = last_seen_language
    return profile


class Test_AccountLanguage(SimpleTestCase):
    def test_explicit_choice_wins_over_the_last_device_language(self):
        self.assertEqual(account_language(stand_in_profile("ja", last_seen_language="de")), "ja")

    def test_automatic_uses_the_language_devices_last_asked_for(self):
        self.assertEqual(account_language(stand_in_profile("auto", last_seen_language="pt-BR")), "pt-BR")

    def test_english_when_nothing_usable_is_known(self):
        self.assertEqual(account_language(stand_in_profile("auto")), "en")
        self.assertEqual(account_language(stand_in_profile("auto", last_seen_language="xx")), "en")
        self.assertEqual(
            account_language(SimpleNamespace(preferences="not json", last_seen_language=None)), "en"
        )
        self.assertEqual(account_language(SimpleNamespace(preferences="[]", last_seen_language="fr")), "fr")


class Test_DeviceLanguage(SimpleTestCase):
    def setUp(self):
        self.factory = RequestFactory()
        self.addCleanup(translation.deactivate)

    def visit(self, profile, **headers):
        request = self.factory.get("/reader/feeds", **headers)
        request.user = SimpleNamespace(is_authenticated=True, profile=profile)
        NewsBlurLocaleMiddleware(lambda request: None).process_request(request)
        return request

    def test_a_new_device_language_is_remembered(self):
        profile = stand_in_profile(last_seen_language="en")
        self.visit(profile, HTTP_ACCEPT_LANGUAGE="de-DE,de;q=0.9")
        self.assertEqual(profile.last_seen_language, "de")
        type(profile).objects.filter.assert_called_once_with(pk=7)
        type(profile).objects.filter.return_value.update.assert_called_once_with(last_seen_language="de")

    def test_the_same_language_writes_nothing(self):
        profile = stand_in_profile(last_seen_language="de")
        self.visit(profile, HTTP_ACCEPT_LANGUAGE="de")
        type(profile).objects.filter.assert_not_called()

    def test_requests_without_the_header_say_nothing_about_the_reader(self):
        # Scripts and API clients send no Accept-Language; English would overwrite the reader's language.
        profile = stand_in_profile(last_seen_language="ja")
        self.visit(profile)
        self.assertEqual(profile.last_seen_language, "ja")
        type(profile).objects.filter.assert_not_called()

    def test_anonymous_visitors_are_skipped(self):
        request = self.factory.get("/", HTTP_ACCEPT_LANGUAGE="fr")
        request.user = SimpleNamespace(is_authenticated=False)
        NewsBlurLocaleMiddleware(lambda request: None).process_request(request)
        self.assertEqual(request.LANGUAGE_CODE, "fr")


class Test_EmailLanguage(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="lectora", password="password", email="lectora@test.com"
        )
        self.addCleanup(translation.deactivate)

    def set_language(self, language="auto", last_seen_language=None):
        Profile.objects.filter(user=self.user).update(
            preferences=json.encode({"language": language}), last_seen_language=last_seen_language
        )
        self.user = User.objects.get(pk=self.user.pk)

    def translated(self, language, message, **values):
        with translation.override(language.lower()):
            text = gettext(message) % values
        self.assertNotEqual(text, message % values, "%s has no %s translation" % (message, language))
        return text

    def test_welcome_email_uses_the_explicit_language(self):
        self.set_language("es", last_seen_language="de")
        self.user.profile.send_new_user_email()
        email = mail.outbox[0]
        self.assertEqual(
            email.subject, self.translated("es", "Welcome to NewsBlur, %(username)s", username="lectora")
        )
        html = email.alternatives[0][0]
        self.assertIn('<html lang="es" dir="ltr">', html)
        self.assertIn(self.translated("es", "Unsubscribe from NewsBlur emails"), html)
        self.assertIn(self.translated("es", "Download the free Android App"), email.body)

    def test_automatic_accounts_get_the_language_their_devices_last_asked_for(self):
        self.set_language("auto", last_seen_language="de")
        self.user.profile.send_forgot_password_email()
        self.assertEqual(mail.outbox[0].subject, self.translated("de", "Forgot your password on NewsBlur?"))

    def test_right_to_left_languages_flip_the_email(self):
        self.set_language("he")
        self.user.profile.send_new_user_email()
        self.assertIn('<html lang="he" dir="rtl">', mail.outbox[0].alternatives[0][0])

    def test_english_stays_english(self):
        self.set_language("auto")
        self.user.profile.send_new_user_email()
        email = mail.outbox[0]
        self.assertEqual(email.subject, "Welcome to NewsBlur, lectora")
        self.assertIn('<html lang="en" dir="ltr">', email.alternatives[0][0])

    @patch("apps.reader.forms.query", return_value=True)
    def test_a_signup_records_its_language_for_the_welcome_email(self, mx_lookup):
        # The signup request is anonymous, and the welcome email can run before the reader's next request.
        with translation.override("de"):
            form = SignupForm(data={"username": "leserin", "email": "leserin@test.com", "password": "secret"})
            self.assertTrue(form.is_valid(), form.errors)
            user = form.save()
        EmailNewUser(user.pk)
        self.assertEqual(
            mail.outbox[-1].subject,
            self.translated("de", "Welcome to NewsBlur, %(username)s", username="leserin"),
        )

    def test_gift_email_names_the_plan_in_the_readers_language(self):
        self.set_language("ja")
        EmailGiftCreated(self.user.pk, "https://www.newsblur.com/gift/abc", "archive")
        email = mail.outbox[0]
        with translation.override("ja"):
            plan = gettext("Premium Archive")
        self.assertNotEqual(plan, "Premium Archive")
        self.assertIn(plan, email.subject)
        self.assertIn(self.translated("ja", "Hi %(username)s,", username="lectora"), email.body)
        self.assertIn("https://www.newsblur.com/gift/abc", email.body)

    def test_sending_leaves_the_active_language_alone(self):
        # Emails sent during a request must not switch the rest of that response's language.
        self.set_language("ja")
        with translation.override("fr"):
            self.user.profile.send_new_user_email()
            self.assertEqual(translation.get_language(), "fr")


class Test_EmailFragments(SimpleTestCase):
    def test_referral_credit_counts_in_the_readers_language(self):
        self.assertEqual(referral_credit_text(400), "1 year")
        self.assertEqual(referral_credit_text(60), "2 months")
        self.assertEqual(referral_credit_text(1), "1 day")
        with translation.override("ru"):
            expected = ngettext("%(count)s month", "%(count)s months", 5) % {"count": 5}
            self.assertEqual(referral_credit_text(150), expected)
        self.assertNotEqual(expected, "5 months")

    def test_notification_match_labels_render_in_the_email_language(self):
        description = format_lazy("{}: {}", CLASSIFIER_MATCH_LABELS["prompt"], "cats")
        self.assertEqual(str(description), "AI text filter: cats")
        with translation.override("fr"):
            french = str(description)
        self.assertNotEqual(french, "AI text filter: cats")
        self.assertTrue(french.endswith(": cats"))

    def test_dates_follow_the_language(self):
        context = {"date": datetime.date(2026, 10, 16)}
        rendered = engines["django"].from_string('{% load utils_tags %}{{ date|language_date:"F j, Y" }}')
        self.assertEqual(rendered.render(context), "October 16, 2026")
        with translation.override("de"):
            self.assertEqual(rendered.render(context), "16. Oktober 2026")
