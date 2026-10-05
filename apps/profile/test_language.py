from types import SimpleNamespace
from unittest.mock import Mock

from django.test import RequestFactory, SimpleTestCase
from django.utils import translation

from apps.profile.language import (
    NewsBlurLocaleMiddleware,
    adopt_login_language,
    detect_language,
    language_preference,
)
from utils import json_functions as json


class Test_Language(SimpleTestCase):
    def setUp(self):
        self.factory = RequestFactory()
        self.addCleanup(translation.deactivate)

    def request(self, language=None, authenticated=False, header="en", cookie=None):
        request = self.factory.post(
            "/profile/language", {"language": language or "auto"}, HTTP_ACCEPT_LANGUAGE=header
        )
        request.user = SimpleNamespace(is_authenticated=authenticated)
        if authenticated:
            request.user.profile = SimpleNamespace(
                preferences=json.encode({"language": language or "auto"}), save=Mock()
            )
        if cookie:
            request.COOKIES["newsblur_language"] = cookie
        request._dont_enforce_csrf_checks = True
        return request

    def test_automatic_negotiates_regions_and_quality(self):
        self.assertEqual(detect_language("en;q=0, fr-CA;q=0.9, de;q=0.8"), "fr")
        self.assertEqual(detect_language("zh-TW"), "zh-Hant")
        self.assertEqual(detect_language("zh-CN"), "zh-Hans")
        self.assertEqual(detect_language("pt-PT"), "pt-BR")
        self.assertEqual(detect_language("xx, *;q=0.5"), "en")

    def test_account_automatic_ignores_anonymous_cookie(self):
        request = self.request(authenticated=True, header="ja", cookie="fr")
        NewsBlurLocaleMiddleware(lambda request: None).process_request(request)
        self.assertEqual(request.LANGUAGE_CODE, "ja")

    def test_account_override_wins_over_device(self):
        request = self.request("es", authenticated=True, header="de")
        NewsBlurLocaleMiddleware(lambda request: None).process_request(request)
        self.assertEqual(request.LANGUAGE_CODE, "es")

    def test_anonymous_override_sets_cookie(self):
        response = language_preference(self.request("fr"))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.cookies["newsblur_language"].value, "fr")

    def test_unsupported_language_does_not_save(self):
        request = self.request("xx", authenticated=True)
        self.assertEqual(language_preference(request).status_code, 400)
        request.user.profile.save.assert_not_called()

    def test_redirect_cannot_leave_newsblur(self):
        request = self.factory.post("/profile/language", {"language": "fr", "next": "https://evil.example/"})
        request.user = SimpleNamespace(is_authenticated=False)
        request._dont_enforce_csrf_checks = True
        response = language_preference(request)
        self.assertEqual(response["Location"], "/")

    def test_server_preference_is_available_to_clients(self):
        request = self.request("fr", authenticated=True)
        language_preference(request)
        self.assertEqual(json.decode(request.user.profile.preferences)["language"], "fr")
        request.user.profile.save.assert_called_once_with(update_fields=["preferences"])

    def test_explicit_login_selection_is_adopted_once(self):
        request = self.request("auto", authenticated=True, cookie="ja")
        request.COOKIES["newsblur_language_pending"] = "1"
        adopt_login_language(None, request, request.user)
        self.assertEqual(json.decode(request.user.profile.preferences)["language"], "ja")
        response = NewsBlurLocaleMiddleware(lambda request: None).process_response(
            request, language_preference(request)
        )
        self.assertEqual(response.cookies["newsblur_language_pending"]["max-age"], 0)

    def test_old_anonymous_cookie_does_not_overwrite_account(self):
        request = self.request("fr", authenticated=True, cookie="ja")
        adopt_login_language(None, request, request.user)
        request.user.profile.save.assert_not_called()
