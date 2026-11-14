"""Listen API (apps/listen/views.py): voices, manifests, segments, previews, usage and listening progress.

Audio bytes never pass through Django. Segment and preview responses hand back either a presigned S3 URL for
cached audio or a /listen/stream/<job>.mp3 URL that HAProxy routes to the node stream server.
"""

import json

from django.utils.translation import gettext
from django.views.decorators.http import require_http_methods

from apps.listen import elevenlabs, voices
from apps.listen.analytics import clamp_report, record_listening
from apps.listen.manifest import (
    build_manifest,
    first_request,
    load_manifest,
    manifest_allowed,
    preview_request,
    public_manifest,
    sample_voice,
    segment_lock,
    stream_job,
    was_charged,
)
from apps.listen.storage import cached_segment, object_key
from apps.listen.usage import ListenUsageTracker
from apps.reader.models import UserSubscription
from apps.rss_feeds.models import Feed, MStarredStory, MStory
from apps.social.models import MSharedStory, MSocialProfile
from utils import json_functions as json_functions
from utils import log as logging
from utils.languages import LANGUAGES
from utils.llm_costs import LLMCostTracker
from utils.user_functions import ajax_login_required
from utils.view_functions import required_params

SEGMENT_LOCK_WAIT_SECONDS = 10
PREVIEW_OVERRIDE_KEYS = {
    "delivery": "listen_delivery",
    "stability": "listen_stability",
    "similarity": "listen_similarity",
    "style": "listen_style",
    "speaker_boost": "listen_speaker_boost",
}


def _preferences(user):
    try:
        preferences = json.loads(user.profile.preferences or "{}")
    except ValueError:
        preferences = {}
    return preferences if isinstance(preferences, dict) else {}


def _unavailable():
    return {"code": -1, "reason": "unavailable", "message": gettext("Listening isn't available right now.")}


def _failure(reason, message, tracker=None):
    response = {"code": -1, "reason": reason, "message": message}
    if tracker:
        response["usage"] = tracker.snapshot()
    return response


def _record_cost(user_id, model, characters, feature_metadata):
    LLMCostTracker.record_speech(
        model=model, characters=characters, user_id=user_id, metadata=feature_metadata
    )


def _can_read_feed(user, feed):
    """The reader's rule for a feed's stories (load_single_feed in apps/reader/views.py): a newsletter needs a
    subscription, and so does a feed with a single subscriber, since it may be that reader's private feed."""
    if not feed:
        return False
    if UserSubscription.objects.filter(user=user, feed=feed).exists():
        return True
    if feed.is_newsletter:
        return False
    if feed.num_subscribers == 1 and not user.is_staff:
        return False
    return True


def _can_read_blurblog(user, sharer_id):
    """The reader's rule for a shared story (load_social_stories in apps/social/views.py): a private blurblog
    is only open to its followers."""
    if sharer_id == user.pk:
        return True
    sharer = MSocialProfile.objects(user_id=sharer_id).only("private", "follower_user_ids").first()
    return not sharer or not sharer.private or sharer.is_followed_by_user(user.pk)


def _readable_story(user, story_hash):
    """The copy of a story this user may read, or None when they can't read any.

    Listen speaks a story's text and hands back its paragraphs, so it only opens stories the reader would show
    this user. MStory.find_story alone would also return another account's newsletter or private feed story,
    and anyone's saved copy.
    """
    story, _ = MStory.find_story(story_hash=story_hash, original_only=True)
    if story and _can_read_feed(user, Feed.get_by_id(story.story_feed_id)):
        return story
    saved_story = MStarredStory.objects(user_id=user.pk, story_hash=story_hash).first()
    if saved_story:
        return saved_story
    for shared_story in MSharedStory.objects(story_hash=story_hash):
        if _can_read_blurblog(user, shared_story.user_id):
            return shared_story
    return None


@ajax_login_required
@require_http_methods(["GET"])
@json_functions.json_view
def listen_voices(request):
    language = request.GET.get("language")
    languages = [language] if language in voices.ELEVENLABS_LANGUAGES else list(voices.ELEVENLABS_LANGUAGES)
    tracker = ListenUsageTracker(request.user)
    return {
        "code": 1,
        "languages": [{"code": code, "name": name} for code, name in LANGUAGES.items()],
        "language": language if language in voices.ELEVENLABS_LANGUAGES else None,
        "voices": {code: voices.curated_voices(code) for code in languages},
        "defaults": {code: voices.default_voice_id(code) for code in LANGUAGES},
        "selected": voices.selected_voices(_preferences(request.user)),
        "delivery_presets": voices.delivery_presets(),
        "filters": voices.library_filters(),
        "usage": tracker.snapshot(),
    }


@ajax_login_required
@require_http_methods(["GET"])
@json_functions.json_view
def listen_library(request):
    if not elevenlabs.is_configured():
        return _unavailable()
    try:
        page = max(0, int(request.GET.get("page", 0)))
    except ValueError:
        page = 0
    result = voices.search_library(
        language=request.GET.get("language"),
        gender=request.GET.get("gender"),
        age=request.GET.get("age"),
        accent=request.GET.get("accent"),
        use_case=request.GET.get("use_case"),
        descriptive=request.GET.get("descriptive"),
        search=(request.GET.get("search") or "").strip()[:100],
        sort=request.GET.get("sort") or "popular",
        page=page,
    )
    if result is None:
        return _failure(
            "unavailable", gettext("The voice library couldn't be reached. Try again in a moment.")
        )
    return {"code": 1, **result}


@ajax_login_required
@require_http_methods(["POST"])
@required_params("story_hash")
@json_functions.json_view
def listen_manifest(request):
    if not elevenlabs.is_configured():
        return _unavailable()
    story_hash = request.POST["story_hash"]
    tracker = ListenUsageTracker(request.user)
    if not manifest_allowed(request.user.pk):
        return _failure(
            "rate_limited", gettext("Too many stories started at once. Try again in a few minutes.")
        )
    # A story this user can't read looks exactly like one that doesn't exist.
    story = _readable_story(request.user, story_hash)
    if not story:
        return _failure("not_found", gettext("Story not found"))

    allowed, reason, message = tracker.check_story(story_hash)
    if not allowed:
        logging.user(request, f"~FRListen denied ({reason}): ~SB{story_hash}")
        tracker.record_denied(reason, story_hash=story_hash)
        return _failure(reason, message, tracker)

    manifest = build_manifest(
        request.user,
        story,
        _preferences(request.user),
        tracker.is_archive_tier,
        request=request,
        language=request.POST.get("language"),
        voice_id=request.POST.get("voice_id"),
    )
    if len(manifest["segments"]) <= 1 and len(manifest["paragraphs"]) <= 1:
        return _failure("no_text", gettext("This story has no text to read aloud."))

    usage = tracker.snapshot()
    logging.user(
        request,
        f"~FCListen manifest: ~SB{story_hash}~SN {manifest['language']} {manifest['voice']['name']}, "
        f"{len(manifest['segments'])} segments",
    )
    return {
        "code": 1,
        **public_manifest(manifest, usage, usage["samples_used"], usage["samples_limit"]),
    }


@ajax_login_required
@require_http_methods(["POST"])
@required_params("manifest_id", "index")
@json_functions.json_view
def listen_segment(request):
    if not elevenlabs.is_configured():
        return _unavailable()
    manifest = load_manifest(request.POST["manifest_id"], request.user)
    if not manifest:
        return _failure("manifest_expired", gettext("This story needs to be reloaded."))
    if manifest["voice_id"] not in voices.premade_voice_ids() and voices.library_voices_blocked():
        # ElevenLabs started refusing library voices after this manifest was built. A rebuilt manifest uses a
        # premade voice with its own cache keys (apps/listen/manifest.py resolve_voice).
        return _failure("manifest_expired", gettext("This story needs to be reloaded."))
    try:
        index = int(request.POST["index"])
    except ValueError:
        return _failure("bad_index", gettext("That part of the story doesn't exist."))
    tracker = ListenUsageTracker(request.user)
    if index < 0 or index >= len(manifest["segments"]):
        if manifest["is_preview"] and index >= len(manifest["segments"]):
            if first_request(request.user.pk, manifest["manifest_id"], index):
                tracker.record_denied(
                    "preview_ended", story_hash=manifest["story_hash"], manifest_id=manifest["manifest_id"]
                )
            return _failure("preview_ended", tracker.upgrade_message(), tracker)
        return _failure("bad_index", gettext("That part of the story doesn't exist."))

    lock = segment_lock(request.user.pk)
    if not lock.acquire(blocking=True, blocking_timeout=SEGMENT_LOCK_WAIT_SECONDS):
        return _failure("busy", gettext("Listening is busy. Try again in a moment."))
    try:
        return _serve_segment(request.user, manifest, index, tracker)
    finally:
        lock.release()


def _serve_segment(user, manifest, index, tracker):
    """Check limits, hand out the segment's stream URL and record it, all under the user's segment lock."""
    segment = manifest["segments"][index]
    key = segment["cache_key"]
    already_charged = was_charged(user.pk, key)
    # Asked now rather than read from the manifest: audio cached since the manifest was built (this player's
    # first pass, another listener) plays free, even past the weekly cap.
    cached_now = bool(cached_segment(key))
    allowed, reason, message = tracker.check_segment(
        manifest["story_hash"], cached=cached_now or already_charged
    )
    if not allowed:
        tracker.record_denied(
            reason,
            story_hash=manifest["story_hash"],
            manifest_id=manifest["manifest_id"],
            segment_index=index,
        )
        return _failure(reason, message, tracker)

    url, cached, duration = stream_job(
        user_id=user.pk,
        text=segment["text"],
        previous_text=segment["previous_text"],
        next_text=segment["next_text"],
        voice_id=manifest["voice_id"],
        fallback_voice_id=manifest["fallback_voice_id"],
        voice_settings=manifest["voice_settings"],
        language_code=manifest["language_code"],
        key=key,
        s3_key=object_key(key),
    )
    if first_request(user.pk, manifest["manifest_id"], index):
        # Audio this user already paid for (a retry, or identical text in another story) isn't charged again,
        # but still counts the story as one of a free user's daily samples.
        tracker.record_segment(manifest, segment, cached=cached or already_charged)
        if not cached and not already_charged:
            _record_cost(
                user.pk,
                manifest["model"],
                len(segment["text"]),
                {"story_hash": manifest["story_hash"], "segment": index, "voice_id": manifest["voice_id"]},
            )
    return {
        "code": 1,
        "index": index,
        "url": url,
        "cached": cached,
        "duration": duration,
        "characters": len(segment["text"]),
        "usage": tracker.snapshot(),
    }


@ajax_login_required
@require_http_methods(["POST"])
@required_params("voice_id")
@json_functions.json_view
def listen_preview(request):
    if not elevenlabs.is_configured():
        return _unavailable()
    tracker = ListenUsageTracker(request.user)
    allowed, reason, message = tracker.check_preview()
    if not allowed:
        tracker.record_denied(reason, story_hash=request.POST.get("story_hash"))
        return _failure(reason, message, tracker)

    sample = sample_voice(request.POST["voice_id"])
    if sample:
        # The hosted sample (apps/listen/manifest.py sample_voice) is free, so it records no usage or cost.
        return {
            "code": 1,
            "url": sample["preview_url"],
            "text": "",
            "voice": sample,
            "cached": True,
            "sample": True,
            "usage": tracker.snapshot(),
        }

    story = None
    story_hash = request.POST.get("story_hash")
    if story_hash:
        # A story this user can't read previews the generic greeting, like a story that doesn't exist.
        story = _readable_story(request.user, story_hash)
    preferences = _preferences(request.user)
    for field, preference in PREVIEW_OVERRIDE_KEYS.items():
        if field in request.POST:
            preferences[preference] = request.POST[field]
    if "stability" in request.POST and "delivery" not in request.POST:
        preferences["listen_delivery"] = "custom"

    preview = preview_request(
        request.user, story, preferences, request.POST["voice_id"], language=request.POST.get("language")
    )
    already_charged = was_charged(request.user.pk, preview["cache_key"])
    url, cached, _ = stream_job(
        user_id=request.user.pk,
        text=preview["text"],
        previous_text="",
        next_text="",
        voice_id=preview["voice"]["voice_id"],
        fallback_voice_id=voices.fallback_voice_id(preview["voice"]),
        voice_settings=preview["voice_settings"],
        language_code=preview["language_code"],
        key=preview["cache_key"],
        s3_key=preview["s3_key"],
    )
    if not already_charged:
        tracker.record_preview(
            story_hash,
            preview["voice"]["voice_id"],
            preview["model"],
            preview["language"],
            preview["text"],
            preview["seconds"],
            cached,
        )
        if not cached:
            _record_cost(
                request.user.pk,
                preview["model"],
                len(preview["text"]),
                {"story_hash": story_hash or "", "preview": True, "voice_id": preview["voice"]["voice_id"]},
            )
    return {
        "code": 1,
        "url": url,
        "text": preview["text"],
        "voice": preview["voice"],
        "cached": cached,
        "sample": False,
        "usage": tracker.snapshot(),
    }


@ajax_login_required
@require_http_methods(["GET"])
@json_functions.json_view
def listen_usage(request):
    return {"code": 1, "usage": ListenUsageTracker(request.user).snapshot()}


@ajax_login_required
@require_http_methods(["POST"])
@required_params("manifest_id", "seconds")
@json_functions.json_view
def listen_progress(request):
    """Seconds of a story the player actually played since its last report, for the usage dashboard.

    Players report every ~30 seconds and on pause, stop and story end. Reports for unknown or expired manifests
    are accepted and ignored so a player never retries them.
    """
    manifest = load_manifest(request.POST["manifest_id"], request.user)
    if not manifest:
        return {"code": 1}
    seconds, speed = clamp_report(request.POST["seconds"], request.POST.get("speed", 1))
    finished = request.POST.get("finished") == "true"
    if seconds < 1 and not finished:
        return {"code": 1}
    record_listening(
        request.user.pk, ListenUsageTracker(request.user).tier, manifest, seconds, speed, finished
    )
    return {"code": 1}
