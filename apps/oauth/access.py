from datetime import datetime, timezone

from django.conf import settings

# Production applied oauth.0002_grant_reader_owners when self-service registration launched.
SELF_SERVICE_LAUNCH = datetime(
    2026, 11, 25, 5, 1, 57, 48914, tzinfo=timezone.utc if settings.USE_TZ else None
)


def owner_has_active_pro(application):
    profile = getattr(application.user, "profile", None)
    return bool(profile and profile.can_register_oauth_application)


def application_is_active(application):
    if not application:
        return False
    if application.user_id is None:
        # Registered by migrations in apps/mcp and apps/archive_extension.
        return application.client_id in ("newsblur-cli", "newsblur-mcp-server", "newsblur-archive-extension")
    if application.created < SELF_SERVICE_LAUNCH:
        return application.user.is_active
    return owner_has_active_pro(application)
