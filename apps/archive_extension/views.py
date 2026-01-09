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
from apps.archive_extension.tasks import index_archive_for_search
from apps.profile.models import Profile
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
    """
    if not user.is_authenticated:
        return False, "Authentication required"

    profile = Profile.objects.get(user=user)
    if not profile.is_archive:
        return False, "Archive Extension requires a Premium Archive subscription"

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
            result = match_and_process(
                user=user,
                url=url,
                title=title,
                content=content,
                content_length=len(content) if content else 0,
                favicon_url=archive_data.get("favicon_url", ""),
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

            results.append(
                {
                    "url": url,
                    "archive_id": str(result["archive"].id),
                    "title": title,
                    "domain": result["archive"].domain,
                    "matched": result["matched"],
                    "created": result["created"],
                    "content_length": content_len,
                    "word_count": word_count,
                    "word_count_display": f"{word_count:,}" if word_count else "0",
                    "file_size_bytes": file_size_bytes,
                    "file_size_display": file_size_display,
                    "error": None,
                }
            )
            processed += 1
            if result["created"]:
                created_count += 1

            # Queue Elasticsearch indexing for full-text search
            index_archive_for_search.delay(str(result["archive"].id))

        except Exception as e:
            logging.error(f"Error ingesting archive {url}: {e}")
            results.append({"url": url, "error": str(e)})
            errors += 1

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
        search: Search query (searches title)
        include_deleted: Include soft-deleted archives (default false)

    Returns:
        {
            code: 0,
            archives: [...],
            total: int,
            has_more: bool
        }
    """
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

    # Build query
    query = {"user_id": user.pk}
    if not include_deleted:
        query["deleted"] = False
    if domain:
        query["domain"] = domain
    if category:
        query["ai_categories"] = category
    if search:
        query["title__icontains"] = search

    # Get total count
    total = MArchivedStory.objects(**query).count()

    # Get paginated results
    archives = MArchivedStory.objects(**query).skip(offset).limit(limit + 1)
    archives_list = list(archives)

    has_more = len(archives_list) > limit
    if has_more:
        archives_list = archives_list[:limit]

    return _json_response(
        {
            "code": 0,
            "archives": [_serialize_archive(a) for a in archives_list],
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
                {_id: "Research", count: 42},
                {_id: "Shopping", count: 15},
                ...
            ],
            domains: [
                {_id: "nytimes.com", count: 42},
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
            "categories": [{"_id": item["_id"], "count": item["count"]} for item in category_breakdown],
            "domains": [{"_id": item["_id"], "count": item["count"]} for item in domain_breakdown],
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
                    "last_visit": item["last_visit"].isoformat() if item.get("last_visit") else None,
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
                    settings.last_archive_date.isoformat() if settings.last_archive_date else None
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
                archive.archived_date.isoformat() if archive.archived_date else "",
                archive.first_visited.isoformat() if archive.first_visited else "",
                archive.last_visited.isoformat() if archive.last_visited else "",
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
        "favicon_url": archive.favicon_url,
        "archived_date": archive.archived_date.isoformat() if archive.archived_date else None,
        "first_visited": archive.first_visited.isoformat() if archive.first_visited else None,
        "last_visited": archive.last_visited.isoformat() if archive.last_visited else None,
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
