"""Premium Pro for teammates: granting it with a seat, what joining does to a plan the person pays for on their
own, releasing it back to the person's own plan the moment the seat ends, and a team lapsing or coming back
(apps/team/models.py TeamProGrant)."""

import datetime

import dateutil.parser
import paypalrestsdk
import redis
import requests
import stripe
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
# grants.py: what Stripe and PayPal report for a subscription that renews, and for one that won't renew again.
STRIPE_ENDED_STATUSES = ("canceled", "incomplete_expired")
PAYPAL_RENEWING_STATUSES = ("ACTIVE", "APPROVED", "APPROVAL_PENDING")
PAYPAL_STOPPED_STATUSES = ("SUSPENDED", "CANCELLED", "EXPIRED")
# grants.py: the same for a subscription made through PayPal's Classic API (GetRecurringPaymentsProfileDetails).
PAYPAL_CLASSIC_RENEWING_STATUSES = ("Active", "Pending")
PAYPAL_CLASSIC_STOPPED_STATUSES = ("Cancelled", "Suspended", "Expired")
PROVIDER_ERRORS = (
    stripe.error.StripeError,
    paypalrestsdk.exceptions.ConnectionError,
    requests.exceptions.RequestException,
)


def grant_team_pro(member, own_plan_replaced=False):
    """Give an active teammate Premium Pro by setting the real tier flags on their profile. Unlike
    Profile.activate_pro it sends no welcome or staff email, writes no payment row and leaves premium_expire
    as the person's own paid through date. Every grant, a rejoin's too, snapshots the plan the person has on their
    own from their profile. A profile carries team Pro only while its grant exists, and there is one grant per
    person, so the snapshot is never team Pro. An owner's can be the Pro a lapse left them until PremiumExpire
    (release_team_pro), which counts for no longer than their premium_expire. The owner's grant comes from
    apps/team/billing.py, and with own_plan_replaced the payment took the place of their own plan, so there is
    none to go back to. An owner's grant also keeps when their own plan ends, since their premium_expire follows the
    team's paid period from then on."""
    user = member.user
    with transaction.atomic():
        profile = Profile.objects.select_for_update().get(user=user)
        own_tier = TeamProGrant.TIER_FREE if own_plan_replaced else TeamProGrant.tier_of(profile)
        grant = TeamProGrant.objects.create(
            user=user,
            member=member,
            own_tier=own_tier,
            own_trial_expire=profile.premium_expire if own_tier == TeamProGrant.TIER_TRIAL else None,
            own_premium_trial=profile.is_premium_trial,
            own_lifetime=own_tier in TeamProGrant.PAID_TIERS and profile.premium_expire is None,
            own_premium_expire=profile.premium_expire if member.role == TeamMember.ROLE_OWNER else None,
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


def release_team_pro(user, owner=False, taken_back=False):
    """End a person's team Pro and put them on their own plan: the tier they pay for while their own
    premium_expire covers today, or for good when it never ended, a trial that is still running, or otherwise
    free through Profile.deactivate_premium, which mutes every site until they choose the ones to keep. With
    owner, the end of their own plan is the one their grant keeps (_own_plan_expire), and it becomes their
    premium_expire again. The team's owner with no plan of their own to go back to keeps the Pro flags instead, and
    their account expires through PremiumExpire (apps/profile/tasks.py) as any lapsed plan does: from the end of the
    team's paid period, or from now with taken_back, when the payment for that period was taken back. Returns the
    plan they are on now, or None when they held no grant or are an owner keeping Pro until it expires."""
    now = datetime.datetime.now()
    with transaction.atomic():
        profile = Profile.objects.select_for_update().get(user=user)
        grant = TeamProGrant.objects.select_for_update().filter(user=user).first()
        if not grant:
            return None
        own_expire = _own_plan_expire(user, grant) if owner else profile.premium_expire
        plan = grant.own_plan_on(own_expire, now)
        grant.delete()
        if plan == TeamProGrant.TIER_FREE and owner:
            plan = None
            if profile.premium_expire is None or (taken_back and profile.premium_expire > now):
                # grants.py: a comp gives its owner no paid through date, and a payment taken back no longer pays
                # for one, so the expiry window starts now.
                Profile.objects.filter(pk=profile.pk).update(premium_expire=now)
        elif plan == TeamProGrant.TIER_FREE:
            # grants.py: an account that never had a trial can still start one. Any other has used it, including
            # one whose trial ran out during the seat.
            profile.is_premium_trial = None if grant.own_premium_trial is None else False
            profile.deactivate_premium()
        else:
            flags = dict(TeamProGrant.TIER_FLAGS[plan])
            if grant.own_lifetime:
                flags["premium_expire"] = None
            elif owner and own_expire:
                flags["premium_expire"] = own_expire
            Profile.objects.filter(pk=profile.pk).update(**flags)
        transaction.on_commit(lambda: _reload_feeds(profile.user))
    logging.user(profile.user, "~FMTeam Pro released, back on %s" % (plan or "Pro until it expires"))
    return plan


def _own_plan_expire(user, grant):
    """grants.py: when the plan a team's owner has on their own ends. Their premium_expire followed the team's paid
    period (apps/team/billing.py), so it is the later of the end their grant keeps (TeamProGrant.own_premium_expire)
    and the end their own payments give, leaving out payments for a team plan."""
    paid_through, _, _ = Profile.premium_expire_from_payments(
        PaymentHistory.objects.filter(user=user).exclude(Profile.team_payments())
    )
    return max((end for end in (grant.own_premium_expire, paid_through) if end), default=None)


def seat_grant_for_former_owner(user, held_as_owner):
    """The grant of a team's owner who handed it to a teammate and keeps a seat on it (apps/team/billing.py
    _hand_over), shaped as a teammate's: it remembers the plan they are on by themselves now, never the team's Pro or
    the team plan they paid for, and keeps no end of it, since their premium_expire, which followed the team's paid
    period while they owned it, is that end again. held_as_owner is False for the grant a lapsed team gave them as a
    teammate when it came back (activate_team), which snapshot their profile after the lapse: the Pro a lapse leaves
    an owner with no plan of their own until it expires (release_team_pro) is no plan of theirs."""
    now = datetime.datetime.now()
    with transaction.atomic():
        profile = Profile.objects.select_for_update().get(user=user)
        grant = TeamProGrant.objects.select_for_update().filter(user=user).first()
        if not grant:
            return
        own_expire = _own_plan_expire(user, grant) if held_as_owner else profile.premium_expire
        own_tier = grant.own_plan_on(own_expire, now)
        TeamProGrant.objects.filter(pk=grant.pk).update(own_tier=own_tier, own_premium_expire=None)
        if held_as_owner:
            open_ended_plan = grant.own_lifetime and own_tier in TeamProGrant.PAID_TIERS
            Profile.objects.filter(pk=profile.pk).update(
                premium_expire=None if open_ended_plan else own_expire
            )
    logging.user(user, "~FMTeam Pro: handed the team on, own plan is %s" % own_tier)


def deactivate_team(team, lapsed_at=None, taken_back=False):
    """Billing calls this when the owner's paid period ends without a payment, or the payment was taken back
    (taken_back). The team goes inactive, every teammate's Premium Pro ends at once, the owner goes back to a plan of
    their own (release_team_pro), and each of them gets one email. Members, roles, invites and settings stay as they
    are. With lapsed_at, as from the hourly task, the team ends only if it has still lapsed at that moment once its
    row is locked (Team.lapsed), so a renewal committed after the task chose it keeps it. Each email goes out from
    its own task once the lapse has committed."""
    # grants.py: apps/team/tasks.py imports this module.
    from apps.team.tasks import EmailTeamPlanEnded

    with transaction.atomic():
        team = team.lock()
        if team.status == Team.STATUS_INACTIVE:
            return
        if lapsed_at and not Team.objects.filter(Team.lapsed(lapsed_at), pk=team.pk).exists():
            return
        team.status = Team.STATUS_INACTIVE
        team.save(update_fields=["status", "updated_date"])
        TeamActivity.log(team, None, "team_deactivated")
        members = list(team.active_members())
        plans = {}
        for grant in TeamProGrant.objects.filter(member__in=members).select_related("user"):
            plans[grant.user_id] = release_team_pro(
                grant.user, owner=grant.user_id == team.owner_id, taken_back=taken_back
            )
        for member in members:
            transaction.on_commit(
                lambda user_id=member.user_id: EmailTeamPlanEnded.delay(
                    user_id=user_id, team_id=team.pk, plan=plans.get(user_id)
                )
            )


def activate_team(team):
    """Billing calls this when a payment for the team succeeds. The team is active again and every teammate
    gets Premium Pro back, with a fresh snapshot of their own plan. The owner's grant comes from the payment
    (apps/team/billing.py)."""
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


def renewing_subscriptions(user, joined_at):
    """The Stripe and PayPal subscriptions this person pays for on their own that renew and were made before they
    joined, at joined_at, a Unix time, as [provider, id] pairs. One made after joining is a plan they bought since,
    which is theirs to keep. The AI filter usage billing subscription isn't one. None when PayPal can't say whether
    one renews. Errors from Stripe or PayPal reach the caller (apps/team/tasks.py SettleOwnPlanOnJoin), which
    retries."""
    profile = Profile.objects.get(user=user)
    renewing = []
    if profile.stripe_id:
        stripe.api_key = settings.STRIPE_SECRET
        for customer_id in user.stripe_ids.values_list("stripe_id", flat=True):
            for subscription in stripe.Subscription.list(customer=customer_id).data:
                if (
                    subscription.cancel_at_period_end
                    or subscription.status in STRIPE_ENDED_STATUSES
                    or Profile.is_usage_billing_subscription(subscription)
                    or subscription["created"] >= joined_at
                ):
                    continue
                renewing.append(["stripe", subscription.id])
    paypal_ids = user.paypal_ids.values_list("paypal_sub_id", flat=True) if profile.paypal_sub_id else []
    for paypal_id in paypal_ids:
        renews, created = _paypal_subscription(profile, paypal_id)
        if renews is None:
            logging.user(user, "~FRCouldn't read own PayPal subscription %s on joining a team" % paypal_id)
            return None
        if renews and created < joined_at:
            renewing.append(["paypal", paypal_id])
    return renewing


def _paypal_subscription(profile, paypal_id):
    """(renews, created) for one of this person's PayPal subscriptions: True or False once PayPal says whether it
    renews, None when it can't be read, and when it was made, as a Unix time. A subscription made through PayPal's
    Classic API is unknown to the REST API, so it is read through the Classic path, as
    Profile.cancel_premium_paypal cancels it."""
    try:
        subscription = profile.paypal_api().get("/v1/billing/subscriptions/%s" % paypal_id)
    except paypalrestsdk.ResourceNotFound:
        classic_api = profile.paypal_classic_api()
        if not classic_api:
            return None, None
        details = classic_api.get_recurring_payments_profile_details(paypal_id)
        return (
            _renews(details["STATUS"], PAYPAL_CLASSIC_RENEWING_STATUSES, PAYPAL_CLASSIC_STOPPED_STATUSES),
            _unix_time(details["PROFILESTARTDATE"]),
        )
    return (
        _renews(subscription["status"], PAYPAL_RENEWING_STATUSES, PAYPAL_STOPPED_STATUSES),
        _unix_time(subscription["create_time"]),
    )


def _renews(status, renewing_statuses, stopped_statuses):
    if status in renewing_statuses:
        return True
    if status in stopped_statuses:
        return False
    return None


def _unix_time(provider_date):
    return dateutil.parser.parse(provider_date).timestamp()


def settle_own_plan_on_join(user, team, subscription, joined_at):
    """Run by SettleOwnPlanOnJoin (apps/team/tasks.py) once a join has committed. The Stripe and PayPal renewals
    made before the join stop at the end of the period already paid for, with no refund, and the AI filter usage
    billing subscription keeps running. The person gets one email saying what happened to their own plan, sent
    only once Stripe or PayPal confirms each renewal is off. Returns False when that can't be confirmed, and then
    nothing is sent."""
    if subscription in RENEWALS_TURNED_OFF_ON_JOIN:
        renewing = renewing_subscriptions(user, joined_at)
        if renewing is None or not _turn_off_renewals(user, renewing):
            return False
    send_own_plan_email(user, team, subscription)
    return True


def _turn_off_renewals(user, renewing):
    profile = Profile.objects.get(user=user)
    stripe_ids = [subscription_id for provider, subscription_id in renewing if provider == "stripe"]
    paypal_ids = [subscription_id for provider, subscription_id in renewing if provider == "paypal"]
    try:
        if stripe_ids:
            profile.cancel_premium_stripe(subscription_ids=stripe_ids)
        if paypal_ids:
            profile.cancel_premium_paypal(force=True, subscription_ids=paypal_ids)
        stopped = all(
            _renewal_stopped(profile, provider, subscription_id) for provider, subscription_id in renewing
        )
    except PROVIDER_ERRORS as e:
        logging.user(user, "~FRCouldn't turn off own renewal on joining a team: %s" % e)
        return False
    profile.setup_premium_history()
    return stopped


def _renewal_stopped(profile, provider, subscription_id):
    """Whether Stripe or PayPal says this subscription won't renew again."""
    if provider == "stripe":
        stripe.api_key = settings.STRIPE_SECRET
        subscription = stripe.Subscription.retrieve(subscription_id)
        return bool(subscription.cancel_at_period_end) or subscription.status in STRIPE_ENDED_STATUSES
    renews, _ = _paypal_subscription(profile, subscription_id)
    return renews is False


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


def send_team_welcome_email(team):
    """Sent by EmailTeamWelcome (apps/team/tasks.py) once the first payment for a team has committed. The link
    opens the team dialog, which asks the owner for the team's name first."""
    owner = team.owner
    profile = Profile.objects.get(user=owner)
    if not owner.email:
        logging.user(owner, "~FMNot sending team welcome email, no email address")
        return

    data = dict(user=owner, plan_name=TIER_NAMES.get(team.plan), seats=team.seat_limit)
    with account_translation(profile):
        text = render_to_string("mail/email_team_welcome.txt", data)
        html = render_to_string("mail/email_team_welcome.xhtml", data)
        subject = gettext("Your %(plan)s plan has started") % {"plan": TIER_NAMES.get(team.plan)}
    _send(profile, subject, text, html, "team_welcome")


def send_transfer_requested_email(team):
    """Sent by EmailTeamTransferRequested (apps/team/tasks.py) to the teammate the owner asked to take the team over
    (Team.request_transfer). It says what taking it over costs them, and the link opens the team dialog, where they
    accept or decline."""
    user = team.pending_owner
    profile = Profile.objects.get(user=user)
    if not user.email:
        logging.user(user, "~FMNot sending team transfer request email, no email address")
        return

    data = dict(
        user=user,
        owner=team.owner,
        team_name=team.name,
        plan_name=TIER_NAMES.get(team.plan),
        comped=team.is_comped,
        price=Team.MONTHLY_PRICES[team.plan],
        store_price=Team.STORE_MONTHLY_PRICES[team.plan],
        expire_date=team.transfer_expire_date,
    )
    with account_translation(profile):
        text = render_to_string("mail/email_team_transfer_requested.txt", data)
        html = render_to_string("mail/email_team_transfer_requested.xhtml", data)
        subject = gettext("%(username)s asked you to take over %(team)s") % {
            "username": team.owner.username,
            "team": team.name,
        }
    _send(profile, subject, text, html, "team_transfer_requested")


def send_new_owner_email(team, former_owner):
    """Sent by EmailTeamNewOwner (apps/team/tasks.py) once a team has changed hands (apps/team/billing.py
    _hand_over)."""
    user = team.owner
    profile = Profile.objects.get(user=user)
    if not user.email:
        logging.user(user, "~FMNot sending team new owner email, no email address")
        return

    data = dict(
        user=user,
        former_owner=former_owner,
        team_name=team.name,
        plan_name=TIER_NAMES.get(team.plan),
        comped=team.is_comped,
    )
    with account_translation(profile):
        text = render_to_string("mail/email_team_new_owner.txt", data)
        html = render_to_string("mail/email_team_new_owner.xhtml", data)
        subject = gettext("You own %(team)s now") % {"team": team.name}
    _send(profile, subject, text, html, "team_new_owner")


def send_former_owner_email(user, team, provider, refund):
    """Sent by SettleHandOver (apps/team/tasks.py) to a team's old owner once its hand over has committed and their
    subscription for it was settled (apps/team/billing.py settle_former_owners_plan). It says what happens to that
    subscription: the dollars refunded on Stripe or PayPal, and the link to cancel it in a store, which only they
    can do."""
    profile = Profile.objects.get(user=user)
    if not user.email:
        logging.user(user, "~FMNot sending team former owner email, no email address")
        return

    data = dict(
        user=user,
        new_owner=team.owner,
        team_name=team.name,
        provider=provider,
        refund=refund,
        manage_url=STORE_SUBSCRIPTION_URLS.get(provider),
    )
    with account_translation(profile):
        text = render_to_string("mail/email_team_former_owner.txt", data)
        html = render_to_string("mail/email_team_former_owner.xhtml", data)
        subject = gettext("%(username)s owns %(team)s now") % {
            "username": team.owner.username,
            "team": team.name,
        }
    _send(profile, subject, text, html, "team_former_owner")


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
