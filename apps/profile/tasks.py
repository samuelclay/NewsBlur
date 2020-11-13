import datetime
from newsblur.celeryapp import app
from apps.profile.models import Profile, RNewUserQueue
from utils import log as logging
from apps.reader.models import UserSubscription, UserSubscriptionFolders
from apps.social.models import MSocialServices, MActivity, MInteraction

@app.task(name="email-new-user")
def EmailNewUser(user_id):
    user_profile = Profile.objects.get(user__pk=user_id)
    user_profile.send_new_user_email()

@app.task(name="email-new-premium")
def EmailNewPremium(user_id):
    user_profile = Profile.objects.get(user__pk=user_id)
    user_profile.send_new_premium_email()

@app.task(name="premium-expire")
def PremiumExpire(**kwargs):
    # Get expired but grace period users
    two_days_ago = datetime.datetime.now() - datetime.timedelta(days=2)
    thirty_days_ago = datetime.datetime.now() - datetime.timedelta(days=30)
    expired_profiles = Profile.objects.filter(is_premium=True, 
                                                premium_expire__lte=two_days_ago,
                                                premium_expire__gt=thirty_days_ago)
    logging.debug(" ---> %s users have expired premiums, emailing grace..." % expired_profiles.count())
    for profile in expired_profiles:
        if profile.grace_period_email_sent():
            continue
        profile.setup_premium_history()
        if profile.premium_expire < two_days_ago:
            profile.send_premium_expire_grace_period_email()
        
    # Get fully expired users
    expired_profiles = Profile.objects.filter(is_premium=True,
                                                premium_expire__lte=thirty_days_ago)
    logging.debug(" ---> %s users have expired premiums, deactivating and emailing..." % expired_profiles.count())
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
    # UserSubscription.refresh_stale_feeds(user_id)
    
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
            

