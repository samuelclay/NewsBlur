"""Team plans billed through PayPal. Every PayPal notice for an account ends in Profile.setup_premium_history, which
reads the account's PayPal subscriptions and their transactions and hands them to sync_team_subscriptions here, so a
team starts, renews, comes back, switches or ends only on what PayPal itself reports (apps/team/billing.py
record_team_payment). PayPal can't change a subscription's plan with proration, so a switch is a new subscription. A
switch up bills the team once PayPal shows its first payment, and the subscriptions it replaces stop renewing with the
unused part of their payment refunded. A switch down starts when the month already paid for ends, and the team's own
subscription stops renewing without a refund."""

import datetime

import dateutil.parser
from django.contrib.auth.models import User
from django.db import transaction

from apps.profile.models import PaypalIds, Profile
from apps.profile.tasks import EmailStaffNotification
from apps.team.billing import end_team_now, end_team_switched_down, record_team_payment
from apps.team.grants import PROVIDER_ERRORS, renewing_subscriptions
from apps.team.models import Team, TeamProGrant
from apps.team.stripe_billing import TEAM_PLANS
from apps.team.tasks import StopRenewalsMadeBefore
from utils import log as logging

# paypal_billing.py: a subscription the buyer approved, which PayPal goes on billing, the transactions that moved
# money, and those PayPal took back.
RENEWING_STATUSES = ("ACTIVE", "APPROVED")
PAYMENT_STATUSES = ("COMPLETED", "PARTIALLY_REFUNDED", "REFUNDED", "REVERSED")
TAKEN_BACK_STATUSES = ("REFUNDED", "REVERSED")


def settled_by_team_sync(profile, plan_id):
    """Whether a PayPal subscription notice is settled by sync_team_subscriptions alone, without the refunds and
    cancellations apps/profile/views.py paypal_webhooks makes for a new plan: the subscription is on a team plan, or
    the account owns a team that is paid for, so a plan bought meanwhile is a switch from the team's."""
    if Profile.paypal_plan(plan_id) in TEAM_PLANS:
        return True
    return Team.paid_for(datetime.datetime.now()).filter(owner_id=profile.user_id).exists()


def switch_start_time(profile, plan):
    """When a new PayPal subscription to plan starts (Profile.switch_paypal_subscription_approval_url), as PayPal's
    start_time: when the month already paid for ends, if PayPal bills the account's team and plan isn't above the
    team's, and otherwise None, for at once."""
    now = datetime.datetime.now()
    team = Team.paid_for(now).filter(owner_id=profile.user_id, billing_provider=Team.PROVIDER_PAYPAL).first()
    if not team or _above(plan, team.plan) or not team.paid_through or team.paid_through <= now:
        return None
    return datetime.datetime.utcfromtimestamp(team.paid_through.timestamp()).strftime("%Y-%m-%dT%H:%M:%SZ")


def refunded_sale_user(resource):
    """The account a refunded or reversed PayPal sale was for, from PayPal's own record of the sale and the
    subscription it billed, or None."""
    sale_id = resource.get("sale_id") or resource.get("id")
    if not sale_id:
        return None
    try:
        sale = Profile.paypal_app_api().get("/v1/payments/sale/%s" % sale_id)
    except PROVIDER_ERRORS as e:
        logging.debug(" ---> Couldn't read PayPal sale %s: %s" % (sale_id, e))
        return None
    subscription_id = sale.get("billing_agreement_id")
    if not subscription_id:
        return None
    user_ids = set(PaypalIds.objects.filter(paypal_sub_id=subscription_id).values_list("user_id", flat=True))
    if len(user_ids) != 1:
        return None
    return User.objects.filter(pk=user_ids.pop()).first()


def sync_team_subscriptions(profile, subscriptions):
    """Called by Profile.setup_premium_history with the account's PayPal subscriptions, each with its transactions,
    as PayPal reports them. A team subscription PayPal shows as paid hands its next billing time to
    record_team_payment, but only when this account bought it, and the first time it bills the team the
    subscriptions it replaces stop (_stop_replaced). One whose latest payment PayPal took back ends its team at once.
    A switch away from the team's plan waits for the month paid for (_settle_switch, _complete_switch). Returns True
    while a team plan decides the account's plan, so the caller reloads what these wrote and activates no other
    PayPal plan."""
    user = profile.user
    decides = False
    team_subscriptions = [
        (subscription, transactions)
        for subscription, transactions in subscriptions
        if Profile.paypal_plan(subscription.get("plan_id")) in TEAM_PLANS
    ]
    for subscription, transactions in sorted(team_subscriptions, key=lambda pair: _created(pair[0])):
        if subscription.get("status") in RENEWING_STATUSES:
            decides = True
        status, paid_through, paid_at = _paid_period(subscription, transactions)
        if status == "paid" and _bought_by(subscription, user):
            _apply_payment(profile, subscriptions, subscription, paid_through, paid_at)
        elif status == "paid":
            logging.user(
                user, "~FRPayPal team subscription %s was bought for another account" % subscription["id"]
            )
        elif status == "reversed" and _end_team_now(user, subscription, paid_at):
            decides = True
    if _settle_switch(profile, subscriptions) or _complete_switch(profile, subscriptions):
        decides = True
    return (
        decides
        or Team.objects.filter(
            owner=user, status=Team.STATUS_ACTIVE, billing_provider=Team.PROVIDER_PAYPAL
        ).exists()
    )


def _paid_period(subscription, transactions):
    """("paid", paid_through, paid_at) while PayPal shows the subscription active, with no failed payment
    outstanding and its latest payment completed. paid_at is when that payment was made and paid_through the next
    billing time, never more than a month (Profile.MONTHLY_PERIOD_DAYS) after the payment, which buys no more.
    ("reversed", None, when that payment was made) when PayPal took the latest payment back, refunded in full or
    reversed, and (None, None, None) otherwise."""
    payments = [payment for payment in transactions if payment.get("status") in PAYMENT_STATUSES]
    latest = max(
        payments, key=lambda payment: _time(payment.get("time")) or datetime.datetime.min, default=None
    )
    if not latest:
        return None, None, None
    if latest["status"] in TAKEN_BACK_STATUSES:
        return "reversed", None, _time(latest.get("time"))
    billing_info = subscription.get("billing_info") or {}
    paid_at = _time((billing_info.get("last_payment") or {}).get("time"))
    next_billing = _time(billing_info.get("next_billing_time"))
    outstanding = float((billing_info.get("outstanding_balance") or {}).get("value") or 0)
    if (
        subscription.get("status") != "ACTIVE"
        or billing_info.get("failed_payments_count")
        or outstanding
        or not paid_at
        or not next_billing
    ):
        return None, None, None
    return "paid", min(next_billing, paid_at + datetime.timedelta(days=Profile.MONTHLY_PERIOD_DAYS)), paid_at


def _apply_payment(profile, subscriptions, subscription, paid_through, paid_at):
    user = profile.user
    billed_before = Team.objects.filter(owner=user).values(
        "billing_provider", "billing_reference", "paid_through"
    )
    billed_before = billed_before.first() or {}
    starts_billing = (billed_before.get("billing_provider"), billed_before.get("billing_reference")) != (
        Team.PROVIDER_PAYPAL,
        subscription["id"],
    )
    replaced = _replaced(subscriptions, subscription, billed_before, paid_at) if starts_billing else []
    payment = record_team_payment(
        user,
        Profile.paypal_plan(subscription["plan_id"]),
        Team.PROVIDER_PAYPAL,
        paid_through,
        subscription["id"],
        paid_at,
        replaces_own_plan=any(
            Profile.paypal_plan(other.get("plan_id")) not in TEAM_PLANS for other, _ in replaced
        ),
    )
    now_billed = Team.objects.filter(
        owner=user, billing_provider=Team.PROVIDER_PAYPAL, billing_reference=subscription["id"]
    ).exists()
    if starts_billing and payment.reason is None and now_billed:
        _stop_replaced(profile, replaced, subscription)


def _replaced(subscriptions, subscription, billed_before, paid_at):
    """The account's other PayPal subscriptions a team subscription replaces once it bills the team, each with
    whether the unused part of its latest payment is refunded: the subscription that billed the team before, refunded
    unless its month was over by this payment, as at a switch down, and any made before this one that still renews,
    such as the plan the owner paid for on their own, which this purchase switched up from."""
    created = _created(subscription)
    replaced = []
    for other, _ in subscriptions:
        if other["id"] == subscription["id"]:
            continue
        if (billed_before.get("billing_provider"), billed_before.get("billing_reference")) == (
            Team.PROVIDER_PAYPAL,
            other["id"],
        ):
            month_left = bool(billed_before.get("paid_through")) and paid_at < billed_before["paid_through"]
            replaced.append((other, month_left))
        elif other.get("status") in RENEWING_STATUSES and _created(other) < created:
            replaced.append((other, True))
    return replaced


def _stop_replaced(profile, replaced, subscription):
    """Once a PayPal subscription bills the team, the unused part of the latest payment of each subscription it
    replaced is refunded where _replaced says so (Profile.refund_paypal_payment_from_subscription), and every Stripe
    and PayPal subscription made before it stops renewing at the end of its period without a refund, as a Stripe team
    purchase stops a PayPal one (apps/team/stripe_billing.py sync_stripe_event). Stopping retries until Stripe and
    PayPal confirm it (apps/team/tasks.py StopRenewalsMadeBefore). A refund PayPal refuses goes to staff."""
    user = profile.user
    refused = []
    for other, refund in replaced:
        if not refund:
            continue
        try:
            refunded = profile.refund_paypal_payment_from_subscription(other["id"], prorate=True)
        except PROVIDER_ERRORS as e:
            refunded = e
        if refunded is not None and not isinstance(refunded, int):
            refused.append("%s (%s)" % (other["id"], refunded))
    if refused:
        logging.user(user, "~FRCouldn't refund what a PayPal team subscription replaced: %s" % refused)
        _tell_staff(
            "team_paypal_refund_failed",
            "Plan replaced by a PayPal team not refunded: %s" % user.username,
            "%s's team is billed through PayPal subscription %s now, but the prorated refund of what it replaced "
            "failed: %s" % (user.username, subscription["id"], ", ".join(refused)),
        )
    _stop_renewals_made_before(user, subscription)


def _settle_switch(profile, subscriptions):
    """A subscription this account approved after the one that bills its team, on a plan not above the team's, is a
    switch to that plan once the month paid for ends (switch_start_time). Every subscription made before it, the
    team's own and any earlier switch, stops renewing without a refund, and Team.pending_plan shows what is coming. A
    switch between team plans bills the team from its first payment. A switch to a plan of the owner's own ends the
    team once the month has passed and PayPal has collected that plan's first payment (end_team_switched_down), and
    otherwise the hourly task ends the team (apps/team/tasks.py) and _complete_switch starts the plan once it is paid.
    Returns True when it ended the team."""
    user = profile.user
    team = Team.objects.filter(
        owner=user, status=Team.STATUS_ACTIVE, billing_provider=Team.PROVIDER_PAYPAL
    ).first()
    billing = team and _subscription(subscriptions, team.billing_reference)
    if not billing:
        return False
    switches = sorted(
        (
            (subscription, transactions)
            for subscription, transactions in subscriptions
            if subscription["id"] != billing["id"]
            and subscription.get("status") in RENEWING_STATUSES
            and _created(subscription) > _created(billing)
            and _bought_by(subscription, user)
            and Profile.paypal_plan(subscription.get("plan_id"))
            and not _above(Profile.paypal_plan(subscription.get("plan_id")), team.plan)
        ),
        key=lambda pair: _created(pair[0]),
    )
    target, target_transactions = switches[-1] if switches else (None, None)
    plan = Profile.paypal_plan(target["plan_id"]) if target else None
    Team.objects.filter(pk=team.pk).update(pending_plan=plan if plan != team.plan else None)
    if not target:
        return False

    if billing.get("status") in RENEWING_STATUSES or len(switches) > 1:
        _stop_renewals_made_before(user, target)
    if plan in TEAM_PLANS or _paid_period(target, target_transactions)[0] != "paid":
        return False
    with transaction.atomic():
        # paypal_billing.py: read again under the team's lock, so a payment that renewed it meanwhile keeps it.
        team = (
            Team.objects.select_for_update()
            .filter(pk=team.pk, status=Team.STATUS_ACTIVE, billing_reference=billing["id"])
            .first()
        )
        if not team or (team.paid_through and team.paid_through > datetime.datetime.now()):
            return False
        own_plan = end_team_switched_down(user, team, plan)
    logging.user(
        user, "~FCTeam %s ended on its PayPal switch down to %s, now on %s" % (team.pk, plan, own_plan)
    )
    return True


def _complete_switch(profile, subscriptions):
    """Finishes a switch down to a plan of the owner's own when the team ended before PayPal collected that plan, as
    the hourly task ends a team a day after its month. Once PayPal collects the plan's first payment the owner is on
    it, unless a plan of their own above it is still valid, and the team's pending plan is cleared so nothing of the
    switch stays on the team. Returns True when it finished the switch."""
    user = profile.user
    team = (
        Team.objects.filter(owner=user, status=Team.STATUS_INACTIVE, billing_provider=Team.PROVIDER_PAYPAL)
        .exclude(pending_plan__isnull=True)
        .exclude(pending_plan__in=TEAM_PLANS)
        .first()
    )
    billing = team and _subscription(subscriptions, team.billing_reference)
    if not billing:
        return False
    plan = team.pending_plan
    if not any(
        Profile.paypal_plan(subscription.get("plan_id")) == plan
        and _created(subscription) > _created(billing)
        and _bought_by(subscription, user)
        and _paid_period(subscription, transactions)[0] == "paid"
        for subscription, transactions in subscriptions
    ):
        return False
    with transaction.atomic():
        if not Team.objects.select_for_update().filter(pk=team.pk, pending_plan=plan).exists():
            return False
        own = Profile.objects.select_for_update().get(user=user)
        own_plan_valid = own.premium_expire is None or own.premium_expire > datetime.datetime.now()
        if not own_plan_valid or TeamProGrant.TIER_ORDER.index(plan) > TeamProGrant.TIER_ORDER.index(
            TeamProGrant.tier_of(own)
        ):
            Profile.objects.filter(pk=own.pk).update(**TeamProGrant.TIER_FLAGS[plan])
        Team.objects.filter(pk=team.pk).update(pending_plan=None)
    logging.user(user, "~FCTeam %s switch down to %s finished once PayPal collected it" % (team.pk, plan))
    return True


def _end_team_now(user, subscription, taken_back_at):
    """The team's payment was refunded in full or reversed. The team row is read again under its lock, so a refund
    of a subscription that no longer bills the team, or of a payment older than the one the team was last renewed
    by, ends nothing."""
    with transaction.atomic():
        team = (
            Team.objects.select_for_update()
            .filter(
                owner=user,
                status=Team.STATUS_ACTIVE,
                billing_provider=Team.PROVIDER_PAYPAL,
                billing_reference=subscription["id"],
            )
            .first()
        )
        # paypal_billing.py: PayPal's transaction and last payment times for one payment can differ a little.
        renewed_since = (
            team
            and team.last_payment_date
            and taken_back_at
            and team.last_payment_date > taken_back_at + datetime.timedelta(days=1)
        )
        if not team or renewed_since:
            return False
        end_team_now(team)
    logging.user(user, "~FRTeam %s ended: its PayPal payment was refunded or reversed" % team.pk)
    return True


def _stop_renewals_made_before(user, subscription):
    started_at = dateutil.parser.parse(subscription["create_time"]).timestamp()
    transaction.on_commit(lambda: StopRenewalsMadeBefore.delay(user_id=user.pk, started_at=started_at))


def stop_renewals_made_before(user, started_at):
    """Run by StopRenewalsMadeBefore (apps/team/tasks.py): every Stripe and PayPal subscription this account made
    before started_at, a Unix time, that still renews stops at the end of the period paid for, one at a time, since
    Profile.cancel_premium_paypal stops only the first it finds. The AI filter usage billing subscription keeps
    running (apps/team/grants.py renewing_subscriptions). Returns True once Stripe and PayPal confirm none of them
    renews. Errors from Stripe or PayPal reach the task, which retries."""
    renewing = renewing_subscriptions(user, started_at)
    if renewing is None:
        return False
    profile = Profile.objects.get(user=user)
    for provider, subscription_id in renewing:
        if provider == "stripe":
            profile.cancel_premium_stripe(subscription_ids=[subscription_id])
        else:
            profile.cancel_premium_paypal(force=True, subscription_ids=[subscription_id])
    if renewing:
        logging.user(user, "~FCStopped renewals made before a team subscription: %s" % renewing)
    return renewing_subscriptions(user, started_at) == []


def _subscription(subscriptions, subscription_id):
    return next(
        (subscription for subscription, _ in subscriptions if subscription["id"] == subscription_id), None
    )


def _above(plan, team_plan):
    return plan in TEAM_PLANS and TEAM_PLANS.index(plan) > TEAM_PLANS.index(team_plan)


def _bought_by(subscription, user):
    """Whether this account started the subscription. Its PayPal button and
    Profile.switch_paypal_subscription_approval_url set custom_id to the account's id, which a subscription another
    account pays for doesn't carry."""
    return str(subscription.get("custom_id") or "") == str(user.pk)


def _created(subscription):
    return _time(subscription.get("create_time")) or datetime.datetime.min


def _time(paypal_time):
    """A PayPal time, which is UTC, as a naive local time like datetime.datetime.now(), or None."""
    if not paypal_time:
        return None
    return datetime.datetime.fromtimestamp(dateutil.parser.parse(paypal_time).timestamp())


def _tell_staff(event_type, subject, body):
    transaction.on_commit(
        lambda: EmailStaffNotification.delay(event_type=event_type, subject=subject, body=body)
    )
