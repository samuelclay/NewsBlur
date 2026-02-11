import datetime
import re
import zlib

import redis
from django.conf import settings
from django.utils.encoding import smart_str

from apps.briefing.activity import RUserActivity
from apps.briefing.models import (
    BRIEFING_SECTION_DEFINITIONS,
    DEFAULT_SECTIONS,
    VALID_SECTION_KEYS,
    MBriefing,
    MBriefingPreferences,
    ensure_briefing_feed,
)
from apps.briefing.summary import normalize_section_key
from apps.notifications.models import MUserFeedNotification
from apps.rss_feeds.models import Feed, MStory
from utils import json_functions as json
from utils.user_functions import ajax_login_required


def _normalize_section_dict(d, merge_lists=False):
    """
    Normalize all keys in a section dict using normalize_section_key.

    Drops keys that can't be normalized. If merge_lists=True and multiple keys
    normalize to the same key, their list values are merged (for curated_sections).
    Otherwise, later values overwrite earlier ones (for section_summaries).
    """
    if not d:
        return {}
    result = {}
    for key, value in d.items():
        normalized = normalize_section_key(key)
        if normalized is None:
            continue
        if merge_lists and normalized in result and isinstance(value, list):
            result[normalized] = result[normalized] + value
        else:
            result[normalized] = value
    return result


def _get_briefing_notification_types(user_id, briefing_feed_id):
    """Return list of active notification types for the user's briefing feed."""
    notification_types = []
    if briefing_feed_id:
        try:
            notif = MUserFeedNotification.objects.get(user_id=user_id, feed_id=briefing_feed_id)
            if notif.is_email:
                notification_types.append("email")
            if notif.is_web:
                notification_types.append("web")
            if notif.is_ios:
                notification_types.append("ios")
            if notif.is_android:
                notification_types.append("android")
        except MUserFeedNotification.DoesNotExist:
            pass
    return notification_types


@ajax_login_required
@json.json_view
def load_briefing_stories(request):
    """
    GET /briefing/stories

    Returns briefing data grouped by period with summaries and curated stories.
    Premium archive/pro users get full briefings; others get a preview.
    """
    user = request.user
    if not user.is_staff:
        return {"code": -1, "message": "Daily Briefing is currently staff-only."}
    profile = user.profile
    is_premium_archive = profile.is_archive or profile.is_pro
    limit = int(request.GET.get("limit", 10))

    briefings = MBriefing.latest_for_user(user.pk, limit=limit)

    r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
    read_stories_key = "RS:%s" % user.pk
    all_briefing_hashes = set()
    for briefing in briefings:
        if briefing.summary_story_hash:
            all_briefing_hashes.add(briefing.summary_story_hash)
        for h in briefing.curated_story_hashes or []:
            all_briefing_hashes.add(h)

    read_hashes = set()
    if all_briefing_hashes:
        pipe = r.pipeline()
        hash_list = list(all_briefing_hashes)
        for h in hash_list:
            pipe.sismember(read_stories_key, h)
        results = pipe.execute()
        for h, is_read in zip(hash_list, results):
            if is_read:
                read_hashes.add(h)

    briefing_list = []
    for briefing in briefings:
        summary_story = None
        if briefing.summary_story_hash:
            try:
                story = MStory.objects.get(story_hash=briefing.summary_story_hash)
                summary_story = _story_to_dict(story)
                summary_story["is_briefing_summary"] = True
                summary_story["read_status"] = 1 if story.story_hash in read_hashes else 0
            except MStory.DoesNotExist:
                pass

        curated_hashes = briefing.curated_story_hashes or []
        if not is_premium_archive:
            curated_hashes = curated_hashes[:3]

        curated_stories = []
        if curated_hashes:
            stories_db = MStory.objects(story_hash__in=curated_hashes)
            stories_by_hash = {s.story_hash: s for s in stories_db}

            feed_ids = set(s.story_feed_id for s in stories_db)
            feeds_by_id = {}
            for feed in Feed.objects.filter(pk__in=feed_ids).only("pk", "feed_title", "favicon_color"):
                feeds_by_id[feed.pk] = feed

            for story_hash in curated_hashes:
                story = stories_by_hash.get(story_hash)
                if story:
                    story_dict = _story_to_dict(story)
                    story_dict["read_status"] = 1 if story_hash in read_hashes else 0
                    feed = feeds_by_id.get(story.story_feed_id)
                    if feed:
                        story_dict["feed_title"] = feed.feed_title
                        story_dict["favicon_color"] = feed.favicon_color
                        story_dict["feed_id"] = feed.pk
                    curated_stories.append(story_dict)

        # views.py: Normalize section keys to handle legacy data with incorrect keys
        normalized_curated_sections = _normalize_section_dict(briefing.curated_sections, merge_lists=True)
        normalized_section_summaries = _normalize_section_dict(briefing.section_summaries)

        briefing_data = {
            "briefing_id": str(briefing.id),
            "briefing_date": (briefing.briefing_date.isoformat() + "Z") if briefing.briefing_date else None,
            "period_start": (briefing.period_start.isoformat() + "Z") if briefing.period_start else None,
            "frequency": briefing.frequency,
            "summary_story": summary_story,
            "curated_story_hashes": curated_hashes,
            "curated_stories": curated_stories,
            "curated_sections": normalized_curated_sections,
            "section_summaries": normalized_section_summaries,
        }
        briefing_list.append(briefing_data)

    prefs = MBriefingPreferences.get_or_create(user.pk)

    section_definitions = {s["key"]: s["name"] for s in BRIEFING_SECTION_DEFINITIONS}

    # views.py: Add display names for custom sections from user prompts
    custom_prompts = prefs.custom_section_prompts or []
    for i, prompt in enumerate(custom_prompts):
        custom_key = "custom_%d" % (i + 1)
        if prompt:
            section_definitions[custom_key] = prompt

    # views.py: Add display names for AI-generated sections not in BRIEFING_SECTION_DEFINITIONS.
    # Extract the name from the <h3> tag text, skipping any embedded <img> icons.
    for briefing in briefings:
        for key, html in (briefing.section_summaries or {}).items():
            if key not in section_definitions and html:
                match = re.search(r"<h3[^>]*>(?:<img[^>]*>)?\s*([^<]+)</h3>", html)
                if match:
                    section_definitions[key] = match.group(1).strip()

    result = {
        "briefings": briefing_list,
        "is_preview": not is_premium_archive,
        "briefing_feed_id": prefs.briefing_feed_id,
        "enabled": prefs.enabled,
        "section_definitions": section_definitions,
    }

    # views.py: Include full preferences when not enabled so the onboarding view
    # can render settings immediately without a separate AJAX call.
    if not prefs.enabled and not briefing_list:
        from apps.ask_ai.providers import (
            DEFAULT_BRIEFING_MODEL,
            get_briefing_models_for_frontend,
        )

        TIME_DISPLAY_MAP = {"08:00": "morning", "13:00": "afternoon", "17:00": "evening"}
        preferred_time_display = TIME_DISPLAY_MAP.get(prefs.preferred_time, prefs.preferred_time) or "morning"
        result["preferences"] = {
            "frequency": prefs.frequency,
            "preferred_time": preferred_time_display,
            "preferred_day": prefs.preferred_day or "sun",
            "story_count": prefs.story_count or 5,
            "summary_length": prefs.summary_length or "medium",
            "story_sources": prefs.story_sources or "all",
            "read_filter": prefs.read_filter or "unread",
            "summary_style": prefs.summary_style or "bullets",
            "include_read": prefs.include_read,
            "sections": prefs.sections if prefs.sections else DEFAULT_SECTIONS,
            "custom_section_prompts": prefs.custom_section_prompts or [],
            "notification_types": _get_briefing_notification_types(user.pk, prefs.briefing_feed_id),
            "briefing_feed_id": prefs.briefing_feed_id,
            "briefing_model": prefs.briefing_model or DEFAULT_BRIEFING_MODEL,
            "briefing_models": get_briefing_models_for_frontend(),
        }

    return result


@ajax_login_required
@json.json_view
def briefing_preferences(request):
    """
    GET /briefing/preferences — Return current briefing preferences.
    POST /briefing/preferences — Update preferences.
    """
    user = request.user
    if not user.is_staff:
        return {"code": -1, "message": "Daily Briefing is currently staff-only."}
    prefs = MBriefingPreferences.get_or_create(user.pk)

    if request.method == "POST":
        frequency = request.POST.get("frequency")
        if frequency in ("daily", "twice_daily", "weekly"):
            prefs.frequency = frequency

        preferred_time = request.POST.get("preferred_time")
        if preferred_time == "auto":
            prefs.preferred_time = None
        elif preferred_time in ("morning", "afternoon", "evening"):
            time_map = {"morning": "08:00", "afternoon": "13:00", "evening": "17:00"}
            prefs.preferred_time = time_map[preferred_time]
        elif preferred_time:
            try:
                parts = preferred_time.split(":")
                hour = int(parts[0])
                minute = int(parts[1])
                if 0 <= hour <= 23 and 0 <= minute <= 59:
                    prefs.preferred_time = "%02d:%02d" % (hour, minute)
            except (ValueError, IndexError):
                pass

        enabled = request.POST.get("enabled")
        if enabled is not None:
            prefs.enabled = enabled in ("true", "1", True)

        story_count = request.POST.get("story_count")
        if story_count:
            try:
                story_count = int(story_count)
                if story_count in (5, 10, 15, 20):
                    prefs.story_count = story_count
            except (ValueError, TypeError):
                pass

        summary_length = request.POST.get("summary_length")
        if summary_length in ("short", "medium", "detailed"):
            prefs.summary_length = summary_length

        story_sources = request.POST.get("story_sources")
        if story_sources:
            if story_sources in ("all",) or story_sources.startswith("folder:"):
                prefs.story_sources = story_sources

        read_filter = request.POST.get("read_filter")
        if read_filter in ("unread", "focus"):
            prefs.read_filter = read_filter

        summary_style = request.POST.get("summary_style")
        if summary_style in ("editorial", "bullets", "headlines"):
            prefs.summary_style = summary_style

        briefing_model = request.POST.get("briefing_model")
        if briefing_model is not None:
            from apps.ask_ai.providers import VALID_BRIEFING_MODELS

            if briefing_model in VALID_BRIEFING_MODELS:
                prefs.briefing_model = briefing_model
            elif briefing_model in ("", "default"):
                prefs.briefing_model = None

        include_read = request.POST.get("include_read")
        if include_read is not None:
            prefs.include_read = include_read in ("true", "1", True)

        preferred_day = request.POST.get("preferred_day")
        if preferred_day in ("sun", "mon", "tue", "wed", "thu", "fri", "sat"):
            prefs.preferred_day = preferred_day

        import json as stdlib_json

        sections_raw = request.POST.get("sections")
        if sections_raw:
            try:
                sections_dict = stdlib_json.loads(sections_raw)
                if isinstance(sections_dict, dict):
                    validated = {}
                    for key, val in sections_dict.items():
                        if key in VALID_SECTION_KEYS:
                            validated[key] = bool(val)
                    prefs.sections = validated
            except (ValueError, TypeError):
                pass

        custom_section_prompts_raw = request.POST.get("custom_section_prompts")
        if custom_section_prompts_raw:
            try:
                prompts = stdlib_json.loads(custom_section_prompts_raw)
                if isinstance(prompts, list):
                    validated_prompts = [p.strip()[:500] for p in prompts if isinstance(p, str) and p.strip()]
                    prefs.custom_section_prompts = validated_prompts[:5] or None
            except (ValueError, TypeError):
                pass

        prefs.save()

    # Migrate old "focused" story_sources to the new read_filter field
    if prefs.story_sources == "focused":
        prefs.story_sources = "all"
        prefs.read_filter = "focus"
        prefs.save()

    TIME_DISPLAY_MAP = {"08:00": "morning", "13:00": "afternoon", "17:00": "evening"}
    preferred_time_display = TIME_DISPLAY_MAP.get(prefs.preferred_time, prefs.preferred_time) or "morning"

    from apps.ask_ai.providers import (
        DEFAULT_BRIEFING_MODEL,
        get_briefing_models_for_frontend,
    )

    folders = []
    try:
        from apps.reader.models import UserSubscriptionFolders

        usf = UserSubscriptionFolders.objects.get(user_id=user.pk)
        flat_folders = usf.flatten_folders()
        folders = sorted([name.strip() for name in flat_folders.keys() if name.strip()])
    except UserSubscriptionFolders.DoesNotExist:
        pass

    return {
        "frequency": prefs.frequency,
        "preferred_time": preferred_time_display,
        "preferred_day": prefs.preferred_day or "sun",
        "enabled": prefs.enabled,
        "briefing_feed_id": prefs.briefing_feed_id,
        "story_count": prefs.story_count or 5,
        "summary_length": prefs.summary_length or "medium",
        "story_sources": prefs.story_sources or "all",
        "read_filter": prefs.read_filter or "unread",
        "summary_style": prefs.summary_style or "bullets",
        "include_read": prefs.include_read,
        "sections": prefs.sections if prefs.sections else DEFAULT_SECTIONS,
        "custom_section_prompts": prefs.custom_section_prompts or [],
        "notification_types": _get_briefing_notification_types(user.pk, prefs.briefing_feed_id),
        "briefing_model": prefs.briefing_model or DEFAULT_BRIEFING_MODEL,
        "briefing_models": get_briefing_models_for_frontend(),
        "folders": folders,
    }


@ajax_login_required
@json.json_view
def briefing_status(request):
    """
    GET /briefing/status — Return briefing generation status and activity data.
    """
    user = request.user
    if not user.is_staff:
        return {"code": -1, "message": "Daily Briefing is currently staff-only."}
    prefs = MBriefingPreferences.get_or_create(user.pk)

    typical_hour = RUserActivity.get_typical_reading_hour(user.pk)
    histogram = RUserActivity.get_activity_histogram(user.pk)

    latest_briefing = MBriefing.latest_for_user(user.pk, limit=1)
    last_generated = None
    if latest_briefing:
        last_generated = (
            latest_briefing[0].generated_at.isoformat() if latest_briefing[0].generated_at else None
        )

    next_generation = None
    if prefs.enabled:
        next_gen_utc = RUserActivity.get_briefing_generation_time(user.pk, user.profile.timezone)
        if next_gen_utc:
            next_generation = next_gen_utc.isoformat()

    return {
        "enabled": prefs.enabled,
        "frequency": prefs.frequency,
        "preferred_time": prefs.preferred_time,
        "typical_reading_hour": typical_hour,
        "activity_histogram": histogram,
        "last_generated": last_generated,
        "next_generation": next_generation,
        "briefing_feed_id": prefs.briefing_feed_id,
    }


@ajax_login_required
@json.json_view
def generate_briefing(request):
    """
    POST /briefing/generate

    Triggers on-demand briefing generation with real-time progress via WebSocket.
    Staff-only during initial rollout.
    """
    if request.method != "POST":
        return {"code": -1, "message": "POST required"}

    from apps.briefing.tasks import GenerateUserBriefing

    user = request.user
    if not user.is_staff:
        return {"code": -1, "message": "Daily Briefing is currently staff-only."}

    # views.py: Generating a briefing implicitly opts the user in to auto-generation
    prefs = MBriefingPreferences.get_or_create(user.pk)
    if not prefs.enabled:
        prefs.enabled = True
        prefs.save()

    # views.py: Create the briefing feed synchronously so the frontend can save
    # notification preferences immediately, before the Celery task runs.
    feed = ensure_briefing_feed(user)

    GenerateUserBriefing.delay(user.pk, on_demand=True)

    return {"status": "generating", "briefing_feed_id": feed.pk}


def _story_to_dict(story):
    """Convert an MStory to a serializable dict."""
    content = story.story_content
    if not content and story.story_content_z:
        try:
            content = smart_str(zlib.decompress(story.story_content_z))
        except Exception:
            content = ""

    story_date = story.story_date or datetime.datetime.utcnow()

    return {
        "story_hash": story.story_hash,
        "story_title": story.story_title,
        "story_content": content,
        "story_date": story_date.isoformat(),
        "story_timestamp": story_date.strftime("%s"),
        "story_authors": story.story_author_name or "",
        "story_permalink": story.story_permalink,
        "story_feed_id": story.story_feed_id,
        "story_tags": story.story_tags or [],
        "image_urls": story.image_urls or [],
        "secure_image_urls": Feed.secure_image_urls(story.image_urls or []),
        "id": story.story_guid or story.story_hash,
    }
