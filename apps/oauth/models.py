from django.conf import settings
from django.db import models


class ApplicationWebsite(models.Model):
    application = models.OneToOneField(settings.OAUTH2_PROVIDER_APPLICATION_MODEL, on_delete=models.CASCADE)
    website = models.URLField(max_length=2048)


class ApplicationExemption(models.Model):
    """Keeps an application working while its owner lacks Premium Pro (apps/oauth/access.py). Staff add and
    remove exemptions in the Django admin (apps/oauth/admin.py)."""

    # oauth.0004_applicationexemption adds this foreign key itself, with ON DELETE CASCADE, so the database
    # removes an application's exemption. A release that predates this model can't cascade the deletion in
    # Python, and Django's own constraint would then refuse to delete the application or its owner.
    application = models.OneToOneField(
        settings.OAUTH2_PROVIDER_APPLICATION_MODEL, on_delete=models.CASCADE, db_constraint=False
    )
    created = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.application} (#{self.application_id})"
