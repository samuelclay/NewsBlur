import datetime
import time

import redis
from django.conf import settings

from apps.analyzer.models import (
    MClassifierAuthor,
    MClassifierFeed,
    MClassifierTag,
    MClassifierTitle,
    compute_story_score,
)
from apps.reader.models import UserSubscription
from apps.rss_feeds.models import Feed, MStory
from apps.statistics.rtrending import RTrendingStory
from utils import log as logging


def select_briefing_stories(user_id, period_start, period_end, max_stories=20):
    """
    Select the most important stories for a user's briefing.

    Scoring factors (weighted):
    1. Global trending read time + reader count (40%)
    2. Feed engagement via Feed.well_read_score() (20%)
    3. User affinity via UserSubscription.feed_opens (20%)
    4. Story recency within the period (10%)
    5. Intelligence classifier scores (10%)

    Returns ordered list of (story_hash, score) tuples.
    """
    # apps/briefing/scoring.py: Get all active subscriptions for this user
    user_subs = UserSubscription.objects.filter(user_id=user_id, active=True).select_related("feed")
    if not user_subs:
        return []

    feed_ids = [sub.feed_id for sub in user_subs]
    feed_opens_map = {sub.feed_id: sub.feed_opens or 0 for sub in user_subs}

    # apps/briefing/scoring.py: Get story hashes from the period via Redis sorted sets
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

    # apps/briefing/scoring.py: Batch-fetch trending data for all candidates
    trending_time_map = _get_trending_times(candidate_hashes)
    trending_count_map = _get_trending_counts(candidate_hashes)

    # apps/briefing/scoring.py: Compute max values for normalization
    max_trending_time = max(trending_time_map.values()) if trending_time_map else 1
    max_trending_count = max(trending_count_map.values()) if trending_count_map else 1
    max_feed_opens = max(feed_opens_map.values()) if feed_opens_map else 1

    # apps/briefing/scoring.py: Load intelligence classifiers for the user
    classifier_feeds = list(MClassifierFeed.objects(user_id=user_id))
    classifier_authors = list(MClassifierAuthor.objects(user_id=user_id))
    classifier_tags = list(MClassifierTag.objects(user_id=user_id))
    classifier_titles = list(MClassifierTitle.objects(user_id=user_id))

    # apps/briefing/scoring.py: Load stories for intelligence scoring (batch)
    stories_by_hash = {}
    for batch_start in range(0, len(candidate_hashes), 100):
        batch = candidate_hashes[batch_start : batch_start + 100]
        for story in MStory.objects(story_hash__in=batch):
            stories_by_hash[story.story_hash] = story

    # apps/briefing/scoring.py: Score each candidate
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

        # Feed engagement score (20%): not calling well_read_score per-story (too expensive)
        # Instead use trending feed-level data as a proxy
        feed_engagement_score = 0.0
        if feed_id:
            feed_trending = _get_feed_trending_time(feed_id)
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
            # raw_score is -1, 0, or 1. Map to 0-1 range.
            if raw_score > 0:
                intelligence_score = 0.1
            elif raw_score < 0:
                intelligence_score = -0.1  # Penalize hidden stories

        total_score = trending_score + feed_engagement_score + user_affinity + recency_score + intelligence_score
        scored.append((story_hash, total_score))

    # apps/briefing/scoring.py: Sort by score descending and return top stories
    scored.sort(key=lambda x: x[1], reverse=True)

    # Filter out stories with negative intelligence scores (user hid them)
    scored = [(h, s) for h, s in scored if s >= 0]

    return scored[:max_stories]


def _get_trending_times(story_hashes, days=1):
    """Get trending read times for a batch of story hashes."""
    r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
    today = datetime.date.today().strftime("%Y-%m-%d")
    key = "sRTi:%s" % today

    pipe = r.pipeline()
    for h in story_hashes:
        pipe.zscore(key, h)
    values = pipe.execute()

    result = {}
    for h, val in zip(story_hashes, values):
        if val:
            try:
                result[h] = int(val)
            except (ValueError, TypeError):
                pass
    return result


def _get_trending_counts(story_hashes, days=1):
    """Get trending reader counts for a batch of story hashes."""
    r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
    today = datetime.date.today().strftime("%Y-%m-%d")
    key = "sRTc:%s" % today

    pipe = r.pipeline()
    for h in story_hashes:
        pipe.zscore(key, h)
    values = pipe.execute()

    result = {}
    for h, val in zip(story_hashes, values):
        if val:
            try:
                result[h] = int(val)
            except (ValueError, TypeError):
                pass
    return result


def _get_feed_trending_time(feed_id, days=1):
    """Get total trending read time for a feed."""
    r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
    today = datetime.date.today().strftime("%Y-%m-%d")
    val = r.zscore("fRT:%s" % today, str(feed_id))
    return int(val) if val else 0
