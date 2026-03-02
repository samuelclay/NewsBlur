"""
Management command to backfill underpopulated subcategories in the popular feeds fixture.
Uses multiple discovery sources (Feedly API, GitHub OPMLs) and Claude-based categorization
to find real feeds for subcategories that have fewer than the minimum required feeds.

Usage:
    python manage.py backfill_underpopulated_feeds --dry-run
    python manage.py backfill_underpopulated_feeds --verbose
    python manage.py backfill_underpopulated_feeds --category parenting --verbose
    python manage.py backfill_underpopulated_feeds --resume
    python manage.py backfill_underpopulated_feeds --skip-feedly --verbose  # GitHub OPMLs only
"""

import json
import os
import time
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict

import anthropic
import requests
from django.conf import settings
from django.core.management.base import BaseCommand

from utils.llm_costs import LLMCostTracker

FIXTURE_DIR = os.path.join(os.path.dirname(__file__), "../../fixtures")
FIXTURE_PATH = os.path.join(FIXTURE_DIR, "popular_feeds.json")
CACHE_PATH = os.path.join(FIXTURE_DIR, "backfill_cache.json")

FEEDLY_SEARCH_URL = "https://cloud.feedly.com/v3/search/feeds"
FEEDLY_DELAY = 2.0
FEEDLY_RATE_LIMIT_WAIT = 60

CLAUDE_MODEL = "claude-haiku-4-5"
CATEGORIZE_BATCH_SIZE = 50

SKIP_DOMAINS = [
    "youtube.com",
    "reddit.com",
    "substack.com",
    "medium.com/feed",
]

# GitHub OPML sources for RSS feed discovery (no rate limiting)
_AWESOME_RSS_BASE = (
    "https://raw.githubusercontent.com/plenaryapp/awesome-rss-feeds/master/recommended/with_category"
)
GITHUB_OPML_SOURCES = [
    (f"{_AWESOME_RSS_BASE}/Tech.opml", "Tech"),
    (f"{_AWESOME_RSS_BASE}/Programming.opml", "Programming"),
    (f"{_AWESOME_RSS_BASE}/Web%20Development.opml", "Web Development"),
    (f"{_AWESOME_RSS_BASE}/Android%20Development.opml", "Android Dev"),
    (f"{_AWESOME_RSS_BASE}/iOS%20Development.opml", "iOS Dev"),
    (f"{_AWESOME_RSS_BASE}/Science.opml", "Science"),
    (f"{_AWESOME_RSS_BASE}/Space.opml", "Space"),
    (f"{_AWESOME_RSS_BASE}/News.opml", "News"),
    (f"{_AWESOME_RSS_BASE}/Business%20%26%20Economy.opml", "Business"),
    (f"{_AWESOME_RSS_BASE}/Startups.opml", "Startups"),
    (f"{_AWESOME_RSS_BASE}/Personal%20finance.opml", "Personal Finance"),
    (f"{_AWESOME_RSS_BASE}/Gaming.opml", "Gaming"),
    (f"{_AWESOME_RSS_BASE}/Sports.opml", "Sports"),
    (f"{_AWESOME_RSS_BASE}/Football.opml", "Football"),
    (f"{_AWESOME_RSS_BASE}/Cricket.opml", "Cricket"),
    (f"{_AWESOME_RSS_BASE}/Tennis.opml", "Tennis"),
    (f"{_AWESOME_RSS_BASE}/Music.opml", "Music"),
    (f"{_AWESOME_RSS_BASE}/Movies.opml", "Movies"),
    (f"{_AWESOME_RSS_BASE}/Television.opml", "Television"),
    (f"{_AWESOME_RSS_BASE}/Food.opml", "Food"),
    (f"{_AWESOME_RSS_BASE}/Travel.opml", "Travel"),
    (f"{_AWESOME_RSS_BASE}/Photography.opml", "Photography"),
    (f"{_AWESOME_RSS_BASE}/Fashion.opml", "Fashion"),
    (f"{_AWESOME_RSS_BASE}/Beauty.opml", "Beauty"),
    (f"{_AWESOME_RSS_BASE}/Books.opml", "Books"),
    (f"{_AWESOME_RSS_BASE}/History.opml", "History"),
    (f"{_AWESOME_RSS_BASE}/DIY.opml", "DIY"),
    (f"{_AWESOME_RSS_BASE}/Cars.opml", "Cars"),
    (f"{_AWESOME_RSS_BASE}/Architecture.opml", "Architecture"),
    (f"{_AWESOME_RSS_BASE}/UI%20-%20UX.opml", "UI/UX"),
    (f"{_AWESOME_RSS_BASE}/Android.opml", "Android"),
    (f"{_AWESOME_RSS_BASE}/Apple.opml", "Apple"),
    (f"{_AWESOME_RSS_BASE}/Funny.opml", "Funny"),
    (f"{_AWESOME_RSS_BASE}/Interior%20design.opml", "Interior Design"),
    (
        "https://raw.githubusercontent.com/kilimchoi/engineering-blogs/master/engineering_blogs.opml",
        "Engineering Blogs",
    ),
]


class Command(BaseCommand):
    help = "Backfill underpopulated subcategories in popular feeds fixture using Feedly API"

    def add_arguments(self, parser):
        parser.add_argument(
            "--min-feeds", type=int, default=8, help="Minimum feeds per subcategory (default: 8)"
        )
        parser.add_argument(
            "--type",
            choices=["rss", "youtube", "reddit", "newsletter", "podcast"],
            default="rss",
            help="Feed type to backfill (default: rss)",
        )
        parser.add_argument("--category", type=str, default=None, help="Only backfill this category")
        parser.add_argument("--dry-run", action="store_true", help="Analyze gaps without calling APIs")
        parser.add_argument("--verbose", action="store_true", help="Show detailed output")
        parser.add_argument("--resume", action="store_true", help="Resume from cached Feedly results")
        parser.add_argument(
            "--use-proxy",
            action="store_true",
            help="Use ScrapingBee proxy for Feedly (avoids rate limits)",
        )
        parser.add_argument(
            "--feedly-count",
            type=int,
            default=40,
            help="Results per Feedly search (max 100, default 40)",
        )
        parser.add_argument(
            "--skip-keyword-gen",
            action="store_true",
            help="Skip Claude keyword generation, use basic queries only",
        )
        parser.add_argument(
            "--skip-feedly",
            action="store_true",
            help="Skip Feedly search (use GitHub OPMLs only)",
        )
        parser.add_argument(
            "--skip-github",
            action="store_true",
            help="Skip GitHub OPML sources",
        )

    def handle(self, *args, **options):
        self.verbose = options["verbose"]
        self.dry_run = options["dry_run"]
        self.use_proxy = options["use_proxy"]
        self.min_feeds = options["min_feeds"]
        self.feed_type = options["type"]
        self.feedly_count = options["feedly_count"]
        self.category_filter = options["category"]
        self.resume = options["resume"]
        self.skip_keyword_gen = options["skip_keyword_gen"]
        self.skip_feedly = options["skip_feedly"]
        self.skip_github = options["skip_github"]

        # Step 1: Load fixture and identify gaps
        fixture_path = os.path.normpath(FIXTURE_PATH)
        if not os.path.exists(fixture_path):
            self.stderr.write(self.style.ERROR(f"Fixture file not found: {fixture_path}"))
            return

        with open(fixture_path, "r") as f:
            all_feeds = json.load(f)

        existing_urls = {f["feed_url"] for f in all_feeds}
        gaps = self._find_gaps(all_feeds)

        if not gaps:
            self.stdout.write(self.style.SUCCESS("All subcategories meet the minimum feed count!"))
            return

        total_subcats = sum(len(subs) for subs in gaps.values())
        total_needed = sum(self.min_feeds - cnt for subs in gaps.values() for _, cnt in subs)
        self.stdout.write(
            f"Found {total_subcats} underpopulated subcategories across {len(gaps)} categories"
        )
        self.stdout.write(f"Need ~{total_needed} new feeds to reach minimum of {self.min_feeds} each")

        if self.dry_run:
            self._print_gap_analysis(gaps)
            return

        all_discovered = []

        # Step 2a: GitHub OPML discovery (no rate limiting)
        if not self.skip_github:
            github_feeds = self._fetch_github_opmls(existing_urls)
            if github_feeds:
                self.stdout.write(f"\nDiscovered {len(github_feeds)} new feeds from GitHub OPMLs")
                all_discovered.extend(github_feeds)
                existing_urls.update(f["feed_url"] for f in github_feeds)

        # Step 2b: Feedly search
        if not self.skip_feedly:
            search_queries = self._generate_search_queries(gaps)
            feedly_feeds = self._search_feedly(search_queries, existing_urls)
            if feedly_feeds:
                self.stdout.write(f"\nDiscovered {len(feedly_feeds)} new feeds from Feedly")
                all_discovered.extend(feedly_feeds)
                existing_urls.update(f["feed_url"] for f in feedly_feeds)

        # Step 2c: LLM-suggested feeds with HTTP verification
        # Use Claude to suggest real feeds, then verify each URL serves valid content
        llm_feeds = self._discover_via_llm_suggestions(gaps, existing_urls, all_feeds=all_feeds)
        if llm_feeds:
            self.stdout.write(f"\nVerified {len(llm_feeds)} feeds from LLM suggestions")
            all_discovered.extend(llm_feeds)

        if not all_discovered:
            self.stdout.write(self.style.WARNING("No new feeds discovered from any source"))
            return

        self.stdout.write(f"\nTotal discovered: {len(all_discovered)} new feeds")

        # Step 3: Categorize discovered feeds with Claude
        categorized_feeds = self._categorize_and_assign(all_discovered, gaps)

        if not categorized_feeds:
            self.stdout.write(
                self.style.WARNING("No feeds matched target subcategories after categorization")
            )
            return

        self.stdout.write(f"Categorized {len(categorized_feeds)} feeds into target subcategories")

        # Step 4: Merge into fixture
        all_feeds.extend(categorized_feeds)

        with open(fixture_path, "w") as f:
            json.dump(all_feeds, f, indent=2)

        self.stdout.write(self.style.SUCCESS(f"\nAdded {len(categorized_feeds)} new feeds to fixture"))
        self._print_post_merge_summary(all_feeds)

    def _find_gaps(self, all_feeds):
        """Identify subcategories with fewer than min_feeds feeds."""
        type_feeds = [f for f in all_feeds if f.get("feed_type", "rss") == self.feed_type]
        subcat_counts = Counter()
        for feed in type_feeds:
            sub = feed.get("subcategory", "")
            if sub:
                subcat_counts[(feed["category"], sub)] += 1

        gaps = defaultdict(list)
        for (cat, sub), cnt in sorted(subcat_counts.items()):
            if cnt < self.min_feeds:
                if self.category_filter and cat != self.category_filter.lower():
                    continue
                gaps[cat].append((sub, cnt))

        return dict(gaps)

    def _print_gap_analysis(self, gaps):
        """Print detailed gap analysis."""
        self.stdout.write("\n--- Gap Analysis ---")
        for cat in sorted(gaps.keys()):
            subs = gaps[cat]
            cat_needed = sum(self.min_feeds - cnt for _, cnt in subs)
            self.stdout.write(f"\n{cat} ({len(subs)} subcats, needs {cat_needed} feeds):")
            for sub, cnt in subs:
                needed = self.min_feeds - cnt
                self.stdout.write(f"  {sub}: has {cnt}, needs {needed} more")

    def _generate_search_queries(self, gaps):
        """Generate effective Feedly search queries for each subcategory.

        Uses Claude to generate short, keyword-based queries that work well with
        Feedly's search API (which needs 1-3 word queries, not full phrases).
        """
        if self.skip_keyword_gen:
            return self._basic_search_queries(gaps)

        api_key = getattr(settings, "ANTHROPIC_API_KEY", None)
        if not api_key:
            self.stderr.write(
                self.style.WARNING("No ANTHROPIC_API_KEY, using basic keyword queries")
            )
            return self._basic_search_queries(gaps)

        client = anthropic.Anthropic(api_key=api_key)

        # Build the subcategory list for the prompt
        subcats_list = []
        for cat, subs in sorted(gaps.items()):
            for sub, cnt in subs:
                subcats_list.append({"category": cat, "subcategory": sub, "current_count": cnt})

        self.stdout.write(f"\nGenerating search keywords for {len(subcats_list)} subcategories...")

        # Batch subcategories by category for efficient API calls
        all_queries = []
        cat_batches = defaultdict(list)
        for item in subcats_list:
            cat_batches[item["category"]].append(item)

        batch_num = 0
        total_batches = len(cat_batches)

        for cat, items in sorted(cat_batches.items()):
            batch_num += 1
            self.stdout.write(f"  [{batch_num}/{total_batches}] {cat} ({len(items)} subcategories)...")

            subcats_str = "\n".join(
                f"- {item['subcategory']} (needs {self.min_feeds - item['current_count']} more feeds)"
                for item in items
            )

            prompt = f"""Generate Feedly search queries to find RSS blog feeds for these subcategories in the "{cat}" category.

Feedly search works best with SHORT queries (1-3 words). Multi-word phrases often return 0 results.
Generate 6-8 different short keyword queries per subcategory that would find relevant RSS feeds/blogs.

Subcategories needing feeds:
{subcats_str}

Examples of GOOD queries (short, specific):
- For "Baby & Toddler": "newborn blog", "baby care", "toddler", "infant parenting", "baby tips", "newborn mom"
- For "Medieval History": "medieval blog", "medieval news", "middle ages", "medieval", "castle history"
- For "Vegan & Vegetarian": "vegan blog", "vegan recipes", "vegetarian", "plant based", "vegan food"

Examples of BAD queries (too long, too specific):
- "baby and toddler parenting advice blog" (too many words)
- "best medieval history blogs 2024" (Feedly doesn't search like Google)"""

            tool_definition = {
                "name": "save_search_queries",
                "description": f"Save search queries for {cat} subcategories",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "subcategories": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "subcategory": {"type": "string"},
                                    "queries": {
                                        "type": "array",
                                        "items": {"type": "string"},
                                        "description": "Short 1-3 word search queries",
                                    },
                                },
                                "required": ["subcategory", "queries"],
                            },
                        }
                    },
                    "required": ["subcategories"],
                },
            }

            try:
                response = client.messages.create(
                    model=CLAUDE_MODEL,
                    max_tokens=4096,
                    tools=[tool_definition],
                    tool_choice={"type": "tool", "name": "save_search_queries"},
                    messages=[{"role": "user", "content": prompt}],
                )

                LLMCostTracker.record_usage(
                    provider="anthropic",
                    model=CLAUDE_MODEL,
                    feature="backfill_keyword_gen",
                    input_tokens=response.usage.input_tokens,
                    output_tokens=response.usage.output_tokens,
                )

                for block in response.content:
                    if block.type == "tool_use" and block.name == "save_search_queries":
                        data = block.input.get("subcategories", [])
                        for subcat_data in data:
                            sub_name = subcat_data["subcategory"]
                            queries = subcat_data.get("queries", [])
                            for q in queries:
                                all_queries.append((q, cat, sub_name))
                            if self.verbose:
                                self.stdout.write(
                                    f"    {sub_name}: {len(queries)} queries - {queries[:3]}..."
                                )

            except anthropic.APIError as e:
                self.stderr.write(self.style.ERROR(f"  Claude API error for {cat}: {e}"))
                # Fall back to basic queries for this category
                for item in items:
                    for q in self._basic_queries_for_subcategory(item["category"], item["subcategory"]):
                        all_queries.append((q, item["category"], item["subcategory"]))

        self.stdout.write(f"Generated {len(all_queries)} search queries total")
        return all_queries

    def _basic_search_queries(self, gaps):
        """Generate basic search queries without Claude."""
        queries = []
        for cat, subs in sorted(gaps.items()):
            for sub, _ in subs:
                for q in self._basic_queries_for_subcategory(cat, sub):
                    queries.append((q, cat, sub))
        return queries

    def _basic_queries_for_subcategory(self, category, subcategory):
        """Generate basic keyword queries for a single subcategory."""
        queries = [subcategory]

        # Split subcategory into individual words and use them
        words = [w for w in subcategory.replace("&", "").split() if len(w) > 2]
        if len(words) >= 2:
            queries.append(words[0])
            queries.append(f"{words[0]} blog")

        queries.append(f"{subcategory} blog")
        queries.append(f"{category} {words[0]}" if words else f"{category} {subcategory}")
        return queries

    def _load_cache(self):
        """Load cached results."""
        cache_path = os.path.normpath(CACHE_PATH)
        if os.path.exists(cache_path):
            with open(cache_path, "r") as f:
                return json.load(f)
        return {"feeds": {}, "completed_queries": []}

    def _save_cache(self, cache):
        """Save results to cache."""
        cache_path = os.path.normpath(CACHE_PATH)
        with open(cache_path, "w") as f:
            json.dump(cache, f)

    def _feedly_get(self, url, params):
        """Make a GET request to Feedly, optionally through ScrapingBee proxy."""
        if self.use_proxy:
            scrapingbee_key = getattr(settings, "SCRAPINGBEE_API_KEY", None)
            if not scrapingbee_key:
                self.stderr.write(self.style.ERROR("SCRAPINGBEE_API_KEY not configured"))
                return None

            from urllib.parse import urlencode

            full_url = f"{url}?{urlencode(params)}"
            resp = requests.get(
                "https://app.scrapingbee.com/api/v1",
                params={
                    "api_key": scrapingbee_key,
                    "url": full_url,
                    "render_js": "false",
                    "return_page_source": "true",
                },
                timeout=30,
            )
            return resp

        return requests.get(
            url,
            params=params,
            timeout=10,
            headers={"User-Agent": "NewsBlur/1.0 (feed discovery)"},
        )

    def _parse_feedly_result(self, result):
        """Parse a single Feedly search result into a feed dict."""
        feed_id = result.get("feedId", "")
        if not feed_id.startswith("feed/"):
            return None

        feed_url = feed_id[5:]
        if not feed_url.startswith(("http://", "https://")):
            return None

        feed_url_lower = feed_url.lower()
        if any(domain in feed_url_lower for domain in SKIP_DOMAINS):
            return None

        subscribers = result.get("subscribers", 0)
        velocity = result.get("velocity", 0)
        if velocity == 0 and subscribers < 5:
            return None

        title = result.get("title", "")
        description = result.get("description", "")
        if description and len(description) > 200:
            description = description[:197] + "..."

        return {
            "feed_url": feed_url,
            "title": title or "",
            "description": description or "",
            "subscriber_count": subscribers,
            "velocity": velocity,
        }

    def _search_feedly(self, search_queries, existing_urls):
        """Search Feedly for feeds using generated search queries."""
        cache = self._load_cache() if self.resume else {"feeds": {}, "completed_queries": []}
        feeds = cache["feeds"]
        completed = set(cache["completed_queries"])

        if self.resume and completed:
            self.stdout.write(
                f"Resuming: {len(completed)} queries completed, {len(feeds)} feeds cached"
            )

        total_queries = len(search_queries)
        query_num = 0
        consecutive_429s = 0

        self.stdout.write(f"\nSearching Feedly with {total_queries} queries...")

        for query, category, subcategory in search_queries:
            query_num += 1

            cache_key = f"{category}|{subcategory}|{query}"
            if cache_key in completed:
                continue

            if self.verbose:
                self.stdout.write(
                    f"  [{query_num}/{total_queries}] {category} > {subcategory}: \"{query}\""
                )
            elif query_num % 20 == 0 or query_num == 1:
                self.stdout.write(
                    f"  [{query_num}/{total_queries}] {len(feeds)} feeds so far..."
                )
            self.stdout.flush()

            try:
                resp = self._feedly_get(
                    FEEDLY_SEARCH_URL, {"query": query, "count": self.feedly_count}
                )
                if resp is None:
                    break

                if resp.status_code == 429 and not self.use_proxy:
                    consecutive_429s += 1
                    wait_time = FEEDLY_RATE_LIMIT_WAIT * consecutive_429s
                    self.stdout.write(
                        self.style.WARNING(
                            f"  Rate limited ({consecutive_429s}x), waiting {wait_time}s..."
                        )
                    )
                    cache["feeds"] = feeds
                    cache["completed_queries"] = list(completed)
                    self._save_cache(cache)

                    if consecutive_429s >= 3:
                        self.stdout.write(
                            self.style.WARNING(
                                f"  Too many rate limits. Saved {len(feeds)} feeds. "
                                f"Use --resume to continue later."
                            )
                        )
                        return self._feeds_dict_to_list(feeds, existing_urls)

                    time.sleep(wait_time)
                    resp = self._feedly_get(
                        FEEDLY_SEARCH_URL, {"query": query, "count": self.feedly_count}
                    )
                    if resp is None or resp.status_code == 429:
                        cache["feeds"] = feeds
                        cache["completed_queries"] = list(completed)
                        self._save_cache(cache)
                        return self._feeds_dict_to_list(feeds, existing_urls)

                if resp.status_code == 200:
                    consecutive_429s = 0
                    try:
                        data = resp.json()
                    except ValueError:
                        try:
                            data = json.loads(resp.text)
                        except ValueError:
                            completed.add(cache_key)
                            time.sleep(FEEDLY_DELAY)
                            continue

                    results = data.get("results", [])
                    new_in_batch = 0

                    for result in results:
                        feed_data = self._parse_feedly_result(result)
                        if feed_data:
                            feed_url = feed_data["feed_url"]
                            if feed_url not in existing_urls and feed_url not in feeds:
                                feed_data["target_category"] = category
                                feed_data["target_subcategory"] = subcategory
                                feeds[feed_url] = feed_data
                                new_in_batch += 1
                            elif feed_url in feeds:
                                if feed_data["subscriber_count"] > feeds[feed_url].get(
                                    "subscriber_count", 0
                                ):
                                    feeds[feed_url]["subscriber_count"] = feed_data[
                                        "subscriber_count"
                                    ]

                    completed.add(cache_key)

                    if self.verbose and new_in_batch > 0:
                        self.stdout.write(
                            f"    +{new_in_batch} new feeds ({len(results)} results)"
                        )
                else:
                    if self.verbose:
                        self.stdout.write(self.style.WARNING(f"    HTTP {resp.status_code}"))
                    completed.add(cache_key)

            except requests.RequestException as e:
                if self.verbose:
                    self.stdout.write(self.style.WARNING(f"    Request error: {e}"))

            time.sleep(FEEDLY_DELAY)

            if query_num % 50 == 0:
                cache["feeds"] = feeds
                cache["completed_queries"] = list(completed)
                self._save_cache(cache)

        cache["feeds"] = feeds
        cache["completed_queries"] = list(completed)
        self._save_cache(cache)

        return self._feeds_dict_to_list(feeds, existing_urls)

    def _feeds_dict_to_list(self, feeds_dict, existing_urls):
        """Convert feeds dict to list, filtering out already-existing URLs."""
        return [feed for url, feed in feeds_dict.items() if url not in existing_urls]

    def _fetch_github_opmls(self, existing_urls):
        """Fetch and parse GitHub OPML collections for feed discovery."""
        self.stdout.write("\nFetching GitHub OPML sources...")
        feeds = []

        for url, description in GITHUB_OPML_SOURCES:
            if self.verbose:
                self.stdout.write(f"  Fetching: {description}")

            try:
                resp = requests.get(url, timeout=15)
                if resp.status_code != 200:
                    if self.verbose:
                        self.stdout.write(self.style.WARNING(f"    HTTP {resp.status_code}"))
                    continue

                parsed = self._parse_opml(resp.text)
                new_count = 0
                for feed in parsed:
                    feed_url = feed["feed_url"]
                    if feed_url in existing_urls:
                        continue

                    feed_url_lower = feed_url.lower()
                    if any(domain in feed_url_lower for domain in SKIP_DOMAINS):
                        continue

                    feeds.append(
                        {
                            "feed_url": feed_url,
                            "title": feed.get("title", ""),
                            "description": feed.get("description", ""),
                            "subscriber_count": 0,
                            "velocity": 0,
                            "target_category": "",
                            "target_subcategory": "",
                        }
                    )
                    existing_urls.add(feed_url)
                    new_count += 1

                if self.verbose and new_count > 0:
                    self.stdout.write(f"    +{new_count} new feeds ({len(parsed)} total)")

            except requests.RequestException as e:
                if self.verbose:
                    self.stdout.write(self.style.WARNING(f"    Request error: {e}"))

            time.sleep(0.3)

        self.stdout.write(f"  GitHub OPMLs: {len(feeds)} new feeds from {len(GITHUB_OPML_SOURCES)} sources")
        return feeds

    def _parse_opml(self, xml_text):
        """Parse OPML XML and extract feed URLs."""
        feeds = []
        try:
            root = ET.fromstring(xml_text)
        except ET.ParseError:
            return feeds

        for outline in root.iter("outline"):
            xml_url = outline.get("xmlUrl", "")
            if not xml_url:
                continue

            title = outline.get("title", "") or outline.get("text", "")
            description = outline.get("description", "")

            feeds.append(
                {
                    "feed_url": xml_url,
                    "title": title,
                    "description": description or "",
                }
            )

        return feeds

    def _discover_via_llm_suggestions(self, gaps, existing_urls, all_feeds=None):
        """Ask Claude to suggest real RSS feed URLs, then verify each one via HTTP.

        For each underpopulated subcategory, Claude suggests feeds it knows from training data.
        Each suggestion is verified by fetching the URL and checking for valid RSS/Atom content.
        Only verified feeds are returned.
        """
        api_key = getattr(settings, "ANTHROPIC_API_KEY", None)
        if not api_key:
            self.stderr.write(self.style.WARNING("No ANTHROPIC_API_KEY for LLM suggestions"))
            return []

        client = anthropic.Anthropic(api_key=api_key)
        verified_feeds = []

        # Build existing feed titles per subcategory so Claude doesn't suggest duplicates
        existing_by_subcat = defaultdict(list)
        if all_feeds:
            for f in all_feeds:
                if f.get("feed_type") == self.feed_type:
                    key = (f.get("category", ""), f.get("subcategory", ""))
                    existing_by_subcat[key].append(f.get("title", ""))

        # Build batch of subcategories grouped by category
        cat_batches = defaultdict(list)
        for cat, subs in gaps.items():
            for sub, cnt in subs:
                needed = self.min_feeds - cnt
                if needed > 0:
                    cat_batches[cat].append({"subcategory": sub, "needed": needed})

        total_cats = len(cat_batches)
        cat_num = 0

        self.stdout.write(f"\nSuggesting feeds via LLM for {total_cats} categories...")

        for cat, items in sorted(cat_batches.items()):
            cat_num += 1

            # Build subcategory info including existing feeds
            subcat_lines = []
            for item in items:
                existing_titles = existing_by_subcat.get((cat, item["subcategory"]), [])
                line = f"- {item['subcategory']} (need {item['needed']} more feeds)"
                if existing_titles:
                    titles_str = ", ".join(existing_titles[:5])
                    line += f"\n  Already have: {titles_str}"
                subcat_lines.append(line)
            subcats_str = "\n".join(subcat_lines)

            self.stdout.write(f"  [{cat_num}/{total_cats}] {cat} ({len(items)} subcategories)...")

            prompt = f"""Suggest real RSS/Atom feed URLs for blogs and sites in the "{cat}" category.

For each subcategory below, suggest 15-20 REAL feeds that are DIFFERENT from the ones already listed.
Use only feeds you are confident actually exist. Include a mix of:
- Major publications and established sites
- Independent blogs with dedicated RSS feeds
- Niche community sites
- Government/NGO/institutional sites (where relevant)

Common feed URL patterns:
- WordPress: example.com/feed/ or example.com/feed/rss/
- Blogger: example.blogspot.com/feeds/posts/default
- Ghost: example.com/rss/
- Hugo/Jekyll: example.com/index.xml or example.com/feed.xml
- Custom: example.com/rss.xml or example.com/atom.xml

Subcategories:
{subcats_str}

IMPORTANT: Suggest feeds DIFFERENT from the ones already listed above.
For each feed provide: the exact feed URL, site title, and a one-line description (under 80 chars).
Do NOT make up URLs. Only suggest feeds from real sites you know exist."""

            tool_definition = {
                "name": "save_suggested_feeds",
                "description": f"Save suggested feeds for {cat}",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "subcategories": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "subcategory": {"type": "string"},
                                    "feeds": {
                                        "type": "array",
                                        "items": {
                                            "type": "object",
                                            "properties": {
                                                "feed_url": {"type": "string"},
                                                "title": {"type": "string"},
                                                "description": {"type": "string"},
                                            },
                                            "required": ["feed_url", "title"],
                                        },
                                    },
                                },
                                "required": ["subcategory", "feeds"],
                            },
                        }
                    },
                    "required": ["subcategories"],
                },
            }

            try:
                response = client.messages.create(
                    model=CLAUDE_MODEL,
                    max_tokens=16384,
                    tools=[tool_definition],
                    tool_choice={"type": "tool", "name": "save_suggested_feeds"},
                    messages=[{"role": "user", "content": prompt}],
                )

                LLMCostTracker.record_usage(
                    provider="anthropic",
                    model=CLAUDE_MODEL,
                    feature="backfill_llm_suggest",
                    input_tokens=response.usage.input_tokens,
                    output_tokens=response.usage.output_tokens,
                )

                suggestions = []
                for block in response.content:
                    if block.type == "tool_use" and block.name == "save_suggested_feeds":
                        for subcat_data in block.input.get("subcategories", []):
                            sub_name = subcat_data["subcategory"]
                            for feed in subcat_data.get("feeds", []):
                                feed_url = feed.get("feed_url", "").strip()
                                if not feed_url or feed_url in existing_urls:
                                    continue
                                if any(d in feed_url.lower() for d in SKIP_DOMAINS):
                                    continue
                                suggestions.append(
                                    {
                                        "feed_url": feed_url,
                                        "title": feed.get("title", ""),
                                        "description": feed.get("description", ""),
                                        "target_category": cat,
                                        "target_subcategory": sub_name,
                                    }
                                )

                self.stdout.write(f"    {len(suggestions)} suggestions, verifying...")

                # Verify each suggested URL
                cat_verified = 0
                for feed in suggestions:
                    if self._verify_feed_url(feed["feed_url"]):
                        feed["subscriber_count"] = 0
                        feed["velocity"] = 0
                        verified_feeds.append(feed)
                        existing_urls.add(feed["feed_url"])
                        cat_verified += 1

                self.stdout.write(
                    f"    {cat_verified}/{len(suggestions)} verified"
                    + (self.style.SUCCESS(" OK") if cat_verified > 0 else "")
                )

            except anthropic.APIError as e:
                self.stderr.write(self.style.ERROR(f"    Claude API error for {cat}: {e}"))

        return verified_feeds

    def _verify_feed_url(self, feed_url):
        """Verify a feed URL returns valid RSS/Atom content via HTTP."""
        try:
            resp = requests.get(
                feed_url,
                timeout=8,
                headers={
                    "User-Agent": "NewsBlur/1.0 (feed verification)",
                    "Accept": "application/rss+xml, application/atom+xml, application/xml, text/xml",
                },
                allow_redirects=True,
            )
            if resp.status_code != 200:
                return False

            content = resp.text[:2000].lower()
            # Check for RSS or Atom markers
            return any(
                marker in content
                for marker in ["<rss", "<feed", "<rdf:rdf", "<?xml", "<channel>", "<entry>"]
            )
        except (requests.RequestException, Exception):
            return False

    def _categorize_and_assign(self, discovered_feeds, gaps):
        """Use Claude to categorize discovered feeds into target subcategories."""
        api_key = getattr(settings, "ANTHROPIC_API_KEY", None)
        if not api_key:
            self.stderr.write(
                self.style.ERROR(
                    "ANTHROPIC_API_KEY not configured, assigning by search target"
                )
            )
            return self._assign_by_target(discovered_feeds, gaps)

        client = anthropic.Anthropic(api_key=api_key)

        valid_targets = {}
        for cat, subs in gaps.items():
            for sub, cnt in subs:
                valid_targets[(cat, sub)] = self.min_feeds - cnt

        taxonomy_lines = []
        for cat in sorted(gaps.keys()):
            subs = [sub for sub, _ in gaps[cat]]
            taxonomy_lines.append(f"- {cat}: {', '.join(subs)}")
        taxonomy_str = "\n".join(taxonomy_lines)

        categorized = []

        for i in range(0, len(discovered_feeds), CATEGORIZE_BATCH_SIZE):
            batch = discovered_feeds[i : i + CATEGORIZE_BATCH_SIZE]
            batch_num = i // CATEGORIZE_BATCH_SIZE + 1
            total_batches = (
                len(discovered_feeds) + CATEGORIZE_BATCH_SIZE - 1
            ) // CATEGORIZE_BATCH_SIZE
            self.stdout.write(
                f"  Categorizing batch {batch_num}/{total_batches} ({len(batch)} feeds)..."
            )

            results = self._categorize_batch(client, batch, taxonomy_str)
            if results:
                for item in results:
                    cat = item.get("category", "").lower()
                    sub = item.get("subcategory", "")
                    feed_url = item.get("feed_url", "")

                    if not feed_url or not cat or not sub:
                        continue

                    if (cat, sub) not in valid_targets:
                        if self.verbose:
                            self.stdout.write(
                                f"    Skipping {feed_url}: {cat} > {sub} not a target"
                            )
                        continue

                    original = next(
                        (f for f in discovered_feeds if f["feed_url"] == feed_url), None
                    )
                    if not original:
                        continue

                    categorized.append(
                        {
                            "feed_type": self.feed_type,
                            "category": cat,
                            "subcategory": sub,
                            "title": original.get("title", ""),
                            "description": original.get("description", ""),
                            "feed_url": feed_url,
                            "subscriber_count": original.get("subscriber_count", 0),
                            "platform": "",
                            "thumbnail_url": "",
                        }
                    )

        return categorized

    def _assign_by_target(self, discovered_feeds, gaps):
        """Fallback: assign feeds to their search target subcategory without Claude."""
        valid_targets = set()
        for cat, subs in gaps.items():
            for sub, _ in subs:
                valid_targets.add((cat, sub))

        assigned = []
        for feed in discovered_feeds:
            cat = feed.get("target_category", "")
            sub = feed.get("target_subcategory", "")
            if (cat, sub) in valid_targets:
                assigned.append(
                    {
                        "feed_type": self.feed_type,
                        "category": cat,
                        "subcategory": sub,
                        "title": feed.get("title", ""),
                        "description": feed.get("description", ""),
                        "feed_url": feed["feed_url"],
                        "subscriber_count": feed.get("subscriber_count", 0),
                        "platform": "",
                        "thumbnail_url": "",
                    }
                )

        return assigned

    def _categorize_batch(self, client, feeds, taxonomy_str):
        """Categorize a batch of feeds using Claude."""
        feeds_json = json.dumps(
            [
                {
                    "feed_url": f["feed_url"],
                    "title": f.get("title", ""),
                    "description": f.get("description", ""),
                }
                for f in feeds
            ],
            indent=1,
        )

        prompt = f"""Categorize each RSS feed into the BEST matching category and subcategory from this list.
Only use categories and subcategories from this list. If a feed doesn't clearly fit any subcategory, set category and subcategory to empty strings.

Available categories and subcategories:
{taxonomy_str}

Feeds to categorize:
{feeds_json}

For each feed, return the feed_url, best category (lowercase), and best subcategory (Title Case)."""

        tool_definition = {
            "name": "save_categorized_feeds",
            "description": "Save the categorized feeds",
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
                feature="backfill_underpopulated_feeds",
                input_tokens=response.usage.input_tokens,
                output_tokens=response.usage.output_tokens,
            )

            if self.verbose:
                self.stdout.write(
                    f"    Tokens: {response.usage.input_tokens} in, "
                    f"{response.usage.output_tokens} out"
                )

            for block in response.content:
                if block.type == "tool_use" and block.name == "save_categorized_feeds":
                    return block.input.get("feeds", [])

        except anthropic.APIError as e:
            self.stderr.write(self.style.ERROR(f"  Claude API error: {e}"))

        return None

    def _print_post_merge_summary(self, all_feeds):
        """Print summary showing remaining gaps after merge."""
        type_feeds = [
            f for f in all_feeds if f.get("feed_type", "rss") == self.feed_type
        ]
        subcat_counts = Counter()
        for feed in type_feeds:
            sub = feed.get("subcategory", "")
            if sub:
                subcat_counts[(feed["category"], sub)] += 1

        still_under = [
            (cat, sub, cnt)
            for (cat, sub), cnt in subcat_counts.items()
            if cnt < self.min_feeds
        ]
        still_under.sort()

        total_subs = len(subcat_counts)
        ok_count = total_subs - len(still_under)

        self.stdout.write(f"\n--- Post-Merge Summary ---")
        self.stdout.write(f"Total subcategories: {total_subs}")
        self.stdout.write(f"Meeting minimum ({self.min_feeds}+): {ok_count}")
        self.stdout.write(f"Still under minimum: {len(still_under)}")

        if still_under:
            self.stdout.write("\nRemaining gaps:")
            for cat, sub, cnt in still_under:
                self.stdout.write(
                    f"  {cat} > {sub}: {cnt} (needs {self.min_feeds - cnt} more)"
                )
