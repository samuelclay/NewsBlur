import datetime

import redis
from django.conf import settings
from django.utils.translation import gettext

from apps.media_player.models import MMediaPlaybackState
from utils import json_functions as json
from utils import log as logging
from utils.user_functions import ajax_login_required


@ajax_login_required
@json.json_view
def playback_state(request):
    """The player state, queue and history, so the mobile Listen players and a refocused web tab share one queue.

    The web otherwise gets this inside /reader/feeds (apps/reader/views.py).
    """
    return {"playback_state": MMediaPlaybackState.get_state_with_redis_position(request.user.pk)}


@ajax_login_required
@json.json_view
def save_playback_state(request):
    """Save media playback state (play/pause/seek/new item/close). Also updates Redis for fast reads."""
    user = request.user
    state_fields = {}

    for field in [
        "current_story_hash",
        "current_media_url",
        "current_media_type",
        "current_media_title",
        "current_image_url",
    ]:
        if field in request.POST:
            state_fields[field] = request.POST[field]

    for field in ["current_feed_id"]:
        if field in request.POST:
            state_fields[field] = int(request.POST[field])

    for field in ["current_position", "current_duration", "current_playback_rate", "current_volume"]:
        if field in request.POST:
            state_fields[field] = float(request.POST[field])

    if "is_playing" in request.POST:
        state_fields["is_playing"] = request.POST["is_playing"] in ("true", "True", "1", True)

    for field in ["skip_back_seconds", "skip_forward_seconds"]:
        if field in request.POST:
            state_fields[field] = int(request.POST[field])

    for field in ["auto_play_next", "remember_position", "resume_on_load"]:
        if field in request.POST:
            state_fields[field] = request.POST[field] in ("true", "True", "1", True)

    if not state_fields:
        return {"code": -1, "message": gettext("No fields to update")}

    state = MMediaPlaybackState.save_playback_state(user.pk, **state_fields)

    # Also update Redis for fast reads on page load
    try:
        r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
        redis_key = f"media:playback:{user.pk}"
        redis_data = {}
        if "current_media_url" in state_fields:
            # sync_playback_position only writes positions for the item named here, and
            # MMediaPlaybackState.get_state_with_redis_position ignores a hash naming another item. A new item
            # starts the hash fresh so the previous item's position can't carry over to it.
            redis_data["media_url"] = state_fields["current_media_url"]
            if r.hget(redis_key, "media_url") != state_fields["current_media_url"]:
                r.delete(redis_key)
        if "current_position" in state_fields:
            redis_data["position"] = str(state_fields["current_position"])
        if "current_duration" in state_fields:
            redis_data["duration"] = str(state_fields["current_duration"])
        if "is_playing" in state_fields:
            redis_data["is_playing"] = "true" if state_fields["is_playing"] else "false"
        if "current_playback_rate" in state_fields:
            redis_data["playback_rate"] = str(state_fields["current_playback_rate"])
        if "current_volume" in state_fields:
            redis_data["volume"] = str(state_fields["current_volume"])
        if redis_data:
            r.hmset(redis_key, redis_data)
            r.expire(redis_key, 86400)  # 24h expiry
    except Exception:
        pass

    logging.user(request, "~FCMedia player: ~SBsave state~SN (%s)" % state.current_media_type)

    return {"playback_state": state.canonical()}


@ajax_login_required
@json.json_view
def sync_playback_position(request):
    """The mobile apps' lightweight position update while an item plays, the HTTP twin of the web's
    media:sync websocket message (node/unread_counts.js). It writes only the Redis hash that
    get_state_with_redis_position reads, so frequent updates never touch MongoDB, and only while media_url is
    still the current item, so a stale or racing client can't move another item's position. Unlike the
    websocket it doesn't broadcast to open web tabs.

    Code -1 means only that another device made something else current, and the apps stop syncing that item
    (ListenMediaSync.kt, ListenMediaPlayer.swift). Every other failure is code 0, which they retry next time.
    """
    if request.method != "POST":
        return {"code": 0, "message": gettext("Use POST")}

    media_url = request.POST.get("media_url", "")

    def is_current_item():
        state = MMediaPlaybackState.objects(user_id=request.user.pk).only("current_media_url").first()
        return bool(state and media_url and state.current_media_url == media_url)

    if not is_current_item():
        return {"code": -1, "message": gettext("That item isn't playing")}

    redis_data = {}
    try:
        for field, redis_field in (("position", "position"), ("duration", "duration")):
            if field in request.POST:
                redis_data[redis_field] = str(max(0.0, float(request.POST[field])))
        if "playback_rate" in request.POST:
            redis_data["playback_rate"] = str(float(request.POST["playback_rate"]))
    except ValueError:
        return {"code": 0, "message": gettext("Invalid position")}
    if "is_playing" in request.POST:
        redis_data["is_playing"] = "true" if request.POST["is_playing"] in ("true", "True", "1") else "false"
    if not redis_data:
        return {"code": 0, "message": gettext("No fields to update")}
    redis_data["media_url"] = media_url

    redis_key = f"media:playback:{request.user.pk}"

    def write_position(pipe):
        # save_playback_state records the current item's media_url in the hash. A hash naming another item
        # means either that item became current after the check above, so this position is dropped instead of
        # landing on it, or save_playback_state's Redis write failed when this item became current and left
        # the old name behind. MongoDB, the record of what's current, tells them apart; a stale hash is
        # replaced. WATCH retries the write if the hash changes underneath.
        stored_media_url = pipe.hget(redis_key, "media_url")
        is_stale_hash = bool(stored_media_url and stored_media_url != media_url)
        if is_stale_hash and not is_current_item():
            return False
        pipe.multi()
        if is_stale_hash:
            pipe.delete(redis_key)
        pipe.hset(redis_key, mapping=redis_data)
        pipe.expire(redis_key, 86400)  # 24h expiry, matching node/unread_counts.js media:sync
        return True

    try:
        r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
        written = r.transaction(write_position, redis_key, value_from_callable=True)
    except redis.RedisError:
        return {"code": 0, "message": gettext("Couldn't save the position")}
    if not written:
        return {"code": -1, "message": gettext("That item isn't playing")}

    return {"code": 1}


@ajax_login_required
@json.json_view
def add_to_media_queue(request):
    """Add a media item to the playback queue."""
    user = request.user
    media_item = {
        "story_hash": request.POST.get("story_hash", ""),
        "media_url": request.POST.get("media_url", ""),
        "media_type": request.POST.get("media_type", ""),
        "media_title": request.POST.get("media_title", ""),
        "feed_id": int(request.POST.get("feed_id", 0)),
        "image_url": request.POST.get("image_url", ""),
    }

    duration = request.POST.get("duration")
    if duration:
        media_item["duration"] = float(duration)

    position = request.POST.get("position")
    if position is not None:
        position = int(position)

    state = MMediaPlaybackState.add_to_queue(user.pk, media_item, position=position)

    logging.user(request, "~FCMedia player: ~SBadd to queue~SN (%s)" % media_item.get("media_title", ""))

    return {"playback_state": state.canonical()}


@ajax_login_required
@json.json_view
def remove_from_media_queue(request):
    """Remove a media item from the playback queue."""
    user = request.user
    story_hash = request.POST.get("story_hash", "")
    media_url = request.POST.get("media_url", "")

    state = MMediaPlaybackState.remove_from_queue(user.pk, story_hash, media_url)
    if not state:
        return {"playback_state": None}

    logging.user(request, "~FCMedia player: ~SBremove from queue~SN")

    return {"playback_state": state.canonical()}


@ajax_login_required
@json.json_view
def reorder_media_queue(request):
    """Reorder the playback queue."""
    user = request.user
    queue_order = json.decode(request.POST.get("queue_order", "[]"))

    state = MMediaPlaybackState.reorder_queue(user.pk, queue_order)
    if not state:
        return {"playback_state": None}

    logging.user(request, "~FCMedia player: ~SBreorder queue~SN")

    return {"playback_state": state.canonical()}


@ajax_login_required
@json.json_view
def clear_playback_state(request):
    """Clear the playback state entirely (close player)."""
    user = request.user
    MMediaPlaybackState.clear_state(user.pk)

    # Clear Redis too
    try:
        r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
        r.delete(f"media:playback:{user.pk}")
    except Exception:
        pass

    logging.user(request, "~FCMedia player: ~SBclear state~SN")

    return {"playback_state": None}


@ajax_login_required
@json.json_view
def clear_media_queue(request):
    """Clear the queue but keep the current playing item."""
    user = request.user
    state = MMediaPlaybackState.get_user(user.pk)
    if state:
        state.queue = []
        state.updated_at = datetime.datetime.now()
        state.save()
        logging.user(request, "~FCMedia player: ~SBclear queue~SN")
        return {"playback_state": state.canonical()}
    return {"playback_state": None}


@ajax_login_required
@json.json_view
def add_to_media_history(request):
    """Add a media item to playback history with its position."""
    user = request.user
    media_item = {
        "story_hash": request.POST.get("story_hash", ""),
        "media_url": request.POST.get("media_url", ""),
        "media_type": request.POST.get("media_type", ""),
        "media_title": request.POST.get("media_title", ""),
        "feed_id": int(request.POST.get("feed_id", 0)),
        "image_url": request.POST.get("image_url", ""),
        "position": float(request.POST.get("position", 0)),
        "duration": float(request.POST.get("duration", 0)),
    }

    state = MMediaPlaybackState.add_to_history(user.pk, media_item)

    logging.user(request, "~FCMedia player: ~SBadd to history~SN (%s)" % media_item.get("media_title", ""))

    return {"playback_state": state.canonical()}


@ajax_login_required
@json.json_view
def remove_from_media_history(request):
    """Remove a media item from playback history."""
    user = request.user
    story_hash = request.POST.get("story_hash", "")
    media_url = request.POST.get("media_url", "")

    state = MMediaPlaybackState.remove_from_history(user.pk, story_hash, media_url)
    if not state:
        return {"playback_state": None}

    logging.user(request, "~FCMedia player: ~SBremove from history~SN")

    return {"playback_state": state.canonical()}


@ajax_login_required
@json.json_view
def clear_media_history(request):
    """Clear playback history."""
    user = request.user
    state = MMediaPlaybackState.clear_history(user.pk)
    if state:
        logging.user(request, "~FCMedia player: ~SBclear history~SN")
        return {"playback_state": state.canonical()}
    return {"playback_state": None}
