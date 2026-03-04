"""
Management command to discover real podcasts from the iTunes Search API.
Replaces AI-generated podcast entries with verified, real podcasts.

Data Sources:
1. iTunes Search API genre-by-genre keyword search (~3,000+ results)
2. iTunes Search API taxonomy keyword search (~2,000+ additional)

No API key required - iTunes Search API is free and unauthenticated.

Usage:
    python manage.py discover_podcasts
    python manage.py discover_podcasts --resume
    python manage.py discover_podcasts --dry-run --verbose
    python manage.py discover_podcasts --min-episodes 5
"""

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
CACHE_PATH = os.path.join(FIXTURE_DIR, "podcast_cache.json")

ITUNES_DELAY = 5.0
ITUNES_RATE_LIMIT_WAIT = 60
ITUNES_MAX_RETRIES = 5
ITUNES_SEARCH_LIMIT = 200

CLAUDE_MODEL = "claude-haiku-4-5"
CATEGORIZE_BATCH_SIZE = 100

# Apple Podcasts genre IDs
ITUNES_GENRES = {
    "Arts": 1301,
    "Business": 1321,
    "Comedy": 1303,
    "Education": 1304,
    "Fiction": 1483,
    "Government": 1511,
    "Health & Fitness": 1512,
    "History": 1487,
    "Kids & Family": 1305,
    "Leisure": 1502,
    "Music": 1310,
    "News": 1489,
    "Religion & Spirituality": 1314,
    "Science": 1533,
    "Society & Culture": 1324,
    "Sports": 1545,
    "Technology": 1318,
    "True Crime": 1488,
    "TV & Film": 1309,
}

# The canonical taxonomy (same as discover_subreddits.py)
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
    "true crime": [
        "Cold Cases",
        "Court Cases",
        "Criminal Psychology",
        "Disappearances",
        "Forensics",
        "Investigations",
        "Murder Mystery",
        "Serial Killers",
        "True Crime Documentary",
        "White Collar Crime",
    ],
}

# Mapping from iTunes genre to our taxonomy category for initial hint
ITUNES_GENRE_TO_CATEGORY = {
    "Arts": "arts & culture",
    "Books": "books & reading",
    "Design": "design",
    "Fashion & Beauty": "fashion & beauty",
    "Food": "food & cooking",
    "Performing Arts": "arts & culture",
    "Visual Arts": "arts & culture",
    "Business": "business",
    "Careers": "business",
    "Entrepreneurship": "entrepreneurship & startups",
    "Investing": "finance",
    "Management": "business",
    "Marketing": "business",
    "Non-Profit": "business",
    "Comedy": "comedy & humor",
    "Comedy Interviews": "comedy & humor",
    "Improv": "comedy & humor",
    "Stand-Up": "comedy & humor",
    "Education": "education",
    "Courses": "education",
    "How To": "education",
    "Language Learning": "education",
    "Self-Improvement": "lifestyle",
    "Fiction": "entertainment",
    "Comedy Fiction": "comedy & humor",
    "Drama": "entertainment",
    "Science Fiction": "entertainment",
    "Government": "news & politics",
    "Health & Fitness": "health & fitness",
    "Alternative Health": "health & fitness",
    "Fitness": "health & fitness",
    "Medicine": "health & fitness",
    "Mental Health": "health & fitness",
    "Nutrition": "health & fitness",
    "Sexuality": "health & fitness",
    "History": "history",
    "Kids & Family": "parenting",
    "Education for Kids": "education",
    "Parenting": "parenting",
    "Pets & Animals": "lifestyle",
    "Stories for Kids": "parenting",
    "Leisure": "lifestyle",
    "Animation & Manga": "entertainment",
    "Automotive": "lifestyle",
    "Aviation": "lifestyle",
    "Crafts": "lifestyle",
    "Games": "gaming",
    "Hobbies": "lifestyle",
    "Home & Garden": "lifestyle",
    "Video Games": "gaming",
    "Music": "music",
    "Music Commentary": "music",
    "Music History": "music",
    "Music Interviews": "music",
    "News": "news & politics",
    "Business News": "business",
    "Daily News": "news & politics",
    "Entertainment News": "entertainment",
    "News Commentary": "news & politics",
    "Politics": "news & politics",
    "Sports News": "sports",
    "Tech News": "technology",
    "Religion & Spirituality": "religion & spirituality",
    "Buddhism": "religion & spirituality",
    "Christianity": "religion & spirituality",
    "Hinduism": "religion & spirituality",
    "Islam": "religion & spirituality",
    "Judaism": "religion & spirituality",
    "Religion": "religion & spirituality",
    "Spirituality": "religion & spirituality",
    "Science": "science",
    "Astronomy": "science",
    "Chemistry": "science",
    "Earth Sciences": "science",
    "Life Sciences": "science",
    "Mathematics": "science",
    "Natural Sciences": "science",
    "Nature": "environment & sustainability",
    "Physics": "science",
    "Social Sciences": "science",
    "Society & Culture": "lifestyle",
    "Documentary": "entertainment",
    "Personal Journals": "lifestyle",
    "Philosophy": "philosophy",
    "Places & Travel": "travel",
    "Relationships": "lifestyle",
    "Sports": "sports",
    "Baseball": "sports",
    "Basketball": "sports",
    "Cricket": "sports",
    "Fantasy Sports": "sports",
    "Football": "sports",
    "Golf": "sports",
    "Hockey": "sports",
    "Rugby": "sports",
    "Running": "health & fitness",
    "Soccer": "sports",
    "Swimming": "sports",
    "Tennis": "sports",
    "Volleyball": "sports",
    "Wilderness": "travel",
    "Wrestling": "sports",
    "Technology": "technology",
    "True Crime": "true crime",
    "TV & Film": "entertainment",
    "After Shows": "entertainment",
    "Film History": "entertainment",
    "Film Interviews": "entertainment",
    "Film Reviews": "entertainment",
    "TV Reviews": "entertainment",
}

# Search keywords for each genre - used in Phase 1
GENRE_SEARCH_TERMS = {
    "Arts": [
        "art", "painting", "creative writing", "poetry", "sculpture",
        "literature", "theater", "dance", "photography art", "illustration",
        "ceramics", "calligraphy", "printmaking", "textile art", "mixed media",
    ],
    "Business": [
        "business", "startup", "entrepreneur", "marketing", "management",
        "leadership", "career", "workplace", "corporate", "consulting",
        "sales", "strategy", "branding", "ecommerce", "freelance",
    ],
    "Comedy": [
        "comedy", "funny", "humor", "stand up", "improv",
        "comedian", "jokes", "satire", "roast", "sketch comedy",
        "comedy podcast", "panel show", "comedians talking", "funny stories",
    ],
    "Education": [
        "education", "learning", "teaching", "school", "university",
        "course", "lecture", "tutorial", "study", "academic",
        "language learning", "vocabulary", "online education", "homeschool",
    ],
    "Fiction": [
        "fiction podcast", "audio drama", "storytelling", "horror fiction",
        "sci-fi audio", "mystery fiction", "fantasy audio", "thriller podcast",
        "audio fiction", "narrative podcast", "serial fiction",
    ],
    "Government": [
        "government", "policy", "public affairs", "civic", "democracy",
        "legislation", "congress", "parliament", "political analysis",
    ],
    "Health & Fitness": [
        "health", "fitness", "workout", "nutrition", "mental health",
        "yoga", "meditation", "wellness", "medicine", "therapy",
        "mindfulness", "diet", "exercise", "self care", "sleep",
        "anxiety", "depression", "psychology", "counseling",
    ],
    "History": [
        "history", "ancient", "medieval", "world war", "civil war",
        "historical", "archaeology", "civilization", "empire", "revolution",
        "cold war", "renaissance", "military history", "american history",
        "british history", "ancient rome", "ancient egypt",
    ],
    "Kids & Family": [
        "kids", "children", "family", "parenting", "bedtime stories",
        "toddler", "baby", "mom", "dad", "pregnancy",
        "family podcast", "children stories", "kids education",
    ],
    "Leisure": [
        "hobbies", "crafts", "gardening", "cooking hobby", "DIY",
        "automotive", "aviation", "board games", "card games", "puzzles",
        "knitting", "woodworking", "home improvement", "pets",
    ],
    "Music": [
        "music", "album review", "hip hop", "rock", "jazz",
        "classical music", "indie music", "electronic music", "country music",
        "pop music", "songwriting", "music production", "music history",
        "music theory", "vinyl", "concert", "music industry",
    ],
    "News": [
        "news", "daily news", "politics", "world news", "current events",
        "breaking news", "journalism", "investigative", "analysis",
        "geopolitics", "foreign policy", "election", "media",
        "international news", "local news", "news commentary",
    ],
    "Religion & Spirituality": [
        "religion", "spirituality", "faith", "bible", "church",
        "christian", "buddhism", "islam", "meditation spiritual",
        "prayer", "theology", "sermon", "devotional", "scripture",
    ],
    "Science": [
        "science", "physics", "biology", "chemistry", "astronomy",
        "space", "neuroscience", "evolution", "genetics", "climate",
        "ecology", "geology", "paleontology", "quantum", "research",
        "scientific", "nature science", "marine biology",
    ],
    "Society & Culture": [
        "society", "culture", "philosophy", "relationships", "dating",
        "social issues", "identity", "race", "gender", "equality",
        "anthropology", "sociology", "community", "urban", "rural",
        "documentary podcast", "personal journal", "memoir",
    ],
    "Sports": [
        "sports", "football", "basketball", "baseball", "soccer",
        "hockey", "tennis", "golf", "MMA", "boxing",
        "wrestling", "cricket", "rugby", "cycling", "running",
        "Olympics", "fantasy sports", "sports analysis", "NFL", "NBA",
        "MLB", "Premier League", "Champions League", "Formula 1",
    ],
    "Technology": [
        "technology", "tech", "programming", "software", "AI",
        "cybersecurity", "data science", "machine learning", "startup tech",
        "gadgets", "apps", "cloud computing", "blockchain", "crypto",
        "web development", "coding", "developer", "silicon valley",
        "open source", "linux", "apple", "android", "robotics",
    ],
    "True Crime": [
        "true crime", "murder", "mystery", "serial killer", "cold case",
        "investigation", "forensic", "crime", "criminal", "detective",
        "unsolved", "disappeared", "court case", "trial", "prison",
        "heist", "fraud", "kidnapping", "crime documentary",
    ],
    "TV & Film": [
        "movies", "film", "television", "TV show", "cinema",
        "movie review", "film review", "TV recap", "streaming",
        "netflix", "HBO", "disney", "marvel", "star wars",
        "anime", "horror movies", "documentary film",
    ],
}

# Phase 2: Additional keyword searches to fill niche categories
SEARCH_KEYWORDS = {
    "technology": [
        "artificial intelligence", "machine learning podcast", "data science",
        "python programming", "javascript", "DevOps", "cloud AWS",
        "cybersecurity podcast", "hacking security", "startup tech",
        "product management tech", "UX design", "web3 development",
        "robotics AI", "quantum computing", "internet of things",
    ],
    "science": [
        "astrophysics", "molecular biology", "organic chemistry",
        "climate science", "oceanography", "environmental science",
        "neuroscience brain", "psychology research", "medical research",
        "space exploration NASA", "paleontology fossils", "genetics DNA",
    ],
    "gaming": [
        "video games", "gaming podcast", "Nintendo", "PlayStation",
        "Xbox", "PC gaming", "indie games", "esports",
        "Dungeons Dragons", "tabletop RPG", "board game review",
        "retro gaming", "game development", "Twitch streaming",
    ],
    "education": [
        "online learning", "higher education", "STEM education",
        "teacher podcast", "academic podcast", "university lecture",
        "educational psychology", "special education", "literacy",
    ],
    "entertainment": [
        "pop culture", "celebrity gossip", "reality TV recap",
        "comic book podcast", "anime discussion", "fandom",
        "award show recap", "streaming review", "entertainment news",
    ],
    "news & politics": [
        "political podcast", "election coverage", "foreign affairs",
        "economic policy", "supreme court", "congress podcast",
        "fact check", "media criticism", "global affairs",
        "immigration policy", "climate policy", "defense policy",
    ],
    "sports": [
        "fantasy football", "NBA basketball", "MLB baseball",
        "Premier League soccer", "UFC MMA", "boxing podcast",
        "Formula 1 racing", "Olympic sports", "college football",
        "sports betting", "triathlon", "marathon running",
    ],
    "music": [
        "music podcast", "album review podcast", "hip hop podcast",
        "rock music podcast", "jazz podcast", "classical music podcast",
        "music production podcast", "songwriter interview",
        "music industry business", "concert review",
    ],
    "comedy & humor": [
        "comedy podcast", "stand up comedian", "improv comedy",
        "funny podcast", "comedy interview", "humor podcast",
    ],
    "business": [
        "business podcast", "MBA", "venture capital",
        "real estate investing", "stock market", "supply chain",
        "small business", "remote work", "negotiation",
        "business strategy", "mergers acquisitions",
    ],
    "food & cooking": [
        "cooking podcast", "food podcast", "recipe", "baking",
        "restaurant review", "wine tasting", "craft beer",
        "vegan cooking", "food science", "chef interview",
        "barbecue", "fermentation", "food history",
    ],
    "travel": [
        "travel podcast", "backpacking", "road trip",
        "adventure travel", "budget travel", "digital nomad",
        "travel tips", "expat life", "solo travel",
    ],
    "finance": [
        "personal finance", "investing podcast", "stock market podcast",
        "real estate investing", "retirement planning", "budgeting",
        "financial independence", "FIRE movement", "cryptocurrency investing",
        "tax planning", "wealth management",
    ],
    "design": [
        "design podcast", "UX design podcast", "graphic design",
        "interior design podcast", "architecture design",
        "industrial design", "typography", "creative direction",
    ],
    "environment & sustainability": [
        "climate change podcast", "sustainability podcast",
        "renewable energy", "conservation", "zero waste",
        "environmental podcast", "green living", "ecology",
    ],
    "health & fitness": [
        "workout podcast", "bodybuilding", "crossfit",
        "marathon training", "physical therapy", "nutrition podcast",
        "mental health podcast", "therapy podcast", "anxiety podcast",
        "sleep science", "longevity", "biohacking",
    ],
    "lifestyle": [
        "minimalism podcast", "productivity podcast", "self improvement",
        "motivation podcast", "habit building", "organization",
        "decluttering", "simple living", "personal development",
    ],
    "arts & culture": [
        "art podcast", "museum podcast", "theater podcast",
        "cultural criticism", "contemporary art", "art history podcast",
        "dance podcast", "performing arts", "visual arts podcast",
    ],
    "history": [
        "history podcast", "ancient history podcast", "World War II",
        "American Civil War", "Roman Empire", "medieval history podcast",
        "military history podcast", "historical biography",
        "archaeology podcast", "historical mystery",
    ],
    "books & reading": [
        "book podcast", "book review podcast", "author interview",
        "fiction book club", "nonfiction book", "literary podcast",
        "audiobook discussion", "reading recommendation", "publishing",
    ],
    "cryptocurrency & web3": [
        "bitcoin podcast", "ethereum podcast", "crypto podcast",
        "blockchain podcast", "DeFi podcast", "NFT podcast",
        "web3 podcast", "crypto trading", "crypto news",
    ],
    "parenting": [
        "parenting podcast", "mom podcast", "dad podcast",
        "pregnancy podcast", "toddler", "homeschooling podcast",
        "teen parenting", "new parent", "family life",
    ],
    "fashion & beauty": [
        "fashion podcast", "beauty podcast", "skincare podcast",
        "makeup podcast", "style podcast", "sustainable fashion",
        "hair care", "fashion industry", "beauty trends",
    ],
    "religion & spirituality": [
        "bible study podcast", "sermon podcast", "christian podcast",
        "buddhist meditation", "islamic podcast", "jewish podcast",
        "spiritual growth", "devotional podcast", "faith podcast",
    ],
    "philosophy": [
        "philosophy podcast", "stoicism podcast", "ethics podcast",
        "existentialism", "political philosophy", "moral philosophy",
        "philosophical discussion", "thought experiment",
    ],
    "entrepreneurship & startups": [
        "startup podcast", "founder story", "SaaS podcast",
        "venture capital podcast", "bootstrapped", "product hunt",
        "indie hacker", "startup fundraising", "growth hacking",
    ],
    "true crime": [
        "true crime podcast", "cold case podcast", "murder mystery podcast",
        "investigation podcast", "forensic files", "crime documentary",
        "unsolved mystery", "crime junkie", "court case podcast",
    ],
}


class Command(BaseCommand):
    help = "Discover real podcasts from the iTunes Search API"

    def add_arguments(self, parser):
        parser.add_argument("--dry-run", action="store_true", help="Preview without writing")
        parser.add_argument("--verbose", action="store_true", help="Detailed output")
        parser.add_argument("--resume", action="store_true", help="Resume from podcast_cache.json")
        parser.add_argument("--skip-categorize", action="store_true", help="Skip Claude categorization")
        parser.add_argument(
            "--min-episodes",
            type=int,
            default=5,
            help="Minimum episode count (default: 5)",
        )

    def handle(self, *args, **options):
        self.verbose = options["verbose"]
        self.dry_run = options["dry_run"]
        self.min_episodes = options["min_episodes"]
        self._current_delay = ITUNES_DELAY

        all_podcasts = {}  # keyed by feed_url

        # Load cache for resume support
        cache = self._load_cache() if options["resume"] else {"feeds": {}, "completed": []}
        if options["resume"] and cache["feeds"]:
            all_podcasts.update(cache["feeds"])
            self.stdout.write(f"Resumed with {len(all_podcasts)} cached podcasts")

        # Phase 1: Genre-specific keyword searches via iTunes
        genre_results = self._discover_by_genre(cache, all_podcasts)
        self.stdout.write(self.style.SUCCESS(f"Phase 1 (genre): discovered {len(genre_results)} podcasts"))
        all_podcasts.update(genre_results)
        cache["feeds"] = all_podcasts
        self._save_cache(cache)

        # Phase 2: Taxonomy keyword searches
        keyword_results = self._discover_by_keywords(cache, all_podcasts)
        self.stdout.write(
            self.style.SUCCESS(f"Phase 2 (keywords): discovered {len(keyword_results)} additional podcasts")
        )
        all_podcasts.update(keyword_results)
        cache["feeds"] = all_podcasts
        self._save_cache(cache)

        self.stdout.write(f"\nTotal unique podcasts: {len(all_podcasts)}")

        # Phase 3: Categorize uncategorized feeds with Claude
        if not options["skip_categorize"]:
            all_podcasts = self._categorize_feeds(all_podcasts)

        # Phase 4: Convert to fixture format and write
        podcasts_list = self._to_fixture_format(all_podcasts)

        if self.dry_run:
            self.stdout.write(self.style.WARNING("\nDry run - not writing fixture file"))
            self._print_summary(podcasts_list)
            return

        self._write_fixture(podcasts_list)
        self._print_summary(podcasts_list)

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

    def _itunes_search(self, term, genre_id=None, offset=0):
        """Make a search request to the iTunes Search API with retry and adaptive backoff."""
        params = {
            "term": term,
            "media": "podcast",
            "entity": "podcast",
            "limit": ITUNES_SEARCH_LIMIT,
        }
        if genre_id:
            params["genreId"] = genre_id
        if offset:
            params["offset"] = offset

        headers = {"User-Agent": "NewsBlur/1.0 (RSS Reader; https://newsblur.com)"}

        for attempt in range(ITUNES_MAX_RETRIES):
            try:
                resp = requests.get(
                    "https://itunes.apple.com/search",
                    params=params,
                    headers=headers,
                    timeout=15,
                )
                if resp.status_code == 200:
                    # Successful request, reduce backoff
                    self._current_delay = max(ITUNES_DELAY, self._current_delay * 0.9)
                    return resp.json()
                if resp.status_code == 403 or resp.status_code == 429:
                    # Adaptive backoff: increase delay for future requests
                    self._current_delay = min(30, self._current_delay * 1.5)
                    wait = ITUNES_RATE_LIMIT_WAIT + (attempt * 30)
                    self.stdout.write(
                        self.style.WARNING(
                            f"    Rate limited, waiting {wait}s (delay now {self._current_delay:.1f}s)..."
                        )
                    )
                    time.sleep(wait)
                    continue
                if self.verbose:
                    self.stdout.write(self.style.WARNING(f"    HTTP {resp.status_code}"))
                return None
            except requests.RequestException as e:
                if self.verbose:
                    self.stdout.write(self.style.WARNING(f"    Request error: {e}"))
                if attempt < ITUNES_MAX_RETRIES - 1:
                    time.sleep(self._current_delay * 2)
        return None

    def _parse_podcast(self, podcast_data):
        """Parse an iTunes API podcast result into our feed format."""
        feed_url = podcast_data.get("feedUrl")
        if not feed_url:
            return None

        collection_name = podcast_data.get("collectionName", "")
        if not collection_name:
            return None

        track_count = podcast_data.get("trackCount", 0) or 0
        if track_count < self.min_episodes:
            return None

        # Get the primary genre for initial category hint
        primary_genre = podcast_data.get("primaryGenreName", "")
        category_hint = ITUNES_GENRE_TO_CATEGORY.get(primary_genre, "")

        # Get artwork URL - prefer larger
        artwork = (
            podcast_data.get("artworkUrl600")
            or podcast_data.get("artworkUrl100")
            or podcast_data.get("artworkUrl60", "")
        )

        artist = podcast_data.get("artistName", "")
        description = (podcast_data.get("description") or "")[:200]
        if not description:
            # Build a description from genre and artist
            parts = []
            if artist:
                parts.append(f"by {artist}")
            if primary_genre:
                parts.append(f"({primary_genre})")
            description = " ".join(parts)

        return {
            "feed_url": feed_url,
            "title": collection_name,
            "description": description,
            "subscriber_count": track_count,  # Use track_count as proxy
            "thumbnail_url": artwork,
            "platform": "",
            "category": category_hint,
            "subcategory": "",
            "artist": artist,
            "genre": primary_genre,
            "source": "itunes_api",
        }

    def _discover_by_genre(self, cache, existing):
        """Phase 1: Search iTunes by genre with multiple keywords per genre."""
        feeds = {}
        completed = set(cache.get("completed", []))
        existing_urls = set(existing.keys())

        total_searches = sum(len(terms) for terms in GENRE_SEARCH_TERMS.values())
        search_idx = 0

        for genre_name, genre_id in ITUNES_GENRES.items():
            terms = GENRE_SEARCH_TERMS.get(genre_name, [genre_name.lower()])

            for term in terms:
                search_idx += 1
                cache_key = f"genre:{genre_name}:{term}"
                if cache_key in completed:
                    continue

                if search_idx % 5 == 1 or search_idx == 1:
                    self.stdout.write(
                        f"  [{search_idx}/{total_searches}] {genre_name}: '{term}' "
                        f"({len(feeds)} new, {len(feeds) + len(existing_urls)} total)"
                    )

                data = self._itunes_search(term, genre_id=genre_id)
                if data:
                    new_count = 0
                    for result in data.get("results", []):
                        podcast = self._parse_podcast(result)
                        if podcast:
                            url_key = podcast["feed_url"]
                            if url_key not in existing_urls and url_key not in feeds:
                                feeds[url_key] = podcast
                                new_count += 1

                    if self.verbose and new_count > 0:
                        self.stdout.write(
                            f"    +{new_count} new from '{term}' in {genre_name} "
                            f"({data.get('resultCount', 0)} results)"
                        )

                completed.add(cache_key)
                time.sleep(self._current_delay)

                # Periodic cache save
                if search_idx % 20 == 0:
                    cache["feeds"].update(feeds)
                    cache["completed"] = list(completed)
                    self._save_cache(cache)

        cache["completed"] = list(completed)
        self._save_cache(cache)
        return feeds

    def _discover_by_keywords(self, cache, existing):
        """Phase 2: Search by taxonomy keywords to fill niche categories."""
        feeds = {}
        completed = set(cache.get("completed", []))
        existing_urls = set(existing.keys())

        all_keywords = []
        for category, keywords in SEARCH_KEYWORDS.items():
            for kw in keywords:
                all_keywords.append((category, kw))

        total = len(all_keywords)
        for idx, (category, keyword) in enumerate(all_keywords, 1):
            cache_key = f"keyword:{keyword}"
            if cache_key in completed:
                continue

            if idx % 10 == 1 or idx == 1:
                self.stdout.write(
                    f"  [{idx}/{total}] Searching: '{keyword}' ({len(feeds)} new so far)"
                )

            data = self._itunes_search(keyword)
            if data:
                new_count = 0
                for result in data.get("results", []):
                    podcast = self._parse_podcast(result)
                    if podcast:
                        url_key = podcast["feed_url"]
                        if url_key not in existing_urls and url_key not in feeds:
                            # Use the taxonomy category as hint
                            if not podcast["category"]:
                                podcast["category"] = category
                            feeds[url_key] = podcast
                            new_count += 1

                if self.verbose and new_count > 0:
                    self.stdout.write(f"    +{new_count} new from '{keyword}'")

            completed.add(cache_key)
            time.sleep(ITUNES_DELAY)

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
            self.stdout.write("All podcasts already have categories")
            return all_feeds

        self.stdout.write(f"Categorizing {len(uncategorized)} podcasts with Claude...")

        category_list = "\n".join(f"- {cat}: {', '.join(subs)}" for cat, subs in sorted(TAXONOMY.items()))

        for i in range(0, len(uncategorized), CATEGORIZE_BATCH_SIZE):
            batch_keys = uncategorized[i : i + CATEGORIZE_BATCH_SIZE]
            batch_feeds = [
                {
                    "feed_url": all_feeds[key]["feed_url"],
                    "title": all_feeds[key].get("title", ""),
                    "description": all_feeds[key].get("description", ""),
                    "artist": all_feeds[key].get("artist", ""),
                    "genre": all_feeds[key].get("genre", ""),
                }
                for key in batch_keys
            ]

            batch_num = i // CATEGORIZE_BATCH_SIZE + 1
            total_batches = (len(uncategorized) + CATEGORIZE_BATCH_SIZE - 1) // CATEGORIZE_BATCH_SIZE
            self.stdout.write(f"  Batch {batch_num}/{total_batches} ({len(batch_feeds)} podcasts)...")

            categorized = self._categorize_batch(client, batch_feeds, category_list)
            if categorized:
                feeds_by_url = {all_feeds[key]["feed_url"]: key for key in batch_keys}
                for item in categorized:
                    url = item.get("feed_url", "")
                    if url in feeds_by_url:
                        key = feeds_by_url[url]
                        all_feeds[key]["category"] = item.get("category", "")
                        all_feeds[key]["subcategory"] = item.get("subcategory", "")

        # Also assign subcategories to feeds that have a category but no subcategory
        needs_subcategory = [
            key
            for key, feed in all_feeds.items()
            if feed.get("category") and not feed.get("subcategory")
        ]
        if needs_subcategory:
            self.stdout.write(f"Assigning subcategories to {len(needs_subcategory)} podcasts...")
            for i in range(0, len(needs_subcategory), CATEGORIZE_BATCH_SIZE):
                batch_keys = needs_subcategory[i : i + CATEGORIZE_BATCH_SIZE]
                batch_feeds = [
                    {
                        "feed_url": all_feeds[key]["feed_url"],
                        "title": all_feeds[key].get("title", ""),
                        "description": all_feeds[key].get("description", ""),
                        "artist": all_feeds[key].get("artist", ""),
                        "genre": all_feeds[key].get("genre", ""),
                        "category": all_feeds[key].get("category", ""),
                    }
                    for key in batch_keys
                ]

                batch_num = i // CATEGORIZE_BATCH_SIZE + 1
                total_batches = (len(needs_subcategory) + CATEGORIZE_BATCH_SIZE - 1) // CATEGORIZE_BATCH_SIZE
                self.stdout.write(
                    f"  Subcategory batch {batch_num}/{total_batches} ({len(batch_feeds)} podcasts)..."
                )

                categorized = self._categorize_batch(client, batch_feeds, category_list)
                if categorized:
                    feeds_by_url = {all_feeds[key]["feed_url"]: key for key in batch_keys}
                    for item in categorized:
                        url = item.get("feed_url", "")
                        if url in feeds_by_url:
                            key = feeds_by_url[url]
                            all_feeds[key]["category"] = item.get("category", all_feeds[key]["category"])
                            all_feeds[key]["subcategory"] = item.get("subcategory", "")

        return all_feeds

    def _categorize_batch(self, client, feeds, category_list):
        """Categorize a batch of feeds using Claude."""
        feeds_json = json.dumps(feeds, indent=1)

        prompt = f"""Categorize each podcast into the best matching category and subcategory.

Available categories and subcategories:
{category_list}

Podcasts to categorize:
{feeds_json}

For each feed, return the feed_url, best category (lowercase), and best subcategory.
Use the podcast title, description, artist, and genre to make the best categorization.
If a podcast's existing category seems wrong based on its content, correct it."""

        tool_definition = {
            "name": "save_categorized_feeds",
            "description": "Save the categorized podcasts",
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
                feature="discover_podcasts_categorize",
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
                    "feed_type": "podcast",
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

    def _write_fixture(self, new_podcasts):
        """Write to fixture file, replacing existing podcast entries."""
        fixture_path = os.path.normpath(FIXTURE_PATH)

        existing_feeds = []
        if os.path.exists(fixture_path):
            with open(fixture_path, "r") as f:
                existing_feeds = json.load(f)

        # Keep everything except podcast feeds
        non_podcast = [f for f in existing_feeds if f["feed_type"] != "podcast"]
        all_feeds = non_podcast + new_podcasts

        with open(fixture_path, "w") as f:
            json.dump(all_feeds, f, indent=2)

        self.stdout.write(
            self.style.SUCCESS(
                f"\nWrote {len(new_podcasts)} podcasts + {len(non_podcast)} other feeds = "
                f"{len(all_feeds)} total to {fixture_path}"
            )
        )

    def _print_summary(self, feeds):
        """Print summary of discovered podcasts."""
        from collections import Counter

        self.stdout.write("\n--- Podcast Discovery Summary ---")
        self.stdout.write(f"\n{len(feeds)} podcasts total")

        cat_counts = Counter(f["category"] for f in feeds)
        self.stdout.write(f"\nAcross {len(cat_counts)} categories:")
        for cat, count in cat_counts.most_common():
            self.stdout.write(f"  {cat}: {count}")

        episodes = [f["subscriber_count"] for f in feeds if f["subscriber_count"] > 0]
        if episodes:
            self.stdout.write(
                f"\nEpisode counts: min={min(episodes):,}, max={max(episodes):,}, "
                f"median={sorted(episodes)[len(episodes) // 2]:,}, "
                f"feeds with counts={len(episodes)}/{len(feeds)}"
            )

        thumbs = sum(1 for f in feeds if f.get("thumbnail_url"))
        self.stdout.write(f"Feeds with thumbnails: {thumbs}/{len(feeds)}")
