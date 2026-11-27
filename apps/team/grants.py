"""Premium Pro for teammates: granting it with a seat, what joining does to a plan the person pays for on their
own, releasing it back to the person's own plan the moment the seat ends, and a team lapsing or coming back
(apps/team/models.py TeamProGrant)."""

import datetime

import redis
from django.conf import settings
from django.contrib.auth.models import User
from django.core.mail import EmailMultiAlternatives
from django.db import transaction
from django.template.loader import render_to_string
from django.utils.translation import gettext

from apps.profile.models import MSentEmail, PaymentHistory, Profile
from apps.profile.tasks import TIER_NAMES
from apps.reader.models import UserSubscription
from apps.rss_feeds.tasks import SchedulePremiumSetup
from apps.team.models import Team, TeamActivity, TeamMember, TeamProGrant, one_line
from apps.team.sites import fit_sites_on_join
from utils import log as logging
from utils.languages import account_translation
from utils.templatetags.utils_tags import language_date

# grants.py: a plan a teammate pays for on their own. Joining turns off a Stripe or PayPal renewal; an App Store
# or Play subscription only its owner can cancel, so they're told where.
RENEWALS_TURNED_OFF_ON_JOIN = ("stripe", "paypal")
STORE_PAYMENT_PREFIXES = (("ios-", "app_store"), ("android-", "play"))
STORE_SUBSCRIPTION_URLS = {
    "app_store": "https://apps.apple.com/account/subscriptions",
    "play": "https://play.google.com/store/account/subscriptions?package=%s"
    % settings.GOOGLE_PLAY_PACKAGE_NAME,
}
STORE_PAYMENT_DAYS = 365


def grant_team_pro(member):
    """Give an active teammate Premium Pro by setting the real tier flags on their profile. Unlike
    Profile.activate_pro it sends no welcome or staff email, writes no payment row and leaves premium_expire
    as the person's own paid through date. Every grant, a rejoin's too, snapshots the plan the person has on their
    own from their profile. A profile carries team Pro only while its grant exists, and there is one grant per
    person, so the snapshot is never team Pro."""
    user = member.user
    with transaction.atomic():
        profile = Profile.objects.select_for_update().get(user=user)
        own_tier = TeamProGrant.tier_of(profile)
        grant = TeamProGrant.objects.create(
            user=user,
            member=member,
            own_tier=own_tier,
            own_trial_expire=profile.premium_expire if own_tier == TeamProGrant.TIER_TRIAL else None,
            own_premium_trial=profile.is_premium_trial,
        )
        # grants.py: as in Profile.activate_pro, only an account that wasn't premium, trial included, gets its
        # muted sites back. Anyone else muted theirs on purpose. Either way the sites stay within the team's
        # shared limit.
        fit_sites_on_join(member, reactivate_muted=not profile.is_premium)
        Profile.objects.filter(pk=profile.pk).update(**TeamProGrant.TIER_FLAGS[TeamProGrant.TIER_PRO])
        User.objects.filter(pk=user.pk, is_active=False).update(is_active=True)

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


def release_team_pro(user):
    """End a person's team Pro and put them on their own plan: the tier they pay for while their own
    premium_expire covers today, a trial that is still running, or otherwise free through
    Profile.deactivate_premium, which mutes every site until they choose the ones to keep. Returns the plan they
    are on now, or None when they held no grant."""
    now = datetime.datetime.now()
    with transaction.atomic():
        profile = Profile.objects.select_for_update().get(user=user)
        grant = TeamProGrant.objects.select_for_update().filter(user=user).first()
        if not grant:
            return None
        plan = grant.own_plan_on(profile, now)
        grant.delete()
        if plan == TeamProGrant.TIER_FREE:
            # grants.py: an account that never had a trial can still start one. Any other has used it, including
            # one whose trial ran out during the seat.
            profile.is_premium_trial = None if grant.own_premium_trial is None else False
            profile.deactivate_premium()
        else:
            Profile.objects.filter(pk=profile.pk).update(**TeamProGrant.TIER_FLAGS[plan])
        transaction.on_commit(lambda: _reload_feeds(profile.user))
    logging.user(profile.user, "~FMTeam Pro released, back on %s" % plan)
    return plan


def deactivate_team(team):
    """Billing calls this when the owner's paid period ends without a payment. The team goes inactive and every
    teammate's Premium Pro ends at once, and each teammate gets one email. Members, roles, invites and settings
    stay as they are."""
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


def own_subscription(user):
    """The plan this person pays for on their own that renews by itself: "stripe" or "paypal", "app_store" or
    "play", or None."""
    profile = Profile.objects.get(user=user)
    if profile.premium_renewal and profile.active_provider in RENEWALS_TURNED_OFF_ON_JOIN:
        return profile.active_provider
    now = datetime.datetime.now()
    if profile.premium_expire and profile.premium_expire <= now:
        return None
    # grants.py: setup_premium_history clears active_provider for an account Stripe and PayPal don't bill, so a
    # store subscription shows only as its payments.
    payment = (
        PaymentHistory.objects.filter(
            user=user,
            payment_amount__gt=0,
            payment_date__gte=now - datetime.timedelta(days=STORE_PAYMENT_DAYS),
        )
        .exclude(refunded=True)
        .order_by("-payment_date")
        .first()
    )
    for prefix, store in STORE_PAYMENT_PREFIXES:
        if payment and payment.payment_provider.startswith(prefix):
            return store
    return None


def own_plan_on_join(user):
    """What joining a team does to the plan this person pays for on their own, for the join screen and the
    accept response (apps/team/views.py). on_join is "renewal_off", "cancel_in_store" or None."""
    subscription = own_subscription(user)
    own_plan = dict(subscription=subscription, on_join=None, paid_through=None, manage_url=None, message=None)
    if subscription in RENEWALS_TURNED_OFF_ON_JOIN:
        paid_through = Profile.objects.get(user=user).premium_expire
        own_plan.update(on_join="renewal_off", paid_through=paid_through)
        if paid_through:
            own_plan["message"] = gettext(
                "The team covers Premium Pro, so joining turns off renewal of the plan you pay for yourself. "
                "You keep that plan until %(date)s."
            ) % {"date": language_date(paid_through, "F j, Y")}
        else:
            own_plan["message"] = gettext(
                "The team covers Premium Pro, so joining turns off renewal of the plan you pay for yourself."
            )
    elif subscription == "app_store":
        own_plan.update(on_join="cancel_in_store", manage_url=STORE_SUBSCRIPTION_URLS[subscription])
        own_plan["message"] = gettext(
            "The team covers Premium Pro, so you can cancel your App Store subscription to NewsBlur. "
            "NewsBlur can't cancel it for you."
        )
    elif subscription == "play":
        own_plan.update(on_join="cancel_in_store", manage_url=STORE_SUBSCRIPTION_URLS[subscription])
        own_plan["message"] = gettext(
            "The team covers Premium Pro, so you can cancel your Google Play subscription to NewsBlur. "
            "NewsBlur can't cancel it for you."
        )
    return own_plan


def settle_own_plan_on_join(user, team, subscription):
    """Run by SettleOwnPlanOnJoin (apps/team/tasks.py) once a join has committed. A Stripe or PayPal renewal stops
    at the end of the period already paid for, with no refund, and the AI filter usage billing subscription keeps
    running. Either way the person gets one email saying what happened to their own plan."""
    if subscription in RENEWALS_TURNED_OFF_ON_JOIN:
        profile = Profile.objects.get(user=user)
        profile.cancel_premium_stripe()
        profile.cancel_premium_paypal()
        profile.setup_premium_history()
    send_own_plan_email(user, team, subscription)


def _plan_context(plan, profile):
    # grants.py: a trial's end stays in premium_expire, which team Pro never writes.
    return {"plan": plan, "plan_name": TIER_NAMES.get(plan), "trial_date": profile.premium_expire}


def send_seat_ended_email(user, team, plan):
    """Sent once a teammate's leaving or removal has committed (apps/team/models.py TeamMember.mark_removed).
    plan is what their account is on now."""
    profile = Profile.objects.get(user=user)
    if not user.email:
        logging.user(user, "~FMNot sending team seat ended email, no email address")
        return

    data = dict(user=user, team_name=team.name, **_plan_context(plan, profile))
    with account_translation(profile):
        text = render_to_string("mail/email_team_seat_ended.txt", data)
        html = render_to_string("mail/email_team_seat_ended.xhtml", data)
        subject = gettext("You're no longer on %(team)s") % {"team": team.name}
    _send(profile, subject, text, html, "team_seat_ended")


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


def send_own_plan_email(user, team, subscription):
    profile = Profile.objects.get(user=user)
    if not user.email:
        logging.user(user, "~FMNot sending team own plan email, no email address")
        return

    data = dict(
        user=user,
        team_name=team.name,
        subscription=subscription,
        paid_through=profile.premium_expire,
        manage_url=STORE_SUBSCRIPTION_URLS.get(subscription),
    )
    with account_translation(profile):
        text = render_to_string("mail/email_team_own_plan.txt", data)
        html = render_to_string("mail/email_team_own_plan.xhtml", data)
        subject_data = {"team": team.name}
        if subscription == "app_store":
            subject = (
                gettext("You're on %(team)s now, so you can cancel your App Store subscription")
                % subject_data
            )
        elif subscription == "play":
            subject = (
                gettext("You're on %(team)s now, so you can cancel your Google Play subscription")
                % subject_data
            )
        else:
            subject = gettext("Your own plan won't renew now that you're on %(team)s") % subject_data
    _send(profile, subject, text, html, "team_own_plan")


def _send(profile, subject, text, html, email_type):
    user = profile.user
    msg = EmailMultiAlternatives(
        one_line(subject),
        text,
        from_email="NewsBlur <%s>" % settings.HELLO_EMAIL,
        to=["%s <%s>" % (user, user.email)],
        headers=profile.email_unsubscribe_headers(),
    )
    msg.attach_alternative(html, "text/html")
    msg.send()
    MSentEmail.record(receiver_user_id=user.pk, email_type=email_type)
    logging.user(user, "~BB~FM~SBSending %s email" % email_type)
