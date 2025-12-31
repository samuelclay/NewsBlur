"""
Management command to backfill trending subscription data from MActivity.

This reads historical subscription activity from MongoDB and populates
the Redis sorted sets used by RTrendingSubscription for trending feeds.
"""

import datetime

import redis
from django.conf import settings
from django.core.management.base import BaseCommand

from apps.social.models import MActivity
from apps.statistics.rtrending_subscriptions import RTrendingSubscription


class Command(BaseCommand):
    help = "Backfill trending subscription data from historical MActivity records"

    def add_arguments(self, parser):
        parser.add_argument(
            "--days",
            type=int,
            default=14,
            help="Number of days to backfill (default: 14)",
        )
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Show what would be done without writing to Redis",
        )
        parser.add_argument(
            "-V",
            "--verbose",
            action="store_true",
            help="Show verbose output",
        )

    def handle(self, *args, **options):
        days = options["days"]
        dry_run = options["dry_run"]
        verbose = options["verbose"]

        cutoff = datetime.datetime.now() - datetime.timedelta(days=days)

        self.stdout.write(f"Querying MActivity for feedsub events since {cutoff.strftime('%Y-%m-%d')}...")

        activities = MActivity.objects.filter(
            category="feedsub",
            date__gte=cutoff,
        ).only("feed_id", "date")

        count = 0
        feed_counts = {}

        for activity in activities:
            if not activity.feed_id:
                continue

            day_key = activity.date.strftime("%Y-%m-%d")
            feed_key = (day_key, activity.feed_id)
            feed_counts[feed_key] = feed_counts.get(feed_key, 0) + 1
            count += 1

            if verbose and count % 1000 == 0:
                self.stdout.write(f"  Processed {count} activities...")

        self.stdout.write(
            f"Found {count} subscription activities across {len(feed_counts)} feed-day pairs"
        )

        if dry_run:
            self.stdout.write(self.style.WARNING("Dry run - not writing to Redis"))
            # Show top 20 entries by count
            sorted_entries = sorted(feed_counts.items(), key=lambda x: -x[1])[:20]
            for (day, feed_id), sub_count in sorted_entries:
                self.stdout.write(f"  {day} feed:{feed_id} = {sub_count} subscriptions")
            return

        # Write to Redis
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        ttl_seconds = RTrendingSubscription.TTL_DAYS * 24 * 60 * 60

        pipe = r.pipeline()
        for (day, feed_id), sub_count in feed_counts.items():
            key = f"fSub:{day}"
            pipe.zincrby(key, sub_count, str(feed_id))
            pipe.expire(key, ttl_seconds)

        pipe.execute()

        self.stdout.write(self.style.SUCCESS(f"Backfilled {count} subscriptions across {days} days"))

        # Show the resulting trending feeds
        self.stdout.write("\nTop 10 trending feeds (7-day window):")
        trending = RTrendingSubscription.get_trending_feeds(days=7, limit=10, min_subscribers=1)
        for feed_id, score in trending:
            self.stdout.write(f"  Feed {feed_id}: {score:.1f} weighted score")
