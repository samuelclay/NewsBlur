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

Guidelines:
- Always cite sources by including the page title and domain when referencing archived content
- Be concise but thorough in your responses
- If asked about topics not in their archives, clearly state that you couldn't find relevant archived pages
- When multiple archives are relevant, synthesize the information rather than just listing them
- If the user asks about recent browsing, focus on the most recently archived pages
- Respect that some information may be incomplete if page content wasn't fully captured

You have access to tools to search the user's archive. Use them to find relevant content before answering questions.
"""

SUGGESTED_QUESTIONS = [
    "What topics have I been researching lately?",
    "Summarize what I've been reading about {topic}",
    "What are the key points from the articles I saved about {topic}?",
    "Compare the different perspectives I've read on {topic}",
    "What shopping research have I done recently?",
    "What news stories have I been following?",
    "Find articles I read about {topic} last week",
    "What were the main arguments in the articles about {topic}?",
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

    # Generic suggestions
    suggestions.append("What topics have I been researching lately?")
    suggestions.append("Summarize my recent reading activity")

    # Category-based suggestions
    if categories:
        for category in categories[:3]:
            suggestions.append(f"What have I been reading about {category}?")

    # Domain-based suggestions
    if recent_domains:
        if any("news" in d or "times" in d or "post" in d for d in recent_domains):
            suggestions.append("What news stories have I been following?")
        if any("amazon" in d or "shop" in d or "store" in d for d in recent_domains):
            suggestions.append("What products have I been researching?")
        if any("github" in d or "stackoverflow" in d for d in recent_domains):
            suggestions.append("What technical topics have I been exploring?")

    # Ensure we have at least 5 suggestions
    default_suggestions = [
        "What are the most interesting articles I've read this week?",
        "Help me find an article I read recently about...",
        "What research have I done on...",
    ]

    while len(suggestions) < 5 and default_suggestions:
        suggestions.append(default_suggestions.pop(0))

    return suggestions[:8]  # Return max 8 suggestions
