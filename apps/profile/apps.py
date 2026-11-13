from urllib.parse import urlparse

from django.apps import AppConfig
from django.db import DEFAULT_DB_ALIAS
from django.db.models.signals import post_migrate

# The domain django.contrib.sites gives the first Site on a fresh database.
DJANGO_PLACEHOLDER_DOMAIN = "example.com"


def sync_default_site_domain(using=DEFAULT_DB_ALIAS, **kwargs):
    """Point a fresh install's Site at NEWSBLUR_URL (apps/profile/apps.py).

    Absolute links such as the default profile photo are built from the current Site's domain,
    which Django creates as example.com. Runs after every migrate, so a self-hosted install picks
    up NEWSBLUR_URL on its next `make`, but only replaces the placeholder: a domain someone has
    already set, like production's, is left alone.
    """
    from django.conf import settings
    from django.contrib.sites.models import Site

    domain = urlparse(settings.NEWSBLUR_URL).netloc
    if not domain:
        return

    site = Site.objects.using(using).filter(pk=settings.SITE_ID).first()
    if site is None or site.domain != DJANGO_PLACEHOLDER_DOMAIN:
        return

    site.domain = domain
    site.name = domain
    site.save(using=using)


class ProfileConfig(AppConfig):
    name = "apps.profile"
    verbose_name = "Profile"

    def ready(self):
        post_migrate.connect(sync_default_site_domain, sender=self)
