import datetime
import re
import time
import zlib

import redis
from django.conf import settings
from django.utils.encoding import smart_str

from apps.analyzer.models import (
    MClassifierAuthor,
    MClassifierFeed,
    MClassifierTag,
    MClassifierTitle,
    compute_story_score,
)
from apps.reader.models import UserSubscription
from apps.rss_feeds.models import MStory
from utils import log as logging


def select_briefing_stories(
    user_id,
    period_start,
    period_end,
    max_stories=20,
    story_sources="all",
    read_filter="unread",
    include_read=False,
    custom_section_prompts=None,
    active_sections=None,
):
    """
    Select the most important stories for a user's briefing and categorize them
    by reader value (why the user should read them).

    Scoring factors (weighted):
    1. Global trending read time + reader count (40%)
    2. Feed engagement via trending feed data (20%)
    3. User affinity via UserSubscription.feed_opens (20%)
    4. Story recency within the period (10%)
    5. Intelligence classifier scores (10%)

    Each story is categorized (priority order):
    - follow_up: Unread story from a feed the user recently read
    - classifier_match: Matches user's positive intelligence classifiers
    - trending_unread: High trending score (trending_norm > 0.5)
    - long_read: Has significant word count
    - trending_global: Fallback for remaining stories

    Args:
        story_sources: "all" (all feeds) or "folder:FolderName" (specific folder's feeds)
        read_filter: "unread" (all unread) or "focus" (trained-positive feeds only)
        include_read: If False, filter to unread stories only (with fallback)

    Returns list of dicts with keys:
        story_hash, score, is_read, category, content_word_count, classifier_matches
    """
    user_subs = UserSubscription.objects.filter(user_id=user_id, active=True).select_related("feed")
    if not user_subs:
        return []

    feed_ids = [sub.feed_id for sub in user_subs]
    feed_opens_map = {sub.feed_id: sub.feed_opens or 0 for sub in user_subs}

    if read_filter == "focus":
        positive_feed_ids = set(
            cf.feed_id for cf in MClassifierFeed.objects(user_id=user_id) if cf.feed_id and cf.score > 0
        )
        if positive_feed_ids:
            feed_ids = [fid for fid in feed_ids if fid in positive_feed_ids]
            logging.debug(
                " ---> Briefing scoring: focus mode, %s feeds with positive classifiers" % len(feed_ids)
            )

    if story_sources and story_sources.startswith("folder:"):
        folder_name = story_sources[len("folder:") :]
        try:
            from apps.reader.models import UserSubscriptionFolders

            usf = UserSubscriptionFolders.objects.get(user_id=user_id)
            flat_folders = usf.flatten_folders()
            # scoring.py: Collect feeds from the folder AND all subfolders.
            # flatten_folders() keys use "Parent - Child" format for nested folders.
            # The frontend sends only the leaf folder name (e.g. "Child"), so we
            # must also match keys that end with " - folder_name" for nested folders.
            # Two-pass: first find matching keys, then include their subfolders.
            matching_keys = set()
            for key in flat_folders:
                if key == folder_name or key.endswith(" - " + folder_name):
                    matching_keys.add(key)
            folder_feed_ids = set()
            for key, fids in flat_folders.items():
                for match_key in matching_keys:
                    if key == match_key or key.startswith(match_key + " - "):
                        folder_feed_ids.update(fids)
                        break
            feed_ids = [fid for fid in feed_ids if fid in folder_feed_ids]
            logging.debug(
                " ---> Briefing scoring: folder '%s' mode, %s feeds (from %s total)"
                % (folder_name, len(feed_ids), len(user_subs))
            )
        except UserSubscriptionFolders.DoesNotExist:
            logging.debug(
                " ---> Briefing scoring: no UserSubscriptionFolders for user %s, using all feeds" % user_id
            )

    if not feed_ids:
        return []

    r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
    period_start_ts = time.mktime(period_start.timetuple())
    period_end_ts = time.mktime(period_end.timetuple())

    candidate_hashes = []
    pipe = r.pipeline()
    for feed_id in feed_ids:
        pipe.zrangebyscore("zF:%s" % feed_id, period_start_ts, period_end_ts)
    results = pipe.execute()

    feed_id_for_hash = {}
    for feed_id, hashes in zip(feed_ids, results):
        for h in hashes:
            story_hash = h.decode() if isinstance(h, bytes) else h
            candidate_hashes.append(story_hash)
            feed_id_for_hash[story_hash] = feed_id

    if not candidate_hashes:
        return []

    logging.debug(
        " ---> Briefing scoring: %s candidate stories from %s feeds for user %s"
        % (len(candidate_hashes), len(feed_ids), user_id)
    )

    read_stories_key = "RS:%s" % user_id
    pipe_read = r.pipeline()
    for h in candidate_hashes:
        pipe_read.sismember(read_stories_key, h)
    read_results = pipe_read.execute()
    read_status_map = {h: bool(is_read) for h, is_read in zip(candidate_hashes, read_results)}

    trending_time_map = _get_trending_scores(candidate_hashes, "sRTi")
    trending_count_map = _get_trending_scores(candidate_hashes, "sRTc")

    unique_feed_ids = list(set(feed_ids))
    feed_trending_map = _get_feed_trending_times(unique_feed_ids)

    max_trending_time = max(trending_time_map.values()) if trending_time_map else 1
    max_trending_count = max(trending_count_map.values()) if trending_count_map else 1
    max_feed_opens = max(feed_opens_map.values()) if feed_opens_map else 1

    classifier_feeds = list(MClassifierFeed.objects(user_id=user_id))
    classifier_authors = list(MClassifierAuthor.objects(user_id=user_id))
    classifier_tags = list(MClassifierTag.objects(user_id=user_id))
    classifier_titles = list(MClassifierTitle.objects(user_id=user_id))

    feed_title_map = {}
    for sub in user_subs:
        if sub.feed:
            feed_title_map[sub.feed_id] = sub.feed.feed_title

    stories_by_hash = {}
    for batch_start in range(0, len(candidate_hashes), 100):
        batch = candidate_hashes[batch_start : batch_start + 100]
        for story in MStory.objects(story_hash__in=batch):
            stories_by_hash[story.story_hash] = story

    scored = []
    for story_hash in candidate_hashes:
        feed_id = feed_id_for_hash.get(story_hash, 0)

        # Trending score (40%): combine read time and reader count
        trending_time = trending_time_map.get(story_hash, 0)
        trending_count = trending_count_map.get(story_hash, 0)
        trending_norm = 0.0
        if max_trending_time > 0:
            trending_norm += 0.7 * (trending_time / max_trending_time)
        if max_trending_count > 0:
            trending_norm += 0.3 * (trending_count / max_trending_count)
        trending_score = trending_norm * 0.4

        # Feed engagement score (20%)
        feed_engagement_score = 0.0
        if feed_id:
            feed_trending = feed_trending_map.get(feed_id, 0)
            if feed_trending > 0 and max_trending_time > 0:
                feed_engagement_score = min(feed_trending / max_trending_time, 1.0) * 0.2

        # User affinity score (20%): based on feed_opens
        user_affinity = 0.0
        opens = feed_opens_map.get(feed_id, 0)
        if max_feed_opens > 0:
            user_affinity = (opens / max_feed_opens) * 0.2

        # Recency score (10%): newer stories score higher
        recency_score = 0.0
        story = stories_by_hash.get(story_hash)
        if story and story.story_date:
            story_ts = time.mktime(story.story_date.timetuple())
            period_range = max(period_end_ts - period_start_ts, 1)
            recency_score = ((story_ts - period_start_ts) / period_range) * 0.1

        # Intelligence score (10%): user's trained classifiers
        intelligence_score = 0.0
        classifier_matches = []
        if story:
            story_dict = {
                "story_feed_id": story.story_feed_id,
                "story_authors": story.story_author_name or "",
                "story_tags": story.story_tags or [],
                "story_title": story.story_title or "",
            }
            raw_score = compute_story_score(
                story_dict,
                classifier_titles,
                classifier_authors,
                classifier_tags,
                classifier_feeds,
            )
            if raw_score > 0:
                intelligence_score = 0.1
                classifier_matches = _get_classifier_matches(
                    story,
                    classifier_feeds,
                    classifier_authors,
                    classifier_tags,
                    classifier_titles,
                    feed_title_map,
                )
            elif raw_score < 0:
                intelligence_score = -0.1

        total_score = (
            trending_score + feed_engagement_score + user_affinity + recency_score + intelligence_score
        )
        scored.append(
            {
                "story_hash": story_hash,
                "score": total_score,
                "is_read": read_status_map.get(story_hash, False),
                "trending_norm": trending_norm,
                "classifier_matches": classifier_matches,
                "feed_id": feed_id,
            }
        )

    scored.sort(key=lambda x: x["score"], reverse=True)

    # Filter out stories with negative intelligence scores (user hid them)
    scored = [s for s in scored if s["score"] >= 0]

    unread_scored = [s for s in scored if not s["is_read"]]
    if not include_read and len(unread_scored) >= 3:
        scored = unread_scored
    elif not include_read:
        # Fallback: not enough unread stories, include read stories too
        logging.debug(
            " ---> Briefing scoring: only %s unread stories for user %s, including read stories"
            % (len(unread_scored), user_id)
        )

    max_per_feed = 3
    feed_counts = {}
    diverse_scored = []
    for s in scored:
        fid = s["feed_id"]
        if feed_counts.get(fid, 0) >= max_per_feed:
            continue
        feed_counts[fid] = feed_counts.get(fid, 0) + 1
        diverse_scored.append(s)
    scored = diverse_scored

    top_candidates = scored[: max_stories * 2]

    read_feeds_with_dates = {}
    for s in scored:
        if s["is_read"]:
            story = stories_by_hash.get(s["story_hash"])
            if story and story.story_date:
                read_feeds_with_dates.setdefault(s["feed_id"], []).append(story.story_date)

    # scoring.py: Detect duplicate stories across feeds by normalized title
    duplicate_hashes = _find_duplicate_stories(top_candidates, stories_by_hash)

    enriched = []
    for s in top_candidates:
        story = stories_by_hash.get(s["story_hash"])
        word_count = _estimate_word_count(story) if story else 0

        # Categorize by priority: duplicates > follow_up > classifier_match > trending_unread > long_read > trending_global
        category = "trending_global"

        if s["story_hash"] in duplicate_hashes:
            category = "duplicates"
        elif not s["is_read"] and s["feed_id"] in read_feeds_with_dates:
            read_dates = read_feeds_with_dates[s["feed_id"]]
            if story and story.story_date and any(story.story_date > rd for rd in read_dates if rd):
                category = "follow_up"

        if category == "trending_global" and s["classifier_matches"]:
            category = "classifier_match"

        if category == "trending_global" and s["trending_norm"] > 0.5:
            category = "trending_unread"

        if category == "trending_global" and word_count >= 800:
            category = "long_read"

        enriched.append(
            {
                "story_hash": s["story_hash"],
                "score": s["score"],
                "is_read": s["is_read"],
                "category": category,
                "content_word_count": word_count,
                "classifier_matches": s["classifier_matches"],
            }
        )

    result = enriched[:max_stories]

    # scoring.py: Reserve slots for stories matching custom section prompts.
    # Search through remaining candidates for keyword matches in story titles.
    if custom_section_prompts and active_sections:
        selected_hashes = {s["story_hash"] for s in result}
        remaining = [s for s in enriched[max_stories:] if s["story_hash"] not in selected_hashes]

        for i, prompt in enumerate(custom_section_prompts):
            custom_key = "custom_%d" % (i + 1)
            if not active_sections.get(custom_key, False) or not prompt:
                continue
            keywords = [w.lower() for w in prompt.split() if len(w) >= 3]
            if not keywords:
                continue
            reserved = 0
            for s in remaining:
                if reserved >= 2:
                    break
                story = stories_by_hash.get(s["story_hash"])
                if not story or not story.story_title:
                    continue
                title_lower = story.story_title.lower()
                if any(kw in title_lower for kw in keywords):
                    s["category"] = custom_key
                    result.append(s)
                    selected_hashes.add(s["story_hash"])
                    reserved += 1
            if reserved > 0:
                logging.debug(
                    " ---> Briefing scoring: reserved %s stories for %s (%s)" % (reserved, custom_key, prompt)
                )

    return result


def _normalize_title(title):
    """Normalize a story title for duplicate detection."""
    if not title:
        return ""
    title = title.lower().strip()
    title = re.sub(r"[^\w\s]", "", title)
    title = re.sub(r"\s+", " ", title)
    return title


def _find_duplicate_stories(candidates, stories_by_hash):
    """
    Find stories that appear in multiple feeds by comparing normalized titles.
    Returns a set of story_hashes that are duplicates.
    """
    title_groups = {}
    for s in candidates:
        story = stories_by_hash.get(s["story_hash"])
        if not story or not story.story_title:
            continue
        norm_title = _normalize_title(story.story_title)
        if not norm_title or len(norm_title) < 10:
            continue
        title_groups.setdefault(norm_title, []).append(s["story_hash"])

    duplicate_hashes = set()
    for norm_title, hashes in title_groups.items():
        feed_ids = set()
        for h in hashes:
            story = stories_by_hash.get(h)
            if story:
                feed_ids.add(story.story_feed_id)
        if len(feed_ids) >= 2:
            for h in hashes:
                duplicate_hashes.add(h)

    return duplicate_hashes


def _get_classifier_matches(
    story, classifier_feeds, classifier_authors, classifier_tags, classifier_titles, feed_title_map
):
    """Identify which classifiers matched positively for a story."""
    matches = []
    for cf in classifier_feeds:
        if cf.feed_id == story.story_feed_id and cf.score > 0:
            feed_title = feed_title_map.get(cf.feed_id, "")
            if feed_title:
                matches.append("feed:%s" % feed_title)
    for ca in classifier_authors:
        if ca.author and ca.score > 0 and story.story_author_name and ca.author in story.story_author_name:
            matches.append("author:%s" % ca.author)
    for ct in classifier_tags:
        if ct.tag and ct.score > 0 and ct.tag in (story.story_tags or []):
            matches.append("tag:%s" % ct.tag)
    for cti in classifier_titles:
        if cti.title and cti.score > 0 and cti.title.lower() in (story.story_title or "").lower():
            matches.append("title:%s" % cti.title)
    return matches


def _estimate_word_count(story):
    """Estimate word count from story content for long-read detection."""
    content = story.story_content
    if not content and story.story_content_z:
        try:
            content = smart_str(zlib.decompress(story.story_content_z))
        except Exception:
            return 0
    if not content:
        return 0
    text = re.sub(r"<[^>]+>", " ", content)
    return len(text.split())


def _get_trending_scores(keys, key_prefix):
    """Batch-fetch trending scores from a Redis sorted set by key prefix."""
    r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
    today = datetime.date.today().strftime("%Y-%m-%d")
    key = "%s:%s" % (key_prefix, today)

    pipe = r.pipeline()
    for h in keys:
        pipe.zscore(key, h)
    values = pipe.execute()

    result = {}
    for h, val in zip(keys, values):
        if val:
            try:
                result[h] = int(val)
            except (ValueError, TypeError):
                pass
    return result


def _get_feed_trending_times(feed_ids):
    """Batch-fetch trending read times for a list of feed IDs."""
    r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
    today = datetime.date.today().strftime("%Y-%m-%d")
    key = "fRT:%s" % today

    pipe = r.pipeline()
    for fid in feed_ids:
        pipe.zscore(key, str(fid))
    values = pipe.execute()

    result = {}
    for fid, val in zip(feed_ids, values):
        if val:
            try:
                result[fid] = int(val)
            except (ValueError, TypeError):
                pass
    return result
