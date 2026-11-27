"""Team plans billed through Stripe. Every Stripe event ends in Profile.setup_premium_history, which reads the
account's subscriptions from Stripe and hands them to sync_team_subscriptions here, so a team starts, renews, comes
back or ends only on what Stripe itself reports (apps/team/billing.py record_team_payment). Switching down from a
team plan waits for the end of the month already paid for, through a Stripe subscription schedule."""

import datetime

import stripe

from apps.profile.models import Profile
from apps.team.billing import end_team_now, end_team_switched_down, record_team_payment
from apps.team.models import Team, TeamMember
from utils import log as logging

# stripe_billing.py: lowest first. Every other plan is below both.
TEAM_PLANS = (Team.PLAN_TEAM, Team.PLAN_TEAM_ENTERPRISE)


def team_purchase_refusal(user, provider=Team.PROVIDER_STRIPE):
    """Why this account can't buy a team plan on the web through provider, Stripe or PayPal, or None. Someone
    holding a seat on another person's team is on one team already, and a team another provider bills, or staff
    comp, is already paid for there. An owner whose team the same provider bills switches between the two team
    plans."""
    membership = TeamMember.active_membership(user)
    if membership and membership.team.owner_id != user.pk:
        return "on_team"
    if Team.paid_for(datetime.datetime.now()).filter(owner=user).exclude(billing_provider=provider).exists():
        return "team_billed_elsewhere"
    return None


def is_team_subscription(profile, subscription_id, price_id):
    """Whether a Stripe subscription event is a team plan's: the subscription is on a team price, or it is the
    one that bills the account's team, which a switch down moves to a lower plan."""
    if Profile.stripe_price_plan(price_id) in TEAM_PLANS:
        return True
    return bool(subscription_id) and _team_billed_by(profile.user_id, subscription_id).exists()


def sync_stripe_event(profile):
    """What a Stripe subscription or payment event runs. When the sync moves the team's billing to a Stripe
    subscription, the web subscription that billed the team before, or the owner's own PayPal plan, stops renewing,
    as when an account moves between Stripe and PayPal."""
    before = _team_billing(profile.user_id)
    profile.setup_premium_history()
    after = _team_billing(profile.user_id)
    if not after or after[0] != Team.PROVIDER_STRIPE or after == before:
        return
    if before and before[0] == Team.PROVIDER_STRIPE:
        profile.cancel_premium_stripe(subscription_ids=[before[1]])
    elif profile.paypal_sub_id:
        profile.cancel_premium_paypal()


def sync_team_subscriptions(profile, subscriptions):
    """Called by Profile.setup_premium_history with one Stripe customer's subscriptions. A team subscription Stripe
    shows as paid hands its period end to record_team_payment, one whose payment was refunded in full or disputed
    ends its team at once, and the team's subscription moved off a team plan by a switch down ends the team once its
    paid month is over. Returns True when a team plan decides the account's plan, so the caller reloads what these
    wrote and doesn't start Premium from a team's payment."""
    team_billed = False
    for subscription in subscriptions:
        plan = Profile.stripe_price_plan(_price_id(subscription))
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
    current_plan = Profile.stripe_price_plan(_price_id(subscription))
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


def _team_billing(user_id):
    return Team.objects.filter(owner_id=user_id).values_list("billing_provider", "billing_reference").first()


def _team_billed_by(user_id, subscription_id):
    return Team.objects.filter(
        owner_id=user_id, billing_provider=Team.PROVIDER_STRIPE, billing_reference=subscription_id
    )


def _price_id(subscription):
    """As Profile.setup_premium_history reads it: the top level plan, or the first item's."""
    plan = subscription.plan
    if not plan:
        items = subscription.get("items")
        if items and items.data:
            plan = items.data[0].plan
    return plan.id if plan else None


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
        _end_team_now(user, subscription)
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


def _end_team_now(user, subscription):
    team = _team_billed_by(user.pk, subscription.id).filter(status=Team.STATUS_ACTIVE).first()
    if not team:
        return
    end_team_now(team)
    logging.user(user, "~FRTeam %s ended: its Stripe payment was refunded or disputed" % team.pk)


def _end_team_switched_down(user, subscription, plan):
    """The team's own subscription is on a lower plan now. Once the month paid for has passed, the team ends and the
    owner is on that plan, or on a higher one of their own they had besides (release_team_pro). Returns True when it
    ended the team."""
    team = _team_billed_by(user.pk, subscription.id).filter(status=Team.STATUS_ACTIVE).first()
    if not team or (team.paid_through and team.paid_through > datetime.datetime.now()):
        return False
    own_plan = end_team_switched_down(user, team, plan)
    logging.user(user, "~FCTeam %s ended on its switch down to %s, now on %s" % (team.pk, plan, own_plan))
    return True


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
