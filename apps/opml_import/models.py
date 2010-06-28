from django.db import models
from django.contrib.auth.models import User
from apps.rss_feeds.models import Feed, Story
import datetime

class OAuthToken(models.Model):
    user = models.OneToOneField(User)
    request_token = models.CharField(max_length=50)
    request_token_secret = models.CharField(max_length=50)
    access_token = models.CharField(max_length=50)
    access_token_secret = models.CharField(max_length=50)