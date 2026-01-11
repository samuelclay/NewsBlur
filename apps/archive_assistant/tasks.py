"""
Celery tasks for the Archive Assistant.

Handles async processing of AI queries with streaming responses via Redis PubSub.
"""

import json
import time
from datetime import datetime

import redis
from celery import shared_task
from django.conf import settings
from django.contrib.auth.models import User

from apps.archive_assistant.models import MArchiveConversation, MArchiveQuery, MArchiveAssistantUsage
from apps.archive_assistant.prompts import ARCHIVE_ASSISTANT_SYSTEM_PROMPT
from apps.archive_assistant.tools import ARCHIVE_TOOLS, execute_tool
from utils import log as logging

# Character limit for non-premium users before truncation
FREE_RESPONSE_CHAR_LIMIT = 300


def get_redis_pubsub_connection():
    """Get Redis connection for pubsub."""
    return redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)


@shared_task(name="archive-assistant-query")
def process_archive_query(
    user_id, conversation_id, query_id, query_text, model="claude-sonnet-4-20250514", is_premium_archive=True
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
        response_text, tool_calls, tokens_used, was_truncated = _call_claude_with_tools(
            user_id, messages, model, publish_event, is_premium_archive
        )

        # Calculate duration
        duration_ms = int((time.time() - start_time) * 1000)

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
    Call Claude API with tools and handle tool execution loop.

    Args:
        user_id: User ID for tool execution
        messages: Conversation messages
        model: Claude model to use
        publish_event: Callback to publish events (type, extra_dict)
        is_premium_archive: Whether user has premium archive (no truncation)

    Returns tuple: (response_text, tool_calls, tokens_used, was_truncated)
    """
    import anthropic

    client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)

    tool_calls = []
    tokens_used = 0
    full_response = ""
    was_truncated = False

    # Initial request with tools
    response = client.messages.create(
        model=model,
        max_tokens=4096,
        system=ARCHIVE_ASSISTANT_SYSTEM_PROMPT,
        tools=ARCHIVE_TOOLS,
        messages=messages,
    )

    tokens_used += response.usage.input_tokens + response.usage.output_tokens

    # Handle tool use loop
    while response.stop_reason == "tool_use":
        # Extract tool calls from response
        tool_use_blocks = [block for block in response.content if block.type == "tool_use"]

        # Execute each tool
        tool_results = []
        for tool_block in tool_use_blocks:
            tool_name = tool_block.name
            tool_input = tool_block.input

            # Publish tool call event
            publish_event("tool_call", {"tool": tool_name, "input": tool_input})

            # Execute tool
            result = execute_tool(tool_name, tool_input, user_id)

            # Build result summary and preview for user visibility
            preview = None
            if tool_name == "search_archives":
                count = result.get("count", 0)
                result_summary = f"Found {count} matching articles"
                # Preview: first 3 article titles
                archives = result.get("archives", [])[:3]
                if archives:
                    preview = [a.get("title", "Untitled")[:60] for a in archives]
            elif tool_name == "get_archive_content":
                title = result.get("title", "article")
                result_summary = f"Reading: {title[:50]}"
            elif tool_name == "get_archive_summary":
                result_summary = f"Archive: {result.get('total_archives', 0)} pages"
            elif tool_name == "get_recent_archives":
                count = len(result.get("archives", []))
                result_summary = f"Found {count} recent pages"
                # Preview: first 3 recent titles
                archives = result.get("archives", [])[:3]
                if archives:
                    preview = [a.get("title", "Untitled")[:60] for a in archives]
            # RSS feed story tools
            elif tool_name == "search_starred_stories":
                count = result.get("count", 0)
                result_summary = f"Found {count} starred stories"
                # Preview: first 3 story titles
                stories = result.get("stories", [])[:3]
                if stories:
                    preview = [s.get("title", "Untitled")[:60] for s in stories]
            elif tool_name == "get_starred_story_content":
                title = result.get("title", "story")
                result_summary = f"Reading: {title[:50]}"
            elif tool_name == "get_starred_summary":
                result_summary = f"Starred: {result.get('total_starred', 0)} stories"
            elif tool_name == "search_feed_stories":
                count = result.get("count", 0)
                result_summary = f"Found {count} feed stories"
                # Preview: first 3 story titles
                stories = result.get("stories", [])[:3]
                if stories:
                    preview = [s.get("title", "Untitled")[:60] for s in stories]
            else:
                result_summary = "Retrieved content"

            # Publish tool result event with optional preview
            event_data = {"tool": tool_name, "summary": result_summary}
            if preview:
                event_data["preview"] = preview
            publish_event("tool_result", event_data)

            tool_calls.append(
                {
                    "tool": tool_name,
                    "input": tool_input,
                    "result_summary": result_summary,
                }
            )

            tool_results.append(
                {
                    "type": "tool_result",
                    "tool_use_id": tool_block.id,
                    "content": json.dumps(result),
                }
            )

        # Continue conversation with tool results
        messages = messages + [{"role": "assistant", "content": response.content}]
        messages = messages + [{"role": "user", "content": tool_results}]

        response = client.messages.create(
            model=model,
            max_tokens=4096,
            system=ARCHIVE_ASSISTANT_SYSTEM_PROMPT,
            tools=ARCHIVE_TOOLS,
            messages=messages,
        )

        tokens_used += response.usage.input_tokens + response.usage.output_tokens

    # Extract final text response (with truncation for non-premium users)
    total_chars = 0
    for block in response.content:
        if hasattr(block, "text"):
            chunk = block.text

            # For non-premium users, enforce character limit
            if not is_premium_archive:
                remaining = FREE_RESPONSE_CHAR_LIMIT - total_chars
                if remaining <= 0:
                    # Already at limit, publish truncated and stop
                    publish_event("truncated", {"reason": "premium_required"})
                    was_truncated = True
                    break
                elif len(chunk) > remaining:
                    # Truncate at word boundary
                    truncated_chunk = chunk[:remaining]
                    # Try to cut at a word boundary
                    last_space = truncated_chunk.rfind(" ")
                    if last_space > remaining // 2:
                        truncated_chunk = truncated_chunk[:last_space]
                    full_response += truncated_chunk
                    total_chars += len(truncated_chunk)
                    publish_event("chunk", {"content": truncated_chunk})
                    publish_event("truncated", {"reason": "premium_required"})
                    was_truncated = True
                    break

            full_response += chunk
            total_chars += len(chunk)
            publish_event("chunk", {"content": chunk})

    return full_response, tool_calls, tokens_used, was_truncated


def _generate_conversation_title(query_text):
    """Generate a short title from the first query."""
    # Simple truncation for now
    title = query_text[:50]
    if len(query_text) > 50:
        title += "..."
    return title
