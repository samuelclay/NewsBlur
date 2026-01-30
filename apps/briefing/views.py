import datetime
import zlib

from django.contrib.auth.decorators import login_required
from django.utils.encoding import smart_str

from apps.briefing.activity import RUserActivity
from apps.briefing.models import MBriefing, MBriefingPreferences, ensure_briefing_feed
from apps.rss_feeds.models import Feed, MStory
from utils import json_functions as json
from utils import log as logging
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
    profile = user.profile
    is_premium_archive = profile.is_archive or profile.is_pro
    limit = int(request.GET.get("limit", 10))

    briefings = MBriefing.latest_for_user(user.pk, limit=limit)

    briefing_list = []
    for briefing in briefings:
        # apps/briefing/views.py: Load the summary story
        summary_story = None
        if briefing.summary_story_hash:
            try:
                story = MStory.objects.get(story_hash=briefing.summary_story_hash)
                summary_story = _story_to_dict(story)
                summary_story["is_briefing_summary"] = True
            except MStory.DoesNotExist:
                pass

        # apps/briefing/views.py: Load curated stories
        curated_hashes = briefing.curated_story_hashes or []
        if not is_premium_archive:
            curated_hashes = curated_hashes[:3]

        curated_stories = []
        if curated_hashes:
            stories_db = MStory.objects(story_hash__in=curated_hashes)
            stories_by_hash = {s.story_hash: s for s in stories_db}

            # apps/briefing/views.py: Load feed info for curated stories
            feed_ids = set(s.story_feed_id for s in stories_db)
            feeds_by_id = {}
            for feed in Feed.objects.filter(pk__in=feed_ids).only("pk", "feed_title", "favicon_color"):
                feeds_by_id[feed.pk] = feed

            # apps/briefing/views.py: Maintain scored order
            for story_hash in curated_hashes:
                story = stories_by_hash.get(story_hash)
                if story:
                    story_dict = _story_to_dict(story)
                    feed = feeds_by_id.get(story.story_feed_id)
                    if feed:
                        story_dict["feed_title"] = feed.feed_title
                        story_dict["favicon_color"] = feed.favicon_color
                        story_dict["feed_id"] = feed.pk
                    curated_stories.append(story_dict)

        briefing_data = {
            "briefing_id": str(briefing.id),
            "briefing_date": briefing.briefing_date.isoformat() if briefing.briefing_date else None,
            "period_start": briefing.period_start.isoformat() if briefing.period_start else None,
            "frequency": briefing.frequency,
            "summary_story": summary_story,
            "curated_story_hashes": curated_hashes,
            "curated_stories": curated_stories,
        }
        briefing_list.append(briefing_data)

    # apps/briefing/views.py: Get the briefing feed_id for the sidebar
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
    prefs = MBriefingPreferences.get_or_create(user.pk)

    if request.method == "POST":
        frequency = request.POST.get("frequency")
        if frequency in ("daily", "twice_daily", "weekly"):
            prefs.frequency = frequency

        preferred_time = request.POST.get("preferred_time")
        if preferred_time == "auto":
            prefs.preferred_time = None
        elif preferred_time in ("morning", "afternoon", "evening"):
            # apps/briefing/views.py: Map named presets to HH:MM
            time_map = {"morning": "07:00", "afternoon": "12:00", "evening": "18:00"}
            prefs.preferred_time = time_map[preferred_time]
        elif preferred_time:
            # apps/briefing/views.py: Validate HH:MM format
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

        prefs.save()

    # apps/briefing/views.py: Map HH:MM back to named preset for frontend
    preferred_time_display = prefs.preferred_time
    if not preferred_time_display:
        preferred_time_display = "auto"
    elif preferred_time_display == "07:00":
        preferred_time_display = "morning"
    elif preferred_time_display == "12:00":
        preferred_time_display = "afternoon"
    elif preferred_time_display == "18:00":
        preferred_time_display = "evening"

    return {
        "frequency": prefs.frequency,
        "preferred_time": preferred_time_display,
        "enabled": prefs.enabled,
        "briefing_feed_id": prefs.briefing_feed_id,
    }


@ajax_login_required
@json.json_view
def briefing_status(request):
    """
    GET /briefing/status — Return briefing generation status and activity data.
    """
    user = request.user
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
    """
    from apps.briefing.tasks import GenerateUserBriefing

    user = request.user
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
