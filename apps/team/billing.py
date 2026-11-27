"""Team billing: where a confirmed payment for a team plan lands, whichever provider took it. The team is its
owner's account, so a team plan is a plan on the owner's own Profile (apps/team/models.py Team)."""

import datetime
from typing import NamedTuple, Optional

from django.db import transaction
from django.utils.translation import gettext

from apps.profile.models import Profile
from apps.profile.tasks import EmailStaffNotification, EmailStaffPremiumUpgrade
from apps.team.grants import (
    activate_team,
    deactivate_team,
    grant_team_pro,
    release_team_pro,
)
from apps.team.models import Team, TeamMember, TeamProGrant
from apps.team.tasks import EmailTeamWelcome
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

    Someone holding a seat on another team gets no team of their own and nothing on their account changes. Staff
    are told, since the provider has already taken the payment."""
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
        team, created, reason = _owners_team(user, plan, Team.period_lapsed(paid_through, now))
        if team:
            return _apply_payment(
                team, user, plan, provider, paid_through, reference, paid_at, replaces_own_plan, created, now
            )
    if reason == "on_team":
        _tell_staff_buyer_is_on_a_team(user, plan, provider, reference)
    return TeamPayment(None, reason)


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


def end_team_now(team):
    """A payment for the team was taken back by a full refund, a dispute or a reversal, so the team ends at once
    (apps/team/grants.py deactivate_team)."""
    with transaction.atomic():
        Team.objects.filter(pk=team.pk).update(paid_through=datetime.datetime.now())
        deactivate_team(team)


def end_team_switched_down(user, team, plan):
    """The owner switched the team down to plan, and the month paid for has passed. The team ends and the owner is
    on that plan, or on a higher one of their own they had besides (release_team_pro). Returns the plan they're
    on."""
    with transaction.atomic():
        team = team.lock()
        own_plan = release_team_pro(user, owner=True)
        if not own_plan or TeamProGrant.TIER_ORDER.index(plan) > TeamProGrant.TIER_ORDER.index(own_plan):
            own_plan = plan
            Profile.objects.filter(user=user).update(**TeamProGrant.TIER_FLAGS[plan])
        deactivate_team(team)
        Team.objects.filter(pk=team.pk).update(pending_plan=None)
    return own_plan


def start_comp_team(owner, name, plan):
    """A team staff start under a name they chose, as a comp that doesn't lapse on a date. Its owner gets Premium
    Pro through record_team_payment like every owner. Returns (team, None), or (None, failure reason) as
    Team.create_team does."""
    with transaction.atomic():
        team, reason = Team.create_team(owner, name, plan)
        if reason:
            return None, reason
        payment = record_team_payment(
            owner, plan, Team.PROVIDER_COMP, None, owner.username, datetime.datetime.now()
        )
    return payment.team, None


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
    The grant remembers the plan they have on their own, records one they buy or are given while it lasts, and
    puts it back when the team's plan ends (release_team_pro). Their premium_expire moves forward to the paid
    through date, so an owner with no plan of their own expires through the usual PremiumExpire window once the
    team ends (apps/profile/tasks.py). A plan with no end of its own keeps its empty premium_expire."""
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
