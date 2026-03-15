"""AI/LLM integration for story classification and text analysis.

Sets up OpenAI and Anthropic API clients, provides story classification
via Claude tool use (text-only and vision/VLM), and handles token counting with tiktoken.
"""

import base64
import json
import logging
import re
from html import unescape

import anthropic
import openai
import requests
import tiktoken
from django.conf import settings

from utils.llm_costs import LLMCostTracker


def setup_openai_model(openai_model):
    openai.api_key = settings.OPENAI_API_KEY
    try:
        encoding = tiktoken.encoding_for_model(openai_model)
    except KeyError:
        logging.debug(f"Could not find encoding for model {openai_model}, using cl100k_base")
        encoding = tiktoken.get_encoding("cl100k_base")

    return encoding


def classify_stories_with_ai(prompt_classifier, stories, model="claude-haiku-4-5", user_id=None):
    """
    Classify a list of stories using Claude's tool use.

    Args:
        prompt_classifier: User-defined prompt (MClassifierPrompt) for classification criteria
        stories: List of dictionaries containing story data with at least title and content
        model: Claude model to use
        user_id: User ID for usage tracking and billing

    Returns:
        Dictionary mapping story_ids to classifications: 1 (focus), 0 (neutral), -1 (hidden)
    """
    from apps.ask_ai.providers import AnthropicProvider

    if not AnthropicProvider().is_configured():
        logging.error("Anthropic API key not configured")
        return {story["story_id"]: 0 for story in stories}

    # Initialize Anthropic client
    client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)

    # Prepare stories for classification
    story_items = []
    for story in stories:
        story_items.append(
            {
                "id": story["story_id"],
                "title": story["story_title"],
                "excerpt": story.get("story_content", "")[:500],  # Limit content size
            }
        )

    # Define the tool for classification
    tool_definition = {
        "name": "classify_stories",
        "description": "Classify stories based on user-defined criteria",
        "input_schema": {
            "type": "object",
            "properties": {
                "classifications": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "id": {"type": "string"},
                            "classification": {
                                "type": "integer",
                                "enum": [1, 0, -1],
                                "description": "1 for focus (promote), 0 for neutral, -1 for hidden (demote)",
                            },
                            "explanation": {
                                "type": "string",
                                "description": "Brief explanation of classification",
                            },
                        },
                        "required": ["id", "classification"],
                    },
                }
            },
            "required": ["classifications"],
        },
    }

    # Create system message based on prompt type
    system_message = f"""You are a story classifier for a news reader application. Your task is to classify stories based on the user's criteria. Each story should be classified as one of:

- Focus (1): Stories that strongly match the user's interests according to their prompt
- Neutral (0): Stories that don't particularly match or contradict the user's criteria
- Hidden (-1): Stories that the user wants to hide based on their prompt

The user's classification criteria is: {prompt_classifier.prompt}

Classify each story independently. Most stories should remain neutral (0) by default.
Only classify stories as Focus (1) or Hidden (-1) if they clearly match the user's criteria.

You MUST use the classify_stories tool to return your classifications."""

    try:
        # Call the Anthropic API with tool use
        response = client.messages.create(
            model=model,
            max_tokens=1024,
            system=system_message,
            tools=[tool_definition],
            tool_choice={"type": "tool", "name": "classify_stories"},
            messages=[
                {"role": "user", "content": f"Please classify these stories: {json.dumps(story_items)}"}
            ],
        )

        # Record LLM cost
        if response.usage:
            LLMCostTracker.record_usage(
                provider="anthropic",
                model=model,
                feature="story_classification",
                input_tokens=response.usage.input_tokens,
                output_tokens=response.usage.output_tokens,
                user_id=user_id,
                metadata={"story_count": len(stories)},
            )

        # Parse the response - look for tool_use blocks
        for block in response.content:
            if block.type == "tool_use" and block.name == "classify_stories":
                try:
                    result = block.input
                    # Convert to dictionary mapping story_id to classification
                    classifications = {
                        item["id"]: item["classification"] for item in result["classifications"]
                    }
                    return classifications
                except (KeyError, TypeError) as e:
                    logging.error(f"Error parsing AI classification response: {e}")
                    return {story["story_id"]: 0 for story in stories}

        logging.error("AI did not return a valid tool use")
        return {story["story_id"]: 0 for story in stories}

    except Exception as e:
        logging.error(f"Error during AI classification: {e}")
        return {story["story_id"]: 0 for story in stories}


def _fetch_image_as_base64(url, timeout=10, max_size_bytes=5 * 1024 * 1024):
    """Download an image and return it as a base64-encoded string with its media type.

    VLMs accept images in two ways:
      1. By URL ({"type": "url", "url": "..."}) — simplest, but requires the URL to be
         publicly accessible. Won't work for images behind auth or on private networks.
      2. By base64 data ({"type": "base64", "media_type": "image/jpeg", "data": "..."}) —
         works for any image you can download, regardless of whether the VLM can reach the URL.

    We use base64 here because story images may be served through NewsBlur's signed imageproxy,
    which the VLM's servers can't access directly.

    Returns:
        Tuple of (base64_data, media_type) or (None, None) on failure
    """
    try:
        resp = requests.get(url, timeout=timeout, stream=True)
        resp.raise_for_status()

        # Check content length before downloading the full body
        content_length = resp.headers.get("Content-Length")
        if content_length and int(content_length) > max_size_bytes:
            logging.warning(f"Image too large ({content_length} bytes): {url}")
            return None, None

        # Read the image data (with size limit)
        data = resp.content
        if len(data) > max_size_bytes:
            logging.warning(f"Image too large ({len(data)} bytes): {url}")
            return None, None

        # Determine media type from Content-Type header or URL extension
        content_type = resp.headers.get("Content-Type", "")
        if "jpeg" in content_type or "jpg" in content_type:
            media_type = "image/jpeg"
        elif "png" in content_type:
            media_type = "image/png"
        elif "gif" in content_type:
            media_type = "image/gif"
        elif "webp" in content_type:
            media_type = "image/webp"
        else:
            # Default to JPEG for unknown types — Claude handles most image formats
            media_type = "image/jpeg"

        return base64.standard_b64encode(data).decode("utf-8"), media_type

    except Exception as e:
        logging.warning(f"Failed to fetch image {url}: {e}")
        return None, None


def classify_stories_with_vision(prompt_classifier, stories, model="claude-haiku-4-5", user_id=None):
    """Classify stories using Claude Vision (VLM) — analyzes both text AND images.

    This is the VLM version of classify_stories_with_ai(). The key difference:
    instead of sending only text (title + excerpt), we also send the story's images
    as part of the message content. Claude "sees" the images and classifies based on
    visual content in addition to text.

    HOW VLM MESSAGES WORK:
    ----------------------
    A normal LLM message has a string content:
        {"role": "user", "content": "What is this about?"}

    A VLM message has a LIST of content blocks — mixing text and images:
        {"role": "user", "content": [
            {"type": "text", "text": "What is in this image?"},
            {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": "..."}},
        ]}

    The model processes all blocks together, so it can reason about the text AND images
    simultaneously. This is what makes VLMs powerful — you can ask natural language
    questions about visual content.

    Args:
        prompt_classifier: MClassifierPrompt with the user's criteria (e.g., "show me food photos")
        stories: List of story dicts with story_id, story_title, story_content, image_urls
        model: Claude model ID (must support vision — Haiku 4.5, Sonnet 4, Opus 4 all do)
        user_id: User ID for usage tracking and billing

    Returns:
        Dict mapping story_id to classification: 1 (focus), 0 (neutral), -1 (hidden)
    """
    from apps.ask_ai.providers import AnthropicProvider

    if not AnthropicProvider().is_configured():
        logging.error("Anthropic API key not configured")
        return {story["story_id"]: 0 for story in stories}

    client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)

    # Same tool definition as text-only classifier — the output format is identical.
    # The only difference is in the INPUT (we add images to the message).
    tool_definition = {
        "name": "classify_stories",
        "description": "Classify stories based on user-defined criteria, considering both text and images",
        "input_schema": {
            "type": "object",
            "properties": {
                "classifications": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "id": {"type": "string"},
                            "classification": {
                                "type": "integer",
                                "enum": [1, 0, -1],
                                "description": "1 for focus (promote), 0 for neutral, -1 for hidden (demote)",
                            },
                            "explanation": {
                                "type": "string",
                                "description": "Brief explanation, referencing image content when relevant",
                            },
                        },
                        "required": ["id", "classification"],
                    },
                }
            },
            "required": ["classifications"],
        },
    }

    # System prompt: classify based on what is VISIBLE in the images, not the text.
    # Users have separate text/title classifiers for text matching — the image filter
    # is specifically for visual content (photos of food, charts, etc.).
    system_message = f"""You are a STRICT image classifier for a news reader. Classify ONLY based on what is literally, visually depicted in the image.

- Match (1): The image literally shows the described thing as the main subject
- No match (0): The image does NOT literally show the described thing

The user's image filter is: {prompt_classifier.prompt}

STRICT RULES:
1. Only match if the described thing is LITERALLY VISIBLE as the main subject of the image.
2. Do NOT match based on text, signs, logos, or words visible in the image.
3. Do NOT match based on indirect associations. For "food": a restaurant exterior, grocery store, kitchen without food, menu, or food-related business is NOT a match. Only actual food items are a match.
4. Do NOT match based on what the location might contain or sell. A photo OF a building is a photo of a building, not what's inside.
5. When in doubt, classify as no match (0). Be very conservative.

If a story has no images, classify as no match (0).

You MUST use the classify_stories tool to return your classifications."""

    # Build the multimodal message content.
    # For each story, we create text + image content blocks.
    # This is the core VLM pattern: interleaving text descriptions with image data
    # so the model can associate each image with its story context.
    content_blocks = []
    stories_with_ids = []
    max_images_per_story = 3  # Limit to control API costs (images use ~1000 tokens each)

    for story in stories:
        story_id = story["story_id"]
        stories_with_ids.append(story_id)

        # Only send the story ID — no title or text content.
        # The VLM should classify based on images alone, not be biased by text.
        content_blocks.append(
            {
                "type": "text",
                "text": f"\n--- Story ID: {story_id} ---\nImages for this story:\n",
            }
        )

        # Add image blocks for this story's images.
        # Each image becomes a separate content block with type "image".
        image_urls = story.get("image_urls", [])
        images_added = 0
        for img_url in image_urls[:max_images_per_story]:
            if not img_url:
                continue

            # Download and encode the image as base64
            b64_data, media_type = _fetch_image_as_base64(img_url)
            if b64_data:
                # This is the VLM image content block format for Claude:
                content_blocks.append(
                    {
                        "type": "image",
                        "source": {
                            "type": "base64",
                            "media_type": media_type,
                            "data": b64_data,
                        },
                    }
                )
                images_added += 1

        if images_added == 0:
            content_blocks.append({"type": "text", "text": "(No images available for this story)\n"})

    # Add final instruction
    content_blocks.append(
        {
            "type": "text",
            "text": "\nClassify all the above stories based on their text AND images.",
        }
    )

    try:
        # The API call is identical to text-only, except the user message content
        # is a list of blocks (text + images) instead of a plain string.
        response = client.messages.create(
            model=model,
            max_tokens=1024,
            system=system_message,
            tools=[tool_definition],
            tool_choice={"type": "tool", "name": "classify_stories"},
            messages=[{"role": "user", "content": content_blocks}],
        )

        if response.usage:
            LLMCostTracker.record_usage(
                provider="anthropic",
                model=model,
                feature="vision_classification",
                input_tokens=response.usage.input_tokens,
                output_tokens=response.usage.output_tokens,
                user_id=user_id,
                metadata={
                    "story_count": len(stories),
                    "has_images": True,
                },
            )

        # Parse response — same format as text-only classifier
        for block in response.content:
            if block.type == "tool_use" and block.name == "classify_stories":
                try:
                    result = block.input
                    classifications = {
                        item["id"]: item["classification"] for item in result["classifications"]
                    }
                    return classifications
                except (KeyError, TypeError) as e:
                    logging.error(f"Error parsing vision classification response: {e}")
                    return {story["story_id"]: 0 for story in stories}

        logging.error("Vision AI did not return a valid tool use")
        return {story["story_id"]: 0 for story in stories}

    except Exception as e:
        logging.error(f"Error during vision classification: {e}")
        return {story["story_id"]: 0 for story in stories}
