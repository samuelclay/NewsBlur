"""
Management command to populate PopularFeed records from the curated fixtures file.
Creates Feed objects in the database and links them to PopularFeed entries.

Usage:
    python manage.py bootstrap_popular_feeds
    python manage.py bootstrap_popular_feeds --type youtube
    python manage.py bootstrap_popular_feeds --dry-run --verbose
    python manage.py bootstrap_popular_feeds --force-update
"""

import json
import os

from django.core.management.base import BaseCommand

from apps.discover.models import PopularFeed
from apps.rss_feeds.models import Feed


class Command(BaseCommand):
    help = "Populate PopularFeed records from the curated fixtures file and create Feed objects"

    FIXTURE_PATH = os.path.join(os.path.dirname(__file__), "../../fixtures/popular_feeds.json")

    VALID_TYPES = ["youtube", "reddit", "newsletter", "podcast"]

    def add_arguments(self, parser):
        parser.add_argument(
            "--type",
            choices=self.VALID_TYPES + ["all"],
            default="all",
            help="Type of feeds to bootstrap (default: all)",
        )
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Show what would be done without creating anything",
        )
        parser.add_argument(
            "--force-update",
            action="store_true",
            help="Force re-fetch of existing Feed objects",
        )
        parser.add_argument(
            "--verbose",
            action="store_true",
            help="Show detailed output",
        )
        parser.add_argument(
            "--skip-fetch",
            action="store_true",
            help="Create PopularFeed records without fetching Feed objects (faster, for data-only updates)",
        )

    def handle(self, *args, **options):
        dry_run = options["dry_run"]
        feed_type = options["type"]
        force_update = options["force_update"]
        verbose = options["verbose"]
        skip_fetch = options["skip_fetch"]

        fixture_path = os.path.normpath(self.FIXTURE_PATH)
        if not os.path.exists(fixture_path):
            self.stderr.write(self.style.ERROR(f"Fixture file not found: {fixture_path}"))
            return

        with open(fixture_path, "r") as f:
            all_feeds = json.load(f)

        if feed_type != "all":
            all_feeds = [entry for entry in all_feeds if entry["feed_type"] == feed_type]

        self.stdout.write(f"Processing {len(all_feeds)} feed entries...")

        created = 0
        updated = 0
        feed_linked = 0
        failed = 0

        for entry in all_feeds:
            feed_url = entry["feed_url"]
            entry_type = entry["feed_type"]
            title = entry["title"]

            if dry_run:
                if verbose:
                    self.stdout.write(f"  Would process: [{entry_type}/{entry['category']}] {title}")
                continue

            # Create or update PopularFeed record
            popular_feed, was_created = PopularFeed.objects.update_or_create(
                feed_url=feed_url,
                feed_type=entry_type,
                defaults={
                    "title": title,
                    "description": entry.get("description", ""),
                    "category": entry["category"],
                    "subcategory": entry.get("subcategory", ""),
                    "thumbnail_url": entry.get("thumbnail_url", ""),
                    "platform": entry.get("platform", ""),
                    "subscriber_count": entry.get("subscriber_count", 0),
                    "is_active": True,
                },
            )

            if was_created:
                created += 1
            else:
                updated += 1

            if verbose:
                action = "+" if was_created else "="
                self.stdout.write(f"  {action} [{entry_type}/{entry['category']}] {title}")

            # Create/link Feed object unless skipping
            if not skip_fetch and not popular_feed.feed:
                try:
                    feed = Feed.get_feed_from_url(feed_url, create=True, fetch=False)
                    if feed:
                        popular_feed.feed = feed
                        popular_feed.save(update_fields=["feed"])
                        feed_linked += 1
                        if verbose:
                            self.stdout.write(f"    Linked to Feed id={feed.pk}")
                except Exception as e:
                    failed += 1
                    if verbose:
                        self.stdout.write(self.style.WARNING(f"    Failed to create Feed: {e}"))

            # Force update existing Feed if requested
            if force_update and popular_feed.feed:
                try:
                    popular_feed.feed.update(force=True, single_threaded=True)
                except Exception as e:
                    if verbose:
                        self.stdout.write(self.style.WARNING(f"    Failed to update Feed: {e}"))

        if dry_run:
            self.stdout.write(self.style.WARNING(f"\nDry run complete - {len(all_feeds)} entries would be processed"))
        else:
            self.stdout.write(
                self.style.SUCCESS(
                    f"\nDone: {created} created, {updated} updated, {feed_linked} feeds linked, {failed} failed"
                )
            )

        # Print category summary
        if verbose or dry_run:
            self._print_summary(all_feeds)

    def _print_summary(self, feeds):
        """Print a summary of feeds by type and category."""
        from collections import Counter

        type_counts = Counter(f["feed_type"] for f in feeds)
        self.stdout.write("\nSummary by type:")
        for feed_type, count in sorted(type_counts.items()):
            self.stdout.write(f"  {feed_type}: {count}")

        self.stdout.write("\nSummary by type/category:")
        category_counts = Counter((f["feed_type"], f["category"]) for f in feeds)
        current_type = None
        for (feed_type, category), count in sorted(category_counts.items()):
            if feed_type != current_type:
                current_type = feed_type
                self.stdout.write(f"  {feed_type}:")
            self.stdout.write(f"    {category}: {count}")
