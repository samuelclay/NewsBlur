import json
import logging
import re
from html import unescape

import openai
import tiktoken
from django.conf import settings


def setup_openai_model(openai_model):
    openai.api_key = settings.OPENAI_API_KEY
    try:
        encoding = tiktoken.encoding_for_model(openai_model)
    except KeyError:
        logging.debug(f"Could not find encoding for model {openai_model}, using cl100k_base")
        encoding = tiktoken.get_encoding("cl100k_base")

    return encoding


def classify_stories_with_ai(prompt_classifier, stories, model="gpt-3.5-turbo"):
    """
    Classify a list of stories using OpenAI's function calling.

    Args:
        prompt_classifier: User-defined prompt (MClassifierPrompt) for classification criteria
        stories: List of dictionaries containing story data with at least title and content
        model: OpenAI model to use

    Returns:
        Dictionary mapping story_ids to classifications: 1 (focus), 0 (neutral), -1 (hidden)
    """
    if not settings.OPENAI_API_KEY:
        logging.error("OpenAI API key not configured")
        return {story["story_id"]: 0 for story in stories}

    # Initialize OpenAI client
    client = openai.OpenAI(api_key=settings.OPENAI_API_KEY)

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

    # Define the function for classification
    function_definition = {
        "name": "classify_stories",
        "description": "Classify stories based on user-defined criteria",
        "parameters": {
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
    system_message = f"""
    You are a story classifier for a news reader application. Your task is to classify stories 
    based on the user's criteria. Each story should be classified as one of:
    
    - Focus (1): Stories that strongly match the user's interests according to their prompt
    - Neutral (0): Stories that don't particularly match or contradict the user's criteria
    - Hidden (-1): Stories that the user wants to hide based on their prompt
    
    The user's classification criteria is: {prompt_classifier.prompt}
    
    Classify each story independently. Most stories should remain neutral (0) by default.
    Only classify stories as Focus (1) or Hidden (-1) if they clearly match the user's criteria.
    """

    try:
        # Call the OpenAI API
        response = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": system_message},
                {"role": "user", "content": f"Please classify these stories: {json.dumps(story_items)}"},
            ],
            functions=[function_definition],
            function_call={"name": "classify_stories"},
        )

        # Parse the response
        function_call = response.choices[0].message.function_call
        if function_call and function_call.name == "classify_stories":
            try:
                result = json.loads(function_call.arguments)
                # Convert to dictionary mapping story_id to classification
                classifications = {item["id"]: item["classification"] for item in result["classifications"]}
                return classifications
            except (json.JSONDecodeError, KeyError) as e:
                logging.error(f"Error parsing AI classification response: {e}")
                return {story["story_id"]: 0 for story in stories}
        else:
            logging.error("AI did not return a valid function call")
            return {story["story_id"]: 0 for story in stories}

    except Exception as e:
        logging.error(f"Error during AI classification: {e}")
        return {story["story_id"]: 0 for story in stories}
