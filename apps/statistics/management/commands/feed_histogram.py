from datetime import timedelta

from django.contrib.auth.models import User
from django.core.management.base import BaseCommand
from django.db.models import Count, Q
from django.utils import timezone

from apps.profile.models import Profile
from apps.reader.models import UserSubscription


class Command(BaseCommand):
    help = "Generate ASCII histograms of feed counts for different user tiers"

    def handle(self, *args, **options):
        self.stdout.write("Fetching user data...")

        # Premium users (premium but not archive/pro)
        premium_users = User.objects.filter(
            profile__is_premium=True,
            profile__is_archive=False,
            profile__is_pro=False,
            profile__premium_expire__gte=timezone.now(),
        ).values_list("id", flat=True)

        premium_feeds = list(
            UserSubscription.objects.filter(user_id__in=premium_users)
            .values("user")
            .annotate(feed_count=Count("id"))
            .values_list("feed_count", flat=True)
        )

        # Free users
        free_users = User.objects.filter(
            Q(profile__is_premium=False) | Q(profile__premium_expire__lt=timezone.now())
        ).values_list("id", flat=True)

        free_feeds = list(
            UserSubscription.objects.filter(user_id__in=free_users)
            .values("user")
            .annotate(feed_count=Count("id"))
            .values_list("feed_count", flat=True)
        )

        # Archive users (archive but not pro)
        archive_users = User.objects.filter(
            profile__is_premium=True,
            profile__is_archive=True,
            profile__is_pro=False,
            profile__premium_expire__gte=timezone.now(),
        ).values_list("id", flat=True)

        archive_feeds = list(
            UserSubscription.objects.filter(user_id__in=archive_users)
            .values("user")
            .annotate(feed_count=Count("id"))
            .values_list("feed_count", flat=True)
        )

        # Pro users
        pro_users = User.objects.filter(
            profile__is_premium=True, profile__is_pro=True, profile__premium_expire__gte=timezone.now()
        ).values_list("id", flat=True)

        pro_feeds = list(
            UserSubscription.objects.filter(user_id__in=pro_users)
            .values("user")
            .annotate(feed_count=Count("id"))
            .values_list("feed_count", flat=True)
        )

        # Active old users (active in last 365 days, account 2+ years old)
        one_year_ago = timezone.now() - timedelta(days=365)
        two_years_ago = timezone.now() - timedelta(days=730)

        active_old_users = User.objects.filter(
            profile__last_seen_on__gte=one_year_ago, date_joined__lte=two_years_ago
        ).values_list("id", flat=True)

        active_old_feeds = list(
            UserSubscription.objects.filter(user_id__in=active_old_users)
            .values("user")
            .annotate(feed_count=Count("id"))
            .values_list("feed_count", flat=True)
        )

        # Generate histograms
        self._generate_histogram(free_feeds, "FREE USERS")
        self._generate_histogram(premium_feeds, "PREMIUM USERS (not Archive/Pro)")
        self._generate_histogram(archive_feeds, "ARCHIVE USERS (not Pro)")
        self._generate_histogram(pro_feeds, "PRO USERS")
        self._generate_histogram(
            active_old_feeds, "ACTIVE OLD USERS (active last 365 days, account 2+ years)"
        )

        # Summary stats
        self.stdout.write("\n" + "=" * 70)
        self.stdout.write("SUMMARY STATISTICS")
        self.stdout.write("=" * 70)
        self.stdout.write(f"Free users: {len(free_feeds):,}")
        self.stdout.write(f"Premium users: {len(premium_feeds):,}")
        self.stdout.write(f"Archive users: {len(archive_feeds):,}")
        self.stdout.write(f"Pro users: {len(pro_feeds):,}")
        self.stdout.write(f"Active old users: {len(active_old_feeds):,}")

    def _generate_histogram(self, data, title, max_width=60):
        """Generate ASCII histogram"""
        if not data:
            self.stdout.write(f"\n{title}: No data")
            return

        # Create buckets
        min_val = min(data)
        max_val = max(data)

        # Define bucket ranges
        if max_val <= 100:
            buckets = [(0, 10), (11, 25), (26, 50), (51, 75), (76, 100)]
        elif max_val <= 500:
            buckets = [(0, 10), (11, 25), (26, 50), (51, 100), (101, 200), (201, 300), (301, 400), (401, 500)]
        else:
            buckets = [
                (0, 10),
                (11, 25),
                (26, 50),
                (51, 100),
                (101, 250),
                (251, 500),
                (501, 750),
                (751, 1000),
                (1001, 1500),
                (1501, max_val),
            ]

        # Count users in each bucket
        bucket_counts = []
        for low, high in buckets:
            count = sum(1 for x in data if low <= x <= high)
            bucket_counts.append((f"{low:4d}-{high:4d}", count))

        # Find max count for scaling
        max_count = max(count for _, count in bucket_counts) if bucket_counts else 1

        self.stdout.write(f"\n{title}")
        self.stdout.write(f"Total users: {len(data)}")
        self.stdout.write(f"Feed range: {min_val}-{max_val}")
        self.stdout.write("-" * 70)

        for label, count in bucket_counts:
            bar_width = int((count / max_count) * max_width) if max_count > 0 else 0
            bar = "█" * bar_width
            self.stdout.write(f"{label} feeds: {count:5d} |{bar}")
