"""Verify App Store Server Notifications V2 before updating any account."""

from functools import lru_cache
from pathlib import Path

import attrs
from appstoreserverlibrary.models.Environment import Environment
from appstoreserverlibrary.signed_data_verifier import (
    SignedDataVerifier,
    VerificationException,
    VerificationStatus,
)

from apps.profile.apple_subscriptions import apply_verified_apple_transaction

APPLE_BUNDLE_ID = "com.newsblur.NewsBlur"
APPLE_APP_ID = 463981119
RENEWAL_NOTIFICATIONS = {"SUBSCRIBED", "DID_RENEW", "DID_RECOVER", "RENEWAL_EXTENDED"}


@lru_cache(maxsize=2)
def apple_verifier(environment):
    # AppleRootCA-G3.cer in apps/profile/certificates comes from Apple's PKI site.
    root = Path(__file__).with_name("certificates") / "AppleRootCA-G3.cer"
    return SignedDataVerifier([root.read_bytes()], True, environment, APPLE_BUNDLE_ID, APPLE_APP_ID)


def verify_apple_notification(signed_payload):
    """Try both real Apple environments; never enable unsigned local testing."""
    retryable = None
    for environment in (Environment.PRODUCTION, Environment.SANDBOX):
        verifier = apple_verifier(environment)
        try:
            notification = verifier.verify_and_decode_notification(signed_payload)
            return notification, verifier
        except VerificationException as exc:
            if exc.status == VerificationStatus.RETRYABLE_VERIFICATION_FAILURE:
                retryable = exc
    if retryable:
        raise retryable
    raise VerificationException(VerificationStatus.VERIFICATION_FAILURE)


def process_apple_notification(signed_payload):
    notification, verifier = verify_apple_notification(signed_payload)
    kind = notification.notificationType
    result = {"notification_type": kind, "notification_uuid": notification.notificationUUID}
    if kind == "TEST":
        return dict(result, status="test")
    if kind not in RENEWAL_NOTIFICATIONS:
        return dict(result, status="ignored", reason="not_a_renewal")
    if not notification.data or not notification.data.signedTransactionInfo:
        raise ValueError("Missing signed transaction")
    transaction = verifier.verify_and_decode_signed_transaction(notification.data.signedTransactionInfo)
    return dict(result, **apply_verified_apple_transaction(attrs.asdict(transaction)))
