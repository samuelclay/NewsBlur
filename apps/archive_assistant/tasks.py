"""
Celery tasks for the Archive Assistant.

Handles async processing of AI queries with streaming responses via Redis PubSub.
Uses Anthropic's streaming API for real-time response streaming with tool support.
"""

import json
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime

import anthropic
import redis
from celery import shared_task
from django.conf import settings
from django.contrib.auth.models import User

from apps.archive_assistant.models import (
    MArchiveAssistantUsage,
    MArchiveConversation,
    MArchiveQuery,
)
from apps.archive_assistant.prompts import get_system_prompt
from apps.archive_assistant.tools import (
    ARCHIVE_TOOLS,
    CODE_EXECUTION_TOOL,
    execute_tool,
)
from utils import log as logging
from utils.llm_costs import LLMCostTracker

# Character limit for non-premium users before truncation
FREE_RESPONSE_CHAR_LIMIT = 300


def get_redis_pubsub_connection():
    """Get Redis connection for pubsub."""
    return redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)


@shared_task(name="archive-assistant-query")
def process_archive_query(
    user_id, conversation_id, query_id, query_text, model="claude-sonnet-4-5", is_premium_archive=True
):
    """
    Process an Archive Assistant query using Claude with tools.

    This task:
    1. Loads conversation history
    2. Calls Claude with the system prompt and tools
    3. Executes any tool calls
    4. Streams the response via Redis PubSub
    5. Saves the final response

    Args:
        user_id: User ID
        conversation_id: Conversation ID (ObjectId as string)
        query_id: Query ID (ObjectId as string)
        query_text: The user's question
        model: Claude model to use
        is_premium_archive: Whether user has premium archive subscription (full responses)
    """
    r = get_redis_pubsub_connection()

    # Get username for Redis channel (Socket.IO subscribes to username channel)
    try:
        user = User.objects.get(pk=user_id)
        channel = user.username
    except User.DoesNotExist:
        logging.error(f"Archive Assistant: User {user_id} not found")
        return

    def publish_event(event_type, extra=None):
        """Publish event with archive_assistant: prefix for Node.js routing."""
        payload = {
            "type": event_type,
            "query_id": query_id,
            "conversation_id": conversation_id,
        }
        if extra:
            payload.update(extra)
        r.publish(channel, f"archive_assistant:{json.dumps(payload, ensure_ascii=False)}")

    start_time = time.time()

    try:
        # Publish start event
        publish_event("start")

        # Get the query object
        try:
            query = MArchiveQuery.objects.get(id=query_id)
        except MArchiveQuery.DoesNotExist:
            publish_event("error", {"error": "Query not found"})
            return

        # Get conversation history for context
        history_messages = _get_conversation_history(conversation_id, limit=10)

        # Build messages for Claude
        messages = history_messages + [{"role": "user", "content": query_text}]

        # Call Claude with tools (truncates response for non-premium users)
        (
            response_text,
            tool_calls,
            tokens_used,
            input_tokens,
            output_tokens,
            was_truncated,
        ) = _call_claude_with_tools(user_id, messages, model, publish_event, is_premium_archive)

        # Calculate duration
        duration_ms = int((time.time() - start_time) * 1000)

        # Record LLM cost
        LLMCostTracker.record_usage(
            provider="anthropic",
            model=model,
            feature="archive_assistant",
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            user_id=user_id,
            request_id=query_id,
            metadata={"tool_calls": len(tool_calls), "was_truncated": was_truncated},
        )

        # Save the response
        query.set_response(response_text)
        query.duration_ms = duration_ms
        query.tokens_used = tokens_used
        query.tool_calls = tool_calls
        query.save()

        # Update conversation
        try:
            conversation = MArchiveConversation.objects.get(id=conversation_id)
            conversation.last_activity = datetime.now()
            if not conversation.title and response_text:
                # Generate title from first response
                conversation.title = _generate_conversation_title(query_text)
            conversation.save()
        except MArchiveConversation.DoesNotExist:
            pass

        # Record usage
        MArchiveAssistantUsage.record_usage(user_id, model, tokens_used, source="live")

        # Publish complete event (only if not truncated - truncated event acts as completion)
        if not was_truncated:
            publish_event("complete", {"duration_ms": duration_ms, "tokens_used": tokens_used})

    except Exception as e:
        logging.error(f"Archive Assistant query error: {e}")
        publish_event("error", {"error": str(e)})

        # Save error to query
        try:
            query = MArchiveQuery.objects.get(id=query_id)
            query.error = str(e)
            query.save()
        except Exception:
            pass


def _get_conversation_history(conversation_id, limit=10):
    """Get previous messages in the conversation for context."""
    messages = []

    queries = MArchiveQuery.objects(conversation_id=conversation_id).order_by("-query_date").limit(limit)

    # Reverse to get chronological order
    for query in reversed(list(queries)):
        messages.append({"role": "user", "content": query.query_text})
        response = query.get_response()
        if response:
            messages.append({"role": "assistant", "content": response})

    return messages


def _call_claude_with_tools(user_id, messages, model, publish_event, is_premium_archive=True):
    """
    Call Claude API with tools using Programmatic Tool Calling (PTC).

    With PTC, Claude generates Python code that calls tools as async functions inside a
    sandboxed container. Intermediate tool results stay in the container and don't enter
    Claude's context -- only the final print() output does. This reduces token usage by
    40-70% on complex queries.

    Tool calls from the code container still pause execution and come back to us as
    regular tool_use blocks (with caller.type == "code_execution_20260120"), so the UI
    tool status pills still work.

    Falls back to traditional tool calling if PTC encounters errors.

    Args:
        user_id: User ID for tool execution
        messages: Conversation messages
        model: Claude model to use
        publish_event: Callback to publish events (type, extra_dict)
        is_premium_archive: Whether user has premium archive (no truncation)

    Returns tuple: (response_text, tool_calls, tokens_used, input_tokens, output_tokens, was_truncated)
    """
    try:
        return _call_claude_with_ptc(user_id, messages, model, publish_event, is_premium_archive)
    except Exception as e:
        logging.info(f"Archive Assistant: PTC failed ({e}), falling back to traditional tool calling")
        return _call_claude_traditional(user_id, messages, model, publish_event, is_premium_archive)


def _call_claude_with_ptc(user_id, messages, model, publish_event, is_premium_archive=True):
    """
    PTC implementation: Claude generates code that calls tools as async functions.
    """
    client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)

    tool_calls = []
    tokens_used = 0
    input_tokens_total = 0
    output_tokens_total = 0
    full_response = ""
    was_truncated = False
    total_chars = 0
    container_id = None

    system_prompt = get_system_prompt()

    # Build tools list with code execution tool
    tools = [CODE_EXECUTION_TOOL] + ARCHIVE_TOOLS

    # Track if we need to continue (tool results to send back)
    continue_loop = True

    while continue_loop:
        continue_loop = False

        # Build create kwargs, include container if we have one from a previous turn
        create_kwargs = {
            "model": model,
            "max_tokens": 4096,
            "system": system_prompt,
            "tools": tools,
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
            current_tool_caller = None

            for event in stream:
                if event.type == "content_block_delta":
                    if hasattr(event.delta, "text"):
                        chunk = event.delta.text

                        # Handle truncation for non-premium
                        if not is_premium_archive:
                            remaining = FREE_RESPONSE_CHAR_LIMIT - total_chars
                            if remaining <= 0:
                                publish_event("truncated", {"reason": "premium_required"})
                                was_truncated = True
                                break
                            elif len(chunk) > remaining:
                                truncated = chunk[:remaining]
                                last_space = truncated.rfind(" ")
                                if last_space > remaining // 2:
                                    truncated = truncated[:last_space]
                                current_text += truncated
                                full_response += truncated
                                total_chars += len(truncated)
                                publish_event("chunk", {"content": truncated})
                                publish_event("truncated", {"reason": "premium_required"})
                                was_truncated = True
                                break

                        current_text += chunk
                        full_response += chunk
                        total_chars += len(chunk)
                        publish_event("chunk", {"content": chunk})

                    elif hasattr(event.delta, "partial_json"):
                        current_tool_input += event.delta.partial_json

                elif event.type == "content_block_start":
                    block = event.content_block
                    if hasattr(block, "type"):
                        if block.type == "tool_use":
                            current_tool_name = block.name
                            current_tool_id = block.id
                            current_tool_input = ""
                            # Check if this tool call came from code execution
                            current_tool_caller = getattr(block, "caller", None)
                            publish_event("tool_call", {"tool": current_tool_name, "input": {}})
                        elif block.type == "server_tool_use":
                            # Claude's generated code block -- no UI event needed
                            pass

                elif event.type == "content_block_stop":
                    if current_tool_name and current_tool_id:
                        try:
                            tool_input = json.loads(current_tool_input) if current_tool_input else {}
                        except json.JSONDecodeError:
                            tool_input = {}

                        caller_type = None
                        if current_tool_caller and hasattr(current_tool_caller, "type"):
                            caller_type = current_tool_caller.type

                        tool_use_blocks.append(
                            {
                                "id": current_tool_id,
                                "name": current_tool_name,
                                "input": tool_input,
                                "caller_type": caller_type,
                            }
                        )
                        current_tool_name = None
                        current_tool_id = None
                        current_tool_input = ""
                        current_tool_caller = None

                if was_truncated:
                    break

            # Get final message for usage info and container ID
            final_message = stream.get_final_message()
            input_tokens_total += final_message.usage.input_tokens
            output_tokens_total += final_message.usage.output_tokens
            tokens_used += final_message.usage.input_tokens + final_message.usage.output_tokens

            # Capture container ID for subsequent turns
            if hasattr(final_message, "container") and final_message.container:
                container_id = final_message.container.id

        if was_truncated:
            break

        # If we have tool calls (from code execution or direct), execute them
        if tool_use_blocks:
            continue_loop = True

            def execute_single_tool(tool_block):
                return (tool_block, execute_tool(tool_block["name"], tool_block["input"], user_id))

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

            # Reconstruct assistant content blocks for the next API turn.
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

                result_summary, preview = _build_tool_summary(tool_name, result)

                event_data = {"tool": tool_name, "summary": result_summary}
                if preview:
                    event_data["preview"] = preview
                publish_event("tool_result", event_data)

                tool_call_data = {
                    "tool": tool_name,
                    "input": tool_input,
                    "result_summary": result_summary,
                }
                if preview:
                    tool_call_data["preview"] = preview
                tool_calls.append(tool_call_data)

                tool_results.append(
                    {
                        "type": "tool_result",
                        "tool_use_id": tool_block["id"],
                        "content": json.dumps(result),
                    }
                )

            # Continue conversation with tool results
            messages = messages + [{"role": "assistant", "content": assistant_content}]
            messages = messages + [{"role": "user", "content": tool_results}]

            tool_use_blocks = []

    return full_response, tool_calls, tokens_used, input_tokens_total, output_tokens_total, was_truncated


def _call_claude_traditional(user_id, messages, model, publish_event, is_premium_archive=True):
    """
    Traditional tool calling fallback (no PTC). Used when PTC fails.
    """
    client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)

    tool_calls = []
    tokens_used = 0
    input_tokens_total = 0
    output_tokens_total = 0
    full_response = ""
    was_truncated = False
    total_chars = 0

    system_prompt = get_system_prompt()

    # Use tools without allowed_callers and without code_execution tool
    tools_without_ptc = []
    for tool in ARCHIVE_TOOLS:
        tool_copy = {k: v for k, v in tool.items() if k != "allowed_callers"}
        tools_without_ptc.append(tool_copy)

    continue_with_tools = True

    while continue_with_tools:
        continue_with_tools = False

        with client.messages.stream(
            model=model,
            max_tokens=4096,
            system=system_prompt,
            tools=tools_without_ptc,
            messages=messages,
        ) as stream:
            current_text = ""
            tool_use_blocks = []
            current_tool_input = ""
            current_tool_name = None
            current_tool_id = None

            for event in stream:
                if event.type == "content_block_delta":
                    if hasattr(event.delta, "text"):
                        chunk = event.delta.text

                        if not is_premium_archive:
                            remaining = FREE_RESPONSE_CHAR_LIMIT - total_chars
                            if remaining <= 0:
                                publish_event("truncated", {"reason": "premium_required"})
                                was_truncated = True
                                break
                            elif len(chunk) > remaining:
                                truncated = chunk[:remaining]
                                last_space = truncated.rfind(" ")
                                if last_space > remaining // 2:
                                    truncated = truncated[:last_space]
                                current_text += truncated
                                full_response += truncated
                                total_chars += len(truncated)
                                publish_event("chunk", {"content": truncated})
                                publish_event("truncated", {"reason": "premium_required"})
                                was_truncated = True
                                break

                        current_text += chunk
                        full_response += chunk
                        total_chars += len(chunk)
                        publish_event("chunk", {"content": chunk})

                    elif hasattr(event.delta, "partial_json"):
                        current_tool_input += event.delta.partial_json

                elif event.type == "content_block_start":
                    if event.content_block.type == "tool_use":
                        current_tool_name = event.content_block.name
                        current_tool_id = event.content_block.id
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

                if was_truncated:
                    break

            final_message = stream.get_final_message()
            input_tokens_total += final_message.usage.input_tokens
            output_tokens_total += final_message.usage.output_tokens
            tokens_used += final_message.usage.input_tokens + final_message.usage.output_tokens

        if was_truncated:
            break

        if tool_use_blocks:
            continue_with_tools = True

            def execute_single_tool(tool_block):
                return (tool_block, execute_tool(tool_block["name"], tool_block["input"], user_id))

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

            for tool_block in tool_use_blocks:
                _, result = tool_execution_results[tool_block["id"]]
                tool_name = tool_block["name"]
                tool_input = tool_block["input"]

                assistant_content.append(
                    {
                        "type": "tool_use",
                        "id": tool_block["id"],
                        "name": tool_name,
                        "input": tool_input,
                    }
                )

                result_summary, preview = _build_tool_summary(tool_name, result)

                event_data = {"tool": tool_name, "summary": result_summary}
                if preview:
                    event_data["preview"] = preview
                publish_event("tool_result", event_data)

                tool_call_data = {
                    "tool": tool_name,
                    "input": tool_input,
                    "result_summary": result_summary,
                }
                if preview:
                    tool_call_data["preview"] = preview
                tool_calls.append(tool_call_data)

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

    return full_response, tool_calls, tokens_used, input_tokens_total, output_tokens_total, was_truncated


def _build_tool_summary(tool_name, result):
    """
    Build a human-readable summary and preview from tool result.

    Returns tuple: (summary_string, preview_list_or_none)
    """
    preview = None

    if tool_name == "search_archives":
        count = result.get("count", 0)
        summary = f"Found {count} matching {'article' if count == 1 else 'articles'}"
        archives = result.get("archives", [])[:3]
        if archives:
            preview = [a.get("title", "Untitled")[:60] for a in archives]
    elif tool_name == "get_archive_content":
        title = result.get("title", "article")
        summary = f"Reading: {title[:50]}"
    elif tool_name == "get_archive_summary":
        archive_count = result.get("total_archives", 0)
        summary = f"Archive: {archive_count} {'page' if archive_count == 1 else 'pages'}"
    elif tool_name == "get_recent_archives":
        count = len(result.get("archives", []))
        summary = f"Found {count} recent {'page' if count == 1 else 'pages'}"
        archives = result.get("archives", [])[:3]
        if archives:
            preview = [a.get("title", "Untitled")[:60] for a in archives]
    elif tool_name == "search_starred_stories":
        count = result.get("count", 0)
        summary = f"Found {count} saved {'story' if count == 1 else 'stories'}"
        stories = result.get("stories", [])[:3]
        if stories:
            preview = [s.get("title", "Untitled")[:60] for s in stories]
    elif tool_name == "get_starred_story_content":
        title = result.get("title", "story")
        summary = f"Reading: {title[:50]}"
    elif tool_name == "get_starred_summary":
        saved_count = result.get("total_starred", 0)
        summary = f"Saved: {saved_count} {'story' if saved_count == 1 else 'stories'}"
    elif tool_name == "search_feed_stories":
        count = result.get("count", 0)
        summary = f"Found {count} feed {'story' if count == 1 else 'stories'}"
        stories = result.get("stories", [])[:3]
        if stories:
            preview = [s.get("title", "Untitled")[:60] for s in stories]
    elif tool_name == "get_feed_story_content":
        title = result.get("title", "story")
        summary = f"Reading: {title[:50]}"
    elif tool_name == "search_shared_stories":
        count = result.get("count", 0)
        summary = f"Found {count} shared {'story' if count == 1 else 'stories'}"
        stories = result.get("stories", [])[:3]
        if stories:
            preview = []
            for s in stories:
                title = s.get("title", "Untitled")[:50]
                sharer = s.get("sharer", "")
                if sharer:
                    preview.append(f"{title} (via {sharer})")
                else:
                    preview.append(title)
    else:
        summary = "Retrieved content"

    return summary, preview


def _generate_conversation_title(query_text):
    """Generate a short title from the first query."""
    # Simple truncation for now
    title = query_text[:50]
    if len(query_text) > 50:
        title += "..."
    return title
