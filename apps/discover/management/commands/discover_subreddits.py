"""
Management command to discover real Reddit subreddits from the Reddit API.
Replaces AI-generated subreddit entries with verified, real subreddits.

Data Sources:
1. Reddit /subreddits/popular.json with after= pagination (~800-1,000 results)
2. Reddit /subreddits/search.json by taxonomy keywords (~500+ additional)

Uses OAuth2 app-only flow with REDDIT_CLIENT_ID / REDDIT_CLIENT_SECRET
from local_settings.py for authenticated API access (100 req/min).

Usage:
    python manage.py discover_subreddits
    python manage.py discover_subreddits --resume
    python manage.py discover_subreddits --dry-run --verbose
    python manage.py discover_subreddits --min-subscribers 10000
"""

import base64
import json
import os
import time

import anthropic
import requests
from django.conf import settings
from django.core.management.base import BaseCommand

from utils.llm_costs import LLMCostTracker

FIXTURE_DIR = os.path.join(os.path.dirname(__file__), "../../fixtures")
FIXTURE_PATH = os.path.join(FIXTURE_DIR, "popular_feeds.json")
CACHE_PATH = os.path.join(FIXTURE_DIR, "subreddit_cache.json")

REDDIT_DELAY = 0.7
REDDIT_RATE_LIMIT_WAIT = 10
REDDIT_MAX_RETRIES = 3

CLAUDE_MODEL = "claude-haiku-4-5"
CATEGORIZE_BATCH_SIZE = 100

# Expanded taxonomy (47 categories) - shared base from discover_real_feeds.py
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
    "true crime": [
        "Cold Cases", "Court Cases", "Criminal Psychology", "Disappearances",
        "Forensics", "Investigations", "Murder Mystery", "Serial Killers",
        "True Crime Documentary", "White Collar Crime",
    ],
}

# Search keywords mapped to taxonomy categories for filling niche categories
SEARCH_KEYWORDS = {
    "technology": ["technology", "programming", "software", "cybersecurity", "linux", "machinelearning", "webdev", "devops"],
    "science": ["science", "physics", "biology", "chemistry", "neuroscience"],
    "gaming": ["gaming", "pcgaming", "nintendo", "playstation", "xbox", "indiegaming"],
    "education": ["education", "college", "teaching", "homeschool", "learnprogramming"],
    "entertainment": ["movies", "television", "comics", "marvelstudios", "startrek"],
    "news & politics": ["news", "politics", "worldnews", "geopolitics", "journalism"],
    "sports": ["sports", "nba", "soccer", "nfl", "baseball", "hockey", "tennis", "golf", "mma", "cycling"],
    "music": ["music", "hiphopheads", "indieheads", "jazz", "classicalmusic", "guitar", "edmproduction"],
    "comedy & humor": ["funny", "memes", "jokes", "standupcomedy"],
    "business": ["business", "marketing", "smallbusiness"],
    "food & cooking": ["cooking", "food", "recipes", "baking", "mealprep", "vegan", "coffee"],
    "travel": ["travel", "solotravel", "backpacking", "digitalnomad", "roadtrip"],
    "diy & crafts": ["diy", "woodworking", "crochet", "knitting", "sewing", "3dprinting", "crafts"],
    "photography": ["photography", "photocritique", "astrophotography", "streetphotography"],
    "automotive": ["cars", "motorcycles", "tesla", "bmw", "toyota", "trucks", "electricvehicles"],
    "finance": ["personalfinance", "investing", "stocks", "financialindependence"],
    "design": ["design", "graphic_design", "UI_Design", "InteriorDesign", "web_design"],
    "environment & sustainability": ["environment", "sustainability", "zerowaste", "renewable"],
    "health & fitness": ["fitness", "health", "nutrition", "running", "weightlifting"],
    "lifestyle": ["minimalism", "simpleliving"],
    "pets & animals": ["cats", "dogs", "aww", "aquariums", "reptiles", "birds", "rabbits"],
    "arts & culture": ["art", "painting", "drawing", "sculpture", "museum", "theater"],
    "home & garden": ["homeimprovement", "gardening", "houseplants", "lawncare", "landscaping"],
    "history": ["history", "archaeology", "ancienthistory", "militaryhistory"],
    "psychology & mental health": ["mentalhealth", "anxiety", "adhd", "psychology", "depression"],
    "books & reading": ["books", "booksuggestions", "literature", "fantasy", "scifi"],
    "anime & manga": ["anime", "manga", "onepiece", "naruto", "cosplay"],
    "architecture": ["architecture", "urbanplanning"],
    "law & legal": ["legaladvice", "law", "lawyers"],
    "real estate": ["realestate", "homebuying", "landlord"],
    "space & astronomy": ["space", "spacex", "nasa", "astronomy", "astrophotography"],
    "cryptocurrency & web3": ["cryptocurrency", "bitcoin", "ethereum", "defi"],
    "data science & analytics": ["datascience", "machinelearning", "statistics", "bigdata"],
    "internet culture & social media": ["askreddit", "showerthoughts", "mildlyinteresting"],
    "parenting": ["parenting", "daddit", "mommit"],
    "fashion & beauty": ["fashion", "streetwear", "skincare", "makeupaddiction"],
    "military & defense": ["military", "veterans", "navy", "airforce"],
    "economics": ["economics", "economy"],
    "religion & spirituality": ["religion", "spirituality", "meditation", "buddhism"],
    "philosophy": ["philosophy", "stoicism", "ethics"],
    "entrepreneurship & startups": ["startups", "SaaS", "venturecapital", "entrepreneur"],
    "weather & climate": ["weather", "climate", "tornado", "meteorology"],
    "career & job market": ["careerguidance", "jobs", "antiwork", "resumes", "remotework"],
    "wellness & self-care": ["yoga", "selfcare", "meditation"],
    "productivity & organization": ["productivity", "selfimprovement", "getdisciplined"],
    "hobbies & collections": ["boardgames", "lego", "coins", "vinyl", "modelbuilding"],
    "relationships & dating": ["relationships", "dating", "tinder", "marriage"],
    "true crime": ["truecrime", "unresolvedmysteries", "serialkillers", "coldcase"],
}


class Command(BaseCommand):
    help = "Discover real Reddit subreddits from the Reddit API"

    def add_arguments(self, parser):
        parser.add_argument("--dry-run", action="store_true", help="Preview without writing")
        parser.add_argument("--verbose", action="store_true", help="Detailed output")
        parser.add_argument("--resume", action="store_true", help="Resume from subreddit_cache.json")
        parser.add_argument("--skip-categorize", action="store_true", help="Skip Claude categorization")
        parser.add_argument(
            "--min-subscribers",
            type=int,
            default=5000,
            help="Minimum subscriber count (default: 5000)",
        )

    def handle(self, *args, **options):
        self.verbose = options["verbose"]
        self.dry_run = options["dry_run"]
        self.min_subscribers = options["min_subscribers"]

        all_subreddits = {}  # keyed by display_name (lowercase)

        # Load cache for resume support
        cache = self._load_cache() if options["resume"] else {"feeds": {}, "completed": []}
        if options["resume"] and cache["feeds"]:
            all_subreddits.update(cache["feeds"])
            self.stdout.write(f"Resumed with {len(all_subreddits)} cached subreddits")

        # Authenticate with Reddit OAuth2
        access_token = self._get_access_token()
        if not access_token:
            self.stderr.write(self.style.ERROR("Failed to authenticate with Reddit API"))
            return

        # Phase 1: Popular subreddits via /subreddits/popular
        popular = self._discover_popular(access_token, cache)
        self.stdout.write(self.style.SUCCESS(f"Popular: discovered {len(popular)} subreddits"))
        all_subreddits.update(popular)
        cache["feeds"] = all_subreddits
        self._save_cache(cache)

        # Phase 2: Search by taxonomy keywords
        search_results = self._discover_by_search(access_token, cache, all_subreddits)
        self.stdout.write(self.style.SUCCESS(f"Search: discovered {len(search_results)} additional subreddits"))
        all_subreddits.update(search_results)
        cache["feeds"] = all_subreddits
        self._save_cache(cache)

        self.stdout.write(f"\nTotal unique subreddits: {len(all_subreddits)}")

        # Phase 3: Categorize uncategorized feeds with Claude
        if not options["skip_categorize"]:
            all_subreddits = self._categorize_feeds(all_subreddits)

        # Phase 4: Convert to fixture format and write
        subreddits_list = self._to_fixture_format(all_subreddits)

        if self.dry_run:
            self.stdout.write(self.style.WARNING("\nDry run - not writing fixture file"))
            self._print_summary(subreddits_list)
            return

        self._write_fixture(subreddits_list)
        self._print_summary(subreddits_list)

    def _load_cache(self):
        cache_path = os.path.normpath(CACHE_PATH)
        if os.path.exists(cache_path):
            with open(cache_path, "r") as f:
                return json.load(f)
        return {"feeds": {}, "completed": []}

    def _save_cache(self, cache):
        cache_path = os.path.normpath(CACHE_PATH)
        with open(cache_path, "w") as f:
            json.dump(cache, f)

    def _get_access_token(self):
        """Get Reddit OAuth2 app-only access token."""
        client_id = getattr(settings, "REDDIT_CLIENT_ID", None)
        client_secret = getattr(settings, "REDDIT_CLIENT_SECRET", None)

        if not client_id or not client_secret:
            self.stderr.write(self.style.ERROR("REDDIT_CLIENT_ID / REDDIT_CLIENT_SECRET not configured"))
            return None

        auth = base64.b64encode(f"{client_id}:{client_secret}".encode()).decode()
        try:
            resp = requests.post(
                "https://www.reddit.com/api/v1/access_token",
                headers={
                    "Authorization": f"Basic {auth}",
                    "User-Agent": "NewsBlur/1.0 (subreddit discovery)",
                },
                data={"grant_type": "client_credentials"},
                timeout=10,
            )
            if resp.status_code == 200:
                token = resp.json().get("access_token")
                if token:
                    self.stdout.write("Authenticated with Reddit OAuth2")
                    return token
            self.stderr.write(self.style.ERROR(f"Reddit auth failed: HTTP {resp.status_code}"))
        except requests.RequestException as e:
            self.stderr.write(self.style.ERROR(f"Reddit auth error: {e}"))
        return None

    def _reddit_get(self, url, params, access_token):
        """Make an authenticated GET request to Reddit's OAuth API with retry."""
        headers = {
            "Authorization": f"Bearer {access_token}",
            "User-Agent": "NewsBlur/1.0 (subreddit discovery)",
        }
        for attempt in range(REDDIT_MAX_RETRIES):
            try:
                resp = requests.get(url, params=params, headers=headers, timeout=15)
                if resp.status_code == 200:
                    return resp.json()
                if resp.status_code == 429:
                    wait = REDDIT_RATE_LIMIT_WAIT * (attempt + 1)
                    self.stdout.write(self.style.WARNING(f"    Rate limited, waiting {wait}s..."))
                    time.sleep(wait)
                    continue
                if self.verbose:
                    self.stdout.write(self.style.WARNING(f"    HTTP {resp.status_code}"))
                return None
            except requests.RequestException as e:
                if self.verbose:
                    self.stdout.write(self.style.WARNING(f"    Request error: {e}"))
                if attempt < REDDIT_MAX_RETRIES - 1:
                    time.sleep(REDDIT_DELAY * 2)
        return None

    def _parse_subreddit(self, data):
        """Parse a subreddit data dict from the Reddit API into our feed format."""
        display_name = data.get("display_name", "")
        if not display_name:
            return None

        # Filter NSFW and quarantined
        if data.get("over18") or data.get("quarantine"):
            return None

        subscribers = data.get("subscribers") or 0
        if subscribers < self.min_subscribers:
            return None

        # Get icon - try community_icon first, then icon_img
        icon_url = data.get("community_icon", "")
        if icon_url:
            icon_url = icon_url.split("?")[0]
        if not icon_url:
            icon_url = data.get("icon_img", "")

        description = (data.get("public_description") or "")[:200]

        return {
            "feed_url": f"https://www.reddit.com/r/{display_name}/.rss",
            "title": f"r/{display_name}",
            "description": description,
            "subscriber_count": subscribers,
            "thumbnail_url": icon_url,
            "platform": "",
            "category": "",
            "subcategory": "",
            "source": "reddit_api",
        }

    def _discover_popular(self, access_token, cache):
        """Paginate through /subreddits/popular to get top subreddits."""
        feeds = {}
        completed = set(cache.get("completed", []))

        if "popular:done" in completed:
            if self.verbose:
                self.stdout.write("  Skipping popular (cached)")
            return feeds

        after = None
        page = 0
        while True:
            page += 1
            cache_key = f"popular:page:{page}"
            if cache_key in completed:
                # We still need to advance the `after` cursor
                # but skip processing. Use cached after token if available.
                after = cache.get(f"after:{page}")
                if not after:
                    break
                continue

            params = {"limit": 100}
            if after:
                params["after"] = after

            if page % 5 == 1:
                self.stdout.write(f"  [page {page}] Fetching popular subreddits... ({len(feeds)} found)")

            data = self._reddit_get("https://oauth.reddit.com/subreddits/popular", params, access_token)
            if not data:
                break

            children = data.get("data", {}).get("children", [])
            if not children:
                break

            new_count = 0
            for child in children:
                sub_data = child.get("data", {})
                feed = self._parse_subreddit(sub_data)
                if feed:
                    key = sub_data["display_name"].lower()
                    if key not in feeds:
                        feeds[key] = feed
                        new_count += 1

            after = data.get("data", {}).get("after")
            completed.add(cache_key)
            cache[f"after:{page}"] = after

            if self.verbose:
                self.stdout.write(f"    page {page}: +{new_count} new ({len(children)} results)")

            if not after:
                break

            time.sleep(REDDIT_DELAY)

        completed.add("popular:done")
        cache["completed"] = list(completed)
        self._save_cache(cache)
        return feeds

    def _discover_by_search(self, access_token, cache, existing):
        """Search by taxonomy keywords to fill niche categories."""
        feeds = {}
        completed = set(cache.get("completed", []))
        existing_names = set(existing.keys())

        all_keywords = []
        for category, keywords in SEARCH_KEYWORDS.items():
            for kw in keywords:
                all_keywords.append((category, kw))

        total = len(all_keywords)
        for idx, (category, keyword) in enumerate(all_keywords, 1):
            cache_key = f"search:{keyword}"
            if cache_key in completed:
                continue

            if idx % 10 == 1 or idx == 1:
                self.stdout.write(f"  [{idx}/{total}] Searching: {keyword} ({len(feeds)} new so far)")

            data = self._reddit_get(
                "https://oauth.reddit.com/subreddits/search",
                {"q": keyword, "limit": 25, "include_over_18": "false", "sort": "relevance", "t": "all"},
                access_token,
            )

            if data:
                new_count = 0
                for child in data.get("data", {}).get("children", []):
                    sub_data = child.get("data", {})
                    feed = self._parse_subreddit(sub_data)
                    if feed:
                        key = sub_data["display_name"].lower()
                        if key not in existing_names and key not in feeds:
                            # Pre-assign category hint from search keyword
                            feed["category"] = category
                            feeds[key] = feed
                            new_count += 1

                if self.verbose and new_count > 0:
                    self.stdout.write(f"    +{new_count} new from '{keyword}'")

            completed.add(cache_key)
            time.sleep(REDDIT_DELAY)

            # Periodic cache save
            if idx % 20 == 0:
                cache["feeds"].update(feeds)
                cache["completed"] = list(completed)
                self._save_cache(cache)

        cache["completed"] = list(completed)
        self._save_cache(cache)
        return feeds

    # -- Claude Categorization --

    def _categorize_feeds(self, all_feeds):
        """Use Claude to categorize feeds that don't have categories."""
        api_key = getattr(settings, "ANTHROPIC_API_KEY", None)
        if not api_key:
            self.stderr.write(self.style.ERROR("ANTHROPIC_API_KEY not configured, skipping categorization"))
            return all_feeds

        client = anthropic.Anthropic(api_key=api_key)

        uncategorized = [key for key, feed in all_feeds.items() if not feed.get("category")]
        if not uncategorized:
            self.stdout.write("All subreddits already have categories")
            return all_feeds

        self.stdout.write(f"Categorizing {len(uncategorized)} subreddits with Claude...")

        category_list = "\n".join(f"- {cat}: {', '.join(subs)}" for cat, subs in sorted(TAXONOMY.items()))

        for i in range(0, len(uncategorized), CATEGORIZE_BATCH_SIZE):
            batch_keys = uncategorized[i : i + CATEGORIZE_BATCH_SIZE]
            batch_feeds = [
                {
                    "feed_url": all_feeds[key]["feed_url"],
                    "title": all_feeds[key].get("title", ""),
                    "description": all_feeds[key].get("description", ""),
                }
                for key in batch_keys
            ]

            batch_num = i // CATEGORIZE_BATCH_SIZE + 1
            total_batches = (len(uncategorized) + CATEGORIZE_BATCH_SIZE - 1) // CATEGORIZE_BATCH_SIZE
            self.stdout.write(f"  Batch {batch_num}/{total_batches} ({len(batch_feeds)} subreddits)...")

            categorized = self._categorize_batch(client, batch_feeds, category_list)
            if categorized:
                # Build lookup by feed_url for matching
                feeds_by_url = {all_feeds[key]["feed_url"]: key for key in batch_keys}
                for item in categorized:
                    url = item.get("feed_url", "")
                    if url in feeds_by_url:
                        key = feeds_by_url[url]
                        all_feeds[key]["category"] = item.get("category", "")
                        all_feeds[key]["subcategory"] = item.get("subcategory", "")

        return all_feeds

    def _categorize_batch(self, client, feeds, category_list):
        """Categorize a batch of feeds using Claude."""
        feeds_json = json.dumps(feeds, indent=1)

        prompt = f"""Categorize each subreddit into the best matching category and subcategory.

Available categories and subcategories:
{category_list}

Subreddits to categorize:
{feeds_json}

For each feed, return the feed_url, best category (lowercase), and best subcategory."""

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
                feature="discover_subreddits_categorize",
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
        for key, feed in all_feeds.items():
            category = feed.get("category", "").lower()
            if not category:
                continue

            feeds_list.append(
                {
                    "feed_type": "reddit",
                    "category": category,
                    "subcategory": feed.get("subcategory", ""),
                    "title": feed.get("title", ""),
                    "description": feed.get("description", ""),
                    "feed_url": feed.get("feed_url", ""),
                    "subscriber_count": feed.get("subscriber_count", 0),
                    "platform": feed.get("platform", ""),
                    "thumbnail_url": feed.get("thumbnail_url", ""),
                }
            )

        feeds_list.sort(key=lambda f: (f["category"], f["subcategory"], -f["subscriber_count"]))
        return feeds_list

    def _write_fixture(self, new_subreddits):
        """Write to fixture file, replacing existing reddit entries."""
        fixture_path = os.path.normpath(FIXTURE_PATH)

        existing_feeds = []
        if os.path.exists(fixture_path):
            with open(fixture_path, "r") as f:
                existing_feeds = json.load(f)

        # Keep everything except reddit feeds
        non_reddit = [f for f in existing_feeds if f["feed_type"] != "reddit"]
        all_feeds = non_reddit + new_subreddits

        with open(fixture_path, "w") as f:
            json.dump(all_feeds, f, indent=2)

        self.stdout.write(
            self.style.SUCCESS(
                f"\nWrote {len(new_subreddits)} subreddits + {len(non_reddit)} other feeds = "
                f"{len(all_feeds)} total to {fixture_path}"
            )
        )

    def _print_summary(self, feeds):
        """Print summary of discovered subreddits."""
        from collections import Counter

        self.stdout.write("\n--- Subreddit Discovery Summary ---")
        self.stdout.write(f"\n{len(feeds)} subreddits total")

        cat_counts = Counter(f["category"] for f in feeds)
        self.stdout.write(f"\nAcross {len(cat_counts)} categories:")
        for cat, count in cat_counts.most_common():
            self.stdout.write(f"  {cat}: {count}")

        subs = [f["subscriber_count"] for f in feeds if f["subscriber_count"] > 0]
        if subs:
            self.stdout.write(
                f"\nSubscriber counts: min={min(subs):,}, max={max(subs):,}, "
                f"median={sorted(subs)[len(subs) // 2]:,}, "
                f"feeds with counts={len(subs)}/{len(feeds)}"
            )

        thumbs = sum(1 for f in feeds if f.get("thumbnail_url"))
        self.stdout.write(f"Feeds with thumbnails: {thumbs}/{len(feeds)}")
