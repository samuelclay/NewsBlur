from dataclasses import dataclass
from typing import Dict


@dataclass
class AskAIPrompt:
    """Represents an Ask AI prompt template."""

    id: str
    short_text: str
    full_prompt: str
    order: int


# Hardcoded prompt templates
PROMPT_TEMPLATES: Dict[str, AskAIPrompt] = {
    "sentence": AskAIPrompt(
        id="sentence",
        short_text="Summarize in one sentence",
        full_prompt="""Please provide a concise one-sentence summary of the following article.
Focus on the main point or most important information.

Title: {story_title}

Content:
{story_content}

Provide only the summary sentence, without any preamble or explanation.""",
        order=1,
    ),
    "bullets": AskAIPrompt(
        id="bullets",
        short_text="Summarize in bullet points",
        full_prompt="""Please summarize the key points of the following article as bullet points.
Include the 3-5 most important facts or ideas.

Title: {story_title}

Content:
{story_content}

Provide only the bullet points, without any preamble or explanation.""",
        order=2,
    ),
    "paragraph": AskAIPrompt(
        id="paragraph",
        short_text="Summarize in a paragraph",
        full_prompt="""Please provide a comprehensive paragraph summary of the following article.
Include the main points and key details in 3-5 sentences.

Title: {story_title}

Content:
{story_content}

Provide only the summary paragraph, without any preamble or explanation.""",
        order=3,
    ),
    "context": AskAIPrompt(
        id="context",
        short_text="What's the context and background?",
        full_prompt="""Please explain the context and background information for the following article.
Help the reader understand the broader situation, relevant history, and why this story matters.

Title: {story_title}

Content:
{story_content}

Provide only the context and background explanation, without any preamble or introductory phrases.""",
        order=4,
    ),
    "people": AskAIPrompt(
        id="people",
        short_text="Identify key people and relationships",
        full_prompt="""Please identify the key people mentioned in the following article and explain their relationships and roles.
Include relevant details about who they are and why they matter to this story.

Title: {story_title}

Content:
{story_content}

Provide only the analysis of key people and their relationships, without any preamble or introductory phrases.""",
        order=5,
    ),
    "arguments": AskAIPrompt(
        id="arguments",
        short_text="What are the main arguments?",
        full_prompt="""Please identify and explain the main arguments or positions presented in the following article.
Include different perspectives if multiple viewpoints are discussed.

Title: {story_title}

Content:
{story_content}

Provide only the analysis of the main arguments, without any preamble or introductory phrases.""",
        order=6,
    ),
    "factcheck": AskAIPrompt(
        id="factcheck",
        short_text="Fact check this story",
        full_prompt="""Please analyze the factual claims made in the following article.
Identify key claims and note any that may need verification or context.
Note: You should indicate if you cannot verify claims without additional sources.

Title: {story_title}

Content:
{story_content}

Provide only your fact-checking analysis, without any preamble or introductory phrases.""",
        order=7,
    ),
}


def get_prompt(prompt_id: str) -> AskAIPrompt:
    """Get a prompt template by ID."""
    return PROMPT_TEMPLATES.get(prompt_id)


def get_full_prompt(prompt_id: str, story_title: str, story_content: str, custom_question: str = None) -> str:
    """
    Build the complete prompt for the LLM.

    Args:
        prompt_id: ID of the prompt template
        story_title: Title of the story
        story_content: Content of the story
        custom_question: Optional custom question from user

    Returns:
        Complete formatted prompt string
    """
    if prompt_id == "custom" and custom_question:
        return f"""Please answer the following question about this article:

Question: {custom_question}

Title: {story_title}

Content:
{story_content}

Provide only your answer to the question, without any preamble or introductory phrases."""

    prompt_template = get_prompt(prompt_id)
    if not prompt_template:
        raise ValueError(f"Unknown prompt_id: {prompt_id}")

    return prompt_template.full_prompt.format(story_title=story_title, story_content=story_content)


def get_prompts_for_frontend() -> list:
    """
    Get all prompts formatted for frontend JavaScript consumption.

    Returns:
        List of dicts with id, short_text, and order
    """
    prompts = sorted(PROMPT_TEMPLATES.values(), key=lambda p: p.order)
    return [{"id": p.id, "short_text": p.short_text, "order": p.order} for p in prompts]
