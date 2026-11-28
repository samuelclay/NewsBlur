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

from apps.profile.apple_subscriptions import (
    APPLE_PRODUCTS,
    TEAM_RANK,
    apply_apple_purchase,
    apply_verified_apple_refund,
    apply_verified_apple_transaction,
    record_apple_pending_plan,
)

APPLE_BUNDLE_ID = "com.newsblur.NewsBlur"
APPLE_APP_ID = 463981119
RENEWAL_NOTIFICATIONS = {"SUBSCRIBED", "DID_RENEW", "DID_RECOVER", "RENEWAL_EXTENDED"}
# apple_notifications.py: a team plan's transaction is applied too when its owner switches plans or turns renewal on
# or off, which is when Apple's renewal info says what the team renews into, and Apple taking its payment back ends the
# team (apps/team/app_store_billing.py).
TEAM_NOTIFICATIONS = RENEWAL_NOTIFICATIONS | {"DID_CHANGE_RENEWAL_PREF", "DID_CHANGE_RENEWAL_STATUS"}
TAKEN_BACK_NOTIFICATIONS = {"REFUND", "REVOKE"}


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


def verify_apple_transaction(signed_transaction):
    """A transaction the app posted, verified as Apple's for this app in either real environment, as
    verify_apple_notification verifies a notification."""
    retryable = None
    for environment in (Environment.PRODUCTION, Environment.SANDBOX):
        try:
            return apple_verifier(environment).verify_and_decode_signed_transaction(signed_transaction)
        except VerificationException as exc:
            if exc.status == VerificationStatus.RETRYABLE_VERIFICATION_FAILURE:
                retryable = exc
    if retryable:
        raise retryable
    raise VerificationException(VerificationStatus.VERIFICATION_FAILURE)


def process_apple_purchase(user, signed_transaction):
    """A purchase the app posted with the transaction StoreKit signed (apps/profile/views.py save_ios_receipt). Returns
    None once the account's plan follows it, or why it doesn't (apply_apple_purchase)."""
    transaction = verify_apple_transaction(signed_transaction)
    return apply_apple_purchase(user, attrs.asdict(transaction))


def process_apple_notification(signed_payload):
    notification, verifier = verify_apple_notification(signed_payload)
    kind = notification.notificationType
    result = {"notification_type": kind, "notification_uuid": notification.notificationUUID}
    if kind == "TEST":
        return dict(result, status="test")
    if kind not in TEAM_NOTIFICATIONS | TAKEN_BACK_NOTIFICATIONS:
        return dict(result, status="ignored", reason="not_a_renewal")
    if not notification.data or not notification.data.signedTransactionInfo:
        raise ValueError("Missing signed transaction")
    transaction = verifier.verify_and_decode_signed_transaction(notification.data.signedTransactionInfo)
    transaction = attrs.asdict(transaction)
    product = APPLE_PRODUCTS.get(transaction.get("productId"))
    if not product or product[3] != TEAM_RANK:
        if kind not in RENEWAL_NOTIFICATIONS:
            return dict(result, status="ignored", reason="not_a_renewal")
        return dict(result, **apply_verified_apple_transaction(transaction))
    if kind in TAKEN_BACK_NOTIFICATIONS:
        return dict(result, **apply_verified_apple_refund(transaction))
    applied = apply_verified_apple_transaction(transaction)
    if notification.data.signedRenewalInfo:
        renewal_info = verifier.verify_and_decode_renewal_info(notification.data.signedRenewalInfo)
        record_apple_pending_plan(attrs.asdict(renewal_info))
    return dict(result, **applied)
