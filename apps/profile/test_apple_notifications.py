"""Regression tests for apps/profile/views.py Apple notification endpoint."""

import json
from types import SimpleNamespace
from unittest.mock import Mock, patch

from appstoreserverlibrary.models.Environment import Environment
from appstoreserverlibrary.models.JWSTransactionDecodedPayload import (
    JWSTransactionDecodedPayload,
)
from appstoreserverlibrary.signed_data_verifier import (
    VerificationException,
    VerificationStatus,
)
from django.test import Client, TestCase
from django.urls import reverse

from apps.profile.apple_notifications import (
    APPLE_APP_ID,
    APPLE_BUNDLE_ID,
    apple_verifier,
    process_apple_notification,
    verify_apple_notification,
)


class Test_AppleNotifications(TestCase):
    @patch("apps.profile.views.mail_admins")
    def test_unsigned_notification_is_rejected_without_email(self, mail_admins):
        response = self.client.post(
            reverse("profile-ios-subscription-status"),
            data=json.dumps({"notification_type": "DID_RENEW"}),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 400)
        mail_admins.assert_not_called()

    def test_get_is_not_a_notification(self):
        response = self.client.get(reverse("profile-ios-subscription-status"))
        self.assertEqual(response.status_code, 405)

    def test_malformed_body_is_rejected(self):
        for body in ("null", "[]", "{", '{"signedPayload": 12}'):
            with self.subTest(body=body):
                response = self.client.post(
                    reverse("profile-ios-subscription-status"), data=body, content_type="application/json"
                )
                self.assertEqual(response.status_code, 400)

    @patch("apps.profile.apple_notifications.process_apple_notification")
    def test_retryable_verification_failure_requests_apple_retry(self, process):
        process.side_effect = VerificationException(VerificationStatus.RETRYABLE_VERIFICATION_FAILURE)
        response = self.client.post(
            reverse("profile-ios-subscription-status"),
            data=json.dumps({"signedPayload": "payload"}),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 503)

    @patch("apps.profile.apple_notifications.process_apple_notification")
    def test_unknown_or_ambiguous_account_requests_apple_retry(self, process):
        for status in ("unmatched", "ambiguous"):
            process.return_value = {"status": status}
            response = self.client.post(
                reverse("profile-ios-subscription-status"),
                data=json.dumps({"signedPayload": "payload"}),
                content_type="application/json",
            )
            self.assertEqual(response.status_code, 503)

    @patch("apps.profile.apple_notifications.SignedDataVerifier")
    def test_verifier_requires_apple_trust_application_and_online_checks(self, verifier):
        apple_verifier.cache_clear()
        try:
            apple_verifier(Environment.PRODUCTION)
            roots, online_checks, environment, bundle, app_id = verifier.call_args.args
            self.assertTrue(roots[0])
            self.assertTrue(online_checks)
            self.assertEqual(environment, Environment.PRODUCTION)
            self.assertEqual(bundle, APPLE_BUNDLE_ID)
            self.assertEqual(app_id, APPLE_APP_ID)
        finally:
            apple_verifier.cache_clear()

    @patch("apps.profile.apple_notifications.apple_verifier")
    def test_sandbox_fallback_still_verifies_signature(self, verifier_factory):
        production, sandbox = Mock(), Mock()
        production.verify_and_decode_notification.side_effect = VerificationException(
            VerificationStatus.INVALID_ENVIRONMENT
        )
        verifier_factory.side_effect = [production, sandbox]
        decoded, used = verify_apple_notification("signed")
        self.assertIs(used, sandbox)
        sandbox.verify_and_decode_notification.assert_called_once_with("signed")

    @patch("apps.profile.apple_notifications.apply_verified_apple_transaction")
    @patch("apps.profile.apple_notifications.verify_apple_notification")
    def test_test_notification_never_changes_accounts(self, verify, apply):
        verify.return_value = (SimpleNamespace(notificationType="TEST", notificationUUID="test-uuid"), Mock())
        self.assertEqual(process_apple_notification("signed")["status"], "test")
        apply.assert_not_called()

    @patch("apps.profile.apple_notifications.apply_verified_apple_transaction")
    @patch("apps.profile.apple_notifications.verify_apple_notification")
    def test_renewal_verifies_nested_transaction_before_processing(self, verify, apply):
        verifier = Mock()
        verifier.verify_and_decode_signed_transaction.return_value = JWSTransactionDecodedPayload(
            transactionId="123", originalTransactionId="100", environment=Environment.PRODUCTION
        )
        verify.return_value = (
            SimpleNamespace(
                notificationType="DID_RENEW",
                notificationUUID="renewal-uuid",
                data=SimpleNamespace(signedTransactionInfo="signed-transaction"),
            ),
            verifier,
        )
        apply.return_value = {"status": "processed", "user_id": 1}
        self.assertEqual(process_apple_notification("signed")["status"], "processed")
        verifier.verify_and_decode_signed_transaction.assert_called_once_with("signed-transaction")
        self.assertEqual(apply.call_args.args[0]["transactionId"], "123")

    @patch("apps.profile.apple_notifications.apply_verified_apple_transaction")
    @patch("apps.profile.apple_notifications.verify_apple_notification")
    def test_invalid_nested_transaction_never_reaches_account_processing(self, verify, apply):
        verifier = Mock()
        verifier.verify_and_decode_signed_transaction.side_effect = VerificationException(
            VerificationStatus.INVALID_APP_IDENTIFIER
        )
        verify.return_value = (
            SimpleNamespace(
                notificationType="DID_RENEW",
                notificationUUID="renewal-uuid",
                data=SimpleNamespace(signedTransactionInfo="wrong-app-transaction"),
            ),
            verifier,
        )
        with self.assertRaises(VerificationException):
            process_apple_notification("signed")
        apply.assert_not_called()

    def test_apple_callback_reaches_validation_without_csrf_cookie(self):
        response = Client(enforce_csrf_checks=True).post(
            reverse("profile-ios-subscription-status"),
            data=json.dumps({"signedPayload": "invalid"}),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 400)
