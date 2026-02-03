WEBFEED_ANALYSIS_SYSTEM = """You are an expert web scraper that analyzes HTML pages to identify repeating story/article patterns. You generate XPath expressions to extract structured content from web pages.

Rules:
- Focus on the MAIN CONTENT area of the page (typically inside <main>, <article>, or primary content <section> elements)
- IGNORE navigation elements, header menus, footer links, sidebars, and secondary navigation even if they contain <article> tags
- Prefer patterns that capture meaningful content items (articles, stories, posts, cards with titles and descriptions) over simple link lists
- Each content item should ideally have a title AND either a description/summary, image, or date -- not just a bare link
- Prefer stable attributes (id, class, data-* attributes) over positional XPaths
- Every variant MUST include a link (href) extraction
- story_container must be an absolute XPath to the repeating element
- title, link, content, image, author, date are relative XPaths within the container
- For link extraction, prefer <a> tags with href attributes
- For image extraction, prefer <img> tags with src attributes (use @src to get the URL)
- Return 3-5 different extraction variants, ordered by confidence (best first)
- Each variant should capture a different logical grouping of content on the page
- The BEST variant is the one that captures the site's primary editorial/article content, not navigation or menu items"""

WEBFEED_ANALYSIS_USER = """Analyze this HTML page and identify repeating article/story patterns. Return 3-5 XPath variant sets as a JSON array.

Each variant object must have:
- "label": short name (e.g. "Main article list", "Sidebar headlines")
- "description": what the pattern captures
- "story_container": absolute XPath to the repeating element (e.g. "//div[@class='post']")
- "title": relative XPath for the title text (e.g. ".//h2/a/text()")
- "link": relative XPath for the permalink href (e.g. ".//h2/a/@href")
- "content": relative XPath for content/summary text (e.g. ".//p[@class='excerpt']/text()"), or null if not available
- "image": relative XPath for image src (e.g. ".//img/@src"), or null if not available
- "author": relative XPath for author text, or null if not available
- "date": relative XPath for date text, or null if not available

IMPORTANT: Prioritize the main editorial content of the page. Skip navigation menus, header links, footer links, and sidebar widgets. Look for content blocks that have rich structure (title + summary/image), not bare link lists.

Return ONLY a JSON array with no markdown formatting, no code fences, no explanation. Just the raw JSON array.

URL: {url}

HTML (truncated to ~100KB):
{html}"""


WEBFEED_ANALYSIS_HINT = """

IMPORTANT USER HINT: The user is looking for content like "{story_hint}". When this hint is provided, RELAX the usual rules:
- DO look inside navigation sections, link lists, topic cards, and category grids -- not just editorial articles
- DO consider repeating link cards, topic tiles with images, category sections, and any grouped content that matches the hint
- Your FIRST variant should be the pattern most likely to contain content related to "{story_hint}"
- Look everywhere on the page for repeating items that match, including <nav> elements, sidebars, and footer sections"""


def get_analysis_messages(url, html, story_hint=None):
    # Truncate HTML to ~100KB for LLM context window
    max_html_length = 100000
    if len(html) > max_html_length:
        html = html[:max_html_length] + "\n<!-- HTML truncated -->"

    user_content = WEBFEED_ANALYSIS_USER.format(url=url, html=html)
    if story_hint:
        user_content += WEBFEED_ANALYSIS_HINT.format(story_hint=story_hint)

    return [
        {"role": "system", "content": WEBFEED_ANALYSIS_SYSTEM},
        {"role": "user", "content": user_content},
    ]
