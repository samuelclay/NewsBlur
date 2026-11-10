from django.core.management.base import BaseCommand, CommandError

from apps.rss_feeds.models import MStarredStory


class Command(BaseCommand):
    help = (
        "Delete saved stories nobody can come back for (MStarredStory.trim_old_stories in "
        "apps/rss_feeds/models.py): copies left behind by unsaving, saves of deleted accounts, and saves "
        "of free accounts that never paid and haven't been seen in --days days."
    )

    def add_arguments(self, parser):
        parser.add_argument("--days", type=int, default=730, help="Days since a free account was last seen")
        parser.add_argument(
            "--min-stories", type=int, default=10, help="Leave accounts with fewer saved stories than this"
        )
        parser.add_argument("--batch", type=int, default=1000, help="Saved stories deleted per batch")
        parser.add_argument(
            "--max-lag", type=int, default=10, help="Seconds of replication lag to wait out between batches"
        )
        parser.add_argument(
            "--dryrun", action="store_true", help="Count what would be deleted, delete nothing"
        )

    def handle(self, *args, **options):
        if options["batch"] < 1:
            # pymongo reads a limit of 0 as no limit, which would delete everything in one request.
            raise CommandError("--batch must be at least 1")
        trimmed = MStarredStory.trim_old_stories(
            days=options["days"],
            min_stories=options["min_stories"],
            batch_size=options["batch"],
            max_lag_seconds=options["max_lag"],
            dryrun=options["dryrun"],
        )
        self.stdout.write(
            " ---> %s %s saved stories" % ("Would delete" if options["dryrun"] else "Deleted", trimmed)
        )
