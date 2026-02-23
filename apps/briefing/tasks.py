"""Briefing tasks: generate and deliver personalized email briefings on schedule."""

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
    import redis
    from django.conf import settings

    from apps.briefing.models import MBriefing, MBriefingPreferences
    from apps.profile.models import Profile

    # tasks.py: Distributed lock — multiple celery beat schedulers (one per htask-work
    # server) fire this task concurrently. Only one instance should run per 15-min cycle.
    # TTL of 14 minutes (just under the 15-min schedule) ensures the lock persists for
    # the entire interval. We intentionally do NOT delete the lock on completion — the
    # task finishes in ~0.1s, and deleting would let later beat tasks acquire the lock.
    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    lock_key = "briefing:generate_all_lock"
    if not r.set(lock_key, "1", nx=True, ex=840):
        logging.debug(" ---> GenerateBriefings: another instance is running, skipping")
        return

    DAY_NAME_TO_WEEKDAY = {"mon": 0, "tue": 1, "wed": 2, "thu": 3, "fri": 4, "sat": 5, "sun": 6}
    # tasks.py: Fixed delivery times for each slot (user's local timezone)
    SLOT_TIMES = {"morning": (8, 0), "afternoon": (13, 0), "evening": (17, 0)}
    DEFAULT_SLOT = "morning"

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

        try:
            tz = pytz.timezone(str(profile.timezone))
        except Exception:
            tz = pytz.utc
        local_now = datetime.datetime.now(tz)

        # tasks.py: Compute generation_time (UTC, naive) — 30 min before preferred delivery.
        # Parse preferred_time "HH:MM" to determine slot, default to morning (8 AM).
        TIME_TO_SLOT = {"08:00": "morning", "13:00": "afternoon", "17:00": "evening"}
        slot = TIME_TO_SLOT.get(prefs.preferred_time, DEFAULT_SLOT)
        # tasks.py: For twice_daily, preferred_time stores the second slot.
        # If it resolves to "morning" (legacy bug), default to "afternoon" instead.
        if prefs.frequency == "twice_daily" and slot == "morning":
            slot = "afternoon"
        hour, minute = SLOT_TIMES[slot]
        local_target = tz.localize(datetime.datetime.combine(local_now.date(), datetime.time(hour, minute)))
        generation_time = (
            (local_target - datetime.timedelta(minutes=30)).astimezone(pytz.utc).replace(tzinfo=None)
        )

        # tasks.py: For twice_daily, preferred_time is the second slot (afternoon or evening).
        # The morning slot always fires at 8 AM local. Check both windows independently
        # so the morning run isn't blocked by a later preferred_time.
        if prefs.frequency == "twice_daily":
            morning_hour, morning_minute = SLOT_TIMES["morning"]
            morning_local = tz.localize(
                datetime.datetime.combine(local_now.date(), datetime.time(morning_hour, morning_minute))
            )
            morning_gen_utc = (
                (morning_local - datetime.timedelta(minutes=30)).astimezone(pytz.utc).replace(tzinfo=None)
            )
            is_morning_window = now >= morning_gen_utc and local_now.hour < 15
            is_second_window = now >= generation_time
            if not is_morning_window and not is_second_window:
                skipped += 1
                continue
        else:
            if now < generation_time:
                skipped += 1
                continue

        # tasks.py: Build period bounds in the user's local timezone so dedupe
        # matches local days, not UTC day boundaries.
        local_midnight = tz.localize(datetime.datetime.combine(local_now.date(), datetime.time(0, 0)))

        if prefs.frequency == "daily":
            period_start = local_midnight.astimezone(pytz.utc).replace(tzinfo=None)
            period_end = (
                (local_midnight + datetime.timedelta(days=1)).astimezone(pytz.utc).replace(tzinfo=None)
            )
        elif prefs.frequency == "twice_daily":
            local_noon = local_midnight + datetime.timedelta(hours=12)
            if local_now.hour < 12:
                period_start = local_midnight.astimezone(pytz.utc).replace(tzinfo=None)
                period_end = local_noon.astimezone(pytz.utc).replace(tzinfo=None)
            else:
                period_start = local_noon.astimezone(pytz.utc).replace(tzinfo=None)
                period_end = (
                    (local_midnight + datetime.timedelta(days=1)).astimezone(pytz.utc).replace(tzinfo=None)
                )
        elif prefs.frequency == "weekly":
            preferred_weekday = DAY_NAME_TO_WEEKDAY.get(prefs.preferred_day, 6)
            if local_now.weekday() != preferred_weekday:
                skipped += 1
                continue
            period_start = local_midnight.astimezone(pytz.utc).replace(tzinfo=None)
            period_end = (
                (local_midnight + datetime.timedelta(days=7)).astimezone(pytz.utc).replace(tzinfo=None)
            )
        else:
            period_start = local_midnight.astimezone(pytz.utc).replace(tzinfo=None)
            period_end = (
                (local_midnight + datetime.timedelta(days=1)).astimezone(pytz.utc).replace(tzinfo=None)
            )

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
    from django.conf import settings

    from apps.briefing.models import (
        MBriefingPreferences,
        create_briefing_story,
        ensure_briefing_feed,
    )
    from apps.briefing.scoring import select_briefing_stories
    from apps.briefing.summary import (
        embed_briefing_icons,
        extract_section_story_hashes,
        extract_section_summaries,
        filter_disabled_sections,
        generate_briefing_summary,
    )

    # tasks.py: Per-user distributed lock prevents duplicate generation from
    # concurrent task dispatches (race conditions, retries, multiple beat schedulers).
    # For scheduled generation, the lock persists via TTL (not deleted on completion)
    # so that duplicate dispatches arriving after the first completes are still blocked.
    # For on_demand (user-initiated regeneration), we delete the lock on completion
    # so the user can regenerate again immediately.
    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    lock_key = "briefing:generate_user:%s" % user_id
    lock_ttl = 120 if on_demand else 840
    if not r.set(lock_key, "1", nx=True, ex=lock_ttl):
        logging.debug(" ---> GenerateUserBriefing: already running for user %s, skipping" % user_id)
        return

    try:
        user = User.objects.get(pk=user_id)
    except User.DoesNotExist:
        logging.error(" ---> GenerateUserBriefing: user %s not found" % user_id)
        return

    def publish(event_type, extra=None):
        if not on_demand:
            return
        try:
            r2 = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
            payload = {"type": event_type}
            if extra:
                payload.update(extra)
            r2.publish(user.username, "briefing:%s" % json.dumps(payload))
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
        max_stories=prefs.story_count or 5,
        story_sources=prefs.story_sources or "all",
        read_filter=prefs.read_filter or "unread",
        include_read=prefs.include_read,
        custom_section_prompts=prefs.custom_section_prompts,
        active_sections=prefs.sections,
    )

    # tasks.py: Lower minimum threshold for twice_daily since 12-hour windows may have fewer stories
    min_stories = 1 if prefs.frequency == "twice_daily" else 3
    if len(scored_stories) < min_stories:
        logging.debug(
            " ---> GenerateUserBriefing: only %s stories for user %s, skipping (need %s)"
            % (len(scored_stories), user_id, min_stories)
        )
        publish(
            "error",
            {
                "error": "Not enough stories to generate a briefing (found %s, need %s)."
                % (len(scored_stories), min_stories)
            },
        )
        return

    # tasks.py: Disable custom sections that have no matching stories so the LLM
    # doesn't force-fit unrelated stories to a custom prompt (e.g. "Trump news" in a gaming folder).
    matched_custom_sections = set()
    for s in scored_stories:
        cat = s.get("category", "")
        if cat.startswith("custom_"):
            matched_custom_sections.add(cat)

    filtered_sections = dict(prefs.sections) if prefs.sections else {}
    if prefs.custom_section_prompts:
        for i, prompt in enumerate(prefs.custom_section_prompts):
            custom_key = "custom_%d" % (i + 1)
            if custom_key not in matched_custom_sections:
                filtered_sections[custom_key] = False

    publish("progress", {"step": "summary", "message": "Writing your briefing summary..."})
    import time

    t_summary_start = time.monotonic()
    summary_html, summary_meta = generate_briefing_summary(
        user_id,
        scored_stories,
        now,
        summary_length=prefs.summary_length or "medium",
        summary_style=prefs.summary_style or "bullets",
        sections=filtered_sections or prefs.sections,
        custom_section_prompts=prefs.custom_section_prompts,
        model=prefs.briefing_model,
    )
    t_summary_elapsed = time.monotonic() - t_summary_start

    if not summary_html:
        logging.error(" ---> GenerateUserBriefing: summary generation failed for user %s" % user_id)
        publish("error", {"error": "Summary generation failed. Please try again."})
        return

    # tasks.py: Strip sections from output that the user has disabled. The LLM may
    # occasionally create sections it wasn't instructed to because it sees category
    # annotations in the story data.
    active_sections = filtered_sections or prefs.sections
    if active_sections:
        summary_html = filter_disabled_sections(summary_html, active_sections)

    # tasks.py: Embed feed favicons and section icons directly in the HTML so they
    # appear in email notifications and don't pop in on the web.
    summary_html = embed_briefing_icons(summary_html, scored_stories)

    # tasks.py: Append debug footer with model and generation stats
    if summary_meta:
        num_candidates = len(scored_stories)
        footer_parts = [
            summary_meta.get("display_name", "Unknown model"),
            "%s stories" % num_candidates,
            "{:,} in / {:,} out tokens".format(
                summary_meta.get("input_tokens", 0), summary_meta.get("output_tokens", 0)
            ),
            "%.1fs" % t_summary_elapsed,
        ]
        summary_html += (
            '\n<p class="NB-briefing-debug" style="margin-top:2em;font-style:italic;'
            'color:#999;font-size:12px;">%s</p>' % " · ".join(footer_parts)
        )

    curated_hashes = [s["story_hash"] for s in scored_stories]
    curated_sections = {}
    for s in scored_stories:
        curated_sections.setdefault(s.get("category", "trending_global"), []).append(s["story_hash"])

    # tasks.py: Filter curated_sections to remove disabled section keys, remapping their
    # stories to trending_global so the sidebar doesn't show pills for disabled categories.
    if active_sections:
        allowed_curated = {k for k, v in active_sections.items() if v}
        allowed_curated.add("trending_global")
        filtered_curated = {}
        for key, hashes in curated_sections.items():
            if key in allowed_curated:
                filtered_curated.setdefault(key, []).extend(hashes)
            else:
                filtered_curated.setdefault("trending_global", []).extend(hashes)
        curated_sections = filtered_curated

    section_summaries = extract_section_summaries(summary_html)
    # tasks.py: Filter section_summaries to remove disabled sections
    if active_sections:
        allowed = {k for k, v in active_sections.items() if v}
        allowed.add("trending_global")
        section_summaries = {k: v for k, v in section_summaries.items() if k in allowed}
    # tasks.py: Merge story hashes referenced in the AI summary into curated_sections.
    # The AI may organize stories into sections (like "Quick catch-up") that don't
    # correspond to scoring categories, referencing stories via data-story-hash links.
    summary_hashes = extract_section_story_hashes(section_summaries)
    curated_hash_set = set(curated_hashes)
    for key, hashes in summary_hashes.items():
        if key not in curated_sections:
            curated_sections[key] = [h for h in hashes if h in curated_hash_set]
    briefing, story = create_briefing_story(
        feed,
        user,
        summary_html,
        now,
        curated_hashes,
        on_demand=on_demand,
        curated_sections=curated_sections,
        section_summaries=section_summaries,
    )

    logging.debug(
        " ---> GenerateUserBriefing: completed for user %s — %s stories, hash %s"
        % (user_id, len(curated_hashes), story.story_hash)
    )

    publish("complete")

    if on_demand:
        r.delete(lock_key)
