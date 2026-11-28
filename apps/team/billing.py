"""Team billing: where a confirmed payment for a team plan lands, whichever provider took it. The team is its
owner's account, so a team plan is a plan on the owner's own Profile (apps/team/models.py Team)."""

import datetime
from typing import NamedTuple, Optional

from django.db import transaction
from django.utils.translation import gettext

from apps.profile.models import PaymentHistory, Profile
from apps.profile.tasks import EmailStaffNotification, EmailStaffPremiumUpgrade
from apps.team.grants import (
    activate_team,
    deactivate_team,
    grant_team_pro,
    release_team_pro,
    seat_grant_for_former_owner,
)
from apps.team.models import Team, TeamActivity, TeamMember, TeamProGrant
from apps.team.tasks import (
    EmailTeamNewOwner,
    EmailTeamWelcome,
    SettleHandOver,
    StopRenewalsMadeBefore,
)
from utils import log as logging
from utils.languages import account_translation


class TeamPayment(NamedTuple):
    """What record_team_payment did. reason is None when the payment was applied, and otherwise says why it
    changed nothing or only part: "on_team", "no_paid_through", "no_paid_at", "comped" or "lapsed"."""

    team: Optional[Team]
    reason: Optional[str] = None
    created: bool = False
    reactivated: bool = False


def record_team_payment(user, plan, provider, paid_through, reference, paid_at, replaces_own_plan=False):
    """Apply a payment for a team plan that the provider has confirmed. Every provider calls this, for the first
    purchase and for every renewal, and calling it again for the same payment changes nothing more.

    The buyer's team is started on the first payment, with a default name the owner is then asked to replace,
    and comes back if it had lapsed. The plan, provider and reference are the newest payment's, so a team paid
    for in two places is billed by the newest purchase, and staff are told. The owner holds Premium Pro through
    a team grant, without Profile.activate_pro's emails (_give_owner_pro).

    reference is the provider's id that stays the same across renewals: the Stripe or PayPal subscription id,
    Apple's original transaction id, or the Play purchase token.

    paid_at is when the provider says this payment was made: the paid time of a Stripe invoice, the time of a
    PayPal sale, Apple's purchase date for the transaction, or Play's start time for the order. It decides which
    payment is newest, so an older one arriving late or again can't change the plan, provider or reference a
    newer one set. Staff comps pass the moment they are made.

    paid_through only moves forward. A paid provider has to give one, or the payment changes nothing and staff
    are told. Only provider "comp" with an empty paid_through makes a team never lapse, and a team comped that
    way stays comped: a later payment from any provider changes nothing on it, and staff are told when a
    provider charged for it.

    A payment that leaves the team's paid period lapsed by Team.lapsed's rule is recorded on a team that exists,
    but starts no team, brings none back and gives no one Pro.

    replaces_own_plan is True when this purchase replaced a plan the owner paid for on their own with the same
    provider and credited what was left of it: a Stripe switch with proration, an App Store upgrade within the
    subscription group, a Play subscription replaced with proration. The owner then has no plan of their own to
    go back to when the team ends.

    The teammate a team's owner asked to take it over pays for it this way too, and their payment hands them the
    team (_hand_over_on_payment).

    Someone holding a seat on another team gets no team of their own and nothing on their account changes. Staff
    are told, since the provider has already taken the payment, unless the buyer handed that team on themselves:
    the payment is then the subscription they paid for it with as its owner, which the hand over settled
    (settle_former_owners_plan)."""
    if plan not in dict(Team.PLAN_CHOICES) or provider not in dict(Team.PROVIDER_CHOICES):
        raise ValueError("Unknown team plan %r or provider %r" % (plan, provider))
    missing_date = None
    if provider != Team.PROVIDER_COMP and not paid_through:
        missing_date = "no_paid_through"
    elif not paid_at:
        missing_date = "no_paid_at"
    if missing_date:
        _tell_staff(
            "team_payment_without_date",
            "Team payment without a date: %s" % user.username,
            "%s paid for %s through %s (%s), but its paid through date or the time it was paid didn't come with "
            "it, so the team was not changed." % (user.username, plan, provider, reference),
        )
        return TeamPayment(None, missing_date)

    now = datetime.datetime.now()
    with transaction.atomic():
        handed_over = _hand_over_on_payment(
            user, plan, provider, paid_through, reference, paid_at, replaces_own_plan, now
        )
        if handed_over:
            return handed_over
        team, created, reason = _owners_team(user, plan, Team.period_lapsed(paid_through, now))
        if team:
            return _apply_payment(
                team, user, plan, provider, paid_through, reference, paid_at, replaces_own_plan, created, now
            )
    if reason == "on_team" and not _handed_on_their_team(user):
        _tell_staff_buyer_is_on_a_team(user, plan, provider, reference)
    return TeamPayment(None, reason)


def _hand_over_on_payment(user, plan, provider, paid_through, reference, paid_at, replaces_own_plan, now):
    """A payment from the teammate a team's owner asked to take it over, while the request waits for them
    (Team.request_transfer), hands them the team (_hand_over). The team's plan and billing become this payment's,
    its paid through date included: this is the one payment that may move paid_through back, since the period before
    it was the old owner's, paid on their own subscription, whose unused part is refunded
    (settle_former_owners_plan). A comp has nothing to pay for, so a payment for one hands nothing over and staff are
    told, and one for a period that has already lapsed hands nothing over either. Returns what the payment did, or
    None when it is no such payment."""
    membership = TeamMember.active_membership(user)
    if not membership or membership.team.pending_owner_id != user.pk:
        return None
    team = membership.team.lock()
    if not team.transfer_waits_for(user, now):
        return None
    if team.is_comped:
        _tell_staff(
            "team_comp_paid",
            "Payment for a comped team: %s" % user.username,
            "%s paid for %s through %s (%s) to take over %s, but it is comped with no end, so it has nothing to pay "
            "and the team was not changed." % (user.username, plan, provider, reference, team.name),
        )
        return TeamPayment(None, "comped")
    if Team.period_lapsed(paid_through, now):
        return TeamPayment(None, "lapsed")

    grant = TeamProGrant.objects.filter(user=user).first()
    previous_tier = grant.own_tier if grant else TeamProGrant.tier_of(Profile.objects.get(user=user))
    former_billing = (team.billing_provider, team.billing_reference)
    reactivated = team.status == Team.STATUS_INACTIVE
    team.plan = plan
    team.billing_provider = provider
    team.billing_reference = reference
    team.last_payment_date = paid_at
    team.paid_through = paid_through
    if not _hand_over(team, user, paid_through, replaces_own_plan, former_billing, now):
        return None
    transaction.on_commit(
        lambda: EmailStaffPremiumUpgrade.delay(user_id=user.pk, tier=plan, previous_tier=previous_tier)
    )
    logging.user(
        user,
        "~FM~SBTeam %s payment~SN: %s through %s (%s), taking it over%s"
        % (team.pk, plan, provider, paid_through, ", reactivated" if reactivated else ""),
    )
    return TeamPayment(team, None, False, reactivated)


def accept_comped_transfer(user, team_id):
    """The teammate a comped team's owner asked to take it over accepts, with nothing to pay, and the team changes
    hands at once and stays comped (_hand_over). A team that is paid for changes hands only on its new owner's payment
    (record_team_payment). Returns a failure reason or None."""
    now = datetime.datetime.now()
    with transaction.atomic():
        team = Team.objects.select_for_update().filter(pk=team_id).first()
        if not team or not team.transfer_waits_for(user, now):
            return "no_transfer"
        if not team.is_comped:
            return "transfer_needs_payment"
        if team.status != Team.STATUS_ACTIVE:
            return "team_inactive"
        former_billing = (team.billing_provider, team.billing_reference)
        if not _hand_over(team, user, None, False, former_billing, now):
            return "not_found"
    return None


def _hand_over(team, new_owner, paid_through, replaces_own_plan, former_billing, now):
    """Hands the locked team to new_owner, the teammate its owner asked to take it over, in one transaction. The old
    owner becomes a manager and keeps their seat, the new owner's grant becomes an owner's (_owner_grant_from_seat)
    and the old owner's a teammate's (seat_grant_for_former_owner), and no grant is released, so nobody's Premium Pro
    or sites change on the way. A team that had lapsed comes back. Once it commits, the old owner's subscription for
    the team, former_billing, is settled (settle_former_owners_plan) and both of them are emailed. Returns the team, or
    None when either seat is gone and nothing was changed."""
    seats = TeamMember.objects.select_related("user").filter(team=team, status=TeamMember.STATUS_ACTIVE)
    old_seat = seats.filter(user_id=team.owner_id, role=TeamMember.ROLE_OWNER).first()
    new_seat = seats.filter(user=new_owner).exclude(role=TeamMember.ROLE_OWNER).first()
    if not old_seat or not new_seat:
        return None
    old_owner = old_seat.user
    reactivated = team.status == Team.STATUS_INACTIVE
    if not reactivated:
        seat_grant_for_former_owner(old_owner, held_as_owner=True)

    old_seat.role = TeamMember.ROLE_MANAGER
    old_seat.save(update_fields=["role"])
    new_seat.role = TeamMember.ROLE_OWNER
    new_seat.save(update_fields=["role"])
    team.owner = new_owner
    team.pending_owner = None
    team.transfer_requested_date = None
    # billing.py: a switch down the old owner scheduled was on their own subscription.
    team.pending_plan = None
    team.save(
        update_fields=[
            "owner",
            "pending_owner",
            "transfer_requested_date",
            "pending_plan",
            "plan",
            "billing_provider",
            "billing_reference",
            "last_payment_date",
            "paid_through",
            "updated_date",
        ]
    )
    TeamActivity.log(
        team, old_owner, "ownership_transferred", user_id=new_owner.pk, username=new_owner.username
    )
    _owner_grant_from_seat(team, new_owner, paid_through, replaces_own_plan)
    if reactivated:
        activate_team(team)
        team.status = Team.STATUS_ACTIVE
        seat_grant_for_former_owner(old_owner, held_as_owner=False)

    provider, reference = former_billing
    handed_over_at = now.timestamp()
    transaction.on_commit(
        lambda: SettleHandOver.delay(
            team_id=team.pk,
            user_id=old_owner.pk,
            provider=provider,
            reference=reference,
            handed_over_at=handed_over_at,
        )
    )
    transaction.on_commit(
        lambda: EmailTeamNewOwner.delay(team_id=team.pk, user_id=new_owner.pk, former_owner_id=old_owner.pk)
    )
    return team


def _owner_grant_from_seat(team, user, paid_through, replaces_own_plan):
    """The grant of a teammate who now owns the team, shaped as _give_owner_pro and grant_team_pro shape a first
    payment's owner's: it keeps when the plan they have on their own ends (TeamProGrant.own_premium_expire), since
    their premium_expire follows the team's paid period from now on, and a purchase that replaced that plan leaves
    none to go back to. Someone whose grant a lapse released gets a new one from _give_owner_pro."""
    profile = Profile.objects.select_for_update().get(user=user)
    grant = TeamProGrant.objects.select_for_update().filter(user=user).first()
    if not grant:
        _give_owner_pro(team, user, profile, paid_through, replaces_own_plan)
        return
    own = dict(own_premium_expire=profile.premium_expire)
    if replaces_own_plan:
        own.update(own_tier=TeamProGrant.TIER_FREE, own_trial_expire=None, own_lifetime=False)
    TeamProGrant.objects.filter(pk=grant.pk).update(**own)
    own_tier = own.get("own_tier", grant.own_tier)
    # billing.py: the flags show team Pro, so whether their own plan never ends is read from the grant.
    open_ended_plan = profile.premium_expire is None and own_tier in TeamProGrant.PAID_TIERS
    if paid_through and not open_ended_plan:
        if profile.premium_expire is None or paid_through > profile.premium_expire:
            Profile.objects.filter(pk=profile.pk).update(premium_expire=paid_through)


def _handed_on_their_team(user):
    """Whether this account handed the team it holds a seat on to a teammate (_hand_over)."""
    membership = TeamMember.active_membership(user)
    return bool(membership) and (
        TeamActivity.objects.filter(
            team_id=membership.team_id, action="ownership_transferred", actor=user
        ).exists()
    )


def settle_former_owners_plan(user, team, provider, reference, handed_over_at):
    """Run by SettleHandOver (apps/team/tasks.py) once a team has changed hands (_hand_over), for its old owner, user,
    whose subscription provider billed it through reference. A Stripe or PayPal subscription is refunded the unused
    part of the month it last paid for, prorated over the period that payment paid for, and stops renewing, which is
    retried until Stripe or PayPal confirms it (StopRenewalsMadeBefore). The refund is tried once, so it can't be made
    twice, and when none is made staff are told and the hand over stands. An App Store or Google Play subscription
    only its owner can cancel, and NewsBlur can't refund it, so staff are told. Returns the dollars refunded, or
    None."""
    # billing.py: apps/team/stripe_billing.py imports this module.
    from apps.team.stripe_billing import refund_unused_month

    new_owner = team.owner.username if team.owner else "nobody"
    if provider in (Team.PROVIDER_APP_STORE, Team.PROVIDER_PLAY):
        EmailStaffNotification.delay(
            event_type="team_handed_over_in_store",
            subject="Team handed over, old owner still subscribed in a store: %s" % user.username,
            body="%s handed %s to %s, but still pays for it through %s (%s), which NewsBlur can't cancel or refund. "
            "They were sent the link to cancel it there."
            % (user.username, team.name, new_owner, provider, reference),
        )
        return None
    if provider not in (Team.PROVIDER_STRIPE, Team.PROVIDER_PAYPAL):
        return None

    refund, problem = None, "nothing was refunded"
    try:
        if provider == Team.PROVIDER_STRIPE:
            refund = refund_unused_month(user, reference, handed_over_at)
        else:
            refunded = Profile.objects.get(user=user).refund_paypal_payment_from_subscription(
                reference, prorate=True
            )
            if isinstance(refunded, int):
                refund = _paypal_refund_since(user, handed_over_at)
            elif refunded is not None:
                problem = str(refunded)
    except Exception as e:
        # billing.py: whatever went wrong, the old owner may be owed money, so this never ends silently.
        problem = repr(e)
    if refund is None:
        logging.user(user, "~FRNo refund for a team handed over: %s" % problem)
        EmailStaffNotification.delay(
            event_type="team_handover_not_refunded",
            subject="Team handed over, unused month not refunded: %s" % user.username,
            body="%s handed %s to %s, but the unused part of the month their %s subscription %s last paid for wasn't "
            "refunded (%s). It needs a look, and a refund by hand if one is due."
            % (user.username, team.name, new_owner, provider, reference, problem),
        )
    StopRenewalsMadeBefore.delay(user_id=user.pk, started_at=handed_over_at.timestamp())
    return refund


def _paypal_refund_since(user, since):
    """The dollars of the refund Profile.refund_paypal_payment_from_subscription recorded since a moment, as its
    payment row holds them, in whole dollars."""
    refund = (
        PaymentHistory.objects.filter(
            user=user, payment_provider="paypal", payment_amount__lt=0, payment_date__gte=since
        )
        .order_by("-payment_date")
        .first()
    )
    return -refund.payment_amount if refund else None


def _owners_team(user, plan, lapsed):
    """The buyer's team, locked, whether this payment started it, and why there is none: "on_team" for someone
    holding a seat on another team, which is every holder of team Pro, and "lapsed" for a payment whose paid
    period has already lapsed, which starts no team."""
    team = Team.objects.select_for_update().filter(owner=user).first()
    if team:
        return team, False, None
    if lapsed:
        return None, False, "lapsed"
    team, reason = Team.create_team(user, _default_name(user), plan, name_confirmed=False)
    if reason == "already_owns_team":
        # billing.py: another notice of the same payment started the team first.
        return Team.objects.select_for_update().get(owner=user), False, None
    if reason:
        return None, False, "on_team"
    return team, True, None


def end_team_now(user, provider, reference, taken_back_at):
    """A payment for the team provider bills through reference was taken back by a full refund, a dispute or a
    reversal, so the team ends at once (apps/team/grants.py deactivate_team). taken_back_at is when that payment was
    made. The team row is read again under its lock, so a payment taken back from a subscription that no longer
    bills the team, or one made before the payment the team was last renewed by, ends nothing. An owner with no plan
    of their own expires from now, and the payment stops counting toward their paid through date
    (Profile.setup_premium_history). Returns the team it ended, or None."""
    with transaction.atomic():
        team = _billed_teams(user, provider, reference, Team.STATUS_ACTIVE).first()
        # billing.py: PayPal's transaction and last payment times for one payment can differ a little.
        renewed_since = (
            team
            and team.last_payment_date
            and taken_back_at
            and team.last_payment_date > taken_back_at + datetime.timedelta(days=1)
        )
        if not team or renewed_since:
            return None
        Team.objects.filter(pk=team.pk).update(paid_through=datetime.datetime.now())
        deactivate_team(team, taken_back=True)
        if taken_back_at:
            PaymentHistory.objects.filter(
                user=user,
                payment_provider=provider,
                payment_amount__gt=0,
                payment_date__date=taken_back_at.date(),
            ).update(refunded=True)
    return team


def end_team_switched_down(user, provider, reference, plan, plan_paid=True):
    """The owner switched the team provider bills through reference down to plan, one of their own, and the month
    paid for has passed. The team row is read again under its lock, so a payment that renewed the team or moved its
    billing meanwhile keeps it. The team ends, and the owner is on plan once the provider has collected its first
    payment (plan_paid), or on a higher one of their own they had besides (release_team_pro). Until it is collected,
    Team.pending_plan keeps plan for finish_switch_down. Once nothing of the switch is left the billing reference is
    cleared too, so later notices for the subscription are for the owner's own plan. Returns (the team, the plan the
    owner is on, or None while they wait for plan), or (None, None) when the team was kept."""
    with transaction.atomic():
        team = _billed_teams(user, provider, reference, Team.STATUS_ACTIVE).first()
        if not team or (team.paid_through and team.paid_through > datetime.datetime.now()):
            return None, None
        own_plan = release_team_pro(user, owner=True)
        switched = not own_plan or TeamProGrant.TIER_ORDER.index(plan) > TeamProGrant.TIER_ORDER.index(
            own_plan
        )
        if switched and plan_paid:
            own_plan = plan
            Profile.objects.filter(user=user).update(**TeamProGrant.TIER_FLAGS[plan])
        deactivate_team(team)
        if switched and not plan_paid:
            Team.objects.filter(pk=team.pk).update(pending_plan=plan)
        else:
            Team.objects.filter(pk=team.pk).update(pending_plan=None, billing_reference=None)
    return team, own_plan


def finish_switch_down(user, provider, reference, plan):
    """Finishes a switch down to plan, one of the owner's own, when the team provider billed through reference ended
    before the provider collected plan's first payment, as the hourly task ends a team a day after its month
    (apps/team/tasks.py). Once the provider has collected it the owner is on plan, unless a plan of their own above it
    is still valid, and the team's pending plan and billing reference are cleared so nothing of the switch stays on
    the team. Pro left from the team until it expires (release_team_pro) isn't a plan of their own. Returns True when
    it finished the switch."""
    with transaction.atomic():
        team = (
            _billed_teams(user, provider, reference, Team.STATUS_INACTIVE).filter(pending_plan=plan).first()
        )
        if not team:
            return False
        own = Profile.objects.select_for_update().get(user=user)
        own_tier = TeamProGrant.tier_of(own)
        keeps_own_plan = (
            own_tier != TeamProGrant.TIER_PRO
            and (own.premium_expire is None or own.premium_expire > datetime.datetime.now())
            and TeamProGrant.TIER_ORDER.index(own_tier) > TeamProGrant.TIER_ORDER.index(plan)
        )
        if not keeps_own_plan:
            Profile.objects.filter(pk=own.pk).update(**TeamProGrant.TIER_FLAGS[plan])
        Team.objects.filter(pk=team.pk).update(pending_plan=None, billing_reference=None)
    return True


def _billed_teams(user, provider, reference, status):
    """The account's team in status that provider bills through reference, locked until the transaction ends."""
    return Team.objects.select_for_update().filter(
        owner=user, status=status, billing_provider=provider, billing_reference=reference
    )


def start_comp_team(owner, name, plan):
    """A team staff start under a name they chose, as a comp that doesn't lapse on a date. With no name it gets the
    default one a bought team starts with, which its owner is asked to replace. Its owner gets Premium Pro through
    record_team_payment like every owner. Returns (team, None), or (None, failure reason) as Team.create_team
    does."""
    with transaction.atomic():
        team, reason = Team.create_team(owner, name or _default_name(owner), plan, name_confirmed=bool(name))
        if reason:
            return None, reason
        payment = record_team_payment(
            owner, plan, Team.PROVIDER_COMP, None, owner.username, datetime.datetime.now()
        )
    return payment.team, None


def comp_refusal(user):
    """Why staff can't comp this account's team (comp_team), or None: the account is on a team it doesn't own, the
    team is comped already, or a provider bills it for a period that hasn't lapsed. A comp ignores every later
    payment (record_team_payment), so that subscription is cancelled first."""
    membership = TeamMember.active_membership(user)
    if not membership:
        return None
    team = membership.team
    if membership.role != TeamMember.ROLE_OWNER:
        return "comp_not_owner"
    if team.is_comped:
        return "already_comped"
    if (
        team.billing_provider in Team.PAID_PROVIDERS
        and Team.paid_for(datetime.datetime.now()).filter(pk=team.pk).exists()
    ):
        return "team_billed"
    return None


def comp_team(user, plan, staff):
    """Staff comp a team on plan for this account: a new one, under the default name, for an account on no team, or
    the team it owns once its paid period has lapsed, which comes back with its teammates. A comp has no payment and
    no lapse date until staff end it (end_comp). Returns (team, None) or (None, failure reason)."""
    with transaction.atomic():
        owned = Team.objects.select_for_update().filter(owner=user).first()
        reason = comp_refusal(user)
        if reason:
            return None, reason
        if owned:
            payment = record_team_payment(
                user, plan, Team.PROVIDER_COMP, None, user.username, datetime.datetime.now()
            )
            team, reason = payment.team, payment.reason
        else:
            team, reason = start_comp_team(user, None, plan)
        if reason:
            return None, reason
        TeamActivity.log(team, staff, "comp_started", plan=plan)
    return team, None


def end_comp(team, staff):
    """Staff end a comp, and the team lapses now as a team whose paid period ended now does (deactivate_team): every
    teammate's Premium Pro ends with one email each, and its owner goes back to a plan of their own or keeps Pro
    through the usual expiry window from now. Returns a failure reason or None."""
    now = datetime.datetime.now()
    with transaction.atomic():
        team = team.lock()
        if not team.is_comped:
            return "not_comped"
        team.paid_through = now
        team.save(update_fields=["paid_through", "updated_date"])
        # billing.py: as each payment moves the owner's premium_expire up to its paid through date (_give_owner_pro),
        # the comp's end moves an older one up to now, so the owner's expiry window starts now. release_team_pro
        # starts it now for an owner who never had one.
        Profile.objects.filter(user_id=team.owner_id, premium_expire__lt=now).update(premium_expire=now)
        TeamActivity.log(team, staff, "comp_ended")
        deactivate_team(team)
    return None


def _default_name(user):
    with account_translation(user.profile):
        name = gettext("%(username)s's team") % {"username": user.username}
    return name[: Team.NAME_MAX_LENGTH].strip()


def _apply_payment(
    team, user, plan, provider, paid_through, reference, paid_at, replaces_own_plan, created, now
):
    if team.billing_provider == Team.PROVIDER_COMP and team.paid_through is None:
        if provider != Team.PROVIDER_COMP:
            _tell_staff(
                "team_comp_paid",
                "Payment for a comped team: %s" % user.username,
                "%s paid for %s through %s (%s), but %s is comped with no end, so the team was not changed."
                % (user.username, plan, provider, reference, team.name),
            )
        return TeamPayment(team, "comped")

    first_payment = team.billing_provider is None
    newest = team.last_payment_date is None or paid_at >= team.last_payment_date
    if (
        newest
        and team.billing_provider in Team.PAID_PROVIDERS
        and provider in Team.PAID_PROVIDERS
        and provider != team.billing_provider
        and team.paid_through
        and team.paid_through > now
    ):
        _tell_staff(
            "team_paid_twice",
            "Team paid for in two places: %s" % user.username,
            "%s pays for %s through %s (%s) and now through %s (%s). The newest, %s, bills the team now."
            % (
                user.username,
                team.name,
                team.billing_provider,
                team.billing_reference,
                provider,
                reference,
                provider,
            ),
        )

    if newest:
        team.plan = plan
        team.billing_provider = provider
        team.billing_reference = reference
        team.last_payment_date = paid_at
    if provider == Team.PROVIDER_COMP and paid_through is None:
        team.paid_through = None
    elif team.paid_through is None or paid_through > team.paid_through:
        team.paid_through = paid_through
    team.save(
        update_fields=[
            "plan",
            "billing_provider",
            "billing_reference",
            "last_payment_date",
            "paid_through",
            "updated_date",
        ]
    )
    if Team.period_lapsed(team.paid_through, now):
        logging.user(
            user, "~FMTeam %s payment for a lapsed period: %s through %s" % (team.pk, plan, provider)
        )
        return TeamPayment(team, "lapsed")

    profile = Profile.objects.select_for_update().get(user=user)
    previous_tier = TeamProGrant.tier_of(profile)
    _give_owner_pro(team, user, profile, paid_through, replaces_own_plan)
    reactivated = team.status == Team.STATUS_INACTIVE
    if reactivated:
        activate_team(team)
        team.status = Team.STATUS_ACTIVE

    if first_payment:
        transaction.on_commit(lambda: EmailTeamWelcome.delay(team_id=team.pk))
        transaction.on_commit(
            lambda: EmailStaffPremiumUpgrade.delay(user_id=user.pk, tier=plan, previous_tier=previous_tier)
        )
    logging.user(
        user,
        "~FM~SBTeam %s payment~SN: %s through %s (%s)%s%s"
        % (
            team.pk,
            plan,
            provider,
            team.paid_through,
            ", new team" if created else "",
            ", reactivated" if reactivated else "",
        ),
    )
    return TeamPayment(team, None, created, reactivated)


def _give_owner_pro(team, user, profile, paid_through, replaces_own_plan):
    """The owner holds Premium Pro through a team grant, as a teammate does (apps/team/grants.py grant_team_pro).
    The grant remembers the plan they have on their own and when it ends, records one they buy or are given while
    it lasts, and puts it back when the team's plan ends (release_team_pro). Their premium_expire moves forward to
    the paid through date, so an owner with no plan of their own expires through the usual PremiumExpire window once
    the team ends (apps/profile/tasks.py). A plan with no end of its own keeps its empty premium_expire."""
    if not TeamProGrant.objects.filter(user=user).exists():
        grant_team_pro(team.members.get(user=user), own_plan_replaced=replaces_own_plan)
    open_ended_plan = profile.premium_expire is None and profile.is_premium and not profile.is_premium_trial
    if paid_through and not open_ended_plan:
        if profile.premium_expire is None or paid_through > profile.premium_expire:
            Profile.objects.filter(pk=profile.pk).update(premium_expire=paid_through)


def _tell_staff_buyer_is_on_a_team(user, plan, provider, reference):
    membership = TeamMember.active_membership(user)
    other_team = membership.team if membership else None
    _tell_staff(
        "team_purchase_on_team",
        "Team purchase from someone on another team: %s" % user.username,
        "%s paid for %s through %s (%s) while on %s, owned by %s. An account is on one team at a time, so no "
        "team was started and nothing on their account changed."
        % (
            user.username,
            plan,
            provider,
            reference,
            other_team.name if other_team else "another team",
            other_team.owner.username if other_team and other_team.owner else "nobody",
        ),
    )


def _tell_staff(event_type, subject, body):
    transaction.on_commit(
        lambda: EmailStaffNotification.delay(event_type=event_type, subject=subject, body=body)
    )
