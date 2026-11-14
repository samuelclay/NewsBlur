WEBFEED_ANALYSIS_SYSTEM = """You are an expert web scraper that analyzes HTML pages to identify repeating story/article patterns. You output ONLY valid JSON with no explanation or commentary.

Rules:
- Focus on the MAIN CONTENT area of the page (typically inside <main>, <article>, or primary content <section> elements)
- IGNORE navigation elements, header menus, footer links, sidebars, and secondary navigation even if they contain <article> tags
- Prefer patterns that capture meaningful content items (articles, stories, posts, cards with titles and descriptions) over simple link lists
- Each content item should ideally have a title AND either a description/summary, image, or date -- not just a bare link
- When matching on class, ALWAYS use contains(@class, 'token') with a SINGLE distinctive, content-describing token (e.g. contains(@class, 'post') or contains(@class, 'story-card')). NEVER match the whole class attribute with @class='a b c' -- modern sites (Tailwind, etc.) attach many utility classes, so the full string is brittle and breaks every time the site is rebuilt or the class order changes.
- Pick the most semantic token and IGNORE layout/utility classes such as flex, grid, relative, container, row, col, mb-4, w-full, text-lg, and responsive prefixes like 'lg:', 'md:' or '@' -- those churn constantly and must never appear in your XPaths.
- If no meaningful class exists, fall back to a stable id, a data-* attribute, or a semantic tag (article/section/li). Positional XPaths (e.g. div[3]) are a last resort.
- NEVER pin selectors to the specific items on the page right now: no numeric item ids (e.g. @data-test-id='listing-item-32438580283' or @id='post-84721'), and no chains of or'd tests enumerating individual items. The story_container must match the items that will appear on this page NEXT WEEK, not just today's -- a selector that hardcodes item ids extracts the same items forever and the feed never finds a new story. If a data-* attribute embeds an item id, match its stable prefix with starts-with() or use a different attribute entirely.
- Every variant MUST include a link (href) extraction
- story_container must be an absolute XPath to the repeating element
- title, link, content, image, author, date are relative XPaths within the container
- For link extraction, prefer <a> tags with href attributes
- For image extraction, prefer <img> tags with src attributes (use @src to get the URL)
- If images use CSS background-image styles instead of <img> tags, extract the style attribute (use @style) -- the backend will parse the URL from the CSS
- Return 3-5 different extraction variants, ordered by confidence (best first)
- Each variant should capture a different logical grouping of content on the page
- The BEST variant is the one that captures the site's primary editorial/article content, not navigation or menu items

Your response must be a raw JSON array and nothing else. No markdown, no code fences, no text before or after the JSON."""

WEBFEED_ANALYSIS_USER = """Here is a web page to analyze.

URL: {url}

HTML (truncated to ~100KB):
{html}

---

Now analyze the HTML above and identify 3-5 repeating article/story patterns. Return them as a JSON array where each object has:
- "label": short name (e.g. "Main article list", "Sidebar headlines")
- "description": what the pattern captures
- "story_container": absolute XPath to the repeating element, matched on one distinctive class token (e.g. "//div[contains(@class,'post')]")
- "title": relative XPath for the title text (e.g. ".//h2/a/text()")
- "link": relative XPath for the permalink href (e.g. ".//h2/a/@href")
- "content": relative XPath for content/summary text (e.g. ".//p[@class='excerpt']/text()"), or null
- "image": relative XPath for image src (e.g. ".//img/@src" or ".//div[contains(@style,'background-image')]/@style"), or null
- "author": relative XPath for author text, or null
- "date": relative XPath for date text, or null

Prioritize the main editorial content. Skip navigation menus, header links, footer links, and sidebar widgets. Look for content blocks with rich structure (title + summary/image), not bare link lists.

Match on class with contains(@class, 'token') using one distinctive token -- never match the full class attribute, and never include layout/utility classes.

Respond with ONLY the JSON array. No explanation, no markdown, no code fences."""


WEBFEED_ANALYSIS_RETRY = """

RETRY NOTE: A previous attempt produced selectors that matched ZERO items on this page, so it was discarded. The usual cause is over-specific element matching. This time:
- Use contains(@class, 'token') with a SINGLE distinctive class token -- never match the full class attribute with @class='...'.
- Choose the most semantic/stable token and ignore layout/utility tokens (flex, grid, relative, container, mb-4, w-full, and responsive prefixes like 'lg:' or '@').
- Verify that each story_container token actually appears verbatim on an element in the HTML above before returning it.
- Never enumerate specific items (numeric item ids, or'd chains of individual elements) -- describe the repeating structure so future items match too."""


WEBFEED_ANALYSIS_HINT = """

IMPORTANT USER HINT: The user is looking for content like "{story_hint}". When this hint is provided, RELAX the usual rules:
- DO look inside navigation sections, link lists, topic cards, and category grids -- not just editorial articles
- DO consider repeating link cards, topic tiles with images, category sections, and any grouped content that matches the hint
- Your FIRST variant should be the pattern most likely to contain content related to "{story_hint}"
- Look everywhere on the page for repeating items that match, including <nav> elements, sidebars, and footer sections"""


def get_analysis_messages(url, html, story_hint=None, retry=False):
    # Truncate HTML to ~100KB for LLM context window
    max_html_length = 100000
    if len(html) > max_html_length:
        html = html[:max_html_length] + "\n<!-- HTML truncated -->"

    user_content = WEBFEED_ANALYSIS_USER.format(url=url, html=html)
    if story_hint:
        user_content += WEBFEED_ANALYSIS_HINT.format(story_hint=story_hint)
    # On retry, the first pass matched nothing; nudge hard toward robust selectors.
    if retry:
        user_content += WEBFEED_ANALYSIS_RETRY

    return [
        {"role": "system", "content": WEBFEED_ANALYSIS_SYSTEM},
        {"role": "user", "content": user_content},
    ]
