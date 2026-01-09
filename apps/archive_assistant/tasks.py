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


def get_redis_pubsub_connection():
    """Get Redis connection for pubsub."""
    return redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)


@shared_task(name="archive-assistant-query")
def process_archive_query(user_id, conversation_id, query_id, query_text, model="claude-sonnet-4-20250514"):
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

        # Call Claude with tools
        response_text, tool_calls, tokens_used = _call_claude_with_tools(
            user_id, messages, model, publish_event
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

        # Publish complete event
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


def _call_claude_with_tools(user_id, messages, model, publish_event):
    """
    Call Claude API with tools and handle tool execution loop.

    Args:
        user_id: User ID for tool execution
        messages: Conversation messages
        model: Claude model to use
        publish_event: Callback to publish events (type, extra_dict)

    Returns tuple: (response_text, tool_calls, tokens_used)
    """
    import anthropic

    client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)

    tool_calls = []
    tokens_used = 0
    full_response = ""

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

            tool_calls.append(
                {
                    "tool": tool_name,
                    "input": tool_input,
                    "result_summary": f"Found {result.get('count', 0)} results"
                    if "count" in result
                    else "Retrieved content",
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

    # Extract final text response
    for block in response.content:
        if hasattr(block, "text"):
            chunk = block.text
            full_response += chunk

            # Stream the chunk
            publish_event("chunk", {"content": chunk})

    return full_response, tool_calls, tokens_used


def _generate_conversation_title(query_text):
    """Generate a short title from the first query."""
    # Simple truncation for now
    title = query_text[:50]
    if len(query_text) > 50:
        title += "..."
    return title
