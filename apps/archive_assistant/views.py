"""
API endpoints for the Archive Assistant.

Provides endpoints for querying the archive with AI, managing conversations,
and getting suggested questions.
"""

from datetime import datetime

from bson import ObjectId
from django.http import HttpResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods

from apps.archive_assistant.models import MArchiveConversation, MArchiveQuery, MArchiveAssistantUsage
from apps.archive_assistant.prompts import get_suggested_questions
from apps.archive_assistant.tasks import process_archive_query
from apps.archive_extension.models import MArchivedStory
from apps.profile.models import Profile
from utils import json_functions as json
from utils import log as logging
from utils.user_functions import ajax_login_required, get_user


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
def submit_query(request):
    """
    Submit a query to the Archive Assistant.

    POST params:
        query: The question to ask (required)
        conversation_id: Existing conversation ID (optional, creates new if not provided)
        model: Model to use (optional, defaults to claude-sonnet-4-20250514)

    Returns:
        {
            code: 0,
            query_id: str,
            conversation_id: str
        }

    The actual response will be streamed via WebSocket/Redis PubSub.
    Non-premium users get truncated responses.
    """
    user = get_user(request)

    # Check usage limits (now allows non-premium with lower daily limit)
    can_use, limit_error = MArchiveAssistantUsage.can_use(user)
    if not can_use:
        return _error_response(limit_error, status=429)

    query_text = request.POST.get("query", "").strip()
    conversation_id = request.POST.get("conversation_id", "").strip()
    model = request.POST.get("model", "claude-sonnet-4-20250514")

    # Check if user has premium archive for full responses
    profile = Profile.objects.get(user=user)
    is_premium_archive = profile.is_archive

    if not query_text:
        return _error_response("Query is required")

    if len(query_text) > 4096:
        return _error_response("Query too long (max 4096 characters)")

    # Get or create conversation
    if conversation_id:
        try:
            conversation = MArchiveConversation.objects.get(id=conversation_id, user_id=user.pk)
        except MArchiveConversation.DoesNotExist:
            return _error_response("Conversation not found")
    else:
        conversation = MArchiveConversation(user_id=user.pk)
        conversation.save()

    # Create query record
    query = MArchiveQuery(
        user_id=user.pk,
        conversation_id=conversation.id,
        query_text=query_text,
        model=model,
    )
    query.save()

    # Queue async processing (route to archive_queue for worktree celery)
    process_archive_query.apply_async(
        kwargs={
            "user_id": user.pk,
            "conversation_id": str(conversation.id),
            "query_id": str(query.id),
            "query_text": query_text,
            "model": model,
            "is_premium_archive": is_premium_archive,
        },
        queue="archive_queue",
    )

    return _json_response(
        {
            "code": 0,
            "query_id": str(query.id),
            "conversation_id": str(conversation.id),
        }
    )


@ajax_login_required
@require_http_methods(["GET"])
def get_conversations(request):
    """
    Get user's conversation history.

    GET params:
        limit: Number of conversations (default 20)
        offset: Pagination offset (default 0)
        active_only: Only return active conversations (default true)

    Returns:
        {
            code: 0,
            conversations: [...]
        }
    """
    user = get_user(request)

    limit = min(int(request.GET.get("limit", 20)), 100)
    offset = int(request.GET.get("offset", 0))
    active_only = request.GET.get("active_only", "true").lower() == "true"

    query = {"user_id": user.pk}
    if active_only:
        query["is_active"] = True

    conversations = MArchiveConversation.objects(**query).skip(offset).limit(limit)

    return _json_response(
        {
            "code": 0,
            "conversations": [
                {
                    "id": str(c.id),
                    "title": c.title or "New Conversation",
                    "created_date": c.created_date.isoformat() if c.created_date else None,
                    "last_activity": c.last_activity.isoformat() if c.last_activity else None,
                    "is_active": c.is_active,
                }
                for c in conversations
            ],
        }
    )


@ajax_login_required
@require_http_methods(["GET"])
def get_conversation(request, conversation_id):
    """
    Get a specific conversation with its queries.

    Returns:
        {
            code: 0,
            conversation: {...},
            queries: [...]
        }
    """
    user = get_user(request)

    try:
        conversation = MArchiveConversation.objects.get(id=conversation_id, user_id=user.pk)
    except MArchiveConversation.DoesNotExist:
        return _error_response("Conversation not found", status=404)

    queries = MArchiveQuery.objects(conversation_id=conversation.id).order_by("query_date")

    return _json_response(
        {
            "code": 0,
            "conversation": {
                "id": str(conversation.id),
                "title": conversation.title or "New Conversation",
                "created_date": conversation.created_date.isoformat() if conversation.created_date else None,
                "last_activity": conversation.last_activity.isoformat() if conversation.last_activity else None,
            },
            "queries": [
                {
                    "id": str(q.id),
                    "query_text": q.query_text,
                    "response": q.get_response(),
                    "query_date": q.query_date.isoformat() if q.query_date else None,
                    "response_date": q.response_date.isoformat() if q.response_date else None,
                    "model": q.model,
                    "duration_ms": q.duration_ms,
                    "error": q.error,
                }
                for q in queries
            ],
        }
    )


@csrf_exempt
@ajax_login_required
@require_http_methods(["POST"])
def delete_conversation(request, conversation_id):
    """
    Delete (deactivate) a conversation.

    Returns:
        {code: 0}
    """
    user = get_user(request)

    try:
        conversation = MArchiveConversation.objects.get(id=conversation_id, user_id=user.pk)
        conversation.is_active = False
        conversation.save()
    except MArchiveConversation.DoesNotExist:
        return _error_response("Conversation not found", status=404)

    return _json_response({"code": 0})


@ajax_login_required
@require_http_methods(["GET"])
def get_suggestions(request):
    """
    Get suggested questions based on user's archive content.

    Returns:
        {
            code: 0,
            suggestions: [...]
        }
    """
    user = get_user(request)

    # Get user's top categories
    categories = MArchivedStory.get_category_breakdown(user.pk)
    category_names = [c["_id"] for c in categories[:5]]

    # Get recent domains
    domains = MArchivedStory.get_domain_breakdown(user.pk, limit=10)
    domain_names = [d["_id"] for d in domains]

    suggestions = get_suggested_questions(categories=category_names, recent_domains=domain_names)

    return _json_response(
        {
            "code": 0,
            "suggestions": suggestions,
        }
    )


@ajax_login_required
@require_http_methods(["GET"])
def get_usage(request):
    """
    Get user's Archive Assistant usage statistics.

    Returns:
        {
            code: 0,
            usage: {
                queries_today: int,
                queries_limit: int,
                can_query: bool
            }
        }
    """
    user = get_user(request)

    # Get user's subscription level for limit display
    profile = Profile.objects.get(user=user)
    daily_limit = 100 if profile.is_archive else 20

    today_start = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    today_count = MArchiveAssistantUsage.objects(
        user_id=user.pk, query_date__gte=today_start, source__in=["live", "cache"]
    ).count()

    can_use, _ = MArchiveAssistantUsage.can_use(user)

    return _json_response(
        {
            "code": 0,
            "usage": {
                "queries_today": today_count,
                "queries_limit": daily_limit,
                "can_query": can_use,
                "is_premium_archive": profile.is_archive,
            },
        }
    )
