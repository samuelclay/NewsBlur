"""
Management command to discover real newsletters from platform APIs.
Replaces AI-generated newsletter entries with verified, real newsletters from
Substack, Medium, Ghost, and Buttondown.

Data Sources:
1. Substack Category API (unauthenticated) - browse by category for top publications
2. TopPub.xyz scraping - leaderboard of Medium publications by tag
3. Feedly Search API (unauthenticated) - search by domain-scoped keywords for Medium
4. Ghost Explore sitemap scraping - top publications from Ghost's directory

Usage:
    python manage.py discover_newsletters
    python manage.py discover_newsletters --platform substack
    python manage.py discover_newsletters --platform medium
    python manage.py discover_newsletters --resume
    python manage.py discover_newsletters --dry-run --verbose
"""

import json
import os
import re
import time
import xml.etree.ElementTree as ET

import anthropic
import requests
from django.conf import settings
from django.core.management.base import BaseCommand

from utils.llm_costs import LLMCostTracker

FIXTURE_DIR = os.path.join(os.path.dirname(__file__), "../../fixtures")
FIXTURE_PATH = os.path.join(FIXTURE_DIR, "popular_feeds.json")
CACHE_PATH = os.path.join(FIXTURE_DIR, "newsletter_cache.json")

FEEDLY_SEARCH_URL = "https://cloud.feedly.com/v3/search/feeds"
FEEDLY_DELAY = 2.0
FEEDLY_RATE_LIMIT_WAIT = 60

SUBSTACK_DELAY = 2.0
SUBSTACK_PAGE_SIZE = 25

TOPPUB_DELAY = 1.0
TOPPUB_PAGES_PER_TAG = 3  # 15 pubs per page × 3 pages = 45 per tag

CLAUDE_MODEL = "claude-haiku-4-5"
CATEGORIZE_BATCH_SIZE = 100

# Substack categories: (id, name) from /api/v1/categories
SUBSTACK_CATEGORIES = [
    (4, "Technology"),
    (62, "Business"),
    (153, "Finance"),
    (96, "Culture"),
    (103, "News"),
    (134, "Science"),
    (94, "Sports"),
    (11, "Music"),
    (355, "Health & Wellness"),
    (13645, "Food & Drink"),
    (109, "Travel"),
    (18, "History"),
    (114, "Philosophy"),
    (61, "Design"),
    (34, "Education"),
    (339, "Literature"),
    (284, "Fiction"),
    (223, "Faith & Spirituality"),
    (15414, "Climate & Environment"),
    (49715, "Fashion & Beauty"),
    (15417, "Art & Illustration"),
    (118, "Crypto"),
    (76739, "U.S. Politics"),
    (76740, "World Politics"),
    (1796, "Parenting"),
    (49692, "Humor"),
    (76782, "Film & TV"),
    (387, "Comics"),
    (51282, "International"),
]

# Map Substack category names to our taxonomy categories
SUBSTACK_TO_TAXONOMY = {
    "Technology": "technology",
    "Business": "business",
    "Finance": "finance",
    "Culture": "arts & culture",
    "News": "news & politics",
    "Science": "science",
    "Sports": "sports",
    "Music": "music",
    "Health & Wellness": "health & fitness",
    "Food & Drink": "food & cooking",
    "Travel": "travel",
    "History": "history",
    "Philosophy": "philosophy",
    "Design": "design",
    "Education": "education",
    "Literature": "books & reading",
    "Fiction": "books & reading",
    "Faith & Spirituality": "religion & spirituality",
    "Climate & Environment": "environment & sustainability",
    "Fashion & Beauty": "fashion & beauty",
    "Art & Illustration": "arts & culture",
    "Crypto": "cryptocurrency & web3",
    "U.S. Politics": "news & politics",
    "World Politics": "news & politics",
    "Parenting": "parenting",
    "Humor": "comedy & humor",
    "Film & TV": "entertainment",
    "Comics": "entertainment",
    "International": "news & politics",
}

# The canonical taxonomy (same as discover_real_feeds.py)
TAXONOMY = {
    "technology": [
        "AI & Machine Learning",
        "Cloud Computing",
        "Cybersecurity",
        "Gadgets",
        "Mobile Apps",
        "Open Source",
        "Programming",
        "Reviews",
        "Startups",
        "Web Development",
    ],
    "science": [
        "Astronomy",
        "Biology",
        "Chemistry",
        "Environmental Science",
        "Innovation",
        "Medical Science",
        "Neuroscience",
        "Physics",
        "Quantum Science",
        "Research & Discoveries",
    ],
    "gaming": [
        "Board Games",
        "Console Gaming",
        "Esports",
        "Game Design",
        "Game Reviews",
        "Gaming Culture",
        "Gaming News",
        "Indie Games",
        "Mobile Gaming",
        "PC Gaming",
    ],
    "education": [
        "Academic Research",
        "Classroom Innovation",
        "Distance Learning",
        "Early Education",
        "EdTech",
        "Higher Education",
        "K-12",
        "Language Learning",
        "STEM",
        "Teaching Resources",
    ],
    "entertainment": [
        "Award Shows",
        "Celebrity",
        "Fan Culture",
        "Film & TV",
        "Late Night",
        "Pop Culture",
        "Reality TV",
        "Satire",
        "Streaming",
        "Viral Content",
    ],
    "news & politics": [
        "Campaign News",
        "Diplomacy",
        "Fact-Checking",
        "Geopolitics",
        "Investigative",
        "Local News",
        "National News",
        "Opinion & Editorials",
        "Policy Analysis",
        "World News",
    ],
    "sports": [
        "Baseball",
        "Basketball",
        "Cycling",
        "Fantasy Sports",
        "Football",
        "Golf",
        "Hockey",
        "MMA & Boxing",
        "Soccer",
        "Tennis",
    ],
    "music": [
        "Album Reviews",
        "Classical Music",
        "Concert Tours",
        "Hip-Hop & Rap",
        "Indie Music",
        "Jazz & Blues",
        "Music Industry",
        "Music Production",
        "New Releases",
        "Rock & Alternative",
    ],
    "comedy & humor": [
        "Comedians",
        "Comedy News",
        "Comedy Writing",
        "Dark Humor",
        "Entertainment Humor",
        "Funny Videos",
        "Memes & Viral",
        "Satire & Parody",
        "Sketch Comedy",
        "Stand-up Comedy",
    ],
    "business": [
        "Corporate News",
        "Economics",
        "Entrepreneurship",
        "Industry Analysis",
        "Management & Leadership",
        "Marketing",
        "Small Business",
        "Startups & VC",
        "Strategy",
        "Supply Chain",
    ],
    "food & cooking": [
        "Baking",
        "Celebrity Chefs",
        "Comfort Food",
        "Cooking Techniques",
        "Food Science",
        "Healthy Eating",
        "International Cuisine",
        "Recipe Collections",
        "Restaurant Reviews",
        "Vegan & Vegetarian",
    ],
    "travel": [
        "Adventure Travel",
        "Budget Travel",
        "Cultural Tourism",
        "Digital Nomad",
        "Family Travel",
        "Hotel Reviews",
        "Luxury Travel",
        "Road Trips",
        "Solo Travel",
        "Travel Photography",
    ],
    "photography": [
        "Camera Gear",
        "Editing & Post-Processing",
        "Film Photography",
        "Landscape Photography",
        "Nature Photography",
        "Photo Tutorials",
        "Photography News",
        "Portrait Photography",
        "Street Photography",
        "Wildlife Photography",
    ],
    "finance": [
        "Banking & Fintech",
        "Budgeting",
        "Credit & Debt",
        "Financial Markets",
        "Financial Planning",
        "Insurance",
        "Investing",
        "Personal Finance",
        "Retirement Planning",
        "Taxes",
    ],
    "design": [
        "Brand Identity",
        "Design Inspiration",
        "Design Tools",
        "Graphic Design",
        "Industrial Design",
        "Interior Design",
        "Motion Graphics",
        "Typography",
        "UI/UX Design",
        "Web Design",
    ],
    "environment & sustainability": [
        "Clean Energy",
        "Climate Change",
        "Conservation",
        "Eco-Friendly Living",
        "Environmental Policy",
        "Green Technology",
        "Oceans & Water",
        "Pollution",
        "Sustainability News",
        "Wildlife",
    ],
    "health & fitness": [
        "Diet & Nutrition",
        "Exercise & Workouts",
        "Health News",
        "Medical Research",
        "Men's Health",
        "Mental Health",
        "Mindfulness",
        "Running & Endurance",
        "Weight Training",
        "Women's Health",
    ],
    "lifestyle": [
        "City Living",
        "Conscious Living",
        "Home Organization",
        "Luxury Lifestyle",
        "Minimalism",
        "Modern Etiquette",
        "Personal Development",
        "Self-Help",
        "Simple Living",
        "Urban Living",
    ],
    "arts & culture": [
        "Art Criticism",
        "Art History",
        "Cultural Events",
        "Cultural News",
        "Dance",
        "Literary Arts",
        "Museums & Galleries",
        "Performing Arts",
        "Theater & Drama",
        "Visual Arts",
    ],
    "history": [
        "Ancient History",
        "Archaeology",
        "Art & Cultural History",
        "Historical Figures",
        "Medieval History",
        "Military History",
        "Modern History",
        "Public History",
        "Social History",
        "World History",
    ],
    "books & reading": [
        "Audiobooks",
        "Author News",
        "Book Culture",
        "Book Recommendations",
        "Book Reviews",
        "Fiction",
        "Literature",
        "New Releases",
        "Non-Fiction",
        "Publishing Industry",
    ],
    "cryptocurrency & web3": [
        "Bitcoin & Ethereum",
        "Blockchain Technology",
        "Crypto News",
        "Crypto Regulation",
        "Crypto Security",
        "Crypto Trading",
        "DeFi & Finance",
        "NFTs & Digital Assets",
        "Stablecoins",
        "Web3 Development",
    ],
    "parenting": [
        "Activities & Crafts",
        "Baby & Toddler",
        "Co-Parenting",
        "Family Health",
        "Homeschooling",
        "Parenting Advice",
        "Pregnancy",
        "School-Age Kids",
        "Special Needs",
        "Teen Parenting",
    ],
    "fashion & beauty": [
        "Beauty Tips",
        "Designer Fashion",
        "Fashion News",
        "Fashion Trends",
        "Hair Care",
        "Makeup",
        "Men's Fashion",
        "Skincare",
        "Street Style",
        "Sustainable Fashion",
    ],
    "religion & spirituality": [
        "Buddhism",
        "Christianity",
        "Comparative Religion",
        "Hinduism",
        "Interfaith Dialogue",
        "Islam",
        "Judaism",
        "Meditation & Mindfulness",
        "Spiritual Growth",
        "Theology",
    ],
    "philosophy": [
        "Aesthetics",
        "Applied Ethics",
        "Eastern Philosophy",
        "Epistemology",
        "Ethics",
        "Existentialism",
        "Logic",
        "Metaphysics",
        "Philosophy of Mind",
        "Political Philosophy",
    ],
    "entrepreneurship & startups": [
        "Angel Investing",
        "Bootstrapping",
        "Founder Stories",
        "Fundraising",
        "Growth Hacking",
        "Incubators & Accelerators",
        "Product Management",
        "SaaS",
        "Startup Culture",
        "Venture Capital",
    ],
}

# Feedly search queries scoped by platform domain.
# Medium needs many diverse queries to get good coverage since Feedly returns
# different feeds per query. More keywords = more unique Medium publications.
FEEDLY_NEWSLETTER_QUERIES = {
    "medium": [
        # Technology
        "technology",
        "programming",
        "software engineering",
        "web development",
        "javascript",
        "python",
        "react",
        "devops",
        "cloud computing",
        "kubernetes",
        "machine learning",
        "artificial intelligence",
        "deep learning",
        "data science",
        "cybersecurity",
        "blockchain",
        "mobile development",
        "iOS development",
        "android development",
        "API design",
        "microservices",
        "system design",
        "open source",
        "tech industry",
        "silicon valley",
        # Business & Startups
        "startup",
        "entrepreneurship",
        "venture capital",
        "product management",
        "business strategy",
        "marketing",
        "growth hacking",
        "leadership",
        "management",
        "remote work",
        "SaaS",
        "B2B",
        "ecommerce",
        # Design
        "design",
        "UX design",
        "UI design",
        "product design",
        "graphic design",
        "typography",
        "accessibility",
        "design thinking",
        "figma",
        # Science & Health
        "science",
        "neuroscience",
        "biology",
        "physics",
        "climate change",
        "health",
        "wellness",
        "mental health",
        "fitness",
        "nutrition",
        "medicine",
        "psychology",
        "mindfulness",
        "meditation",
        # Finance
        "finance",
        "investing",
        "stock market",
        "cryptocurrency",
        "personal finance",
        "economics",
        "fintech",
        "real estate",
        # Culture & Society
        "culture",
        "society",
        "politics",
        "philosophy",
        "history",
        "education",
        "writing",
        "journalism",
        "media",
        "books",
        "literature",
        "poetry",
        # Lifestyle
        "travel",
        "food",
        "cooking",
        "photography",
        "architecture",
        "sustainability",
        "environment",
        "parenting",
        "relationships",
        # Creative
        "music",
        "film",
        "art",
        "gaming",
        "sports",
        "comedy",
        "entertainment",
        "fashion",
        # Data & Analytics
        "data analytics",
        "data visualization",
        "statistics",
        "big data",
        "data engineering",
        "SQL",
        # Career
        "career",
        "productivity",
        "self improvement",
        "freelancing",
        "job search",
        "interviewing",
        "salary negotiation",
    ],
}

# Domain patterns for platform detection
PLATFORM_DOMAINS = {
    "substack": [".substack.com"],
    "medium": ["medium.com/feed/", "medium.com/feed/@", "medium.com/feed"],
    "ghost": [".ghost.io"],
    "buttondown": ["buttondown.email", "buttondown.com"],
    "beehiiv": [".beehiiv.com"],
}


# TopPub.xyz tags: (id, name, taxonomy_category)
# Scraped from https://toppub.xyz/publications/tags
# We select a diverse subset of the 103 available tags, mapped to our taxonomy.
TOPPUB_TAGS = [
    # Technology
    (2, "artificial intelligence", "technology"),
    (518, "ai", "technology"),
    (20, "technology", "technology"),
    (4, "tech", "technology"),
    (85, "programming", "technology"),
    (447, "javascript", "technology"),
    (508, "python", "technology"),
    (312, "react", "technology"),
    (59, "web development", "technology"),
    (306, "coding", "technology"),
    (340, "software engineering", "technology"),
    (324, "software development", "technology"),
    (454, "software", "technology"),
    (192, "devops", "technology"),
    (191, "cloud computing", "technology"),
    (1218, "cybersecurity", "technology"),
    (296, "open source", "technology"),
    (302, "mobile app development", "technology"),
    (547, "android", "technology"),
    (58, "engineering", "technology"),
    (719, "digital transformation", "technology"),
    # Data & AI
    (546, "data science", "technology"),
    (348, "machine learning", "technology"),
    (670, "deep learning", "technology"),
    (221, "data", "technology"),
    (219, "data visualization", "technology"),
    # Business & Startups
    (41, "business", "business"),
    (12, "startup", "entrepreneurship & startups"),
    (10, "entrepreneurship", "entrepreneurship & startups"),
    (49, "venture capital", "finance"),
    (32, "marketing", "business"),
    (245, "leadership", "business"),
    (108, "innovation", "business"),
    (56, "product management", "business"),
    (530, "product development", "business"),
    (55, "productivity", "lifestyle"),
    (149, "social media", "business"),
    # Design
    (13, "design", "design"),
    (226, "design thinking", "design"),
    (57, "product design", "design"),
    (47, "user experience", "design"),
    (44, "ux", "design"),
    (45, "ux design", "design"),
    # Science & Health
    (193, "science", "science"),
    (342, "research", "science"),
    (23, "health", "health & fitness"),
    (387, "mental health", "health & fitness"),
    (554, "psychology", "health & fitness"),
    # Finance & Crypto
    (214, "finance", "finance"),
    (213, "investing", "finance"),
    (274, "economics", "finance"),
    (510, "fintech", "finance"),
    (512, "money", "finance"),
    (136, "bitcoin", "cryptocurrency & web3"),
    (148, "blockchain", "cryptocurrency & web3"),
    (137, "cryptocurrency", "cryptocurrency & web3"),
    (138, "ethereum", "cryptocurrency & web3"),
    # Culture & Society
    (7, "culture", "arts & culture"),
    (79, "art", "arts & culture"),
    (17, "creativity", "arts & culture"),
    (248, "society", "arts & culture"),
    (88, "politics", "news & politics"),
    (38, "news", "news & politics"),
    (9, "journalism", "news & politics"),
    (11, "media", "news & politics"),
    (171, "history", "history"),
    (371, "philosophy", "philosophy"),
    (22, "education", "education"),
    (354, "learning", "education"),
    # Writing & Books
    (165, "writing", "books & reading"),
    (1336, "writing tips", "books & reading"),
    (91, "books", "books & reading"),
    (21, "fiction", "books & reading"),
    (63, "poetry", "books & reading"),
    # Lifestyle
    (14, "life", "lifestyle"),
    (16, "life lessons", "lifestyle"),
    (18, "personal growth", "lifestyle"),
    (19, "personal development", "lifestyle"),
    (365, "self improvement", "lifestyle"),
    (287, "self", "lifestyle"),
    (272, "inspiration", "lifestyle"),
    (90, "lifestyle", "lifestyle"),
    (60, "love", "lifestyle"),
    (61, "relationships", "lifestyle"),
    # Entertainment & Media
    (182, "film", "entertainment"),
    (94, "movies", "entertainment"),
    (74, "music", "music"),
    (133, "sports", "sports"),
    (40, "humor", "comedy & humor"),
    (157, "photography", "photography"),
    # Other
    (184, "travel", "travel"),
    (66, "food", "food & cooking"),
    (119, "parenting", "parenting"),
    (64, "environment", "environment & sustainability"),
    (68, "climate change", "environment & sustainability"),
    (505, "sustainability", "environment & sustainability"),
    (140, "feminism", "arts & culture"),
    (139, "women", "arts & culture"),
    (954, "spirituality", "religion & spirituality"),
]


class Command(BaseCommand):
    help = "Discover real newsletters from Substack, Medium, Ghost, and Buttondown APIs"

    def add_arguments(self, parser):
        parser.add_argument(
            "--platform",
            choices=["substack", "medium", "ghost", "all"],
            default="all",
            help="Which platforms to discover (default: all)",
        )
        parser.add_argument("--dry-run", action="store_true", help="Preview without writing")
        parser.add_argument("--verbose", action="store_true", help="Detailed output")
        parser.add_argument(
            "--resume", action="store_true", help="Resume from cached results after rate limiting"
        )
        parser.add_argument(
            "--use-proxy", action="store_true", help="Use ScrapingBee proxy for rate-limited APIs"
        )
        parser.add_argument("--skip-categorize", action="store_true", help="Skip Claude categorization")
        parser.add_argument(
            "--max-pages", type=int, default=20, help="Max pages per Substack category (default: 20)"
        )
        parser.add_argument(
            "--ghost-limit",
            type=int,
            default=600,
            help="Max Ghost publications to scrape from sitemap (default: 600)",
        )
        parser.add_argument(
            "--feedly-count", type=int, default=40, help="Results per Feedly search (default: 40)"
        )
        parser.add_argument(
            "--toppub-pages",
            type=int,
            default=TOPPUB_PAGES_PER_TAG,
            help=f"Pages per TopPub tag to scrape (default: {TOPPUB_PAGES_PER_TAG}, 15 pubs/page)",
        )

    def handle(self, *args, **options):
        self.verbose = options["verbose"]
        self.dry_run = options["dry_run"]
        self.use_proxy = options["use_proxy"]

        platform = options["platform"]
        all_newsletters = {}  # keyed by feed_url

        # Load cache for resume support
        cache = self._load_cache() if options["resume"] else {"feeds": {}, "completed": []}
        if options["resume"] and cache["feeds"]:
            all_newsletters.update(cache["feeds"])
            self.stdout.write(f"Resumed with {len(all_newsletters)} cached newsletters")

        # Phase 1: Substack category browsing
        if platform in ("substack", "all"):
            substack_feeds = self._discover_substack(options["max_pages"], cache)
            self.stdout.write(self.style.SUCCESS(f"Substack: discovered {len(substack_feeds)} newsletters"))
            all_newsletters.update(substack_feeds)
            # Save cache after Substack phase
            cache["feeds"] = all_newsletters
            self._save_cache(cache)

        # Phase 2a: TopPub.xyz scraping for Medium publications
        if platform in ("medium", "all"):
            toppub_feeds = self._discover_medium_toppub(
                cache, options.get("toppub_pages", TOPPUB_PAGES_PER_TAG)
            )
            self.stdout.write(
                self.style.SUCCESS(f"Medium (TopPub): discovered {len(toppub_feeds)} newsletters")
            )
            all_newsletters.update(toppub_feeds)
            cache["feeds"] = all_newsletters
            self._save_cache(cache)

        # Phase 2b: Feedly search for additional Medium feeds
        if platform in ("medium", "all"):
            medium_feeds = self._search_feedly_for_platform(
                "medium", "site:medium.com", options["feedly_count"], cache
            )
            self.stdout.write(
                self.style.SUCCESS(f"Medium (Feedly): discovered {len(medium_feeds)} newsletters")
            )
            for url, feed in medium_feeds.items():
                if url not in all_newsletters:
                    all_newsletters[url] = feed
            cache["feeds"] = all_newsletters
            self._save_cache(cache)

        # Phase 3: Ghost Explore sitemap scraping
        if platform in ("ghost", "all"):
            ghost_feeds = self._discover_ghost_explore(cache, options["ghost_limit"])
            self.stdout.write(self.style.SUCCESS(f"Ghost: discovered {len(ghost_feeds)} newsletters"))
            for url, feed in ghost_feeds.items():
                if url not in all_newsletters:
                    all_newsletters[url] = feed
            cache["feeds"] = all_newsletters
            self._save_cache(cache)

        self.stdout.write(f"\nTotal unique newsletters: {len(all_newsletters)}")

        # Phase 5: Categorize uncategorized feeds with Claude
        if not options["skip_categorize"]:
            all_newsletters = self._categorize_feeds(all_newsletters)

        # Phase 6: Convert to fixture format and write
        newsletters_list = self._to_fixture_format(all_newsletters)

        if self.dry_run:
            self.stdout.write(self.style.WARNING("\nDry run - not writing fixture file"))
            self._print_summary(newsletters_list)
            return

        self._write_fixture(newsletters_list)
        self._print_summary(newsletters_list)

    def _load_cache(self):
        """Load cached newsletter results."""
        cache_path = os.path.normpath(CACHE_PATH)
        if os.path.exists(cache_path):
            with open(cache_path, "r") as f:
                return json.load(f)
        return {"feeds": {}, "completed": []}

    def _save_cache(self, cache):
        """Save newsletter results to cache."""
        cache_path = os.path.normpath(CACHE_PATH)
        with open(cache_path, "w") as f:
            json.dump(cache, f)

    def _parse_subscriber_count(self, count_str):
        """Parse Substack subscriber count string like '1,100,000' or '459K+' to int."""
        if not count_str:
            return 0
        if isinstance(count_str, (int, float)):
            return int(count_str)
        # Remove commas and plus signs
        cleaned = str(count_str).replace(",", "").replace("+", "").strip()
        # Handle K/M suffixes
        multiplier = 1
        if cleaned.upper().endswith("M"):
            multiplier = 1_000_000
            cleaned = cleaned[:-1]
        elif cleaned.upper().endswith("K"):
            multiplier = 1_000
            cleaned = cleaned[:-1]
        try:
            return int(float(cleaned) * multiplier)
        except (ValueError, TypeError):
            return 0

    # -- Substack Discovery --

    def _discover_substack(self, max_pages, cache):
        """Browse Substack categories to discover top newsletters."""
        feeds = {}
        completed = set(cache.get("completed", []))
        total_categories = len(SUBSTACK_CATEGORIES)

        for idx, (cat_id, cat_name) in enumerate(SUBSTACK_CATEGORIES, 1):
            cache_key = f"substack:{cat_id}"
            if cache_key in completed:
                if self.verbose:
                    self.stdout.write(f"  [{idx}/{total_categories}] Skipping {cat_name} (cached)")
                continue

            self.stdout.write(f"  [{idx}/{total_categories}] Browsing Substack: {cat_name}")
            self.stdout.flush()

            page = 0
            category_count = 0
            consecutive_empty = 0

            while page < max_pages:
                try:
                    url = f"https://substack.com/api/v1/category/public/{cat_id}/all"
                    resp = requests.get(
                        url,
                        params={"page": page, "limit": SUBSTACK_PAGE_SIZE},
                        timeout=15,
                        headers={"User-Agent": "NewsBlur/1.0 (newsletter discovery)"},
                    )

                    if resp.status_code == 429:
                        self.stdout.write(
                            self.style.WARNING(f"    Rate limited on page {page}, saving cache...")
                        )
                        cache["feeds"].update(feeds)
                        cache["completed"] = list(completed)
                        self._save_cache(cache)
                        time.sleep(FEEDLY_RATE_LIMIT_WAIT)
                        continue

                    if resp.status_code != 200:
                        if self.verbose:
                            self.stdout.write(
                                self.style.WARNING(f"    HTTP {resp.status_code} on page {page}")
                            )
                        break

                    data = resp.json()
                    publications = data if isinstance(data, list) else data.get("publications", [])

                    if not publications:
                        consecutive_empty += 1
                        if consecutive_empty >= 2:
                            break
                        page += 1
                        time.sleep(SUBSTACK_DELAY)
                        continue

                    consecutive_empty = 0

                    for pub in publications:
                        feed = self._parse_substack_publication(pub, cat_name)
                        if feed:
                            feed_url = feed["feed_url"]
                            if feed_url not in feeds:
                                feeds[feed_url] = feed
                                category_count += 1

                    page += 1
                    time.sleep(SUBSTACK_DELAY)

                except requests.RequestException as e:
                    if self.verbose:
                        self.stdout.write(self.style.WARNING(f"    Request error: {e}"))
                    break

            completed.add(cache_key)
            if self.verbose:
                self.stdout.write(f"    Found {category_count} new newsletters in {cat_name}")

            # Periodic cache save
            if idx % 5 == 0:
                cache["feeds"].update(feeds)
                cache["completed"] = list(completed)
                self._save_cache(cache)

        # Final cache save
        cache["feeds"].update(feeds)
        cache["completed"] = list(completed)
        self._save_cache(cache)

        return feeds

    def _parse_substack_publication(self, pub, substack_category):
        """Parse a Substack publication object into our feed dict format."""
        subdomain = pub.get("subdomain", "")
        if not subdomain:
            return None

        name = pub.get("name", "")
        if not name:
            return None

        # Build feed URL
        custom_domain = pub.get("custom_domain")
        if custom_domain:
            feed_url = f"https://{custom_domain}/feed"
        else:
            feed_url = f"https://{subdomain}.substack.com/feed"

        # Parse subscriber count - try freeSubscriberCount first, fall back to order of magnitude
        subscriber_count = self._parse_subscriber_count(
            pub.get("freeSubscriberCount") or pub.get("freeSubscriberCountOrderOfMagnitude") or 0
        )

        # Use hero_text or author_bio as description
        description = pub.get("hero_text", "") or pub.get("author_bio", "") or ""
        if len(description) > 200:
            description = description[:197] + "..."

        # Map Substack category to our taxonomy
        category = SUBSTACK_TO_TAXONOMY.get(substack_category, "")

        return {
            "feed_url": feed_url,
            "title": name,
            "description": description,
            "subscriber_count": subscriber_count,
            "platform": "substack",
            "category": category,
            "subcategory": "",
            "source": "substack_api",
        }

    # -- Feedly Search for Non-Substack Platforms --

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
            headers={"User-Agent": "NewsBlur/1.0 (newsletter discovery)"},
        )

    def _search_feedly_for_platform(self, platform, domain_prefix, count, cache):
        """Search Feedly for newsletters on a specific platform.

        Feedly doesn't support site: filters, so we use domain name + keyword queries
        and filter results by URL domain after fetching.
        """
        queries = FEEDLY_NEWSLETTER_QUERIES.get(platform, [])
        feeds = {}
        completed = set(cache.get("completed", []))
        total_queries = len(queries)
        consecutive_429s = 0

        # Map platform to domain for URL filtering
        domain_filter = {
            "medium": "medium.com",
            "ghost": "ghost.io",
            "buttondown": "buttondown.email",
        }.get(platform, "")

        for idx, query_term in enumerate(queries, 1):
            cache_key = f"feedly:{platform}:{query_term}"
            if cache_key in completed:
                continue

            # Use domain name + keyword (Feedly doesn't support site: syntax)
            search_query = f"{domain_filter} {query_term}"
            if self.verbose:
                self.stdout.write(f"  [{idx}/{total_queries}] Searching Feedly: {search_query}")
            elif idx % 5 == 0 or idx == 1:
                self.stdout.write(f"  [{idx}/{total_queries}] {len(feeds)} {platform} feeds so far...")

            try:
                resp = self._feedly_get(FEEDLY_SEARCH_URL, {"query": search_query, "count": count})
                if resp is None:
                    break

                if resp.status_code == 429 and not self.use_proxy:
                    consecutive_429s += 1
                    wait_time = FEEDLY_RATE_LIMIT_WAIT * consecutive_429s
                    self.stdout.write(
                        self.style.WARNING(f"    Rate limited ({consecutive_429s}x), waiting {wait_time}s...")
                    )
                    cache["feeds"].update(feeds)
                    cache["completed"] = list(completed)
                    self._save_cache(cache)

                    if consecutive_429s >= 3:
                        self.stdout.write(
                            self.style.WARNING(
                                "    Too many rate limits. Use --resume --use-proxy to continue."
                            )
                        )
                        return feeds

                    time.sleep(wait_time)
                    resp = self._feedly_get(FEEDLY_SEARCH_URL, {"query": search_query, "count": count})
                    if resp is None or resp.status_code == 429:
                        cache["feeds"].update(feeds)
                        cache["completed"] = list(completed)
                        self._save_cache(cache)
                        return feeds

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
                        feed = self._parse_feedly_newsletter(result, platform)
                        if feed:
                            feed_url = feed["feed_url"]
                            if feed_url not in feeds:
                                feeds[feed_url] = feed
                                new_in_batch += 1

                    completed.add(cache_key)
                    if self.verbose and new_in_batch > 0:
                        self.stdout.write(f"    +{new_in_batch} new feeds ({len(results)} results)")
                else:
                    if self.verbose:
                        self.stdout.write(self.style.WARNING(f"    HTTP {resp.status_code}"))
                    completed.add(cache_key)

            except requests.RequestException as e:
                if self.verbose:
                    self.stdout.write(self.style.WARNING(f"    Request error: {e}"))

            time.sleep(FEEDLY_DELAY)

        # Save progress
        cache["feeds"].update(feeds)
        cache["completed"] = list(completed)
        self._save_cache(cache)

        return feeds

    def _parse_feedly_newsletter(self, result, expected_platform):
        """Parse a Feedly search result into a newsletter feed dict."""
        feed_id = result.get("feedId", "")
        if not feed_id.startswith("feed/"):
            return None

        feed_url = feed_id[5:]  # strip "feed/" prefix
        if not feed_url.startswith(("http://", "https://")):
            return None

        # Detect platform from URL
        platform = self._detect_platform(feed_url)
        if not platform:
            # For Feedly results, check if the URL matches expected platform
            feed_url_lower = feed_url.lower()
            if expected_platform == "medium" and "medium.com" in feed_url_lower:
                platform = "medium"
            elif expected_platform == "ghost" and ".ghost.io" in feed_url_lower:
                platform = "ghost"
            elif expected_platform == "buttondown" and "buttondown" in feed_url_lower:
                platform = "buttondown"
            else:
                return None

        subscribers = result.get("subscribers", 0)
        velocity = result.get("velocity", 0)

        # Only include feeds with some activity
        if velocity == 0 and subscribers < 3:
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
            "platform": platform,
            "category": "",
            "subcategory": "",
            "source": "feedly",
        }

    # -- TopPub.xyz Medium Discovery --

    def _discover_medium_toppub(self, cache, pages_per_tag):
        """Discover Medium publications by scraping TopPub.xyz tag pages.

        TopPub.xyz is a leaderboard of ~20,000 Medium publications organized by tags.
        We scrape the top publications from each tag page (sorted by follower count)
        and construct RSS feed URLs as medium.com/feed/{slug}.
        """
        feeds = {}
        completed = set(cache.get("completed", []))
        total_tags = len(TOPPUB_TAGS)

        for idx, (tag_id, tag_name, taxonomy_cat) in enumerate(TOPPUB_TAGS, 1):
            for page in range(1, pages_per_tag + 1):
                cache_key = f"toppub:{tag_id}:p{page}"
                if cache_key in completed:
                    continue

                if page == 1:
                    self.stdout.write(f"  [{idx}/{total_tags}] TopPub tag: {tag_name}")
                    self.stdout.flush()

                try:
                    url = f"https://toppub.xyz/publications/tags/{tag_id}"
                    resp = requests.get(
                        url,
                        params={"page": page},
                        timeout=15,
                        headers={"User-Agent": "NewsBlur/1.0 (newsletter discovery)"},
                    )

                    if resp.status_code == 429:
                        self.stdout.write(self.style.WARNING("    Rate limited, saving cache..."))
                        cache["feeds"].update(feeds)
                        cache["completed"] = list(completed)
                        self._save_cache(cache)
                        time.sleep(30)
                        continue

                    if resp.status_code != 200:
                        completed.add(cache_key)
                        continue

                    page_feeds = self._parse_toppub_page(resp.text, taxonomy_cat)

                    new_count = 0
                    for feed_url, feed in page_feeds.items():
                        if feed_url not in feeds:
                            feeds[feed_url] = feed
                            new_count += 1

                    completed.add(cache_key)

                    if self.verbose and new_count > 0:
                        self.stdout.write(f"    p{page}: +{new_count} new ({len(page_feeds)} on page)")

                    # If page had fewer than 15 results, no more pages
                    if len(page_feeds) < 15:
                        # Mark remaining pages as completed
                        for remaining_page in range(page + 1, pages_per_tag + 1):
                            completed.add(f"toppub:{tag_id}:p{remaining_page}")
                        break

                except requests.RequestException as e:
                    if self.verbose:
                        self.stdout.write(self.style.WARNING(f"    Request error: {e}"))

                time.sleep(TOPPUB_DELAY)

            # Periodic cache save
            if idx % 10 == 0:
                cache["feeds"].update(feeds)
                cache["completed"] = list(completed)
                self._save_cache(cache)

        # Final cache save
        cache["feeds"].update(feeds)
        cache["completed"] = list(completed)
        self._save_cache(cache)

        return feeds

    def _parse_toppub_page(self, html, taxonomy_category):
        """Parse a TopPub.xyz tag page to extract Medium publication data.

        HTML structure per publication:
        <tr>
          <td><a href="https://toppub.xyz/publications/{slug}">...</a></td>
          <td><a href="https://toppub.xyz/publications/{slug}">{Name}</a></td>
          <td>{Description}</td>
          <td class="text-right">{Follower Count}</td>
        </tr>
        """
        feeds = {}

        # Match each table row with publication data
        # Pattern: slug from href, name from link text, description, follower count
        row_pattern = re.compile(
            r'<tr>\s*<td>\s*<a href="https://toppub\.xyz/publications/([^"]+)">'
            r".*?</td>\s*"
            r'<td><a href="https://toppub\.xyz/publications/[^"]+">([^<]+)</a></td>\s*'
            r"<td>(.*?)</td>\s*"
            r'<td class="text-right">([\d,]+)</td>\s*</tr>',
            re.DOTALL,
        )

        for match in row_pattern.finditer(html):
            slug = match.group(1).strip()
            name = match.group(2).strip()
            description = match.group(3).strip()
            follower_str = match.group(4).strip()

            if not slug or not name:
                continue

            # Clean up HTML entities in description
            description = description.replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
            description = re.sub(r"<[^>]+>", "", description)  # strip any HTML tags
            if len(description) > 200:
                description = description[:197] + "..."

            # Parse follower count
            try:
                follower_count = int(follower_str.replace(",", ""))
            except ValueError:
                follower_count = 0

            # Construct Medium RSS feed URL
            feed_url = f"https://medium.com/feed/{slug}"

            feeds[feed_url] = {
                "feed_url": feed_url,
                "title": name,
                "description": description,
                "subscriber_count": follower_count,
                "platform": "medium",
                "category": taxonomy_category,
                "subcategory": "",
                "source": "toppub",
            }

        return feeds

    # -- Ghost Explore Discovery --

    # Map Ghost Explore categories to our taxonomy
    GHOST_TO_TAXONOMY = {
        "news": "news & politics",
        "technology": "technology",
        "business": "business",
        "culture": "arts & culture",
        "science": "science",
        "food & drink": "food & cooking",
        "food": "food & cooking",
        "finance": "finance",
        "health & wellness": "health & fitness",
        "health": "health & fitness",
        "sport & fitness": "sports",
        "sports": "sports",
        "design": "design",
        "travel": "travel",
        "music": "music",
        "education": "education",
        "crypto": "cryptocurrency & web3",
        "gaming": "gaming",
        "programming": "technology",
        "youtubers": "entertainment",
        "politics": "news & politics",
        "art & illustration": "arts & culture",
        "fashion": "fashion & beauty",
        "photography": "photography",
        "movies & tv": "entertainment",
        "entertainment": "entertainment",
        "lifestyle": "lifestyle",
    }

    def _discover_ghost_explore(self, cache, ghost_limit=600):
        """Discover Ghost publications via the Ghost Explore sitemap.

        1. Fetch https://explore.ghost.org/sitemap.xml for all /p/{slug} URLs
        2. Fetch the top N publication pages to extract: site URL, name, category, subscriber count
        3. Build RSS feed URL as {site_url}/rss/

        The sitemap contains 40K+ entries sorted by popularity. We limit to the top
        ghost_limit entries to keep runtime reasonable (~5 minutes at 0.5s/request).
        """
        feeds = {}
        completed = set(cache.get("completed", []))

        # Step 1: Always fetch sitemap to get publication slugs (fast, idempotent)
        self.stdout.write("  Fetching Ghost Explore sitemap...")
        slugs = []

        try:
            resp = requests.get(
                "https://explore.ghost.org/sitemap.xml",
                timeout=15,
                headers={"User-Agent": "NewsBlur/1.0 (newsletter discovery)"},
            )
            if resp.status_code != 200:
                self.stdout.write(self.style.WARNING(f"    HTTP {resp.status_code}"))
                return feeds

            root = ET.fromstring(resp.text)
            ns = {"s": "http://www.sitemaps.org/schemas/sitemap/0.9"}

            for url_elem in root.findall("s:url", ns):
                loc = url_elem.find("s:loc", ns)
                if loc is not None and "/p/" in loc.text:
                    slug = loc.text.rstrip("/").split("/p/")[-1]
                    if slug:
                        slugs.append(slug)

            total_in_sitemap = len(slugs)
            slugs = slugs[:ghost_limit]  # Sitemap is sorted by popularity
            self.stdout.write(
                f"    Found {total_in_sitemap} publications in sitemap, scraping top {len(slugs)}"
            )

        except (requests.RequestException, ET.ParseError) as e:
            self.stdout.write(self.style.WARNING(f"    Error fetching sitemap: {e}"))
            return feeds

        # Step 2: Fetch each publication page for metadata
        total = len(slugs)
        for idx, slug in enumerate(slugs, 1):
            page_cache_key = f"ghost:p:{slug}"
            if page_cache_key in completed:
                continue

            if idx % 25 == 0 or idx == 1:
                self.stdout.write(f"  [{idx}/{total}] Fetching Ghost publications... ({len(feeds)} found)")

            try:
                resp = requests.get(
                    f"https://explore.ghost.org/p/{slug}",
                    timeout=10,
                    headers={"User-Agent": "NewsBlur/1.0 (newsletter discovery)"},
                )

                if resp.status_code == 429:
                    self.stdout.write(self.style.WARNING("    Rate limited, saving cache and pausing..."))
                    cache["feeds"].update(feeds)
                    cache["completed"] = list(completed)
                    self._save_cache(cache)
                    time.sleep(30)
                    continue

                if resp.status_code != 200:
                    completed.add(page_cache_key)
                    continue

                html = resp.text
                feed = self._parse_ghost_explore_page(html, slug)
                if feed:
                    feeds[feed["feed_url"]] = feed

                completed.add(page_cache_key)

            except requests.RequestException:
                pass

            # Gentle rate limiting - 0.5s between requests
            time.sleep(0.5)

            # Periodic cache save
            if idx % 50 == 0:
                cache["feeds"].update(feeds)
                cache["completed"] = list(completed)
                self._save_cache(cache)

        # Final cache save
        cache["feeds"].update(feeds)
        cache["completed"] = list(completed)
        self._save_cache(cache)

        return feeds

    def _parse_ghost_explore_page(self, html, slug):
        """Parse a Ghost Explore publication page to extract metadata."""
        # Extract actual site URL from ghost-explore referral links
        url_match = re.search(r'href="(https?://[^"]+)\?ref=ghost-explore"', html)
        if not url_match:
            return None

        site_url = url_match.group(1).rstrip("/")
        domain = site_url.split("//")[-1].split("/")[0].lower()

        # Skip ghost.org internal links
        if "ghost.org" in domain or "explore.ghost" in domain:
            return None

        feed_url = f"{site_url}/rss/"

        # Extract publication name from og:title (most reliable) or <title> tag
        og_match = re.search(r'<meta property="og:title" content="([^"]+)"', html)
        if og_match:
            title = og_match.group(1).strip()
        else:
            title_match = re.search(r"<title>([^<]+)</title>", html)
            if title_match:
                title = title_match.group(1).strip()
                # Remove " - Ghost Explore" suffix
                title = re.sub(r"\s*-\s*Ghost Explore$", "", title)
            else:
                title = slug.replace("-", " ").title()

        # Extract subscriber count - first match of "NNK subscribers"
        sub_match = re.search(r"([\d,.]+)\s*([KkMm])?\s*[Ss]ubscribers", html)
        subscriber_count = 0
        if sub_match:
            num_str = sub_match.group(1).replace(",", "")
            suffix = (sub_match.group(2) or "").upper()
            try:
                num = float(num_str)
                if suffix == "K":
                    subscriber_count = int(num * 1000)
                elif suffix == "M":
                    subscriber_count = int(num * 1_000_000)
                else:
                    subscriber_count = int(num)
            except ValueError:
                pass

        # Extract category from "More from {Category}" text
        cat_match = re.search(r"More from\s+([A-Za-z &]+)", html)
        ghost_category = cat_match.group(1).strip().lower() if cat_match else ""
        category = self.GHOST_TO_TAXONOMY.get(ghost_category, "")

        # Extract description from og:description
        desc_match = re.search(r'<meta property="og:description" content="([^"]*)"', html)
        description = desc_match.group(1).strip() if desc_match else ""
        if len(description) > 200:
            description = description[:197] + "..."

        return {
            "feed_url": feed_url,
            "title": title,
            "description": description,
            "subscriber_count": subscriber_count,
            "platform": "ghost",
            "category": category,
            "subcategory": "",
            "source": "ghost_explore",
        }

    def _detect_platform(self, url):
        """Detect newsletter platform from feed URL."""
        url_lower = url.lower()
        for platform, domains in PLATFORM_DOMAINS.items():
            for domain in domains:
                if domain in url_lower:
                    return platform
        return ""

    # -- Claude Categorization --

    def _categorize_feeds(self, all_feeds):
        """Use Claude to categorize feeds that don't have categories."""
        api_key = getattr(settings, "ANTHROPIC_API_KEY", None)
        if not api_key:
            self.stderr.write(self.style.ERROR("ANTHROPIC_API_KEY not configured, skipping categorization"))
            return all_feeds

        client = anthropic.Anthropic(api_key=api_key)

        uncategorized = [url for url, feed in all_feeds.items() if not feed.get("category")]
        if not uncategorized:
            self.stdout.write("All newsletters already have categories")
            return all_feeds

        self.stdout.write(f"Categorizing {len(uncategorized)} newsletters with Claude...")

        category_list = "\n".join(f"- {cat}: {', '.join(subs)}" for cat, subs in sorted(TAXONOMY.items()))

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
                        all_feeds[url]["category"] = item.get("category", "")
                        all_feeds[url]["subcategory"] = item.get("subcategory", "")

        return all_feeds

    def _categorize_batch(self, client, feeds, category_list):
        """Categorize a batch of feeds using Claude."""
        feeds_json = json.dumps(feeds, indent=1)

        prompt = f"""Categorize each newsletter into the best matching category and subcategory.

Available categories and subcategories:
{category_list}

Newsletters to categorize:
{feeds_json}

For each feed, return the feed_url, best category (lowercase), and best subcategory."""

        tool_definition = {
            "name": "save_categorized_feeds",
            "description": "Save the categorized newsletters",
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
                feature="discover_newsletters_categorize",
                input_tokens=response.usage.input_tokens,
                output_tokens=response.usage.output_tokens,
            )

            for block in response.content:
                if block.type == "tool_use" and block.name == "save_categorized_feeds":
                    return block.input.get("feeds", [])

        except anthropic.APIError as e:
            self.stderr.write(self.style.ERROR(f"  Claude API error: {e}"))

        return None

    # -- Fixture Output --

    def _to_fixture_format(self, all_feeds):
        """Convert internal feed dict to fixture JSON format."""
        feeds_list = []
        for url, feed in all_feeds.items():
            category = feed.get("category", "").lower()
            if not category:
                continue

            feeds_list.append(
                {
                    "feed_type": "newsletter",
                    "category": category,
                    "subcategory": feed.get("subcategory", ""),
                    "title": feed.get("title", ""),
                    "description": feed.get("description", ""),
                    "feed_url": url,
                    "subscriber_count": feed.get("subscriber_count", 0),
                    "platform": feed.get("platform", ""),
                    "thumbnail_url": "",
                }
            )

        feeds_list.sort(key=lambda f: (f["category"], f["subcategory"], -f["subscriber_count"]))
        return feeds_list

    def _write_fixture(self, new_newsletters):
        """Write to fixture file, replacing existing newsletter entries."""
        fixture_path = os.path.normpath(FIXTURE_PATH)

        existing_feeds = []
        if os.path.exists(fixture_path):
            with open(fixture_path, "r") as f:
                existing_feeds = json.load(f)

        # Keep everything except newsletters
        non_newsletter = [f for f in existing_feeds if f["feed_type"] != "newsletter"]
        all_feeds = non_newsletter + new_newsletters

        with open(fixture_path, "w") as f:
            json.dump(all_feeds, f, indent=2)

        self.stdout.write(
            self.style.SUCCESS(
                f"\nWrote {len(new_newsletters)} newsletters + {len(non_newsletter)} other feeds = "
                f"{len(all_feeds)} total to {fixture_path}"
            )
        )

    def _print_summary(self, feeds):
        """Print summary of discovered newsletters."""
        from collections import Counter

        self.stdout.write("\n--- Newsletter Discovery Summary ---")

        platform_counts = Counter(f["platform"] for f in feeds)
        self.stdout.write(f"\n{len(feeds)} newsletters by platform:")
        for platform, count in platform_counts.most_common():
            self.stdout.write(f"  {platform or 'unknown'}: {count}")

        cat_counts = Counter(f["category"] for f in feeds)
        self.stdout.write(f"\nAcross {len(cat_counts)} categories:")
        for cat, count in cat_counts.most_common():
            self.stdout.write(f"  {cat}: {count}")

        subs = [f["subscriber_count"] for f in feeds if f["subscriber_count"] > 0]
        if subs:
            self.stdout.write(
                f"\nSubscriber counts: min={min(subs)}, max={max(subs)}, "
                f"median={sorted(subs)[len(subs) // 2]}, "
                f"feeds with counts={len(subs)}/{len(feeds)}"
            )
