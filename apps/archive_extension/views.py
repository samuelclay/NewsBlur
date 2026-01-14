"""
API endpoints for the Archive Extension.

All endpoints require authentication via OAuth token with 'archive' scope.
These endpoints are called by the browser extension to ingest and manage
archived pages.
"""

import json
from datetime import datetime

import redis
from django.conf import settings
from django.http import HttpResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods

from apps.archive_extension.blocklist import get_blocked_domains, get_blocked_patterns, is_blocked
from apps.archive_extension.matching import match_and_process
from apps.archive_extension.models import MArchivedStory, MArchiveUserSettings
from apps.archive_extension.tasks import categorize_archives, index_archive_for_search
from apps.archive_extension.utils import format_datetime_utc
from utils import json_functions as json
from utils import log as logging
from utils.user_functions import ajax_login_required, get_user


def _publish_archive_event(user, archives_data, event_type="new"):
    """
    Publish archive events via Redis PubSub for real-time WebSocket updates.

    Args:
        user: The user object
        archives_data: List of archive data dicts to include in the event
        event_type: Type of event ("new" or "deleted")
    """
    try:
        r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
        payload = json.encode({"type": event_type, "archives": archives_data, "count": len(archives_data)})
        r.publish(user.username, f"archive:{payload}")
    except Exception as e:
        logging.error(f"Error publishing archive event: {e}")


def _check_archive_access(user):
    """
    Check if user has access to the Archive Extension feature.
    Returns (has_access, error_message).

    All authenticated users can ingest content. Premium Archive is only
    required for querying via Archive Assistant (checked separately).
    """
    if not user.is_authenticated:
        return False, "Authentication required"

    return True, None


def _json_response(data, status=200):
    """Return a JSON response."""
    return HttpResponse(
        json.encode(data),
        content_type="application/json",
        status=status,
    )


def _error_response(message, code=-1, status=400):
    """Return a JSON error response."""
    return _json_response({"code": code, "message": message}, status=status)


@csrf_exempt
@ajax_login_required
@require_http_methods(["POST"])
def ingest(request):
    """
    Ingest a single archived page from the browser extension.

    POST params:
        url (required): Page URL
        title (required): Page title
        content: Extracted text content
        favicon_url: Favicon URL
        time_on_page: Seconds spent on page
        browser: Browser identifier (chrome, firefox, edge, safari)
        extension_version: Extension version string

    Returns:
        {
            code: 0 for success,
            archive_id: str,
            matched: bool,
            matched_story_hash: str or null,
            content_stored: bool,
            created: bool,
            updated: bool
        }
    """
    user = get_user(request)
    has_access, error = _check_archive_access(user)
    if not has_access:
        return _error_response(error, status=403)

    # Parse params
    url = request.POST.get("url", "").strip()
    title = request.POST.get("title", "").strip()
    content = request.POST.get("content", "")
    favicon_url = request.POST.get("favicon_url", "")
    author = request.POST.get("author", "").strip() or None
    time_on_page = int(request.POST.get("time_on_page", 0))
    browser = request.POST.get("browser", "") or None
    extension_version = request.POST.get("extension_version", "") or None

    if not url:
        return _error_response("URL is required")
    if not title:
        return _error_response("Title is required")

    # Check blocklist
    user_settings = MArchiveUserSettings.get_or_create(user.pk)
    if is_blocked(url, user_settings):
        return _json_response(
            {
                "code": 1,
                "message": "URL is blocked",
                "blocked": True,
            }
        )

    try:
        result = match_and_process(
            user=user,
            url=url,
            title=title,
            content=content,
            content_length=len(content) if content else 0,
            favicon_url=favicon_url,
            author=author,
            time_on_page=time_on_page,
            browser=browser,
            extension_version=extension_version,
        )

        # Update user stats
        if result["created"]:
            user_settings.total_archived = (user_settings.total_archived or 0) + 1
            user_settings.last_archive_date = datetime.now()
            user_settings.save()

        # Queue Elasticsearch indexing for full-text search
        index_archive_for_search.delay(str(result["archive"].id))

        # Queue AI categorization (only if content was stored)
        if result["content_stored"]:
            categorize_archives.delay(user.pk, archive_ids=[str(result["archive"].id)])

        # Publish WebSocket event for real-time updates
        archive_data = {
            "archive_id": str(result["archive"].id),
            "url": url,
            "title": title,
            "domain": result["archive"].domain,
            "matched": result["matched"],
            "created": result["created"],
        }
        _publish_archive_event(user, [archive_data])

        return _json_response(
            {
                "code": 0,
                "archive_id": str(result["archive"].id),
                "matched": result["matched"],
                "matched_story_hash": result["matched_story_hash"],
                "content_stored": result["content_stored"],
                "created": result["created"],
                "updated": result["updated"],
            }
        )

    except Exception as e:
        logging.error(f"Error ingesting archive: {e}")
        return _error_response(f"Error archiving page: {str(e)}", status=500)


@csrf_exempt
@ajax_login_required
@require_http_methods(["POST"])
def batch_ingest(request):
    """
    Ingest multiple archived pages in a single request.
    Used for efficient batch syncing from the extension.

    POST params:
        archives: JSON array of archive objects, each containing:
            - url (required)
            - title (required)
            - content
            - favicon_url
            - time_on_page
            - browser
            - extension_version

    Returns:
        {
            code: 0 for success,
            results: [
                {
                    url: str,
                    archive_id: str,
                    matched: bool,
                    created: bool,
                    error: str or null
                },
                ...
            ],
            processed: int,
            errors: int
        }
    """
    user = get_user(request)
    has_access, error = _check_archive_access(user)
    if not has_access:
        return _error_response(error, status=403)

    # Parse archives from JSON body or POST data
    archives_json = request.POST.get("archives") or request.body.decode("utf-8")
    try:
        archives = json.decode(archives_json) if isinstance(archives_json, str) else archives_json
    except Exception as e:
        return _error_response(f"Invalid JSON: {e}")

    if not isinstance(archives, list):
        return _error_response("archives must be an array")

    if len(archives) > 100:
        return _error_response("Maximum 100 archives per batch")

    user_settings = MArchiveUserSettings.get_or_create(user.pk)
    results = []
    processed = 0
    errors = 0
    created_count = 0
    archives_with_content = []  # Track archives that need categorization

    for archive_data in archives:
        url = archive_data.get("url", "").strip()
        title = archive_data.get("title", "").strip()

        if not url or not title:
            results.append({"url": url, "error": "Missing url or title"})
            errors += 1
            continue

        # Check blocklist
        if is_blocked(url, user_settings):
            results.append({"url": url, "blocked": True})
            continue

        try:
            content = archive_data.get("content", "")
            author = archive_data.get("author", "").strip() or None
            result = match_and_process(
                user=user,
                url=url,
                title=title,
                content=content,
                content_length=len(content) if content else 0,
                favicon_url=archive_data.get("favicon_url", ""),
                author=author,
                time_on_page=int(archive_data.get("time_on_page", 0)),
                browser=archive_data.get("browser", "") or None,
                extension_version=archive_data.get("extension_version", "") or None,
            )

            # Calculate display fields for WebSocket event
            archive_obj = result["archive"]
            content_len = archive_obj.content_length or 0
            word_count = content_len // 5 if content_len else 0
            file_size_bytes = len(archive_obj.content_z) if archive_obj.content_z else 0
            if file_size_bytes < 1024:
                file_size_display = f"{file_size_bytes} B"
            elif file_size_bytes < 1024 * 1024:
                file_size_display = f"{file_size_bytes / 1024:.1f} KB"
            else:
                file_size_display = f"{file_size_bytes / (1024 * 1024):.1f} MB"

            # Get content preview for display
            archive_obj = result["archive"]
            content_preview = _get_content_preview(archive_obj) if content else None

            results.append(
                {
                    "url": url,
                    "archive_id": str(archive_obj.id),
                    "title": title,
                    "domain": archive_obj.domain,
                    "author": archive_obj.author,
                    "favicon_url": archive_obj.favicon_url,
                    "archived_date": format_datetime_utc(archive_obj.archived_date),
                    "matched": result["matched"],
                    "matched_feed_id": archive_obj.matched_feed_id,
                    "created": result["created"],
                    "content_length": content_len,
                    "word_count": word_count,
                    "word_count_display": f"{word_count:,}" if word_count else "0",
                    "content_preview": content_preview,
                    "has_content": bool(content),
                    "error": None,
                }
            )
            processed += 1
            if result["created"]:
                created_count += 1

            # Queue Elasticsearch indexing for full-text search
            index_archive_for_search.delay(str(result["archive"].id))

            # Track archives with content for categorization
            if result["content_stored"]:
                archives_with_content.append(str(result["archive"].id))

        except Exception as e:
            logging.error(f"Error ingesting archive {url}: {e}")
            results.append({"url": url, "error": str(e)})
            errors += 1

    # Queue AI categorization for all archives with content (batch for efficiency)
    if archives_with_content:
        categorize_archives.delay(user.pk, archive_ids=archives_with_content)

    # Update user stats
    if created_count > 0:
        user_settings.total_archived = (user_settings.total_archived or 0) + created_count
        user_settings.last_archive_date = datetime.now()
        user_settings.save()

    # Publish WebSocket event for real-time updates
    if processed > 0:
        successful_archives = [r for r in results if r.get("archive_id") and not r.get("error")]
        if successful_archives:
            _publish_archive_event(user, successful_archives)

    return _json_response(
        {
            "code": 0,
            "results": results,
            "processed": processed,
            "errors": errors,
        }
    )


@ajax_login_required
@require_http_methods(["GET"])
def list_archives(request):
    """
    List user's archived pages with filtering and pagination.

    GET params:
        limit: Number of results (default 50, max 200)
        offset: Pagination offset (default 0)
        domain: Filter by domain
        category: Filter by AI category
        search: Search query (full-text search via Elasticsearch)
        include_deleted: Include soft-deleted archives (default false)

    Returns:
        {
            code: 0,
            archives: [...],
            total: int,
            has_more: bool
        }
    """
    from apps.archive_extension.search import SearchArchive

    user = get_user(request)
    has_access, error = _check_archive_access(user)
    if not has_access:
        return _error_response(error, status=403)

    limit = min(int(request.GET.get("limit", 50)), 200)
    offset = int(request.GET.get("offset", 0))
    domain = request.GET.get("domain", "").strip()
    category = request.GET.get("category", "").strip()
    search = request.GET.get("search", "").strip()
    include_deleted = request.GET.get("include_deleted", "").lower() == "true"

    if search:
        # Use Elasticsearch for full-text search with highlights
        es_results = SearchArchive.query_with_highlights(
            user_id=user.pk,
            query=search,
            order="newest",
            offset=offset,
            limit=limit + 1,
            domain=domain if domain else None,
            categories=[category] if category else None,
        )

        # Fetch archives by IDs while preserving search result order
        archive_ids = [r["archive_id"] for r in es_results]
        archives_by_id = {}
        if archive_ids:
            for archive in MArchivedStory.objects(id__in=archive_ids, user_id=user.pk, deleted=False):
                archives_by_id[str(archive.id)] = archive

        # Build response with highlights, preserving search order
        serialized_list = []
        for es_result in es_results:
            archive = archives_by_id.get(es_result["archive_id"])
            if archive:
                serialized = _serialize_archive(archive)
                serialized["highlights"] = es_result["highlights"]
                serialized["search_score"] = es_result["score"]
                serialized_list.append(serialized)

        has_more = len(serialized_list) > limit
        if has_more:
            serialized_list = serialized_list[:limit]

        # Get approximate total from ES count
        total = len(serialized_list) + (1 if has_more else 0)

        return _json_response(
            {
                "code": 0,
                "archives": serialized_list,
                "total": total,
                "has_more": has_more,
            }
        )

    # No search - use MongoDB with content preview
    query = {"user_id": user.pk}
    if not include_deleted:
        query["deleted"] = False
    if domain:
        query["domain"] = domain
    if category:
        query["ai_categories"] = category

    # Get total count
    total = MArchivedStory.objects(**query).count()

    # Get paginated results
    archives = MArchivedStory.objects(**query).skip(offset).limit(limit + 1)
    archives_list = list(archives)

    has_more = len(archives_list) > limit
    if has_more:
        archives_list = archives_list[:limit]

    # Serialize with content preview
    serialized_list = []
    for archive in archives_list:
        serialized = _serialize_archive(archive)
        serialized["content_preview"] = _get_content_preview(archive)
        serialized_list.append(serialized)

    return _json_response(
        {
            "code": 0,
            "archives": serialized_list,
            "total": total,
            "has_more": has_more,
        }
    )


@ajax_login_required
@require_http_methods(["GET"])
def get_categories(request):
    """
    Get breakdown of archives by AI-generated categories and domains.

    Returns:
        {
            code: 0,
            categories: [
                {category: "Research", count: 42},
                {category: "Shopping", count: 15},
                ...
            ],
            domains: [
                {domain: "nytimes.com", count: 42},
                ...
            ]
        }
    """
    user = get_user(request)
    has_access, error = _check_archive_access(user)
    if not has_access:
        return _error_response(error, status=403)

    category_breakdown = MArchivedStory.get_category_breakdown(user.pk)
    domain_breakdown = MArchivedStory.get_domain_breakdown(user.pk, limit=20)

    return _json_response(
        {
            "code": 0,
            "categories": category_breakdown,
            "domains": domain_breakdown,
        }
    )


@ajax_login_required
@require_http_methods(["GET"])
def get_domains(request):
    """
    Get breakdown of archives by domain.

    GET params:
        limit: Number of domains to return (default 20)

    Returns:
        {
            code: 0,
            domains: [
                {domain: "nytimes.com", count: 42, last_visit: "2024-01-15T..."},
                ...
            ]
        }
    """
    user = get_user(request)
    has_access, error = _check_archive_access(user)
    if not has_access:
        return _error_response(error, status=403)

    limit = min(int(request.GET.get("limit", 20)), 100)
    breakdown = MArchivedStory.get_domain_breakdown(user.pk, limit=limit)

    return _json_response(
        {
            "code": 0,
            "domains": [
                {
                    "domain": item["_id"],
                    "count": item["count"],
                    "last_visit": format_datetime_utc(item.get("last_visit")),
                }
                for item in breakdown
            ],
        }
    )


@ajax_login_required
@require_http_methods(["GET"])
def get_stats(request):
    """
    Get archive statistics for the user.

    Returns:
        {
            code: 0,
            stats: {
                total_archived: int,
                total_matched: int,
                total_domains: int,
                archives_today: int,
                archives_this_week: int,
                last_archive_date: str or null
            }
        }
    """
    user = get_user(request)
    has_access, error = _check_archive_access(user)
    if not has_access:
        return _error_response(error, status=403)

    from datetime import timedelta

    now = datetime.now()
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    week_start = today_start - timedelta(days=today_start.weekday())

    # Get counts
    total = MArchivedStory.objects(user_id=user.pk, deleted=False).count()
    matched = MArchivedStory.objects(
        user_id=user.pk, deleted=False, matched_story_hash__ne=None
    ).count()
    today = MArchivedStory.objects(user_id=user.pk, deleted=False, archived_date__gte=today_start).count()
    week = MArchivedStory.objects(user_id=user.pk, deleted=False, archived_date__gte=week_start).count()

    # Get domain count
    domains = len(MArchivedStory.objects(user_id=user.pk, deleted=False).distinct("domain"))

    # Get user settings for last archive date
    settings = MArchiveUserSettings.get_or_create(user.pk)

    return _json_response(
        {
            "code": 0,
            "stats": {
                "total_archived": total,
                "total_matched": matched,
                "total_domains": domains,
                "archives_today": today,
                "archives_this_week": week,
                "last_archive_date": (
                    format_datetime_utc(settings.last_archive_date)
                ),
            },
        }
    )


@csrf_exempt
@ajax_login_required
@require_http_methods(["POST"])
def delete_archives(request):
    """
    Soft-delete one or more archived pages.

    POST params:
        archive_ids: JSON array of archive IDs to delete

    Returns:
        {
            code: 0,
            deleted: int
        }
    """
    user = get_user(request)
    has_access, error = _check_archive_access(user)
    if not has_access:
        return _error_response(error, status=403)

    archive_ids_json = request.POST.get("archive_ids", "[]")
    try:
        archive_ids = json.decode(archive_ids_json)
    except Exception:
        return _error_response("Invalid archive_ids JSON")

    if not isinstance(archive_ids, list):
        return _error_response("archive_ids must be an array")

    deleted_count = 0
    deleted_ids = []
    for archive_id in archive_ids:
        try:
            archive = MArchivedStory.objects.get(id=archive_id, user_id=user.pk)
            archive.soft_delete()
            deleted_count += 1
            deleted_ids.append(archive_id)
        except MArchivedStory.DoesNotExist:
            pass
        except Exception as e:
            logging.error(f"Error deleting archive {archive_id}: {e}")

    # Publish WebSocket event for real-time updates
    if deleted_ids:
        _publish_archive_event(user, [{"archive_id": aid} for aid in deleted_ids], event_type="deleted")

    return _json_response({"code": 0, "deleted": deleted_count})


@ajax_login_required
@require_http_methods(["GET"])
def get_blocklist(request):
    """
    Get user's blocklist settings.

    Returns:
        {
            code: 0,
            default_blocked_domains: [...],
            default_blocked_patterns: [...],
            custom_blocked_domains: [...],
            custom_blocked_patterns: [...],
            allowed_domains: [...]
        }
    """
    user = get_user(request)
    has_access, error = _check_archive_access(user)
    if not has_access:
        return _error_response(error, status=403)

    settings = MArchiveUserSettings.get_or_create(user.pk)

    return _json_response(
        {
            "code": 0,
            "default_blocked_domains": get_blocked_domains(),
            "default_blocked_patterns": get_blocked_patterns(),
            "custom_blocked_domains": settings.blocked_domains or [],
            "custom_blocked_patterns": settings.blocked_patterns or [],
            "allowed_domains": settings.allowed_domains or [],
        }
    )


@csrf_exempt
@ajax_login_required
@require_http_methods(["POST"])
def update_blocklist(request):
    """
    Update user's blocklist settings.

    POST params:
        blocked_domains: JSON array of domains to block
        blocked_patterns: JSON array of regex patterns to block
        allowed_domains: JSON array of domains to allow (overrides defaults)

    Returns:
        {code: 0}
    """
    user = get_user(request)
    has_access, error = _check_archive_access(user)
    if not has_access:
        return _error_response(error, status=403)

    settings = MArchiveUserSettings.get_or_create(user.pk)

    # Update blocked domains
    blocked_domains = request.POST.get("blocked_domains")
    if blocked_domains:
        try:
            settings.blocked_domains = json.decode(blocked_domains)
        except Exception:
            return _error_response("Invalid blocked_domains JSON")

    # Update blocked patterns
    blocked_patterns = request.POST.get("blocked_patterns")
    if blocked_patterns:
        try:
            settings.blocked_patterns = json.decode(blocked_patterns)
        except Exception:
            return _error_response("Invalid blocked_patterns JSON")

    # Update allowed domains
    allowed_domains = request.POST.get("allowed_domains")
    if allowed_domains:
        try:
            settings.allowed_domains = json.decode(allowed_domains)
        except Exception:
            return _error_response("Invalid allowed_domains JSON")

    settings.save()

    return _json_response({"code": 0})


@ajax_login_required
@require_http_methods(["GET"])
def export_archives(request):
    """
    Export user's archive data as JSON or CSV.

    GET params:
        format: 'json' or 'csv' (default 'json')
        include_content: Include full content (default false, significantly increases size)

    Returns:
        JSON array or CSV file download
    """
    user = get_user(request)
    has_access, error = _check_archive_access(user)
    if not has_access:
        return _error_response(error, status=403)

    export_format = request.GET.get("format", "json").lower()
    include_content = request.GET.get("include_content", "").lower() == "true"

    archives = MArchivedStory.objects(user_id=user.pk, deleted=False)

    if export_format == "csv":
        import csv
        from io import StringIO

        output = StringIO()
        writer = csv.writer(output)

        # Header
        headers = [
            "url",
            "title",
            "domain",
            "archived_date",
            "first_visited",
            "last_visited",
            "visit_count",
            "categories",
            "matched_story_hash",
        ]
        if include_content:
            headers.append("content")
        writer.writerow(headers)

        # Data
        for archive in archives:
            row = [
                archive.url,
                archive.title,
                archive.domain,
                format_datetime_utc(archive.archived_date) or "",
                format_datetime_utc(archive.first_visited) or "",
                format_datetime_utc(archive.last_visited) or "",
                archive.visit_count,
                ",".join(archive.ai_categories or []),
                archive.matched_story_hash or "",
            ]
            if include_content:
                row.append(archive.get_content())
            writer.writerow(row)

        response = HttpResponse(output.getvalue(), content_type="text/csv")
        response["Content-Disposition"] = 'attachment; filename="newsblur_archives.csv"'
        return response

    else:  # JSON
        data = [_serialize_archive(a, include_content=include_content) for a in archives]
        response = HttpResponse(json.encode(data, indent=2), content_type="application/json")
        response["Content-Disposition"] = 'attachment; filename="newsblur_archives.json"'
        return response


# ===================
# Category Management
# ===================


@csrf_exempt
@ajax_login_required
@require_http_methods(["POST"])
def merge_categories(request):
    """
    Merge multiple categories into one target category.

    All stories with source categories will have those categories replaced
    with the target category.

    POST params:
        source_categories: JSON array of category names to merge
        target_category: Target category name

    Returns:
        {
            code: 0,
            merged_count: int,
            target_category: str
        }
    """
    user = get_user(request)
    has_access, error = _check_archive_access(user)
    if not has_access:
        return _error_response(error, status=403)

    source_categories_json = request.POST.get("source_categories", "[]")
    target_category = request.POST.get("target_category", "").strip()

    try:
        source_categories = json.decode(source_categories_json)
    except Exception:
        return _error_response("Invalid source_categories JSON")

    if not isinstance(source_categories, list) or not source_categories:
        return _error_response("source_categories must be a non-empty array")
    if not target_category:
        return _error_response("target_category is required")

    merged_count = 0
    for source in source_categories:
        if source == target_category:
            continue

        # Get stories with source category
        stories = MArchivedStory.objects(user_id=user.pk, ai_categories=source)
        count = stories.count()

        # Update stories: first add target, then remove source
        # MongoDB doesn't allow pull and add_to_set on same field in one update
        if count > 0:
            stories.update(add_to_set__ai_categories=target_category)
            MArchivedStory.objects(user_id=user.pk, ai_categories=source).update(pull__ai_categories=source)
            merged_count += count

    # Update Elasticsearch index for affected stories
    if merged_count > 0:
        _reindex_categories_async(user.pk, source_categories, target_category)

    return _json_response(
        {
            "code": 0,
            "merged_count": merged_count,
            "target_category": target_category,
        }
    )


@csrf_exempt
@ajax_login_required
@require_http_methods(["POST"])
def rename_category(request):
    """
    Rename a category.

    POST params:
        old_name: Current category name
        new_name: New category name

    Returns:
        {
            code: 0,
            renamed_count: int
        }
    """
    user = get_user(request)
    has_access, error = _check_archive_access(user)
    if not has_access:
        return _error_response(error, status=403)

    old_name = request.POST.get("old_name", "").strip()
    new_name = request.POST.get("new_name", "").strip()

    if not old_name or not new_name:
        return _error_response("old_name and new_name are required")
    if old_name == new_name:
        return _error_response("old_name and new_name must be different")

    stories = MArchivedStory.objects(user_id=user.pk, ai_categories=old_name)
    renamed_count = stories.count()

    if renamed_count > 0:
        stories.update(add_to_set__ai_categories=new_name)
        MArchivedStory.objects(user_id=user.pk, ai_categories=old_name).update(pull__ai_categories=old_name)

    # Update Elasticsearch index
    if renamed_count > 0:
        _reindex_categories_async(user.pk, [old_name], new_name)

    return _json_response(
        {
            "code": 0,
            "renamed_count": renamed_count,
        }
    )


@csrf_exempt
@ajax_login_required
@require_http_methods(["POST"])
def split_category(request):
    """
    Split a category into multiple categories using AI suggestions.

    POST params:
        category: Category to split
        action: "suggest" to get AI suggestions, "apply" to apply a split

    For action="suggest":
        Returns AI-suggested split targets based on story content.

    For action="apply":
        split_rules: JSON array of {new_category: str, story_ids: [str]}
        or new_category + story_ids for a single split

    Returns:
        {
            code: 0,
            suggestions: [...] (for suggest)
            or
            applied_count: int (for apply)
        }
    """
    user = get_user(request)
    has_access, error = _check_archive_access(user)
    if not has_access:
        return _error_response(error, status=403)

    category = request.POST.get("category", "").strip()
    action = request.POST.get("action", "suggest")

    if not category:
        return _error_response("category is required")

    if action == "suggest":
        # Get ALL stories from this category (up to 100)
        stories = list(
            MArchivedStory.objects(user_id=user.pk, ai_categories=category, deleted=False).limit(100)
        )

        if not stories:
            return _json_response({"code": 0, "suggestions": []})

        # Build a mapping of story ID to story for lookup
        id_to_story = {str(s.id): s for s in stories}

        # Build AI prompt with story IDs so we can map back directly
        story_summaries = "\n".join([f"[{s.id}] {s.title}" for s in stories])

        try:
            import anthropic
            from django.conf import settings

            if not getattr(settings, "ANTHROPIC_API_KEY", None):
                return _error_response("ANTHROPIC_API_KEY not configured")

            client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)

            prompt = f"""Analyze these {len(stories)} items currently in the "{category}" category and split them into 2-4 more specific categories.

IMPORTANT: You MUST assign EVERY item to at least one category. Each item can belong to multiple categories if relevant.

Items (format: [ID] Title):
{story_summaries}

Return ONLY valid JSON with the exact IDs from above:
[
  {{"name": "Category Name", "ids": ["id1", "id2", ...]}}
]"""

            response = client.messages.create(
                model="claude-haiku-4-5", max_tokens=2000, messages=[{"role": "user", "content": prompt}]
            )

            result_text = response.content[0].text.strip()
            # Remove markdown code block if present
            if result_text.startswith("```"):
                result_text = result_text.split("\n", 1)[1]
                if result_text.endswith("```"):
                    result_text = result_text.rsplit("```", 1)[0]

            suggestions = json.decode(result_text)

            # Map IDs from AI response - AI returns "ids" field with story IDs
            for suggestion in suggestions:
                # AI returns ids directly now
                ids = suggestion.get("ids", [])
                # Validate that these IDs exist in our stories
                valid_ids = [sid for sid in ids if sid in id_to_story]
                suggestion["story_ids"] = valid_ids

            return _json_response(
                {
                    "code": 0,
                    "original_category": category,
                    "suggestions": suggestions,
                    "total_stories": len(stories),
                }
            )

        except Exception as e:
            logging.error(f"AI split suggestion failed: {e}")
            return _error_response(f"Failed to generate suggestions: {str(e)}")

    elif action == "apply":
        split_rules_json = request.POST.get("split_rules", "").strip()
        if split_rules_json:
            try:
                split_rules = json.decode(split_rules_json)
            except Exception:
                return _error_response("Invalid split_rules JSON")
        else:
            new_category = request.POST.get("new_category", "").strip()
            story_ids_json = request.POST.get("story_ids", "[]")

            try:
                story_ids = json.decode(story_ids_json) if story_ids_json else []
            except Exception:
                return _error_response("Invalid story_ids JSON")

            if not new_category:
                return _error_response("new_category is required")
            if not story_ids:
                return _error_response("story_ids is required")

            split_rules = [{"new_category": new_category, "story_ids": story_ids}]

        applied_count = 0
        # Update stories: remove old category, add new category
        # Note: MongoDB doesn't allow pull and add_to_set on same field in one update
        for rule in split_rules:
            new_category = (rule.get("new_category") or "").strip()
            story_ids = rule.get("story_ids") or []

            if not new_category or not story_ids:
                continue

            for story_id in story_ids:
                try:
                    # First remove the old category
                    MArchivedStory.objects(id=story_id, user_id=user.pk).update(pull__ai_categories=category)
                    # Then add the new category
                    MArchivedStory.objects(id=story_id, user_id=user.pk).update(
                        add_to_set__ai_categories=new_category
                    )
                    applied_count += 1
                except Exception as e:
                    logging.error(f"Error applying split to story {story_id}: {e}")

        return _json_response(
            {
                "code": 0,
                "applied_count": applied_count,
            }
        )

    return _error_response("Invalid action. Use 'suggest' or 'apply'")


@ajax_login_required
@require_http_methods(["GET"])
def suggest_category_merges(request):
    """
    Get AI-suggested category merges based on name similarity.

    Returns categories that might be duplicates or could be merged.

    Returns:
        {
            code: 0,
            suggestions: [
                {
                    categories: ["AI", "Artificial Intelligence"],
                    suggested_target: "AI & Machine Learning",
                    confidence: 0.85,
                    reason: "Similar category names"
                }
            ]
        }
    """
    from difflib import SequenceMatcher

    user = get_user(request)
    has_access, error = _check_archive_access(user)
    if not has_access:
        return _error_response(error, status=403)

    # Get all categories with counts
    categories = MArchivedStory.get_category_breakdown(user.pk)

    if len(categories) < 2:
        return _json_response({"code": 0, "suggestions": []})

    suggestions = []
    category_names = [c["category"] for c in categories]
    category_counts = {c["category"]: c["count"] for c in categories}

    # Find similar category names
    checked = set()
    for i, cat1 in enumerate(category_names):
        for cat2 in category_names[i + 1 :]:
            pair = tuple(sorted([cat1, cat2]))
            if pair in checked:
                continue
            checked.add(pair)

            # Check string similarity
            ratio = SequenceMatcher(None, cat1.lower(), cat2.lower()).ratio()

            if ratio > 0.6:  # Similar names
                # Suggest the category with higher count as target
                if category_counts[cat1] >= category_counts[cat2]:
                    suggested_target = cat1
                else:
                    suggested_target = cat2

                suggestions.append(
                    {
                        "categories": [cat1, cat2],
                        "suggested_target": suggested_target,
                        "confidence": round(ratio, 2),
                        "reason": "Similar category names",
                        "counts": {cat1: category_counts[cat1], cat2: category_counts[cat2]},
                    }
                )

    # Sort by confidence
    suggestions.sort(key=lambda x: -x["confidence"])

    return _json_response(
        {
            "code": 0,
            "suggestions": suggestions[:10],  # Top 10 suggestions
        }
    )


@csrf_exempt
@ajax_login_required
@require_http_methods(["POST"])
def bulk_categorize(request):
    """
    Trigger bulk categorization of uncategorized archives.

    POST params:
        limit: Max stories to process (default 100, max 500)

    Returns:
        {
            code: 0,
            queued_count: int,
            task_id: str
        }
    """
    from apps.archive_extension.tasks import bulk_categorize_archives

    user = get_user(request)
    has_access, error = _check_archive_access(user)
    if not has_access:
        return _error_response(error, status=403)

    limit = min(int(request.POST.get("limit", 100)), 500)

    # Count uncategorized archives
    uncategorized_count = MArchivedStory.objects(
        user_id=user.pk, deleted=False, ai_categorized_date=None, content_z__ne=None
    ).count()

    if uncategorized_count == 0:
        return _json_response(
            {
                "code": 0,
                "queued_count": 0,
                "message": "No uncategorized archives found",
            }
        )

    # Queue the task
    task = bulk_categorize_archives.delay(user.pk, limit=min(limit, uncategorized_count))

    return _json_response(
        {
            "code": 0,
            "queued_count": min(limit, uncategorized_count),
            "task_id": str(task.id),
            "total_uncategorized": uncategorized_count,
        }
    )


@csrf_exempt
@ajax_login_required
@require_http_methods(["POST"])
def recategorize_archives(request):
    """
    Re-categorize specific archives by clearing their categories
    and queuing them for fresh AI categorization.

    POST params:
        archive_ids: JSON array of archive IDs to re-categorize

    Returns:
        {
            code: 0,
            queued_count: int,
            task_id: str
        }
    """
    import json

    from apps.archive_extension.tasks import categorize_archives

    user = get_user(request)
    has_access, error = _check_archive_access(user)
    if not has_access:
        return _error_response(error, status=403)

    try:
        archive_ids = json.loads(request.POST.get("archive_ids", "[]"))
    except json.JSONDecodeError:
        return _error_response("Invalid archive_ids format", status=400)

    if not archive_ids:
        return _error_response("No archive IDs provided", status=400)

    # Clear categories for specified archives owned by this user
    result = MArchivedStory.objects(user_id=user.pk, id__in=archive_ids).update(
        set__ai_categories=[], set__ai_categorized_date=None
    )

    if result == 0:
        return _error_response("No matching archives found", status=404)

    # Queue for re-categorization
    task = categorize_archives.delay(user.pk, archive_ids=archive_ids)

    return _json_response(
        {
            "code": 0,
            "queued_count": result,
            "task_id": str(task.id),
        }
    )


def _reindex_categories_async(user_id, old_categories, new_category):
    """
    Queue reindexing of stories affected by category changes.

    This updates the Elasticsearch index for all stories that had
    categories changed.
    """
    from apps.archive_extension.tasks import index_archive_for_search

    # Find all stories that now have the new category
    stories = MArchivedStory.objects(user_id=user_id, ai_categories=new_category).only("id")

    for story in stories:
        index_archive_for_search.delay(str(story.id))


def _get_content_preview(archive, max_chars=100):
    """Get truncated content preview for display."""
    content = archive.get_content()
    if not content:
        return None

    content = content.strip()
    if len(content) <= max_chars:
        return content

    # Find word boundary
    truncated = content[:max_chars]
    last_space = truncated.rfind(" ")
    if last_space > max_chars * 0.7:
        truncated = truncated[:last_space]

    return truncated + "..."


def _serialize_archive(archive, include_content=False):
    """Serialize an MArchivedStory to a dict for JSON response."""
    # Calculate word count from content length (rough estimate: ~5 chars per word)
    word_count = 0
    if archive.content_length:
        word_count = archive.content_length // 5

    # Calculate file size (compressed content + metadata overhead)
    file_size_bytes = 0
    if archive.content_z:
        file_size_bytes = len(archive.content_z)

    # Format file size for display
    if file_size_bytes < 1024:
        file_size_display = f"{file_size_bytes} B"
    elif file_size_bytes < 1024 * 1024:
        file_size_display = f"{file_size_bytes / 1024:.1f} KB"
    else:
        file_size_display = f"{file_size_bytes / (1024 * 1024):.1f} MB"

    data = {
        "id": str(archive.id),
        "url": archive.url,
        "title": archive.title,
        "domain": archive.domain,
        "author": archive.author,
        "favicon_url": archive.favicon_url,
        "archived_date": format_datetime_utc(archive.archived_date),
        "first_visited": format_datetime_utc(archive.first_visited),
        "last_visited": format_datetime_utc(archive.last_visited),
        "visit_count": archive.visit_count,
        "time_on_page_seconds": archive.time_on_page_seconds,
        "content_length": archive.content_length,
        "content_length_display": f"{archive.content_length:,}" if archive.content_length else "0",
        "word_count": word_count,
        "word_count_display": f"{word_count:,}" if word_count else "0",
        "file_size_bytes": file_size_bytes,
        "file_size_display": file_size_display,
        "has_content": bool(archive.content_z),
        "matched": archive.matched_story_hash is not None,
        "matched_story_hash": archive.matched_story_hash,
        "matched_feed_id": archive.matched_feed_id,
        "content_source": archive.content_source,
        "ai_categories": archive.ai_categories or [],
        "browser": archive.browser,
    }

    if include_content:
        data["content"] = archive.get_content()

    return data
