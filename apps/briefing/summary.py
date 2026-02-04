import re
import zlib

import anthropic
from django.conf import settings
from django.utils.encoding import smart_str

from apps.rss_feeds.models import Feed, MStory
from utils import log as logging
from utils.llm_costs import LLMCostTracker

BRIEFING_MODEL = "claude-haiku-4-5"

LENGTH_INSTRUCTIONS = {
    "short": "Include only the top 1-2 sections with the most important stories. Keep it under 150 words.",
    "medium": "Include 2-4 sections. Keep each section to 1-3 sentences per story. Under 400 words total.",
    "detailed": (
        "Include all relevant sections with 2-3 sentences of analysis per story. "
        "Explain connections between stories where relevant. Up to 800 words."
    ),
}

STYLE_INSTRUCTIONS = {
    "editorial": "Write in a narrative editorial style with flowing prose that connects stories thematically.",
    "bullets": (
        "Use bullet points for each story. Group by the section headers below. "
        "Each bullet should be one sentence."
    ),
    "headlines": (
        "List each story as a headline with a single explanatory sentence beneath it. "
        "Group by the section headers below."
    ),
}


SECTION_PROMPTS = {
    "trending_unread": '"Stories you missed" — CATEGORY: trending_unread. Popular stories the reader hasn\'t read yet.',
    "long_read": '"Long reads for later" — CATEGORY: long_read. Longer articles worth setting time aside for. Use the WORD_COUNT field to judge which stories qualify as long reads relative to other stories.',
    "classifier_match": '"Based on your interests" — CATEGORY: classifier_match. Stories matching topics, authors, or feeds the reader has trained as interesting. Mention which interest matched using the MATCHES field.',
    "follow_up": '"Follow-ups" — CATEGORY: follow_up. New posts from feeds where the reader recently read other stories.',
    "trending_global": '"Trending across NewsBlur" — CATEGORY: trending_global. Widely-read stories from across the platform.',
    "duplicates": '"Common stories" — CATEGORY: duplicates. Stories covered by multiple feeds. For each story, show the shared headline then list each source\'s unique angle or perspective as sub-items.',
    "quick_catchup": '"Quick catch-up" — This is a special section. Select the 3-5 most important stories from the entire briefing and write a 1-2 sentence TL;DR for each. This section should appear first.',
    "emerging_topics": '"Emerging topics" — Look across all the stories for topics that appear multiple times or are getting increasing coverage. Group these stories under the topic and explain why it\'s trending.',
    "contrarian_views": '"Contrarian views" — Look for stories where different feeds have notably different perspectives on the same topic. Highlight the disagreement and present each side.',
}


def _build_system_prompt(summary_length="medium", summary_style="bullets", sections=None, custom_section_prompts=None):
    """Build the system prompt based on user preferences for length, style, and sections."""
    from apps.briefing.models import DEFAULT_SECTIONS

    length_instruction = LENGTH_INSTRUCTIONS.get(summary_length, LENGTH_INSTRUCTIONS["medium"])
    style_instruction = STYLE_INSTRUCTIONS.get(summary_style, STYLE_INSTRUCTIONS["bullets"])

    active_sections = sections if sections else DEFAULT_SECTIONS
    section_lines = []
    num = 1
    for key, prompt in SECTION_PROMPTS.items():
        if active_sections.get(key, False):
            section_lines.append("%d. %s" % (num, prompt))
            num += 1

    # summary.py: Add custom sections (up to 5) with user-defined prompts
    prompts = custom_section_prompts or []
    for i, prompt in enumerate(prompts):
        custom_key = "custom_%d" % (i + 1)
        if active_sections.get(custom_key, False) and prompt:
            section_lines.append(
                '%d. Custom section — The reader has requested a custom section with this prompt: "%s". '
                "Generate an appropriate section header for this content. Use your best judgment "
                "to select relevant stories from the provided list." % (num, prompt)
            )
            num += 1

    sections_text = "\n".join(section_lines) if section_lines else "Include all stories in a single section."

    return """You are a personal news editor writing a daily briefing for a NewsBlur reader.
You are given stories from their RSS feeds, each annotated with a CATEGORY indicating why
it was selected for them.

Organize the briefing into sections based on these categories. Use ONLY these section headers
(as <h3 data-section="CATEGORY_KEY"> tags, where CATEGORY_KEY is the category value like
"trending_unread" or "classifier_match"), and only include a section if there are stories for it:

%s

Within each section, briefly explain WHY these stories matter to the reader — not just what
they are about. Focus on what makes each story worth reading.

%s

%s

Reference each story by wrapping its title in an anchor tag like:
<a class="NB-briefing-story-link" data-story-hash="HASH">Story Title</a>

Output valid HTML. Use <h3 data-section="CATEGORY_KEY"> for section headers.
Do not use markdown. Do not wrap in code fences. Do not add any preamble.
Your very first character must be "<". Start directly with <div class="NB-briefing-summary">.
Wrap everything in a <div class="NB-briefing-summary"> tag.""" % (
        sections_text,
        length_instruction,
        style_instruction,
    )


def generate_briefing_summary(user_id, scored_stories, briefing_date, summary_length="medium", summary_style="bullets", sections=None, custom_section_prompts=None):
    """
    Generate an editorial summary of the selected stories.

    Args:
        user_id: The user's ID
        scored_stories: List of dicts from scoring.py with keys:
            story_hash, score, is_read, category, content_word_count, classifier_matches
        briefing_date: The briefing date
        summary_length: "short", "medium", or "detailed"
        summary_style: "editorial", "bullets", or "headlines"

    Returns:
        HTML string of the briefing summary, or None on failure.
    """
    story_hashes = [s["story_hash"] for s in scored_stories]

    stories_by_hash = {}
    for story in MStory.objects(story_hash__in=story_hashes):
        stories_by_hash[story.story_hash] = story

    feed_ids = set()
    for story in stories_by_hash.values():
        feed_ids.add(story.story_feed_id)
    feeds_by_id = {}
    for feed in Feed.objects.filter(pk__in=feed_ids).only("pk", "feed_title"):
        feeds_by_id[feed.pk] = feed.feed_title

    story_lines = []
    for scored in scored_stories:
        story_hash = scored["story_hash"]
        story = stories_by_hash.get(story_hash)
        if not story:
            continue

        feed_title = feeds_by_id.get(story.story_feed_id, "Unknown Feed")
        content_excerpt = _get_content_excerpt(story, max_chars=300)

        line = (
            "- HASH: %s\n  TITLE: %s\n  FEED: %s\n  AUTHOR: %s\n  DATE: %s\n"
            "  CATEGORY: %s\n  READ_STATUS: %s\n  WORD_COUNT: %s\n  EXCERPT: %s"
            % (
                story_hash,
                story.story_title or "Untitled",
                feed_title,
                story.story_author_name or "Unknown",
                story.story_date.strftime("%Y-%m-%d %H:%M") if story.story_date else "Unknown",
                scored["category"],
                "read" if scored["is_read"] else "unread",
                scored.get("content_word_count", 0),
                content_excerpt,
            )
        )

        if scored.get("classifier_matches"):
            line += "\n  MATCHES: %s" % ", ".join(scored["classifier_matches"])

        story_lines.append(line)

    if not story_lines:
        return None

    user_prompt = "Today's date: %s\n\nStories ranked by importance:\n\n%s" % (
        briefing_date.strftime("%A, %B %d, %Y"),
        "\n\n".join(story_lines),
    )

    try:
        system_prompt = _build_system_prompt(summary_length, summary_style, sections, custom_section_prompts)
        client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)
        response = client.messages.create(
            model=BRIEFING_MODEL,
            max_tokens=2048,
            system=system_prompt,
            messages=[{"role": "user", "content": user_prompt}],
        )

        summary_html = "".join(block.text for block in response.content if hasattr(block, "text"))

        summary_html = summary_html.strip()
        if summary_html.startswith("```"):
            summary_html = re.sub(r"^```\w*\n?", "", summary_html)
            summary_html = re.sub(r"\n?```\s*$", "", summary_html)
            summary_html = summary_html.strip()

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


def extract_section_summaries(summary_html):
    """
    Parse the briefing summary HTML into per-section blocks.

    Splits on <h3 data-section="KEY"> tags and returns a dict mapping
    section_key to the HTML for that section (including its h3 header).
    Each section is wrapped in <div class="NB-briefing-summary">.
    """
    if not summary_html:
        return {}

    # summary.py: Split on h3 tags with data-section attributes
    pattern = r'(<h3\s+data-section="([^"]+)"[^>]*>)'
    parts = re.split(pattern, summary_html)

    sections = {}
    # parts[0] is content before first h3 (the opening div wrapper, etc.)
    # Then groups of 3: (full h3 tag, section_key, content until next h3)
    i = 1
    while i < len(parts) - 2:
        h3_tag = parts[i]
        section_key = parts[i + 1]
        # Content runs until the next h3 or end
        content = parts[i + 2] if i + 2 < len(parts) else ""

        # summary.py: Strip trailing </div> that closes the outer wrapper
        content = re.sub(r'\s*</div>\s*$', '', content)

        section_html = '<div class="NB-briefing-summary">%s%s</div>' % (h3_tag, content)
        sections[section_key] = section_html
        i += 3

    return sections


def extract_section_story_hashes(section_summaries):
    """
    Extract story hashes referenced in each section's summary HTML.

    Parses <a data-story-hash="HASH"> links from the HTML and returns a dict
    mapping section_key to list of story hashes mentioned in that section.
    """
    result = {}
    for key, html in (section_summaries or {}).items():
        hashes = re.findall(r'data-story-hash="([^"]+)"', html)
        if hashes:
            result[key] = hashes
    return result


def _get_content_excerpt(story, max_chars=300):
    """Extract a plain text excerpt from a story's content."""
    content = story.story_content
    if not content and story.story_content_z:
        try:
            content = smart_str(zlib.decompress(story.story_content_z))
        except Exception:
            content = ""

    if not content:
        return ""

    text = re.sub(r"<[^>]+>", " ", content)
    text = re.sub(r"\s+", " ", text).strip()

    if len(text) > max_chars:
        text = text[:max_chars] + "..."

    return text
