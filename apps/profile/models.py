import datetime
from django.db import models
from django.contrib.auth.models import User
from django.db.models.signals import post_save
from apps.reader.models import UserSubscription
from paypal.standard.ipn.signals import subscription_signup
     
class Profile(models.Model):
    user = models.OneToOneField(User, unique=True, related_name="profile")
    is_premium = models.BooleanField(default=False)
    preferences = models.TextField(default="{}")
    view_settings = models.TextField(default="{}")
    collapsed_folders = models.TextField(default="[]")
    last_seen_on = models.DateTimeField(default=datetime.datetime.now)
    last_seen_ip = models.CharField(max_length=50, blank=True, null=True)
    
def create_profile(sender, instance, created, **kwargs):
    if created:
        Profile.objects.create(user=instance)
    else:
        Profile.objects.get_or_create(user=instance)
post_save.connect(create_profile, sender=User)


def paypal_signup(sender, **kwargs):
    ipn_obj = sender
    
    user = User.objects.get(username=ipn_obj.custom)
    user.profile.is_premium = True
    user.profile.save()

    subs = UserSubscription.objects.filter(user=user)
    for sub in subs:
        sub.active = True
        sub.save()
        sub.feed.setup_feed_for_premium_subscribers()
subscription_signup.connect(paypal_signup)