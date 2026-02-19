import html as html_mod
import re
import zlib

from django.conf import settings
from django.utils.encoding import smart_str

from apps.rss_feeds.models import Feed, MStory
from utils import log as logging
from utils.llm_costs import LLMCostTracker


def normalize_section_key(key):
    """
    Normalize a section key to match VALID_SECTION_KEYS.

    1. Lowercase and strip whitespace
    2. Replace hyphens with underscores
    3. Collapse multiple underscores to single
    4. Fuzzy match to closest valid key if no exact match

    Returns normalized key if valid, None if no match found.
    """
    from apps.briefing.models import VALID_SECTION_KEYS

    if not key:
        return None

    # Basic normalization
    normalized = key.lower().strip()
    normalized = normalized.replace("-", "_")
    normalized = re.sub(r"_+", "_", normalized)  # Collapse multiple underscores
    normalized = normalized.strip("_")  # Remove leading/trailing underscores

    # Exact match after normalization
    if normalized in VALID_SECTION_KEYS:
        return normalized

    # Fuzzy match: find closest valid key by removing all separators and comparing
    key_no_sep = normalized.replace("_", "")
    for valid_key in VALID_SECTION_KEYS:
        if valid_key.replace("_", "") == key_no_sep:
            return valid_key

    # No match found - reject this key
    return None


LENGTH_INSTRUCTIONS = {
    "short": (
        "Include ALL sections listed above that have relevant stories, but keep each story to a single "
        "sentence or headline. Under 300 words total."
    ),
    "medium": (
        "Include ALL sections listed above that have relevant stories. "
        "Keep each story to 1-2 sentences. Under 600 words total."
    ),
    "detailed": (
        "Include ALL sections listed above that have relevant stories. "
        "Write 2-3 sentences of analysis per story. Explain connections between stories where relevant. "
        "Up to 1000 words."
    ),
}

STYLE_INSTRUCTIONS = {
    "editorial": (
        "Write in a narrative editorial style with flowing prose that connects stories thematically. "
        "Wrap each story paragraph in a <p> tag. Do NOT use <ul> or <li> tags."
    ),
    "bullets": (
        "Write each story as a concise one-sentence summary. Group by the section headers below. "
        "Wrap each story in its own <p> tag. Do NOT use <ul> or <li> tags."
    ),
    "headlines": (
        "List each story as a headline with a single explanatory sentence beneath it. "
        "Group by the section headers below. "
        "Wrap each story in its own <p> tag. Do NOT use <ul> or <li> tags."
    ),
}


SECTION_PROMPTS = {
    "trending_unread": '"Stories you missed" — CATEGORY: trending_unread. Popular stories the reader hasn\'t read yet.',
    "long_read": '"Long reads for later" — CATEGORY: long_read. Longer articles worth setting time aside for. Use the WORD_COUNT field to judge which stories qualify as long reads relative to other stories.',
    "classifier_match": (
        '"Based on your interests" — CATEGORY: classifier_match. '
        "Stories matching topics, authors, or feeds the reader has trained as interesting. "
        "After each story link, include ALL matching classifiers from the MATCHES field as pills. "
        "For each match in MATCHES, output this exact HTML: "
        '<span class="NB-classifier NB-classifier-TYPE NB-classifier-like NB-briefing-classifier">'
        '<div class="NB-classifier-icon-like"></div>'
        "<label><b>TYPE_TITLE: </b><span>VALUE</span></label>"
        "</span> "
        "where TYPE is the prefix before the colon (feed, author, tag, or title), "
        "TYPE_TITLE is the ALL CAPS version (SITE for feed, AUTHOR, TAG, or TITLE), "
        "and VALUE is the text after the colon. Include all matches, not just the first one."
    ),
    "follow_up": '"Follow-ups" — CATEGORY: follow_up. New posts from feeds where the reader recently read other stories.',
    "trending_global": '"Trending across NewsBlur" — CATEGORY: trending_global. Widely-read stories from across the platform.',
    "duplicates": '"Common stories" — CATEGORY: duplicates. Stories covered by multiple feeds. For each story, show the shared headline then list each source\'s unique angle or perspective as sub-items.',
    "quick_catchup": '"Quick catch-up" — KEY: quick_catchup. This is a special section. Select the 3-5 most important stories from the entire briefing and write a 1-2 sentence TL;DR for each. Link to each story using the anchor tag format specified below. This section should appear first.',
    "emerging_topics": '"Emerging topics" — CATEGORY: emerging_topics. Look across all the stories for topics that appear multiple times or are getting increasing coverage. Group these stories under the topic and explain why it\'s trending.',
    "contrarian_views": '"Contrarian views" — CATEGORY: contrarian_views. Look for stories where different feeds have notably different perspectives on the same topic. Highlight the disagreement and present each side.',
}


def _build_system_prompt(
    summary_length="medium", summary_style="bullets", sections=None, custom_section_prompts=None
):
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
                "%d. Keyword section (KEY: %s) — The reader has a keyword section that matches stories "
                'with these keywords: "%s". Generate a section header based on the keywords. '
                "ONLY include stories whose CATEGORY field is set to %s."
                % (num, custom_key, prompt, custom_key)
            )
            num += 1

    sections_text = "\n".join(section_lines) if section_lines else "Include all stories in a single section."

    return """You are a personal news editor writing a daily briefing for a NewsBlur reader.
You are given stories from their RSS feeds, each annotated with a CATEGORY indicating why
it was selected for them.

Organize the briefing into sections based on these categories. Use ONLY these section headers
(as <h3 data-section="CATEGORY_KEY"> tags, where CATEGORY_KEY is the category value like
"trending_unread" or "classifier_match"). You MUST include every section listed below if there
are stories that match it. Do not omit sections to save space:

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


def generate_briefing_summary(
    user_id,
    scored_stories,
    briefing_date,
    summary_length="medium",
    summary_style="bullets",
    sections=None,
    custom_section_prompts=None,
    model=None,
):
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

    # summary.py: Remap story categories for disabled sections to "trending_global" so the
    # LLM doesn't see category annotations for sections it shouldn't create.
    from apps.briefing.models import DEFAULT_SECTIONS

    active_sections = sections if sections else DEFAULT_SECTIONS
    category_overrides = {}
    for scored in scored_stories:
        category = scored.get("category", "trending_global")
        if category.startswith("custom_") or category == "trending_global":
            continue
        if not active_sections.get(category, False):
            category_overrides[scored["story_hash"]] = "trending_global"

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
                category_overrides.get(story_hash, scored["category"]),
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
        from apps.ask_ai.providers import (
            BRIEFING_MODELS,
            DEFAULT_BRIEFING_MODEL,
            LLM_EXCEPTIONS,
            get_briefing_provider,
        )

        model_name = model if model and model in BRIEFING_MODELS else DEFAULT_BRIEFING_MODEL
        provider, model_id = get_briefing_provider(model_name)

        # summary.py: Fall back to default if the chosen provider's API key isn't configured
        if not provider.is_configured():
            if model_name != DEFAULT_BRIEFING_MODEL:
                provider, model_id = get_briefing_provider(DEFAULT_BRIEFING_MODEL)
                model_name = DEFAULT_BRIEFING_MODEL
            if not provider.is_configured():
                logging.error(" ---> Briefing summary failed for user %s: no API key configured" % user_id)
                return None

        system_prompt = _build_system_prompt(summary_length, summary_style, sections, custom_section_prompts)
        # summary.py: Scale max_tokens based on story/section count to avoid truncation
        num_sections = sum(1 for v in (sections or {}).values() if v)
        max_tokens = min(1024 + (len(scored_stories) * 80) + (num_sections * 100), 4096)

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ]

        summary_html = provider.generate(messages, model_id, max_tokens=max_tokens)

        summary_html = summary_html.strip()
        if summary_html.startswith("```"):
            summary_html = re.sub(r"^```\w*\n?", "", summary_html)
            summary_html = re.sub(r"\n?```\s*$", "", summary_html)
            summary_html = summary_html.strip()

        input_tokens, output_tokens = provider.get_last_usage()
        model_config = BRIEFING_MODELS.get(model_name, {})
        vendor = model_config.get("vendor", "unknown")
        LLMCostTracker.record_usage(
            provider=vendor,
            model=model_id,
            feature="daily_briefing",
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            user_id=user_id,
        )

        logging.debug(
            " ---> Briefing summary generated for user %s: %s input, %s output tokens (model: %s)"
            % (user_id, input_tokens, output_tokens, model_name)
        )

        metadata = {
            "model_name": model_name,
            "display_name": model_config.get("display_name", model_name),
            "input_tokens": input_tokens,
            "output_tokens": output_tokens,
        }

        return summary_html, metadata

    except LLM_EXCEPTIONS as e:
        logging.error(" ---> Briefing summary failed for user %s: %s" % (user_id, str(e)))
        return None, None


def extract_section_summaries(summary_html):
    """
    Parse the briefing summary HTML into per-section blocks.

    Splits on <h3 data-section="KEY"> tags and returns a dict mapping
    section_key to the HTML for that section (including its h3 header).
    Each section is wrapped in <div class="NB-briefing-summary">.
    """
    if not summary_html:
        return {}

    # summary.py: Split on h3 tags with data-section attributes.
    # Use [^>]*? before data-section so we match even if the LLM adds other
    # attributes (class, style) before data-section in the opening tag.
    pattern = r'(<h3\s[^>]*?data-section="([^"]+)"[^>]*>)'
    parts = re.split(pattern, summary_html)

    sections = {}
    # parts[0] is content before first h3 (the opening div wrapper, etc.)
    # Then groups of 3: (full h3 tag, section_key, content until next h3)
    i = 1
    while i < len(parts) - 2:
        h3_tag = parts[i]
        raw_section_key = parts[i + 1]

        # summary.py: Normalize and validate section key
        section_key = normalize_section_key(raw_section_key)
        if section_key is None:
            logging.warning(" ---> Briefing: rejecting invalid section key '%s'" % raw_section_key)
            i += 3
            continue

        # summary.py: Update h3 tag to use normalized key if it changed
        if section_key != raw_section_key:
            h3_tag = re.sub(r'data-section="[^"]+"', 'data-section="%s"' % section_key, h3_tag)

        # Content runs until the next h3 or end
        content = parts[i + 2] if i + 2 < len(parts) else ""

        # summary.py: Strip trailing </div> that closes the outer wrapper
        content = re.sub(r"\s*</div>\s*$", "", content)

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


BRIEFING_SECTION_ICONS = {
    "trending_unread": "indicator-unread-gray.svg",
    "long_read": "scroll.svg",
    "classifier_match": "train.svg",
    "follow_up": "boomerang.svg",
    "trending_global": "discover.svg",
    "duplicates": "venn.svg",
    "quick_catchup": "pulse.svg",
    "emerging_topics": "growth-rocket-gray.svg",
    "contrarian_views": "stack.svg",
    "custom_1": "prompt.svg",
    "custom_2": "prompt.svg",
    "custom_3": "prompt.svg",
    "custom_4": "prompt.svg",
    "custom_5": "prompt.svg",
}


def embed_briefing_icons(summary_html, scored_stories):
    """
    Post-process briefing summary HTML to embed feed favicons, section icons,
    and inline styles for email-compatible rendering. Uses inline data URIs
    (base64-encoded) so icons render without network requests, and inline CSS
    so classifier pills and layout look correct in email clients that strip
    class-based styles.
    """
    import base64
    import os

    from apps.rss_feeds.models import MFeedIcon

    if not summary_html:
        return summary_html

    icons_dir = os.path.join(
        os.path.dirname(os.path.dirname(os.path.dirname(__file__))),
        "media",
        "img",
        "icons",
        "nouns",
    )
    icon_data_cache = {}

    def _get_icon_data_uri(icon_file):
        if icon_file in icon_data_cache:
            return icon_data_cache[icon_file]
        icon_path = os.path.join(icons_dir, icon_file)
        try:
            with open(icon_path, "rb") as f:
                svg_data = base64.b64encode(f.read()).decode("ascii")
            data_uri = "data:image/svg+xml;base64,%s" % svg_data
        except FileNotFoundError:
            data_uri = None
        icon_data_cache[icon_file] = data_uri
        return data_uri

    # --- Phase 1: Build story_hash -> favicon data URI mapping ---

    story_hashes = [s["story_hash"] for s in scored_stories]
    stories_by_hash = {}
    for story in MStory.objects(story_hash__in=story_hashes):
        stories_by_hash[story.story_hash] = story

    feed_ids = set(s.story_feed_id for s in stories_by_hash.values())

    favicon_data_map = {}
    for icon in MFeedIcon.objects.filter(feed_id__in=feed_ids):
        if icon.data:
            favicon_data_map[icon.feed_id] = "data:image/png;base64,%s" % icon.data

    favicon_map = {}
    for story_hash, story in stories_by_hash.items():
        data_uri = favicon_data_map.get(story.story_feed_id)
        if data_uri:
            favicon_map[story_hash] = data_uri

    # Build story_hash -> feed_title mapping for favicon title attributes
    feed_title_map = {}
    feeds_by_id = {}
    for feed_obj in Feed.objects.filter(pk__in=feed_ids):
        feeds_by_id[feed_obj.pk] = feed_obj.feed_title
    for story_hash, story in stories_by_hash.items():
        title = feeds_by_id.get(story.story_feed_id)
        if title:
            feed_title_map[story_hash] = title

    # --- Phase 2: Style wrapper div ---

    wrapper_style = (
        "font-family:'Helvetica Neue',Arial,sans-serif;" "font-size:18px;line-height:1.5;color:#333;"
    )
    summary_html = re.sub(
        r'(<div\s+class="NB-briefing-summary")([^>]*>)',
        lambda m: '%s%s style="%s">' % (m.group(1), m.group(2).rstrip(">"), wrapper_style),
        summary_html,
    )

    # --- Phase 3: Style <ul> tags — remove disc bullets for favicon-based layout ---

    ul_style = "list-style:none;margin:0 0 16px 0;padding:0 0 0 22px;"
    summary_html = re.sub(
        r"<ul(?P<attrs>[^>]*)>",
        lambda m: '<ul%s style="%s">' % (m.group("attrs"), ul_style),
        summary_html,
    )

    # --- Phase 4: Style <li> tags — clean spacing, no bottom border ---

    li_style = "margin:0 0 12px 0;padding:0;line-height:1.5;"
    summary_html = re.sub(
        r"<li(?P<attrs>[^>]*)>",
        lambda m: '<li%s style="%s">' % (m.group("attrs"), li_style),
        summary_html,
    )

    # --- Phase 4b: Style <p> tags — consistent spacing for editorial/headlines ---

    p_style = "margin:0 0 12px 0;padding:0 0 0 22px;line-height:1.5;"
    summary_html = re.sub(
        r"<p(?P<attrs>[^>]*)>",
        lambda m: '<p%s style="%s">' % (m.group("attrs"), p_style),
        summary_html,
    )

    # --- Phase 5: Embed favicons BEFORE story links as visual bullets ---

    favicon_style = "width:16px;height:16px;border-radius:2px;margin:0;vertical-align:top;"

    def _replace_story_link(match):
        tag = match.group(0)
        story_hash = match.group(1)

        # summary.py: Add href to <a> tag so links work in email and look clickable on web
        href = "%s/briefing?story=%s" % (settings.NEWSBLUR_URL, story_hash)
        tag = tag.replace(
            'class="NB-briefing-story-link"',
            'href="%s" class="NB-briefing-story-link"' % href,
        )

        url = favicon_map.get(story_hash)
        if not url:
            return tag
        title_attr = ""
        feed_title = feed_title_map.get(story_hash)
        if feed_title:
            title_attr = ' title="%s"' % html_mod.escape(feed_title, quote=True)
        img = '<img src="%s" class="NB-briefing-inline-favicon" style="%s"%s>' % (
            url,
            favicon_style,
            title_attr,
        )
        return img + tag

    summary_html = re.sub(
        r'<a\s[^>]*data-story-hash="([^"]+)"[^>]*>',
        _replace_story_link,
        summary_html,
    )

    # --- Phase 5b: Wrap favicon + text in table layout for email alignment ---

    def _tablify_li(match):
        li_tag = match.group(1)
        content = match.group(2)
        favicon_match = re.match(
            r"(\s*<img[^>]*NB-briefing-inline-favicon[^>]*>)\s*(.*)",
            content,
            re.DOTALL,
        )
        if not favicon_match:
            return match.group(0)
        favicon_img = favicon_match.group(1)
        rest = favicon_match.group(2)
        return (
            '%s<table cellpadding="0" cellspacing="0" border="0" style="width:100%%;">'
            "<tr>"
            '<td style="width:22px;vertical-align:top;padding-top:0;">%s</td>'
            '<td style="vertical-align:top;">%s</td>'
            "</tr></table></li>" % (li_tag, favicon_img, rest)
        )

    summary_html = re.sub(
        r"(<li[^>]*>)(.*?)</li>",
        _tablify_li,
        summary_html,
        flags=re.DOTALL,
    )

    # --- Phase 5c: Wrap favicon + text in table layout for <p> tags (editorial/headlines) ---

    def _tablify_p(match):
        p_tag = match.group(1)
        content = match.group(2)
        favicon_match = re.match(
            r"(\s*<img[^>]*NB-briefing-inline-favicon[^>]*>)\s*(.*)",
            content,
            re.DOTALL,
        )
        if not favicon_match:
            return match.group(0)
        favicon_img = favicon_match.group(1)
        rest = favicon_match.group(2)
        # summary.py: Convert <p> to <div> because <table> cannot nest inside <p>.
        # Browsers auto-close <p> before block elements, causing a blank <p> that
        # offsets the favicon and breaks font inheritance.
        div_tag = re.sub(r"^<p\b", "<div", p_tag)
        return (
            '%s<table cellpadding="0" cellspacing="0" border="0" style="width:100%%;">'
            "<tr>"
            '<td style="width:22px;vertical-align:top;padding-top:0;">%s</td>'
            '<td style="vertical-align:top;">%s</td>'
            "</tr></table></div>" % (div_tag, favicon_img, rest)
        )

    summary_html = re.sub(
        r"(<p[^>]*>)(.*?)</p>",
        _tablify_p,
        summary_html,
        flags=re.DOTALL,
    )

    # --- Phase 6: Style classifier pills with inline CSS ---

    classifier_pill_style = (
        "display:inline-block;background-color:#34912E;"
        "border:1px solid #202020;border-radius:14px;"
        "padding:1px 8px;font-size:11px;line-height:16px;"
        "margin:0 4px 0 0;white-space:nowrap;vertical-align:text-bottom;"
        "text-decoration:none;"
    )
    classifier_label_style = "color:white;text-decoration:none;"
    classifier_b_style = "color:rgba(255,255,255,0.7);font-weight:normal;text-decoration:none;"
    classifier_value_style = "color:white;text-shadow:1px 1px 0 rgba(0,0,0,0.5);text-decoration:none;"

    def _style_classifier_block(match):
        block = match.group(0)
        block = block.replace(
            'class="NB-classifier',
            'style="%s" class="NB-classifier' % classifier_pill_style,
            1,
        )
        block = block.replace("<label>", '<label style="%s">' % classifier_label_style)
        block = block.replace("<b>", '<b style="%s">' % classifier_b_style)
        block = re.sub(
            r"(<label[^>]*>.*?)<span>",
            lambda m: m.group(1) + '<span style="%s">' % classifier_value_style,
            block,
        )
        return block

    summary_html = re.sub(
        r'<span\s+class="[^"]*NB-briefing-classifier[^"]*">.*?</label>\s*</span>',
        _style_classifier_block,
        summary_html,
        flags=re.DOTALL,
    )

    # --- Phase 7: Replace classifier icon <div> with inline thumbs-up <img> ---

    thumbs_up_path = os.path.join(icons_dir, "thumbs-up.svg")
    try:
        with open(thumbs_up_path, "rb") as f:
            thumbs_up_svg = f.read()
        thumbs_up_svg = thumbs_up_svg.replace(b'fill="#FFC021"', b'fill="#FFFFFF"')
        thumbs_up_b64 = base64.b64encode(thumbs_up_svg).decode("ascii")
        thumbs_up_data_uri = "data:image/svg+xml;base64,%s" % thumbs_up_b64
    except FileNotFoundError:
        thumbs_up_data_uri = None

    if thumbs_up_data_uri:
        thumbs_up_style = (
            "display:inline-block;width:12px;height:12px;" "vertical-align:middle;margin:0 3px 0 0;"
        )
        thumbs_up_img = '<img src="%s" class="NB-classifier-icon-like" style="%s" alt="">' % (
            thumbs_up_data_uri,
            thumbs_up_style,
        )
        summary_html = re.sub(
            r'<div\s+class="NB-classifier-icon-like"[^>]*>\s*</div>',
            thumbs_up_img,
            summary_html,
        )

    # --- Phase 7b: Override auto-linked text inside classifier pills ---
    # Mail.app auto-links domain names (e.g. "kottke.org") inside classifier
    # pills, turning them blue/underlined. Style any <a> tags inside pills to
    # keep white text with no underline.
    auto_link_style = "color:white;text-decoration:none;"

    def _fix_autolinked_classifiers(match):
        block = match.group(0)
        block = re.sub(
            r"<a\b([^>]*)>",
            lambda m: '<a%s style="%s">' % (m.group(1), auto_link_style),
            block,
        )
        return block

    summary_html = re.sub(
        r"<span\s[^>]*NB-briefing-classifier[^>]*>.*?</span>",
        _fix_autolinked_classifiers,
        summary_html,
        flags=re.DOTALL,
    )

    # --- Phase 8: Style <h3> section headers and embed section icons ---

    h3_style = (
        "font-size:16px;font-weight:bold;color:#2d5273;"
        "margin:24px 0 10px 0;padding-bottom:6px;"
        "border-bottom:2px solid #e8e8e8;"
    )
    section_icon_style = (
        "display:inline-block;width:1em;height:1em;" "vertical-align:-0.1em;margin:0 0.3em 0 0;"
    )

    def _replace_section_header(match):
        tag = match.group(0)
        section_key = match.group(1)
        icon_file = BRIEFING_SECTION_ICONS.get(section_key, "briefing.svg")
        data_uri = _get_icon_data_uri(icon_file)
        styled_tag = tag.replace(">", ' style="%s">' % h3_style, 1)
        if not data_uri:
            return styled_tag
        img = '<img src="%s" class="NB-briefing-section-icon" style="%s">' % (
            data_uri,
            section_icon_style,
        )
        return styled_tag + img

    summary_html = re.sub(
        r'<h3\s[^>]*data-section="([^"]+)"[^>]*>',
        _replace_section_header,
        summary_html,
    )

    return summary_html


def filter_disabled_sections(summary_html, active_sections):
    """
    Remove sections from briefing HTML that correspond to disabled sections.
    Parses via extract_section_summaries and rebuilds with only allowed sections.
    """
    if not summary_html or not active_sections:
        return summary_html

    sections = extract_section_summaries(summary_html)
    if not sections:
        return summary_html

    allowed = {k for k, v in active_sections.items() if v}
    # Always keep trending_global as the fallback section
    allowed.add("trending_global")

    filtered = {k: v for k, v in sections.items() if k in allowed}
    if not filtered:
        return summary_html

    # Rebuild: concatenate section HTML blocks
    parts = []
    for section_html in filtered.values():
        inner = re.sub(r'^<div class="NB-briefing-summary">', "", section_html)
        inner = re.sub(r"</div>$", "", inner)
        parts.append(inner)

    return '<div class="NB-briefing-summary">%s</div>' % "".join(parts)


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
