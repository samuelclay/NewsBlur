"""Apply already verified App Store transactions to an existing NewsBlur account."""

import datetime

from django.db import transaction
from django.db.models import Max, Q

from apps.profile.models import PaymentHistory, Profile

APPLE_PRODUCTS = {
    "newsblur_premium_auto_renew_36": ("premium", "ios-subscription", 36, 1),
    "newsblur_premium_archive": ("archive", "ios-archive-subscription", 99, 2),
    "newsblur_premium_pro": ("pro", "ios-pro-subscription", 29, 3),
}
APPLE_PROVIDERS = tuple(product[1] for product in APPLE_PRODUCTS.values())


def _apple_date(value):
    try:
        if isinstance(value, bool) or value is None:
            raise ValueError("Missing Apple transaction date")
        return datetime.datetime.utcfromtimestamp(int(value) / 1000)
    except (TypeError, ValueError, OverflowError, OSError) as exc:
        raise ValueError("Invalid Apple transaction date") from exc


def apply_verified_apple_transaction(transaction_data, now=None):
    """Accept only signature-verified production transactions, never client claims.

    apps/profile/views.py verifies the signed notification and transaction before
    calling here. Existing payment history is the only account ownership evidence;
    an Apple account identifier or untrusted client account token is not sufficient.
    """
    now = now or datetime.datetime.now()
    if transaction_data.get("environment") != "Production":
        return {"status": "ignored", "reason": "environment"}
    product = APPLE_PRODUCTS.get(transaction_data.get("productId"))
    if product is None:
        return {"status": "ignored", "reason": "product"}
    if transaction_data.get("revocationDate") is not None or transaction_data.get("isUpgraded"):
        return {"status": "ignored", "reason": "revoked-or-upgraded"}
    purchase = _apple_date(transaction_data.get("purchaseDate"))
    expiration = _apple_date(transaction_data.get("expiresDate"))
    if purchase >= expiration or purchase > now:
        raise ValueError("Invalid Apple transaction period")
    if expiration <= now:
        return {"status": "ignored", "reason": "expired"}
    identifier = transaction_data.get("transactionId")
    original_identifier = transaction_data.get("originalTransactionId")
    if any(
        not isinstance(value, str) or not value or len(value) > 100
        for value in (identifier, original_identifier)
    ):
        raise ValueError("Invalid Apple transaction identifier")

    tier, provider, amount, rank = product
    ownership = Q(payment_identifier__in=(identifier, original_identifier)) | Q(
        apple_original_transaction_id=original_identifier
    )

    def owners():
        return set(
            PaymentHistory.objects.filter(ownership, payment_provider__in=APPLE_PROVIDERS).values_list(
                "user_id", flat=True
            )
        )

    with transaction.atomic():
        user_ids = owners()
        if not user_ids:
            return {"status": "unmatched"}
        if len(user_ids) != 1:
            return {"status": "ambiguous"}
        user_id = user_ids.pop()
        profile = Profile.objects.select_for_update().select_related("user").get(user_id=user_id)
        if owners() != {user_id}:
            return {"status": "ambiguous"}
        paid = profile.is_premium and not profile.is_premium_trial
        if paid and profile.premium_expire is None:
            return {"status": "ignored", "reason": "lifetime", "user_id": user_id}
        current_rank = (3 if profile.is_pro else 2 if profile.is_archive else 1) if paid else 0
        if paid and current_rank != rank:
            # apps/profile/models.py has one shared tier/expiry, so a lower-tier
            # or upgrade transaction needs separate entitlement reconciliation.
            return {"status": "ignored", "reason": "cross-tier", "user_id": user_id}

        payments = PaymentHistory.objects.filter(user_id=user_id, payment_provider__in=APPLE_PROVIDERS)
        payment = payments.filter(payment_identifier=identifier).first()
        duplicate = bool(payment and payment.apple_expires_date)
        if payment and payment.refunded:
            return {"status": "ignored", "reason": "refunded", "user_id": user_id}
        if duplicate:
            expiration = max(expiration, payment.apple_expires_date)
        if payment is None:
            # Old clients post the original ID and local receipt time. Reconcile
            # that period in place in apps/profile/models.py's payment ledger.
            payment = (
                payments.filter(
                    payment_provider=provider,
                    payment_identifier=original_identifier,
                    apple_expires_date__isnull=True,
                    payment_date__gte=purchase - datetime.timedelta(minutes=5),
                    payment_date__lt=expiration,
                )
                .exclude(refunded=True)
                .order_by("payment_date")
                .first()
            )
        if payment is None:
            payment = PaymentHistory(user_id=user_id)
        payment.payment_identifier = identifier
        payment.apple_original_transaction_id = original_identifier
        payment.apple_expires_date = expiration
        payment.payment_date = purchase
        payment.payment_provider = provider
        # PaymentHistory stores integer USD plan prices, as the existing iOS
        # client receipt paths in apps/profile/models.py do, not Apple proceeds.
        payment.payment_amount = amount
        payment.save()

        previous_expiration = profile.premium_expire
        target_expiration = max(
            expiration,
            previous_expiration if current_rank == rank and previous_expiration else expiration,
        )
        profile.premium_expire = target_expiration
        profile.save(update_fields=["premium_expire"])

    # Commit the durable receipt before apps/profile/models.py sends activation
    # tasks. A failed activation can be retried even when the receipt exists.
    getattr(profile, "activate_%s" % tier)()
    with transaction.atomic():
        profile = Profile.objects.select_for_update().get(user_id=user_id)
        fresh_rank = 3 if profile.is_pro else 2 if profile.is_archive else 1
        if profile.premium_expire is None or fresh_rank != rank:
            return {"status": "duplicate" if duplicate else "processed", "user_id": user_id}
        latest_expiration = (
            PaymentHistory.objects.filter(
                user_id=user_id,
                payment_provider=provider,
                apple_original_transaction_id=original_identifier,
            )
            .exclude(refunded=True)
            .aggregate(expiration=Max("apple_expires_date"))["expiration"]
        )
        # Activation can infer dates through setup_premium_history in
        # apps/profile/models.py. Concurrent signed renewals must also survive.
        profile.premium_expire = max(
            profile.premium_expire, target_expiration, latest_expiration or target_expiration
        )
        profile.save(update_fields=["premium_expire"])
    return {"status": "duplicate" if duplicate else "processed", "user_id": user_id}
