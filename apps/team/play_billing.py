"""Team plans billed through Google Play, on Android. apps/profile/views.py hands this module a purchase the app posted
or a real time developer notification, and neither is taken at its word: the subscription is read from Google with its
purchase token, and a team starts, renews, comes back, switches or ends only on what Google's record says
(apps/team/billing.py record_team_payment).

The app buys a team plan with the account's obfuscated account id (play_account_id), which Google keeps on the
subscription, so Google's record names the NewsBlur account it was bought for. The purchase token is the team's billing
reference and stays the same across renewals. A purchase that replaces another subscription gets a new token that Google
links to the old one: an upgrade takes effect at once, and a switch down keeps the plan paid for until the month ends,
with the plan it renews into named on the subscription."""

import datetime

import dateutil.parser
from dateutil.relativedelta import relativedelta
from django.conf import settings
from django.db import transaction
from django.utils.crypto import salted_hmac

from apps.profile.models import GooglePlayIds, PaymentHistory, Profile
from apps.team.billing import (
    end_team_now,
    end_team_switched_down,
    finish_switch_down,
    record_team_payment,
)
from apps.team.models import Team
from apps.team.tasks import StopRenewalsMadeBefore
from utils import log as logging

# play_billing.py: product ids are matched exactly, never by a part of the id, which the two team ids share.
PLAY_TEAM_PRODUCTS = {
    "nb.premium.team.79": (Team.PLAN_TEAM, "android-team", 79),
    "nb.premium.team.enterprise.129": (Team.PLAN_TEAM_ENTERPRISE, "android-team-enterprise", 129),
}
PLAY_TEAM_PROVIDERS = tuple(provider for _plan, provider, _amount in PLAY_TEAM_PRODUCTS.values())
# play_billing.py: the plans of an account's own sold on Google Play, with the payment provider and price
# Profile.activate_android_premium records for each. A team's subscription can be switched down to one of them.
PLAY_OWN_PRODUCTS = {
    "nb.premium.36": ("premium", "android-subscription", 36),
    "nb.premium.archive.99": ("archive", "android-archive", 99),
    "nb.premium.archive.extra.159": ("archive_extra", "android-archive-extra", 159),
    "nb.premium.pro.299": ("pro", "android-pro", 299),
}
# play_billing.py: every product NewsBlur sells on Google Play, and its plan. A purchase of any other starts nothing.
PLAY_PLANS = {
    product: plan
    for product, (plan, _provider, _amount) in {**PLAY_OWN_PRODUCTS, **PLAY_TEAM_PRODUCTS}.items()
}
# play_billing.py: the states in which a line item is paid for up to its expiry time. A canceled subscription is paid
# for until then and doesn't renew. In a grace period or on hold, Google hasn't been paid for the renewal.
PAID_STATES = ("SUBSCRIPTION_STATE_ACTIVE", "SUBSCRIPTION_STATE_CANCELED")
# play_billing.py: the real time developer notification types read here (apps/profile/views.py
# handle_google_play_notification names them all). Recovered, renewed, purchased and restarted apply what Google's
# record shows. On hold, grace period and expired change nothing, since the hourly task lapses a team a day after its
# paid period (apps/team/tasks.py TeamProGrants).
PAYMENT_NOTIFICATIONS = (1, 2, 4, 7)
CANCELED_NOTIFICATION = 3
REVOKED_NOTIFICATION = 12


def play_account_id(user_id):
    """The obfuscated account id the Android app buys a team plan with for this account (apps/team/views.py
    play_purchase). Google keeps it on the subscription, which ties the subscription to this account. It can't be
    worked out from the account's id without the server's secret key."""
    return salted_hmac(
        "apps.team.play_billing.play_account_id", str(user_id), algorithm="sha256"
    ).hexdigest()[:32]


def save_play_purchase(user, product_id, purchase_token):
    """A purchase the Android app posted (apps/profile/views.py save_android_receipt). A team plan's purchase, or one
    Google's record shows on the subscription that bills the account's team, is applied from Google's record of it.
    Returns (False, None) for any other purchase, which the caller applies as before, or (True, None) once the
    account's plan follows Google's record, or (True, why it doesn't)."""
    team_product = product_id in PLAY_TEAM_PRODUCTS
    if not team_product and not (purchase_token and _play_teams().filter(owner=user).exists()):
        return False, None
    if not purchase_token:
        return True, "not_verified"
    subscription = _google_play_subscription(purchase_token)
    if not team_product and not _is_team_subscription(user, purchase_token, subscription):
        return False, None
    if not subscription:
        return True, "verify_later"
    return True, apply_play_subscription(user, purchase_token, subscription)


def is_team_notification(purchase_token, product_id):
    """Whether a real time developer notification is for a team plan's subscription or the one that bills a team."""
    return (
        product_id in PLAY_TEAM_PRODUCTS
        or _play_teams().filter(billing_reference=purchase_token).exists()
        or GooglePlayIds.objects.filter(
            purchase_token=purchase_token, product_id__in=list(PLAY_TEAM_PRODUCTS)
        ).exists()
    )


def process_play_notification(purchase_token, notification_type):
    """A real time developer notification for a team plan (apps/profile/views.py google_play_rtdn), for the account
    the subscription is for (_subscriber). Returns "verify_later" when Google couldn't be asked, so the notification is
    delivered again, or None."""
    if notification_type not in PAYMENT_NOTIFICATIONS + (CANCELED_NOTIFICATION, REVOKED_NOTIFICATION):
        return None
    subscription = _google_play_subscription(purchase_token)
    if not subscription:
        return "verify_later"
    user = _subscriber(purchase_token, subscription)
    if not user:
        logging.debug(" ---> Google Play team notification for an unknown purchase: %s" % notification_type)
        return None
    if _account_id(subscription) != play_account_id(user.pk):
        logging.user(user, "~FRGoogle Play team notification for a purchase made for another account")
        return None
    if notification_type == REVOKED_NOTIFICATION:
        _end_revoked_team(user, purchase_token, subscription)
    elif notification_type == CANCELED_NOTIFICATION:
        _record_pending_plan(purchase_token, subscription)
    else:
        reason = apply_play_subscription(user, purchase_token, subscription)
        logging.user(
            user, "~FCGoogle Play team notification %s: %s" % (notification_type, reason or "applied")
        )
    return None


def apply_play_subscription(user, purchase_token, subscription):
    """A subscription as Google's API returned it for purchase_token, bought by user. A team plan Google shows as paid
    for starts or renews the account's team, with Google's expiry time as its paid through date. A plan of the
    account's own that the team's subscription switched to starts as any Play purchase does, and ends the team once
    its paid month is over. Returns None when the account's plan follows the subscription, or why it doesn't:
    "other_account" when Google's record names another account, "ended" when it shows nothing paid for, and
    record_team_payment's "on_team" or "comped"."""
    if _account_id(subscription) != play_account_id(user.pk):
        return "other_account"
    now = datetime.datetime.now()
    team_item = _paid_item(subscription, PLAY_TEAM_PRODUCTS, now)
    if team_item:
        return _apply_team_item(user, purchase_token, subscription, team_item, now)
    own_item = _paid_item(subscription, PLAY_OWN_PRODUCTS, now)
    if own_item:
        _apply_own_item(user, purchase_token, subscription, own_item)
        return None
    return "ended"


def _apply_team_item(user, purchase_token, subscription, item, now):
    """A team plan Google has been paid for until the item's expiry. When this moves the team's billing to Google Play,
    every Stripe and PayPal subscription the account made before the purchase stops renewing, as when Stripe or PayPal
    starts billing a team (apps/team/tasks.py StopRenewalsMadeBefore). A test purchase costs nothing, so it stops none
    of them. A store subscription can't be stopped from here, so record_team_payment tells staff when one billed the
    team before."""
    plan, provider, amount = PLAY_TEAM_PRODUCTS[item["productId"]]
    paid_through = _google_time(item["expiryTime"])
    paid_at = _period_start(subscription, paid_through, now)
    test_purchase = "testPurchase" in subscription
    order_id = _order_id(subscription, item)
    _remember_token(user, purchase_token, item["productId"], order_id)
    if order_id:
        _record_payment(user, provider, amount, plan, order_id, paid_at, paid_through, test_purchase)
    billed_before = _billing(user.pk)
    payment = record_team_payment(
        user,
        plan,
        Team.PROVIDER_PLAY,
        paid_through,
        purchase_token,
        paid_at,
        replaces_own_plan=_replaces_own_plan(user, purchase_token, subscription),
    )
    moved_here = _billing(user.pk) == (Team.PROVIDER_PLAY, purchase_token) and (
        not billed_before or billed_before[0] != Team.PROVIDER_PLAY
    )
    if payment.reason is None and moved_here and not test_purchase:
        started_at = paid_at.timestamp()
        transaction.on_commit(lambda: StopRenewalsMadeBefore.delay(user_id=user.pk, started_at=started_at))
    _record_pending_plan(purchase_token, subscription)
    return payment.reason if payment.reason in ("on_team", "comped") else None


def _apply_own_item(user, purchase_token, subscription, item):
    """A plan of the account's own on a subscription that is or replaced the team's: the switch down Google renewed
    into, or one that replaced the team's subscription at once. It is recorded and started the way
    Profile.activate_android_premium starts it, and the team ends once its paid month is over (_settle_switch_down).
    """
    plan, provider, amount = PLAY_OWN_PRODUCTS[item["productId"]]
    order_id = _order_id(subscription, item)
    _remember_token(user, purchase_token, item["productId"], order_id)
    if order_id:
        _record_payment(
            user,
            provider,
            amount,
            plan,
            order_id,
            datetime.datetime.now(),
            _google_time(item["expiryTime"]),
            "testPurchase" in subscription,
        )
    profile = Profile.objects.get(user=user)
    profile.setup_premium_history()
    getattr(profile, "activate_%s" % plan)()
    _settle_switch_down(user, purchase_token, subscription, plan)


def _settle_switch_down(user, purchase_token, subscription, plan):
    """The owner's own plan now on the subscription that billed their team, or on the one that replaced it. The team
    ends when its paid month is over, with the owner on plan (apps/team/billing.py end_team_switched_down), or finishes
    the switch its lapse was waiting for (finish_switch_down). Until the month is over Team.pending_plan shows plan, and
    the hourly task ends the team a day after it, when the owner goes back to plan as theirs
    (apps/team/grants.py release_team_pro)."""
    team = (
        _play_teams()
        .filter(
            owner=user, billing_reference__in=_tokens(purchase_token, subscription.get("linkedPurchaseToken"))
        )
        .first()
    )
    if not team or (team.status != Team.STATUS_ACTIVE and team.pending_plan != plan):
        return
    reference = team.billing_reference
    ended, own_plan = end_team_switched_down(user, Team.PROVIDER_PLAY, reference, plan)
    if ended:
        logging.user(
            user,
            "~FCTeam %s ended on its Google Play switch down to %s, now on %s" % (ended.pk, plan, own_plan),
        )
        return
    if finish_switch_down(user, Team.PROVIDER_PLAY, reference, plan):
        logging.user(user, "~FCTeam switch down to %s finished once Google Play collected it" % plan)
        return
    _play_teams().filter(pk=team.pk, status=Team.STATUS_ACTIVE).update(pending_plan=plan)


def _record_pending_plan(purchase_token, subscription):
    """Team.pending_plan for the active team Google Play bills through purchase_token, from Google's record: the plan
    the subscription renews into once the month paid for ends, when the owner switched down to it, or None when it
    renews on the team's plan or not at all."""
    team = _play_teams().filter(status=Team.STATUS_ACTIVE, billing_reference=purchase_token).first()
    if not team:
        return
    item = _paid_item(subscription, PLAY_TEAM_PRODUCTS, datetime.datetime.now()) or {}
    replacement = (item.get("deferredItemReplacement") or {}).get("productId")
    plan = PLAY_PLANS.get(replacement)
    if subscription.get("subscriptionState") != "SUBSCRIPTION_STATE_ACTIVE" or plan == team.plan:
        plan = None
    _play_teams().filter(pk=team.pk).update(pending_plan=plan)


def _end_revoked_team(user, purchase_token, subscription):
    """Google revoked the subscription, taking its payment back, which its record shows as ended. The payment is
    recorded as refunded, and the team Google Play bills through the subscription ends at once, unless a newer payment
    renewed it since (apps/team/billing.py end_team_now)."""
    if subscription.get("subscriptionState") != "SUBSCRIPTION_STATE_EXPIRED":
        return
    order_ids = [_order_id(subscription, item) for item in subscription.get("lineItems") or []]
    _end_team_taken_back(user, purchase_token, [order_id for order_id in order_ids if order_id])


def end_voided_team(purchase_token, order_id):
    """A voided purchase notification: Google refunded or charged back an order (apps/profile/views.py
    google_play_rtdn). An order that paid for a team plan is confirmed with Google's list of voided purchases, recorded
    as refunded, and ends the team Google Play bills through its subscription at once, unless a newer payment renewed
    it since. Returns "verify_later" when Google couldn't be asked, so the notification is delivered again, or None.
    """
    payment = (
        PaymentHistory.objects.filter(payment_provider__in=PLAY_TEAM_PROVIDERS, payment_identifier=order_id)
        .select_related("user")
        .first()
    )
    if not payment or not purchase_token or not order_id:
        return None
    voided = _voided_by_google(purchase_token, order_id)
    if voided is None:
        return "verify_later"
    if voided:
        _end_team_taken_back(payment.user, purchase_token, [order_id])
    return None


def _end_team_taken_back(user, purchase_token, order_ids):
    payments = PaymentHistory.objects.filter(
        user=user, payment_provider__in=PLAY_TEAM_PROVIDERS, payment_identifier__in=order_ids
    )
    taken_back_at = payments.order_by("-payment_date").values_list("payment_date", flat=True).first()
    payments.update(refunded=True)
    ended = end_team_now(user, Team.PROVIDER_PLAY, purchase_token, taken_back_at)
    if ended:
        logging.user(user, "~FRTeam %s ended: its Google Play payment was refunded or revoked" % ended.pk)


def _voided_by_google(purchase_token, order_id):
    """Whether Google lists the order among the app's voided purchases of the last 30 days, or None when Google
    couldn't be asked."""
    from google.auth.exceptions import GoogleAuthError
    from googleapiclient.errors import HttpError
    from httplib2 import HttpLib2Error

    try:
        voided_purchases = Profile._google_play_service().purchases().voidedpurchases()
        page = None
        while True:
            request = {"packageName": settings.GOOGLE_PLAY_PACKAGE_NAME, "type": 1}
            if page:
                request["token"] = page
            response = voided_purchases.list(**request).execute()
            for voided in response.get("voidedPurchases") or []:
                if voided.get("purchaseToken") == purchase_token and voided.get("orderId") == order_id:
                    return True
            page = (response.get("tokenPagination") or {}).get("nextPageToken")
            if not page:
                return False
    except (HttpError, GoogleAuthError, HttpLib2Error, OSError, ValueError) as e:
        # play_billing.py: Profile._google_play_service raises ValueError when no service account is configured.
        logging.debug(" ---> Google Play voided purchases error: %s" % e)
        return None


def _google_play_subscription(purchase_token):
    # play_billing.py: apps/profile/views.py imports this module.
    from apps.profile.views import get_google_play_subscription

    return get_google_play_subscription(purchase_token)


def _play_teams():
    return Team.objects.filter(billing_provider=Team.PROVIDER_PLAY)


def _tokens(*tokens):
    return [token for token in tokens if token]


def _billing(user_id):
    return Team.objects.filter(owner_id=user_id).values_list("billing_provider", "billing_reference").first()


def _is_team_subscription(user, purchase_token, subscription):
    """Whether Google's record of an own plan's purchase from a team owner is the team's: it bills the team or replaced
    the subscription that does, or it still holds a team plan until a switch down renews."""
    if not subscription:
        return False
    references = _tokens(purchase_token, subscription.get("linkedPurchaseToken"))
    if _play_teams().filter(owner=user, billing_reference__in=references).exists():
        return True
    return any(item.get("productId") in PLAY_TEAM_PRODUCTS for item in subscription.get("lineItems") or [])


def _subscriber(purchase_token, subscription):
    """The account a team plan's subscription is for: the owner of the team it bills, or the account its token was
    posted from, or that of the subscription it replaced or that Google renewed from outside the app."""
    out_of_app = subscription.get("outOfAppPurchaseContext") or {}
    for token in _tokens(
        purchase_token, subscription.get("linkedPurchaseToken"), out_of_app.get("expiredPurchaseToken")
    ):
        team = (
            _play_teams().filter(billing_reference=token, owner__isnull=False).select_related("owner").first()
        )
        if team:
            return team.owner
        known = (
            GooglePlayIds.objects.filter(purchase_token=token, user__isnull=False)
            .select_related("user")
            .first()
        )
        if known:
            return known.user
    return None


def _account_id(subscription):
    """The obfuscated account id Google keeps on the subscription, or on the expired one it renewed from outside the
    app."""
    for identifiers in (
        subscription.get("externalAccountIdentifiers"),
        (subscription.get("outOfAppPurchaseContext") or {}).get("expiredExternalAccountIdentifiers"),
    ):
        account_id = (identifiers or {}).get("obfuscatedExternalAccountId")
        if account_id:
            return account_id
    return None


def _paid_item(subscription, products, now):
    """The line item for one of products that Google shows paid for past now, the one paid for longest if there are
    more, or None. An item waiting to replace another at renewal has no expiry yet."""
    if subscription.get("subscriptionState") not in PAID_STATES:
        return None
    paid = []
    for item in subscription.get("lineItems") or []:
        expiry = _google_time(item.get("expiryTime"))
        if item.get("productId") in products and expiry and expiry > now:
            paid.append((expiry, item))
    return max(paid, key=lambda paid_item: paid_item[0])[1] if paid else None


def _period_start(subscription, paid_through, now):
    """When the month paid through paid_through began, which is when its payment was made: a month before it ends, or
    when the subscription started if that was later, as it is for a purchase that replaced another in the same month.
    Each reading of one payment gives the same time, so a payment read again is never newer than the one after it.
    """
    period_start = paid_through - relativedelta(months=1)
    start = _google_time(subscription.get("startTime"))
    if start and start > period_start:
        period_start = start
    return min(period_start, now)


def _order_id(subscription, item):
    """The order that paid for the line item. Google names it on the item. A subscription holding one item may name it
    only as its latest order. An item that replaces another at renewal has no order yet, so the deferred switch makes
    no payment row of its own."""
    if item.get("latestSuccessfulOrderId"):
        return item["latestSuccessfulOrderId"]
    if len(subscription.get("lineItems") or []) == 1:
        return subscription.get("latestOrderId")
    return None


def _record_payment(user, provider, amount, plan, order_id, paid_at, period_end, test_purchase):
    """One payment row per Google Play order. The app's purchase and Google's notification of one order can arrive at
    once, so the check and the insert hold the account's Profile row. A test purchase is flagged as sandbox, so no
    revenue report counts it."""
    with transaction.atomic():
        Profile.objects.select_for_update().get(user=user)
        if PaymentHistory.objects.filter(
            user=user, payment_provider__startswith="android-", payment_identifier=order_id
        ).exists():
            return
        PaymentHistory.objects.create(
            user=user,
            payment_date=paid_at,
            payment_amount=amount,
            payment_provider=provider,
            payment_identifier=order_id,
            plan=plan,
            period_end=period_end,
            sandbox=test_purchase or None,
        )


def _remember_token(user, purchase_token, product_id, order_id):
    """The purchase token is the account's from now on, so its notifications find the account (google_play_rtdn)."""
    GooglePlayIds.objects.update_or_create(
        purchase_token=purchase_token, defaults=dict(user=user, product_id=product_id, order_id=order_id)
    )


def _replaces_own_plan(user, purchase_token, subscription):
    """Whether this team purchase replaced a plan the owner pays for on their own on Google Play, which Google then
    credits toward the team plan, so there is no plan of their own to go back to once the team ends: Google links the
    purchase to the subscription it replaced, and its record shows one of the account's own plans. Asked only until
    the purchase bills the team."""
    linked = subscription.get("linkedPurchaseToken")
    if not linked or _play_teams().filter(owner=user, billing_reference=purchase_token).exists():
        return False
    if GooglePlayIds.objects.filter(purchase_token=linked).exclude(user=user).exists():
        return False
    replaced = _google_play_subscription(linked)
    return bool(replaced) and any(
        item.get("productId") in PLAY_OWN_PRODUCTS for item in replaced.get("lineItems") or []
    )


def _google_time(value):
    """A time as Google's API writes it, in RFC 3339, as the naive UTC time NewsBlur keeps (settings.TIME_ZONE), or
    None."""
    if not isinstance(value, str):
        return None
    try:
        moment = dateutil.parser.isoparse(value)
    except (ValueError, OverflowError):
        return None
    if moment.tzinfo:
        moment = moment.astimezone(datetime.timezone.utc).replace(tzinfo=None)
    return moment
