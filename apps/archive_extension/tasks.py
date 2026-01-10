"""
Celery tasks for the Archive Extension.

These tasks handle async processing of archived pages, including:
- AI categorization (hybrid approach: prefers existing categories, creates new when needed)
- Elasticsearch indexing
- Batch processing
"""

import redis
from celery import shared_task
from django.conf import settings
from django.contrib.auth.models import User

from utils import json_functions as json
from utils import log as logging


def _publish_category_update(user_id, archive_id, categories):
    """
    Publish category update event via Redis PubSub for real-time WebSocket updates.

    Args:
        user_id: The user ID
        archive_id: The archive ID that was categorized
        categories: List of categories assigned to the archive
    """
    try:
        user = User.objects.get(pk=user_id)
        r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
        payload = json.encode({
            "type": "categories",
            "archive_id": str(archive_id),
            "categories": categories
        })
        r.publish(user.username, f"archive:{payload}")
    except Exception as e:
        logging.error(f"Error publishing category update event: {e}")


@shared_task(name="archive-categorize")
def categorize_archives(user_id, archive_ids=None, limit=100):
    """
    Run AI categorization on uncategorized archives.

    Uses a hybrid approach: prefers user's existing categories when relevant,
    creates new categories when nothing fits.

    Args:
        user_id: User ID to process archives for
        archive_ids: Optional list of specific archive IDs to categorize
        limit: Max number of archives to process (default 100)
    """
    from datetime import datetime

    from apps.archive_extension.models import MArchivedStory

    logging.info(f"Starting archive categorization for user {user_id}")

    # Get uncategorized archives
    query = {
        "user_id": user_id,
        "deleted": False,
        "ai_categorized_date": None,
        "content_z__ne": None,  # Only categorize if we have content
    }

    if archive_ids:
        query["id__in"] = archive_ids

    archives = MArchivedStory.objects(**query).limit(limit)
    archives_list = list(archives)

    if not archives_list:
        logging.info(f"No uncategorized archives found for user {user_id}")
        return {"processed": 0}

    # Get user's existing categories once for the batch
    user_categories = _get_user_categories(user_id)

    processed = 0
    for archive in archives_list:
        try:
            categories = _categorize_single_archive(archive, user_categories)
            archive.ai_categories = categories
            archive.ai_categorized_date = datetime.now()
            archive.save()
            processed += 1

            # Publish real-time update for category addition
            if categories:
                _publish_category_update(user_id, archive.id, categories)

            # Track new categories for subsequent items in this batch
            for cat in categories:
                if cat not in user_categories:
                    user_categories.append(cat)

        except Exception as e:
            logging.error(f"Error categorizing archive {archive.id}: {e}")

    logging.info(f"Categorized {processed} archives for user {user_id}")
    return {"processed": processed}


@shared_task(name="archive-bulk-categorize")
def bulk_categorize_archives(user_id, limit=100):
    """
    Bulk categorize all uncategorized archives for a user.

    This is the main entry point for triggering categorization from the UI.
    Uses batching to be cost-efficient with Haiku.

    Args:
        user_id: User ID to process
        limit: Max archives to process in this run
    """
    from datetime import datetime

    from apps.archive_extension.models import MArchivedStory

    logging.info(f"Starting bulk categorization for user {user_id}, limit={limit}")

    # Get user's existing categories once
    user_categories = _get_user_categories(user_id)

    # Get uncategorized archives
    archives = MArchivedStory.objects(
        user_id=user_id, deleted=False, ai_categorized_date=None, content_z__ne=None
    ).limit(limit)

    processed = 0
    for archive in archives:
        try:
            categories = _categorize_single_archive(archive, user_categories)
            archive.ai_categories = categories
            archive.ai_categorized_date = datetime.now()
            archive.save()

            # Update Elasticsearch index
            _index_archive(archive)

            # Publish real-time update for category addition
            if categories:
                _publish_category_update(user_id, archive.id, categories)

            processed += 1

            # Track new categories for subsequent items
            for cat in categories:
                if cat not in user_categories:
                    user_categories.append(cat)

        except Exception as e:
            logging.error(f"Error categorizing archive {archive.id}: {e}")

    logging.info(f"Bulk categorized {processed} archives for user {user_id}")
    return {"processed": processed, "user_id": user_id}


def _get_user_categories(user_id):
    """
    Get list of user's existing categories sorted by usage count.

    Returns top 50 categories to keep the prompt manageable.
    """
    from apps.archive_extension.models import MArchivedStory

    breakdown = MArchivedStory.get_category_breakdown(user_id)
    return [item["_id"] for item in breakdown[:50]]


def _categorize_single_archive(archive, user_categories=None):
    """
    Use AI to categorize a single archive using hybrid approach.

    1. Checks user's existing categories first
    2. Picks from existing when there's a close match
    3. Creates new categories when nothing fits

    Args:
        archive: MArchivedStory to categorize
        user_categories: Optional list of user's existing categories

    Returns:
        List of category strings (1-3 categories)
    """
    content = archive.get_content()
    if not content:
        return []

    # Truncate content if too long
    max_content_length = 4000
    if len(content) > max_content_length:
        content = content[:max_content_length] + "..."

    # Get user's existing categories if not provided
    if user_categories is None:
        user_categories = _get_user_categories(archive.user_id)

    try:
        import anthropic
        from django.conf import settings

        api_key = getattr(settings, "ANTHROPIC_API_KEY", None)
        if not api_key:
            logging.warning("ANTHROPIC_API_KEY not configured, falling back to domain-based categorization")
            return _fallback_categorize(archive)

        client = anthropic.Anthropic(api_key=api_key)

        prompt = _build_categorization_prompt(
            title=archive.title, domain=archive.domain, content=content, existing_categories=user_categories
        )

        response = client.messages.create(
            model="claude-3-5-haiku-20241022",
            max_tokens=100,
            messages=[{"role": "user", "content": prompt}],
        )

        result = response.content[0].text.strip()
        return _parse_category_response(result)

    except Exception as e:
        logging.error(f"AI categorization failed: {e}")
        return _fallback_categorize(archive)


def _build_categorization_prompt(title, domain, content, existing_categories):
    """
    Build the categorization prompt with hybrid approach.

    If user has existing categories, instructs AI to reuse them only when accurate.
    Otherwise, allows AI to create appropriate categories.
    """
    if existing_categories:
        existing_list = ", ".join(existing_categories[:30])
        return f"""Analyze this web page and assign 1-3 accurate categories.

YOUR EXISTING CATEGORIES:
{existing_list}

INSTRUCTIONS:
1. Accuracy is paramount. Categories must precisely describe the content.
2. Reuse an existing category ONLY if it's a strong, accurate match.
3. DO NOT stretch categories to fit - create a new one if nothing matches well.
4. Geographic categories (e.g., "Middle East reporting") should ONLY apply to content actually about that region.
5. Categories should be specific but not too narrow (2-4 words).

Page Details:
Title: {title}
Domain: {domain}
Content (truncated):
{content}

Return ONLY a comma-separated list of 1-3 categories. Example responses:
- "Latin America, Politics" (accurate geographic + topic)
- "US Energy Policy" (specific new category)
- "Technology, Machine Learning" (reusing when accurate)

Categories:"""
    else:
        return f"""Analyze this web page and assign 1-3 concise categories (2-4 words each).

Categories should be descriptive and useful for organizing browsing history.

Page Details:
Title: {title}
Domain: {domain}
Content (truncated):
{content}

Return ONLY a comma-separated list of categories. Example: "Technology, Programming" or "Recipe, Cooking"

Categories:"""


def _parse_category_response(response):
    """
    Parse AI response, ensuring clean category names.

    Handles various response formats and cleans up the output.
    """
    # Strip any reasoning/explanation text that might follow
    if "\n" in response:
        response = response.split("\n")[0]
    if "Reasoning:" in response:
        response = response.split("Reasoning:")[0]

    categories = [c.strip() for c in response.split(",")]

    cleaned = []
    for cat in categories:
        # Remove quotes and extra whitespace
        cat = cat.strip('"\'').strip()
        # Skip categories with line breaks or explanations
        if "\n" in cat:
            cat = cat.split("\n")[0].strip()
        # Limit length
        if len(cat) > 64:
            cat = cat[:64]
        # Skip empty or very short categories
        if cat and len(cat) >= 2:
            cleaned.append(cat)

    return cleaned[:3]  # Max 3 categories


def _fallback_categorize(archive):
    """
    Simple rule-based fallback categorization based on domain.
    Used when AI categorization fails.
    """
    domain = (archive.domain or "").lower()

    # News sites
    if any(
        news in domain
        for news in [
            "nytimes",
            "washingtonpost",
            "cnn",
            "bbc",
            "reuters",
            "apnews",
            "theguardian",
            "news",
        ]
    ):
        return ["News"]

    # Shopping sites
    if any(shop in domain for shop in ["amazon", "ebay", "walmart", "target", "bestbuy", "shop", "store"]):
        return ["Shopping"]

    # Tech sites
    if any(
        tech in domain
        for tech in ["github", "stackoverflow", "techcrunch", "verge", "arstechnica", "hackernews"]
    ):
        return ["Technology"]

    # Social sites
    if any(social in domain for social in ["twitter", "facebook", "instagram", "reddit", "linkedin"]):
        return ["Social"]

    # Video/Entertainment
    if any(ent in domain for ent in ["youtube", "netflix", "twitch", "spotify", "imdb"]):
        return ["Entertainment"]

    # Finance
    if any(fin in domain for fin in ["bloomberg", "wsj", "marketwatch", "yahoo.com/finance"]):
        return ["Finance"]

    return []


@shared_task(name="archive-index-elasticsearch")
def index_archive_for_search(archive_id):
    """
    Index a single archive in Elasticsearch for full-text search.

    Args:
        archive_id: ID of the MArchivedStory to index
    """
    from apps.archive_extension.models import MArchivedStory

    try:
        archive = MArchivedStory.objects.get(id=archive_id)
    except MArchivedStory.DoesNotExist:
        logging.warning(f"Archive {archive_id} not found for indexing")
        return

    if archive.deleted:
        # Remove from index if deleted
        _remove_from_index(archive)
        return

    _index_archive(archive)


def _index_archive(archive):
    """
    Index an archive in Elasticsearch.
    """
    from apps.archive_extension.search import SearchArchive

    try:
        SearchArchive.index_archive(archive)
        logging.debug(f"Indexed archive {archive.id} in Elasticsearch")

    except Exception as e:
        logging.error(f"Failed to index archive {archive.id}: {e}")


def _remove_from_index(archive):
    """
    Remove an archive from Elasticsearch index.
    """
    from apps.archive_extension.search import SearchArchive

    try:
        SearchArchive.remove(str(archive.id))
        logging.debug(f"Removed archive {archive.id} from Elasticsearch")
    except Exception as e:
        logging.error(f"Failed to remove archive {archive.id} from index: {e}")


@shared_task(name="archive-process-batch")
def process_archive_batch(user_id, archive_ids):
    """
    Process a batch of archives for a user.

    This task runs categorization and indexing for a batch of archives.

    Args:
        user_id: User ID
        archive_ids: List of archive IDs to process
    """
    logging.info(f"Processing batch of {len(archive_ids)} archives for user {user_id}")

    # Categorize
    categorize_archives(user_id, archive_ids=archive_ids)

    # Index each archive
    for archive_id in archive_ids:
        index_archive_for_search(archive_id)

    logging.info(f"Batch processing complete for user {user_id}")
    return {"processed": len(archive_ids)}


@shared_task(name="archive-cleanup-old")
def cleanup_old_archives(days_old=365, batch_size=1000):
    """
    Cleanup task for permanently deleting old soft-deleted archives.

    Runs periodically to remove archives that have been soft-deleted
    for more than `days_old` days.

    Args:
        days_old: Number of days after soft-delete to permanently remove
        batch_size: Max number of archives to delete per run
    """
    from datetime import datetime, timedelta

    from apps.archive_extension.models import MArchivedStory

    cutoff_date = datetime.now() - timedelta(days=days_old)

    # Find old soft-deleted archives
    old_archives = MArchivedStory.objects(deleted=True, deleted_date__lt=cutoff_date).limit(batch_size)

    count = 0
    for archive in old_archives:
        try:
            # Remove from search index first
            _remove_from_index(archive)
            # Then delete from MongoDB
            archive.delete()
            count += 1
        except Exception as e:
            logging.error(f"Error permanently deleting archive {archive.id}: {e}")

    logging.info(f"Permanently deleted {count} old soft-deleted archives")
    return {"deleted": count}
