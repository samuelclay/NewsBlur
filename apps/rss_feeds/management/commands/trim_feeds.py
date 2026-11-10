import sys
import time
from concurrent.futures import ThreadPoolExecutor

from django.core.management.base import BaseCommand
from django.db import close_old_connections

from apps.rss_feeds.models import Feed


class Command(BaseCommand):
    help = (
        "Trim stories from feeds nobody has been seen reading in DAYS_OF_UNREAD days and no Archive "
        "subscriber keeps (Feed.trim_if_abandoned). Nothing fetches those feeds, so the trim after each "
        "fetch never runs on them. The daily TrimAbandonedFeeds task keeps up with feeds that just went "
        "quiet; this catches up on the ones before that."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "-f", "--feed", dest="feed", type=int, default=None, help="Trim only this feed id"
        )
        parser.add_argument("--start", type=int, default=0, help="Resume from this feed id")
        parser.add_argument("--threads", type=int, default=8, help="How many feeds to trim at once")
        parser.add_argument("--chunk", type=int, default=10000, help="Feed ids per progress line")
        parser.add_argument(
            "--dryrun",
            action="store_true",
            help="Estimate from the stored subscriber counts without recounting or deleting anything",
        )

    def handle(self, *args, **options):
        self.dryrun = options["dryrun"]

        if options["feed"]:
            removed = self.trim_abandoned_feed(options["feed"])
            self.stdout.write(" ---> Feed %s: %s stories trimmed" % (options["feed"], removed or 0))
            return

        if options["threads"] > 1:
            with ThreadPoolExecutor(max_workers=options["threads"]) as pool:
                self.trim_all_abandoned_feeds(pool.map, options["start"], options["chunk"])
        else:
            # A single thread runs in the caller's thread, which also lets tests see their own
            # uncommitted rows.
            self.trim_all_abandoned_feeds(map, options["start"], options["chunk"])

    def trim_all_abandoned_feeds(self, map_feeds, start, chunk):
        candidates = Feed.abandoned_feed_candidates()
        last_feed_id = Feed.objects.latest("pk").pk
        trimmed_feeds = 0
        trimmed_stories = 0
        failures = 0
        started = time.time()

        for window_start in range(start, last_feed_id + 1, chunk):
            window_end = window_start + chunk
            feed_ids = list(
                candidates.filter(pk__gte=window_start, pk__lt=window_end)
                .order_by("pk")
                .values_list("pk", flat=True)
            )
            # Counted here on the calling thread, since the feeds are trimmed on several.
            for removed in map_feeds(self.trim_abandoned_feed, feed_ids):
                if removed is None:
                    failures += 1
                elif removed:
                    trimmed_feeds += 1
                    trimmed_stories += removed
            self.stdout.write(
                " ---> Feeds up to %s: %s %s stories from %s feeds, %s failed, %.0fs. Resume with --start %s"
                % (
                    window_end - 1,
                    "would trim" if self.dryrun else "trimmed",
                    trimmed_stories,
                    trimmed_feeds,
                    failures,
                    time.time() - started,
                    window_end,
                )
            )

    def trim_abandoned_feed(self, feed_id):
        """Returns how many stories were trimmed from the feed, or in a dry run, would be.
        Returns None when the feed failed to trim."""
        try:
            return Feed.trim_if_abandoned(feed_id, dryrun=self.dryrun)
        except Exception as e:
            # One bad feed shouldn't stop a pass over millions. Drop a connection the error left
            # unusable so this thread's next feed reconnects.
            sys.stderr.write(" ***> Feed %s failed to trim: %s\n" % (feed_id, e))
            close_old_connections()
            return None
