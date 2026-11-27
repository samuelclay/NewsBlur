"""Team billing: where a confirmed payment for a team plan lands, whichever provider took it. The team is its
owner's account, so a team plan is a plan on the owner's own Profile (apps/team/models.py Team)."""

import datetime
from typing import NamedTuple, Optional

from django.contrib.auth.models import User
from django.db import transaction
from django.utils.translation import gettext

from apps.profile.models import Profile
from apps.profile.tasks import EmailStaffNotification, EmailStaffPremiumUpgrade
from apps.team.grants import _set_up_pro_feeds, activate_team
from apps.team.models import Team, TeamMember, TeamProGrant
from apps.team.sites import fit_sites_on_join
from apps.team.tasks import EmailTeamWelcome
from utils import log as logging
from utils.languages import account_translation


class TeamPayment(NamedTuple):
    """What record_team_payment did. reason is None when the payment was applied, and otherwise says why it
    changed nothing: "on_team", "no_paid_through" or "comped"."""

    team: Optional[Team]
    reason: Optional[str] = None
    created: bool = False
    reactivated: bool = False


def record_team_payment(user, plan, provider, paid_through, reference):
    """Apply a payment for a team plan that the provider has confirmed. Every provider calls this, for the first
    purchase and for every renewal, and calling it again for the same payment changes nothing more.

    The buyer's team is started on the first payment, with a default name the owner is then asked to replace,
    and comes back if it had lapsed. The plan, provider and reference are the newest payment's, so a team paid
    for in two places is billed by the newest purchase, and staff are told. The owner gets the Premium Pro flags
    as their own plan, without a team grant and without Profile.activate_pro's emails.

    reference is the provider's id that stays the same across renewals: the Stripe or PayPal subscription id,
    Apple's original transaction id, or the Play purchase token.

    paid_through only moves forward. A paid provider has to give one, or the payment changes nothing and staff
    are told. Only provider "comp" with an empty paid_through makes a team never lapse, and a team comped that
    way stays comped: a later payment from any provider changes nothing on it, and staff are told when a
    provider charged for it.

    Someone holding a seat on another team gets no team of their own and nothing on their account changes. Staff
    are told, since the provider has already taken the payment."""
    if plan not in dict(Team.PLAN_CHOICES) or provider not in dict(Team.PROVIDER_CHOICES):
        raise ValueError("Unknown team plan %r or provider %r" % (plan, provider))
    if provider != Team.PROVIDER_COMP and not paid_through:
        _tell_staff(
            "team_payment_without_date",
            "Team payment without a paid through date: %s" % user.username,
            "%s paid for %s through %s (%s), but no paid through date came with it, so the team was not changed."
            % (user.username, plan, provider, reference),
        )
        return TeamPayment(None, "no_paid_through")

    with transaction.atomic():
        team, created = _owners_team(user, plan)
        payment = (
            _apply_payment(team, user, plan, provider, paid_through, reference, created) if team else None
        )
    if not payment:
        _tell_staff_buyer_is_on_a_team(user, plan, provider, reference)
        return TeamPayment(None, "on_team")
    return payment


def _owners_team(user, plan):
    """The buyer's team, locked, and whether this payment started it. None when they hold a seat on another
    team, which is every holder of team Pro."""
    team = Team.objects.select_for_update().filter(owner=user).first()
    if team:
        return team, False
    team, reason = Team.create_team(user, _default_name(user), plan, name_confirmed=False)
    if reason == "already_owns_team":
        # billing.py: another notice of the same payment started the team first.
        return Team.objects.select_for_update().get(owner=user), False
    if reason:
        return None, False
    return team, True


def start_comp_team(owner, name, plan):
    """A team staff start under a name they chose, as a comp that doesn't lapse on a date. Its owner gets Premium
    Pro through record_team_payment like every owner. Returns (team, None), or (None, failure reason) as
    Team.create_team does."""
    with transaction.atomic():
        team, reason = Team.create_team(owner, name, plan)
        if reason:
            return None, reason
        payment = record_team_payment(owner, plan, Team.PROVIDER_COMP, None, owner.username)
    return payment.team, None


def _default_name(user):
    with account_translation(user.profile):
        name = gettext("%(username)s's team") % {"username": user.username}
    return name[: Team.NAME_MAX_LENGTH].strip()


def _apply_payment(team, user, plan, provider, paid_through, reference, created):
    if team.billing_provider == Team.PROVIDER_COMP and team.paid_through is None:
        if provider != Team.PROVIDER_COMP:
            _tell_staff(
                "team_comp_paid",
                "Payment for a comped team: %s" % user.username,
                "%s paid for %s through %s (%s), but %s is comped with no end, so the team was not changed."
                % (user.username, plan, provider, reference, team.name),
            )
        return TeamPayment(team, "comped")

    now = datetime.datetime.now()
    first_payment = team.billing_provider is None
    if (
        team.billing_provider in Team.PAID_PROVIDERS
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

    team.plan = plan
    team.billing_provider = provider
    team.billing_reference = reference
    if provider == Team.PROVIDER_COMP and paid_through is None:
        team.paid_through = None
    elif team.paid_through is None or paid_through > team.paid_through:
        team.paid_through = paid_through
    team.save(update_fields=["plan", "billing_provider", "billing_reference", "paid_through", "updated_date"])

    profile = Profile.objects.select_for_update().get(user=user)
    previous_tier = TeamProGrant.tier_of(profile)
    _give_owner_pro(team, user, profile, paid_through)
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


def _give_owner_pro(team, user, profile, paid_through):
    """The owner's Premium Pro is their own plan, set the way apps/team/grants.py grant_team_pro sets a
    teammate's. Their premium_expire moves forward to the paid through date, so once the team lapses their own
    account expires through the usual PremiumExpire window (apps/profile/tasks.py). A plan with no end of its own
    keeps its empty premium_expire."""
    updates = {}
    open_ended_plan = profile.premium_expire is None and profile.is_premium and not profile.is_premium_trial
    if paid_through and not open_ended_plan:
        if profile.premium_expire is None or paid_through > profile.premium_expire:
            updates["premium_expire"] = paid_through
    if TeamProGrant.tier_of(profile) != TeamProGrant.TIER_PRO:
        if not profile.is_premium:
            # billing.py: as in Profile.activate_pro, an account that wasn't premium gets its muted sites back,
            # within the team's shared limit.
            fit_sites_on_join(team.members.get(user=user), reactivate_muted=True)
        updates.update(TeamProGrant.TIER_FLAGS[TeamProGrant.TIER_PRO])
        User.objects.filter(pk=user.pk, is_active=False).update(is_active=True)
        start_archive_backfill = not profile.is_archive
        transaction.on_commit(lambda: _set_up_pro_feeds(user, start_archive_backfill))
    if updates:
        Profile.objects.filter(pk=profile.pk).update(**updates)


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
