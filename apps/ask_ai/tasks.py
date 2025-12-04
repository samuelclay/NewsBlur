import json
import time
import uuid

import redis
from django.conf import settings
from django.contrib.auth.models import User

from apps.rss_feeds.models import MStory
from newsblur_web.celeryapp import app
from utils import log as logging
from utils.story_functions import html_to_text

from .models import MAskAIResponse
from .prompts import get_full_prompt
from .providers import DEFAULT_MODEL, LLM_EXCEPTIONS, MODELS, get_provider
from .usage import AskAIUsageTracker


@app.task(name="ask-ai-question", time_limit=120, soft_time_limit=110)
def AskAIQuestion(
    user_id,
    story_hash,
    question_id,
    custom_question=None,
    conversation_history=None,
    request_id=None,
    model=None,
):
    """
    Process an Ask AI question and stream the response via Redis PubSub.
    """

    start_time = time.time()
    publish_event = None
    user = None
    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)

    try:
        user = User.objects.get(pk=user_id)
        username = user.username
        request_token = request_id or str(uuid.uuid4())

        def publish(event_type, extra=None):
            payload = {
                "type": event_type,
                "story_hash": story_hash,
                "question_id": question_id,
                "request_id": request_token,
            }
            if extra:
                payload.update(extra)
            try:
                r.publish(username, f"ask_ai:{json.dumps(payload, ensure_ascii=False)}")
            except redis.RedisError:
                logging.user(user, f"~BB~FGAsk AI: ~FR~SBPublish failure~SN~FG for event ~SB{event_type}~SN")

        publish_event = publish
        publish_event("start")

        story, _ = MStory.find_story(story_hash=story_hash)
        if not story:
            error_msg = "Story not found"
            publish_event("error", {"error": error_msg})
            logging.user(user, f"~BB~FGAsk AI: ~FR~SBError~SN~FG - {error_msg} for story ~SB{story_hash}~SN")
            return {"code": -1, "message": error_msg}

        # Determine model early so it can be used for cache lookup
        model_name = model if model and model in MODELS else getattr(settings, "ASK_AI_MODEL", DEFAULT_MODEL)
        if model_name not in MODELS:
            model_name = DEFAULT_MODEL

        if not conversation_history and not custom_question:
            cached = MAskAIResponse.get_cached_response(
                user_id=user_id,
                story_hash=story_hash,
                question_id=question_id,
                custom_question=custom_question,
                model=model_name,
            )
            if cached:
                response_text = cached.response_text
                chunk_size = 50
                for i in range(0, len(response_text), chunk_size):
                    chunk = response_text[i : i + chunk_size]
                    publish_event("chunk", {"chunk": chunk})
                    time.sleep(0.05)

                # Record usage for cached responses
                tracker = AskAIUsageTracker(user)
                tracker.record_usage(
                    question_id=question_id,
                    story_hash=story_hash,
                    request_id=request_token,
                    cached=True,
                )
                usage_message = tracker.get_usage_message()

                publish_event("complete")
                if usage_message:
                    publish_event("usage", {"message": usage_message})
                logging.user(user, f"~BB~FGAsk AI: Served ~SBcached~SN response for story ~SB{story_hash}~SN")
                return {"code": 1, "message": "Cached response served", "cached": True}

        if conversation_history:
            messages = [
                {
                    "role": "system",
                    "content": "You are a helpful assistant analyzing news articles. Be direct and succinct. Do not use preambles, introductory phrases like 'Certainly!' or 'Here is the analysis', or other conversational niceties. Start directly with your analysis.",
                }
            ]
            messages.extend(conversation_history)
            logging.user(
                user,
                f"~BB~FGAsk AI: Follow-up for story ~SB{story_hash}~SN, ~SB{len(conversation_history)}~SN messages in history",
            )
        else:
            story_title = story.story_title
            story_content = html_to_text(story.story_content_str)

            try:
                full_prompt = get_full_prompt(question_id, story_title, story_content, custom_question)
            except ValueError as e:
                error_msg = str(e)
                publish_event("error", {"error": error_msg})
                logging.user(user, f"~BB~FGAsk AI: ~FR~SBError~SN~FG - {error_msg}")
                return {"code": -1, "message": error_msg}

            messages = [
                {
                    "role": "system",
                    "content": "You are a helpful assistant analyzing news articles. Be direct and succinct. Do not use preambles, introductory phrases like 'Certainly!' or 'Here is the analysis', or other conversational niceties. Start directly with your analysis.",
                },
                {"role": "user", "content": full_prompt},
            ]

        # Get provider and model ID
        provider, model_id = get_provider(model_name)

        # Check for required API key
        if not provider.is_configured():
            error_msg = f"{provider.__class__.__name__.replace('Provider', '')} API key not configured"
            publish_event("error", {"error": error_msg})
            logging.user(user, f"~BB~FGAsk AI: ~FR~SBError~SN~FG - {error_msg}")
            return {"code": -1, "message": error_msg}

        logging.user(
            user,
            f"~BB~FGAsk AI: Starting stream for story ~SB{story_hash}~SN, question ~SB{question_id}~SN, model ~SB{model_name}~SN",
        )

        full_response = []
        chunk_count = 0

        for text in provider.stream_response(messages, model_id):
            full_response.append(text)
            publish_event("chunk", {"chunk": text})
            chunk_count += 1
            if chunk_count == 1:
                logging.user(user, f"~BB~FGAsk AI: First chunk to Redis channel ~SB'{username}'~SN")

        full_response_text = "".join(full_response)

        # Record usage for live responses
        tracker = AskAIUsageTracker(user)
        tracker.record_usage(
            question_id=question_id,
            story_hash=story_hash,
            request_id=request_token,
            cached=False,
        )
        usage_message = tracker.get_usage_message()

        publish_event("complete")
        if usage_message:
            publish_event("usage", {"message": usage_message})

        logging.user(
            user,
            f"~BB~FGAsk AI: Completed for ~SB{story_hash}~SN, "
            f"~SB{len(full_response_text)}~SN chars in ~SB{time.time() - start_time:.2f}s~SN",
        )

        if not conversation_history and not custom_question:
            metadata = {
                "model": model_name,
                "question_id": question_id,
                "duration_seconds": time.time() - start_time,
                "response_length": len(full_response_text),
                "request_id": request_token,
            }

            MAskAIResponse.create_response(
                user_id=user_id,
                story_hash=story_hash,
                question_id=question_id,
                response_text=full_response_text,
                custom_question=custom_question,
                model=model_name,
                metadata=metadata,
            )

        return {
            "code": 1,
            "message": "Response completed",
            "response_length": len(full_response_text),
            "duration": time.time() - start_time,
        }

    except LLM_EXCEPTIONS as e:
        error_msg = provider.format_error(e)
        if publish_event:
            publish_event("error", {"error": error_msg})
        if user:
            logging.user(user, f"~BB~FGAsk AI: ~FR~SBError~SN~FG - {e}")
        return {"code": -1, "message": error_msg}

    except Exception as e:
        error_msg = f"Unexpected error: {str(e)}"
        if publish_event:
            publish_event("error", {"error": error_msg})
        if user:
            logging.user(user, f"~BB~FGAsk AI: ~FR~SBUnexpected error~SN~FG - {e}")
        return {"code": -1, "message": error_msg}
