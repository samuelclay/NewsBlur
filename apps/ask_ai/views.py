import uuid

from django.views.decorators.http import require_http_methods

from apps.rss_feeds.models import MStory
from utils import json_functions as json
from utils.user_functions import ajax_login_required
from utils.view_functions import required_params

from .tasks import AskAIQuestion


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

    Returns:
        JSON response with request_id and status
    """
    story_hash = request.POST.get("story_hash")
    question_id = request.POST.get("question_id")
    custom_question = request.POST.get("custom_question", "")

    # Validate story exists
    story, _ = MStory.find_story(story_hash=story_hash)
    if not story:
        return {"code": -1, "message": "Story not found"}

    # Validate custom question if question_id is "custom"
    if question_id == "custom" and not custom_question:
        return {"code": -1, "message": "Custom question is required"}

    # Generate unique request ID for tracking
    request_id = str(uuid.uuid4())

    # Queue Celery task
    AskAIQuestion.apply_async(
        kwargs={
            "user_id": request.user.pk,
            "story_hash": story_hash,
            "question_id": question_id,
            "custom_question": custom_question if custom_question else None,
        },
        queue="ask_ai",
    )

    return {
        "code": 1,
        "message": "Processing question",
        "request_id": request_id,
        "story_hash": story_hash,
        "question_id": question_id,
    }
