"""Ask AI tasks: process user questions via LLM providers and stream responses."""

import json
import time
import uuid
from concurrent.futures import ThreadPoolExecutor, as_completed

import anthropic
import redis
from django.conf import settings
from django.contrib.auth.models import User

from apps.rss_feeds.models import MStory
from newsblur_web.celeryapp import app
from utils import log as logging
from utils.llm_costs import LLMCostTracker
from utils.story_functions import html_to_text

from .models import MAskAIResponse
from .prompts import get_deep_analysis_prompt, get_deep_system_prompt, get_full_prompt
from .providers import (
    DEFAULT_MODEL,
    LLM_EXCEPTIONS,
    MODEL_VENDORS,
    MODELS,
    get_provider,
)
from .tools import ASK_AI_DEEP_TOOLS
from .tools import execute_tool as deep_execute_tool
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
    thinking=False,
    deep=False,
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

        # Cache key differentiates thinking mode from fast mode
        cache_model_key = f"{model_name}:thinking" if thinking else model_name

        if not conversation_history and not custom_question:
            cached = MAskAIResponse.get_cached_response(
                user_id=user_id,
                story_hash=story_hash,
                question_id=question_id,
                custom_question=custom_question,
                model=cache_model_key,
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

        # Log which content source we're using
        content_source = "original text" if story.original_text_z else "story content"
        story_title = story.story_title
        story_content = html_to_text(story.original_text_str)
        logging.user(
            user,
            f"~BB~FGAsk AI: Using ~SB{content_source}~SN ({len(story_content)} chars) for story ~SB{story_hash}~SN",
        )

        if conversation_history:
            # For follow-ups, we need to include the original article as context
            article_context = f"Article Title: {story_title}\n\nArticle Content:\n{story_content}"

            messages = [
                {
                    "role": "system",
                    "content": "You are a helpful assistant analyzing news articles. Be direct and succinct. Do not use preambles, introductory phrases like 'Certainly!' or 'Here is the analysis', or other conversational niceties. Start directly with your analysis.",
                },
                {
                    "role": "user",
                    "content": f"Here is the article I want to discuss:\n\n{article_context}",
                },
            ]
            messages.extend(conversation_history)
            logging.user(
                user,
                f"~BB~FGAsk AI: Follow-up with ~SB{len(conversation_history)}~SN messages in history",
            )
        else:
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
        provider, model_id, thinking_config = get_provider(model_name, thinking=thinking)

        # Check for required API key
        if not provider.is_configured():
            error_msg = f"{provider.__class__.__name__.replace('Provider', '')} API key not configured"
            publish_event("error", {"error": error_msg})
            logging.user(user, f"~BB~FGAsk AI: ~FR~SBError~SN~FG - {error_msg}")
            return {"code": -1, "message": error_msg}

        mode_label = " (deep)" if deep else (" (thinking)" if thinking else "")
        logging.user(
            user,
            f"~BB~FGAsk AI: Starting stream for story ~SB{story_hash}~SN, question ~SB{question_id}~SN, model ~SB{model_name}{mode_label}~SN",
        )

        # Deep analysis mode: use PTC with tools (Anthropic only)
        if deep:
            feed_id = story.story_feed_id
            deep_prompt = get_deep_analysis_prompt(
                question_id, story_title, story_content, feed_id, custom_question
            )
            full_response_text, tool_calls_data, input_tokens, output_tokens = _call_deep_analysis(
                user_id, deep_prompt, model_id, publish_event
            )

            LLMCostTracker.record_usage(
                provider="anthropic",
                model=model_id,
                feature="ask_ai_deep",
                input_tokens=input_tokens,
                output_tokens=output_tokens,
                user_id=user_id,
                request_id=request_token,
                metadata={
                    "question_id": question_id,
                    "story_hash": story_hash,
                    "tool_calls": len(tool_calls_data),
                    "deep": True,
                },
            )

            # Deep mode counts as 3 uses against quota
            tracker = AskAIUsageTracker(user)
            for _ in range(3):
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
                f"~BB~FGAsk AI: Deep analysis completed for ~SB{story_hash}~SN, "
                f"~SB{len(full_response_text)}~SN chars, ~SB{len(tool_calls_data)}~SN tool calls "
                f"in ~SB{time.time() - start_time:.2f}s~SN",
            )

            return {
                "code": 1,
                "message": "Response completed",
                "response_length": len(full_response_text),
                "duration": time.time() - start_time,
                "deep": True,
                "tool_calls": len(tool_calls_data),
            }

        # Standard mode: direct LLM streaming (no tools)
        full_response = []
        chunk_count = 0

        for text in provider.stream_response(messages, model_id, thinking_config=thinking_config):
            full_response.append(text)
            publish_event("chunk", {"chunk": text})
            chunk_count += 1
            if chunk_count == 1:
                logging.user(user, f"~BB~FGAsk AI: First chunk to Redis channel ~SB'{username}'~SN")

        full_response_text = "".join(full_response)

        # Record LLM cost
        input_tokens, output_tokens = provider.get_last_usage()
        LLMCostTracker.record_usage(
            provider=MODEL_VENDORS.get(model_name, "unknown"),
            model=model_id,
            feature="ask_ai",
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            user_id=user_id,
            request_id=request_token,
            metadata={"question_id": question_id, "story_hash": story_hash},
        )

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
                "thinking": thinking,
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
                model=cache_model_key,
                metadata=metadata,
            )

        return {
            "code": 1,
            "message": "Response completed",
            "response_length": len(full_response_text),
            "duration": time.time() - start_time,
        }

    except LLM_EXCEPTIONS as e:
        error_msg = provider.format_error(e) if provider else str(e)
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


def _call_deep_analysis(user_id, user_prompt, model_id, publish_event):
    """
    Execute deep analysis using PTC (Programmatic Tool Calling).

    Claude generates code that calls search/content tools, filters results in code,
    and prints a curated summary. Only the print() output enters Claude's context.

    Args:
        user_id: User ID for tool execution
        user_prompt: The formatted deep analysis prompt
        model_id: Claude model ID to use
        publish_event: Callback for streaming events

    Returns tuple: (response_text, tool_calls, input_tokens, output_tokens)
    """
    client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)

    system_prompt = get_deep_system_prompt()
    messages = [{"role": "user", "content": user_prompt}]
    tool_calls = []
    input_tokens_total = 0
    output_tokens_total = 0
    full_response = ""
    container_id = None

    continue_loop = True

    while continue_loop:
        continue_loop = False

        create_kwargs = {
            "model": model_id,
            "max_tokens": 4096,
            "system": system_prompt,
            "tools": ASK_AI_DEEP_TOOLS,
            "messages": messages,
        }
        if container_id:
            create_kwargs["container"] = container_id

        with client.messages.stream(**create_kwargs) as stream:
            current_text = ""
            tool_use_blocks = []
            current_tool_input = ""
            current_tool_name = None
            current_tool_id = None

            for event in stream:
                if event.type == "content_block_delta":
                    if hasattr(event.delta, "text"):
                        chunk = event.delta.text
                        current_text += chunk
                        full_response += chunk
                        publish_event("chunk", {"chunk": chunk})
                    elif hasattr(event.delta, "partial_json"):
                        current_tool_input += event.delta.partial_json

                elif event.type == "content_block_start":
                    block = event.content_block
                    if hasattr(block, "type") and block.type == "tool_use":
                        current_tool_name = block.name
                        current_tool_id = block.id
                        current_tool_input = ""
                        publish_event("tool_call", {"tool": current_tool_name, "input": {}})

                elif event.type == "content_block_stop":
                    if current_tool_name and current_tool_id:
                        try:
                            tool_input = json.loads(current_tool_input) if current_tool_input else {}
                        except json.JSONDecodeError:
                            tool_input = {}

                        tool_use_blocks.append(
                            {
                                "id": current_tool_id,
                                "name": current_tool_name,
                                "input": tool_input,
                            }
                        )
                        current_tool_name = None
                        current_tool_id = None
                        current_tool_input = ""

            final_message = stream.get_final_message()
            input_tokens_total += final_message.usage.input_tokens
            output_tokens_total += final_message.usage.output_tokens

            if hasattr(final_message, "container") and final_message.container:
                container_id = final_message.container.id

        if tool_use_blocks:
            continue_loop = True

            def execute_single_tool(tool_block):
                return (tool_block, deep_execute_tool(tool_block["name"], tool_block["input"], user_id))

            tool_execution_results = {}
            with ThreadPoolExecutor(max_workers=6) as executor:
                futures = {executor.submit(execute_single_tool, block): block for block in tool_use_blocks}
                for future in as_completed(futures):
                    tool_block, result = future.result()
                    tool_execution_results[tool_block["id"]] = (tool_block, result)

            tool_results = []
            assistant_content = []

            if current_text:
                assistant_content.append({"type": "text", "text": current_text})

            # server_tool_use and code_execution_tool_result are managed by the
            # container -- we only send back tool_use blocks (external tool calls)
            # and any text blocks that preceded them.
            for block in final_message.content:
                block_type = getattr(block, "type", None)
                if block_type == "tool_use":
                    assistant_content.append(
                        {
                            "type": "tool_use",
                            "id": block.id,
                            "name": block.name,
                            "input": block.input,
                        }
                    )

            for tool_block in tool_use_blocks:
                _, result = tool_execution_results[tool_block["id"]]
                tool_name = tool_block["name"]
                tool_input = tool_block["input"]

                result_summary = _build_deep_tool_summary(tool_name, result)
                event_data = {"tool": tool_name, "summary": result_summary}
                publish_event("tool_result", event_data)

                tool_calls.append({"tool": tool_name, "input": tool_input, "result_summary": result_summary})

                tool_results.append(
                    {
                        "type": "tool_result",
                        "tool_use_id": tool_block["id"],
                        "content": json.dumps(result),
                    }
                )

            messages = messages + [{"role": "assistant", "content": assistant_content}]
            messages = messages + [{"role": "user", "content": tool_results}]

            tool_use_blocks = []

    return full_response, tool_calls, input_tokens_total, output_tokens_total


def _build_deep_tool_summary(tool_name, result):
    """Build a human-readable summary from a deep analysis tool result."""
    if tool_name == "search_feed_stories":
        count = result.get("count", 0)
        return f"Found {count} related feed {'story' if count == 1 else 'stories'}"
    elif tool_name == "get_feed_story_content":
        title = result.get("title", "story")
        return f"Reading: {title[:50]}"
    elif tool_name == "search_starred_stories":
        count = result.get("count", 0)
        return f"Found {count} saved {'story' if count == 1 else 'stories'}"
    elif tool_name == "get_starred_story_content":
        title = result.get("title", "story")
        return f"Reading: {title[:50]}"
    elif tool_name == "search_shared_stories":
        count = result.get("count", 0)
        return f"Found {count} shared {'story' if count == 1 else 'stories'}"
    elif tool_name == "get_same_feed_recent":
        count = result.get("count", 0)
        feed = result.get("feed_title", "feed")
        return f"Found {count} recent {'story' if count == 1 else 'stories'} from {feed[:30]}"
    return "Retrieved content"
