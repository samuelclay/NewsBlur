import json
import re
from html.parser import HTMLParser
from types import SimpleNamespace
from unittest.mock import patch

from django.template.loader import render_to_string
from django.test import SimpleTestCase

from utils import json_functions


class ScriptCollector(HTMLParser):
    def __init__(self, html):
        super().__init__()
        self.scripts = []
        self.in_script = False
        self.feed(html)

    def handle_starttag(self, tag, attrs):
        if tag == "script":
            self.in_script = True
            self.scripts.append("")

    def handle_endtag(self, tag):
        if tag == "script":
            self.in_script = False

    def handle_data(self, data):
        if self.in_script:
            self.scripts[-1] += data


class Test_InvoicePreferencesRendering(SimpleTestCase):
    templates = ("base.html", "social/social_page.xhtml")

    def render_page(self, template, invoice_text):
        # test_invoice_preferences_rendering.py uses the same JSON storage format as AccountSettingsForm.
        profile = SimpleNamespace(preferences=json_functions.encode({"invoice_text": invoice_text}))
        user = SimpleNamespace(
            pk=1, username="invoiceowner", email="invoice@example.com", is_authenticated=True, profile=profile
        )
        social_profile = SimpleNamespace(
            user_id=1, username="invoiceowner", shared_stories_count=0, follower_count=0
        )
        with patch("utils.templatetags.utils_tags.Site.objects.get_current") as current_site:
            current_site.return_value.domain = "testserver"
            return render_to_string(
                template,
                {"user": user, "user_profile": profile, "social_profile": social_profile, "debug": True},
            )

    def test_invoice_text_cannot_create_script_elements_in_reader_or_blurblog(self):
        details = "</script><script>window.invoice_markup_executed = true;</script>"
        for template in self.templates:
            with self.subTest(template=template):
                baseline = ScriptCollector(self.render_page(template, "Ordinary billing details"))
                rendered = ScriptCollector(self.render_page(template, details))
                self.assertEqual(len(rendered.scripts), len(baseline.scripts))
                self.assertNotIn("window.invoice_markup_executed = true;", rendered.scripts)

    def test_invoice_text_round_trips_quotes_newlines_and_script_delimiters(self):
        details = '</script>\nExample "Company" & O\'Brien\\VAT\nכתובת\u2028\u2029'
        for template in self.templates:
            with self.subTest(template=template):
                rendered = ScriptCollector(self.render_page(template, details))
                source = next(
                    script for script in rendered.scripts if "_.extend(NEWSBLUR.Preferences," in script
                )
                string_literal = re.search(r"JSON\.parse\('([^']*)'\)", source)
                self.assertIsNotNone(string_literal)
                serialized_preferences = json.loads('"' + string_literal.group(1) + '"')
                self.assertEqual(json.loads(serialized_preferences)["invoice_text"], details)
