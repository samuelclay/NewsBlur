import re
import uuid

from django.views.decorators.http import require_http_methods

from apps.rss_feeds.models import MStory
from utils import json_functions as json
from utils.user_functions import ajax_login_required
from utils.view_functions import required_params

from .prompts import get_prompt
from .tasks import AskAIQuestion
from .usage import AskAIUsageTracker

MAX_CUSTOM_QUESTION_LENGTH = 5000
REQUEST_ID_RE = re.compile(r"^[A-Za-z0-9_\-]{8,64}$")


@ajax_login_required
@require_http_methods(["POST"])
@required_params("story_hash", "question_id")
@json.json_view
def ask_ai_question(request):
    """
    API endpoint to start an Ask AI question.

    POST Parameters:
        story_hash: Hash of the story to analyze
        question_id: ID of the question template (e.g., "sentence", "bullets", "custom")
        custom_question: Optional custom question text (required if question_id is "custom")
        conversation_history: Optional JSON string of conversation history for follow-ups

    Returns:
        JSON response with request_id and status
    """
    story_hash = request.POST.get("story_hash")
    question_id = request.POST.get("question_id")
    custom_question = request.POST.get("custom_question", "")
    conversation_history_json = request.POST.get("conversation_history", "")
    request_id = request.POST.get("request_id")

    # Validate request identifier (optional client-provided UUID)
    if request_id:
        if not REQUEST_ID_RE.match(request_id):
            return {"code": -1, "message": "Invalid request identifier"}
    else:
        request_id = str(uuid.uuid4())

    # Parse conversation history if provided
    conversation_history = None
    if conversation_history_json:
        try:
            conversation_history = json.decode(conversation_history_json)
            if not isinstance(conversation_history, list):
                raise ValueError("Conversation history must be a list")
        except (json.JSONDecodeError, ValueError, TypeError):
            return {"code": -1, "message": "Invalid conversation history format"}

    # Normalize custom question input
    if custom_question:
        custom_question = custom_question.strip()

    # Check usage limits
    can_use, limit_message = AskAIUsageTracker(request.user).can_use()
    if not can_use:
        return {"code": -1, "message": limit_message}

    # Validate story exists
    story, _ = MStory.find_story(story_hash=story_hash)
    if not story:
        return {"code": -1, "message": "Story not found"}

    # Validate question id and custom question payload
    if question_id == "custom":
        if not custom_question and not conversation_history:
            return {"code": -1, "message": "Custom question is required"}
        if custom_question and len(custom_question) > MAX_CUSTOM_QUESTION_LENGTH:
            return {
                "code": -1,
                "message": f"Custom questions are limited to {MAX_CUSTOM_QUESTION_LENGTH} characters",
            }
    elif not get_prompt(question_id):
        return {"code": -1, "message": "Unknown Ask AI question"}

    # Queue Celery task
    AskAIQuestion.apply_async(
        kwargs={
            "user_id": request.user.pk,
            "story_hash": story_hash,
            "question_id": question_id,
            "custom_question": custom_question if custom_question else None,
            "conversation_history": conversation_history,
            "request_id": request_id,
        },
        queue="work_queue",
    )

    return {
        "code": 1,
        "message": "Processing question",
        "request_id": request_id,
        "story_hash": story_hash,
        "question_id": question_id,
    }
