import datetime
from django.db import models
from django.db import IntegrityError
from django.contrib.auth.models import User
from django.db.models.signals import post_save
from django.core.mail import mail_admins
from django.contrib.auth import authenticate
from apps.reader.models import UserSubscription
from apps.rss_feeds.models import Feed
from apps.feed_import.models import queue_new_feeds
from paypal.standard.ipn.signals import subscription_signup
from utils import log as logging
from utils.timezones.fields import TimeZoneField
     
class Profile(models.Model):
    user = models.OneToOneField(User, unique=True, related_name="profile")
    is_premium = models.BooleanField(default=False)
    preferences = models.TextField(default="{}")
    view_settings = models.TextField(default="{}")
    collapsed_folders = models.TextField(default="[]")
    last_seen_on = models.DateTimeField(default=datetime.datetime.now)
    last_seen_ip = models.CharField(max_length=50, blank=True, null=True)
    timezone = TimeZoneField(default="America/New_York")
    
    def __unicode__(self):
        return "%s" % self.user
        
    def activate_premium(self):
        self.is_premium = True
        self.save()
        
        subs = UserSubscription.objects.filter(user=self.user)
        for sub in subs:
            sub.active = True
            try:
                sub.save()
                sub.feed.setup_feed_for_premium_subscribers()
            except IntegrityError, Feed.DoesNotExist:
                pass
        
        queue_new_feeds(self.user)
        
        logging.info(' ---> [%s] ~SK~BGNEW PREMIUM ACCOUNT! WOOHOO!!! ~SB%s subscriptions~SN!' % (self.user.username, subs.count()))
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

def change_password(user, old_password, new_password):
    user_db = authenticate(username=user.username, password=old_password)
    if user_db is None:
        return -1
    else:
        user_db.set_password(new_password)
        user_db.save()
        return 1