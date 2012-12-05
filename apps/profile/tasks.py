import datetime
from celery.task import Task
from apps.profile.models import Profile
from utils import log as logging


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
        five_days_ago = datetime.datetime.now() - datetime.timedelta(days=5)
        expired_profiles = Profile.objects.filter(is_premium=True, 
                                                  premium_expire__lte=five_days_ago)
        logging.debug(" ---> %s users have expired premiums, emailing grace..." % expired_profiles.count())
        for profile in expired_profiles:
            profile.send_premium_expire_grace_period_email()
            
        # Get fully expired users
        thirty_days_ago = datetime.datetime.now() - datetime.timedelta(days=30)
        expired_profiles = Profile.objects.filter(is_premium=True,
                                                  premium_expire__lte=thirty_days_ago)
        logging.debug(" ---> %s users have expired premiums, deactivating and emailing..." % expired_profiles.count())
        for profile in expired_profiles:
            profile.send_premium_expire_email()
            # profile.deactive_premium()
