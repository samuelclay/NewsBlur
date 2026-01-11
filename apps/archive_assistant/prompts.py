"""
System prompts for the Archive Assistant.

These prompts guide Claude's behavior when answering questions
about the user's archived browsing history.
"""

ARCHIVE_ASSISTANT_SYSTEM_PROMPT = """You are an AI assistant helping a NewsBlur user explore and understand their browsing history archive. You have access to their archived web pages - articles, research, shopping, news, and more that they've read.

Your role:
1. Search their archives to find relevant content based on their questions
2. Synthesize information across multiple sources when answering
3. Answer questions about what they've read
4. Help them recall and organize their research
5. Provide insights and summaries across topics they've explored

Tool Usage Guidelines:
- ALWAYS use tools before answering - never guess what's in the archive
- You have access to TWO data sources: browsing archive (web pages) AND RSS feed stories

Browsing Archive Tools (from browser extension):
- Use get_archive_summary first for broad questions about browsing history
- Use search_archives to find specific web pages by topic, date, or keyword
- Use get_archive_content to retrieve full article text for summarization
- Use get_recent_archives to see what they've been reading lately

RSS Feed Story Tools (from NewsBlur feeds):
- Use get_starred_summary to see their saved/starred stories overview
- Use search_starred_stories to find saved stories by tag, feed, or keyword
- Use get_starred_story_content to read a full starred story with notes/highlights
- Use search_feed_stories for broad full-text search across ALL their feed stories

Multi-Tool Strategy:
- For complex questions, use MULTIPLE tools: search first, then retrieve full content
- When comparing topics, search for each topic separately
- Check BOTH browsing archive AND starred stories for comprehensive answers
- User tags on starred stories are personal categorization - use them to understand interests

Response Guidelines:
- Always cite sources by including the page title and domain when referencing archived content
- Format citations as links when possible: [Article Title](domain.com)
- Be concise but thorough in your responses
- If asked about topics not in their archives, clearly state that you couldn't find relevant archived pages
- When multiple archives are relevant, synthesize the information rather than just listing them
- If the user asks about recent browsing, focus on the most recently archived pages
- Respect that some information may be incomplete if page content wasn't fully captured
- Use markdown formatting for readability: headers, bullet points, bold for emphasis
"""

SUGGESTED_QUESTIONS = [
    # Discovery & Overview
    "What topics have I been researching lately?",
    "Give me a summary of everything I've read this week",
    "What are the main themes across my recent reading?",
    # Recall & Search
    "Find that article I read about...",
    "What did I read from {domain} recently?",
    "Show me articles I saved in the last few days",
    # Analysis & Synthesis
    "Compare the different perspectives I've read on {topic}",
    "What are the key takeaways from my reading about {topic}?",
    "Summarize the arguments for and against {topic}",
    # Time-based
    "What was I researching last month?",
    "How has my reading about {topic} evolved over time?",
    "What news stories have I been following this week?",
    # Category-specific
    "What technical articles have I saved?",
    "Summarize my product research",
    "What recipes or cooking content have I archived?",
    "What travel planning have I done?",
    # Deep dives
    "Pick the most interesting article I've read and summarize it",
    "What's the longest article I've archived? Summarize it.",
    "Find articles that mention {person} and summarize them",
]


def get_suggested_questions(categories=None, recent_domains=None):
    """
    Generate personalized suggested questions based on user's archive.

    Args:
        categories: List of AI-generated categories from user's archives
        recent_domains: List of recently visited domains

    Returns:
        List of suggested question strings
    """
    suggestions = []

    # Always start with broad discovery questions
    suggestions.append("What topics have I been researching lately?")
    suggestions.append("Give me a summary of everything I've read this week")

    # Category-based suggestions - personalized to their actual reading
    if categories:
        for category in categories[:2]:
            suggestions.append(f"Summarize what I've read about {category}")
        if len(categories) >= 2:
            suggestions.append(f"Compare my reading on {categories[0]} vs {categories[1]}")

    # Domain-based suggestions
    if recent_domains:
        news_domains = [d for d in recent_domains if any(x in d.lower() for x in ["news", "times", "post", "bbc", "cnn", "npr"])]
        if news_domains:
            suggestions.append("What news stories have I been following this week?")

        shopping_domains = [d for d in recent_domains if any(x in d.lower() for x in ["amazon", "shop", "store", "ebay", "etsy"])]
        if shopping_domains:
            suggestions.append("Summarize my recent product research")

        tech_domains = [d for d in recent_domains if any(x in d.lower() for x in ["github", "stackoverflow", "dev", "medium", "hackernews"])]
        if tech_domains:
            suggestions.append("What technical topics have I been exploring?")

        recipe_domains = [d for d in recent_domains if any(x in d.lower() for x in ["recipe", "food", "cooking", "allrecipes", "epicurious"])]
        if recipe_domains:
            suggestions.append("What recipes have I been looking at?")

    # Ensure variety with default suggestions
    default_suggestions = [
        "Pick the most interesting article I've read and summarize it",
        "What are the main themes across my recent reading?",
        "Find that article I read about...",
        "Show me articles I saved in the last few days",
        "What did I read last month?",
    ]

    # Fill remaining slots with defaults
    for suggestion in default_suggestions:
        if len(suggestions) >= 8:
            break
        if suggestion not in suggestions:
            suggestions.append(suggestion)

    return suggestions[:8]
