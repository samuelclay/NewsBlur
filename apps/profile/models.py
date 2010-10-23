import datetime
from django.db import models
from django.contrib.auth.models import User
from django.db.models.signals import post_save
from django.core.mail import mail_admins
from apps.reader.models import UserSubscription
from paypal.standard.ipn.signals import subscription_signup
from utils import log as logging
     
class Profile(models.Model):
    user = models.OneToOneField(User, unique=True, related_name="profile")
    is_premium = models.BooleanField(default=False)
    preferences = models.TextField(default="{}")
    view_settings = models.TextField(default="{}")
    collapsed_folders = models.TextField(default="[]")
    last_seen_on = models.DateTimeField(default=datetime.datetime.now)
    last_seen_ip = models.CharField(max_length=50, blank=True, null=True)
    
    def __unicode__(self):
        return "%s" % self.user
        
    def activate_premium(self):
        self.is_premium = True
        self.save()
        
        subs = UserSubscription.objects.filter(user=self.user)
        for sub in subs:
            sub.active = True
            sub.save()
            sub.feed.setup_feed_for_premium_subscribers()
        
        logging.info(' ---> [%s] NEW PREMIUM ACCOUNT! WOOHOO!!! %s subscriptions!' % (self.user.username, subs.count()))
        message = """Woohoo!
        
User: %(user)s
Feeds: %(feeds)s

Sincerely,
NewsBlur""" % {'user': self.user.username, 'feeds': subs.count()}
        mail_admins('New premium account', message, fail_silently=True)
        
def create_profile(sender, instance, created, **kwargs):
    if created:
        Profile.objects.create(user=instance)
    else:
        Profile.objects.get_or_create(user=instance)
post_save.connect(create_profile, sender=User)


def paypal_signup(sender, **kwargs):
    ipn_obj = sender
    user = User.objects.get(username=ipn_obj.custom)
    user.profile.activate_premium()
subscription_signup.connect(paypal_signup)