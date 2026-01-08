import hashlib
import zlib
from datetime import datetime

import mongoengine as mongo

from utils import log as logging


class MArchivedStory(mongo.Document):
    """
    Stores archived web pages from the browser extension.
    Collection: archived_stories on analytics MongoDB (MONGO_ANALYTICS_DB)

    This is the core data model for the Archive Extension feature, which
    automatically captures pages users browse and makes them searchable
    via the Archive Assistant AI feature.
    """

    user_id = mongo.IntField(required=True)

    # Page metadata
    url = mongo.StringField(required=True, max_length=2048)
    url_hash = mongo.StringField(required=True)  # SHA256 of normalized URL for dedup
    title = mongo.StringField(max_length=1024)
    favicon_url = mongo.StringField(max_length=2048)
    domain = mongo.StringField(max_length=255)

    # Content (compressed with zlib)
    content_z = mongo.BinaryField()  # zlib-compressed extracted text
    content_length = mongo.IntField(default=0)  # Original uncompressed length for comparison

    # Timestamps
    archived_date = mongo.DateTimeField(default=datetime.now)
    first_visited = mongo.DateTimeField()
    last_visited = mongo.DateTimeField()
    visit_count = mongo.IntField(default=1)
    time_on_page_seconds = mongo.IntField(default=0)

    # Story matching - links to existing NewsBlur stories if URL matches
    matched_story_hash = mongo.StringField()  # Format: "feed_id:hash" if matched
    matched_feed_id = mongo.IntField()
    content_source = mongo.StringField(choices=["extension", "newsblur", "hybrid"], default="extension")

    # AI-generated categorization
    ai_categories = mongo.ListField(mongo.StringField(max_length=64))  # e.g., ['Research', 'Shopping']
    ai_categorized_date = mongo.DateTimeField()

    # Extension metadata
    extension_version = mongo.StringField(max_length=32)
    browser = mongo.StringField(max_length=32, choices=["chrome", "firefox", "edge", "safari"])

    # Soft delete support
    deleted = mongo.BooleanField(default=False)
    deleted_date = mongo.DateTimeField()

    meta = {
        "collection": "archived_stories",
        "indexes": [
            {"fields": ["user_id", "-archived_date"]},
            {"fields": ["user_id", "url_hash"], "unique": True},
            {"fields": ["user_id", "domain"]},
            {"fields": ["user_id", "ai_categories"]},
            {"fields": ["user_id", "matched_feed_id"]},
            {"fields": ["user_id", "deleted", "-archived_date"]},
        ],
        "db_alias": "nbanalytics",
        "allow_inheritance": False,
        "ordering": ["-archived_date"],
    }

    def __str__(self):
        return f"Archive: {self.title or self.url} ({self.user_id})"

    @classmethod
    def hash_url(cls, url):
        """Generate SHA256 hash of normalized URL for deduplication."""
        normalized = cls.normalize_url(url)
        return hashlib.sha256(normalized.encode("utf-8")).hexdigest()[:32]

    @classmethod
    def normalize_url(cls, url):
        """
        Normalize URL by:
        - Lowercasing scheme and host
        - Removing common tracking parameters (utm_*, fbclid, etc.)
        - Removing trailing slashes
        - Sorting query parameters
        """
        from urllib.parse import parse_qs, urlencode, urlparse, urlunparse

        parsed = urlparse(url.strip())

        # Lowercase scheme and netloc
        scheme = parsed.scheme.lower()
        netloc = parsed.netloc.lower()

        # Remove www. prefix for consistency
        if netloc.startswith("www."):
            netloc = netloc[4:]

        # Remove tracking parameters
        tracking_params = {
            "utm_source",
            "utm_medium",
            "utm_campaign",
            "utm_term",
            "utm_content",
            "utm_id",
            "fbclid",
            "gclid",
            "gclsrc",
            "dclid",
            "msclkid",
            "ref",
            "source",
            "_ga",
            "_gl",
            "mc_cid",
            "mc_eid",
        }

        query_params = parse_qs(parsed.query, keep_blank_values=True)
        filtered_params = {k: v for k, v in query_params.items() if k.lower() not in tracking_params}

        # Sort and rebuild query string
        sorted_query = urlencode(sorted(filtered_params.items()), doseq=True)

        # Remove trailing slash from path
        path = parsed.path.rstrip("/") or "/"

        return urlunparse((scheme, netloc, path, parsed.params, sorted_query, ""))

    @classmethod
    def extract_domain(cls, url):
        """Extract domain from URL."""
        from urllib.parse import urlparse

        parsed = urlparse(url)
        domain = parsed.netloc.lower()
        if domain.startswith("www."):
            domain = domain[4:]
        return domain

    def set_content(self, content):
        """Compress and store content."""
        if content:
            self.content_z = zlib.compress(content.encode("utf-8"))
            self.content_length = len(content)
        else:
            self.content_z = None
            self.content_length = 0

    def get_content(self):
        """Decompress and return content."""
        if self.content_z:
            try:
                return zlib.decompress(self.content_z).decode("utf-8")
            except Exception as e:
                logging.error(f"Failed to decompress archive content: {e}")
                return ""
        return ""

    @classmethod
    def archive_page(
        cls,
        user_id,
        url,
        title,
        content=None,
        favicon_url=None,
        time_on_page=0,
        browser=None,
        extension_version=None,
        matched_story_hash=None,
        matched_feed_id=None,
        content_source="extension",
    ):
        """
        Archive a page, handling deduplication and updates.

        Returns tuple: (archive, created, updated)
        - archive: The MArchivedStory instance
        - created: True if new archive was created
        - updated: True if existing archive was updated
        """
        url_hash = cls.hash_url(url)
        domain = cls.extract_domain(url)
        now = datetime.now()

        # Try to find existing archive for this URL
        try:
            existing = cls.objects.get(user_id=user_id, url_hash=url_hash)

            # Update existing archive
            existing.last_visited = now
            existing.visit_count += 1
            existing.time_on_page_seconds += time_on_page

            # Update title if we have a better one
            if title and (not existing.title or len(title) > len(existing.title)):
                existing.title = title

            # Update content if new content is longer
            if content and len(content) > (existing.content_length or 0):
                existing.set_content(content)
                existing.content_source = content_source

            # Update matching info if provided
            if matched_story_hash:
                existing.matched_story_hash = matched_story_hash
                existing.matched_feed_id = matched_feed_id

            # Undelete if was deleted
            if existing.deleted:
                existing.deleted = False
                existing.deleted_date = None

            existing.save()
            return existing, False, True

        except cls.DoesNotExist:
            # Create new archive
            archive = cls(
                user_id=user_id,
                url=url,
                url_hash=url_hash,
                title=title,
                domain=domain,
                favicon_url=favicon_url,
                first_visited=now,
                last_visited=now,
                archived_date=now,
                visit_count=1,
                time_on_page_seconds=time_on_page,
                browser=browser,
                extension_version=extension_version,
                matched_story_hash=matched_story_hash,
                matched_feed_id=matched_feed_id,
                content_source=content_source,
            )

            if content:
                archive.set_content(content)

            archive.save()
            return archive, True, False

    @classmethod
    def get_user_archives(
        cls, user_id, limit=50, offset=0, domain=None, category=None, include_deleted=False
    ):
        """Get paginated archives for a user with optional filters."""
        query = {"user_id": user_id}

        if not include_deleted:
            query["deleted"] = False

        if domain:
            query["domain"] = domain

        if category:
            query["ai_categories"] = category

        return cls.objects(**query).skip(offset).limit(limit)

    @classmethod
    def get_category_breakdown(cls, user_id):
        """Get count of archives by AI category for a user."""
        pipeline = [
            {"$match": {"user_id": user_id, "deleted": False}},
            {"$unwind": "$ai_categories"},
            {"$group": {"_id": "$ai_categories", "count": {"$sum": 1}}},
            {"$sort": {"count": -1}},
        ]
        return list(cls.objects.aggregate(pipeline))

    @classmethod
    def get_domain_breakdown(cls, user_id, limit=20):
        """Get count of archives by domain for a user."""
        pipeline = [
            {"$match": {"user_id": user_id, "deleted": False}},
            {"$group": {"_id": "$domain", "count": {"$sum": 1}, "last_visit": {"$max": "$last_visited"}}},
            {"$sort": {"count": -1}},
            {"$limit": limit},
        ]
        return list(cls.objects.aggregate(pipeline))

    def soft_delete(self):
        """Mark archive as deleted without removing from database."""
        self.deleted = True
        self.deleted_date = datetime.now()
        self.save()


class MArchiveUserSettings(mongo.Document):
    """
    User-specific settings for the Archive Extension.
    Stores blocklist customizations and preferences.
    """

    user_id = mongo.IntField(required=True, unique=True)

    # Custom blocklist additions (domains or patterns)
    blocked_domains = mongo.ListField(mongo.StringField(max_length=255))
    blocked_patterns = mongo.ListField(mongo.StringField(max_length=255))  # Regex patterns

    # Domains user has explicitly allowed (overrides default blocklist)
    allowed_domains = mongo.ListField(mongo.StringField(max_length=255))

    # Preferences
    auto_archive_enabled = mongo.BooleanField(default=True)
    archive_read_stories = mongo.BooleanField(default=True)  # Archive stories from NewsBlur feeds too

    # Stats
    total_archived = mongo.IntField(default=0)
    last_archive_date = mongo.DateTimeField()

    meta = {
        "collection": "archive_user_settings",
        "indexes": [
            {"fields": ["user_id"], "unique": True},
        ],
        "db_alias": "nbanalytics",
    }

    @classmethod
    def get_or_create(cls, user_id):
        """Get or create settings for a user."""
        try:
            return cls.objects.get(user_id=user_id)
        except cls.DoesNotExist:
            settings = cls(user_id=user_id)
            settings.save()
            return settings
