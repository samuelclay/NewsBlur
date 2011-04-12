from django.db import models

from vendor.timezones.fields import TimeZoneField



class Profile(models.Model):
    name = models.CharField(max_length=100)
    timezone = TimeZoneField()
