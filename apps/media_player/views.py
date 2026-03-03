import datetime

import redis
from django.conf import settings

from apps.media_player.models import MMediaPlaybackState
from utils import json_functions as json
from utils import log as logging
from utils.user_functions import ajax_login_required


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
        return {"code": -1, "message": "No fields to update"}

    state = MMediaPlaybackState.save_playback_state(user.pk, **state_fields)

    # Also update Redis for fast reads on page load
    try:
        r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
        redis_key = f"media:playback:{user.pk}"
        redis_data = {}
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
