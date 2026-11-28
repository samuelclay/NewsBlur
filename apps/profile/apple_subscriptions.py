"""Apply already verified App Store transactions to an existing NewsBlur account."""

import datetime
import uuid

from django.db import transaction
from django.db.models import Max, Q
from django.utils.crypto import salted_hmac

from apps.profile.models import PaymentHistory, Profile
from apps.team.app_store_billing import (
    bills_team,
    end_refunded_team,
    record_app_store_payment,
    record_pending_plan,
    settle_switch_down,
    switched_down_team,
)
from apps.team.models import team_pro_grant

# apple_subscriptions.py: the team plans rank above Pro and share a rank, so the newer of the two verified purchases
# decides which one the team is on (apps/team/app_store_billing.py).
TEAM_RANK = 4
APPLE_PRODUCTS = {
    "newsblur_premium_auto_renew_36": ("premium", "ios-subscription", 36, 1),
    "newsblur_premium_archive": ("archive", "ios-archive-subscription", 99, 2),
    # Archive Extra shares Archive's rank, so switching between them is a same-tier change of the Listen allowance.
    "newsblur_premium_archive_extra": ("archive_extra", "ios-archive-extra-subscription", 159, 2),
    "newsblur_premium_pro": ("pro", "ios-pro-subscription", 29, 3),
    "newsblur_premium_team": ("team", "ios-team-subscription", 79, TEAM_RANK),
    "newsblur_premium_team_enterprise": (
        "team_enterprise",
        "ios-team-enterprise-subscription",
        129,
        TEAM_RANK,
    ),
}
APPLE_PROVIDERS = tuple(product[1] for product in APPLE_PRODUCTS.values())
TIER_RANKS = {tier: rank for tier, _provider, _amount, rank in APPLE_PRODUCTS.values()}
# apple_subscriptions.py: the environments whose signed transactions start and renew plans. App Review, TestFlight
# and sandbox testers buy in the sandbox, which Apple signs as it signs production.
APPLE_ENVIRONMENTS = ("Production", "Sandbox")
# apple_subscriptions.py: why a purchase the app posted changed nothing, by why apply_verified_apple_transaction
# ignored it (apply_apple_purchase).
PURCHASE_REFUSALS = {
    "environment": "not_verified",
    "revoked-or-upgraded": "ended",
    "expired": "ended",
    "refunded": "ended",
    "family-shared": "other_account",
}


def app_account_token(user_id):
    """The app account token the iOS and macOS apps buy a plan with for this account (apps/team/views.py). Apple signs
    it into every transaction of that subscription, which ties them to this account. It can't be worked out from the
    account's id without the server's secret key."""
    digest = salted_hmac(
        "apps.profile.apple_subscriptions.app_account_token", str(user_id), algorithm="sha256"
    ).digest()
    return str(uuid.UUID(bytes=digest[:16], version=4))


def is_account_token(token, user_id):
    try:
        return uuid.UUID(str(token)) == uuid.UUID(app_account_token(user_id))
    except ValueError:
        return False


def _paid_rank(profile):
    """The rank of the plan the account pays for itself, or 0 for none. The owner of a team the App Store bills pays
    for the team in the same subscription, so theirs is the team's rank. A teammate's flags show team Pro, so
    theirs is the tier they hold on their own (apps/team/models.py TeamProGrant)."""
    if bills_team(profile.user_id):
        return TEAM_RANK
    team_grant = team_pro_grant(profile.user_id)
    if team_grant:
        return TIER_RANKS.get(team_grant.own_tier, 0)
    if not profile.is_premium or profile.is_premium_trial:
        return 0
    return 3 if profile.is_pro else 2 if profile.is_archive else 1


def _apple_date(value):
    try:
        if isinstance(value, bool) or value is None:
            raise ValueError("Missing Apple transaction date")
        return datetime.datetime.utcfromtimestamp(int(value) / 1000)
    except (TypeError, ValueError, OverflowError, OSError) as exc:
        raise ValueError("Invalid Apple transaction date") from exc


def apply_verified_apple_transaction(transaction_data, now=None, account=None):
    """Accept only signature-verified production or sandbox transactions, never client claims.

    apps/profile/views.py verifies the signed notification and transaction before
    calling here. Existing payment history is the account ownership evidence, and
    the app account token Apple signs into a transaction narrows it to the account
    the token was made for (app_account_token); an Apple account identifier is not
    sufficient. account is the account the app posted a verified transaction from
    (apply_apple_purchase), which owns it unless the history gives it to another.
    A transaction for a plan other than the one the account pays for is ignored,
    unless the app posted it: its payment is then recorded, and apply_apple_purchase
    starts its plan.

    A team plan's transaction, and one that switched a team's subscription down to
    a plan of the owner's own, go on to apps/team/app_store_billing.py.
    """
    now = now or datetime.datetime.now()
    if transaction_data.get("environment") not in APPLE_ENVIRONMENTS:
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
    team_plan = rank == TEAM_RANK
    sandbox = transaction_data.get("environment") == "Sandbox"
    if team_plan and transaction_data.get("inAppOwnershipType") == "FAMILY_SHARED":
        # apple_subscriptions.py: a team plan is for the account that bought it, not the buyer's family.
        return {"status": "ignored", "reason": "family-shared"}
    token = transaction_data.get("appAccountToken")
    ownership = Q(payment_identifier__in=(identifier, original_identifier)) | Q(
        apple_original_transaction_id=original_identifier
    )

    def owners():
        user_ids = set(
            PaymentHistory.objects.filter(ownership, payment_provider__in=APPLE_PROVIDERS).values_list(
                "user_id", flat=True
            )
        )
        if account:
            user_ids.add(account.pk)
        if token:
            user_ids = {user_id for user_id in user_ids if is_account_token(token, user_id)}
        return user_ids

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
        # apple_subscriptions.py: a team plan's payment is the team's, and the plan a team's subscription switched
        # down to replaces the team's, so neither is compared with the plan the account has now.
        switched_from = (
            None if team_plan else switched_down_team(user_id, original_identifier, purchase, tier)
        )
        current_rank = None
        cross_tier = False
        if not team_plan and not switched_from:
            current_rank = _paid_rank(profile)
            paid = current_rank > 0
            if paid and profile.premium_expire is None:
                return {"status": "ignored", "reason": "lifetime", "user_id": user_id}
            cross_tier = paid and current_rank != rank
            if cross_tier and not account:
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
        payment.plan = tier
        payment.period_end = expiration
        payment.sandbox = sandbox or None
        payment.save()

        if not team_plan and not cross_tier:
            previous_expiration = profile.premium_expire
            target_expiration = max(
                expiration,
                previous_expiration if current_rank == rank and previous_expiration else expiration,
            )
            profile.premium_expire = target_expiration
            profile.save(update_fields=["premium_expire"])

    status = "duplicate" if duplicate else "processed"
    if cross_tier:
        return {"status": status, "reason": "cross-tier", "user_id": user_id}
    if team_plan:
        team_payment = record_app_store_payment(
            profile.user,
            tier,
            original_identifier,
            purchase,
            expiration,
            sandbox=sandbox,
        )
        result = {"status": status, "user_id": user_id}
        if team_payment.reason:
            result["reason"] = team_payment.reason
        return result

    # Commit the durable receipt before apps/profile/models.py sends activation
    # tasks. A failed activation can be retried even when the receipt exists.
    if tier in ("archive", "archive_extra"):
        # Archive and Archive Extra share a rank, so a replayed or late notification for an older transaction
        # of either one also gets here. Only the newer of the two verified purchases decides between them, which
        # is what an App Store crossgrade produces. Extra billed by Stripe, PayPal or Google Play
        # (Profile.active_provider in apps/profile/models.py) isn't in Apple's history, so an Apple Archive
        # transaction never takes that away.
        other_provider = (
            "ios-archive-subscription" if tier == "archive_extra" else "ios-archive-extra-subscription"
        )
        other_latest = (
            PaymentHistory.objects.filter(
                user_id=user_id, payment_provider=other_provider, apple_expires_date__isnull=False
            )
            .exclude(refunded=True)
            .aggregate(latest=Max("payment_date"))["latest"]
        )
        # Purchases at the same moment keep Extra rather than take it away.
        if not other_latest:
            newest_purchase = True
        elif tier == "archive_extra":
            newest_purchase = purchase >= other_latest
        else:
            newest_purchase = purchase > other_latest
        if tier == "archive_extra" and newest_purchase:
            profile.activate_archive_extra()
        else:
            downgrade = tier == "archive" and newest_purchase and not profile.active_provider
            profile.activate_archive(downgrade_extra=downgrade)
    else:
        getattr(profile, "activate_%s" % tier)()
    if switched_from:
        settle_switch_down(profile.user, original_identifier, tier)
    with transaction.atomic():
        profile = Profile.objects.select_for_update().get(user_id=user_id)
        if profile.premium_expire is None or _paid_rank(profile) != rank:
            return {"status": status, "user_id": user_id}
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
    return {"status": status, "user_id": user_id}


def apply_apple_purchase(user, transaction_data):
    """A transaction the app posted from this account, once Apple's signature on it is verified
    (apps/profile/apple_notifications.py process_apple_purchase). It is applied as a notification of it would be, to
    this account, unless it carries another account's app account token or the payment history gives it to another
    account. A plan above or below the one the account pays for, which a notification leaves alone, starts the way the
    app's purchases always have (Profile.activate_ios_premium and the rest), with its payment recorded from Apple's
    purchase and expiry dates. Returns None when the account's plan follows the transaction, or why it doesn't: a
    reason apps/profile/views.py save_ios_receipt explains."""
    product = APPLE_PRODUCTS.get(transaction_data.get("productId"))
    if product is None:
        return "unknown_product"
    token = transaction_data.get("appAccountToken")
    if token and not is_account_token(token, user.pk):
        return "other_account"
    result = apply_verified_apple_transaction(transaction_data, account=user)
    status, reason = result["status"], result.get("reason")
    if status not in ("processed", "duplicate", "ignored"):
        return "other_account"
    if reason == "cross-tier":
        # apple_subscriptions.py: what Profile.activate_ios_premium and the rest do once they've recorded a payment,
        # here one recorded with Apple's dates, so what it pays for ends when Apple says. activate_ios_premium starts
        # Premium only on an account without it, which an account paying for another plan isn't.
        profile = Profile.objects.get(user=user)
        profile.setup_premium_history()
        if product[0] != "premium":
            getattr(profile, "activate_%s" % product[0])()
        return None
    if status == "ignored" and reason == "lifetime":
        profile = Profile.objects.get(user=user)
        getattr(profile, "activate_ios_%s" % product[0])(transaction_data["transactionId"])
        if transaction_data.get("environment") == "Sandbox":
            PaymentHistory.objects.filter(
                user=user, payment_identifier=transaction_data["transactionId"]
            ).update(sandbox=True)
        return None
    if status == "ignored":
        return PURCHASE_REFUSALS.get(reason, "ended")
    return reason if reason in ("on_team", "comped") else None


def apply_verified_apple_refund(transaction_data):
    """Apple refunded or revoked a verified transaction. A payment taken back for a team plan ends the team it paid
    for at once (apps/team/app_store_billing.py end_refunded_team). Any other plan runs to its expiry."""
    product = APPLE_PRODUCTS.get(transaction_data.get("productId"))
    if (
        transaction_data.get("environment") not in APPLE_ENVIRONMENTS
        or not product
        or product[3] != TEAM_RANK
    ):
        return {"status": "ignored", "reason": "not_a_team_payment"}
    identifier = transaction_data.get("transactionId")
    original_identifier = transaction_data.get("originalTransactionId")
    if any(not isinstance(value, str) or not value for value in (identifier, original_identifier)):
        raise ValueError("Invalid Apple transaction identifier")
    team = end_refunded_team(
        identifier, original_identifier, _apple_date(transaction_data.get("purchaseDate"))
    )
    if not team:
        return {"status": "ignored", "reason": "team_kept"}
    return {"status": "processed", "user_id": team.owner_id}


def record_apple_pending_plan(renewal_info):
    """The plan a team's App Store subscription renews into, from Apple's verified renewal info
    (apps/team/app_store_billing.py record_pending_plan). It renews into nothing once its owner turns renewal
    off."""
    if renewal_info.get("environment") not in APPLE_ENVIRONMENTS:
        return
    product = APPLE_PRODUCTS.get(renewal_info.get("autoRenewProductId"))
    renews = renewal_info.get("autoRenewStatus") == 1
    record_pending_plan(renewal_info.get("originalTransactionId"), product[0] if product and renews else None)
