import logging
import time

import openai
import redis
from django.conf import settings
from django.contrib.auth.models import User

from apps.rss_feeds.models import MStory
from newsblur_web.celeryapp import app
from utils import log as logging

from .models import MAskAIResponse
from .prompts import get_full_prompt


@app.task(name="ask-ai-question", queue="ask_ai", time_limit=120, soft_time_limit=110)
def AskAIQuestion(user_id, story_hash, question_id, custom_question=None, conversation_history=None):
    """
    Process an Ask AI question and stream the response via Redis PubSub.

    Args:
        user_id: User ID
        story_hash: Story hash
        question_id: Question ID (e.g., "sentence", "bullets", "custom")
        custom_question: Optional custom question text
        conversation_history: Optional list of previous conversation messages for follow-ups

    Returns:
        Dict with response metadata
    """
    start_time = time.time()

    try:
        # Get user
        user = User.objects.get(pk=user_id)
        username = user.username

        # Get Redis PubSub client
        r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)

        # Publish start event (include question_id to differentiate multiple requests for same story)
        r.publish(username, f"ask_ai:start:{story_hash}:{question_id}")

        # Get story
        story, _ = MStory.find_story(story_hash=story_hash)
        if not story:
            error_msg = "Story not found"
            r.publish(username, f"ask_ai:error:{story_hash}:{question_id}:{error_msg}")
            logging.user(user, f"~FRAsk AI error: {error_msg} for story {story_hash}")
            return {"code": -1, "message": error_msg}

        # Check for cached response (optional optimization)
        cached = MAskAIResponse.get_cached_response(
            user_id=user_id, story_hash=story_hash, question_id=question_id, custom_question=custom_question
        )
        if cached and not custom_question:
            # Stream cached response in chunks
            response_text = cached.response_text
            chunk_size = 50  # Characters per chunk
            for i in range(0, len(response_text), chunk_size):
                chunk = response_text[i : i + chunk_size]
                r.publish(username, f"ask_ai:chunk:{story_hash}:{question_id}:{chunk}")
                time.sleep(0.05)  # Small delay to simulate streaming

            r.publish(username, f"ask_ai:complete:{story_hash}:{question_id}")
            logging.user(user, f"~FGAsk AI: Served cached response for story {story_hash}")
            return {"code": 1, "message": "Cached response served", "cached": True}

        # Build messages for OpenAI API
        if conversation_history:
            # Follow-up: use existing conversation history
            messages = [{"role": "system", "content": "You are a helpful assistant analyzing news articles."}]
            messages.extend(conversation_history)
            logging.user(
                user,
                f"~FBAsk AI: Follow-up question for story {story_hash}, "
                f"{len(conversation_history)} messages in history",
            )
        else:
            # Initial question: build prompt with story content
            story_title = story.story_title
            story_content = story.story_content_str  # Use property to decompress content_z

            try:
                full_prompt = get_full_prompt(question_id, story_title, story_content, custom_question)
            except ValueError as e:
                error_msg = str(e)
                r.publish(username, f"ask_ai:error:{story_hash}:{question_id}:{error_msg}")
                logging.user(user, f"~FRAsk AI error: {error_msg}")
                return {"code": -1, "message": error_msg}

            messages = [
                {"role": "system", "content": "You are a helpful assistant analyzing news articles."},
                {"role": "user", "content": full_prompt},
            ]

        # Initialize OpenAI client
        if not settings.OPENAI_API_KEY:
            error_msg = "OpenAI API key not configured"
            r.publish(username, f"ask_ai:error:{story_hash}:{question_id}:{error_msg}")
            logging.user(user, f"~FRAsk AI error: {error_msg}")
            return {"code": -1, "message": error_msg}

        client = openai.OpenAI(api_key=settings.OPENAI_API_KEY)

        # Call OpenAI API with streaming
        logging.user(
            user, f"~FBAsk AI: Starting streaming response for story {story_hash}, question {question_id}"
        )

        response = client.chat.completions.create(
            model="gpt-5",
            messages=messages,
            stream=True,
        )

        # Stream chunks to Redis PubSub
        full_response = []
        chunk_count = 0
        for chunk in response:
            if chunk.choices[0].delta.content:
                chunk_text = chunk.choices[0].delta.content
                full_response.append(chunk_text)
                # Publish each chunk (include question_id to route to correct view)
                result = r.publish(username, f"ask_ai:chunk:{story_hash}:{question_id}:{chunk_text}")
                chunk_count += 1
                if chunk_count == 1:
                    logging.user(
                        user, f"~FBPublished first chunk to Redis channel '{username}', subscribers: {result}"
                    )

        # Complete response
        full_response_text = "".join(full_response)
        complete_result = r.publish(username, f"ask_ai:complete:{story_hash}:{question_id}")
        logging.user(
            user,
            f"~FBPublished {chunk_count} chunks total, complete message subscribers: {complete_result}",
        )

        # Save response to cache
        metadata = {
            "model": "gpt-5",
            "question_id": question_id,
            "duration_seconds": time.time() - start_time,
            "response_length": len(full_response_text),
        }

        MAskAIResponse.create_response(
            user_id=user_id,
            story_hash=story_hash,
            question_id=question_id,
            response_text=full_response_text,
            custom_question=custom_question,
            metadata=metadata,
        )

        logging.user(
            user,
            f"~FGAsk AI: Completed streaming response for story {story_hash}, "
            f"{len(full_response_text)} chars in {time.time() - start_time:.2f}s",
        )

        return {
            "code": 1,
            "message": "Response completed",
            "response_length": len(full_response_text),
            "duration": time.time() - start_time,
        }

    except openai.APITimeoutError as e:
        error_msg = "OpenAI API timeout"
        r.publish(username, f"ask_ai:error:{story_hash}:{question_id}:{error_msg}")
        logging.user(user, f"~FRAsk AI timeout: {e}")
        return {"code": -1, "message": error_msg}

    except openai.APIError as e:
        error_msg = f"OpenAI API error: {str(e)}"
        r.publish(username, f"ask_ai:error:{story_hash}:{question_id}:{error_msg}")
        logging.user(user, f"~FRAsk AI error: {e}")
        return {"code": -1, "message": error_msg}

    except Exception as e:
        error_msg = f"Unexpected error: {str(e)}"
        r.publish(username, f"ask_ai:error:{story_hash}:{question_id}:{error_msg}")
        logging.user(user, f"~FRAsk AI unexpected error: {e}")
        return {"code": -1, "message": error_msg}
