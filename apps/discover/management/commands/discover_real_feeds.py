"""
Management command to discover real RSS feeds from Feedly Search API and GitHub OPML collections.
Replaces LLM-hallucinated feeds with verified, real feed URLs and subscriber counts.

Data Sources:
1. Feedly Search API (unauthenticated) - search by category/subcategory keywords
2. GitHub OPML collections (plenaryapp/awesome-rss-feeds, kilimchoi/engineering-blogs)

Usage:
    python manage.py discover_real_feeds
    python manage.py discover_real_feeds --skip-feedly
    python manage.py discover_real_feeds --skip-github
    python manage.py discover_real_feeds --dry-run
    python manage.py discover_real_feeds --resume  # resume from cache after rate limiting
"""

import json
import os
import sys
import time
import xml.etree.ElementTree as ET

import anthropic
import requests
from django.conf import settings
from django.core.management.base import BaseCommand

from utils.llm_costs import LLMCostTracker

FIXTURE_DIR = os.path.join(os.path.dirname(__file__), "../../fixtures")
FIXTURE_PATH = os.path.join(FIXTURE_DIR, "popular_feeds.json")
CACHE_PATH = os.path.join(FIXTURE_DIR, "feedly_cache.json")

# GitHub OPML sources: (raw URL, description)
_AWESOME_RSS_BASE = "https://raw.githubusercontent.com/plenaryapp/awesome-rss-feeds/master/recommended/with_category"
GITHUB_OPML_SOURCES = [
    (f"{_AWESOME_RSS_BASE}/Tech.opml", "awesome-rss Tech"),
    (f"{_AWESOME_RSS_BASE}/Programming.opml", "awesome-rss Programming"),
    (f"{_AWESOME_RSS_BASE}/Web%20Development.opml", "awesome-rss Web Development"),
    (f"{_AWESOME_RSS_BASE}/Android%20Development.opml", "awesome-rss Android Dev"),
    (f"{_AWESOME_RSS_BASE}/iOS%20Development.opml", "awesome-rss iOS Dev"),
    (f"{_AWESOME_RSS_BASE}/Science.opml", "awesome-rss Science"),
    (f"{_AWESOME_RSS_BASE}/Space.opml", "awesome-rss Space"),
    (f"{_AWESOME_RSS_BASE}/News.opml", "awesome-rss News"),
    (f"{_AWESOME_RSS_BASE}/Business%20%26%20Economy.opml", "awesome-rss Business"),
    (f"{_AWESOME_RSS_BASE}/Startups.opml", "awesome-rss Startups"),
    (f"{_AWESOME_RSS_BASE}/Personal%20finance.opml", "awesome-rss Personal Finance"),
    (f"{_AWESOME_RSS_BASE}/Gaming.opml", "awesome-rss Gaming"),
    (f"{_AWESOME_RSS_BASE}/Sports.opml", "awesome-rss Sports"),
    (f"{_AWESOME_RSS_BASE}/Football.opml", "awesome-rss Football"),
    (f"{_AWESOME_RSS_BASE}/Cricket.opml", "awesome-rss Cricket"),
    (f"{_AWESOME_RSS_BASE}/Tennis.opml", "awesome-rss Tennis"),
    (f"{_AWESOME_RSS_BASE}/Music.opml", "awesome-rss Music"),
    (f"{_AWESOME_RSS_BASE}/Movies.opml", "awesome-rss Movies"),
    (f"{_AWESOME_RSS_BASE}/Television.opml", "awesome-rss Television"),
    (f"{_AWESOME_RSS_BASE}/Food.opml", "awesome-rss Food"),
    (f"{_AWESOME_RSS_BASE}/Travel.opml", "awesome-rss Travel"),
    (f"{_AWESOME_RSS_BASE}/Photography.opml", "awesome-rss Photography"),
    (f"{_AWESOME_RSS_BASE}/Fashion.opml", "awesome-rss Fashion"),
    (f"{_AWESOME_RSS_BASE}/Beauty.opml", "awesome-rss Beauty"),
    (f"{_AWESOME_RSS_BASE}/Books.opml", "awesome-rss Books"),
    (f"{_AWESOME_RSS_BASE}/History.opml", "awesome-rss History"),
    (f"{_AWESOME_RSS_BASE}/DIY.opml", "awesome-rss DIY"),
    (f"{_AWESOME_RSS_BASE}/Cars.opml", "awesome-rss Cars"),
    (f"{_AWESOME_RSS_BASE}/Architecture.opml", "awesome-rss Architecture"),
    (f"{_AWESOME_RSS_BASE}/UI%20-%20UX.opml", "awesome-rss UI/UX"),
    (f"{_AWESOME_RSS_BASE}/Android.opml", "awesome-rss Android"),
    (f"{_AWESOME_RSS_BASE}/Apple.opml", "awesome-rss Apple"),
    (f"{_AWESOME_RSS_BASE}/Funny.opml", "awesome-rss Funny"),
    (f"{_AWESOME_RSS_BASE}/Interior%20design.opml", "awesome-rss Interior Design"),
    (
        "https://raw.githubusercontent.com/kilimchoi/engineering-blogs/master/engineering_blogs.opml",
        "engineering-blogs",
    ),
]

FEEDLY_SEARCH_URL = "https://cloud.feedly.com/v3/search/feeds"
FEEDLY_DELAY = 2.0  # seconds between API calls
FEEDLY_RATE_LIMIT_WAIT = 60  # seconds to wait on 429

CLAUDE_MODEL = "claude-haiku-4-5"
CATEGORIZE_BATCH_SIZE = 100  # feeds per Claude categorization call

# URL domains to skip (these have their own feed types in PopularFeed)
SKIP_DOMAINS = [
    "youtube.com",
    "reddit.com",
    "substack.com",
    "medium.com/feed",
]


class Command(BaseCommand):
    help = "Discover real RSS feeds from Feedly and GitHub OPML collections"

    def add_arguments(self, parser):
        parser.add_argument("--dry-run", action="store_true", help="Show what would be done without writing")
        parser.add_argument("--skip-feedly", action="store_true", help="Skip Feedly search API")
        parser.add_argument("--skip-github", action="store_true", help="Skip GitHub OPML sources")
        parser.add_argument(
            "--skip-categorize",
            action="store_true",
            help="Skip Claude categorization (use raw Feedly topics)",
        )
        parser.add_argument(
            "--feedly-count", type=int, default=40, help="Results per Feedly search (max 100, default 40)"
        )
        parser.add_argument("--verbose", action="store_true", help="Show detailed output")
        parser.add_argument(
            "--max-categories",
            type=int,
            default=0,
            help="Limit number of categories to search (0=all, for testing)",
        )
        parser.add_argument(
            "--resume", action="store_true", help="Resume from cached Feedly results (skip completed queries)"
        )
        parser.add_argument(
            "--use-proxy",
            action="store_true",
            help="Use ScrapingBee proxy for Feedly requests (avoids rate limiting)",
        )

    def handle(self, *args, **options):
        self.verbose = options["verbose"]
        self.dry_run = options["dry_run"]
        self.use_proxy = options["use_proxy"]

        # Phase 1: Load existing taxonomy from fixture
        taxonomy = self._load_taxonomy()
        if not taxonomy:
            self.stderr.write(self.style.ERROR("No taxonomy found in fixture file"))
            return

        self.stdout.write(f"Loaded taxonomy: {len(taxonomy)} categories")
        self.stdout.flush()

        all_feeds = {}  # keyed by feed_url for dedup

        # Phase 2: Feedly search
        if not options["skip_feedly"]:
            feedly_feeds = self._search_feedly(
                taxonomy, options["feedly_count"], options["max_categories"], options["resume"]
            )
            self.stdout.write(f"Feedly: discovered {len(feedly_feeds)} unique feeds")
            all_feeds.update(feedly_feeds)

        # Phase 3: GitHub OPML
        if not options["skip_github"]:
            github_feeds = self._fetch_github_opmls()
            self.stdout.write(f"GitHub OPML: discovered {len(github_feeds)} unique feeds")
            # Merge: don't overwrite Feedly data (which has subscriber counts)
            for url, feed in github_feeds.items():
                if url not in all_feeds:
                    all_feeds[url] = feed

        self.stdout.write(f"\nTotal unique feeds after merge: {len(all_feeds)}")

        # Phase 4: Categorize uncategorized feeds with Claude
        if not options["skip_categorize"]:
            all_feeds = self._categorize_feeds(all_feeds, taxonomy)

        # Phase 5: Convert to fixture format and write
        feeds_list = self._to_fixture_format(all_feeds)

        if self.dry_run:
            self.stdout.write(self.style.WARNING("\nDry run - not writing fixture file"))
            self._print_summary(feeds_list)
            return

        self._write_fixture(feeds_list)
        self._print_summary(feeds_list)

    # Hardcoded taxonomy - the canonical categories and subcategories for RSS feeds.
    # This is independent of the fixture file so we always have a complete taxonomy to search with.
    TAXONOMY = {
        "technology": [
            "AI & Machine Learning", "Cloud Computing", "Cybersecurity", "Gadgets",
            "Mobile Apps", "Open Source", "Programming", "Reviews", "Startups", "Web Development",
        ],
        "science": [
            "Astronomy", "Biology", "Chemistry", "Environmental Science", "Innovation",
            "Medical Science", "Neuroscience", "Physics", "Quantum Science", "Research & Discoveries",
        ],
        "gaming": [
            "Board Games", "Console Gaming", "Esports", "Game Design", "Game Reviews",
            "Gaming Culture", "Gaming News", "Indie Games", "Mobile Gaming", "PC Gaming",
        ],
        "education": [
            "Academic Research", "Classroom Innovation", "Distance Learning", "Early Education",
            "EdTech", "Higher Education", "K-12", "Language Learning", "STEM", "Teaching Resources",
        ],
        "entertainment": [
            "Award Shows", "Celebrity", "Fan Culture", "Film & TV", "Late Night",
            "Pop Culture", "Reality TV", "Satire", "Streaming", "Viral Content",
        ],
        "news & politics": [
            "Campaign News", "Diplomacy", "Fact-Checking", "Geopolitics", "Investigative",
            "Local News", "National News", "Opinion & Editorials", "Policy Analysis", "World News",
        ],
        "sports": [
            "Baseball", "Basketball", "Cycling", "Fantasy Sports", "Football",
            "Golf", "Hockey", "MMA & Boxing", "Soccer", "Tennis",
        ],
        "music": [
            "Album Reviews", "Classical Music", "Concert Tours", "Hip-Hop & Rap", "Indie Music",
            "Jazz & Blues", "Music Industry", "Music Production", "New Releases", "Rock & Alternative",
        ],
        "comedy & humor": [
            "Comedians", "Comedy News", "Comedy Writing", "Dark Humor", "Entertainment Humor",
            "Funny Videos", "Memes & Viral", "Satire & Parody", "Sketch Comedy", "Stand-up Comedy",
        ],
        "business": [
            "Corporate News", "Economics", "Entrepreneurship", "Industry Analysis",
            "Management & Leadership", "Marketing", "Small Business", "Startups & VC",
            "Strategy", "Supply Chain",
        ],
        "food & cooking": [
            "Baking", "Celebrity Chefs", "Comfort Food", "Cooking Techniques", "Food Science",
            "Healthy Eating", "International Cuisine", "Recipe Collections", "Restaurant Reviews",
            "Vegan & Vegetarian",
        ],
        "travel": [
            "Adventure Travel", "Budget Travel", "Cultural Tourism", "Digital Nomad",
            "Family Travel", "Hotel Reviews", "Luxury Travel", "Road Trips",
            "Solo Travel", "Travel Photography",
        ],
        "diy & crafts": [
            "Crafting", "DIY Projects", "Electronics DIY", "Home Improvement",
            "Jewelry Making", "Knitting & Crochet", "Painting", "Sewing",
            "Upcycling", "Woodworking",
        ],
        "photography": [
            "Camera Gear", "Editing & Post-Processing", "Film Photography", "Landscape Photography",
            "Nature Photography", "Photo Tutorials", "Photography News", "Portrait Photography",
            "Street Photography", "Wildlife Photography",
        ],
        "automotive": [
            "Auto Maintenance", "Automotive Culture", "Automotive News", "Automotive Technology",
            "Car Reviews", "Classic Cars", "Electric Vehicles", "Motorcycles",
            "New Releases", "Performance & Tuning",
        ],
        "finance": [
            "Banking & Fintech", "Budgeting", "Credit & Debt", "Financial Markets",
            "Financial Planning", "Insurance", "Investing", "Personal Finance",
            "Retirement Planning", "Taxes",
        ],
        "parenting": [
            "Activities & Crafts", "Baby & Toddler", "Co-Parenting", "Family Health",
            "Homeschooling", "Parenting Advice", "Pregnancy", "School-Age Kids",
            "Special Needs", "Teen Parenting",
        ],
        "design": [
            "Brand Identity", "Design Inspiration", "Design Tools", "Graphic Design",
            "Industrial Design", "Interior Design", "Motion Graphics", "Typography",
            "UI/UX Design", "Web Design",
        ],
        "environment & sustainability": [
            "Clean Energy", "Climate Change", "Conservation", "Eco-Friendly Living",
            "Environmental Policy", "Green Technology", "Oceans & Water", "Pollution",
            "Sustainability News", "Wildlife",
        ],
        "health & fitness": [
            "Diet & Nutrition", "Exercise & Workouts", "Health News", "Medical Research",
            "Men's Health", "Mental Health", "Mindfulness", "Running & Endurance",
            "Weight Training", "Women's Health",
        ],
        "lifestyle": [
            "City Living", "Conscious Living", "Home Organization", "Luxury Lifestyle",
            "Minimalism", "Modern Etiquette", "Personal Development", "Self-Help",
            "Simple Living", "Urban Living",
        ],
        "pets & animals": [
            "Animal Welfare", "Birds", "Cat Care", "Dog Training", "Exotic Pets",
            "Fish & Aquariums", "Pet Adoption", "Pet Health", "Pet News", "Wildlife",
        ],
        "arts & culture": [
            "Art Criticism", "Art History", "Cultural Events", "Cultural News", "Dance",
            "Literary Arts", "Museums & Galleries", "Performing Arts", "Theater & Drama",
            "Visual Arts",
        ],
        "home & garden": [
            "Container Gardening", "Flower Gardening", "Garden Design", "Home Decor",
            "Home Improvement", "Houseplants", "Landscape Design", "Organic Gardening",
            "Smart Home", "Sustainable Living",
        ],
        "history": [
            "Ancient History", "Archaeology", "Art & Cultural History", "Historical Figures",
            "Medieval History", "Military History", "Modern History", "Public History",
            "Social History", "World History",
        ],
        "psychology & mental health": [
            "Anxiety & Depression", "Behavioral Psychology", "Brain Science",
            "Cognitive Psychology", "Counseling", "Mental Health Advocacy", "Mindfulness",
            "Positive Psychology", "Relationships", "Self-Improvement",
        ],
        "books & reading": [
            "Audiobooks", "Author News", "Book Culture", "Book Recommendations",
            "Book Reviews", "Fiction", "Literature", "New Releases", "Non-Fiction",
            "Publishing Industry",
        ],
        "anime & manga": [
            "Anime Culture", "Anime News", "Anime Reviews", "Anime Streaming",
            "Character Analysis", "Cosplay", "Fan Art", "Manga Adaptations",
            "Manga Series", "New Releases",
        ],
        "architecture": [
            "Architectural Styles", "Architecture News", "Architecture Trends", "Building Design",
            "Commercial Design", "Famous Buildings", "Historic Architecture", "Residential Design",
            "Sustainable Architecture", "Urban Planning",
        ],
        "law & legal": [
            "Business Law", "Civil Rights", "Constitutional Law", "Corporate Law",
            "Criminal Law", "Environmental Law", "Intellectual Property", "International Law",
            "Legal Analysis", "Supreme Court",
        ],
        "real estate": [
            "Commercial Real Estate", "Home Buying", "Home Staging", "Housing Market",
            "Investment Properties", "Luxury Real Estate", "Market Analysis",
            "Mortgage & Finance", "Property Management", "Rental Market",
        ],
        "space & astronomy": [
            "Astrophysics", "Cosmology", "Dark Matter & Energy", "Exoplanets",
            "NASA & Space Agencies", "Rocket Technology", "Satellite Technology",
            "Space Exploration", "Space Industry", "Telescopes & Observatories",
        ],
        "philosophy": [
            "Aesthetics", "Applied Ethics", "Eastern Philosophy", "Epistemology",
            "Ethics", "Existentialism", "Logic", "Metaphysics", "Philosophy of Mind",
            "Political Philosophy",
        ],
        "religion & spirituality": [
            "Buddhism", "Christianity", "Comparative Religion", "Hinduism",
            "Interfaith Dialogue", "Islam", "Judaism", "Meditation & Mindfulness",
            "Spiritual Growth", "Theology",
        ],
        "fashion & beauty": [
            "Beauty Tips", "Designer Fashion", "Fashion News", "Fashion Trends",
            "Hair Care", "Makeup", "Men's Fashion", "Skincare", "Street Style",
            "Sustainable Fashion",
        ],
        "military & defense": [
            "Arms & Equipment", "Cybersecurity & Warfare", "Defense Industry",
            "Defense Policy", "Geopolitical Analysis", "Intelligence Community",
            "Military History", "Military Technology", "Naval Operations",
            "Veterans & Service",
        ],
        "economics": [
            "Behavioral Economics", "Development Economics", "Economic Policy",
            "Economic Research", "Global Economics", "Labor Markets",
            "Macroeconomics", "Microeconomics", "Trade & Tariffs",
            "Wealth & Inequality",
        ],
        "cryptocurrency & web3": [
            "Bitcoin & Ethereum", "Blockchain Technology", "Crypto News",
            "Crypto Regulation", "Crypto Security", "Crypto Trading",
            "DeFi & Finance", "NFTs & Digital Assets", "Stablecoins",
            "Web3 Development",
        ],
        "data science & analytics": [
            "Big Data", "Business Intelligence", "Data Analysis", "Data Privacy",
            "Data Science Research", "Data Tools", "Data Visualization",
            "Machine Learning", "NLP", "Statistics",
        ],
        "internet culture & social media": [
            "Content Creation", "Digital Culture", "Influencer Culture",
            "Internet History", "Internet Privacy", "Meme Culture",
            "Online Communities", "Platform News", "Social Media Strategy",
            "Viral Trends",
        ],
        "entrepreneurship & startups": [
            "Angel Investing", "Bootstrapping", "Founder Stories", "Fundraising",
            "Growth Hacking", "Incubators & Accelerators", "Product Management",
            "SaaS", "Startup Culture", "Venture Capital",
        ],
        "weather & climate": [
            "Climate Data", "Climate Policy", "Climate Science", "Extreme Weather",
            "Forecasting", "Meteorology", "Oceanography", "Seasonal Weather",
            "Severe Storms", "Weather Technology",
        ],
        "career & job market": [
            "Career Advice", "Career Change", "Career Development", "Industry Trends",
            "Job Market News", "Job Search Tips", "Remote Work", "Resume & Interviews",
            "Salary & Compensation", "Skills & Training",
        ],
        "wellness & self-care": [
            "Alternative Medicine", "Aromatherapy", "Body Positivity", "Holistic Health",
            "Meditation", "Self-Care Routines", "Sleep Health", "Spa & Relaxation",
            "Stress Management", "Yoga & Pilates",
        ],
        "productivity & organization": [
            "Automation", "Decision Making", "Focus & Concentration", "Goal Setting",
            "Habit Building", "Note-Taking", "Planning Systems", "Productivity Apps",
            "Task Management", "Time Management",
        ],
        "hobbies & collections": [
            "Antiques & Vintage", "Board Games", "Card Collecting", "Coin Collecting",
            "Comic Books", "Genealogy", "Model Building", "Puzzles",
            "Stamps", "Vinyl Records",
        ],
        "relationships & dating": [
            "Communication Skills", "Dating Advice", "Divorce & Separation",
            "Friendship", "Long-Distance Relationships", "Marriage",
            "Online Dating", "Relationship Psychology", "Self-Love",
            "Singles & Dating",
        ],
    }

    def _load_taxonomy(self):
        """Return the canonical taxonomy for feed discovery."""
        return self.TAXONOMY

    def _build_search_queries(self, taxonomy):
        """Build Feedly search queries from taxonomy.
        Feedly search works best with short queries (1-2 words).
        """
        queries = []  # list of (query_string, category, subcategory)
        seen_queries = set()

        for category, subcategories in taxonomy.items():
            # Search for the category name
            if category not in seen_queries:
                queries.append((category, category, ""))
                seen_queries.add(category)

            for subcategory in subcategories:
                # Use subcategory as query
                if subcategory not in seen_queries:
                    queries.append((subcategory, category, subcategory))
                    seen_queries.add(subcategory)

        return queries

    def _load_cache(self):
        """Load cached Feedly results."""
        cache_path = os.path.normpath(CACHE_PATH)
        if os.path.exists(cache_path):
            with open(cache_path, "r") as f:
                return json.load(f)
        return {"feeds": {}, "completed_queries": []}

    def _save_cache(self, cache):
        """Save Feedly results to cache."""
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

            # Build the full Feedly URL with params
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

    def _search_feedly(self, taxonomy, count, max_categories, resume):
        """Search Feedly for feeds using taxonomy keywords."""
        categories_dict = dict(taxonomy)
        if max_categories > 0:
            categories_dict = dict(list(taxonomy.items())[:max_categories])

        queries = self._build_search_queries(categories_dict)
        total_searches = len(queries)

        # Load cache for resume support
        cache = self._load_cache() if resume else {"feeds": {}, "completed_queries": []}
        feeds = cache["feeds"]
        completed = set(cache["completed_queries"])

        if resume and completed:
            self.stdout.write(f"  Resuming: {len(completed)} queries already completed, {len(feeds)} feeds cached")

        search_num = 0
        consecutive_429s = 0

        for query, category, subcategory in queries:
            search_num += 1

            if query in completed:
                continue

            if self.verbose:
                self.stdout.write(f"  [{search_num}/{total_searches}] Searching: {query}")
            elif search_num % 10 == 0 or search_num == 1:
                self.stdout.write(f"  [{search_num}/{total_searches}] {len(feeds)} feeds so far...")

            try:
                resp = self._feedly_get(FEEDLY_SEARCH_URL, {"query": query, "count": count})
                if resp is None:
                    break

                if resp.status_code == 429 and not self.use_proxy:
                    consecutive_429s += 1
                    wait_time = FEEDLY_RATE_LIMIT_WAIT * consecutive_429s
                    self.stdout.write(
                        self.style.WARNING(
                            f"  Rate limited ({consecutive_429s}x), waiting {wait_time}s... "
                            f"({len(feeds)} feeds cached)"
                        )
                    )
                    cache["feeds"] = feeds
                    cache["completed_queries"] = list(completed)
                    self._save_cache(cache)

                    if consecutive_429s >= 3:
                        self.stdout.write(
                            self.style.WARNING(
                                f"  Too many rate limits. Saved {len(feeds)} feeds to cache. "
                                f"Run with --resume --use-proxy to continue via ScrapingBee."
                            )
                        )
                        return feeds

                    time.sleep(wait_time)
                    resp = self._feedly_get(FEEDLY_SEARCH_URL, {"query": query, "count": count})
                    if resp is None or resp.status_code == 429:
                        self.stdout.write(
                            self.style.WARNING(
                                f"  Still rate limited. Saved {len(feeds)} feeds. "
                                f"Use --resume --use-proxy to continue."
                            )
                        )
                        cache["feeds"] = feeds
                        cache["completed_queries"] = list(completed)
                        self._save_cache(cache)
                        return feeds

                if resp.status_code == 200:
                    consecutive_429s = 0
                    # ScrapingBee returns raw HTML/text, need to parse JSON from body
                    try:
                        data = resp.json()
                    except ValueError:
                        # ScrapingBee may return the JSON as text in page source
                        import json as json_mod

                        try:
                            data = json_mod.loads(resp.text)
                        except ValueError:
                            if self.verbose:
                                self.stdout.write(self.style.WARNING(f"    Could not parse JSON response"))
                            completed.add(query)
                            time.sleep(FEEDLY_DELAY)
                            continue

                    results = data.get("results", [])
                    new_in_batch = 0

                    for result in results:
                        feed_data = self._parse_feedly_result(result, category, subcategory)
                        if feed_data:
                            feed_url = feed_data["feed_url"]
                            if feed_url not in feeds:
                                feeds[feed_url] = feed_data
                                new_in_batch += 1
                            elif feed_data["subscriber_count"] > feeds[feed_url].get("subscriber_count", 0):
                                feeds[feed_url]["subscriber_count"] = feed_data["subscriber_count"]

                    completed.add(query)

                    if self.verbose and new_in_batch > 0:
                        self.stdout.write(f"    +{new_in_batch} new feeds ({len(results)} results)")
                else:
                    if self.verbose:
                        self.stdout.write(self.style.WARNING(f"    HTTP {resp.status_code}"))
                    completed.add(query)  # skip bad queries

            except requests.RequestException as e:
                if self.verbose:
                    self.stdout.write(self.style.WARNING(f"    Request error: {e}"))

            time.sleep(FEEDLY_DELAY)

            # Periodic cache save every 50 queries
            if search_num % 50 == 0:
                cache["feeds"] = feeds
                cache["completed_queries"] = list(completed)
                self._save_cache(cache)

        # Final cache save
        cache["feeds"] = feeds
        cache["completed_queries"] = list(completed)
        self._save_cache(cache)

        return feeds

    def _parse_feedly_result(self, result, category, subcategory):
        """Parse a single Feedly search result into a feed dict."""
        feed_id = result.get("feedId", "")
        if not feed_id.startswith("feed/"):
            return None

        feed_url = feed_id[5:]  # strip "feed/" prefix

        if not feed_url.startswith(("http://", "https://")):
            return None

        # Skip YouTube, Reddit, etc
        feed_url_lower = feed_url.lower()
        if any(domain in feed_url_lower for domain in SKIP_DOMAINS):
            return None

        subscribers = result.get("subscribers", 0)
        velocity = result.get("velocity", 0)

        # Only include feeds with some activity
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
            "feedly_category": category,
            "feedly_subcategory": subcategory,
            "source": "feedly",
        }

    def _fetch_github_opmls(self):
        """Fetch and parse OPML files from GitHub repositories."""
        feeds = {}

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
                for feed in parsed:
                    feed_url = feed["feed_url"]
                    if feed_url not in feeds:
                        feeds[feed_url] = {
                            "feed_url": feed_url,
                            "title": feed.get("title", ""),
                            "description": feed.get("description", ""),
                            "subscriber_count": 0,
                            "velocity": 0,
                            "feedly_category": "",
                            "feedly_subcategory": "",
                            "opml_category": feed.get("opml_category", ""),
                            "source": "github_opml",
                        }

                if self.verbose:
                    self.stdout.write(f"    Parsed {len(parsed)} feeds")

            except requests.RequestException as e:
                if self.verbose:
                    self.stdout.write(self.style.WARNING(f"    Request error: {e}"))

            time.sleep(0.5)

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

            if any(domain in xml_url.lower() for domain in ["youtube.com", "reddit.com"]):
                continue

            title = outline.get("title", "") or outline.get("text", "")
            description = outline.get("description", "")
            category_attr = outline.get("category", "")

            feeds.append(
                {
                    "feed_url": xml_url,
                    "title": title,
                    "description": description or "",
                    "opml_category": category_attr,
                }
            )

        return feeds

    def _categorize_feeds(self, all_feeds, taxonomy):
        """Use Claude to categorize feeds that don't have categories from Feedly search."""
        api_key = getattr(settings, "ANTHROPIC_API_KEY", None)
        if not api_key:
            self.stderr.write(self.style.ERROR("ANTHROPIC_API_KEY not configured, skipping categorization"))
            return all_feeds

        client = anthropic.Anthropic(api_key=api_key)

        uncategorized = [url for url, feed in all_feeds.items() if not feed.get("feedly_category")]

        if not uncategorized:
            self.stdout.write("All feeds already have categories from Feedly search")
            return all_feeds

        self.stdout.write(f"Categorizing {len(uncategorized)} feeds with Claude...")

        category_list = "\n".join(
            f"- {cat}: {', '.join(subs)}" for cat, subs in sorted(taxonomy.items())
        )

        for i in range(0, len(uncategorized), CATEGORIZE_BATCH_SIZE):
            batch_urls = uncategorized[i : i + CATEGORIZE_BATCH_SIZE]
            batch_feeds = [
                {
                    "feed_url": url,
                    "title": all_feeds[url].get("title", ""),
                    "description": all_feeds[url].get("description", ""),
                }
                for url in batch_urls
            ]

            batch_num = i // CATEGORIZE_BATCH_SIZE + 1
            total_batches = (len(uncategorized) + CATEGORIZE_BATCH_SIZE - 1) // CATEGORIZE_BATCH_SIZE
            self.stdout.write(f"  Batch {batch_num}/{total_batches} ({len(batch_feeds)} feeds)...")

            categorized = self._categorize_batch(client, batch_feeds, category_list)
            if categorized:
                for item in categorized:
                    url = item.get("feed_url", "")
                    if url in all_feeds:
                        all_feeds[url]["feedly_category"] = item.get("category", "")
                        all_feeds[url]["feedly_subcategory"] = item.get("subcategory", "")

        return all_feeds

    def _categorize_batch(self, client, feeds, category_list):
        """Categorize a batch of feeds using Claude."""
        feeds_json = json.dumps(feeds, indent=1)

        prompt = f"""Categorize each RSS feed into the best matching category and subcategory.

Available categories and subcategories:
{category_list}

Feeds to categorize:
{feeds_json}

For each feed, return the feed_url, best category (lowercase), and best subcategory."""

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
                feature="discover_real_feeds_categorize",
                input_tokens=response.usage.input_tokens,
                output_tokens=response.usage.output_tokens,
            )

            for block in response.content:
                if block.type == "tool_use" and block.name == "save_categorized_feeds":
                    return block.input.get("feeds", [])

        except anthropic.APIError as e:
            self.stderr.write(self.style.ERROR(f"  Claude API error: {e}"))

        return None

    def _to_fixture_format(self, all_feeds):
        """Convert internal feed dict to fixture JSON format."""
        feeds_list = []
        for url, feed in all_feeds.items():
            category = feed.get("feedly_category", "").lower()
            subcategory = feed.get("feedly_subcategory", "")

            if not category:
                continue  # skip uncategorized

            feeds_list.append(
                {
                    "feed_type": "rss",
                    "category": category,
                    "subcategory": subcategory,
                    "title": feed.get("title", ""),
                    "description": feed.get("description", ""),
                    "feed_url": url,
                    "subscriber_count": feed.get("subscriber_count", 0),
                    "platform": "",
                    "thumbnail_url": "",
                }
            )

        feeds_list.sort(key=lambda f: (f["category"], f["subcategory"], -f["subscriber_count"]))
        return feeds_list

    def _write_fixture(self, new_rss_feeds):
        """Write to fixture file, preserving non-RSS feeds."""
        fixture_path = os.path.normpath(FIXTURE_PATH)

        existing_feeds = []
        if os.path.exists(fixture_path):
            with open(fixture_path, "r") as f:
                existing_feeds = json.load(f)

        non_rss = [f for f in existing_feeds if f["feed_type"] != "rss"]
        all_feeds = non_rss + new_rss_feeds

        with open(fixture_path, "w") as f:
            json.dump(all_feeds, f, indent=2)

        self.stdout.write(
            self.style.SUCCESS(
                f"\nWrote {len(new_rss_feeds)} RSS feeds + {len(non_rss)} other feeds = "
                f"{len(all_feeds)} total to {fixture_path}"
            )
        )

    def _print_summary(self, feeds):
        """Print summary of discovered feeds."""
        from collections import Counter

        self.stdout.write("\n--- Discovery Summary ---")
        cat_counts = Counter(f["category"] for f in feeds)
        self.stdout.write(f"\n{len(feeds)} RSS feeds across {len(cat_counts)} categories:")
        for cat, count in cat_counts.most_common():
            self.stdout.write(f"  {cat}: {count}")

        subs = [f["subscriber_count"] for f in feeds if f["subscriber_count"] > 0]
        if subs:
            self.stdout.write(
                f"\nSubscriber counts: min={min(subs)}, max={max(subs)}, "
                f"median={sorted(subs)[len(subs) // 2]}"
            )
