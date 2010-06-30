import datetime
from django.db import models
from django.contrib.auth.models import User
from django.db.models.signals import post_save
     
class Profile(models.Model):
    user = models.OneToOneField(User, unique=True, related_name="profile")
    view_settings = models.TextField(default="{}")
    last_seen_on = models.DateTimeField(default=datetime.datetime.now)
    last_seen_ip = models.CharField(max_length=50, blank=True, null=True)
    
def create_profile(sender, instance, created, **kwargs):
    if created:
        Profile.objects.create(user=instance)
    else:
        Profile.objects.get_or_create(user=instance)
post_save.connect(create_profile, sender=User)