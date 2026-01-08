"""
Celery tasks for the Archive Extension.

These tasks handle async processing of archived pages, including:
- AI categorization
- Elasticsearch indexing
- Batch processing
"""

from celery import shared_task

from utils import log as logging


@shared_task(name="archive-categorize")
def categorize_archives(user_id, archive_ids=None, limit=100):
    """
    Run AI categorization on uncategorized archives.

    This task uses Claude to analyze archive content and assign categories
    like 'Research', 'Shopping', 'News', 'Entertainment', etc.

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

    processed = 0
    for archive in archives_list:
        try:
            categories = _categorize_single_archive(archive)
            archive.ai_categories = categories
            archive.ai_categorized_date = datetime.now()
            archive.save()
            processed += 1
        except Exception as e:
            logging.error(f"Error categorizing archive {archive.id}: {e}")

    logging.info(f"Categorized {processed} archives for user {user_id}")
    return {"processed": processed}


def _categorize_single_archive(archive):
    """
    Use AI to categorize a single archive.

    Returns list of category strings.
    """
    # Get content
    content = archive.get_content()
    if not content:
        return []

    # Truncate content if too long
    max_content_length = 4000
    if len(content) > max_content_length:
        content = content[:max_content_length] + "..."

    # Define available categories
    categories = [
        "News",
        "Research",
        "Shopping",
        "Entertainment",
        "Technology",
        "Finance",
        "Health",
        "Travel",
        "Food",
        "Sports",
        "Education",
        "Work",
        "Social",
        "Reference",
    ]

    try:
        import anthropic

        client = anthropic.Anthropic()

        prompt = f"""Analyze this web page content and assign 1-3 relevant categories from this list:
{', '.join(categories)}

Title: {archive.title}
Domain: {archive.domain}
Content (truncated):
{content}

Return ONLY a comma-separated list of categories, nothing else. Example: "News, Technology" or "Shopping"
"""

        response = client.messages.create(
            model="claude-3-5-haiku-20241022",
            max_tokens=50,
            messages=[{"role": "user", "content": prompt}],
        )

        # Parse response
        result = response.content[0].text.strip()
        assigned = [c.strip() for c in result.split(",")]

        # Filter to only valid categories
        valid = [c for c in assigned if c in categories]

        return valid[:3]  # Max 3 categories

    except Exception as e:
        logging.error(f"AI categorization failed: {e}")
        # Fallback to domain-based categorization
        return _fallback_categorize(archive)


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
    from apps.search.models import SearchStory

    try:
        # Create document for indexing
        doc = {
            "id": str(archive.id),
            "user_id": archive.user_id,
            "title": archive.title or "",
            "content": archive.get_content() or "",
            "url": archive.url,
            "domain": archive.domain,
            "categories": archive.ai_categories or [],
            "archived_date": archive.archived_date,
            "matched_story_hash": archive.matched_story_hash,
        }

        # Use NewsBlur's search indexing
        SearchStory.index_archive(doc)

        logging.debug(f"Indexed archive {archive.id} in Elasticsearch")

    except Exception as e:
        logging.error(f"Failed to index archive {archive.id}: {e}")


def _remove_from_index(archive):
    """
    Remove an archive from Elasticsearch index.
    """
    from apps.search.models import SearchStory

    try:
        SearchStory.remove_archive(str(archive.id))
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
