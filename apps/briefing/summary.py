import datetime
import zlib

import anthropic
from django.conf import settings
from django.utils.encoding import smart_str

from apps.rss_feeds.models import Feed, MStory
from utils import log as logging
from utils.llm_costs import LLMCostTracker

BRIEFING_MODEL = "claude-haiku-4-5"

SYSTEM_PROMPT = """You are a news editor writing a daily briefing for a NewsBlur user.
You are given a list of stories from their RSS feeds, ranked by importance.
Write a concise editorial briefing that:

1. Opens with a brief 1-2 sentence overview of the day's most important themes
2. Groups stories into 2-4 thematic sections (e.g., "Technology", "World News", "Science")
3. For each section, write 1-2 sentences summarizing the key stories
4. Reference each story by wrapping its title in an anchor tag like:
   <a class="NB-briefing-story-link" data-story-hash="HASH">Story Title</a>

Output valid HTML. Use <h3> for section headers. Keep it under 400 words.
Do not use markdown. Do not add any preamble. Start directly with the briefing content.
Wrap everything in a <div class="NB-briefing-summary"> tag."""


def generate_briefing_summary(user_id, scored_stories, briefing_date):
    """
    Generate an AI editorial summary of the selected stories.

    Args:
        user_id: The user's ID
        scored_stories: List of (story_hash, score) tuples from scoring.py
        briefing_date: The briefing date

    Returns:
        HTML string of the briefing summary, or None on failure.
    """
    story_hashes = [h for h, _ in scored_stories]

    # apps/briefing/summary.py: Load story details from MongoDB
    stories_by_hash = {}
    for story in MStory.objects(story_hash__in=story_hashes):
        stories_by_hash[story.story_hash] = story

    # apps/briefing/summary.py: Load feed titles for context
    feed_ids = set()
    for story in stories_by_hash.values():
        feed_ids.add(story.story_feed_id)
    feeds_by_id = {}
    for feed in Feed.objects.filter(pk__in=feed_ids).only("pk", "feed_title"):
        feeds_by_id[feed.pk] = feed.feed_title

    # apps/briefing/summary.py: Build the prompt with story details
    story_lines = []
    for story_hash, score in scored_stories:
        story = stories_by_hash.get(story_hash)
        if not story:
            continue

        feed_title = feeds_by_id.get(story.story_feed_id, "Unknown Feed")
        content_excerpt = _get_content_excerpt(story, max_chars=300)

        story_lines.append(
            "- HASH: %s\n  TITLE: %s\n  FEED: %s\n  AUTHOR: %s\n  DATE: %s\n  EXCERPT: %s"
            % (
                story_hash,
                story.story_title or "Untitled",
                feed_title,
                story.story_author_name or "Unknown",
                story.story_date.strftime("%Y-%m-%d %H:%M") if story.story_date else "Unknown",
                content_excerpt,
            )
        )

    if not story_lines:
        return None

    user_prompt = "Today's date: %s\n\nStories ranked by importance:\n\n%s" % (
        briefing_date.strftime("%A, %B %d, %Y"),
        "\n\n".join(story_lines),
    )

    # apps/briefing/summary.py: Call Claude API (non-streaming for background task)
    try:
        client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)
        response = client.messages.create(
            model=BRIEFING_MODEL,
            max_tokens=2048,
            system=SYSTEM_PROMPT,
            messages=[{"role": "user", "content": user_prompt}],
        )

        summary_html = ""
        for block in response.content:
            if hasattr(block, "text"):
                summary_html += block.text

        # apps/briefing/summary.py: Track cost
        if response.usage:
            LLMCostTracker.record_usage(
                provider="anthropic",
                model=BRIEFING_MODEL,
                feature="daily_briefing",
                input_tokens=response.usage.input_tokens,
                output_tokens=response.usage.output_tokens,
                user_id=user_id,
            )

        logging.debug(
            " ---> Briefing summary generated for user %s: %s input, %s output tokens"
            % (
                user_id,
                response.usage.input_tokens if response.usage else "?",
                response.usage.output_tokens if response.usage else "?",
            )
        )

        return summary_html

    except (anthropic.APIConnectionError, anthropic.APIStatusError) as e:
        logging.error(" ---> Briefing summary failed for user %s: %s" % (user_id, str(e)))
        return None


def _get_content_excerpt(story, max_chars=300):
    """Extract a plain text excerpt from a story's content."""
    import re

    content = story.story_content
    if not content and story.story_content_z:
        try:
            content = smart_str(zlib.decompress(story.story_content_z))
        except Exception:
            content = ""

    if not content:
        return ""

    # apps/briefing/summary.py: Strip HTML tags for the excerpt
    text = re.sub(r"<[^>]+>", " ", content)
    text = re.sub(r"\s+", " ", text).strip()

    if len(text) > max_chars:
        text = text[:max_chars] + "..."

    return text
