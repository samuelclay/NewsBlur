"""Clustering tasks: compute duplicate story clusters using title matching and similarity."""

import datetime
import time

import redis
from django.conf import settings

from newsblur_web.celeryapp import app
from utils import log as logging

# clustering/tasks.py: Max feeds per ZRANGEBYSCORE pipeline batch to avoid
# blocking Redis for too long. Each batch is a separate pipeline.execute().
CANDIDATE_FEED_BATCH_SIZE = 50


@app.task(name="compute-story-clusters")
def ComputeStoryClusters(feed_id):
    """Compute story clusters for a feed after it updates.

    Finds duplicate/similar stories across feeds by:
    1. Title normalization (exact title match across feeds)
    2. Elasticsearch more_like_this (semantic similarity)

    Results are stored in Redis for fast lookup during river loads.
    Gated to feeds with archive subscribers.
    """
    from apps.clustering.models import (
        CLUSTER_LOOKBACK_HOURS,
        find_semantic_clusters,
        find_title_clusters,
        merge_clusters,
        store_clusters_to_redis,
    )
    from apps.rss_feeds.models import Feed, MStory

    # Clear dedup key so this feed can be re-enqueued after we finish
    r_update = redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)
    r_update.delete("cluster_queued:%s" % feed_id)

    # Use replica for read-heavy operations to reduce primary Redis load
    r_replica = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_REPLICA_POOL)
    # Writes still go to the primary
    r_primary = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)

    try:
        feed = Feed.objects.get(pk=feed_id)
    except Feed.DoesNotExist:
        return

    # Only cluster for feeds with archive subscribers
    if not feed.archive_subscribers or feed.archive_subscribers <= 0:
        return

    cluster_start = time.time()

    # Get recent stories from this feed
    lookback = datetime.datetime.utcnow() - datetime.timedelta(hours=CLUSTER_LOOKBACK_HOURS)
    lookback_ts = time.mktime(lookback.timetuple())
    now_ts = time.mktime(datetime.datetime.utcnow().timetuple())

    story_hashes = r_replica.zrangebyscore("zF:%s" % feed_id, lookback_ts, now_ts)
    if not story_hashes:
        return

    story_hashes = [h if isinstance(h, str) else h.decode() for h in story_hashes]

    # Skip stories already in a cluster
    pipe = r_replica.pipeline()
    for h in story_hashes:
        pipe.get("sCL:%s" % h)
    existing = pipe.execute()
    unclustered = [h for h, cid in zip(story_hashes, existing) if not cid]
    if not unclustered:
        return

    # Get candidate stories from other feeds that share archive subscribers.
    from apps.reader.models import UserSubscription

    # Find archive users subscribed to this feed
    archive_user_ids = list(
        UserSubscription.objects.filter(
            feed_id=feed_id, active=True, user__profile__is_archive=True
        ).values_list("user_id", flat=True)[:50]
    )
    if not archive_user_ids:
        return

    # Get all feed IDs these users are subscribed to
    related_feed_ids = set(
        UserSubscription.objects.filter(user_id__in=archive_user_ids, active=True).values_list(
            "feed_id", flat=True
        )
    )
    related_feed_ids.discard(feed_id)
    if not related_feed_ids:
        return

    # Fetch candidate stories from related feeds in batched pipelines
    # to avoid blocking Redis for too long with a single large pipeline
    related_feed_ids = list(related_feed_ids)[:200]
    candidate_hashes = set()
    for batch_start in range(0, len(related_feed_ids), CANDIDATE_FEED_BATCH_SIZE):
        batch_feeds = related_feed_ids[batch_start : batch_start + CANDIDATE_FEED_BATCH_SIZE]
        candidate_pipe = r_replica.pipeline()
        for fid in batch_feeds:
            candidate_pipe.zrangebyscore("zF:%s" % fid, lookback_ts, now_ts)
        candidate_results = candidate_pipe.execute()
        for fid, hashes in zip(batch_feeds, candidate_results):
            for h in hashes:
                candidate_hashes.add(h if isinstance(h, str) else h.decode())

    # Check which candidates are already clustered so we can:
    # 1. Skip them from the expensive clustering algorithms
    # 2. Merge new stories into their existing clusters when matched
    candidate_cluster_map = {}
    candidate_list = list(candidate_hashes)
    for batch_start in range(0, len(candidate_list), 500):
        batch = candidate_list[batch_start : batch_start + 500]
        pipe = r_replica.pipeline()
        for h in batch:
            pipe.get("sCL:%s" % h)
        results = pipe.execute()
        for h, cid in zip(batch, results):
            if cid:
                candidate_cluster_map[h] = cid if isinstance(cid, str) else cid.decode()

    # Split candidates into unclustered (for full comparison) and
    # already-clustered (only used for joining new stories to existing clusters)
    unclustered_candidates = candidate_hashes - set(candidate_cluster_map.keys())

    # Combine unclustered stories from this feed + unclustered candidates for clustering.
    # Already-clustered candidates are included so that title matching can detect
    # when a new story should join an existing cluster.
    all_hashes = set(unclustered) | unclustered_candidates | set(candidate_cluster_map.keys())
    if len(all_hashes) < 2:
        return

    # Fetch story metadata from MongoDB
    all_hashes_list = list(all_hashes)
    stories = []
    for batch_start in range(0, len(all_hashes_list), 100):
        batch = all_hashes_list[batch_start : batch_start + 100]
        for story in (
            MStory.objects(story_hash__in=batch)
            .only("story_hash", "story_feed_id", "story_title", "story_date")
            .order_by()
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

    story_title_map = {s["story_hash"]: s["story_title"] for s in stories}

    logging.debug(
        " ---> ~FBClustering: computing clusters for feed %s (%s stories, %s candidates, %s already clustered)"
        % (feed_id, len(unclustered), len(unclustered_candidates), len(candidate_cluster_map))
    )

    # Build original_feed_map and feed_title_map for branched feed resolution
    # and feed-title-aware fuzzy matching. Combines both into one query.
    all_feed_ids = [feed_id] + related_feed_ids
    original_feed_map = {}
    feed_title_map = {}
    for f in Feed.objects.filter(pk__in=all_feed_ids).only("pk", "branch_from_feed", "feed_title"):
        if f.branch_from_feed_id:
            original_feed_map[f.pk] = f.branch_from_feed_id
        else:
            original_feed_map[f.pk] = f.pk
        feed_title_map[f.pk] = f.feed_title or ""

    # Tier 1: Title-based clustering
    title_clusters = find_title_clusters(
        stories, original_feed_map=original_feed_map, feed_title_map=feed_title_map
    )

    # Tier 2: Semantic clustering via Elasticsearch MLT on new stories only.
    # Use story titles as query text, searching both title and content fields
    # in the ES index to find similar stories across related feeds.
    unclustered_stories = [s for s in stories if s["story_hash"] in set(unclustered)]

    semantic_clusters = {}
    if unclustered_stories:
        semantic_clusters = find_semantic_clusters(
            unclustered_stories,
            all_feed_ids,
            lookback_date=lookback,
            original_feed_map=original_feed_map,
            story_title_map=story_title_map,
            feed_title_map=feed_title_map,
        )

    # Merge title and semantic clusters
    if title_clusters or semantic_clusters:
        story_feed_map = {s["story_hash"]: s["story_feed_id"] for s in stories}
        combined = merge_clusters(
            title_clusters,
            semantic_clusters,
            story_feed_map=story_feed_map,
            original_feed_map=original_feed_map,
            story_title_map=story_title_map,
            feed_title_map=feed_title_map,
        )
        store_clusters_to_redis(combined, candidate_cluster_map=candidate_cluster_map)
        logging.debug(
            " ---> ~FBClustering: found %s title + %s semantic = %s combined clusters for feed %s"
            % (len(title_clusters), len(semantic_clusters), len(combined), feed_id)
        )

    # clustering/tasks.py: Record timing for Grafana
    from apps.statistics.rclustering_usage import RClusteringUsage

    cluster_duration_ms = (time.time() - cluster_start) * 1000
    RClusteringUsage.record_timing(cluster_duration_ms)
