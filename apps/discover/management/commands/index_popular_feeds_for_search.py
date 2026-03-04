"""
Management command to index PopularFeed entries into SearchFeed with embeddings.
Links PopularFeed entries to Feed objects and generates content vectors for
semantic search in the Add Site modal.

Usage:
    python manage.py index_popular_feeds_for_search
    python manage.py index_popular_feeds_for_search --type reddit
    python manage.py index_popular_feeds_for_search --type youtube --offset 100
    python manage.py index_popular_feeds_for_search --dry-run
"""

from django.core.management.base import BaseCommand

from apps.discover.models import PopularFeed
from apps.rss_feeds.models import Feed
from apps.search.models import SearchFeed
from utils import log as logging


class Command(BaseCommand):
    help = "Index PopularFeed entries into SearchFeed with embeddings for semantic search"

    VALID_TYPES = ["rss", "youtube", "reddit", "newsletter", "podcast"]

    def add_arguments(self, parser):
        parser.add_argument(
            "--type",
            type=str,
            choices=self.VALID_TYPES,
            help="Only index feeds of this type",
        )
        parser.add_argument(
            "--offset",
            type=int,
            default=0,
            help="Start from this offset (for resuming)",
        )
        parser.add_argument(
            "--limit",
            type=int,
            default=0,
            help="Max number of feeds to index (0 = all)",
        )
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Show what would be indexed without actually doing it",
        )
        parser.add_argument(
            "--reindex",
            action="store_true",
            help="Re-index feeds that are already in SearchFeed",
        )

    def handle(self, *args, **options):
        feed_type = options.get("type")
        offset = options["offset"]
        limit = options["limit"]
        dry_run = options["dry_run"]
        reindex = options["reindex"]

        qs = PopularFeed.objects.filter(is_active=True)
        if feed_type:
            qs = qs.filter(feed_type=feed_type)
        qs = qs.order_by("pk")

        total = qs.count()
        self.stdout.write(f"Found {total} active PopularFeed entries" + (f" (type={feed_type})" if feed_type else ""))

        if offset:
            qs = qs[offset:]
        if limit:
            qs = qs[:limit]

        linked = 0
        indexed = 0
        skipped = 0
        failed = 0
        already_indexed = 0

        for i, pf in enumerate(qs.iterator()):
            position = offset + i + 1
            if position % 100 == 0:
                self.stdout.write(
                    f"  Progress: {position}/{total} "
                    f"(linked={linked}, indexed={indexed}, skipped={skipped}, failed={failed})"
                )

            # Link to Feed object if not already linked
            if not pf.feed_id:
                if dry_run:
                    self.stdout.write(f"  [dry-run] Would link: {pf.title}")
                    skipped += 1
                    continue
                try:
                    # Look up by exact feed_address first (fast, no HTTP)
                    feed = Feed.objects.filter(feed_address=pf.feed_url).first()
                    if not feed:
                        # Create directly - we already know the RSS URL
                        feed = Feed.objects.create(feed_address=pf.feed_url, feed_title=pf.title)
                    pf.feed = feed
                    pf.save(update_fields=["feed"])
                    linked += 1
                except Exception as e:
                    self.stdout.write(self.style.WARNING(f"  Failed to link {pf.title}: {e}"))
                    failed += 1
                    continue

            feed_id = pf.feed_id

            # Check if already indexed (unless reindexing)
            if not reindex:
                try:
                    existing = SearchFeed.ES().exists(
                        index=SearchFeed.index_name(), id=feed_id, doc_type=SearchFeed.doc_type()
                    )
                    if existing:
                        already_indexed += 1
                        continue
                except Exception:
                    pass

            if dry_run:
                self.stdout.write(f"  [dry-run] Would index: {pf.title} (feed_id={feed_id})")
                skipped += 1
                continue

            # Build embedding text from PopularFeed title + description
            text = f"{pf.title} {pf.description}"

            # If the Feed has been fetched and has stories, use richer content
            try:
                feed_obj = Feed.objects.get(pk=feed_id)
                if feed_obj.feed_title and feed_obj.feed_title not in ("", "[Untitled]"):
                    text = f"{feed_obj.feed_title} {text}"
                if hasattr(feed_obj, "data") and feed_obj.data and feed_obj.data.feed_tagline:
                    text = f"{text} {feed_obj.data.feed_tagline}"
                stories = feed_obj.get_stories(limit=10)
                if stories:
                    stories_text = " ".join(
                        f"{s['story_title']} {' '.join(s.get('story_tags', []))}" for s in stories
                    )
                    text = f"{text} {stories_text}"
            except Feed.DoesNotExist:
                pass

            try:
                content_vector = SearchFeed.generate_content_vector_from_text(
                    text,
                    feature="popular_feed_embedding",
                    metadata={"popular_feed_id": pf.pk, "feed_type": pf.feed_type},
                )
                if not content_vector:
                    skipped += 1
                    continue

                # Get feed details for indexing
                try:
                    feed_obj = Feed.objects.get(pk=feed_id)
                    title = feed_obj.feed_title if feed_obj.feed_title not in ("", "[Untitled]") else pf.title
                    address = feed_obj.feed_address
                    link = feed_obj.feed_link or pf.feed_url
                    num_subscribers = max(feed_obj.num_subscribers, pf.subscriber_count)
                except Feed.DoesNotExist:
                    title = pf.title
                    address = pf.feed_url
                    link = pf.feed_url
                    num_subscribers = pf.subscriber_count

                SearchFeed.index(
                    feed_id=feed_id,
                    title=title,
                    address=address,
                    link=link,
                    num_subscribers=num_subscribers,
                    content_vector=content_vector,
                )
                indexed += 1

            except Exception as e:
                self.stdout.write(self.style.WARNING(f"  Failed to index {pf.title}: {e}"))
                failed += 1

        self.stdout.write(
            self.style.SUCCESS(
                f"\nDone: {indexed} indexed, {linked} newly linked, "
                f"{already_indexed} already indexed, {skipped} skipped, {failed} failed"
            )
        )
