"""Team plans billed through Stripe. Every Stripe event ends in Profile.setup_premium_history, which reads the
account's subscriptions from Stripe and hands them to sync_team_subscriptions here, so a team starts, renews, comes
back or ends only on what Stripe itself reports (apps/team/billing.py record_team_payment). Switching down from a
team plan waits for the end of the month already paid for, through a Stripe subscription schedule."""

import datetime

import stripe
from django.conf import settings
from django.db import transaction

from apps.profile.models import PaymentHistory, Profile
from apps.team.billing import (
    end_team_now,
    end_team_switched_down,
    finish_switch_down,
    record_team_payment,
)
from apps.team.models import Team, TeamMember
from apps.team.tasks import StopRenewalsMadeBefore
from utils import log as logging

# stripe_billing.py: lowest first. Every other plan is below both.
TEAM_PLANS = (Team.PLAN_TEAM, Team.PLAN_TEAM_ENTERPRISE)
# stripe_billing.py: the metadata key on a custom Stripe price staff make for a team with more seats, whose value
# names the team plan the price is for (price_plan).
TEAM_PLAN_METADATA_KEY = "newsblur_plan"


def price_plan(price):
    """The plan a Stripe price is for, as Profile.stripe_price_plan names it. A custom price staff made for a team with
    more seats names its team plan in its metadata, and bills that team as the plan's own price does. price is a price
    or plan object as Stripe's API or an event gives it, or None."""
    if not price:
        return None
    plan = Profile.stripe_price_plan(price.get("id"))
    named = (price.get("metadata") or {}).get(TEAM_PLAN_METADATA_KEY)
    return plan or (named if named in TEAM_PLANS else None)


def subscription_plan(subscription):
    """The plan a Stripe subscription is on (price_plan): its first item's price, which carries the price's metadata,
    or its top level plan."""
    items = (subscription.get("items") or {}).get("data") or []
    return price_plan(items[0].get("price") if items else None) or price_plan(subscription.get("plan"))


def team_purchase_refusal(user, provider=Team.PROVIDER_STRIPE):
    """Why this account can't buy a team plan through provider, or None. Someone holding a seat on another person's
    team is on one team already, unless its owner asked them to take it over (Team.request_transfer): buying its plan
    with any provider is how they accept, except for a comp, which has nothing to pay. A team another provider bills,
    or staff comp, is already paid for there. An owner whose team the same provider bills switches between the two
    team plans."""
    membership = TeamMember.active_membership(user)
    if membership and membership.team.owner_id != user.pk:
        if not membership.team.transfer_waits_for(user):
            return "on_team"
        if membership.team.is_comped:
            return "team_comped"
        return None
    if Team.paid_for(datetime.datetime.now()).filter(owner=user).exclude(billing_provider=provider).exists():
        return "team_billed_elsewhere"
    return None


def is_team_subscription(profile, subscription):
    """Whether a Stripe subscription event, given the subscription as the event holds it, is a team plan's: the
    subscription is on a team price (subscription_plan), or it is the one that bills the account's team, which a
    switch down moves to a lower plan."""
    if subscription_plan(subscription) in TEAM_PLANS:
        return True
    subscription_id = subscription.get("id")
    return bool(subscription_id) and _team_billed_by(profile.user_id, subscription_id).exists()


def sync_stripe_event(profile):
    """What a Stripe subscription or payment event runs. When the sync moves the team's billing to a Stripe
    subscription, every Stripe and PayPal subscription the account made before that payment stops renewing, the web
    subscription that billed the team before and the owner's own plan, as when a PayPal subscription starts billing
    the team (apps/team/paypal_billing.py). Stopping retries until Stripe and PayPal confirm it, and staff are told
    when they can't (apps/team/tasks.py StopRenewalsMadeBefore)."""
    before = _team_billing(profile.user_id)
    profile.setup_premium_history()
    after = _team_billing(profile.user_id)
    if not after or after[0] != Team.PROVIDER_STRIPE or not after[1] or after[:2] == (before or ())[:2]:
        return
    user_id, subscription_id = profile.user_id, after[1]
    started_at = (after[2] or datetime.datetime.now()).timestamp()
    transaction.on_commit(
        lambda: StopRenewalsMadeBefore.delay(user_id=user_id, started_at=started_at, kept_id=subscription_id)
    )


def sync_team_subscriptions(profile, subscriptions):
    """Called by Profile.setup_premium_history with one Stripe customer's subscriptions. A team subscription Stripe
    shows as paid hands its period end to record_team_payment, one whose payment was refunded in full or disputed
    ends its team at once, and the team's subscription moved off a team plan by a switch down ends the team once its
    paid month is over. Returns True when a team plan decides the account's plan, so the caller reloads what these
    wrote and doesn't start Premium from a team's payment."""
    team_billed = False
    for subscription in subscriptions:
        plan = subscription_plan(subscription)
        if plan in TEAM_PLANS:
            team_billed = True
            _apply_team_subscription(profile.user, subscription, plan)
        elif plan and _end_team_switched_down(profile.user, subscription, plan):
            team_billed = True
    return team_billed


def switch_team_subscription(profile, subscription, plan):
    """Profile.switch_stripe_subscription's switch of the subscription that bills the owner's team. A switch
    already scheduled is dropped first. A switch down from a team plan, Enterprise to Team included, waits for the end
    of the month already paid for. Returns True once the switch is made, or False for the caller to switch at once
    with proration, as for any plan."""
    if not _team_billed_by(profile.user_id, subscription.id).exists():
        return False
    current_plan = subscription_plan(subscription)
    release_schedule(subscription)
    if plan == current_plan:
        return True
    if current_plan not in TEAM_PLANS or (
        plan in TEAM_PLANS and TEAM_PLANS.index(plan) > TEAM_PLANS.index(current_plan)
    ):
        return False
    _schedule_switch(subscription, Profile.plan_to_stripe_price(plan))
    logging.user(
        profile.user,
        "~FCTeam plan switches from %s to %s at the end of the paid month" % (current_plan, plan),
    )
    return True


def release_schedule(subscription):
    """Stripe refuses to change or cancel a subscription a schedule manages, so a scheduled switch down is dropped
    first. The subscription stays on the plan it is on."""
    schedule_id = subscription.get("schedule")
    if isinstance(schedule_id, str):
        stripe.SubscriptionSchedule.release(schedule_id)


def refund_unused_month(user, subscription_id, at):
    """Refunds, on the charge a team's Stripe subscription last made, what is left after at of the period that charge
    paid for, prorated over that period, as when its owner hands the team on (apps/team/billing.py
    settle_former_owners_plan). Profile.refund_prorated_stripe_payment prorates the account's latest charge over a
    year instead. What was refunded on the charge already counts toward it. Returns the dollars refunded, or None when
    Stripe shows nothing paid that is left to refund. Errors from Stripe reach the caller."""
    stripe.api_key = settings.STRIPE_SECRET
    status, _, invoice = _paid_period(stripe.Subscription.retrieve(subscription_id))
    charge = invoice.get("charge") if status == "paid" else None
    period = _charged_period(invoice) if charge else None
    if not period or period[1] <= at:
        return None
    start, end = period
    cents = int(charge["amount"] * ((end - at) / (end - start))) - (charge.get("amount_refunded") or 0)
    if cents <= 0:
        return None
    refund = stripe.Refund.create(charge=charge["id"], amount=cents)
    dollars = cents / 100.0
    PaymentHistory.objects.create(
        user=user,
        payment_date=datetime.datetime.now(),
        payment_amount=-int(round(dollars)),
        payment_provider="stripe",
        payment_identifier=refund.id,
        refunded=True,
    )
    logging.user(
        user, "~FRRefunded the unused month of team subscription %s: $%.2f" % (subscription_id, dollars)
    )
    return dollars


def _charged_period(invoice):
    """(start, end) of the service period an invoice charged for, from its first line that charged anything, as
    Profile.stripe_payment_period reads it."""
    for line in (invoice.get("lines") or {}).get("data") or []:
        period = line.get("period") or {}
        if (line.get("amount") or 0) > 0 and period.get("start") and period.get("end"):
            return datetime.datetime.fromtimestamp(period["start"]), datetime.datetime.fromtimestamp(
                period["end"]
            )
    return None


def _team_billing(user_id):
    return (
        Team.objects.filter(owner_id=user_id)
        .values_list("billing_provider", "billing_reference", "last_payment_date")
        .first()
    )


def _team_billed_by(user_id, subscription_id):
    return Team.objects.filter(
        owner_id=user_id, billing_provider=Team.PROVIDER_STRIPE, billing_reference=subscription_id
    )


def _apply_team_subscription(user, subscription, plan):
    team = Team.objects.filter(owner=user).first()
    winding_down = subscription.get("cancel_at_period_end") or subscription.get("cancel_at")
    if winding_down and team and team.billing_reference and team.billing_reference != subscription.id:
        # stripe_billing.py: a subscription set to end doesn't take the team back from the one that bills it now.
        return
    status, paid_through, invoice = _paid_period(subscription)
    if status == "paid":
        paid_at = (invoice.get("status_transitions") or {}).get("paid_at")
        # stripe_billing.py: a subscription that starts billing the team on an invoice for changing it was the
        # owner's own plan, switched to the team plan with proration (Profile.switch_stripe_subscription).
        replaces_own_plan = invoice.get("billing_reason") == "subscription_update" and (
            not team or team.billing_reference != subscription.id
        )
        record_team_payment(
            user,
            plan,
            Team.PROVIDER_STRIPE,
            paid_through,
            subscription.id,
            datetime.datetime.fromtimestamp(paid_at) if paid_at else None,
            replaces_own_plan=replaces_own_plan,
        )
    elif status == "reversed":
        _end_team_now(user, subscription, invoice)
    _team_billed_by(user.pk, subscription.id).update(pending_plan=_scheduled_plan(subscription))


def _paid_period(subscription):
    """("paid", the end of the period paid for, the latest invoice) while the subscription is active and its
    latest invoice is paid. Stripe starts a renewal's period before charging it, and a renewal it couldn't charge
    is past due, so neither counts. ("reversed", None, the invoice) when the latest invoice's charge was refunded
    in full or disputed, and (None, None, None) otherwise."""
    if subscription.get("status") != "active" or not subscription.get("latest_invoice"):
        return None, None, None
    invoice = stripe.Invoice.retrieve(subscription["latest_invoice"], expand=["charge"])
    if invoice.get("status") != "paid":
        return None, None, None
    charge = invoice.get("charge")
    if charge and (charge.get("refunded") or charge.get("disputed")):
        return "reversed", None, invoice
    period_end = subscription.get("current_period_end")
    if not period_end:
        # stripe_billing.py: newer Stripe API versions keep the period on each subscription item.
        items = (subscription.get("items") or {}).get("data") or []
        period_end = items[0].get("current_period_end") if items else None
    if not period_end:
        return None, None, None
    return "paid", datetime.datetime.fromtimestamp(period_end), invoice


def _end_team_now(user, subscription, invoice):
    """The latest invoice's payment was refunded in full or disputed, which ends the team the subscription bills
    (apps/team/billing.py end_team_now)."""
    paid_at = (invoice.get("status_transitions") or {}).get("paid_at")
    team = end_team_now(
        user,
        Team.PROVIDER_STRIPE,
        subscription.id,
        datetime.datetime.fromtimestamp(paid_at) if paid_at else None,
    )
    if team:
        logging.user(user, "~FRTeam %s ended: its Stripe payment was refunded or disputed" % team.pk)


def _end_team_switched_down(user, subscription, plan):
    """The team's own subscription is on a lower plan now, one of the owner's own, as a switch down leaves it once
    the month paid for ends. The team ends then, and the owner is on that plan once Stripe has collected its first
    payment, or on a higher one of their own they had besides (apps/team/billing.py end_team_switched_down). A plan
    Stripe collects only after the team ended starts then (finish_switch_down). Returns True when it ended the team or
    started the plan."""
    if not _team_billed_by(user.pk, subscription.id).exists():
        return False
    plan_paid = _paid_period(subscription)[0] == "paid"
    team, own_plan = end_team_switched_down(user, Team.PROVIDER_STRIPE, subscription.id, plan, plan_paid)
    if team:
        logging.user(user, "~FCTeam %s ended on its switch down to %s, now on %s" % (team.pk, plan, own_plan))
        return True
    if plan_paid and finish_switch_down(user, Team.PROVIDER_STRIPE, subscription.id, plan):
        logging.user(user, "~FCTeam switch down to %s finished once Stripe collected it" % plan)
        return True
    return False


def _scheduled_plan(subscription):
    """The plan a scheduled switch down moves the subscription to once its current phase ends, or None."""
    schedule_id = subscription.get("schedule")
    if not schedule_id:
        return None
    schedule = stripe.SubscriptionSchedule.retrieve(schedule_id)
    current_end = (schedule.get("current_phase") or {}).get("end_date")
    for phase in schedule.get("phases") or []:
        if current_end and phase.get("start_date", 0) >= current_end:
            return Profile.stripe_price_plan(_phase_price_id(phase["items"][0]))
    return None


def _phase_price_id(item):
    price = item.get("price")
    return price if isinstance(price, str) else price.get("id")


def _schedule_switch(subscription, target_price):
    """The current phase runs to the end of the period already paid for, then the lower price starts and the
    subscription carries on without the schedule."""
    if subscription.get("cancel_at_period_end"):
        stripe.Subscription.modify(subscription.id, cancel_at_period_end=False)
    schedule = stripe.SubscriptionSchedule.create(from_subscription=subscription.id)
    current = schedule["phases"][0]
    stripe.SubscriptionSchedule.modify(
        schedule.id,
        end_behavior="release",
        proration_behavior="none",
        phases=[
            {
                "items": [
                    {"price": _phase_price_id(item), "quantity": item.get("quantity") or 1}
                    for item in current["items"]
                ],
                "start_date": current["start_date"],
                "end_date": current["end_date"],
            },
            {
                "items": [{"price": target_price, "quantity": 1}],
                "iterations": 1,
                "proration_behavior": "none",
            },
        ],
    )
