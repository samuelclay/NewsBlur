import datetime

from django.conf import settings
from django.core.mail import EmailMultiAlternatives
from django.db.models import Count
from django.template.loader import render_to_string

from apps.profile.models import MSentEmail, Profile, RNewUserQueue
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
        if MSentEmail.objects.filter(receiver_user_id=user.pk, email_type="feed_limit_notification").exists():
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
