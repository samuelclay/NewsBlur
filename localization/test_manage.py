import unittest
from unittest.mock import patch

from localization.manage import (
    BudgetExhausted,
    Translator,
    entry,
    gettext_catalog,
    ios_plural_entries,
    protected,
    source_entries,
    validate,
)


class Test_Translation(unittest.TestCase):
    def test_changed_placeholders_are_rejected(self):
        for original, translated in [
            ("%1$s stories", "histoires"),
            ("<b>Read</b>", "<i>Lire</i>"),
            ("%(count)d items", "%s éléments"),
        ]:
            with self.assertRaises(ValueError):
                validate(original, translated)

    def test_unicode_and_preserved_placeholders_are_accepted(self):
        validate("%1$d stories", "%1$d ストーリー")
        validate("<b>Read</b>", "<b>Lire</b>")
        validate("Expected 'https://' in URL", "URL에 'https://'이(가) 필요합니다")
        validate("NewsBlur is a reader", "NewsBlurはリーダーです")
        validate("Visit https://newsblur.com", "https://newsblur.comを開く")

    def test_unnumbered_format_arguments_cannot_change_order(self):
        with self.assertRaises(ValueError):
            validate("%@ has %ld stories", "%ld articles pour %@")

    @patch.dict("os.environ", {"OPENAI_API_KEY": "local-test-key"})
    @patch("urllib.request.urlopen")
    def test_budget_is_enforced_before_sending_a_request(self, request):
        with self.assertRaises(BudgetExhausted):
            Translator(0).translate("fr", [("title", "Read stories", "button")], [])
        request.assert_not_called()

    def test_stray_percent_in_a_format_string_is_rejected(self):
        with self.assertRaises(ValueError):
            validate("Only 1.9%% of users", "Yalnızca %1,9%%'u")
        validate("Save 50% off", "Économisez 50 % de")

    def test_arabic_plurals_use_cldr_order(self):
        catalog = gettext_catalog("ar")
        import gettext

        plural = gettext.c2py(catalog.plural_expr)
        self.assertEqual([plural(n) for n in (0, 1, 2, 5, 11, 99, 100, 102)], [0, 1, 2, 3, 4, 4, 5, 5])

    def test_changed_source_invalidates_translation_key(self):
        self.assertNotEqual(entry("ios", "save", "Save")["id"], entry("ios", "save", "Save story")["id"])

    def test_context_distinguishes_different_meanings(self):
        self.assertNotEqual(
            entry("android", "read_verb", "Read")["id"], entry("android", "read_adjective", "Read")["id"]
        )

    def test_date_range_labels_do_not_share_the_email_recipient_message(self):
        # archive_view.js's date range "To" must not reuse reader_send_email.js's recipient "To",
        # or one translation ("end date" or "recipient") is wrong in the other dialog.
        contexts = {
            item.get("msgctxt")
            for item in source_entries()
            if item["platform"] == "web" and item["source"] == "To"
        }
        self.assertIn("date range", contexts)
        self.assertIn(None, contexts)

    def test_lazy_form_errors_are_in_the_translation_inventory(self):
        messages = [item["source"] for item in source_entries() if item["platform"] == "web"]
        self.assertIn("Your old password is incorrect.", messages)

    def test_arabic_plural_resources_cover_all_categories(self):
        entries = source_entries("ar")
        contexts = {item["context"] for item in entries if item["platform"] == "android"}
        for quantity in ("zero", "one", "two", "few", "many", "other"):
            self.assertIn("discover_subscribers:" + quantity, contexts)

    def test_ios_plural_entries_preserve_counts_and_all_arabic_forms(self):
        entries = list(ios_plural_entries("ar"))
        subscribers = [item for item in entries if item["key"] == "%@ subscribers"]
        self.assertEqual(
            {item["quantity"] for item in subscribers}, {"zero", "one", "two", "few", "many", "other"}
        )
        self.assertTrue(all(protected(item["source"])["%@"] == 1 for item in subscribers))
        singular = next(item for item in subscribers if item["quantity"] == "one")
        self.assertEqual(singular["source"], "%@ subscriber")
