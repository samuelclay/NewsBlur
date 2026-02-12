import re
import time

import redis
from django.conf import settings

from utils import log as logging

# clustering/models.py: Cluster ID TTL (14 days)
CLUSTER_TTL_SECONDS = 14 * 24 * 60 * 60
CLUSTER_LOOKBACK_HOURS = 48
CLUSTER_MAX_SIZE = 10
TITLE_MIN_LENGTH = 10
FUZZY_MIN_WORDS = 5
FUZZY_SIMILARITY_THRESHOLD = 0.6

# clustering/models.py: Common English stopwords for fuzzy title matching
STOPWORDS = frozenset(
    "a an the and or but in on at to for of is it by with from as be was were are this that"
    " have has had do does did will would could should may might can shall not no its his her"
    " their our your my its been being".split()
)


def normalize_title(title):
    """Normalize a story title for duplicate detection.

    Extracted from apps/briefing/scoring.py for shared use.
    """
    if not title:
        return ""
    title = title.lower().strip()
    title = re.sub(r"[^\w\s]", "", title)
    title = re.sub(r"\s+", " ", title)
    return title


def title_significant_words(title):
    """Extract significant (non-stopword) words from a normalized title."""
    norm = normalize_title(title)
    return frozenset(w for w in norm.split() if w not in STOPWORDS and len(w) > 2)


def find_title_clusters(stories):
    """Group stories by title similarity across different feeds.

    Uses two tiers:
    1. Exact normalized title match (fast, O(n))
    2. Significant-word overlap with Jaccard similarity >= threshold (catches
       rephrased headlines about the same event)

    Args:
        stories: list of dicts with at minimum 'story_hash', 'story_title', 'story_feed_id'

    Returns:
        dict of {cluster_key: [story_hash, ...]} where cluster_key is the
        story_hash of the earliest story in each group. Only groups with
        stories from 2+ different feeds are returned.
    """
    # Tier 1: Exact normalized title match
    title_groups = {}
    for s in stories:
        title = s.get("story_title") or ""
        norm = normalize_title(title)
        if not norm or len(norm) < TITLE_MIN_LENGTH:
            continue
        title_groups.setdefault(norm, []).append(s)

    # clustering/models.py: Union-find for merging exact + fuzzy matches
    parent = {}

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[ra] = rb

    story_by_hash = {s["story_hash"]: s for s in stories}

    # Add all stories with valid titles to union-find
    for s in stories:
        norm = normalize_title(s.get("story_title") or "")
        if norm and len(norm) >= TITLE_MIN_LENGTH:
            parent[s["story_hash"]] = s["story_hash"]

    # Union exact matches
    for norm_title, group in title_groups.items():
        feed_ids = set(s["story_feed_id"] for s in group)
        if len(feed_ids) < 2:
            continue
        for i in range(1, len(group)):
            union(group[0]["story_hash"], group[i]["story_hash"])

    # Tier 2: Fuzzy matching via significant-word Jaccard similarity
    # Build word-set index for stories not yet in a multi-feed cluster
    word_index = []
    for s in stories:
        h = s["story_hash"]
        if h not in parent:
            continue
        words = title_significant_words(s.get("story_title") or "")
        if len(words) >= FUZZY_MIN_WORDS:
            word_index.append((h, s["story_feed_id"], words))

    # Compare stories from different feeds using inverted index for efficiency
    from collections import defaultdict

    inverted = defaultdict(list)
    for idx, (h, fid, words) in enumerate(word_index):
        for w in words:
            inverted[w].append(idx)

    seen_pairs = set()
    for w, indices in inverted.items():
        if len(indices) > 50:
            continue
        for i in range(len(indices)):
            for j in range(i + 1, len(indices)):
                idx_a, idx_b = indices[i], indices[j]
                if idx_a > idx_b:
                    idx_a, idx_b = idx_b, idx_a
                pair = (idx_a, idx_b)
                if pair in seen_pairs:
                    continue
                seen_pairs.add(pair)

                h_a, fid_a, words_a = word_index[idx_a]
                h_b, fid_b, words_b = word_index[idx_b]
                if fid_a == fid_b:
                    continue

                intersection = len(words_a & words_b)
                union_size = len(words_a | words_b)
                if union_size == 0:
                    continue
                jaccard = intersection / union_size
                if jaccard >= FUZZY_SIMILARITY_THRESHOLD:
                    union(h_a, h_b)

    # Collect groups from union-find
    groups = {}
    for h in parent:
        root = find(h)
        groups.setdefault(root, []).append(h)

    # Only return clusters with 2+ stories from different feeds
    clusters = {}
    for root, members in groups.items():
        if len(members) < 2:
            continue
        member_feeds = set(story_by_hash[h]["story_feed_id"] for h in members)
        if len(member_feeds) < 2:
            continue
        members.sort(key=lambda h: story_by_hash[h].get("story_date") or 0)
        cluster_id = members[0]
        clusters[cluster_id] = members[:CLUSTER_MAX_SIZE]

    return clusters


def find_semantic_clusters(stories, feed_ids, lookback_date=None, min_score=30):
    """Find semantically similar stories using Elasticsearch more_like_this.

    For each story, sends its title + content as text to ES MLT to find
    similar stories across different feeds. Groups results using union-find.

    Only run this on the new/unclustered stories (not all candidates) to
    keep ES query count low (~1-20 queries per feed update).

    Args:
        stories: list of dicts with 'story_hash', 'story_feed_id', 'story_title',
                 and optionally 'story_content' (plaintext, truncated)
        feed_ids: list of all feed IDs to search across
        lookback_date: datetime for the oldest stories to match (limits ES results)
        min_score: minimum ES relevance score to consider a match

    Returns:
        dict of {cluster_id: [story_hash, ...]}
    """
    import elasticsearch

    from apps.search.models import SearchStory

    if not stories or not feed_ids:
        return {}

    story_feed_map = {s["story_hash"]: s["story_feed_id"] for s in stories}

    # clustering/models.py: Union-find for grouping similar stories
    parent = {s["story_hash"]: s["story_hash"] for s in stories}

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[ra] = rb

    try:
        es = SearchStory.ES()
        index_name = SearchStory.index_name()
    except Exception as e:
        logging.debug(" ---> ~FRClustering: ES not available: %s" % e)
        return {}

    for story in stories:
        story_hash = story["story_hash"]
        # Use only title as query text (not content) to avoid topical noise.
        # ES still searches both title and content fields in the index, so
        # matching works when title terms appear in another article's body.
        query_text = story.get("story_title") or ""

        if not query_text or len(query_text.strip()) < 10:
            continue

        # Search across related feeds, excluding this story's own feed
        search_feed_ids = [fid for fid in feed_ids if fid != story["story_feed_id"]]
        if not search_feed_ids:
            continue

        body = {
            "query": {
                "bool": {
                    "must": [
                        {
                            "more_like_this": {
                                "fields": ["title", "content"],
                                "like": query_text[:2000],
                                "min_term_freq": 1,
                                "min_doc_freq": 2,
                                "min_word_length": 3,
                                "max_query_terms": 25,
                            }
                        }
                    ],
                    "filter": [
                        {"terms": {"feed_id": search_feed_ids[:2000]}},
                    ]
                    + (
                        [{"range": {"date": {"gte": lookback_date.strftime("%Y-%m-%d")}}}]
                        if lookback_date
                        else []
                    ),
                }
            },
            "min_score": min_score,
            "size": 5,
            "_source": False,
            "docvalue_fields": ["feed_id"],
        }

        try:
            results = es.search(body=body, index=index_name)
            hits = results.get("hits", {}).get("hits", [])
        except elasticsearch.exceptions.NotFoundError:
            continue
        except elasticsearch.exceptions.ConnectionError as e:
            logging.debug(" ---> ~FRClustering: ES connection error: %s" % e)
            return {}
        except Exception as e:
            logging.debug(" ---> ~FRClustering semantic search error for %s: %s" % (story_hash, e))
            continue

        for hit in hits:
            sim_hash = hit["_id"]
            if sim_hash == story_hash:
                continue
            sim_feed = (hit.get("fields", {}).get("feed_id") or [None])[0]
            if sim_feed:
                story_feed_map[sim_hash] = sim_feed
            if sim_hash not in parent:
                parent[sim_hash] = sim_hash
            union(story_hash, sim_hash)

    # Collect clusters
    groups = {}
    for h in parent:
        root = find(h)
        groups.setdefault(root, []).append(h)

    # Only return clusters with 2+ stories from different feeds
    clusters = {}
    for root, members in groups.items():
        if len(members) < 2:
            continue
        member_feeds = set(story_feed_map.get(h) for h in members if story_feed_map.get(h))
        if len(member_feeds) < 2:
            continue
        clusters[root] = members[:CLUSTER_MAX_SIZE]

    return clusters


def merge_clusters(title_clusters, semantic_clusters, story_feed_map=None):
    """Merge title-based and semantic clusters using union-find.

    If any story appears in both a title cluster and a semantic cluster,
    the two clusters are merged into one.

    Args:
        title_clusters: dict of {cluster_id: [story_hash, ...]}
        semantic_clusters: dict of {cluster_id: [story_hash, ...]}
        story_feed_map: dict of {story_hash: feed_id} for multi-feed validation

    Returns:
        dict of {cluster_id: [story_hash, ...]}
    """
    all_hashes = set()
    for members in title_clusters.values():
        all_hashes.update(members)
    for members in semantic_clusters.values():
        all_hashes.update(members)

    if not all_hashes:
        return {}

    parent = {h: h for h in all_hashes}

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[ra] = rb

    # Union within title clusters
    for members in title_clusters.values():
        for i in range(1, len(members)):
            union(members[0], members[i])

    # Union within semantic clusters
    for members in semantic_clusters.values():
        for i in range(1, len(members)):
            union(members[0], members[i])

    # Collect final groups
    groups = {}
    for h in all_hashes:
        root = find(h)
        groups.setdefault(root, []).append(h)

    # If we have feed info, enforce multi-feed requirement after merge
    if story_feed_map:
        # Look up any unknown feed_ids from MongoDB
        unknown = [h for h in all_hashes if h not in story_feed_map]
        if unknown:
            from apps.rss_feeds.models import MStory

            for batch_start in range(0, len(unknown), 100):
                batch = unknown[batch_start : batch_start + 100]
                for s in MStory.objects(story_hash__in=batch).only("story_hash", "story_feed_id"):
                    story_feed_map[s.story_hash] = s.story_feed_id

        clusters = {}
        for root, members in groups.items():
            if len(members) < 2:
                continue
            member_feeds = set(story_feed_map.get(h) for h in members if story_feed_map.get(h))
            if len(member_feeds) < 2:
                continue
            clusters[root] = members[:CLUSTER_MAX_SIZE]
        return clusters

    return {root: members[:CLUSTER_MAX_SIZE] for root, members in groups.items() if len(members) >= 2}


def store_clusters_to_redis(clusters, ttl=CLUSTER_TTL_SECONDS):
    """Write cluster memberships to Redis.

    Keys:
        sCL:{story_hash} -> cluster_id (STRING with TTL)
        zCL:{cluster_id} -> sorted set of story_hashes scored by story_date
    """
    if not clusters:
        return

    r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
    pipe = r.pipeline()

    for cluster_id, members in clusters.items():
        for story_hash in members:
            pipe.set("sCL:%s" % story_hash, cluster_id, ex=ttl)
        # Store cluster members (sorted set scored by timestamp 0 for now,
        # will be overwritten with real dates if available)
        for story_hash in members:
            pipe.zadd("zCL:%s" % cluster_id, {story_hash: 0})
        pipe.expire("zCL:%s" % cluster_id, ttl)

    pipe.execute()
    logging.debug(
        " ---> ~FBClustering: stored %s clusters with %s total stories"
        % (len(clusters), sum(len(m) for m in clusters.values()))
    )


def get_cluster_for_story(story_hash):
    """Look up the cluster_id for a story_hash from Redis."""
    r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
    cid = r.get("sCL:%s" % story_hash)
    if cid and isinstance(cid, bytes):
        cid = cid.decode()
    return cid


def get_cluster_members(cluster_id):
    """Get all story_hashes in a cluster from Redis."""
    r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
    if isinstance(cluster_id, bytes):
        cluster_id = cluster_id.decode()
    members = r.zrange("zCL:%s" % cluster_id, 0, -1)
    return [m.decode() if isinstance(m, bytes) else m for m in members]


def apply_clustering_to_stories(stories, user):
    """Apply clustering to a list of story dicts from the river view.

    For each story on the current page that belongs to a cluster, fetches
    all cluster members (even those not on the current page) and attaches
    them as cluster_stories metadata. If multiple cluster members appear
    on the same page, the highest-scoring one is kept and others are removed.

    Args:
        stories: list of story dicts (already scored with 'score' key)
        user: User object

    Returns:
        Modified stories list with cluster_stories attached to representatives.
    """
    if not stories:
        return stories

    r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)

    # Batch lookup cluster memberships for stories on this page
    story_hashes = [s["story_hash"] for s in stories]
    pipe = r.pipeline()
    for h in story_hashes:
        pipe.get("sCL:%s" % h)
    cluster_ids = pipe.execute()

    # Map story_hash -> cluster_id for stories on this page
    # clustering/models.py: Redis returns bytes, decode to str
    hash_to_cluster = {}
    unique_cluster_ids = set()
    for h, cid in zip(story_hashes, cluster_ids):
        if cid:
            cid_str = cid.decode() if isinstance(cid, bytes) else cid
            hash_to_cluster[h] = cid_str
            unique_cluster_ids.add(cid_str)

    if not hash_to_cluster:
        return stories

    # Fetch ALL members for each cluster (including those not on this page)
    cluster_all_members = {}
    pipe = r.pipeline()
    for cid in unique_cluster_ids:
        pipe.zrange("zCL:%s" % cid, 0, -1)
    member_results = pipe.execute()
    for cid, members in zip(unique_cluster_ids, member_results):
        cluster_all_members[cid] = [m.decode() if isinstance(m, bytes) else m for m in members]

    # Build a set of story hashes on this page for quick lookup
    page_hashes = set(story_hashes)
    page_stories_by_hash = {s["story_hash"]: s for s in stories}

    # For each cluster, fetch metadata for members NOT on this page from MongoDB
    off_page_hashes = set()
    for cid, members in cluster_all_members.items():
        for h in members:
            if h not in page_hashes:
                off_page_hashes.add(h)

    from apps.rss_feeds.models import Feed, MStory

    off_page_metadata = {}
    if off_page_hashes:
        off_page_list = list(off_page_hashes)
        for batch_start in range(0, len(off_page_list), 100):
            batch = off_page_list[batch_start : batch_start + 100]
            for story in MStory.objects(story_hash__in=batch).only(
                "story_hash", "story_feed_id", "story_title", "story_date"
            ):
                feed = Feed.get_by_id(story.story_feed_id)
                off_page_metadata[story.story_hash] = {
                    "story_hash": story.story_hash,
                    "story_feed_id": story.story_feed_id,
                    "story_title": story.story_title or "",
                    "story_date": story.story_date.strftime("%Y-%m-%d %H:%M") if story.story_date else "",
                    "story_timestamp": str(int(story.story_date.timestamp())) if story.story_date else "",
                    "feed_title": feed.feed_title if feed else "",
                }

    # Group page stories by cluster_id
    cluster_page_stories = {}
    for story in stories:
        cid = hash_to_cluster.get(story["story_hash"])
        if cid:
            cluster_page_stories.setdefault(cid, []).append(story)

    # For each cluster, pick the representative and build cluster_stories
    clustered_hashes = set()
    representative_hashes = set()
    cluster_data = {}

    for cid, page_group in cluster_page_stories.items():
        all_members = cluster_all_members.get(cid, [])
        if len(all_members) < 2:
            continue

        # The representative is the highest-scoring story on this page
        page_group.sort(key=lambda s: s.get("score", 0), reverse=True)
        representative = page_group[0]
        representative_hashes.add(representative["story_hash"])

        # Mark other on-page members as clustered (to remove from results)
        for s in page_group[1:]:
            clustered_hashes.add(s["story_hash"])

        # Build cluster_stories from ALL other members (on-page and off-page)
        cluster_stories = []
        for member_hash in all_members:
            if member_hash == representative["story_hash"]:
                continue

            if member_hash in page_stories_by_hash:
                # On-page member
                s = page_stories_by_hash[member_hash]
                feed = Feed.get_by_id(s["story_feed_id"])
                cluster_stories.append(
                    {
                        "story_hash": s["story_hash"],
                        "story_feed_id": s["story_feed_id"],
                        "story_title": s.get("story_title", ""),
                        "story_date": s.get("story_date", ""),
                        "story_timestamp": s.get("story_timestamp", ""),
                        "feed_title": feed.feed_title if feed else "",
                    }
                )
            elif member_hash in off_page_metadata:
                # Off-page member fetched from MongoDB
                cluster_stories.append(off_page_metadata[member_hash])

        if cluster_stories:
            cluster_data[representative["story_hash"]] = cluster_stories

    # Rebuild stories list: keep representatives (with cluster_stories attached),
    # remove non-representative clustered stories
    result = []
    for story in stories:
        h = story["story_hash"]
        if h in clustered_hashes and h not in representative_hashes:
            continue
        if h in cluster_data:
            story["cluster_stories"] = cluster_data[h]
        result.append(story)

    if cluster_data:
        total_clustered = sum(len(cs) + 1 for cs in cluster_data.values())
        logging.debug(
            " ---> ~FBClustering: grouped %s stories into %s clusters for user %s"
            % (total_clustered, len(cluster_data), user.pk)
        )

    return result
