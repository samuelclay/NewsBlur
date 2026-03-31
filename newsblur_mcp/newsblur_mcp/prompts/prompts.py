"""MCP Prompt Templates for common NewsBlur workflows."""

from newsblur_mcp.server import mcp


@mcp.prompt()
def newsblur_daily_briefing(focus_only: bool = False) -> str:
    """Summarize today's unread stories across all feeds, grouped by folder."""
    focus_clause = " Only include stories scored as 'focus' by trained classifiers." if focus_only else ""
    return (
        "Use the newsblur_list_feeds tool to get all feeds and folders. "
        "Then use newsblur_get_stories for each folder to load unread stories. "
        f"Summarize the stories grouped by folder, highlighting the most important items.{focus_clause} "
        "Include the story title, source feed, and a 1-2 sentence summary for each. "
        "At the end, provide a count of total unread stories and how many you covered."
    )


@mcp.prompt()
def newsblur_triage_inbox(folder: str | None = None, tags: str | None = None) -> str:
    """Review unread stories and categorize them: save interesting ones, mark the rest as read."""
    folder_clause = f" Focus on the '{folder}' folder." if folder else " Start with all feeds."
    tag_clause = f" Use these tags when saving: {tags}." if tags else ""
    return (
        f"Review unread stories in NewsBlur.{folder_clause} For each story: "
        "1. Read the title and content summary. "
        "2. Decide if it's interesting enough to save. "
        "3. If interesting, use newsblur_save_story with appropriate tags. "
        f"4. Mark the rest as read using newsblur_mark_stories_read.{tag_clause} "
        "Ask for confirmation before taking actions. Show me what you plan to save vs skip."
    )


@mcp.prompt()
def newsblur_research_topic(topic: str) -> str:
    """Search feeds and saved stories for information about a specific topic."""
    return (
        f"Research the topic: '{topic}' across my NewsBlur account. "
        "1. Use newsblur_search_stories to find relevant stories in subscribed feeds. "
        "2. Use newsblur_get_read_stories with a query to search your reading history. "
        "3. Use newsblur_get_saved_stories to check saved stories for related content. "
        "4. Compile findings into a structured summary with source links. "
        "Group by subtopic and note the most authoritative sources."
    )


@mcp.prompt()
def newsblur_train_from_reading() -> str:
    """Analyze reading patterns and suggest classifier training rules."""
    return (
        "Analyze my reading patterns to improve story filtering: "
        "1. Use newsblur_get_saved_stories to see what I've saved recently. "
        "2. Use newsblur_list_feeds to see feed structure. "
        "3. Use newsblur_get_classifiers to see existing training. "
        "4. Identify patterns: frequently saved authors, tags, or title keywords. "
        "5. Suggest new classifier rules using newsblur_train_classifier. "
        "Present suggestions as a table and ask before applying any changes."
    )


@mcp.prompt()
def newsblur_feed_health_check() -> str:
    """Audit subscriptions for dead, rarely-updated, or never-read feeds."""
    return (
        "Audit my NewsBlur subscriptions for health: "
        "1. Use newsblur_list_feeds to get all feeds. "
        "2. For feeds that look concerning, use newsblur_get_feed_info for details. "
        "3. Flag: dead feeds (errors), rarely-updated (no stories in 30+ days), "
        "and feeds I never read (0 opens). "
        "4. Suggest cleanup: unsubscribe from dead feeds, consider alternatives. "
        "Present findings as a report and let me decide what to remove."
    )


@mcp.prompt()
def newsblur_discover_new_feeds(interests: str | None = None) -> str:
    """Suggest new feeds based on interests and current subscriptions."""
    interest_clause = f" My interests: {interests}." if interests else ""
    return (
        f"Help me discover new feeds for NewsBlur.{interest_clause} "
        "1. Use newsblur_list_feeds to understand what I already follow. "
        "2. Use newsblur_discover_feeds with 'trending' to see popular feeds. "
        "3. Use newsblur_discover_feeds with 'similar' for feeds like my favorites. "
        "4. Suggest 5-10 new feeds organized by topic, explaining why each is relevant. "
        "Offer to subscribe to any that interest me using newsblur_subscribe."
    )
