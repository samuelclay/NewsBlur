"""Team tasks: invite emails, what joining does to a teammate's own plan, and the hourly upkeep of teammates'
Premium Pro (apps/team/grants.py)."""

import datetime

from django.contrib.auth.models import User
from django.db.models import Q

from apps.profile.models import Profile
from apps.team.grants import deactivate_team, settle_own_plan_on_join
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


@app.task(name="team-pro-grants")
def TeamProGrants():
    now = datetime.datetime.now()

    # tasks.py: a team lapses once its paid period has passed, and a team whose owner's account was deleted
    # (Team.owner is SET_NULL) has nobody paying for it.
    lapsed_teams = Team.objects.filter(status=Team.STATUS_ACTIVE).filter(
        Q(paid_through__lt=now) | Q(owner__isnull=True)
    )
    for team in lapsed_teams:
        logging.debug(" ---> Team %s lapsed, ending its teammates' Premium Pro" % team)
        deactivate_team(team)

    # tasks.py: a change to a teammate's own plan already under way when they join (PremiumExpire in
    # apps/profile/tasks.py ending a trial it loaded before the join, a payment webhook mid activation) writes
    # the plan it loaded over the Pro the join set, so Pro is put back on everyone holding a grant.
    pro_flags = TeamProGrant.TIER_FLAGS[TeamProGrant.TIER_PRO]
    restored = (
        Profile.objects.filter(user__team_pro_grant__isnull=False).exclude(**pro_flags).update(**pro_flags)
    )
    if restored:
        logging.debug(" ---> Put team Premium Pro back on %s overwritten profiles" % restored)
