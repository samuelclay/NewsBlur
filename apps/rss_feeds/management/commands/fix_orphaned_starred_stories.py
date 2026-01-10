"""
Management command to fix orphaned starred stories after feed merges.

This command finds starred stories that reference feed IDs which no longer exist
(due to feed merges) and attempts to map them to the correct merged feed using
the DuplicateFeed table.

Usage:
    python manage.py fix_orphaned_starred_stories --dry-run  # Preview changes
    python manage.py fix_orphaned_starred_stories            # Apply fixes
"""
from django.core.management.base import BaseCommand

from apps.rss_feeds.models import (
    DuplicateFeed,
    Feed,
    MStarredStory,
    MStarredStoryCounts,
)


class Command(BaseCommand):
    help = "Fix orphaned starred stories that reference deleted feed IDs"

    def add_arguments(self, parser):
        parser.add_argument(
            "--dry-run",
            action="store_true",
            dest="dry_run",
            default=False,
            help="Preview changes without applying them",
        )
        parser.add_argument(
            "--limit",
            type=int,
            dest="limit",
            default=None,
            help="Limit number of feed IDs to process",
        )
        parser.add_argument(
            "-V",
            "--verbose",
            dest="verbose",
            action="store_true",
            help="Verbose output",
        )

    def handle(self, *args, **options):
        dry_run = options["dry_run"]
        verbose = options["verbose"]
        limit = options["limit"]

        if dry_run:
            self.stdout.write(self.style.WARNING("DRY RUN - no changes will be made"))

        # Get all unique feed IDs from starred stories
        self.stdout.write("Finding all unique feed IDs in starred stories...")
        all_starred_feed_ids = set(MStarredStory.objects.distinct("story_feed_id"))
        self.stdout.write(f"Found {len(all_starred_feed_ids)} unique feed IDs in starred stories")

        # Get all valid feed IDs
        self.stdout.write("Getting valid feed IDs...")
        valid_feed_ids = set(Feed.objects.values_list("pk", flat=True))
        self.stdout.write(f"Found {len(valid_feed_ids)} valid feeds")

        # Find orphaned feed IDs
        orphaned_feed_ids = all_starred_feed_ids - valid_feed_ids
        # Filter out None and 0 which are valid "no feed" values
        orphaned_feed_ids = {fid for fid in orphaned_feed_ids if fid and fid > 0}

        self.stdout.write(f"Found {len(orphaned_feed_ids)} orphaned feed IDs")

        if limit:
            orphaned_feed_ids = set(list(orphaned_feed_ids)[:limit])
            self.stdout.write(f"Processing only {len(orphaned_feed_ids)} due to limit")

        # Build mapping from orphaned feed IDs to their merged targets
        feed_mapping = {}
        unmapped_feed_ids = []

        self.stdout.write("Building feed mapping from DuplicateFeed table...")
        for orphan_id in orphaned_feed_ids:
            # Look up in DuplicateFeed table
            try:
                duplicate = DuplicateFeed.objects.get(duplicate_feed_id=orphan_id)
                feed_mapping[orphan_id] = duplicate.feed_id
                if verbose:
                    self.stdout.write(f"  {orphan_id} -> {duplicate.feed_id}")
            except DuplicateFeed.DoesNotExist:
                unmapped_feed_ids.append(orphan_id)
                if verbose:
                    self.stdout.write(self.style.WARNING(f"  {orphan_id} -> NOT FOUND"))

        self.stdout.write(f"Mapped {len(feed_mapping)} feed IDs")
        self.stdout.write(self.style.WARNING(f"Could not map {len(unmapped_feed_ids)} feed IDs"))

        if unmapped_feed_ids and verbose:
            self.stdout.write("Unmapped feed IDs (will be skipped):")
            for fid in unmapped_feed_ids[:20]:  # Show first 20
                count = MStarredStory.objects.filter(story_feed_id=fid).count()
                self.stdout.write(f"  Feed {fid}: {count} starred stories")
            if len(unmapped_feed_ids) > 20:
                self.stdout.write(f"  ... and {len(unmapped_feed_ids) - 20} more")

        # Apply fixes
        total_fixed = 0
        users_affected = set()

        for old_feed_id, new_feed_id in feed_mapping.items():
            # Verify the target feed still exists
            if new_feed_id not in valid_feed_ids:
                if verbose:
                    self.stdout.write(
                        self.style.WARNING(
                            f"Target feed {new_feed_id} no longer exists, skipping {old_feed_id}"
                        )
                    )
                continue

            stories = MStarredStory.objects.filter(story_feed_id=old_feed_id)
            count = stories.count()

            if count == 0:
                continue

            self.stdout.write(f"Fixing {count} starred stories: feed {old_feed_id} -> {new_feed_id}")

            if not dry_run:
                for story in stories:
                    users_affected.add(story.user_id)
                    story.story_feed_id = new_feed_id
                    story.story_hash = story.feed_guid_hash
                    story.save()

            total_fixed += count

        # Recalculate starred story counts for affected users
        if not dry_run and users_affected:
            self.stdout.write(f"Recalculating starred story counts for {len(users_affected)} users...")
            for user_id in users_affected:
                try:
                    MStarredStoryCounts.count_for_user(user_id)
                except Exception as e:
                    self.stdout.write(self.style.ERROR(f"Error recounting for user {user_id}: {e}"))

        # Summary
        self.stdout.write("")
        self.stdout.write(self.style.SUCCESS("=" * 50))
        self.stdout.write(self.style.SUCCESS("Summary"))
        self.stdout.write(self.style.SUCCESS("=" * 50))
        self.stdout.write(f"Total orphaned feed IDs: {len(orphaned_feed_ids)}")
        self.stdout.write(f"Successfully mapped: {len(feed_mapping)}")
        self.stdout.write(f"Could not map: {len(unmapped_feed_ids)}")
        self.stdout.write(f"Starred stories fixed: {total_fixed}")
        self.stdout.write(f"Users affected: {len(users_affected)}")

        if dry_run:
            self.stdout.write("")
            self.stdout.write(self.style.WARNING("DRY RUN - run without --dry-run to apply changes"))
