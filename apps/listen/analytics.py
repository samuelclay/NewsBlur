"""Listening time reported by the players, for the usage dashboard (apps/listen/analytics.py).

POST /listen/progress (apps/listen/views.py) calls record_listening every ~30 seconds of playback. Each call adds
to one MListenDaily document per user, story and UTC day; apps/monitor/views/newsblur_listen.py aggregates them.
"""

import datetime

from mongoengine.errors import NotUniqueError

from apps.listen.models import MListenDaily, length_bucket
from apps.listen.usage import SAMPLE_SECONDS

MAX_REPORT_SECONDS = 300
MIN_SPEED = 0.5
MAX_SPEED = 3.0
# A preview counts as heard to the end once playback gets within this many seconds of the cutoff.
PREVIEW_COMPLETE_SLACK_SECONDS = 2


def clamp_report(seconds, speed):
    """Bound one report so a buggy or hostile client can't inflate the dashboard."""
    try:
        seconds = float(seconds)
    except (TypeError, ValueError):
        seconds = 0.0
    try:
        speed = float(speed)
    except (TypeError, ValueError):
        speed = 1.0
    seconds = min(MAX_REPORT_SECONDS, max(0.0, seconds))
    speed = min(MAX_SPEED, max(MIN_SPEED, speed))
    return seconds, speed


def record_listening(user_id, plan_tier, manifest, audio_seconds, speed, finished):
    now = datetime.datetime.utcnow()
    voice = manifest.get("voice") or {}
    story_seconds = manifest.get("story_seconds") or sum(
        segment["duration"] for segment in manifest["segments"]
    )
    key = {"user_id": user_id, "date": now.strftime("%Y-%m-%d"), "story_hash": manifest["story_hash"]}
    update = {
        "inc__audio_seconds": audio_seconds,
        "inc__listen_seconds": audio_seconds / speed,
        "set__updated_at": now,
        "set__feed_id": manifest.get("feed_id"),
        "set__language": manifest.get("language"),
        "set__voice_id": manifest.get("voice_id"),
        "set__voice_name": voice.get("name", ""),
        "set__voice_source": voice.get("source", ""),
        "set__delivery": manifest.get("delivery", ""),
        "set__plan_tier": plan_tier,
        "set__is_preview": bool(manifest.get("is_preview")),
        "set__story_seconds": story_seconds,
        "set__length_bucket": length_bucket(story_seconds),
        "set_on_insert__created_at": now,
    }
    if finished:
        update["set__finished"] = True
    try:
        MListenDaily.objects(**key).update_one(upsert=True, **update)
    except NotUniqueError:
        # Two reports raced to create today's document; the other one won, so add to it.
        update.pop("set_on_insert__created_at")
        MListenDaily.objects(**key).update_one(**update)

    if manifest.get("is_preview"):
        # An upserted document only holds the fields the update set, so preview_completed may be missing.
        MListenDaily.objects(
            audio_seconds__gte=SAMPLE_SECONDS - PREVIEW_COMPLETE_SLACK_SECONDS,
            preview_completed__ne=True,
            **key
        ).update_one(set__preview_completed=True)
