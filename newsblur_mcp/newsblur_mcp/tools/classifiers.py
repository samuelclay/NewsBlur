"""Intelligence classifier tools."""

from newsblur_mcp.client import NewsBlurClient
from newsblur_mcp.server import mcp, get_client


async def _train_classifier(
    client: NewsBlurClient,
    feed_id: int,
    like_title: list[str] | None = None,
    dislike_title: list[str] | None = None,
    super_dislike_title: list[str] | None = None,
    like_author: list[str] | None = None,
    dislike_author: list[str] | None = None,
    super_dislike_author: list[str] | None = None,
    like_tag: list[str] | None = None,
    dislike_tag: list[str] | None = None,
    super_dislike_tag: list[str] | None = None,
    like_text: list[str] | None = None,
    dislike_text: list[str] | None = None,
    super_dislike_text: list[str] | None = None,
    like_feed: bool | None = None,
    dislike_feed: bool | None = None,
) -> dict:
    """Train the intelligence classifier to like, dislike, or super-dislike stories."""
    # NewsBlur's classifier API expects repeated form fields for multiple values
    # (e.g. like_title=python&like_title=rust), so we build a list of tuples
    fields = [("feed_id", feed_id)]

    for keyword in (like_title or []):
        fields.append(("like_title", keyword))
    for keyword in (dislike_title or []):
        fields.append(("dislike_title", keyword))
    for keyword in (super_dislike_title or []):
        fields.append(("super_dislike_title", keyword))
    for author in (like_author or []):
        fields.append(("like_author", author))
    for author in (dislike_author or []):
        fields.append(("dislike_author", author))
    for author in (super_dislike_author or []):
        fields.append(("super_dislike_author", author))
    for tag in (like_tag or []):
        fields.append(("like_tag", tag))
    for tag in (dislike_tag or []):
        fields.append(("dislike_tag", tag))
    for tag in (super_dislike_tag or []):
        fields.append(("super_dislike_tag", tag))
    for keyword in (like_text or []):
        fields.append(("like_text", keyword))
    for keyword in (dislike_text or []):
        fields.append(("dislike_text", keyword))
    for keyword in (super_dislike_text or []):
        fields.append(("super_dislike_text", keyword))
    if like_feed:
        fields.append(("like_feed", feed_id))
    if dislike_feed:
        fields.append(("dislike_feed", feed_id))

    resp = await client.post("/classifier/save", data=fields)
    return {"code": resp.get("code"), "message": "Classifier updated"}


@mcp.tool()
async def newsblur_train_classifier(
    feed_id: int,
    like_title: list[str] | None = None,
    dislike_title: list[str] | None = None,
    super_dislike_title: list[str] | None = None,
    like_author: list[str] | None = None,
    dislike_author: list[str] | None = None,
    super_dislike_author: list[str] | None = None,
    like_tag: list[str] | None = None,
    dislike_tag: list[str] | None = None,
    super_dislike_tag: list[str] | None = None,
    like_text: list[str] | None = None,
    dislike_text: list[str] | None = None,
    super_dislike_text: list[str] | None = None,
    like_feed: bool | None = None,
    dislike_feed: bool | None = None,
) -> dict:
    """Train the intelligence classifier to like, dislike, or super-dislike stories.

    Training affects how future stories are scored: liked attributes
    boost stories (green/focus), disliked attributes suppress them (red/hidden).
    Super-dislike is the strongest filter — it overrides all positive classifiers,
    guaranteeing the story is hidden regardless of how many likes match.

    Args:
        feed_id: Feed ID to train on.
        like_title: Title keywords to like (boost stories containing these).
        dislike_title: Title keywords to dislike (suppress stories containing these).
        super_dislike_title: Title keywords to super-dislike (always hide, overrides all likes).
        like_author: Author names to like.
        dislike_author: Author names to dislike.
        super_dislike_author: Author names to super-dislike (always hide, overrides all likes).
        like_tag: Story tags to like.
        dislike_tag: Story tags to dislike.
        super_dislike_tag: Story tags to super-dislike (always hide, overrides all likes).
        like_text: Content keywords to like (boost stories containing these in body text).
        dislike_text: Content keywords to dislike (suppress stories containing these in body text).
        super_dislike_text: Content keywords to super-dislike (always hide, overrides all likes).
        like_feed: Like the entire feed (boost all its stories).
        dislike_feed: Dislike the entire feed (suppress all its stories).
    """
    client = get_client()
    try:
        return await _train_classifier(
            client, feed_id,
            like_title, dislike_title, super_dislike_title,
            like_author, dislike_author, super_dislike_author,
            like_tag, dislike_tag, super_dislike_tag,
            like_text, dislike_text, super_dislike_text,
            like_feed, dislike_feed,
        )
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
