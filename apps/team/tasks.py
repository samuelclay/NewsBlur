"""Team tasks: invite emails, what joining does to a teammate's own plan, and the hourly upkeep of teammates'
Premium Pro (apps/team/grants.py)."""

import datetime

from django.contrib.auth.models import User
from django.db.models import Q

from apps.profile.models import Profile
from apps.team.grants import (
    REMINDER_AFTER_DAYS,
    deactivate_team,
    release_team_pro,
    send_grace_reminder,
    settle_own_plan_on_join,
)
from apps.team.models import Team, TeamInvite, TeamMember, TeamProGrant
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

    for grant in TeamProGrant.objects.filter(grace_until__lte=now).select_related("user"):
        release_team_pro(grant.user, grace_ended_by=now)

    reminder_due = now - datetime.timedelta(days=REMINDER_AFTER_DAYS)
    reminders = TeamProGrant.objects.filter(
        grace_started__lte=reminder_due, grace_until__gt=now, day10_sent_date__isnull=True
    )
    for grant_id in reminders.values_list("pk", flat=True):
        send_grace_reminder(grant_id, now)

    # tasks.py: a request that loaded a teammate's profile before their grant and saves the whole row after it
    # (LastSeenMiddleware in apps/profile/middleware.py) writes their old flags back, so Pro is put back on
    # everyone holding a seat or in grace.
    holding_pro = TeamProGrant.objects.filter(
        Q(grace_until__gt=now)
        | Q(member__status=TeamMember.STATUS_ACTIVE, member__team__status=Team.STATUS_ACTIVE)
    )
    pro_flags = TeamProGrant.TIER_FLAGS[TeamProGrant.TIER_PRO]
    restored = (
        Profile.objects.filter(user_id__in=holding_pro.values("user_id"))
        .exclude(**pro_flags)
        .update(**pro_flags)
    )
    if restored:
        logging.debug(" ---> Put team Premium Pro back on %s overwritten profiles" % restored)
