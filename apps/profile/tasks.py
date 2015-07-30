import datetime
from celery.task import Task
from apps.profile.models import Profile, RNewUserQueue
from utils import log as logging
from apps.reader.models import UserSubscription
from apps.social.models import MSocialServices

class EmailNewUser(Task):
    
    def run(self, user_id):
        user_profile = Profile.objects.get(user__pk=user_id)
        user_profile.send_new_user_email()

class EmailNewPremium(Task):
    
    def run(self, user_id):
        user_profile = Profile.objects.get(user__pk=user_id)
        user_profile.send_new_premium_email()

class PremiumExpire(Task):
    name = 'premium-expire'
    
    def run(self, **kwargs):
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


class ActivateNextNewUser(Task):
    name = 'activate-next-new-user'
    
    def run(self):
        RNewUserQueue.activate_next()


class CleanupUser(Task):
    name = 'cleanup-user'
    
    def run(self, user_id):
        UserSubscription.trim_user_read_stories(user_id)
        UserSubscription.verify_feeds_scheduled(user_id)
        Profile.count_all_feed_subscribers_for_user(user_id)
        # UserSubscription.refresh_stale_feeds(user_id)
        
        try:
            ss = MSocialServices.objects.get(user_id=user_id)
        except MSocialServices.DoesNotExist:
            logging.debug(" ---> ~FRCleaning up user, can't find social_services for user_id: ~SB%s" % user_id)
            return
        ss.sync_twitter_photo()

