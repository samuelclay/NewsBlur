"""Premium Pro for teammates: granting it with a seat, 14 days of grace after a seat on an active team ends,
releasing it back to the person's own plan, and a team lapsing or coming back (apps/team/models.py
TeamProGrant)."""

import datetime

import redis
from django.conf import settings
from django.contrib.auth.models import User
from django.core.mail import EmailMultiAlternatives
from django.db import transaction
from django.template.loader import render_to_string
from django.utils.translation import gettext

from apps.profile.models import MSentEmail, Profile
from apps.profile.tasks import TIER_NAMES
from apps.reader.models import UserSubscription
from apps.rss_feeds.tasks import SchedulePremiumSetup
from apps.team.models import Team, TeamActivity, TeamMember, TeamProGrant
from utils import log as logging
from utils.languages import account_translation
from utils.templatetags.utils_tags import language_date

GRACE_DAYS = 14
# grants.py: the reminder goes out on day 10 of grace, where day 1 is the day grace began.
REMINDER_AFTER_DAYS = 9


def grant_team_pro(member):
    """Give an active teammate Premium Pro by setting the real tier flags on their profile. Unlike
    Profile.activate_pro it sends no welcome or staff email, writes no payment row and leaves premium_expire
    as the person's own paid through date. The first grant keeps the person's own plan to go back to; a rejoin
    during grace reuses that row, so team Pro never becomes their own plan."""
    user = member.user
    with transaction.atomic():
        profile = Profile.objects.select_for_update().get(user=user)
        grant = TeamProGrant.objects.select_for_update().filter(user=user).first()
        if grant:
            grant.member = member
            grant.grace_started = None
            grant.grace_until = None
            grant.day10_sent_date = None
            grant.save(update_fields=["member", "grace_started", "grace_until", "day10_sent_date"])
        else:
            own_tier = TeamProGrant.tier_of(profile)
            grant = TeamProGrant.objects.create(
                user=user,
                member=member,
                own_tier=own_tier,
                own_trial_expire=profile.premium_expire if own_tier == TeamProGrant.TIER_TRIAL else None,
            )
        Profile.objects.filter(pk=profile.pk).update(**TeamProGrant.TIER_FLAGS[TeamProGrant.TIER_PRO])
        User.objects.filter(pk=user.pk, is_active=False).update(is_active=True)
        # grants.py: every muted site comes back, as a free account's do on any upgrade.
        UserSubscription.objects.filter(user=user, active=False).update(active=True)
        TeamActivity.log(member.team, user, "team_pro_granted")

        start_archive_backfill = not profile.is_archive
        transaction.on_commit(lambda: _set_up_pro_feeds(user, start_archive_backfill))
    return grant


def _set_up_pro_feeds(user, start_archive_backfill):
    """What Profile.activate_pro starts for a new subscriber's feeds, once the grant has committed."""
    feed_ids = list(UserSubscription.objects.filter(user=user).values_list("feed_id", flat=True))
    SchedulePremiumSetup.apply_async(kwargs=dict(feed_ids=feed_ids))
    UserSubscription.queue_new_feeds(user)
    if start_archive_backfill:
        UserSubscription.schedule_fetch_archive_feeds_for_user(user.pk)
    _reload_feeds(user)


def _reload_feeds(user):
    redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL).publish(user.username, "reload:feeds")


def begin_seat_grace(member):
    """A seat on an active team ended. Its Premium Pro lasts 14 more days, with an email now and on day 10."""
    now = datetime.datetime.now()
    with transaction.atomic():
        grant = (
            TeamProGrant.objects.select_for_update()
            .filter(user=member.user, member=member, grace_started__isnull=True)
            .first()
        )
        if not grant:
            return
        grant.grace_started = now
        grant.grace_until = now + datetime.timedelta(days=GRACE_DAYS)
        grant.day10_sent_date = None
        grant.save(update_fields=["grace_started", "grace_until", "day10_sent_date"])
    send_grace_email(grant, member.team, reminder=False)


def send_grace_reminder(grant_id, now):
    """Day 10 of grace. The row stays locked while the email goes out, so a second run of the hourly task skips
    it, and a failed send rolls back for the next run to retry."""
    with transaction.atomic():
        grant = (
            TeamProGrant.objects.select_for_update(skip_locked=True)
            .filter(pk=grant_id, day10_sent_date__isnull=True, grace_until__gt=now, member__isnull=False)
            .first()
        )
        if not grant:
            return
        grant.day10_sent_date = now
        grant.save(update_fields=["day10_sent_date"])
        send_grace_email(grant, grant.member.team, reminder=True)


def release_team_pro(user, grace_ended_by=None):
    """End a person's team Pro and put them on their own plan: the tier they pay for while their own
    premium_expire covers today, a trial that is still running, or otherwise free through
    Profile.deactivate_premium, which mutes every site until they choose the ones to keep. With grace_ended_by,
    only a grant whose grace ended by then is released, so a teammate who rejoined meanwhile keeps theirs.
    Returns the plan they are on now, or None when nothing was released."""
    now = datetime.datetime.now()
    with transaction.atomic():
        profile = Profile.objects.select_for_update().get(user=user)
        grants = TeamProGrant.objects.select_for_update().filter(user=user)
        if grace_ended_by:
            grants = grants.filter(grace_until__lte=grace_ended_by)
        grant = grants.first()
        if not grant:
            return None
        plan = grant.own_plan_on(profile, now)
        grant.delete()
        if plan == TeamProGrant.TIER_FREE:
            profile.deactivate_premium()
        else:
            Profile.objects.filter(pk=profile.pk).update(**TeamProGrant.TIER_FLAGS[plan])
        transaction.on_commit(lambda: _reload_feeds(profile.user))
    logging.user(profile.user, "~FMTeam Pro released, back on %s" % plan)
    return plan


def deactivate_team(team):
    """Billing calls this when the owner's paid period ends without a payment. The team goes inactive and every
    teammate's Premium Pro ends at once, with no grace, and each teammate gets one email. Members, roles, invites
    and settings stay as they are. Someone already in grace from an earlier seat keeps the date they were given.
    """
    with transaction.atomic():
        team = team.lock()
        if team.status == Team.STATUS_INACTIVE:
            return
        team.status = Team.STATUS_INACTIVE
        team.save(update_fields=["status", "updated_date"])
        TeamActivity.log(team, None, "team_deactivated")
        members = list(team.active_members())
        plans = {}
        for grant in TeamProGrant.objects.filter(member__in=members).select_related("user"):
            plans[grant.user_id] = release_team_pro(grant.user)
    for member in members:
        send_team_plan_ended_email(member.user, team, plans.get(member.user_id))


def activate_team(team):
    """Billing calls this when a payment for the team succeeds. The team is active again and every teammate
    gets Premium Pro back, with a fresh snapshot of their own plan. The owner's Pro is their own plan."""
    with transaction.atomic():
        team = team.lock()
        if team.status == Team.STATUS_ACTIVE:
            return
        team.status = Team.STATUS_ACTIVE
        team.save(update_fields=["status", "updated_date"])
        TeamActivity.log(team, None, "team_activated")
        for member in team.active_members().exclude(role=TeamMember.ROLE_OWNER):
            grant_team_pro(member)


def _plan_context(plan, profile):
    # grants.py: a trial's end stays in premium_expire, which team Pro never writes.
    return {"plan": plan, "plan_name": TIER_NAMES.get(plan), "trial_date": profile.premium_expire}


def send_grace_email(grant, team, reminder):
    user = grant.user
    profile = Profile.objects.get(user=user)
    if not user.email:
        logging.user(user, "~FMNot sending team Pro grace email, no email address")
        return

    data = dict(
        user=user,
        team_name=team.name,
        end_date=grant.grace_until,
        reminder=reminder,
        **_plan_context(grant.own_plan_on(profile, grant.grace_until), profile),
    )
    with account_translation(profile):
        text = render_to_string("mail/email_team_pro_grace.txt", data)
        html = render_to_string("mail/email_team_pro_grace.xhtml", data)
        subject_data = {"team": team.name, "date": language_date(grant.grace_until, "F j, Y")}
        if reminder:
            subject = gettext("Reminder: your Premium Pro from %(team)s ends on %(date)s") % subject_data
        else:
            subject = gettext("Your Premium Pro from %(team)s ends on %(date)s") % subject_data
    _send(profile, subject, text, html, "team_pro_grace_reminder" if reminder else "team_pro_grace")


def send_team_plan_ended_email(user, team, plan):
    """plan is what a released teammate is on now, or None for someone whose account the lapse didn't change,
    such as the owner."""
    profile = Profile.objects.get(user=user)
    if not user.email:
        logging.user(user, "~FMNot sending team plan ended email, no email address")
        return

    data = dict(user=user, team_name=team.name, **_plan_context(plan, profile))
    with account_translation(profile):
        text = render_to_string("mail/email_team_plan_ended.txt", data)
        html = render_to_string("mail/email_team_plan_ended.xhtml", data)
        subject = gettext("The Premium Team plan for %(team)s has ended") % {"team": team.name}
    _send(profile, subject, text, html, "team_plan_ended")


def _send(profile, subject, text, html, email_type):
    user = profile.user
    msg = EmailMultiAlternatives(
        subject,
        text,
        from_email="NewsBlur <%s>" % settings.HELLO_EMAIL,
        to=["%s <%s>" % (user, user.email)],
        headers=profile.email_unsubscribe_headers(),
    )
    msg.attach_alternative(html, "text/html")
    msg.send()
    MSentEmail.record(receiver_user_id=user.pk, email_type=email_type)
    logging.user(user, "~BB~FM~SBSending %s email" % email_type)
