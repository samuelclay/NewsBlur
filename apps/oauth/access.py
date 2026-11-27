from datetime import datetime, timezone

from django.conf import settings
from django.core.exceptions import ObjectDoesNotExist
from django.db.models import Q

from apps.oauth.reader_grants import READER_OWNERS

# Production applied oauth.0002_grant_reader_owners when self-service registration launched. Applications
# registered before then worked without Premium Pro, and oauth.0004_applicationexemption gave each of them an
# ApplicationExemption (apps/oauth/models.py) to keep that.
SELF_SERVICE_LAUNCH = datetime(
    2026, 11, 25, 5, 1, 57, 48914, tzinfo=timezone.utc if settings.USE_TZ else None
)


def owner_has_active_pro(application):
    profile = getattr(application.user, "profile", None)
    return bool(profile and profile.can_register_oauth_application)


def application_is_exempt(application):
    # select_related("applicationexemption") preloads this, as apps/oauth/validators.py does.
    try:
        application.applicationexemption
    except ObjectDoesNotExist:
        return False
    return True


def application_is_active(application):
    if not application:
        return False
    if application.user_id is None:
        # Registered by migrations in apps/mcp and apps/archive_extension.
        return application.client_id in ("newsblur-cli", "newsblur-mcp-server", "newsblur-archive-extension")
    if application_is_exempt(application):
        return application.user.is_active
    return owner_has_active_pro(application)


def exempt_existing_applications(apps, database, owners=READER_OWNERS):
    """Exempt every owned application registered before self-service launched, and every application owned by
    an approved reader partner in apps/oauth/reader_grants.py. Run by oauth.0004_applicationexemption."""
    applications = apps.get_model("oauth2_provider", "Application").objects.using(database)
    exemptions = apps.get_model("oauth", "ApplicationExemption").objects.using(database)
    exempt = Q(created__lt=SELF_SERVICE_LAUNCH)
    for user_id, username, _ in owners:
        # Match the username too, as grant_reader_accounts does: other databases reuse these user IDs.
        exempt |= Q(user_id=user_id, user__username=username)
    for application_id in applications.filter(exempt, user__isnull=False).values_list("pk", flat=True):
        exemptions.get_or_create(application_id=application_id)
