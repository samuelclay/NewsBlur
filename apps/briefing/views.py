import datetime
import zlib

import redis
from django.conf import settings
from django.utils.encoding import smart_str

from apps.briefing.activity import RUserActivity
from apps.briefing.models import MBriefing, MBriefingPreferences
from apps.rss_feeds.models import Feed, MStory
from utils import json_functions as json
from utils.user_functions import ajax_login_required


@ajax_login_required
@json.json_view
def load_briefing_stories(request):
    """
    GET /briefing/stories

    Returns briefing data grouped by period with AI summaries and curated stories.
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
        for h in (briefing.curated_story_hashes or []):
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

        briefing_data = {
            "briefing_id": str(briefing.id),
            "briefing_date": (briefing.briefing_date.isoformat() + "Z") if briefing.briefing_date else None,
            "period_start": (briefing.period_start.isoformat() + "Z") if briefing.period_start else None,
            "frequency": briefing.frequency,
            "summary_story": summary_story,
            "curated_story_hashes": curated_hashes,
            "curated_stories": curated_stories,
        }
        briefing_list.append(briefing_data)

    prefs = MBriefingPreferences.get_or_create(user.pk)

    return {
        "briefings": briefing_list,
        "is_preview": not is_premium_archive,
        "briefing_feed_id": prefs.briefing_feed_id,
    }


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
            time_map = {"morning": "07:00", "afternoon": "12:00", "evening": "18:00"}
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
                if story_count in (10, 20, 30, 50):
                    prefs.story_count = story_count
            except (ValueError, TypeError):
                pass

        summary_length = request.POST.get("summary_length")
        if summary_length in ("short", "medium", "detailed"):
            prefs.summary_length = summary_length

        story_sources = request.POST.get("story_sources")
        if story_sources:
            if story_sources in ("all", "focused") or story_sources.startswith("folder:"):
                prefs.story_sources = story_sources

        summary_style = request.POST.get("summary_style")
        if summary_style in ("editorial", "bullets", "headlines"):
            prefs.summary_style = summary_style

        include_read = request.POST.get("include_read")
        if include_read is not None:
            prefs.include_read = include_read in ("true", "1", True)

        prefs.save()

    TIME_DISPLAY_MAP = {"07:00": "morning", "12:00": "afternoon", "18:00": "evening"}
    preferred_time_display = TIME_DISPLAY_MAP.get(prefs.preferred_time, prefs.preferred_time) or "auto"

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
        "enabled": prefs.enabled,
        "briefing_feed_id": prefs.briefing_feed_id,
        "story_count": prefs.story_count or 20,
        "summary_length": prefs.summary_length or "medium",
        "story_sources": prefs.story_sources or "all",
        "summary_style": prefs.summary_style or "editorial",
        "include_read": prefs.include_read,
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
        last_generated = latest_briefing[0].generated_at.isoformat() if latest_briefing[0].generated_at else None

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

    GenerateUserBriefing.delay(user.pk, on_demand=True)

    return {"status": "generating"}


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
        "id": story.story_guid or story.story_hash,
    }
