from types import SimpleNamespace
from unittest.mock import Mock, patch

from django.conf import settings
from django.http import HttpResponse
from django.template.loader import render_to_string
from django.test import RequestFactory, SimpleTestCase
from django.utils import translation
from django.views.i18n import JavaScriptCatalog

from apps.profile.language import (
    LanguageCatalogMiddleware,
    NewsBlurLocaleMiddleware,
    adopt_login_language,
    detect_language,
    javascript_catalog_data,
    language_context,
    language_preference,
)
from utils import json_functions as json


class Test_Language(SimpleTestCase):
    def setUp(self):
        self.factory = RequestFactory()
        self.addCleanup(translation.deactivate)

    def test_welcome_language_form_can_submit_on_first_visit(self):
        from apps.reader.views import index, welcome_req

        for view in (index, welcome_req):
            with self.subTest(view=view.__name__):
                request = self.factory.get("/welcome")
                request.user = SimpleNamespace(is_authenticated=False, is_anonymous=True)

                def welcome_form(request, **kwargs):
                    return HttpResponse(render_to_string("includes/language_selector.html", request=request))

                with patch("apps.reader.views.welcome", side_effect=welcome_form), patch(
                    "apps.reader.views.get_subdomain", return_value=None
                ):
                    response = view(request)
                self.assertIn(settings.CSRF_COOKIE_NAME, response.cookies)
                token = response.cookies[settings.CSRF_COOKIE_NAME].value
                post = self.factory.post(
                    "/profile/language", {"language": "es", "csrfmiddlewaretoken": token}
                )
                post.user = request.user
                post.COOKIES[settings.CSRF_COOKIE_NAME] = token
                self.assertEqual(language_preference(post).status_code, 200)

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

    def test_oversized_headers_do_not_enter_djangos_parser_cache(self):
        from django.utils.translation.trans_real import parse_accept_lang_header

        with patch("apps.profile.language.parse_accept_lang_header", wraps=parse_accept_lang_header) as parse:
            self.assertEqual(detect_language("fr," + "a" * 10000), "fr")
            self.assertEqual(detect_language("a" * 10000), "en")
        self.assertTrue(all(len(call.args[0]) <= 500 for call in parse.call_args_list))

    def test_public_catalog_uses_url_language_and_bypasses_sessions(self):
        request = self.request("es", authenticated=True)
        request.LANGUAGE_CODE = "es"
        url = language_context(request)["ui_catalog_url"]
        catalog_request = self.factory.get(url, HTTP_COOKIE="newsblur_language=fr")
        downstream = Mock()
        with translation.override("ar"):
            response = LanguageCatalogMiddleware(downstream)(catalog_request)
        downstream.assert_not_called()
        self.assertContains(response, "Preferencias")
        self.assertEqual(response["Content-Language"], "es")
        self.assertEqual(response["Cache-Control"], "public, max-age=31536000, immutable")
        self.assertNotIn("Cookie", response.get("Vary", ""))
        self.assertFalse(response.cookies)
        conditional = self.factory.get(url, HTTP_IF_NONE_MATCH=response["ETag"])
        self.assertEqual(LanguageCatalogMiddleware(downstream)(conditional).status_code, 304)
        compressed = self.factory.get(url, HTTP_IF_NONE_MATCH="W/" + response["ETag"])
        self.assertEqual(LanguageCatalogMiddleware(downstream)(compressed).status_code, 304)

    def test_catalog_is_rendered_once_per_language(self):
        javascript_catalog_data.cache_clear()
        self.addCleanup(javascript_catalog_data.cache_clear)
        with patch(
            "apps.profile.language.JavaScriptCatalog.as_view", wraps=JavaScriptCatalog.as_view
        ) as view:
            first = javascript_catalog_data("es")
            second = javascript_catalog_data("es")
        self.assertEqual(first, second)
        view.assert_called_once()

    def test_catalog_url_remains_available_after_a_worker_deployment(self):
        request = self.request("es", authenticated=True)
        request.LANGUAGE_CODE = "es"
        previous_url = language_context(request)["ui_catalog_url"]
        downstream = Mock()
        # test_language.py simulates HTML from one release reaching a worker with different catalogs.
        with patch("apps.profile.language.javascript_catalog_data", return_value=(b"new catalog", "b" * 16)):
            response = LanguageCatalogMiddleware(downstream)(self.factory.get(previous_url))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.content, b"new catalog")
        self.assertEqual(response["Cache-Control"], "no-store")
        self.assertEqual(response["ETag"], '"' + "b" * 16 + '"')

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
