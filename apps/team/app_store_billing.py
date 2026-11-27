"""Team plans billed through the App Store, on iOS and macOS. apps/profile/apple_subscriptions.py hands this module a
transaction, a refund or the renewal info Apple signed, only once the signature is verified
(apps/profile/apple_notifications.py) and the transaction is matched to its account, so a team starts, renews, comes
back, switches or ends only on what Apple itself reports (apps/team/billing.py record_team_payment).

Apple keeps every NewsBlur plan in one subscription group, billed as one subscription per Apple ID, whose original
transaction id is the team's billing reference. An upgrade to a team plan, or from Premium Team to Enterprise, takes
effect at once. A switch down renews into the lower plan once the month already paid for ends."""

import datetime

from django.db import transaction
from django.db.models import Q

from apps.profile.models import PaymentHistory, Profile
from apps.team.billing import (
    end_team_now,
    end_team_switched_down,
    finish_switch_down,
    record_team_payment,
)
from apps.team.models import Team
from apps.team.stripe_billing import TEAM_PLANS
from apps.team.tasks import StopRenewalsMadeBefore
from utils import log as logging


def bills_team(user_id):
    """Whether the App Store bills this account's team, and the team is paid for."""
    return (
        Team.paid_for(datetime.datetime.now())
        .filter(owner_id=user_id, billing_provider=Team.PROVIDER_APP_STORE)
        .exists()
    )


def record_app_store_payment(user, plan, original_transaction_id, purchased_at, expires_at, sandbox=False):
    """A verified App Store transaction for a team plan, for the first purchase or a renewal: Apple's expiry date is
    the paid through date, its purchase date when the payment was made, and the subscription's original transaction
    id the reference. When this moves the team's billing to the App Store, every Stripe and PayPal subscription the
    account made before the purchase stops renewing, as when Stripe or PayPal starts billing a team
    (apps/team/tasks.py StopRenewalsMadeBefore). A sandbox purchase costs nothing, so it stops none of them. A
    store subscription can't be stopped from here, so record_team_payment tells staff when one billed the team
    before."""
    billed_before = _billing(user.pk)
    payment = record_team_payment(
        user,
        plan,
        Team.PROVIDER_APP_STORE,
        expires_at,
        original_transaction_id,
        purchased_at,
        replaces_own_plan=_replaces_own_plan(user, original_transaction_id, purchased_at),
    )
    billed_here = (Team.PROVIDER_APP_STORE, original_transaction_id)
    moved_here = _billing(user.pk) == billed_here and billed_before != billed_here
    if payment.reason is None and moved_here and not sandbox:
        started_at = purchased_at.timestamp()
        transaction.on_commit(lambda: StopRenewalsMadeBefore.delay(user_id=user.pk, started_at=started_at))
    return payment


def _billing(user_id):
    return Team.objects.filter(owner_id=user_id).values_list("billing_provider", "billing_reference").first()


def _replaces_own_plan(user, original_transaction_id, purchased_at):
    """Whether this team purchase upgraded a plan the owner pays for on their own in the App Store with the same Apple
    ID: a plan of theirs in this subscription was still paid for when the team plan was bought. Apple credits what was
    left of it toward the team plan, so there is no plan of their own to go back to once the team ends."""
    year_before = purchased_at - datetime.timedelta(days=Profile.ANNUAL_PERIOD_DAYS)
    still_paid = Q(apple_expires_date__gt=purchased_at) | Q(
        apple_expires_date__isnull=True, payment_date__gt=year_before
    )
    return (
        PaymentHistory.objects.filter(
            Q(apple_original_transaction_id=original_transaction_id)
            | Q(payment_identifier=original_transaction_id),
            still_paid,
            user=user,
            payment_provider__startswith="ios-",
            payment_date__lt=purchased_at,
        )
        .exclude(plan__in=TEAM_PLANS)
        .exclude(refunded=True)
        .exists()
    )


def switched_down_team(user_id, original_transaction_id, purchased_at, plan):
    """The account's team whose App Store subscription a transaction for plan, one of the owner's own, switched down
    from, or None. Apple billed the team through the same subscription, and the transaction was bought after the
    team's newest payment, as Apple renews a switch down into the lower plan once the month paid for ends. A team that
    has lapsed counts only while plan is the switch it was waiting for (Team.pending_plan)."""
    team = Team.objects.filter(
        owner_id=user_id,
        billing_provider=Team.PROVIDER_APP_STORE,
        billing_reference=original_transaction_id,
        last_payment_date__lt=purchased_at,
    ).first()
    if team and team.status != Team.STATUS_ACTIVE and team.pending_plan != plan:
        return None
    return team


def settle_switch_down(user, original_transaction_id, plan):
    """Called once the transaction switched_down_team found has been applied as a plan of the owner's own. The team
    ends when its paid month is over, with the owner on plan (apps/team/billing.py end_team_switched_down), or finishes
    the switch its lapse was waiting for (finish_switch_down). Until the month is over Team.pending_plan shows plan,
    and the hourly task ends the team a day after it, when the owner goes back to plan as theirs
    (apps/team/grants.py release_team_pro)."""
    team, own_plan = end_team_switched_down(user, Team.PROVIDER_APP_STORE, original_transaction_id, plan)
    if team:
        logging.user(
            user, "~FCTeam %s ended on its App Store switch down to %s, now on %s" % (team.pk, plan, own_plan)
        )
        return
    if finish_switch_down(user, Team.PROVIDER_APP_STORE, original_transaction_id, plan):
        logging.user(user, "~FCTeam switch down to %s finished once the App Store collected it" % plan)
        return
    Team.objects.filter(
        owner=user,
        status=Team.STATUS_ACTIVE,
        billing_provider=Team.PROVIDER_APP_STORE,
        billing_reference=original_transaction_id,
    ).update(pending_plan=plan)


def record_pending_plan(original_transaction_id, plan):
    """Team.pending_plan for the active team the App Store bills through this subscription, from the renewal info
    Apple signed: plan, the one Apple renews the subscription into once the month paid for ends, when the owner switched
    down to it, or None when it renews on the team's plan or not at all."""
    team = Team.objects.filter(
        status=Team.STATUS_ACTIVE,
        billing_provider=Team.PROVIDER_APP_STORE,
        billing_reference=original_transaction_id,
    ).first()
    if not team or not original_transaction_id:
        return
    Team.objects.filter(pk=team.pk).update(pending_plan=plan if plan != team.plan else None)


def end_refunded_team(transaction_id, original_transaction_id, purchased_at):
    """Apple refunded or revoked a payment for a team plan, the transaction bought at purchased_at. The payment is
    recorded as refunded, and the team the App Store bills through that subscription ends at once, unless a newer
    payment renewed it since (apps/team/billing.py end_team_now). Returns the team it ended, or None."""
    team = (
        Team.objects.filter(
            billing_provider=Team.PROVIDER_APP_STORE, billing_reference=original_transaction_id
        )
        .select_related("owner")
        .first()
    )
    if not team or not team.owner or not original_transaction_id:
        return None
    PaymentHistory.objects.filter(
        user=team.owner,
        payment_identifier=transaction_id,
        apple_original_transaction_id=original_transaction_id,
    ).update(refunded=True)
    ended = end_team_now(team.owner, Team.PROVIDER_APP_STORE, original_transaction_id, purchased_at)
    if ended:
        logging.user(team.owner, "~FRTeam %s ended: its App Store payment was refunded or revoked" % ended.pk)
    return ended
