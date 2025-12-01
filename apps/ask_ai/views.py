import re
import uuid

import openai
from django.conf import settings
from django.views.decorators.http import require_http_methods

from apps.rss_feeds.models import MStory
from utils import json_functions as json
from utils import log as logging
from utils.user_functions import ajax_login_required
from utils.view_functions import required_params

from .prompts import get_prompt
from .providers import VALID_MODELS
from .tasks import AskAIQuestion
from .usage import AskAIUsageTracker, TranscriptionUsageTracker

MAX_CUSTOM_QUESTION_LENGTH = 5000
MAX_AUDIO_SIZE_MB = 25  # OpenAI Whisper API limit
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
        model: Optional model to use (haiku, sonnet, opus, gpt-4.1). Defaults to server setting.

    Returns:
        JSON response with request_id and status
    """
    story_hash = request.POST.get("story_hash")
    question_id = request.POST.get("question_id")
    custom_question = request.POST.get("custom_question", "")
    conversation_history_json = request.POST.get("conversation_history", "")
    request_id = request.POST.get("request_id")
    model = request.POST.get("model", "")

    # Validate request identifier (optional client-provided UUID)
    if request_id:
        if not REQUEST_ID_RE.match(request_id):
            return {"code": -1, "message": "Invalid request identifier"}
    else:
        request_id = str(uuid.uuid4())

    # Validate model (optional, defaults to server setting if not provided)
    if model and model not in VALID_MODELS:
        return {"code": -1, "message": f"Invalid model. Valid options: {', '.join(VALID_MODELS)}"}

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
    tracker = AskAIUsageTracker(request.user)
    can_use, limit_message = tracker.can_use()
    if not can_use:
        # Record this denied attempt for analytics
        tracker.record_denied(question_id=question_id, story_hash=story_hash, request_id=request_id)
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
            "model": model if model else None,
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


@ajax_login_required
@require_http_methods(["POST"])
@json.json_view
def transcribe_audio(request):
    """
    API endpoint to transcribe audio using OpenAI Whisper.

    POST Parameters:
        audio: Audio file (webm, mp3, wav, etc.)

    Returns:
        JSON response with transcribed text
    """
    if "audio" not in request.FILES:
        return {"code": -1, "message": "No audio file provided"}

    audio_file = request.FILES["audio"]

    # Check file size (OpenAI Whisper API has 25MB limit)
    if audio_file.size > MAX_AUDIO_SIZE_MB * 1024 * 1024:
        return {"code": -1, "message": f"Audio file too large. Maximum size is {MAX_AUDIO_SIZE_MB}MB"}

    # Check transcription quota
    transcription_tracker = TranscriptionUsageTracker(request.user)
    can_use, limit_message = transcription_tracker.can_use()
    if not can_use:
        # Record this denied attempt for analytics
        transcription_tracker.record_denied(
            story_hash=request.POST.get("story_hash", ""), request_id=request.POST.get("request_id", "")
        )
        return {"code": -1, "message": limit_message}

    # Check OpenAI API key is configured
    if not settings.OPENAI_API_KEY:
        return {"code": -1, "message": "OpenAI API key not configured"}

    try:
        client = openai.OpenAI(api_key=settings.OPENAI_API_KEY)

        logging.user(
            request.user,
            f"~BB~FGAsk AI Transcribe: ~SB{audio_file.name}~SN ({audio_file.size} bytes)",
        )

        # Transcribe using OpenAI Whisper API
        # OpenAI SDK expects a tuple of (filename, file_content, content_type) for uploaded files
        # Read the file content from Django's InMemoryUploadedFile
        audio_file.seek(0)  # Ensure we're at the start of the file
        file_tuple = (audio_file.name, audio_file.read(), audio_file.content_type)

        transcript = client.audio.transcriptions.create(model="whisper-1", file=file_tuple, language="en")

        transcribed_text = transcript.text.strip()

        # Record transcription usage
        # Duration is not easily available from the audio file without additional processing
        # We'll estimate based on file size (rough approximation: webm is ~12.5KB/sec for speech)
        estimated_duration = audio_file.size / (12.5 * 1024)
        transcription_tracker.record_usage(
            transcription_text=transcribed_text,
            duration_seconds=estimated_duration,
            story_hash=request.POST.get("story_hash", ""),
            request_id=request.POST.get("request_id", ""),
        )

        logging.user(
            request.user,
            f"~BB~FGAsk AI Transcribe: Completed ~SB{len(transcribed_text)}~SN chars",
        )

        return {"code": 1, "text": transcribed_text}

    except openai.APITimeoutError as e:
        error_msg = "OpenAI API timeout during transcription"
        logging.user(request.user, f"~BB~FGAsk AI Transcribe: ~FR~SBTimeout~SN~FG - {e}")
        return {"code": -1, "message": error_msg}

    except openai.APIError as e:
        error_msg = f"OpenAI API error during transcription: {str(e)}"
        logging.user(request.user, f"~BB~FGAsk AI Transcribe: ~FR~SBError~SN~FG - {e}")
        return {"code": -1, "message": error_msg}

    except Exception as e:
        error_msg = f"Unexpected error during transcription: {str(e)}"
        logging.user(request.user, f"~BB~FGAsk AI Transcribe: ~FR~SBUnexpected error~SN~FG - {e}")
        return {"code": -1, "message": error_msg}
