import datetime
import time

import redis
from django.conf import settings
from newsblur_web.celeryapp import app

from utils import log as logging


@app.task(name="compute-story-clusters")
def ComputeStoryClusters(feed_id):
    """Compute story clusters for a feed after it updates.

    Finds duplicate/similar stories across feeds by:
    1. Title normalization (exact title match across feeds)
    2. Elasticsearch more_like_this (semantic similarity)

    Results are stored in Redis for fast lookup during river loads.
    Gated to feeds with premium subscribers. Rate-limited to once per 6h per feed.
    """
    from apps.clustering.models import (
        CLUSTER_LOOKBACK_HOURS,
        find_title_clusters,
        store_clusters_to_redis,
    )
    from apps.rss_feeds.models import Feed, MStory

    r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)

    # Rate limit: once per 6-hour window per feed
    window = datetime.datetime.now().hour // 6
    rate_key = "cCL:%s:%s:%s" % (feed_id, datetime.datetime.now().strftime("%Y-%m-%d"), window)
    if r.get(rate_key):
        return
    r.set(rate_key, 1, ex=6 * 60 * 60)

    try:
        feed = Feed.objects.get(pk=feed_id)
    except Feed.DoesNotExist:
        return

    # Only cluster for feeds with premium subscribers
    if not feed.premium_subscribers or feed.premium_subscribers <= 0:
        return

    # Get recent stories from this feed
    lookback = datetime.datetime.utcnow() - datetime.timedelta(hours=CLUSTER_LOOKBACK_HOURS)
    lookback_ts = time.mktime(lookback.timetuple())
    now_ts = time.mktime(datetime.datetime.utcnow().timetuple())

    story_hashes = r.zrangebyscore("zF:%s" % feed_id, lookback_ts, now_ts)
    if not story_hashes:
        return

    story_hashes = [h if isinstance(h, str) else h.decode() for h in story_hashes]

    # Skip stories already in a cluster
    pipe = r.pipeline()
    for h in story_hashes:
        pipe.get("sCL:%s" % h)
    existing = pipe.execute()
    unclustered = [h for h, cid in zip(story_hashes, existing) if not cid]
    if not unclustered:
        return

    # Get candidate stories from other feeds that share subscribers.
    # Use feeds with overlapping subscribers by checking the feed's similar_feeds
    # or just check feeds subscribed by the same premium users.
    # For efficiency, get all feeds from the same folders as this feed.
    from apps.reader.models import UserSubscription

    # Find premium users subscribed to this feed
    premium_user_ids = list(
        UserSubscription.objects.filter(feed_id=feed_id, active=True, user__profile__is_premium=True).values_list(
            "user_id", flat=True
        )[:50]
    )
    if not premium_user_ids:
        return

    # Get all feed IDs these users are subscribed to
    related_feed_ids = set(
        UserSubscription.objects.filter(user_id__in=premium_user_ids, active=True).values_list(
            "feed_id", flat=True
        )
    )
    related_feed_ids.discard(feed_id)
    if not related_feed_ids:
        return

    # Fetch candidate stories from related feeds in the same time window
    related_feed_ids = list(related_feed_ids)[:200]
    candidate_pipe = r.pipeline()
    for fid in related_feed_ids:
        candidate_pipe.zrangebyscore("zF:%s" % fid, lookback_ts, now_ts)
    candidate_results = candidate_pipe.execute()

    candidate_hashes = set()
    for fid, hashes in zip(related_feed_ids, candidate_results):
        for h in hashes:
            candidate_hashes.add(h if isinstance(h, str) else h.decode())

    # Combine unclustered + candidates for clustering
    all_hashes = set(unclustered) | candidate_hashes
    if len(all_hashes) < 2:
        return

    # Fetch story metadata from MongoDB
    all_hashes_list = list(all_hashes)
    stories = []
    for batch_start in range(0, len(all_hashes_list), 100):
        batch = all_hashes_list[batch_start : batch_start + 100]
        for story in MStory.objects(story_hash__in=batch).only(
            "story_hash", "story_feed_id", "story_title", "story_date"
        ):
            stories.append(
                {
                    "story_hash": story.story_hash,
                    "story_feed_id": story.story_feed_id,
                    "story_title": story.story_title or "",
                    "story_date": time.mktime(story.story_date.timetuple()) if story.story_date else 0,
                }
            )

    if len(stories) < 2:
        return

    logging.debug(
        " ---> ~FBClustering: computing clusters for feed %s (%s stories, %s candidates)"
        % (feed_id, len(unclustered), len(candidate_hashes))
    )

    # Tier 1: Title-based clustering
    title_clusters = find_title_clusters(stories)

    # TODO: Tier 2 semantic clustering (Elasticsearch MLT) is disabled until
    # similarity thresholds are tuned. The current more_like_this results are
    # too loose, grouping unrelated stories together.

    if title_clusters:
        store_clusters_to_redis(title_clusters)
        logging.debug(
            " ---> ~FBClustering: found %s title clusters for feed %s" % (len(title_clusters), feed_id)
        )
