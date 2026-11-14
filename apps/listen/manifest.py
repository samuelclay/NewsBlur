"""Listen manifests and stream jobs (apps/listen/manifest.py).

A manifest is everything needed to read one story with one voice: its paragraphs, its segments with the exact
text sent to ElevenLabs, and the voice settings. It is stored in Redis for a few hours so every segment of a
story is generated with the same settings. Segment requests then become stream jobs: small Redis records the
node stream server (node/listen.coffee) reads by an unguessable id to generate, stream and cache the audio.
"""

import hashlib
import json
import time
import uuid
import zlib

import redis
from django.conf import settings
from django.utils import translation
from django.utils.encoding import smart_str
from django.utils.translation import gettext

from apps.listen import storage, voices
from apps.listen.language import detect_language
from apps.listen.text import (
    PARAGRAPH_PREFIX_LENGTH,
    build_paragraphs,
    build_segments,
    estimate_seconds,
    normalize_whitespace,
    preview_text,
    truncate_segments,
)
from apps.listen.usage import SAMPLE_SECONDS
from apps.rss_feeds.models import Feed
from utils import log as logging
from utils.languages import account_language
from utils.story_functions import html_to_text

MANIFEST_SECONDS = 6 * 60 * 60
# Manifests hold a story's full text in the shared pubsub Redis, so each user may only build so many.
MANIFESTS_PER_WINDOW = 60
MANIFEST_WINDOW_SECONDS = 10 * 60
CHARGE_DEDUPE_SECONDS = 60 * 60
SHORT_FEED_TEXT_CHARACTERS = 1500
ORIGINAL_TEXT_ADVANTAGE = 1.2


def _redis():
    return redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)


def model_id():
    return getattr(settings, "LISTEN_MODEL", "eleven_v4_turbo")


def story_html(story, request=None):
    """The fuller of the feed's content and the extracted article text, and which one it was."""
    feed_html = (
        story.story_content_str if hasattr(story, "story_content_str") else (story.story_content or "")
    )
    feed_length = len(html_to_text(feed_html))
    original_html = None
    if getattr(story, "original_text_z", None):
        original_html = smart_str(zlib.decompress(story.original_text_z))
    elif feed_length < SHORT_FEED_TEXT_CHARACTERS and hasattr(story, "fetch_original_text"):
        try:
            original_html = smart_str(story.fetch_original_text(request=request) or "")
        except Exception as e:
            logging.user(request, f"~FRListen couldn't fetch original text for {story.story_hash}: {e}")
    if original_html and len(html_to_text(original_html)) > feed_length * ORIGINAL_TEXT_ADVANTAGE:
        return original_html, "original"
    return feed_html, "story"


def _elevenlabs_language_code(language):
    return voices.ELEVENLABS_LANGUAGES.get(language, ("en", []))[0]


def resolve_voice(voice_id, language):
    """Voice metadata for voice_id, substituting a premade voice when the account can't use library voices."""
    voice = voices.voice_metadata(voice_id)
    if voice_id not in voices.premade_voice_ids() and voices.library_voices_blocked():
        fallback = voices.voice_metadata(voices.fallback_voice_id(voice))
        return fallback, True, voice
    return voice, False, voice


def build_manifest(user, story, preferences, is_archive_tier, request=None, language=None, voice_id=None):
    story_hash = story.story_hash
    feed = Feed.get_by_id(story.story_feed_id)
    feed_title = feed.feed_title if feed else ""
    title = story.decoded_story_title if hasattr(story, "decoded_story_title") else story.story_title
    html, text_source = story_html(story, request=request)
    paragraphs = build_paragraphs(title, html)

    detected_language = detect_language(" ".join(paragraph["text"] for paragraph in paragraphs[:20]))
    language = language if language in voices.ELEVENLABS_LANGUAGES else None
    language = language or detected_language or account_language(user.profile)

    if voice_id:
        chosen_voice_id = voices.usable_voice_id(voice_id, language)
    else:
        chosen_voice_id = voices.selected_voices(preferences)[language]
    voice, voice_fallback, requested_voice = resolve_voice(chosen_voice_id, language)
    voice_settings = voices.voice_settings_from(preferences)

    title_suffix = ""
    if feed_title and normalize_whitespace(feed_title).lower() != normalize_whitespace(title).lower():
        with translation.override(language.lower()):
            title_suffix = gettext("From %(feed_title)s.") % {"feed_title": normalize_whitespace(feed_title)}
    segments = build_segments(paragraphs, title_suffix=title_suffix)
    story_seconds = round(sum(estimate_seconds(segment["text"], language) for segment in segments), 1)
    if not is_archive_tier:
        segments = truncate_segments(segments, SAMPLE_SECONDS, language)

    language_code = _elevenlabs_language_code(language)
    stored_segments = []
    for segment in segments:
        key = storage.cache_key(
            model_id(),
            voice["voice_id"],
            voice_settings,
            language_code,
            segment["text"],
            segment["previous_text"],
            segment["next_text"],
        )
        cached = storage.cached_segment(key)
        stored_segments.append(
            {
                "index": segment["index"],
                "paragraphs": segment["paragraphs"],
                "text": segment["text"],
                "previous_text": segment["previous_text"],
                "next_text": segment["next_text"],
                "cache_key": key,
                "duration": cached["duration"] if cached else estimate_seconds(segment["text"], language),
                "estimated": not cached,
                "cached": bool(cached),
            }
        )

    # Rebuilding the same story with the same voice and settings overwrites one manifest instead of adding more.
    identity = [
        user.pk,
        story_hash,
        is_archive_tier,
        model_id(),
        [segment["cache_key"] for segment in stored_segments],
    ]
    manifest_id = hashlib.sha1(json.dumps(identity).encode("utf-8")).hexdigest()[:32]
    manifest = {
        "manifest_id": manifest_id,
        "user_id": user.pk,
        "story_hash": story_hash,
        "feed_id": story.story_feed_id,
        "story_title": title,
        "feed_title": feed_title,
        "language": language,
        "detected_language": detected_language,
        "language_code": language_code,
        "voice_id": voice["voice_id"],
        "voice": voice,
        "requested_voice": requested_voice,
        "voice_fallback": voice_fallback,
        "fallback_voice_id": voices.fallback_voice_id(voice),
        "voice_settings": voice_settings,
        "delivery": preferences.get("listen_delivery") or voices.DEFAULT_DELIVERY,
        "model": model_id(),
        "text_source": text_source,
        "is_preview": not is_archive_tier,
        "story_seconds": story_seconds,
        "paragraphs": [
            {
                "index": paragraph["index"],
                "kind": paragraph["kind"],
                "text": paragraph["text"][:PARAGRAPH_PREFIX_LENGTH],
            }
            for paragraph in paragraphs
        ],
        "segments": stored_segments,
        "expires_at": int(time.time()) + MANIFEST_SECONDS,
    }
    _redis().set(f"listen:manifest:{manifest_id}", json.dumps(manifest), ex=MANIFEST_SECONDS)
    return manifest


def load_manifest(manifest_id, user):
    raw = _redis().get(f"listen:manifest:{manifest_id}")
    if not raw:
        return None
    manifest = json.loads(raw)
    if manifest.get("user_id") != user.pk:
        return None
    return manifest


def public_manifest(manifest, usage, samples_used, samples_limit):
    """The manifest as clients see it, without segment text or cache keys."""
    return {
        "manifest_id": manifest["manifest_id"],
        "expires_at": manifest["expires_at"],
        "story_hash": manifest["story_hash"],
        "feed_id": manifest["feed_id"],
        "story_title": manifest["story_title"],
        "feed_title": manifest["feed_title"],
        "language": manifest["language"],
        "detected_language": manifest["detected_language"],
        "voice": manifest["voice"],
        "voice_fallback": manifest["voice_fallback"],
        "text_source": manifest["text_source"],
        "paragraphs": manifest["paragraphs"],
        "segments": [
            {
                "index": segment["index"],
                "paragraphs": segment["paragraphs"],
                "characters": len(segment["text"]),
                "duration": segment["duration"],
                "estimated": segment["estimated"],
                "cached": segment["cached"],
            }
            for segment in manifest["segments"]
        ],
        "total_duration": round(sum(segment["duration"] for segment in manifest["segments"]), 1),
        "preview": {
            "is_preview": manifest["is_preview"],
            "seconds": SAMPLE_SECONDS if manifest["is_preview"] else None,
            "samples_used": samples_used,
            "samples_limit": samples_limit,
        },
        "usage": usage,
    }


def stream_job(
    user_id,
    text,
    previous_text,
    next_text,
    voice_id,
    fallback_voice_id,
    voice_settings,
    language_code,
    key,
    s3_key,
):
    """A stream URL for one piece of audio: a presigned S3 URL when cached, else a node stream job."""
    cached = storage.cached_segment(key)
    if cached:
        return storage.presigned_get(s3_key), True, cached["duration"]

    r = _redis()
    dedupe_key = f"listen:charged:{user_id}:{key}"
    existing_job = r.get(dedupe_key)
    if existing_job and r.exists(f"listen:job:{existing_job}"):
        return f"/listen/stream/{existing_job}.mp3", False, None

    job_id = uuid.uuid4().hex
    job = {
        "user_id": user_id,
        "text": text,
        "previous_text": previous_text,
        "next_text": next_text,
        "voice_id": voice_id,
        "fallback_voice_id": fallback_voice_id if fallback_voice_id != voice_id else None,
        "is_premade_voice": voice_id in voices.premade_voice_ids(),
        "model_id": model_id(),
        "language_code": language_code,
        "voice_settings": voice_settings,
        "output_format": storage.OUTPUT_FORMAT,
        "cache_key": key,
        "s3_put_url": storage.presigned_put(s3_key),
        "s3_get_url": storage.presigned_get(s3_key),
    }
    r.set(f"listen:job:{job_id}", json.dumps(job), ex=storage.URL_EXPIRATION_SECONDS)
    r.set(dedupe_key, job_id, ex=CHARGE_DEDUPE_SECONDS)
    return f"/listen/stream/{job_id}.mp3", False, None


def was_charged(user_id, key):
    """Whether this user already started generating this exact audio, so it isn't paid for twice."""
    return bool(_redis().get(f"listen:charged:{user_id}:{key}"))


def first_request(user_id, manifest_id, index):
    """True only the first time a manifest's segment is requested, so retries record usage once."""
    recorded_key = f"listen:recorded:{user_id}:{manifest_id}:{index}"
    return bool(_redis().set(recorded_key, 1, nx=True, ex=CHARGE_DEDUPE_SECONDS))


def manifest_allowed(user_id):
    """Whether this user may build another manifest in the current ten minute window."""
    r = _redis()
    window_key = f"listen:manifests:{user_id}:{int(time.time() // MANIFEST_WINDOW_SECONDS)}"
    count = r.incr(window_key)
    if count == 1:
        r.expire(window_key, MANIFEST_WINDOW_SECONDS)
    return count <= MANIFESTS_PER_WINDOW


def segment_lock(user_id):
    """Serializes one user's segment requests, so parallel requests can't all pass a limit before any is recorded."""
    return _redis().lock(f"listen:segment_lock:{user_id}", timeout=15)


def sample_voice(voice_id):
    """The requested voice when its preview should be ElevenLabs' hosted sample instead of new speech.

    While library voices are blocked, a generated preview would speak in the premade stand-in, so every library
    voice would sound alike. The voice's own preview_url still plays the real voice, and costs nothing.
    """
    _, substituted, requested_voice = resolve_voice(voice_id, None)
    if substituted and requested_voice.get("preview_url"):
        return requested_voice
    return None


def preview_request(user, story, preferences, voice_id, language=None):
    """Text, voice and job for a ~10 second voice preview from the start of a story."""
    if story:
        title = story.decoded_story_title if hasattr(story, "decoded_story_title") else story.story_title
        html, _ = story_html(story)
        paragraphs = build_paragraphs(title, html)
        text = preview_text(paragraphs) or normalize_whitespace(title)
        detected = detect_language(" ".join(paragraph["text"] for paragraph in paragraphs[:10]))
        language = (
            language
            if language in voices.ELEVENLABS_LANGUAGES
            else (detected or account_language(user.profile))
        )
    else:
        language = language if language in voices.ELEVENLABS_LANGUAGES else account_language(user.profile)
        with translation.override(language.lower()):
            text = gettext("Hi, I'm one of the voices that can read your stories to you on NewsBlur.")
    voice, _, _ = resolve_voice(voices.usable_voice_id(voice_id, language), language)
    voice_settings = voices.voice_settings_from(preferences)
    language_code = _elevenlabs_language_code(language)
    key = storage.cache_key(model_id(), voice["voice_id"], voice_settings, language_code, text)
    return {
        "text": text,
        "language": language,
        "language_code": language_code,
        "voice": voice,
        "voice_settings": voice_settings,
        "cache_key": key,
        "s3_key": storage.object_key(key),
        "seconds": estimate_seconds(text, language),
        "model": model_id(),
    }
