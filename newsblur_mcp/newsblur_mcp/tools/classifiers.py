"""Intelligence classifier tools."""

from newsblur_mcp.client import NewsBlurClient
from newsblur_mcp.server import mcp, get_client


async def _train_classifier(
    client: NewsBlurClient,
    feed_id: int,
    like_title: list[str] | None = None,
    dislike_title: list[str] | None = None,
    like_author: list[str] | None = None,
    dislike_author: list[str] | None = None,
    like_tag: list[str] | None = None,
    dislike_tag: list[str] | None = None,
    like_feed: bool | None = None,
    dislike_feed: bool | None = None,
) -> dict:
    """Train the intelligence classifier to like or dislike stories."""
    data = {"feed_id": feed_id}

    for keyword in (like_title or []):
        data[f"like_title"] = keyword
    for keyword in (dislike_title or []):
        data[f"dislike_title"] = keyword
    for author in (like_author or []):
        data[f"like_author"] = author
    for author in (dislike_author or []):
        data[f"dislike_author"] = author
    for tag in (like_tag or []):
        data[f"like_tag"] = tag
    for tag in (dislike_tag or []):
        data[f"dislike_tag"] = tag
    if like_feed:
        data["like_feed"] = feed_id
    if dislike_feed:
        data["dislike_feed"] = feed_id

    resp = await client.post(f"/classifier/save", data=data)
    return {"code": resp.get("code"), "message": "Classifier updated"}


@mcp.tool()
async def newsblur_train_classifier(
    feed_id: int,
    like_title: list[str] | None = None,
    dislike_title: list[str] | None = None,
    like_author: list[str] | None = None,
    dislike_author: list[str] | None = None,
    like_tag: list[str] | None = None,
    dislike_tag: list[str] | None = None,
    like_feed: bool | None = None,
    dislike_feed: bool | None = None,
) -> dict:
    """Train the intelligence classifier to like or dislike stories.

    Training affects how future stories are scored: liked attributes
    boost stories (green/focus), disliked attributes suppress them (red/hidden).

    Args:
        feed_id: Feed ID to train on.
        like_title: Title keywords to like (boost stories containing these).
        dislike_title: Title keywords to dislike (suppress stories containing these).
        like_author: Author names to like.
        dislike_author: Author names to dislike.
        like_tag: Story tags to like.
        dislike_tag: Story tags to dislike.
        like_feed: Like the entire feed (boost all its stories).
        dislike_feed: Dislike the entire feed (suppress all its stories).
    """
    client = get_client()
    try:
        return await _train_classifier(client, feed_id, like_title, dislike_title, like_author, dislike_author, like_tag, dislike_tag, like_feed, dislike_feed)
    finally:
        await client.close()


async def _get_classifiers(
    client: NewsBlurClient,
    feed_id: int | None = None,
) -> dict:
    """View all trained intelligence classifiers."""
    if feed_id:
        resp = await client.get(f"/classifier/{feed_id}")
        return {
            "feed_id": feed_id,
            "classifiers": {
                "titles": resp.get("payload", {}).get("classifiers", {}).get("titles", []),
                "authors": resp.get("payload", {}).get("classifiers", {}).get("authors", []),
                "tags": resp.get("payload", {}).get("classifiers", {}).get("tags", []),
                "feeds": resp.get("payload", {}).get("classifiers", {}).get("feeds", []),
            },
        }
    else:
        resp = await client.get("/reader/all_classifiers")
        return {"classifiers": resp.get("classifiers", {})}


@mcp.tool()
async def newsblur_get_classifiers(
    feed_id: int | None = None,
) -> dict:
    """View all trained intelligence classifiers.

    Shows what the user has trained to like/dislike, organized by type.
    Use this to understand current training before suggesting new classifiers.

    Args:
        feed_id: Get classifiers for a specific feed only. Omit for all feeds.
    """
    client = get_client()
    try:
        return await _get_classifiers(client, feed_id)
    finally:
        await client.close()
