"""Voices for Listen: the curated per-language catalog, library search, presets and preferences
(apps/listen/voices.py).

The curated catalog lives in apps/listen/voice_catalog.json and is regenerated from the ElevenLabs voice
library by `manage.py refresh_listen_voices`. Library voices a user picks outside the catalog are remembered
in Redis so manifests can still show their name.
"""

import hashlib
import json
import re
from pathlib import Path

import redis
from django.conf import settings
from django.utils.translation import gettext

from apps.listen import elevenlabs
from utils.languages import LANGUAGES

CATALOG_PATH = Path(__file__).resolve().parent / "voice_catalog.json"
LIBRARY_PAGE_SIZE = 30
LIBRARY_CACHE_SECONDS = 60 * 60
VOICE_METADATA_SECONDS = 60 * 60 * 24 * 365
# ElevenLabs voice ids are 20 letters and digits. Anything else is refused before it can reach their API.
VOICE_ID_RE = re.compile(r"^[A-Za-z0-9]{20}$")
NAME_TAGLINE_RE = re.compile(r"\s+[-–—]\s+")

# Our interface languages mapped to ElevenLabs library languages and preferred locales.
ELEVENLABS_LANGUAGES = {
    "en": ("en", ["en-US", "en-GB"]),
    "es": ("es", ["es-ES", "es-MX"]),
    "fr": ("fr", ["fr-FR"]),
    "de": ("de", ["de-DE"]),
    "pt-BR": ("pt", ["pt-BR"]),
    "it": ("it", ["it-IT"]),
    "nl": ("nl", ["nl-NL"]),
    "pl": ("pl", ["pl-PL"]),
    "tr": ("tr", ["tr-TR"]),
    "ru": ("ru", ["ru-RU"]),
    "uk": ("uk", ["uk-UA"]),
    "ar": ("ar", []),
    "he": ("he", []),
    "hi": ("hi", ["hi-IN"]),
    "id": ("id", ["id-ID"]),
    "vi": ("vi", ["vi-VN"]),
    "th": ("th", []),
    "ja": ("ja", ["ja-JP"]),
    "ko": ("ko", ["ko-KR"]),
    "zh-Hans": ("zh", ["cmn-CN"]),
    "zh-Hant": ("zh", ["cmn-TW"]),
}

DELIVERY_PRESETS = {
    "steady": {"stability": 0.75, "similarity": 0.75, "style": 0.0},
    "natural": {"stability": 0.5, "similarity": 0.75, "style": 0.0},
    "expressive": {"stability": 0.3, "similarity": 0.75, "style": 0.35},
}
DEFAULT_DELIVERY = "natural"

LIBRARY_SORTS = {
    "popular": "usage_character_count_1y",
    "trending": "trending",
    "newest": "created_date",
}

# Premade voices are on every ElevenLabs plan. They stand in for library voices the account can't use.
FALLBACK_VOICES = {
    "female": "EXAVITQu4vr4xnSDxMaL",
    "male": "JBFqnCBsd6RMkjVDRZzb",
    "neutral": "SAz9YHcvj6GT2YYXdXww",
}


def _redis():
    return redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)


_catalog_cache = {}


def catalog():
    """The curated catalog, reloaded when voice_catalog.json changes on disk."""
    try:
        modified = CATALOG_PATH.stat().st_mtime
    except FileNotFoundError:
        return {"premade": [], "languages": {}}
    if _catalog_cache.get("modified") != modified:
        _catalog_cache["data"] = json.loads(CATALOG_PATH.read_text())
        _catalog_cache["modified"] = modified
    return _catalog_cache["data"]


def normalize_voice(raw, source="library"):
    """Convert an ElevenLabs voice (library or account shape) into the Voice object the clients use."""
    labels = raw.get("labels") or {}
    name = raw.get("name") or ""
    description = raw.get("description") or ""
    name_parts = NAME_TAGLINE_RE.split(name, maxsplit=1)
    if len(name_parts) == 2:
        name, description = name_parts
    return {
        "voice_id": raw.get("voice_id"),
        "name": name.strip(),
        "description": description.strip()[:200],
        "gender": raw.get("gender") or labels.get("gender") or "",
        "age": (raw.get("age") or labels.get("age") or "").replace("-", "_"),
        "accent": raw.get("accent") or labels.get("accent") or "",
        "use_case": raw.get("use_case") or labels.get("use_case") or "",
        "descriptive": raw.get("descriptive") or labels.get("descriptive") or "",
        "language": raw.get("language") or labels.get("language") or "",
        "locale": raw.get("locale"),
        "preview_url": raw.get("preview_url"),
        "category": raw.get("category") or "",
        "source": source,
    }


def premade_voice_ids():
    return {voice["voice_id"] for voice in catalog().get("premade", [])} | set(FALLBACK_VOICES.values())


def curated_voices(language):
    return catalog().get("languages", {}).get(language, {}).get("voices", [])


def default_voice_id(language):
    entry = catalog().get("languages", {}).get(language, {})
    if entry.get("default"):
        return entry["default"]
    voices = entry.get("voices") or []
    return voices[0]["voice_id"] if voices else FALLBACK_VOICES["female"]


def remember_voice(voice):
    """Cache a voice's metadata so a manifest can describe a library voice outside the catalog."""
    if voice.get("voice_id"):
        _redis().set(f"listen:voice:{voice['voice_id']}", json.dumps(voice), ex=VOICE_METADATA_SECONDS)


def catalog_voice_ids():
    ids = {voice["voice_id"] for voice in catalog().get("premade", [])}
    for entry in catalog().get("languages", {}).values():
        ids.update(voice["voice_id"] for voice in entry.get("voices", []))
    return ids


def is_known_voice(voice_id):
    """Voices Listen may use: well-formed ids from our catalog, the premade set, or a library search (which already
    left out surcharge voices, apps/listen/elevenlabs.py). Our account's private voices and arbitrary ids never
    reach ElevenLabs."""
    if not isinstance(voice_id, str) or not VOICE_ID_RE.match(voice_id):
        return False
    if voice_id in catalog_voice_ids() or voice_id in FALLBACK_VOICES.values():
        return True
    return bool(_redis().exists(f"listen:voice:{voice_id}"))


def usable_voice_id(voice_id, language):
    return voice_id if is_known_voice(voice_id) else default_voice_id(language)


def voice_metadata(voice_id):
    for voice in catalog().get("premade", []):
        if voice["voice_id"] == voice_id:
            return voice
    for entry in catalog().get("languages", {}).values():
        for voice in entry.get("voices", []):
            if voice["voice_id"] == voice_id:
                return voice
    r = _redis()
    cached = r.get(f"listen:voice:{voice_id}")
    if cached:
        # A voice someone is listening with stays remembered.
        r.expire(f"listen:voice:{voice_id}", VOICE_METADATA_SECONDS)
        return json.loads(cached)
    return {
        "voice_id": voice_id,
        "name": gettext("Custom voice"),
        "description": "",
        "gender": "",
        "age": "",
        "accent": "",
        "use_case": "",
        "descriptive": "",
        "language": "",
        "locale": None,
        "preview_url": None,
        "category": "",
        "source": "library",
    }


def fallback_voice_id(voice):
    """The premade voice that sounds closest to voice: same gender, then same accent, then same age.

    Ties go to the earliest voice in apps/listen/voice_catalog.json, so a story's stand-in never changes
    between segments. Without a premade voice of that gender, FALLBACK_VOICES picks by gender alone.
    """
    gender = voice.get("gender") or ""
    same_gender = [premade for premade in catalog().get("premade", []) if premade.get("gender") == gender]
    if not same_gender:
        return FALLBACK_VOICES.get(gender, FALLBACK_VOICES["female"])
    closest = min(
        same_gender,
        key=lambda premade: (
            premade.get("accent") != voice.get("accent"),
            premade.get("age") != voice.get("age"),
        ),
    )
    return closest["voice_id"]


def library_voices_blocked():
    """Set by node/listen.coffee when ElevenLabs refuses library voices (an account without a paid plan)."""
    return bool(_redis().get("listen:library_blocked"))


def search_library(
    language=None,
    gender=None,
    age=None,
    accent=None,
    use_case=None,
    descriptive=None,
    search=None,
    sort="popular",
    page=0,
):
    params = {
        "page_size": LIBRARY_PAGE_SIZE,
        "page": page,
        "gender": gender,
        "age": age,
        "accent": accent,
        "use_cases": use_case,
        "descriptives": descriptive,
        "search": search,
        "sort": LIBRARY_SORTS.get(sort, LIBRARY_SORTS["popular"]),
    }
    if language in ELEVENLABS_LANGUAGES:
        params["language"] = ELEVENLABS_LANGUAGES[language][0]
    cache_key = "listen:library:" + hashlib.sha1(json.dumps(params, sort_keys=True).encode()).hexdigest()
    r = _redis()
    cached = r.get(cache_key)
    if cached:
        return json.loads(cached)
    response = elevenlabs.shared_voices(**params)
    if response is None:
        return None
    result = {
        "voices": [normalize_voice(voice, source="library") for voice in response.get("voices", [])],
        "has_more": bool(response.get("has_more")),
        "page": page,
    }
    for voice in result["voices"]:
        remember_voice(voice)
    r.set(cache_key, json.dumps(result), ex=LIBRARY_CACHE_SECONDS)
    return result


def _float_preference(preferences, key, default, low=0.0, high=1.0):
    try:
        value = float(preferences.get(key, default))
    except (TypeError, ValueError):
        return default
    return min(high, max(low, value))


def _bool_preference(preferences, key, default):
    value = preferences.get(key, default)
    if isinstance(value, str):
        return value.lower() in ("true", "1", "yes")
    return bool(value)


def voice_settings_from(values):
    """ElevenLabs voice_settings for a delivery preset, or for raw values when delivery is "custom"."""
    delivery = values.get("listen_delivery") or DEFAULT_DELIVERY
    if delivery != "custom":
        preset = DELIVERY_PRESETS.get(delivery, DELIVERY_PRESETS[DEFAULT_DELIVERY])
        return {
            "stability": preset["stability"],
            "similarity_boost": preset["similarity"],
            "style": preset["style"],
            "use_speaker_boost": True,
            "speed": 1.0,
        }
    return {
        "stability": round(_float_preference(values, "listen_stability", 0.5), 2),
        "similarity_boost": round(_float_preference(values, "listen_similarity", 0.75), 2),
        "style": round(_float_preference(values, "listen_style", 0.0), 2),
        "use_speaker_boost": _bool_preference(values, "listen_speaker_boost", True),
        "speed": 1.0,
    }


def selected_voices(preferences):
    """The user's voice for each language: their pick if they made one, else our default."""
    try:
        chosen = json.loads(preferences.get("listen_voices") or "{}")
    except (TypeError, ValueError):
        chosen = {}
    if not isinstance(chosen, dict):
        chosen = {}
    return {language: usable_voice_id(chosen.get(language), language) for language in LANGUAGES}


def library_filters():
    """Filter choices for the voice browser. Accents come from the catalog because they vary by language."""
    return {
        "gender": [
            {"value": "female", "label": gettext("Female")},
            {"value": "male", "label": gettext("Male")},
            {"value": "neutral", "label": gettext("Neutral")},
        ],
        "age": [
            {"value": "young", "label": gettext("Young")},
            {"value": "middle_aged", "label": gettext("Middle aged")},
            {"value": "old", "label": gettext("Old")},
        ],
        "use_case": [
            {"value": "narrative_story", "label": gettext("Narration")},
            {"value": "informative_educational", "label": gettext("Informative")},
            {"value": "conversational", "label": gettext("Conversational")},
            {"value": "entertainment_tv", "label": gettext("Entertainment")},
            {"value": "social_media", "label": gettext("Social media")},
            {"value": "advertisement", "label": gettext("Advertising")},
            {"value": "characters_animation", "label": gettext("Characters")},
        ],
        "descriptive": [
            {"value": "calm", "label": gettext("Calm")},
            {"value": "warm", "label": gettext("Warm")},
            {"value": "professional", "label": gettext("Professional")},
            {"value": "confident", "label": gettext("Confident")},
            {"value": "deep", "label": gettext("Deep")},
            {"value": "casual", "label": gettext("Casual")},
            {"value": "crisp", "label": gettext("Crisp")},
            {"value": "soft", "label": gettext("Soft")},
            {"value": "upbeat", "label": gettext("Upbeat")},
            {"value": "formal", "label": gettext("Formal")},
        ],
        "accent": {
            language: entry.get("accents", []) for language, entry in catalog().get("languages", {}).items()
        },
        "sort": [
            {"value": "popular", "label": gettext("Most used")},
            {"value": "trending", "label": gettext("Trending")},
            {"value": "newest", "label": gettext("Newest")},
        ],
    }


def delivery_presets():
    return [{"id": preset_id, **values} for preset_id, values in DELIVERY_PRESETS.items()]
