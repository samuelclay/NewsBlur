"""
Management command to fill missing subcategories and fix rogue categories
for Reddit subreddits in popular_feeds.json.

Processes only entries that need work:
- Entries with empty subcategory
- Entries with categories not in the defined taxonomy

Uses Claude Haiku in batches to assign category + subcategory.

Usage:
    python manage.py categorize_subreddits
    python manage.py categorize_subreddits --dry-run --verbose
    python manage.py categorize_subreddits --batch-size 50
"""

import json
import os

import anthropic
from django.conf import settings
from django.core.management.base import BaseCommand

from utils.llm_costs import LLMCostTracker

from .discover_subreddits import TAXONOMY

FIXTURE_DIR = os.path.join(os.path.dirname(__file__), "../../fixtures")
FIXTURE_PATH = os.path.join(FIXTURE_DIR, "popular_feeds.json")

CLAUDE_MODEL = "claude-haiku-4-5"
DEFAULT_BATCH_SIZE = 100


class Command(BaseCommand):
    help = "Fill missing subcategories and fix rogue categories for Reddit subreddits"

    def add_arguments(self, parser):
        parser.add_argument("--dry-run", action="store_true", help="Preview changes without writing")
        parser.add_argument("--verbose", action="store_true", help="Show each categorization")
        parser.add_argument("--batch-size", type=int, default=DEFAULT_BATCH_SIZE, help="Feeds per Claude API call")

    def handle(self, *args, **options):
        self.verbose = options["verbose"]
        self.dry_run = options["dry_run"]
        self.batch_size = options["batch_size"]

        fixture_path = os.path.normpath(FIXTURE_PATH)
        with open(fixture_path, "r") as f:
            all_feeds = json.load(f)

        reddit_feeds = [f for f in all_feeds if f.get("feed_type") == "reddit"]
        non_reddit = [f for f in all_feeds if f.get("feed_type") != "reddit"]

        self.stdout.write(f"Total feeds: {len(all_feeds)} ({len(reddit_feeds)} reddit, {len(non_reddit)} other)")

        # Find entries needing work
        valid_categories = set(TAXONOMY.keys())
        needs_work = []
        for feed in reddit_feeds:
            category = feed.get("category", "")
            subcategory = feed.get("subcategory", "")
            if category not in valid_categories:
                needs_work.append(feed)
            elif not subcategory:
                needs_work.append(feed)
            elif subcategory not in TAXONOMY.get(category, []):
                needs_work.append(feed)

        missing_subcategory = sum(1 for f in needs_work if not f.get("subcategory"))
        rogue_category = sum(1 for f in needs_work if f.get("category", "") not in valid_categories)
        mismatched = sum(
            1
            for f in needs_work
            if f.get("category", "") in valid_categories
            and f.get("subcategory")
            and f.get("subcategory") not in TAXONOMY.get(f.get("category", ""), [])
        )

        self.stdout.write(f"\nEntries needing work: {len(needs_work)}")
        self.stdout.write(f"  Missing subcategory: {missing_subcategory}")
        self.stdout.write(f"  Rogue category (not in taxonomy): {rogue_category}")
        self.stdout.write(f"  Mismatched subcategory (wrong category): {mismatched}")

        if not needs_work:
            self.stdout.write(self.style.SUCCESS("All entries are properly categorized!"))
            return

        # Show rogue categories
        rogue_cats = {}
        for f in needs_work:
            cat = f.get("category", "")
            if cat not in valid_categories:
                rogue_cats.setdefault(cat, 0)
                rogue_cats[cat] += 1
        if rogue_cats:
            self.stdout.write("\n  Rogue categories:")
            for cat, count in sorted(rogue_cats.items(), key=lambda x: -x[1]):
                self.stdout.write(f"    '{cat}': {count} entries")

        if self.dry_run and not self._has_api_key():
            self.stdout.write(self.style.WARNING("\nDry run - would categorize these entries with Claude"))
            return

        # Categorize with Claude
        api_key = getattr(settings, "ANTHROPIC_API_KEY", None)
        if not api_key:
            self.stderr.write(self.style.ERROR("ANTHROPIC_API_KEY not configured"))
            return

        client = anthropic.Anthropic(api_key=api_key)
        category_list = "\n".join(f"- {cat}: {', '.join(subs)}" for cat, subs in sorted(TAXONOMY.items()))

        # Build lookup for updating feeds in-place
        feed_by_url = {}
        for feed in reddit_feeds:
            feed_by_url[feed["feed_url"]] = feed

        total_updated = 0
        total_skipped = 0

        for i in range(0, len(needs_work), self.batch_size):
            batch = needs_work[i : i + self.batch_size]
            batch_num = i // self.batch_size + 1
            total_batches = (len(needs_work) + self.batch_size - 1) // self.batch_size

            self.stdout.write(f"\n  Batch {batch_num}/{total_batches} ({len(batch)} feeds)...")

            batch_input = [
                {
                    "feed_url": f["feed_url"],
                    "title": f.get("title", ""),
                    "description": f.get("description", ""),
                    "current_category": f.get("category", ""),
                }
                for f in batch
            ]

            results = self._categorize_batch(client, batch_input, category_list)
            if not results:
                self.stderr.write(self.style.ERROR(f"  Batch {batch_num} failed"))
                continue

            for item in results:
                url = item.get("feed_url", "")
                new_cat = item.get("category", "").lower()
                new_sub = item.get("subcategory", "")

                if url not in feed_by_url:
                    continue

                feed = feed_by_url[url]
                old_cat = feed.get("category", "")
                old_sub = feed.get("subcategory", "")

                # Validate Claude's returned pair first
                if new_cat not in TAXONOMY:
                    if self.verbose:
                        self.stdout.write(self.style.WARNING(f"    SKIP {url}: invalid category '{new_cat}'"))
                    total_skipped += 1
                    continue

                if new_sub not in TAXONOMY[new_cat]:
                    if self.verbose:
                        self.stdout.write(
                            self.style.WARNING(
                                f"    SKIP {feed.get('title', url)}: "
                                f"subcategory '{new_sub}' not valid for '{new_cat}'"
                            )
                        )
                    total_skipped += 1
                    continue

                # Keep existing category if valid AND the subcategory works for it
                if old_cat in valid_categories and new_sub in TAXONOMY[old_cat]:
                    final_cat = old_cat
                else:
                    # Category must change to match the subcategory
                    final_cat = new_cat

                if self.verbose:
                    self.stdout.write(
                        f"    {feed.get('title', url)}: "
                        f"'{old_cat}/{old_sub}' -> '{final_cat}/{new_sub}'"
                    )

                if not self.dry_run:
                    feed["category"] = final_cat
                    feed["subcategory"] = new_sub

                total_updated += 1

        self.stdout.write(f"\n  Updated: {total_updated}, Skipped (invalid): {total_skipped}")

        if self.dry_run:
            self.stdout.write(self.style.WARNING("\nDry run - no changes written"))
            return

        # Write back
        reddit_feeds.sort(key=lambda f: (f["category"], f["subcategory"], -f.get("subscriber_count", 0)))
        all_feeds_out = non_reddit + reddit_feeds

        with open(fixture_path, "w") as f:
            json.dump(all_feeds_out, f, indent=2)

        self.stdout.write(self.style.SUCCESS(f"\nWrote {len(all_feeds_out)} feeds to {fixture_path}"))

        # Print remaining gaps
        still_missing = sum(1 for f in reddit_feeds if not f.get("subcategory"))
        still_rogue = sum(1 for f in reddit_feeds if f.get("category", "") not in valid_categories)
        self.stdout.write(f"Remaining: {still_missing} missing subcategory, {still_rogue} rogue category")

    def _has_api_key(self):
        return bool(getattr(settings, "ANTHROPIC_API_KEY", None))

    def _categorize_batch(self, client, feeds, category_list):
        """Categorize a batch of feeds using Claude."""
        feeds_json = json.dumps(feeds, indent=1)

        prompt = f"""Categorize each Reddit subreddit into the best matching category and subcategory.

You MUST choose from EXACTLY these categories and their subcategories.
Do NOT invent new categories or subcategories. Use only what is listed below.

IMPORTANT: If a subreddit has a current_category, you MUST keep that same category
and pick a subcategory from that category's list. Only change the category if
current_category is empty or not in the available list.

Available categories and subcategories:
{category_list}

Subreddits to categorize:
{feeds_json}

For each feed, return the feed_url, best category (lowercase, exactly as listed), and best subcategory (exactly as listed matching the category)."""

        tool_definition = {
            "name": "save_categorized_feeds",
            "description": "Save the categorized subreddits",
            "input_schema": {
                "type": "object",
                "properties": {
                    "feeds": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "feed_url": {"type": "string"},
                                "category": {"type": "string"},
                                "subcategory": {"type": "string"},
                            },
                            "required": ["feed_url", "category", "subcategory"],
                        },
                    }
                },
                "required": ["feeds"],
            },
        }

        try:
            response = client.messages.create(
                model=CLAUDE_MODEL,
                max_tokens=8192,
                tools=[tool_definition],
                tool_choice={"type": "tool", "name": "save_categorized_feeds"},
                messages=[{"role": "user", "content": prompt}],
            )

            LLMCostTracker.record_usage(
                provider="anthropic",
                model=CLAUDE_MODEL,
                feature="categorize_subreddits",
                input_tokens=response.usage.input_tokens,
                output_tokens=response.usage.output_tokens,
            )

            for block in response.content:
                if block.type == "tool_use" and block.name == "save_categorized_feeds":
                    return block.input.get("feeds", [])

        except anthropic.APIError as e:
            self.stderr.write(self.style.ERROR(f"  Claude API error: {e}"))

        return None
