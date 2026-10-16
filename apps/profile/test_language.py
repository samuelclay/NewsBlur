import datetime
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock, patch

from django.conf import settings
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
    language_chooser_copy,
    language_chooser_copy_script,
    language_context,
    language_preference,
)
from utils import json_functions as json
from utils.languages import LANGUAGES
from utils.story_functions import format_story_link_date__long, format_story_link_date__short, relative_date


class Test_Language(SimpleTestCase):
    def setUp(self):
        self.factory = RequestFactory()
        self.addCleanup(translation.deactivate)

    def test_footer_language_form_works_without_a_csrf_cookie(self):
        # Static pages render the footer selector without ever setting a CSRF cookie.
        request = self.factory.post("/profile/language", {"language": "es", "next": "/about"})
        request.user = SimpleNamespace(is_authenticated=False)
        response = language_preference(request)
        self.assertEqual(response.status_code, 302)
        self.assertEqual(response["Location"], "/about")
        self.assertEqual(response.cookies["newsblur_language"].value, "es")

    def test_footer_selector_lists_automatic_in_the_detected_language(self):
        request = self.factory.get("/about", HTTP_ACCEPT_LANGUAGE="de")
        request.user = SimpleNamespace(is_authenticated=False)
        NewsBlurLocaleMiddleware(lambda request: None).process_request(request)
        html = render_to_string("reader/footer.xhtml", {"show_language": True}, request=request)
        self.assertIn('lang="de"', html)
        self.assertIn("· Deutsch", html)

    def test_raw_served_pages_have_no_template_tags(self):
        # nginx serves 502.html as a file and ansible renders maintenance_off.html with Jinja2.
        for name in ("502.html", "maintenance_off.html"):
            self.assertNotIn("{%", (Path(settings.NEWSBLUR_DIR) / "templates" / name).read_text())

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

    def test_language_chooser_copy_is_written_in_each_language(self):
        # reader_language.js previews the grid's selected language, so its button must not mix in the
        # interface language ("Use Українська" on an English page).
        copy = language_chooser_copy()
        self.assertEqual(set(copy), set(LANGUAGES))
        self.assertEqual(copy["en"]["use"], "Use English")
        self.assertEqual(copy["es"]["use"], "Usar Español")
        self.assertIn("Українська", copy["uk"]["use"])
        self.assertNotIn("Use ", copy["uk"]["use"])
        self.assertNotEqual(copy["uk"]["title"], copy["en"]["title"])
        self.assertNotEqual(copy["zh-Hant"]["pick"], copy["en"]["pick"])
        for code, name in LANGUAGES.items():
            self.assertIn(name, copy[code]["use"])

    def test_language_chooser_copy_cannot_close_the_script_block(self):
        script = language_chooser_copy_script()
        self.assertNotIn("<", script)
        self.assertEqual(json.decode(script)["fr"]["use"], language_chooser_copy()["fr"]["use"])

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

    def test_automatic_is_labeled_in_the_detected_language(self):
        request = self.request("es", authenticated=True, header="ja")
        NewsBlurLocaleMiddleware(lambda request: None).process_request(request)
        context = language_context(request)
        self.assertEqual(request.LANGUAGE_CODE, "es")
        self.assertEqual(context["ui_detected_language"], "ja")
        self.assertEqual(context["ui_detected_language_name"], "日本語")
        with translation.override("ja"):
            self.assertEqual(context["ui_language_auto_short"], translation.gettext("Auto"))
            self.assertEqual(
                context["ui_language_auto_label"], translation.gettext("Automatic (device language)")
            )
        self.assertNotEqual(context["ui_language_auto_short"], "Auto")
        self.assertNotEqual(context["ui_language_auto_label"], "Automatic (device language)")

    def test_english_story_dates_keep_their_format(self):
        now = datetime.datetime(2026, 10, 14, 12, 0)
        with translation.override("en"):
            self.assertEqual(
                format_story_link_date__short(datetime.datetime(2026, 10, 14, 9, 5), now), "9:05am"
            )
            self.assertEqual(
                format_story_link_date__short(datetime.datetime(2026, 10, 13, 21, 5), now),
                "Yesterday, 9:05pm",
            )
            self.assertEqual(
                format_story_link_date__short(datetime.datetime(2025, 9, 2, 9, 5), now), "02 Sep 2025, 9:05am"
            )
            self.assertEqual(
                format_story_link_date__long(datetime.datetime(2026, 10, 14, 9, 5), now),
                "Today, October 14th 9:05am",
            )
            self.assertEqual(
                format_story_link_date__long(datetime.datetime(2025, 9, 2, 9, 5), now),
                "Tuesday, September 2nd, 2025 9:05am",
            )
            self.assertEqual(
                relative_date(datetime.datetime.utcnow() - datetime.timedelta(hours=3)), "3 hours ago"
            )

    def test_story_dates_use_the_active_language(self):
        now = datetime.datetime(2026, 10, 14, 12, 0)
        with translation.override("es"):
            self.assertEqual(
                format_story_link_date__short(datetime.datetime(2025, 9, 2, 9, 5), now), "02/09/2025, 09:05"
            )
            yesterday = format_story_link_date__long(datetime.datetime(2026, 10, 13, 9, 5), now)
            older = format_story_link_date__long(datetime.datetime(2025, 9, 2, 9, 5), now)
            ago = relative_date(datetime.datetime.utcnow() - datetime.timedelta(hours=3))
        self.assertNotIn("Yesterday", yesterday)
        self.assertIn("13 de octubre de 2026 09:05", yesterday.lower())
        self.assertEqual(older.lower(), "martes, 2 de septiembre de 2025 09:05")
        self.assertNotIn("hours ago", ago)
