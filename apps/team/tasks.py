"""Team tasks: invite emails, what joining does to a teammate's own plan, handing a team to a new owner, and the hourly
upkeep of teammates' Premium Pro (apps/team/grants.py)."""

import datetime

from django.contrib.auth.models import User
from django.db import transaction

from apps.profile.models import Profile
from apps.profile.tasks import EmailStaffNotification
from apps.team.grants import (
    deactivate_team,
    own_subscription,
    send_former_owner_email,
    send_new_owner_email,
    send_team_plan_ended_email,
    send_team_welcome_email,
    send_transfer_requested_email,
    settle_own_plan_on_join,
)
from apps.team.models import Team, TeamInvite, TeamProGrant
from newsblur_web.celeryapp import app
from utils import log as logging


# tasks.py: one task per invite, queued once the invite has committed (Team.invite_by_email), so a failed send
# retries only its own recipient.
@app.task(
    name="email-team-invite", autoretry_for=(Exception,), retry_backoff=60, retry_kwargs={"max_retries": 3}
)
def SendTeamInviteEmail(invite_id):
    invite = TeamInvite.objects.select_related("team", "created_by").filter(pk=invite_id).first()
    # tasks.py: an invite revoked, used or expired before its turn in the queue isn't sent.
    if not invite or not invite.created_by or invite.refusal_reason():
        return
    invite.send_email()


# tasks.py: queued once a join commits (TeamInvite.accept), with the time of the join, so the Stripe and PayPal
# subscriptions it turns off are the ones made before it, and only while the grant this join made is still held.
# Turning off a renewal again is harmless, so a retry repeats the whole thing. A renewal Stripe or PayPal can't read
# or confirm is off, and any other error, is retried, and after the last retry staff are told instead of the
# teammate. subscription is the kind of plan read on the first try, kept through the retries.
@app.task(name="team-own-plan-on-join", bind=True, max_retries=3)
def SettleOwnPlanOnJoin(self, grant_id, joined_at, subscription=None):
    grant = TeamProGrant.objects.select_related("user", "member__team").filter(pk=grant_id).first()
    # tasks.py: a seat that ended before the task's turn released this grant, and whatever the person pays for
    # since is theirs to keep.
    if not grant or not grant.member:
        return
    user, team = grant.user, grant.member.team
    subscription = subscription or own_subscription(user)
    if not subscription:
        return
    problem = "a renewal that isn't confirmed off"
    try:
        if settle_own_plan_on_join(user, team, subscription, joined_at):
            return
    except Exception as e:
        # tasks.py: whatever went wrong, the person's renewal may still be on, so this never ends silently.
        logging.user(user, "~FRCouldn't settle own plan on joining a team: %r" % e)
        problem = repr(e)
    if self.request.retries < self.max_retries:
        raise self.retry(
            kwargs=dict(grant_id=grant_id, joined_at=joined_at, subscription=subscription),
            countdown=60 * 2**self.request.retries,
        )
    EmailStaffNotification.delay(
        event_type="team_own_plan_unconfirmed",
        subject="Own renewal not confirmed off after joining a team: %s" % user.username,
        body="%s joined %s, which covers Premium Pro, but their own %s renewal could not be confirmed off (%s). "
        "They were not emailed about their own plan." % (user.username, team.name, subscription, problem),
    )


# tasks.py: queued once a PayPal subscription starts billing a team or is approved as a switch away from the team's
# plan (apps/team/paypal_billing.py), with when that subscription was made, or once a Stripe subscription starts
# billing a team (apps/team/stripe_billing.py), with when it was paid for and its id as kept_id. The account's Stripe
# and PayPal subscriptions made before then, apart from kept_id, stop renewing. One Stripe or PayPal can't stop or
# confirm stopped is retried, and after the last retry staff are told, since the account would otherwise pay twice.
@app.task(name="team-stop-renewals-made-before", bind=True, max_retries=3)
def StopRenewalsMadeBefore(self, user_id, started_at, kept_id=None):
    # tasks.py: apps/team/paypal_billing.py imports this module.
    from apps.team.paypal_billing import stop_renewals_made_before

    user = User.objects.filter(pk=user_id).first()
    if not user:
        return
    problem = "a renewal that isn't confirmed off"
    try:
        if stop_renewals_made_before(user, started_at, kept_id):
            return
    except Exception as e:
        logging.user(user, "~FRCouldn't stop renewals made before a team subscription: %r" % e)
        problem = repr(e)
    if self.request.retries < self.max_retries:
        raise self.retry(
            kwargs=dict(user_id=user_id, started_at=started_at, kept_id=kept_id),
            countdown=60 * 2**self.request.retries,
        )
    EmailStaffNotification.delay(
        event_type="team_renewal_unconfirmed",
        subject="Renewal not confirmed off after a team billing change: %s" % user.username,
        body="%s changed how their team is billed through a subscription that started at %s, but their Stripe or "
        "PayPal subscriptions made before it could not be confirmed off (%s), so they may pay twice."
        % (user.username, datetime.datetime.fromtimestamp(started_at), problem),
    )


# tasks.py: one task per teammate, queued once a lapse has committed (apps/team/grants.py deactivate_team), so a
# failed send retries only its own recipient.
@app.task(
    name="email-team-plan-ended",
    autoretry_for=(Exception,),
    retry_backoff=60,
    retry_kwargs={"max_retries": 3},
)
def EmailTeamPlanEnded(user_id, team_id, plan):
    user = User.objects.filter(pk=user_id).first()
    team = Team.objects.filter(pk=team_id).first()
    # tasks.py: a payment that brought the team back before this email's turn makes it untrue.
    if not user or not team or team.status != Team.STATUS_INACTIVE:
        return
    send_team_plan_ended_email(user, team, plan)


# tasks.py: queued once the first payment for a team has committed (apps/team/billing.py).
@app.task(
    name="email-team-welcome", autoretry_for=(Exception,), retry_backoff=60, retry_kwargs={"max_retries": 3}
)
def EmailTeamWelcome(team_id):
    team = Team.objects.select_related("owner").filter(pk=team_id).first()
    if not team or not team.owner:
        return
    send_team_welcome_email(team)


# tasks.py: queued once a request to hand a team over has committed (Team.request_transfer). One replaced, ended or
# run out before its turn isn't sent.
@app.task(
    name="email-team-transfer-requested",
    autoretry_for=(Exception,),
    retry_backoff=60,
    retry_kwargs={"max_retries": 3},
)
def EmailTeamTransferRequested(team_id, pending_owner_id):
    team = Team.objects.select_related("owner", "pending_owner").filter(pk=team_id).first()
    if not team or not team.owner or not team.pending_owner:
        return
    if team.pending_owner_id != pending_owner_id or not team.transfer_waits_for(team.pending_owner):
        return
    send_transfer_requested_email(team)


# tasks.py: queued once a team has changed hands (apps/team/billing.py _hand_over), for its old owner, with the
# subscription that billed the team until then. Never retried, so its refund can't be made twice. Then the old owner
# is emailed what happened to that subscription.
@app.task(name="team-settle-hand-over")
def SettleHandOver(team_id, user_id, provider, reference, handed_over_at):
    # tasks.py: apps/team/billing.py imports this module.
    from apps.team.billing import settle_former_owners_plan

    team = Team.objects.select_related("owner").filter(pk=team_id).first()
    user = User.objects.filter(pk=user_id).first()
    if not team or not user:
        return
    handed_over_at = datetime.datetime.fromtimestamp(handed_over_at)
    refund = settle_former_owners_plan(user, team, provider, reference, handed_over_at)
    EmailTeamFormerOwner.delay(team_id=team_id, user_id=user_id, provider=provider, refund=refund)


@app.task(
    name="email-team-former-owner",
    autoretry_for=(Exception,),
    retry_backoff=60,
    retry_kwargs={"max_retries": 3},
)
def EmailTeamFormerOwner(team_id, user_id, provider, refund=None):
    team = Team.objects.select_related("owner").filter(pk=team_id).first()
    user = User.objects.filter(pk=user_id).first()
    if not team or not team.owner or not user:
        return
    send_former_owner_email(user, team, provider, refund)


# tasks.py: queued once a team has changed hands (apps/team/billing.py _hand_over).
@app.task(
    name="email-team-new-owner", autoretry_for=(Exception,), retry_backoff=60, retry_kwargs={"max_retries": 3}
)
def EmailTeamNewOwner(team_id, user_id, former_owner_id):
    team = Team.objects.select_related("owner").filter(pk=team_id).first()
    # tasks.py: a team handed on again before this email's turn isn't theirs to be told about.
    if not team or team.owner_id != user_id:
        return
    send_new_owner_email(team, User.objects.filter(pk=former_owner_id).first())


@app.task(name="team-pro-grants")
def TeamProGrants():
    now = datetime.datetime.now()

    # tasks.py: a team lapses a day after its paid period ends without a payment, when it has no paid period and
    # isn't a comp, or when its owner's account was deleted (Team.owner is SET_NULL) and nobody pays for it.
    lapsed_teams = Team.objects.filter(Team.lapsed(now), status=Team.STATUS_ACTIVE)
    for team in lapsed_teams:
        logging.debug(" ---> Team %s lapsed, ending its teammates' Premium Pro" % team)
        deactivate_team(team, lapsed_at=now)

    # tasks.py: a request to hand a team over that its teammate didn't take up in time ends.
    for team in Team.transfers_run_out(now):
        team.expire_transfer(now)

    # tasks.py: a change to a teammate's own plan already under way when they join (PremiumExpire in
    # apps/profile/tasks.py ending a trial it loaded before the join, a payment webhook mid activation) writes
    # the plan it loaded over the Pro the join set, so Pro is put back on everyone holding a grant. Each profile is
    # locked before its grant is read, the order release_team_pro takes them in, so a profile whose grant was
    # released meanwhile keeps the plan the release wrote.
    pro_flags = TeamProGrant.TIER_FLAGS[TeamProGrant.TIER_PRO]
    overwritten = Profile.objects.filter(user__team_pro_grant__isnull=False).exclude(**pro_flags)
    restored = 0
    for profile_id in list(overwritten.values_list("pk", flat=True)):
        with transaction.atomic():
            profile = Profile.objects.select_for_update().filter(pk=profile_id).first()
            if profile and TeamProGrant.objects.filter(user_id=profile.user_id).exists():
                restored += Profile.objects.filter(pk=profile_id).exclude(**pro_flags).update(**pro_flags)
    if restored:
        logging.debug(" ---> Put team Premium Pro back on %s overwritten profiles" % restored)
