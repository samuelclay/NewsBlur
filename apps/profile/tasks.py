"""Profile tasks: user lifecycle management including onboarding, premium tiers, and cleanup."""

import datetime

from django.conf import settings
from django.core.mail import EmailMultiAlternatives
from django.db.models import Count
from django.template.loader import render_to_string

from apps.profile.models import MGiftCode, MSentEmail, Profile, RNewUserQueue
from apps.reader.models import UserSubscription, UserSubscriptionFolders
from apps.social.models import MActivity, MInteraction, MSocialServices
from newsblur_web.celeryapp import app
from utils import log as logging


@app.task(name="email-new-user")
def EmailNewUser(user_id):
    user_profile = Profile.objects.get(user__pk=user_id)
    user_profile.send_new_user_email()


@app.task(name="email-new-premium")
def EmailNewPremium(user_id):
    user_profile = Profile.objects.get(user__pk=user_id)
    user_profile.send_new_premium_email()


@app.task()
def FetchArchiveFeedsForUser(user_id):
    # subs = UserSubscription.objects.filter(user=user_id)
    # user_profile = Profile.objects.get(user__pk=user_id)
    # logging.user(user_profile.user, f"~FCBeginning archive feed fetches for ~SB~FG{subs.count()} feeds~SN...")

    UserSubscription.fetch_archive_feeds_for_user(user_id)


@app.task()
def FetchArchiveFeedsChunk(feed_ids, user_id=None):
    # logging.debug(" ---> Fetching archive stories: %s for %s" % (feed_ids, user_id))
    UserSubscription.fetch_archive_feeds_chunk(feed_ids, user_id)


@app.task()
def FinishFetchArchiveFeeds(results, user_id, start_time, starting_story_count):
    # logging.debug(" ---> Fetching archive stories finished for %s" % (user_id))

    ending_story_count, pre_archive_count = UserSubscription.finish_fetch_archive_feeds(
        user_id, start_time, starting_story_count
    )

    user_profile = Profile.objects.get(user__pk=user_id)
    user_profile.send_new_premium_archive_email(ending_story_count, pre_archive_count)


@app.task(name="email-new-premium-pro")
def EmailNewPremiumPro(user_id):
    user_profile = Profile.objects.get(user__pk=user_id)
    user_profile.send_new_premium_pro_email()


@app.task(name="email-new-premium-trial")
def EmailNewPremiumTrial(user_id):
    user_profile = Profile.objects.get(user__pk=user_id)
    user_profile.send_premium_trial_welcome_email()


@app.task(name="email-staff-premium-upgrade")
def EmailStaffPremiumUpgrade(user_id, tier, previous_tier):
    from django.core.cache import cache

    # Deduplicate: only send one staff upgrade email per user+tier within 1 hour
    cache_key = f"staff_premium_upgrade_email:{user_id}:{tier}"
    if cache.get(cache_key):
        logging.debug(
            " ---> Skipping duplicate staff premium upgrade email for user_id=%s tier=%s" % (user_id, tier)
        )
        return
    cache.set(cache_key, True, timeout=3600)

    user_profile = Profile.objects.get(user__pk=user_id)
    user_profile.send_staff_premium_upgrade_email(tier=tier, previous_tier=previous_tier)


@app.task(name="premium-expire")
def PremiumExpire(**kwargs):
    now = datetime.datetime.now()

    # Handle trial expirations FIRST (no grace period for trials)
    expired_trials = Profile.objects.filter(
        is_premium=True,
        is_premium_trial=True,
        premium_expire__lte=now,
    )
    logging.debug(" ---> %s trial users have expired, downgrading..." % expired_trials.count())
    for profile in expired_trials:
        logging.debug(" ---> Expiring trial for user: %s" % profile.user.username)
        profile.send_premium_trial_expire_email()
        profile.deactivate_premium()
        profile.is_premium_trial = False
        profile.save()

    # Get expired paid premium users in grace period (2-30 days expired)
    # Exclude trial users (is_premium_trial != True)
    two_days_ago = now - datetime.timedelta(days=2)
    thirty_days_ago = now - datetime.timedelta(days=30)
    expired_profiles = Profile.objects.filter(
        is_premium=True,
        premium_expire__lte=two_days_ago,
        premium_expire__gt=thirty_days_ago,
    ).exclude(is_premium_trial=True)
    logging.debug(" ---> %s users have expired premiums, emailing grace..." % expired_profiles.count())
    for profile in expired_profiles:
        if profile.grace_period_email_sent():
            continue
        profile.setup_premium_history()
        if profile.premium_expire < two_days_ago:
            profile.send_premium_expire_grace_period_email()

    # Get fully expired paid premium users (30+ days expired)
    # Exclude trial users (is_premium_trial != True)
    expired_profiles = Profile.objects.filter(
        is_premium=True,
        premium_expire__lte=thirty_days_ago,
    ).exclude(is_premium_trial=True)
    logging.debug(
        " ---> %s users have expired premiums, deactivating and emailing..." % expired_profiles.count()
    )
    for profile in expired_profiles:
        profile.setup_premium_history()
        if profile.premium_expire < thirty_days_ago:
            profile.send_premium_expire_email()
            profile.deactivate_premium()


@app.task(name="activate-next-new-user")
def ActivateNextNewUser():
    RNewUserQueue.activate_next()


@app.task(name="cleanup-user")
def CleanupUser(user_id):
    UserSubscription.trim_user_read_stories(user_id)
    UserSubscription.verify_feeds_scheduled(user_id)
    Profile.count_all_feed_subscribers_for_user(user_id)
    MInteraction.trim(user_id)
    MActivity.trim(user_id)
    UserSubscriptionFolders.add_missing_feeds_for_user(user_id)
    UserSubscriptionFolders.compact_for_user(user_id)
    UserSubscription.refresh_stale_feeds(user_id)

    try:
        ss = MSocialServices.objects.get(user_id=user_id)
    except MSocialServices.DoesNotExist:
        logging.debug(" ---> ~FRCleaning up user, can't find social_services for user_id: ~SB%s" % user_id)
        return
    ss.sync_twitter_photo()


@app.task(name="clean-spam")
def CleanSpam():
    logging.debug(" ---> Finding spammers...")
    Profile.clear_dead_spammers(confirm=True)


@app.task(name="reimport-stripe-history")
def ReimportStripeHistory():
    logging.debug(" ---> Reimporting Stripe history...")
    Profile.reimport_stripe_history(limit=10, days=1)


@app.task(name="email-premium-renewal-notice")
def EmailPremiumRenewalNotice():
    """Daily task to email users who opted in to renewal notifications 3 days before charge."""
    logging.debug(" ---> Checking for premium renewal notice emails...")
    now = datetime.datetime.now()
    three_days = now + datetime.timedelta(days=3)
    four_days = now + datetime.timedelta(days=4)

    profiles = (
        Profile.objects.filter(
            is_premium=True,
            premium_renewal=True,
            premium_expire__gte=three_days,
            premium_expire__lt=four_days,
        )
        .exclude(is_premium_trial=True)
        .select_related("user")
    )

    logging.debug(" ---> %s users renewing in ~3 days, checking preferences..." % profiles.count())
    for profile in profiles:
        if not profile.preference_value("notify_before_renewal", default=False):
            continue
        profile.send_premium_renewal_notice_email()


@app.task(name="email-feed-limit-notifications")
def EmailFeedLimitNotifications():
    """
    Daily task to email grandfathered users 7 days before their renewal date.

    Grandfathering is done once at launch via: manage.py grandfather_premium_users
    """
    logging.debug(" ---> Checking for feed limit notification emails...")
    now = datetime.datetime.now(datetime.timezone.utc)
    one_year_ago = now - datetime.timedelta(days=365)
    days_before = 7

    window_start = now
    window_end = now + datetime.timedelta(days=days_before)

    profiles = Profile.objects.filter(
        is_premium=True,
        is_archive=False,
        is_pro=False,
        is_grandfathered=True,
        grandfather_expires__isnull=False,
        grandfather_expires__gte=window_start,
        grandfather_expires__lte=window_end,
    ).select_related("user")

    user_ids = list(profiles.values_list("user_id", flat=True))
    feed_counts = dict(
        UserSubscription.objects.filter(user_id__in=user_ids, active=True)
        .values("user_id")
        .annotate(feed_count=Count("id"))
        .values_list("user_id", "feed_count")
    )

    for profile in profiles:
        user = profile.user
        feed_count = feed_counts.get(user.pk, 0)

        # Skip inactive users (no login in past year)
        last_seen = profile.last_seen_on
        if last_seen.tzinfo is None:
            last_seen = last_seen.replace(tzinfo=datetime.timezone.utc)
        if last_seen < one_year_ago:
            continue

        # Skip if already sent
        if (
            MSentEmail.objects.filter(receiver_user_id=user.pk, email_type="feed_limit_notification").count()
            > 0
        ):
            continue

        deadline = profile.grandfather_expires
        if deadline.tzinfo is None:
            deadline = deadline.replace(tzinfo=datetime.timezone.utc)
        deadline_date = deadline.strftime("%B %d, %Y")

        # Send email
        params = {
            "user": user,
            "username": user.username,
            "feed_count": f"{feed_count:,}",
            "deadline_date": deadline_date,
        }
        text = render_to_string("mail/email_feed_limit_notification.txt", params)
        html = render_to_string("mail/email_feed_limit_notification.xhtml", params)
        subject = f"Your NewsBlur subscription and your {feed_count:,} sites"

        msg = EmailMultiAlternatives(
            subject,
            text,
            from_email=f"NewsBlur <{settings.HELLO_EMAIL}>",
            to=[f"{user.username} <{user.email}>"],
        )
        msg.attach_alternative(html, "text/html")
        msg.send()

        MSentEmail.record(receiver_user_id=user.pk, email_type="feed_limit_notification")
        logging.user(
            user, f"~BB~FM~SBSent feed limit notification: {feed_count:,} feeds, deadline: {deadline_date}"
        )


@app.task(name="refund-unredeemed-gifts")
def RefundUnredeemedGifts():
    import stripe

    from django.conf import settings

    stripe.api_key = settings.STRIPE_SECRET
    now = datetime.datetime.now()

    expired_gifts = MGiftCode.objects.filter(
        expires_date__lte=now,
        redeemed_date=None,
        stripe_payment_intent_id__ne=None,
        stripe_refund_id=None,
        is_staff_gift=False,
    )

    logging.debug(" ---> Checking %s expired unredeemed gifts for auto-refund..." % expired_gifts.count())

    for gift in expired_gifts:
        try:
            refund = stripe.Refund.create(payment_intent=gift.stripe_payment_intent_id)
            gift.stripe_refund_id = refund.id
            gift.save()
            logging.debug(
                " ---> Auto-refunded gift %s (payment_intent: %s, refund: %s)"
                % (gift.gift_code, gift.stripe_payment_intent_id, refund.id)
            )
        except Exception as e:
            logging.debug(
                " ---> Failed to auto-refund gift %s: %s" % (gift.gift_code, e)
            )


@app.task(name="email-referral-credit")
def EmailReferralCredit(referrer_user_id, referred_username, credit_days, referrer_tier):
    try:
        profile = Profile.objects.get(user__pk=referrer_user_id)
    except Profile.DoesNotExist:
        return

    tier_names = {"premium": "Premium", "archive": "Premium Archive", "pro": "Premium Pro"}
    tier_name = tier_names.get(referrer_tier, "Premium")

    if credit_days >= 365:
        credit_text = "%s year%s" % (credit_days // 365, "s" if credit_days >= 730 else "")
    elif credit_days >= 30:
        credit_text = "%s month%s" % (credit_days // 30, "s" if credit_days >= 60 else "")
    else:
        credit_text = "%s day%s" % (credit_days, "s" if credit_days != 1 else "")

    params = {
        "username": profile.user.username,
        "referred_username": referred_username,
        "credit_text": credit_text,
        "tier_name": tier_name,
    }
    text = render_to_string("mail/email_referral_credit.txt", params)
    html = render_to_string("mail/email_referral_credit.xhtml", params)
    subject = "You earned free %s from a referral!" % tier_name
    msg = EmailMultiAlternatives(
        subject,
        text,
        from_email="NewsBlur <%s>" % settings.HELLO_EMAIL,
        to=["%s <%s>" % (profile.user.username, profile.user.email)],
    )
    msg.attach_alternative(html, "text/html")
    msg.send()

    MSentEmail.record(receiver_user_id=referrer_user_id, email_type="referral_credit")
    logging.user(
        profile.user,
        "~BB~FM~SBSent referral credit email: %s earned %s of %s"
        % (profile.user.username, credit_text, tier_name),
    )
