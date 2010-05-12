from django.db import models
from django.contrib.auth.models import User
from django.db.models.signals import post_save
     
class Profile(models.Model):
    user = models.OneToOneField(User, unique=True, related_name="profile")
    view_setting = models.TextField(default="{}")
    
def create_profile(sender, instance, created, **kwargs):
    if created:
        Profile.objects.create(user=instance)
post_save.connect(create_profile, sender=User)