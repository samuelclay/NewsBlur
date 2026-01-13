import datetime

from django.core.management.base import BaseCommand
from django.db.models import Count

from apps.profile.models import Profile
from apps.reader.models import UserSubscription
from utils import log as logging


class Command(BaseCommand):
    help = "One-time command to grandfather premium users over 1024 feeds. Run at launch."

    def add_arguments(self, parser):
        parser.add_argument(
            "--dry-run",
            action="store_true",
            default=False,
            help="Show what would be done without making changes",
        )

    def handle(self, *args, **options):
        dry_run = options.get("dry_run")

        if dry_run:
            self.stdout.write("=== DRY RUN MODE ===\n")

        profiles = Profile.objects.filter(
            is_premium=True,
            is_archive=False,
            is_pro=False,
            grandfather_expires__isnull=True,
        ).select_related("user")

        user_ids = list(profiles.values_list("user_id", flat=True))

        # Find users with > 1024 active feeds
        feed_counts = dict(
            UserSubscription.objects.filter(user_id__in=user_ids, active=True)
            .values("user_id")
            .annotate(feed_count=Count("id"))
            .filter(feed_count__gt=Profile.PREMIUM_FEED_LIMIT)
            .values_list("user_id", "feed_count")
        )

        profiles_to_update = profiles.filter(user_id__in=feed_counts.keys())
        count = profiles_to_update.count()

        if count == 0:
            self.stdout.write("No premium users over 1024 feeds to grandfather")
            return

        self.stdout.write(f"Found {count} premium users over 1024 feeds\n")

        grandfathered = 0
        skipped_lifetime = []

        for profile in profiles_to_update:
            user = profile.user
            feed_count = feed_counts[user.pk]

            if not profile.premium_expire:
                skipped_lifetime.append((user.username, feed_count))
                continue

            expires = profile.premium_expire
            if expires.tzinfo is None:
                expires = expires.replace(tzinfo=datetime.timezone.utc)
            expires_date = expires.strftime("%B %d, %Y")

            if dry_run:
                self.stdout.write(f"  WOULD SET: {user.username} - {feed_count:,} feeds, renewal: {expires_date}")
            else:
                profile.is_grandfathered = True
                profile.grandfather_expires = expires
                profile.save(update_fields=["is_grandfathered", "grandfather_expires"])
                logging.user(user, f"~BB~FM~SBGrandfathered: {feed_count:,} feeds, expires: {expires_date}")
                self.stdout.write(f"  SET: {user.username} - {feed_count:,} feeds, renewal: {expires_date}")

            grandfathered += 1

        self.stdout.write(f"\nGrandfathered: {grandfathered}")

        if skipped_lifetime:
            self.stdout.write(f"Skipped {len(skipped_lifetime)} lifetime premium users (no renewal date):")
            for username, feeds in skipped_lifetime:
                self.stdout.write(f"  {username}: {feeds:,} feeds")
