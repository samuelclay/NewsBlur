"""Approved Goodies partners for the OAuth rollout. Never match on a self-entered app name."""

from django.db import transaction
from django.utils import timezone

# Production owner ID, username, and one of their verified registered application IDs.
WINBLUR_OWNER = (179699, "amittere", 128)
READER_OWNERS = (
    (13, "samuel", 5),
    (320840, "prendio2", 7),
    (380808, "jbrayton", 18),
    (154048, "readkit", 23),
    (93498, "mehlkelm", 33),
    (593941, "Richasy", 32),
    (764146, "sered", 127),
    WINBLUR_OWNER,
)


def grant_reader_accounts(apps, database, apply, report, owners=None):
    application = apps.get_model("oauth2_provider", "Application").objects.using(database)
    profiles = apps.get_model("profile", "Profile").objects.using(database)
    payments = apps.get_model("profile", "PaymentHistory").objects.using(database)
    for user_id, username, app_id in READER_OWNERS if owners is None else owners:
        with transaction.atomic(using=database):
            if not application.filter(pk=app_id, user_id=user_id, user__username=username).exists():
                continue
            profile = profiles.select_for_update().get(user_id=user_id)
            billing = (
                f" (review recurring billing: {profile.active_provider or 'unknown provider'})"
                if profile.premium_renewal
                else ""
            )
            report(f"{username}: lifetime Premium Pro{billing}")
            if apply:
                profiles.filter(pk=profile.pk).update(
                    is_premium=True, is_archive=True, is_pro=True, is_premium_trial=False, premium_expire=None
                )
                payments.get_or_create(
                    user_id=user_id,
                    payment_provider="oauth-reader-grant",
                    defaults={"payment_date": timezone.now(), "payment_amount": 0},
                )
