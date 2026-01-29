"""
Management command to bootstrap Feed objects for popular channels displayed in Add Site view.
This ensures icons and stories are pre-fetched for YouTube channels, newsletters, and podcasts.

Usage:
    python manage.py bootstrap_popular_channels --dry-run
    python manage.py bootstrap_popular_channels --verbose
    python manage.py bootstrap_popular_channels --type youtube
"""

from django.core.management.base import BaseCommand

from apps.rss_feeds.models import Feed


class Command(BaseCommand):
    help = "Pre-create Feed objects for popular channels in Add Site view"

    # Mirroring add_site_view.js POPULAR_YOUTUBE_CHANNELS
    POPULAR_YOUTUBE_CHANNELS = [
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCBcRF18a7Qf58cCRy5xuWwQ",  # MKBHD
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCXuqSBlHAE6Xw-yeJA0Tunw",  # Linus Tech Tips
        "https://www.youtube.com/feeds/videos.xml?channel_id=UC6nSFpj9HTCZ5t-N3Rm3-HA",  # Vsauce
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCsXVk37bltHxD1rDPwtNM8Q",  # Kurzgesagt
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCHnyfMqiRRG1u-2MsSQLbXA",  # Veritasium
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCWX3bGDLdJ8y_E7n2ghDbTQ",  # Tom Scott
        "https://www.youtube.com/feeds/videos.xml?channel_id=UC9-y-6csu5WGm29I7JiwpnA",  # Computerphile
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCy0tKL1T7wFoYcxCe0xjN6Q",  # Technology Connections
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCVHFbqXqoYvEWM1Ddxl0QKg",  # Bloomberg Technology
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCeY0bbntWzzVIaj2z3QigXg",  # NBC News
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCupvZG-5ko_eiXAupbDfxWw",  # CNN
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCYfdidRxbB8Qhf0Nx7ioOYw",  # The Verge
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCddiUEpeqJcYeBxX1IVBKvQ",  # Wired
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCBJycsmduvYEL83R_U4JriQ",  # Marques Brownlee
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCVls1GmFKf6WlTraIb_IaJg",  # DistroTube
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCX6OQ3DkcsbYNE6H8uQQuVA",  # MrBeast
        "https://www.youtube.com/feeds/videos.xml?channel_id=UC-lHJZR3Gqxm24_Vd_AJ5Yw",  # PewDiePie
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCq-Fj5jknLsUf-MWSy4_brA",  # 3Blue1Brown
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCYO_jab_esuFRV4b17AJtAw",  # 3Blue1Brown (main)
        "https://www.youtube.com/feeds/videos.xml?channel_id=UC2C_jShtL725hvbm1arSV9w",  # CGP Grey
    ]

    # Mirroring add_site_view.js POPULAR_NEWSLETTERS
    POPULAR_NEWSLETTERS = [
        "https://thehustle.co/feed/",  # The Hustle
        "https://www.lennysnewsletter.com/feed",  # Lenny's Newsletter
        "https://stratechery.com/feed/",  # Stratechery
        "https://newsletter.pragmaticengineer.com/feed",  # The Pragmatic Engineer
        "https://www.platformer.news/feed",  # Platformer
        "https://www.bloomberg.com/opinion/authors/ARbTQlRLRjE/matthew-s-levine.rss",  # Money Stuff
        "https://towardsdatascience.com/feed",  # Towards Data Science
        "https://betterprogramming.pub/feed",  # Better Programming
        "https://onezero.medium.com/feed",  # OneZero
        "https://css-tricks.com/feed/",  # CSS-Tricks
        "https://www.smashingmagazine.com/feed/",  # Smashing Magazine
        "https://www.morningbrew.com/daily/rss",  # Morning Brew
        "https://www.theverge.com/rss/index.xml",  # The Verge
        "https://feeds.arstechnica.com/arstechnica/index",  # Ars Technica
        "https://news.ycombinator.com/rss",  # Hacker News
    ]

    # Mirroring add_site_view.js POPULAR_PODCASTS
    POPULAR_PODCASTS = [
        "https://feeds.simplecast.com/54nAGcIl",  # The Daily
        "https://feeds.simplecast.com/xl36XBC2",  # Serial
        "https://www.thisamericanlife.org/podcast/rss.xml",  # This American Life
        "https://feeds.simplecast.com/EmVW7VGp",  # Radiolab
        "https://feeds.npr.org/510289/podcast.xml",  # Planet Money
        "https://feeds.npr.org/510313/podcast.xml",  # How I Built This
        "https://feeds.simplecast.com/Y8lFbOT4",  # Freakonomics Radio
        "https://feeds.simplecast.com/JBiZ0WnY",  # Acquired
        "https://lexfridman.com/feed/podcast/",  # Lex Fridman Podcast
        "https://feeds.simplecast.com/4MVDEgRM",  # All-In Podcast
        "https://feeds.megaphone.fm/vergecast",  # The Vergecast
        "https://feeds.simplecast.com/dHoohVNH",  # Conan O'Brien Needs a Friend
        "https://feeds.simplecast.com/xs0YcAjq",  # SmartLess
        "https://feeds.megaphone.fm/stuffyoushouldknow",  # Stuff You Should Know
        "https://feeds.npr.org/510308/podcast.xml",  # Hidden Brain
        "https://feeds.simplecast.com/qm_9xx0g",  # Crime Junkie
        "https://feeds.simplecast.com/GLTi1Mcb",  # My Favorite Murder
        "https://feeds.npr.org/510298/podcast.xml",  # TED Radio Hour
        "https://feeds.megaphone.fm/GLT1412515089",  # The Joe Rogan Experience
        "https://feeds.feedburner.com/dancarlin/history",  # Hardcore History
    ]

    def add_arguments(self, parser):
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Show what would be done without creating feeds",
        )
        parser.add_argument(
            "--type",
            choices=["youtube", "newsletters", "podcasts", "all"],
            default="all",
            help="Type of channels to bootstrap (default: all)",
        )
        parser.add_argument(
            "--force-update",
            action="store_true",
            help="Force update feeds even if they already exist",
        )
        parser.add_argument(
            "--verbose",
            action="store_true",
            help="Show verbose output",
        )

    def handle(self, *args, **options):
        dry_run = options["dry_run"]
        channel_type = options["type"]
        force_update = options["force_update"]
        verbose = options["verbose"]

        urls = []
        if channel_type in ("youtube", "all"):
            urls.extend(self.POPULAR_YOUTUBE_CHANNELS)
        if channel_type in ("newsletters", "all"):
            urls.extend(self.POPULAR_NEWSLETTERS)
        if channel_type in ("podcasts", "all"):
            urls.extend(self.POPULAR_PODCASTS)

        self.stdout.write(f"Processing {len(urls)} feed URLs...")

        created = 0
        existing = 0
        failed = 0

        for url in urls:
            if dry_run:
                self.stdout.write(f"  Would process: {url}")
                continue

            try:
                # Check if feed already exists
                existing_feed = Feed.objects.filter(feed_address=url).first()

                if existing_feed and not force_update:
                    if verbose:
                        self.stdout.write(f"  = {existing_feed.feed_title} (already exists, id={existing_feed.pk})")
                    existing += 1
                    continue

                # Create or get feed
                feed = Feed.get_feed_from_url(url, create=True, fetch=True)
                if feed:
                    if verbose:
                        self.stdout.write(self.style.SUCCESS(f"  + {feed.feed_title} (id={feed.pk})"))

                    # Force update if requested or if feed is new (no stories)
                    if force_update or not feed.fetched_once:
                        feed.update(force=True, single_threaded=True)

                    created += 1
                else:
                    self.stdout.write(self.style.WARNING(f"  x Could not create feed: {url}"))
                    failed += 1
            except Exception as e:
                self.stdout.write(self.style.ERROR(f"  x Error creating {url}: {e}"))
                failed += 1

        if dry_run:
            self.stdout.write(self.style.WARNING(f"\nDry run - no feeds created"))
        else:
            self.stdout.write(
                self.style.SUCCESS(f"\nDone: {created} created/updated, {existing} existing, {failed} failed")
            )
