"""Team tasks: the hourly upkeep of teammates' Premium Pro (apps/team/grants.py)."""

import datetime

from django.db.models import Q

from apps.team.grants import (
    REMINDER_AFTER_DAYS,
    deactivate_team,
    release_team_pro,
    send_grace_reminder,
)
from apps.team.models import Team, TeamProGrant
from newsblur_web.celeryapp import app
from utils import log as logging


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
