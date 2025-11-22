import datetime

import pytz
from django.core.management.base import BaseCommand

from apps.ask_ai.models import MAITranscriptionUsage, MAskAIUsage


class Command(BaseCommand):
    help = """Reset Ask AI usage limits by removing usage records within a time window.

    Examples:
        # Reset all usage from last 24 hours
        python manage.py reset_askai_usage

        # Reset usage for specific user from last 24 hours
        python manage.py reset_askai_usage --user 123

        # Reset all usage from last 48 hours
        python manage.py reset_askai_usage --hours 48

        # Reset usage for specific user from last 12 hours
        python manage.py reset_askai_usage --user 123 --hours 12
    """

    def add_arguments(self, parser):
        parser.add_argument(
            "--user",
            type=int,
            help="User ID to reset usage for (if not provided, resets for all users)",
        )
        parser.add_argument(
            "--hours",
            type=int,
            default=24,
            help="Number of hours to look back (default: 24)",
        )
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Show what would be deleted without actually deleting",
        )

    def handle(self, *args, **options):
        user_id = options.get("user")
        hours = options.get("hours")
        dry_run = options.get("dry_run")

        # Calculate time window
        now = datetime.datetime.now(pytz.UTC).replace(tzinfo=None)
        start_time = now - datetime.timedelta(hours=hours)

        # Build query
        query = {"created_at__gte": start_time}
        if user_id:
            query["user_id"] = user_id

        # Get count before deletion for both usage types
        usage_entries = MAskAIUsage.objects(**query)
        transcription_entries = MAITranscriptionUsage.objects(**query)
        count = usage_entries.count()
        transcription_count = transcription_entries.count()
        total_count = count + transcription_count

        if total_count == 0:
            self.stdout.write(
                self.style.WARNING(
                    f"No usage entries found within the last {hours} hour(s)"
                    + (f" for user {user_id}" if user_id else "")
                )
            )
            return

        # Show what we found
        user_msg = f" for user {user_id}" if user_id else " for all users"
        time_msg = f"from the last {hours} hour(s)"

        if dry_run:
            self.stdout.write(
                self.style.WARNING(
                    f"[DRY RUN] Would delete {count} Ask AI usage record(s) "
                    f"and {transcription_count} transcription record(s){user_msg} {time_msg}"
                )
            )
            self._show_sample_entries(usage_entries)
            return

        # Delete entries
        deleted = usage_entries.delete()
        transcription_deleted = transcription_entries.delete()

        self.stdout.write(
            self.style.SUCCESS(
                f"Successfully deleted {deleted} Ask AI usage record(s) "
                f"and {transcription_deleted} transcription record(s){user_msg} {time_msg}"
            )
        )

    def _show_sample_entries(self, usage_entries):
        """Show a sample of entries that would be deleted."""
        sample_size = min(5, usage_entries.count())
        self.stdout.write("\nSample entries:")
        for entry in usage_entries.limit(sample_size):
            self.stdout.write(
                f"  - User {entry.user_id}, created at {entry.created_at}, "
                f"question: {entry.question_id}, plan: {entry.plan_tier}"
            )
        if usage_entries.count() > sample_size:
            self.stdout.write(f"  ... and {usage_entries.count() - sample_size} more")
