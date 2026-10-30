import datetime
from unittest.mock import patch

from django.contrib.auth.models import User
from django.db import connection
from django.test import TestCase
from django.test.utils import CaptureQueriesContext
from django.urls import reverse

from apps.profile.forms import AccountSettingsForm
from apps.profile.models import PaymentHistory
from utils import json_functions as json


class Test_InvoiceDetails(TestCase):
    def setUp(self):
        self.user = User.objects.create_user("invoiceowner", email="invoice@example.com")
        self.user.profile.preferences = json.encode({"language": "en", "unrelated": "keep"})
        self.user.profile.save()
        self.payment = PaymentHistory.objects.create(
            user=self.user,
            payment_date=datetime.datetime(2025, 1, 15),
            payment_amount=36,
            payment_provider="stripe",
        )
        self.client.force_login(self.user)
        self.url = reverse("profile-invoice", args=[self.payment.pk])

    def save_details(self, **fields):
        with patch("apps.profile.forms.MCustomStyling.save_user"), patch(
            "apps.profile.views.MSocialProfile.profile", return_value={}
        ):
            response = self.client.post(
                "/profile/set_account_settings",
                {"username": self.user.username, "email": self.user.email, **fields},
            )
        self.assertEqual(response.status_code, 200)
        return json.decode(response.content)

    def preferences(self):
        self.user.profile.refresh_from_db()
        return json.decode(self.user.profile.preferences)

    def test_saved_details_update_old_invoices_and_escape_html(self):
        details = 'Example & Sons\nVAT: DE123456789\n<script>alert("invoice")</script>'
        result = self.save_details(invoice_text=details)
        self.assertEqual(result["code"], 1, result)
        self.assertEqual(result["payload"]["invoice_text"], details)
        self.assertEqual(self.preferences()["invoice_text"], details)
        self.assertEqual(self.preferences()["unrelated"], "keep")
        response = self.client.get(self.url)
        self.assertContains(response, "Example &amp; Sons\nVAT: DE123456789\n&lt;script&gt;")
        self.assertNotContains(response, '<script>alert("invoice")</script>')
        self.save_details(invoice_text="New address")
        self.assertContains(self.client.get(self.url), "New address")

    def test_omitted_field_preserves_details_and_empty_field_removes_them(self):
        self.save_details(invoice_text="VAT: DE123456789")
        self.save_details()
        self.assertEqual(self.preferences()["invoice_text"], "VAT: DE123456789")
        self.save_details(invoice_text=" \n ")
        self.assertNotIn("invoice_text", self.preferences())
        self.assertNotContains(self.client.get(self.url), 'class="invoice-custom-text"')

    def test_invalid_account_or_oversized_details_do_not_overwrite_saved_text(self):
        self.save_details(invoice_text="Original")
        result = self.save_details(invoice_text="x" * 2001)
        self.assertEqual(result["code"], -4)
        self.assertEqual(self.preferences()["invoice_text"], "Original")
        result = self.save_details(invoice_text="Changed", email="invalid")
        self.assertEqual(result["code"], -1)
        self.assertEqual(self.preferences()["invoice_text"], "Original")

    def test_staff_see_invoice_owners_details_and_other_users_cannot_view_them(self):
        self.save_details(invoice_text="Owner VAT details")
        viewer = User.objects.create_user("invoiceviewer", email="viewer@example.com")
        viewer.profile.preferences = json.encode({"invoice_text": "Viewer VAT details"})
        viewer.profile.save()
        self.client.force_login(viewer)
        self.assertEqual(self.client.get(self.url).status_code, 404)
        viewer.is_staff = True
        viewer.save()
        response = self.client.get(self.url)
        self.assertContains(response, "Owner VAT details")
        self.assertNotContains(response, "Viewer VAT details")
        self.client.logout()
        self.assertEqual(self.client.get(self.url).status_code, 302)

    def test_account_saves_invoice_and_email_preferences_together(self):
        result = self.save_details(
            invoice_text="VAT: DE123456789", send_emails="false", notify_before_renewal="true"
        )
        self.assertEqual(result["code"], 1, result)
        preferences = self.preferences()
        self.assertFalse(self.user.profile.send_emails)
        self.assertTrue(preferences["notify_before_renewal"])
        self.assertEqual(preferences["invoice_text"], "VAT: DE123456789")
        self.assertFalse(result["payload"]["send_emails"])
        self.assertTrue(result["payload"]["notify_before_renewal"])
        self.save_details(invoice_text="Updated address")
        self.assertTrue(self.preferences()["notify_before_renewal"])
        self.assertFalse(self.user.profile.send_emails)
        self.save_details(notify_before_renewal="false", send_emails="true")
        self.assertFalse(self.preferences()["notify_before_renewal"])
        self.assertTrue(self.user.profile.send_emails)
        self.assertEqual(self.preferences()["invoice_text"], "Updated address")

    def test_rejected_account_save_does_not_change_email_preferences(self):
        result = self.save_details(invoice_text="x" * 2001, send_emails="false", notify_before_renewal="true")
        self.assertEqual(result["code"], -4)
        self.assertNotIn("notify_before_renewal", self.preferences())
        self.assertTrue(self.user.profile.send_emails)

    def test_unchanged_invoice_text_does_not_rewrite_preferences(self):
        self.save_details(invoice_text="Original")
        self.preferences()
        form = AccountSettingsForm(
            user=self.user,
            data={"username": self.user.username, "email": self.user.email, "invoice_text": "Original"},
        )
        self.assertTrue(form.is_valid(), form.errors)
        with patch("apps.profile.forms.MCustomStyling.save_user"), CaptureQueriesContext(
            connection
        ) as queries:
            form.save()
        writes = [query["sql"] for query in queries if query["sql"].startswith('UPDATE "profile_profile"')]
        self.assertFalse(any('"preferences" =' in query for query in writes), writes)

    def test_generic_preferences_cannot_overwrite_account_invoice_details(self):
        self.save_details(invoice_text="Original")
        self.client.post("/profile/set_preference", {"invoice_text": "x" * 2001, "hide_read_feeds": "true"})
        self.assertEqual(self.preferences()["invoice_text"], "Original")
        self.assertTrue(self.preferences()["hide_read_feeds"])
