"""Story action tools - mark read, save, share."""

from newsblur_mcp.server import mcp, get_client


@mcp.tool()
async def newsblur_mark_stories_read(
    story_hashes: list[str] | None = None,
    feed_id: int | None = None,
    folder: str | None = None,
    older_than_days: int | None = None,
) -> dict:
    """Mark one or more stories as read.

    Can mark by specific story hashes, by feed, or by folder.
    Use this after reading/processing stories.

    Args:
        story_hashes: Specific story hashes to mark read.
        feed_id: Mark all stories in this feed as read.
        folder: Mark all stories in this folder as read.
        older_than_days: Only mark stories older than N days.
    """
    client = get_client()
    try:
        if story_hashes:
            resp = await client.post(
                "/reader/mark_story_hashes_as_read",
                data={"story_hash": story_hashes},
            )
        elif feed_id:
            data = {"feed_id": feed_id}
            if older_than_days:
                data["days"] = older_than_days
            resp = await client.post("/reader/mark_feed_as_read", data=data)
        elif folder:
            data = {}
            if folder != "all":
                data["folder_name"] = folder
            if older_than_days:
                data["days"] = older_than_days
            resp = await client.post("/reader/mark_all_as_read", data=data)
        else:
            return {"error": "Provide story_hashes, feed_id, or folder to mark as read."}

        return {"code": resp.get("code"), "message": "Stories marked as read"}
    finally:
        await client.close()


@mcp.tool()
async def newsblur_save_story(
    story_hash: str,
    tags: list[str] | None = None,
    notes: str | None = None,
    highlights: list[str] | None = None,
) -> dict:
    """Save/star a story for later reference.

    Optionally add tags and notes for organization.
    Use this to bookmark interesting stories or tag them for specific projects.

    Args:
        story_hash: Story hash to save (e.g. "123:abcdef").
        tags: Tags to apply (e.g. ["research", "ai"]).
        notes: Personal notes about the story.
        highlights: Text snippets to highlight in the story.
    """
    client = get_client()
    try:
        data = {"story_hash": story_hash}
        if tags:
            data["user_tags"] = tags
        if notes:
            data["user_notes"] = notes
        if highlights:
            data["highlights"] = highlights

        resp = await client.post("/reader/mark_story_hash_as_starred", data=data)
        return {
            "code": resp.get("code"),
            "message": f"Story saved{' with tags: ' + ', '.join(tags) if tags else ''}",
        }
    finally:
        await client.close()


@mcp.tool()
async def newsblur_unsave_story(story_hash: str) -> dict:
    """Remove a story from saved/starred stories.

    Args:
        story_hash: Story hash to unsave.
    """
    client = get_client()
    try:
        resp = await client.post(
            "/reader/mark_story_hash_as_unstarred",
            data={"story_hash": story_hash},
        )
        return {"code": resp.get("code"), "message": "Story removed from saved"}
    finally:
        await client.close()


@mcp.tool()
async def newsblur_share_story(
    story_hash: str,
    feed_id: int,
    comments: str | None = None,
) -> dict:
    """Share a story to your Blurblog with optional comments.

    Shared stories appear on your public profile and in the
    social feeds of your followers.

    Args:
        story_hash: Story hash to share.
        feed_id: Feed ID the story belongs to.
        comments: Comments to include with the share.
    """
    client = get_client()
    try:
        data = {
            "story_id": story_hash,
            "feed_id": feed_id,
        }
        if comments:
            data["comments"] = comments

        resp = await client.post("/social/share_story", data=data)
        return {"code": resp.get("code"), "message": "Story shared to your blurblog"}
    finally:
        await client.close()
