"""Team tasks: invite emails, what joining does to a teammate's own plan, and the hourly upkeep of teammates'
Premium Pro (apps/team/grants.py)."""

import datetime

from django.contrib.auth.models import User

from apps.profile.models import Profile
from apps.team.grants import (
    deactivate_team,
    send_team_welcome_email,
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


# tasks.py: queued once a join has committed (TeamInvite.accept). Turning off a renewal again is harmless, so a
# retry after a failed email repeats the whole thing.
@app.task(
    name="team-own-plan-on-join",
    autoretry_for=(Exception,),
    retry_backoff=60,
    retry_kwargs={"max_retries": 3},
)
def SettleOwnPlanOnJoin(user_id, team_id, subscription):
    user = User.objects.filter(pk=user_id).first()
    team = Team.objects.filter(pk=team_id).first()
    if not user or not team:
        return
    settle_own_plan_on_join(user, team, subscription)


# tasks.py: queued once the first payment for a team has committed (apps/team/billing.py).
@app.task(
    name="email-team-welcome", autoretry_for=(Exception,), retry_backoff=60, retry_kwargs={"max_retries": 3}
)
def EmailTeamWelcome(team_id):
    team = Team.objects.select_related("owner").filter(pk=team_id).first()
    if not team or not team.owner:
        return
    send_team_welcome_email(team)


@app.task(name="team-pro-grants")
def TeamProGrants():
    now = datetime.datetime.now()

    # tasks.py: a team lapses a day after its paid period ends without a payment, when it has no paid period and
    # isn't a comp, or when its owner's account was deleted (Team.owner is SET_NULL) and nobody pays for it.
    lapsed_teams = Team.objects.filter(Team.lapsed(now), status=Team.STATUS_ACTIVE)
    for team in lapsed_teams:
        logging.debug(" ---> Team %s lapsed, ending its teammates' Premium Pro" % team)
        deactivate_team(team, lapsed_at=now)

    # tasks.py: a change to a teammate's own plan already under way when they join (PremiumExpire in
    # apps/profile/tasks.py ending a trial it loaded before the join, a payment webhook mid activation) writes
    # the plan it loaded over the Pro the join set, so Pro is put back on everyone holding a grant.
    pro_flags = TeamProGrant.TIER_FLAGS[TeamProGrant.TIER_PRO]
    restored = (
        Profile.objects.filter(user__team_pro_grant__isnull=False).exclude(**pro_flags).update(**pro_flags)
    )
    if restored:
        logging.debug(" ---> Put team Premium Pro back on %s overwritten profiles" % restored)
