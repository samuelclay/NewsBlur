import datetime

from django.conf import settings
from django.core.mail import EmailMultiAlternatives
from django.core.management.base import BaseCommand
from django.db.models import Count
from django.template.loader import render_to_string

from apps.profile.models import MSentEmail, Profile
from apps.reader.models import UserSubscription
from utils import log as logging


class Command(BaseCommand):
    help = "Grandfather users over the feed limit and email them 7 days before expiry. Run daily via Celery."

    def add_arguments(self, parser):
        parser.add_argument(
            "--dry-run",
            action="store_true",
            dest="dry_run",
            default=False,
            help="Don't actually make changes or send emails",
        )
        parser.add_argument(
            "--force",
            action="store_true",
            dest="force",
            default=False,
            help="Send emails even if already sent (ignores MSentEmail check)",
        )
        parser.add_argument(
            "--username",
            dest="username",
            default=None,
            help="Only process a specific username (for testing)",
        )
        parser.add_argument(
            "--days-before",
            dest="days_before",
            type=int,
            default=7,
            help="Send email this many days before grandfather_expires (default: 7)",
        )

    def handle(self, *args, **options):
        dry_run = options.get("dry_run")
        force = options.get("force")
        username_filter = options.get("username")
        days_before = options.get("days_before")

        if dry_run:
            self.stdout.write("=== DRY RUN MODE ===\n")

        now = datetime.datetime.now(datetime.timezone.utc)
        one_year_ago = now - datetime.timedelta(days=365)
        hard_cutoff = Profile.GRANDFATHER_CUTOFF_DATE + datetime.timedelta(days=365)

        # Step 1: Set grandfather_expires on users who are over the limit but don't have it set
        self._grandfather_new_users(dry_run, username_filter, now, hard_cutoff)

        # Step 2: Email users whose grandfather_expires is coming up
        self._send_expiry_notifications(dry_run, force, username_filter, days_before, now, one_year_ago)

    def _grandfather_new_users(self, dry_run, username_filter, now, hard_cutoff):
        """Set grandfather_expires on users who are over the limit but don't have it set."""
        self.stdout.write("\n--- Grandfathering new users ---")

        profiles = Profile.objects.filter(
            is_premium=True,
            is_archive=False,
            is_pro=False,
            grandfather_expires__isnull=True,
        ).select_related("user")

        if username_filter:
            profiles = profiles.filter(user__username=username_filter)

        user_ids = list(profiles.values_list("user_id", flat=True))

        # Get users with > 1024 active feeds
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
            self.stdout.write("No new users to grandfather")
            return

        self.stdout.write(f"Found {count} users over {Profile.PREMIUM_FEED_LIMIT} feeds without grandfather_expires")

        for profile in profiles_to_update:
            user = profile.user
            feed_count = feed_counts[user.pk]

            # Determine grandfather_expires based on premium_expire, capped at hard cutoff
            if profile.premium_expire:
                expires = profile.premium_expire
                if expires.tzinfo is None:
                    expires = expires.replace(tzinfo=datetime.timezone.utc)
                if expires > hard_cutoff:
                    expires = hard_cutoff
            else:
                expires = hard_cutoff

            expires_date = expires.strftime("%B %d, %Y")

            if dry_run:
                self.stdout.write(f"  WOULD SET: {user.username} - {feed_count} feeds, expires: {expires_date}")
            else:
                profile.grandfather_expires = expires
                profile.save(update_fields=["grandfather_expires"])
                logging.user(user, f"~BB~FM~SBSet grandfather_expires: {expires_date} ({feed_count} feeds)")

    def _send_expiry_notifications(self, dry_run, force, username_filter, days_before, now, one_year_ago):
        """Email users whose grandfather_expires is coming up in the next N days."""
        self.stdout.write(f"\n--- Sending expiry notifications ({days_before} days before) ---")

        window_start = now
        window_end = now + datetime.timedelta(days=days_before)

        profiles = Profile.objects.filter(
            is_premium=True,
            is_archive=False,
            is_pro=False,
            grandfather_expires__isnull=False,
        ).select_related("user")

        if username_filter:
            profiles = profiles.filter(user__username=username_filter)
        else:
            profiles = profiles.filter(
                grandfather_expires__gte=window_start,
                grandfather_expires__lte=window_end,
            )

        user_ids = list(profiles.values_list("user_id", flat=True))

        feed_counts = dict(
            UserSubscription.objects.filter(user_id__in=user_ids, active=True)
            .values("user_id")
            .annotate(feed_count=Count("id"))
            .values_list("user_id", "feed_count")
        )

        count = profiles.count()
        if count == 0:
            self.stdout.write("No users expiring in notification window")
            return

        self.stdout.write(f"Found {count} users expiring in next {days_before} days")

        sent_count = 0
        skipped_inactive = 0
        already_sent = 0

        for profile in profiles:
            user = profile.user
            feed_count = feed_counts.get(user.pk, 0)

            # Skip inactive users
            last_seen = profile.last_seen_on
            if last_seen.tzinfo is None:
                last_seen = last_seen.replace(tzinfo=datetime.timezone.utc)
            if last_seen < one_year_ago:
                skipped_inactive += 1
                continue

            # Check if already sent
            if not force:
                if MSentEmail.objects.filter(
                    receiver_user_id=user.pk,
                    email_type="feed_limit_notification",
                ).exists():
                    already_sent += 1
                    continue

            deadline = profile.grandfather_expires
            if deadline.tzinfo is None:
                deadline = deadline.replace(tzinfo=datetime.timezone.utc)

            deadline_date = deadline.strftime("%B %d, %Y")
            days_until = (deadline - now).days

            if dry_run:
                self.stdout.write(
                    f"  WOULD EMAIL: {user.username} <{user.email}> - "
                    f"{feed_count} feeds, deadline: {deadline_date} ({days_until} days)"
                )
            else:
                self._send_email(user, profile, feed_count, deadline_date)
                MSentEmail.record(receiver_user_id=user.pk, email_type="feed_limit_notification")
                logging.user(user, f"~BB~FM~SBSent feed limit notification: {feed_count} feeds, deadline: {deadline_date}")

            sent_count += 1

        self.stdout.write(f"\nEmails: {sent_count}, Skipped (inactive): {skipped_inactive}, Already sent: {already_sent}")

    def _send_email(self, user, profile, feed_count, deadline_date):
        params = {
            "user": user,
            "username": user.username,
            "feed_count": feed_count,
            "deadline_date": deadline_date,
        }

        text = render_to_string("mail/email_feed_limit_notification.txt", params)
        html = render_to_string("mail/email_feed_limit_notification.xhtml", params)
        subject = f"Your NewsBlur subscription and your {feed_count} sites"

        msg = EmailMultiAlternatives(
            subject,
            text,
            from_email=f"NewsBlur <{settings.HELLO_EMAIL}>",
            to=[f"{user.username} <{user.email}>"],
        )
        msg.attach_alternative(html, "text/html")
        msg.send()
