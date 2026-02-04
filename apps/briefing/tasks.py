import datetime

from django.contrib.auth.models import User
from django.db.models import Q
from newsblur_web.celeryapp import app

from utils import log as logging


@app.task(name="generate-briefings", time_limit=600)
def GenerateBriefings():
    """
    Periodic task that runs every 15 minutes.
    Finds users who need a briefing generated and dispatches per-user tasks.
    """
    import pytz

    from apps.briefing.activity import RUserActivity
    from apps.briefing.models import MBriefing, MBriefingPreferences
    from apps.profile.models import Profile

    now = datetime.datetime.utcnow()

    eligible_profiles = Profile.objects.filter(
        Q(is_archive=True) | Q(is_pro=True),
        user__is_staff=True,
    ).select_related("user")

    dispatched = 0
    skipped = 0

    for profile in eligible_profiles:
        user = profile.user

        prefs = MBriefingPreferences.get_or_create(user.pk)
        if not prefs.enabled:
            skipped += 1
            continue

        if prefs.preferred_time:
            try:
                tz = pytz.timezone(str(profile.timezone))
                hour, minute = map(int, prefs.preferred_time.split(":"))
                today = datetime.datetime.now(tz).date()
                local_target = tz.localize(datetime.datetime.combine(today, datetime.time(hour, minute)))
                generation_time = (local_target - datetime.timedelta(minutes=30)).astimezone(pytz.utc).replace(
                    tzinfo=None
                )
            except Exception:
                generation_time = RUserActivity.get_briefing_generation_time(user.pk, profile.timezone)
        else:
            generation_time = RUserActivity.get_briefing_generation_time(user.pk, profile.timezone)

        if now < generation_time:
            skipped += 1
            continue

        if prefs.frequency == "daily":
            period_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
            period_end = period_start + datetime.timedelta(days=1)
        elif prefs.frequency == "twice_daily":
            if now.hour < 12:
                period_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
                period_end = now.replace(hour=12, minute=0, second=0, microsecond=0)
            else:
                period_start = now.replace(hour=12, minute=0, second=0, microsecond=0)
                period_end = period_start + datetime.timedelta(hours=12)
        elif prefs.frequency == "weekly":
            weekday = now.weekday()
            period_start = (now - datetime.timedelta(days=weekday)).replace(
                hour=0, minute=0, second=0, microsecond=0
            )
            period_end = period_start + datetime.timedelta(days=7)
        else:
            period_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
            period_end = period_start + datetime.timedelta(days=1)

        if MBriefing.exists_for_period(user.pk, period_start, period_end):
            skipped += 1
            continue

        GenerateUserBriefing.delay(user.pk)
        dispatched += 1

    logging.debug(
        " ---> GenerateBriefings: dispatched %s, skipped %s of %s eligible users"
        % (dispatched, skipped, eligible_profiles.count())
    )


@app.task(name="generate-user-briefing", time_limit=120, soft_time_limit=110)
def GenerateUserBriefing(user_id, on_demand=False):
    """
    Generate a single user's daily briefing.

    1. Ensure briefing feed exists
    2. Select stories via scoring algorithm
    3. Generate summary
    4. Create MStory for summary in the briefing feed
    5. Create MBriefing record linking summary + curated stories

    When on_demand=True, publishes progress events via Redis pubsub for
    real-time WebSocket updates to the client.
    """
    import json

    import redis

    from apps.briefing.models import MBriefingPreferences, create_briefing_story, ensure_briefing_feed
    from apps.briefing.scoring import select_briefing_stories
    from apps.briefing.summary import generate_briefing_summary
    from django.conf import settings

    try:
        user = User.objects.get(pk=user_id)
    except User.DoesNotExist:
        logging.error(" ---> GenerateUserBriefing: user %s not found" % user_id)
        return

    def publish(event_type, extra=None):
        if not on_demand:
            return
        try:
            r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
            payload = {"type": event_type}
            if extra:
                payload.update(extra)
            r.publish(user.username, "briefing:%s" % json.dumps(payload))
        except Exception as e:
            logging.error(" ---> GenerateUserBriefing: publish error: %s" % e)

    publish("start")

    prefs = MBriefingPreferences.get_or_create(user_id)
    now = datetime.datetime.utcnow()

    if prefs.frequency == "weekly":
        period_start = now - datetime.timedelta(days=7)
    elif prefs.frequency == "twice_daily":
        period_start = now - datetime.timedelta(hours=12)
    else:
        period_start = now - datetime.timedelta(days=1)

    feed = ensure_briefing_feed(user)

    publish("progress", {"step": "scoring", "message": "Selecting your top stories..."})
    scored_stories = select_briefing_stories(
        user_id,
        period_start,
        now,
        max_stories=prefs.story_count or 20,
        story_sources=prefs.story_sources or "all",
        read_filter=prefs.read_filter or "unread",
        include_read=prefs.include_read,
    )

    if len(scored_stories) < 3:
        logging.debug(
            " ---> GenerateUserBriefing: only %s stories for user %s, skipping"
            % (len(scored_stories), user_id)
        )
        publish("error", {"error": "Not enough stories to generate a briefing (found %s, need 3)." % len(scored_stories)})
        return

    publish("progress", {"step": "summary", "message": "Writing your briefing summary..."})
    summary_html = generate_briefing_summary(
        user_id,
        scored_stories,
        now,
        summary_length=prefs.summary_length or "medium",
        summary_style=prefs.summary_style or "editorial",
        sections=prefs.sections,
        custom_section_prompts=prefs.custom_section_prompts,
    )

    if not summary_html:
        logging.error(" ---> GenerateUserBriefing: summary generation failed for user %s" % user_id)
        publish("error", {"error": "Summary generation failed. Please try again."})
        return

    curated_hashes = [s["story_hash"] for s in scored_stories]
    briefing, story = create_briefing_story(feed, user, summary_html, now, curated_hashes, on_demand=on_demand)

    logging.debug(
        " ---> GenerateUserBriefing: completed for user %s — %s stories, hash %s"
        % (user_id, len(curated_hashes), story.story_hash)
    )

    publish("complete")
