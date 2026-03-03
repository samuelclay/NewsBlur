"""AI/LLM integration for story classification and text analysis.

Sets up OpenAI and Anthropic API clients, provides story classification
via Claude tool use, and handles token counting with tiktoken.
"""

import json
import logging
import re
from html import unescape

import anthropic
import openai
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


def classify_stories_with_ai(prompt_classifier, stories, model="claude-haiku-4-5"):
    """
    Classify a list of stories using Claude's tool use.

    Args:
        prompt_classifier: User-defined prompt (MClassifierPrompt) for classification criteria
        stories: List of dictionaries containing story data with at least title and content
        model: Claude model to use

    Returns:
        Dictionary mapping story_ids to classifications: 1 (focus), 0 (neutral), -1 (hidden)
    """
    if not settings.ANTHROPIC_API_KEY:
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
