"""
Management command to generate a two-level category taxonomy for popular feeds
using Claude API. Outputs to apps/discover/fixtures/popular_feeds.json.

Uses a two-phase approach:
1. Generate taxonomy structure (categories + subcategories)
2. Generate feeds for each category in separate API calls

Usage:
    python manage.py generate_popular_feeds_taxonomy
    python manage.py generate_popular_feeds_taxonomy --type youtube
    python manage.py generate_popular_feeds_taxonomy --dry-run
"""

import json
import os

import anthropic
from django.conf import settings
from django.core.management.base import BaseCommand

from utils.llm_costs import LLMCostTracker


class Command(BaseCommand):
    help = "Generate two-level category taxonomy for popular feeds using Claude API"

    FIXTURE_PATH = os.path.join(os.path.dirname(__file__), "../../fixtures/popular_feeds.json")

    VALID_TYPES = ["rss", "youtube", "reddit", "newsletter", "podcast"]

    MODEL = "claude-haiku-4-5"

    # Type-specific prompt context
    TYPE_CONFIGS = {
        "rss": {
            "name": "RSS",
            "feed_description": "RSS feeds from blogs and news sites",
            "feed_instructions": (
                "Include traditional blogs, news sites, tech publications, and independent writers. "
                "Use real RSS/Atom feed URLs. Exclude YouTube channels, Reddit subreddits, "
                "email newsletters, and podcasts. Focus on sites with well-known RSS feeds. "
                "Platform should be empty string."
            ),
        },
        "youtube": {
            "name": "YouTube",
            "feed_description": "YouTube channels",
            "feed_instructions": (
                "For each channel, provide the real YouTube channel_id (e.g., UCBcRF18a7Qf58cCRy5xuWwQ). "
                "The feed_url must be: https://www.youtube.com/feeds/videos.xml?channel_id=<real_channel_id>. "
                "Only use REAL existing YouTube channels with their actual channel IDs. "
                "Platform should be empty string."
            ),
        },
        "reddit": {
            "name": "Reddit",
            "feed_description": "Reddit subreddits",
            "feed_instructions": (
                "For each subreddit, provide the real subreddit name (e.g., 'programming'). "
                "The feed_url must be: https://www.reddit.com/r/<subreddit_name>/.rss. "
                "Only use REAL existing subreddits. Platform should be empty string."
            ),
        },
        "newsletter": {
            "name": "Newsletter",
            "feed_description": "newsletters",
            "feed_instructions": (
                "Include newsletters from various platforms: Substack, Medium, Ghost, Buttondown, etc. "
                "Set the 'platform' field appropriately (substack, medium, ghost, buttondown, generic, direct). "
                "Use real RSS/Atom feed URLs. For Substack: https://name.substack.com/feed. "
                "For Medium: https://medium.com/feed/@username or https://medium.com/feed/publication."
            ),
        },
        "podcast": {
            "name": "Podcast",
            "feed_description": "podcasts",
            "feed_instructions": (
                "Use real podcast RSS feed URLs from hosts like Simplecast, NPR, Megaphone, Libsyn, etc. "
                "The feed_url must be a real, working RSS feed URL for the podcast. "
                "Platform should be empty string."
            ),
        },
    }

    def add_arguments(self, parser):
        parser.add_argument(
            "--type",
            choices=self.VALID_TYPES + ["all"],
            default="all",
            help="Type of feeds to generate taxonomy for (default: all)",
        )
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Preview taxonomy structure without writing fixture file",
        )
        parser.add_argument(
            "--verbose",
            action="store_true",
            help="Show detailed output including API responses",
        )

    def handle(self, *args, **options):
        feed_type = options["type"]
        dry_run = options["dry_run"]
        verbose = options["verbose"]

        api_key = getattr(settings, "ANTHROPIC_API_KEY", None)
        if not api_key:
            self.stderr.write(self.style.ERROR("ANTHROPIC_API_KEY not configured in settings"))
            return

        client = anthropic.Anthropic(api_key=api_key)

        # Load existing fixture data to use as seed
        fixture_path = os.path.normpath(self.FIXTURE_PATH)
        existing_feeds = []
        if os.path.exists(fixture_path):
            with open(fixture_path, "r") as f:
                existing_feeds = json.load(f)

        types_to_generate = self.VALID_TYPES if feed_type == "all" else [feed_type]
        all_results = []

        for ftype in types_to_generate:
            self.stdout.write(f"\nGenerating taxonomy for {ftype}...")

            seed_feeds = [f for f in existing_feeds if f["feed_type"] == ftype]

            # For RSS type, also load DB-discovered candidates as seed data
            if ftype == "rss" and not seed_feeds:
                candidates_path = os.path.join(os.path.dirname(self.FIXTURE_PATH), "rss_candidates.json")
                candidates_path = os.path.normpath(candidates_path)
                if os.path.exists(candidates_path):
                    with open(candidates_path, "r") as f:
                        candidates = json.load(f)
                    seed_feeds = [
                        {
                            "feed_type": "rss",
                            "category": "",
                            "title": c["title"],
                            "feed_url": c["feed_url"],
                            "subscriber_count": c.get("subscriber_count", 0),
                        }
                        for c in candidates
                    ]
                    self.stdout.write(f"  Loaded {len(seed_feeds)} RSS candidates as seed data")

            # Phase 1: Generate taxonomy structure
            taxonomy = self._generate_taxonomy_structure(client, ftype, seed_feeds, verbose)
            if not taxonomy:
                self.stderr.write(self.style.ERROR(f"  Failed to generate taxonomy for {ftype}"))
                continue

            self.stdout.write(f"  Got {len(taxonomy)} categories")

            # Phase 2: Generate feeds for each category
            for cat_info in taxonomy:
                cat_name = cat_info["name"]
                subcategories = cat_info["subcategories"]
                self.stdout.write(f"  Generating feeds for {cat_name} ({len(subcategories)} subcategories)...")

                feeds = self._generate_feeds_for_category(
                    client, ftype, cat_name, subcategories, seed_feeds, verbose
                )
                if feeds:
                    all_results.extend(feeds)
                    if verbose:
                        self.stdout.write(f"    Got {len(feeds)} feeds")
                else:
                    self.stderr.write(self.style.WARNING(f"    No feeds generated for {cat_name}"))

            self.stdout.write(
                self.style.SUCCESS(
                    f"  Total: {len([f for f in all_results if f['feed_type'] == ftype])} feeds for {ftype}"
                )
            )

        if dry_run:
            self.stdout.write(self.style.WARNING("\nDry run - not writing fixture file"))
            self._print_taxonomy_summary(all_results)
            return

        if not all_results:
            self.stderr.write(self.style.ERROR("No results generated"))
            return

        # If generating for a single type, merge with existing data for other types
        if feed_type != "all":
            other_feeds = [f for f in existing_feeds if f["feed_type"] not in types_to_generate]
            all_results = other_feeds + all_results

        with open(fixture_path, "w") as f:
            json.dump(all_results, f, indent=2)

        self.stdout.write(self.style.SUCCESS(f"\nWrote {len(all_results)} feeds to {fixture_path}"))
        self._print_taxonomy_summary(all_results)

    def _generate_taxonomy_structure(self, client, feed_type, seed_feeds, verbose):
        """Phase 1: Generate taxonomy structure (categories + subcategories, no feeds)."""
        config = self.TYPE_CONFIGS[feed_type]

        # Build seed categories summary
        seed_cats = ""
        if seed_feeds:
            from collections import Counter

            cat_counts = Counter(f["category"] for f in seed_feeds)
            seed_cats = "\n\nExisting categories to build upon: " + ", ".join(
                f"{cat} ({count})" for cat, count in cat_counts.most_common()
            )

        prompt = f"""Generate a category taxonomy for popular {config['feed_description']}.

Create 35-40 top-level categories (broad topics) with 8-10 subcategories each.
Categories should cover the most popular and distinct topic areas for {config['name']}.

You MUST include all of these existing categories: Technology, Science, Gaming, Education, Entertainment, News & Politics, Sports, Music, Comedy & Humor, Business, Food & Cooking, Travel, DIY & Crafts, Photography, Automotive, Finance, Parenting, Design, Environment & Sustainability, Health & Fitness, Lifestyle, Pets & Animals, Arts & Culture, Home & Garden, Sports & Recreation.

Then add 12+ NEW categories beyond those. Examples of new categories to add: History, Psychology & Mental Health, Books & Reading, Anime & Manga, Architecture, Law & Legal, Real Estate, Space & Astronomy, Philosophy, Religion & Spirituality, Fashion & Beauty, Military & Defense, Weather & Climate, Economics, Cryptocurrency & Web3, Data Science & Analytics, etc.

Subcategories should be specific niches within each category.
Example: Technology -> Reviews, Programming, AI, Gadgets, Cybersecurity, Open Source, Cloud, Mobile
{seed_cats}"""

        tool_definition = {
            "name": "save_taxonomy_structure",
            "description": "Save the taxonomy structure with categories and subcategories",
            "input_schema": {
                "type": "object",
                "properties": {
                    "categories": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string", "description": "Category name"},
                                "subcategories": {
                                    "type": "array",
                                    "items": {"type": "string"},
                                    "description": "List of subcategory names",
                                },
                            },
                            "required": ["name", "subcategories"],
                        },
                    }
                },
                "required": ["categories"],
            },
        }

        try:
            response = client.messages.create(
                model=self.MODEL,
                max_tokens=4096,
                tools=[tool_definition],
                tool_choice={"type": "tool", "name": "save_taxonomy_structure"},
                messages=[{"role": "user", "content": prompt}],
            )

            LLMCostTracker.record_usage(
                provider="anthropic",
                model=self.MODEL,
                feature="generate_popular_feeds_taxonomy",
                input_tokens=response.usage.input_tokens,
                output_tokens=response.usage.output_tokens,
            )
            if verbose:
                self.stdout.write(
                    f"  Taxonomy structure: {response.usage.input_tokens} in, "
                    f"{response.usage.output_tokens} out tokens"
                )

            for block in response.content:
                if block.type == "tool_use" and block.name == "save_taxonomy_structure":
                    return block.input.get("categories", [])

            self.stderr.write(
                self.style.ERROR(f"  No tool_use block. Stop: {response.stop_reason}")
            )
            return None

        except anthropic.APIError as e:
            self.stderr.write(self.style.ERROR(f"  Anthropic API error: {e}"))
            return None

    def _generate_feeds_for_category(self, client, feed_type, category, subcategories, seed_feeds, verbose):
        """Phase 2: Generate feeds for one category with its subcategories."""
        config = self.TYPE_CONFIGS[feed_type]

        # Build seed data for this category
        seed_summary = ""
        cat_seeds = [f for f in seed_feeds if f["category"].lower() == category.lower()]
        if cat_seeds:
            seed_entries = [f"- {f['title']} ({f['feed_url']})" for f in cat_seeds[:10]]
            seed_summary = "\n\nExisting entries to include:\n" + "\n".join(seed_entries)

        subcats_str = ", ".join(subcategories)
        prompt = f"""Generate popular {config['feed_description']} for the "{category}" category.

Subcategories: {subcats_str}

For each subcategory, provide 10-15 popular, real {config['feed_description']}.
{config['feed_instructions']}

Each feed needs: title, description (under 80 chars), feed_url, subscriber_count (integer), platform (string).
{seed_summary}

Only include feeds you are confident actually exist."""

        tool_definition = {
            "name": "save_category_feeds",
            "description": f"Save feeds for the {category} category",
            "input_schema": {
                "type": "object",
                "properties": {
                    "subcategories": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string"},
                                "feeds": {
                                    "type": "array",
                                    "items": {
                                        "type": "object",
                                        "properties": {
                                            "title": {"type": "string"},
                                            "description": {"type": "string"},
                                            "feed_url": {"type": "string"},
                                            "subscriber_count": {"type": "integer"},
                                            "platform": {"type": "string"},
                                        },
                                        "required": ["title", "description", "feed_url", "subscriber_count"],
                                    },
                                },
                            },
                            "required": ["name", "feeds"],
                        },
                    }
                },
                "required": ["subcategories"],
            },
        }

        try:
            response = client.messages.create(
                model=self.MODEL,
                max_tokens=16384,
                tools=[tool_definition],
                tool_choice={"type": "tool", "name": "save_category_feeds"},
                messages=[{"role": "user", "content": prompt}],
            )

            LLMCostTracker.record_usage(
                provider="anthropic",
                model=self.MODEL,
                feature="generate_popular_feeds_taxonomy",
                input_tokens=response.usage.input_tokens,
                output_tokens=response.usage.output_tokens,
            )

            for block in response.content:
                if block.type == "tool_use" and block.name == "save_category_feeds":
                    data = block.input
                    return self._flatten_category_feeds(feed_type, category, data)

            if verbose:
                self.stderr.write(
                    self.style.WARNING(f"    No tool_use for {category}. Stop: {response.stop_reason}")
                )
            return None

        except anthropic.APIError as e:
            self.stderr.write(self.style.ERROR(f"    API error for {category}: {e}"))
            return None

    def _flatten_category_feeds(self, feed_type, category, data):
        """Convert category feeds response into flat list of feed entries."""
        feeds = []
        category_name = category.lower()

        for subcategory in data.get("subcategories", []):
            subcategory_name = subcategory["name"]
            for feed in subcategory.get("feeds", []):
                feeds.append(
                    {
                        "feed_type": feed_type,
                        "category": category_name,
                        "subcategory": subcategory_name,
                        "title": feed["title"],
                        "description": feed.get("description", ""),
                        "feed_url": feed["feed_url"],
                        "subscriber_count": feed.get("subscriber_count", 0),
                        "platform": feed.get("platform", ""),
                        "thumbnail_url": "",
                    }
                )

        return feeds

    def _print_taxonomy_summary(self, feeds):
        """Print a summary of the generated taxonomy."""
        from collections import Counter

        self.stdout.write("\n--- Taxonomy Summary ---")

        type_counts = Counter(f["feed_type"] for f in feeds)
        for ftype, count in sorted(type_counts.items()):
            self.stdout.write(f"\n{ftype}: {count} feeds")

            type_feeds = [f for f in feeds if f["feed_type"] == ftype]
            cat_counts = Counter(f["category"] for f in type_feeds)
            for cat, cat_count in sorted(cat_counts.items()):
                cat_feeds = [f for f in type_feeds if f["category"] == cat]
                subcat_counts = Counter(f.get("subcategory", "") for f in cat_feeds)
                subcats = [s for s in subcat_counts.keys() if s]
                if subcats:
                    self.stdout.write(f"  {cat} ({cat_count}): {', '.join(subcats)}")
                else:
                    self.stdout.write(f"  {cat}: {cat_count}")

        self.stdout.write(f"\nTotal: {len(feeds)} feeds")
