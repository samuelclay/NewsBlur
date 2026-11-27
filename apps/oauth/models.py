from django.conf import settings
from django.db import models


class ApplicationWebsite(models.Model):
    application = models.OneToOneField(settings.OAUTH2_PROVIDER_APPLICATION_MODEL, on_delete=models.CASCADE)
    website = models.URLField(max_length=2048)
