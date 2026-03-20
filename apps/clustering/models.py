"""Clustering models: detect duplicate and similar stories across feeds."""

import re
import time

import redis
from django.conf import settings

from utils import log as logging

# clustering/models.py: Cluster ID TTL (14 days)
CLUSTER_TTL_SECONDS = 14 * 24 * 60 * 60
CLUSTER_LOOKBACK_HOURS = 120
CLUSTER_MAX_SIZE = 10
TITLE_MIN_LENGTH = 10
FUZZY_MIN_WORDS = 5
FUZZY_SIMILARITY_THRESHOLD = 0.6
FUZZY_MIN_INTERSECTION = 3
SEMANTIC_MIN_TITLE_INTERSECTION = 3

# clustering/models.py: Common English stopwords for fuzzy title matching
STOPWORDS = frozenset(
    "a an the and or but in on at to for of is it by with from as be was were are this that"
    " have has had do does did will would could should may might can shall not no its his her"
    " their our your my its been being"
    " he she so up if me we am us go oh ok".split()
)


def normalize_title(title):
    """Normalize a story title for duplicate detection.

    Extracted from apps/briefing/scoring.py for shared use.
    """
    if not title:
        return ""
    title = title.lower().strip()
    # clustering/models.py: Replace hyphens and slashes with spaces before
    # stripping punctuation so "Anthropic-backed" becomes "anthropic backed"
    # (two tokens) rather than "anthropicbacked" (one merged token).
    title = re.sub(r"[-/]", " ", title)
    title = re.sub(r"[^\w\s]", "", title)
    title = re.sub(r"\s+", " ", title)
    return title


def _simple_stem(word):
    """Strip trailing 's' for basic plural normalization.

    Only applies to words longer than 3 characters to avoid
    mangling short words like 'bus', 'gas', 'ios'.
    Does not strip 'ss' endings (e.g. 'press', 'class').
    """
    if len(word) > 3 and word.endswith("s") and not word.endswith("ss"):
        return word[:-1]
    return word


def title_significant_words(title):
    """Extract significant (non-stopword) words from a normalized title.

    Filters out purely numeric tokens (e.g. '2026', '17') which cause
    date-based false matches across unrelated stories.
    """
    norm = normalize_title(title)
    return frozenset(
        _simple_stem(w) for w in norm.split() if w not in STOPWORDS and len(w) > 1 and not w.isdigit()
    )


def title_words_excluding_feed(story_title, feed_title):
    """Significant words from story title excluding words that appear in the feed title.

    Prevents false fuzzy matches when story titles consistently start with
    the feed name (e.g. "Saturday Morning Breakfast Cereal - Cow").
    """
    story_words = title_significant_words(story_title)
    if feed_title:
        feed_words = title_significant_words(feed_title)
        story_words = story_words - feed_words
    return story_words


def story_guid_hash(story_hash):
    """Extract the GUID hash suffix from a story_hash (format: feed_id:guid_hash).

    Stories from duplicate/branched feeds share the same GUID hash, so
    matching on this detects the same underlying content regardless of feed.
    """
    return story_hash.split(":", 1)[1] if ":" in story_hash else story_hash


def resolve_feed_id(feed_id, original_feed_map):
    """Resolve a feed_id to its original (non-branched) feed_id.

    Branched feeds share the same original_feed_id, so clustering treats
    them as the same source to avoid false clusters.
    """
    if original_feed_map:
        return original_feed_map.get(feed_id, feed_id)
    return feed_id


def find_title_clusters(stories, original_feed_map=None, feed_title_map=None):
    """Group stories by title similarity across different feeds.

    Uses two tiers:
    1. Exact normalized title match (fast, O(n))
    2. Significant-word overlap with Jaccard similarity >= threshold (catches
       rephrased headlines about the same event)

    Skips pairs that share the same GUID hash (duplicate/branched feed copies)
    or resolve to the same original feed via branch_from_feed.

    Args:
        stories: list of dicts with at minimum 'story_hash', 'story_title', 'story_feed_id'
        original_feed_map: dict of {feed_id: original_feed_id} for branched feed resolution

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

    # Union exact matches: GUID-dedup the group first so we compare all
    # genuinely different stories, not just pairs anchored on group[0].
    for norm_title, group in title_groups.items():
        # Keep one representative per unique GUID to avoid unioning duplicates
        guid_reps = {}
        for s in group:
            guid = story_guid_hash(s["story_hash"])
            if guid not in guid_reps:
                guid_reps[guid] = s
        deduped_group = list(guid_reps.values())
        # Need 2+ different resolved feeds among GUID-unique stories
        rfids = set(resolve_feed_id(s["story_feed_id"], original_feed_map) for s in deduped_group)
        if len(rfids) < 2:
            continue
        # Union all GUID-unique stories together
        for i in range(1, len(deduped_group)):
            union(deduped_group[0]["story_hash"], deduped_group[i]["story_hash"])

    # Tier 2: Fuzzy matching via significant-word Jaccard similarity
    # Build word-set index for stories not yet in a multi-feed cluster.
    # When feed_title_map is provided, strip feed title words so that
    # shared feed-name prefixes (e.g. "Saturday Morning Breakfast Cereal")
    # don't dominate the similarity score.
    word_index = []
    for s in stories:
        h = s["story_hash"]
        if h not in parent:
            continue
        if feed_title_map:
            feed_title = feed_title_map.get(s["story_feed_id"], "")
            words = title_words_excluding_feed(s.get("story_title") or "", feed_title)
        else:
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
                if resolve_feed_id(fid_a, original_feed_map) == resolve_feed_id(fid_b, original_feed_map):
                    continue
                if story_guid_hash(h_a) == story_guid_hash(h_b):
                    continue

                intersection = len(words_a & words_b)
                if intersection < FUZZY_MIN_INTERSECTION:
                    continue
                # clustering/models.py: Use overlap coefficient (intersection / min set size)
                # instead of Jaccard to handle asymmetric title lengths.
                # Aggregator titles (Techmeme, Google News) include source attribution
                # and extra detail, making them 2-3x longer than the original title.
                # Jaccard penalizes these because the union is dominated by the
                # longer title's unique words. Overlap coefficient normalizes by the
                # smaller set, so a short title sharing most words with a long title
                # scores high.
                smaller = min(len(words_a), len(words_b))
                if smaller == 0:
                    continue
                similarity = intersection / smaller
                if similarity >= FUZZY_SIMILARITY_THRESHOLD:
                    union(h_a, h_b)

    # Collect groups from union-find
    groups = {}
    for h in parent:
        root = find(h)
        groups.setdefault(root, []).append(h)

    # Only return clusters with 2+ GUID-unique stories from different resolved feeds.
    # Keep ALL members (including GUID duplicates) so every story_hash gets an sCL:
    # key in Redis — otherwise the dropped copy can't resolve its cluster.
    clusters = {}
    for root, members in groups.items():
        if len(members) < 2:
            continue
        # Validate using GUID-unique members: need 2+ unique stories from 2+ feeds
        guid_to_feed = {}
        for h in members:
            guid = story_guid_hash(h)
            if guid not in guid_to_feed:
                guid_to_feed[guid] = resolve_feed_id(story_by_hash[h]["story_feed_id"], original_feed_map)
        if len(guid_to_feed) < 2:
            continue
        if len(set(guid_to_feed.values())) < 2:
            continue
        members.sort(key=lambda h: story_by_hash[h].get("story_date") or 0)
        cluster_id = members[0]
        clusters[cluster_id] = members[:CLUSTER_MAX_SIZE]

    return clusters


def find_semantic_clusters(
    stories,
    feed_ids,
    lookback_date=None,
    min_score=30,
    original_feed_map=None,
    story_title_map=None,
    feed_title_map=None,
    max_es_queries=200,
    deadline=None,
):
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
        max_es_queries: max number of ES queries per invocation (safety cap, default 200)
        deadline: absolute time.time() value after which no new ES queries are issued

    Returns:
        tuple of (dict of {cluster_id: [story_hash, ...]}, dict of ES stats,
                  set of story_hashes that were checked)
    """
    import elasticsearch

    from apps.search.models import SearchStory

    es_stats = {
        "query_count": 0,
        "total_ms": 0,
        "max_ms": 0,
        "stories_compared": len(stories) if stories else 0,
        "skipped_short_title": 0,
        "skipped_no_feeds": 0,
        "skipped_deadline": 0,
        "skipped_max_queries": 0,
        "hits_found": 0,
        "hits_matched": 0,
    }
    # clustering/models.py: Track which stories were actually checked (had ES
    # query run, or skipped for legitimate reasons like short title / no feeds).
    # Stories skipped due to cap/deadline are NOT included — they need re-checking.
    checked_hashes = set()

    if not stories or not feed_ids:
        return {}, es_stats, checked_hashes

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
        return {}, es_stats, checked_hashes

    for story in stories:
        # clustering/models.py: Check budget limits before issuing ES queries
        if es_stats["query_count"] >= max_es_queries:
            es_stats["skipped_max_queries"] += 1
            continue
        if deadline and time.time() >= deadline:
            es_stats["skipped_deadline"] += 1
            continue

        story_hash = story["story_hash"]
        # Use only title as query text (not content) to avoid topical noise.
        # ES still searches both title and content fields in the index, so
        # matching works when title terms appear in another article's body.
        query_text = story.get("story_title") or ""

        if not query_text or len(query_text.strip()) < 10:
            es_stats["skipped_short_title"] += 1
            # Story was evaluated — short title won't change, mark as checked
            checked_hashes.add(story_hash)
            continue

        # Search across related feeds, excluding this story's own feed and its branches
        story_rfid = resolve_feed_id(story["story_feed_id"], original_feed_map)
        search_feed_ids = [fid for fid in feed_ids if resolve_feed_id(fid, original_feed_map) != story_rfid]
        if not search_feed_ids:
            es_stats["skipped_no_feeds"] += 1
            # No feeds to search won't change for this story, mark as checked
            checked_hashes.add(story_hash)
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
            query_start = time.time()
            results = es.search(body=body, index=index_name, request_timeout=5)
            query_ms = (time.time() - query_start) * 1000
            es_stats["query_count"] += 1
            es_stats["total_ms"] += query_ms
            es_stats["max_ms"] = max(es_stats["max_ms"], query_ms)
            hits = results.get("hits", {}).get("hits", [])
            es_stats["hits_found"] += len(hits)
        except elasticsearch.exceptions.NotFoundError:
            checked_hashes.add(story_hash)
            continue
        except elasticsearch.exceptions.ConnectionError as e:
            logging.debug(" ---> ~FRClustering: ES connection error: %s" % e)
            return {}, es_stats, checked_hashes
        except Exception as e:
            logging.debug(" ---> ~FRClustering semantic search error for %s: %s" % (story_hash, e))
            checked_hashes.add(story_hash)
            continue

        # ES query ran successfully — mark as checked regardless of hits
        checked_hashes.add(story_hash)

        for hit in hits:
            sim_hash = hit["_id"]
            if sim_hash == story_hash:
                continue
            # Skip duplicate/branched feed copies of the same story
            if story_guid_hash(sim_hash) == story_guid_hash(story_hash):
                continue
            sim_feed = (hit.get("fields", {}).get("feed_id") or [None])[0]
            if sim_feed:
                story_feed_map[sim_hash] = sim_feed
            # clustering/models.py: Validate title-word overlap before unioning.
            # ES more_like_this can match on shared terms like "apple" + "app"
            # even when the stories are about completely different topics.
            # When feed_title_map is provided, strip feed title words so
            # shared feed-name prefixes don't inflate the intersection count.
            if story_title_map:
                if feed_title_map:
                    query_feed_title = feed_title_map.get(story["story_feed_id"], "")
                    query_title_words = title_words_excluding_feed(
                        story.get("story_title") or "", query_feed_title
                    )
                else:
                    query_title_words = title_significant_words(story.get("story_title") or "")
                sim_title = story_title_map.get(sim_hash, "")
                if sim_title:
                    if feed_title_map and sim_feed:
                        sim_feed_title = feed_title_map.get(sim_feed, "")
                        sim_title_words = title_words_excluding_feed(sim_title, sim_feed_title)
                    else:
                        sim_title_words = title_significant_words(sim_title)
                    if len(query_title_words & sim_title_words) < SEMANTIC_MIN_TITLE_INTERSECTION:
                        continue
                else:
                    continue
            if sim_hash not in parent:
                parent[sim_hash] = sim_hash
            union(story_hash, sim_hash)
            es_stats["hits_matched"] += 1

    # Collect clusters
    groups = {}
    for h in parent:
        root = find(h)
        groups.setdefault(root, []).append(h)

    # Only return clusters with 2+ GUID-unique stories from different resolved feeds.
    # Keep ALL members so every story_hash gets an sCL: key in Redis.
    clusters = {}
    for root, members in groups.items():
        if len(members) < 2:
            continue
        guid_to_feed = {}
        for h in members:
            guid = story_guid_hash(h)
            if guid not in guid_to_feed and story_feed_map.get(h):
                guid_to_feed[guid] = resolve_feed_id(story_feed_map[h], original_feed_map)
        if len(guid_to_feed) < 2:
            continue
        if len(set(guid_to_feed.values())) < 2:
            continue
        clusters[root] = members[:CLUSTER_MAX_SIZE]

    # Compute average for stats
    if es_stats["query_count"] > 0:
        es_stats["avg_ms"] = round(es_stats["total_ms"] / es_stats["query_count"], 1)
    else:
        es_stats["avg_ms"] = 0

    return clusters, es_stats, checked_hashes


def merge_clusters(
    title_clusters,
    semantic_clusters,
    story_feed_map=None,
    original_feed_map=None,
    story_title_map=None,
    feed_title_map=None,
):
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

    # Union within semantic clusters (with title-word validation when available).
    # When feed_title_map is provided, strip feed title words so shared
    # feed-name prefixes don't inflate the intersection count.
    for members in semantic_clusters.values():
        for i in range(1, len(members)):
            if story_title_map:
                title_a = story_title_map.get(members[0], "")
                title_b = story_title_map.get(members[i], "")
                if title_a and title_b:
                    if feed_title_map and story_feed_map:
                        ft_a = feed_title_map.get(story_feed_map.get(members[0]), "")
                        ft_b = feed_title_map.get(story_feed_map.get(members[i]), "")
                        words_a = title_words_excluding_feed(title_a, ft_a)
                        words_b = title_words_excluding_feed(title_b, ft_b)
                    else:
                        words_a = title_significant_words(title_a)
                        words_b = title_significant_words(title_b)
                    if len(words_a & words_b) < SEMANTIC_MIN_TITLE_INTERSECTION:
                        continue
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
                for s in MStory.objects(story_hash__in=batch).only("story_hash", "story_feed_id").order_by():
                    story_feed_map[s.story_hash] = s.story_feed_id

        clusters = {}
        for root, members in groups.items():
            if len(members) < 2:
                continue
            guid_to_feed = {}
            for h in members:
                guid = story_guid_hash(h)
                if guid not in guid_to_feed and story_feed_map.get(h):
                    guid_to_feed[guid] = resolve_feed_id(story_feed_map[h], original_feed_map)
            if len(guid_to_feed) < 2:
                continue
            if len(set(guid_to_feed.values())) < 2:
                continue
            clusters[root] = members[:CLUSTER_MAX_SIZE]
        return clusters

    return {root: members[:CLUSTER_MAX_SIZE] for root, members in groups.items() if len(members) >= 2}


def store_clusters_to_redis(
    clusters, ttl=CLUSTER_TTL_SECONDS, candidate_cluster_map=None, story_title_map=None
):
    """Write cluster memberships to Redis.

    When candidate_cluster_map is provided, detects when a newly computed cluster
    contains stories that already belong to an existing cluster. In that case,
    new stories are merged into the existing cluster (ZADD without DELETE) rather
    than creating a duplicate cluster.

    Merge validation: new members must share >= FUZZY_MIN_INTERSECTION significant
    title words with at least one existing cluster member. This prevents unrelated
    stories from accumulating in a cluster through transitive chains across runs.

    Keys:
        sCL:{story_hash} -> cluster_id (STRING with TTL)
        zCL:{cluster_id} -> sorted set of story_hashes scored by story_date
    """
    if not clusters:
        return

    r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
    pipe = r.pipeline()
    merged_count = 0
    new_count = 0
    skipped_validation = 0

    for cluster_id, members in clusters.items():
        # Check if any member already belongs to an existing cluster
        existing_cluster_id = None
        if candidate_cluster_map:
            for story_hash in members:
                if story_hash in candidate_cluster_map:
                    existing_cluster_id = candidate_cluster_map[story_hash]
                    break

        if existing_cluster_id:
            # Merge new stories into the existing cluster. Don't delete the
            # existing zCL: — just add new members and update sCL: pointers.
            target_cluster_id = existing_cluster_id

            # Enforce CLUSTER_MAX_SIZE: check how many members the existing
            # cluster already has before adding more.
            existing_members = r.zrange("zCL:%s" % target_cluster_id, 0, -1)
            existing_size = len(existing_members) if existing_members else 0

            # Build title-word sets for existing cluster members (for merge validation)
            existing_title_words = []
            if story_title_map and existing_members:
                for em in existing_members:
                    em_str = em.decode() if isinstance(em, bytes) else em
                    em_title = story_title_map.get(em_str, "")
                    if em_title:
                        existing_title_words.append(title_significant_words(em_title))

            added_count = 0
            merged_count += 1
            for story_hash in members:
                if story_hash not in candidate_cluster_map:
                    # Enforce max size — skip new additions but keep processing
                    # existing members below to refresh their TTLs.
                    if existing_size + added_count >= CLUSTER_MAX_SIZE:
                        continue

                    # Validate title-word overlap with existing cluster members.
                    # If title data is available, require >= FUZZY_MIN_INTERSECTION
                    # shared words with at least one existing member.
                    if story_title_map and existing_title_words:
                        new_title = story_title_map.get(story_hash, "")
                        if new_title:
                            new_words = title_significant_words(new_title)
                            has_overlap = any(
                                len(new_words & ew) >= FUZZY_MIN_INTERSECTION for ew in existing_title_words
                            )
                            if not has_overlap:
                                skipped_validation += 1
                                continue

                    # New story joining existing cluster
                    pipe.set("sCL:%s" % story_hash, target_cluster_id, ex=ttl)
                    pipe.zadd("zCL:%s" % target_cluster_id, {story_hash: 0})
                    added_count += 1
                else:
                    # Already in a cluster — refresh TTL on its sCL: key
                    pipe.expire("sCL:%s" % story_hash, ttl)
            pipe.expire("zCL:%s" % target_cluster_id, ttl)
        else:
            # Brand new cluster — replace any stale data
            new_count += 1
            for story_hash in members:
                pipe.set("sCL:%s" % story_hash, cluster_id, ex=ttl)
            pipe.delete("zCL:%s" % cluster_id)
            for story_hash in members:
                pipe.zadd("zCL:%s" % cluster_id, {story_hash: 0})
            pipe.expire("zCL:%s" % cluster_id, ttl)

    pipe.execute()

    if skipped_validation:
        logging.debug(
            " ---> ~FBClustering: skipped %s stories that failed merge title-word validation"
            % skipped_validation
        )

    total_stories = sum(len(m) for m in clusters.values())
    logging.debug(
        " ---> ~FBClustering: stored %s clusters (%s new, %s merged) with %s total stories"
        % (len(clusters), new_count, merged_count, total_stories)
    )

    # clustering/models.py: Record unique cluster IDs and story hashes for Grafana
    from apps.statistics.rclustering_usage import RClusteringUsage

    all_story_hashes = [h for members in clusters.values() for h in members]
    RClusteringUsage.record_cluster_ids(list(clusters.keys()), all_story_hashes)


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


def apply_clustering_to_stories(stories, user, classifiers_context=None, include_expanded_data=False):
    """Apply clustering to a list of story dicts from the river view.

    For each story on the current page that belongs to a cluster, fetches
    all cluster members (even those not on the current page) and attaches
    them as cluster_stories metadata. If multiple cluster members appear
    on the same page, the highest-scoring one is kept and others are removed.

    Args:
        stories: list of story dicts (already scored with 'score' key)
        user: User object
        classifiers_context: dict with classifier_feeds, classifier_authors,
            classifier_titles, classifier_tags, classifier_texts, classifier_urls,
            folder_feed_ids, user_is_pro, unread_feed_story_hashes, read_filter
        include_expanded_data: if True, include image_urls, story_content,
            secure_image_thumbnails for expanded cluster preview

    Returns:
        Modified stories list with cluster_stories attached to representatives.
    """
    if not stories:
        return stories

    # Get the user's subscribed feed IDs so we only show cluster members
    # from feeds the user actually subscribes to.
    from apps.reader.models import UserSubscription

    user_feed_ids = set(
        UserSubscription.objects.filter(user=user, active=True).values_list("feed_id", flat=True)
    )

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

    # For each cluster, fetch metadata for members NOT on this page from MongoDB.
    # Only include members from feeds the user is subscribed to.
    off_page_hashes = set()
    for cid, members in cluster_all_members.items():
        for h in members:
            if h not in page_hashes:
                # Extract feed_id from story_hash (format: feed_id:guid_hash)
                member_feed_id = int(h.split(":", 1)[0]) if ":" in h else None
                if member_feed_id and member_feed_id in user_feed_ids:
                    off_page_hashes.add(h)

    import zlib

    from apps.rss_feeds.models import Feed, MStory

    # Determine read status for off-page members via Redis.
    # Always check Redis directly because the unread_feed_story_hashes from
    # the view only covers feeds on the current page, not other feeds that
    # cluster members may belong to.
    off_page_read_hashes = set()
    if off_page_hashes:
        read_filter = classifiers_context.get("read_filter", "unread") if classifiers_context else "unread"
        if read_filter == "unread":
            off_page_read_hashes = set()
        else:
            read_pipe = r.pipeline()
            read_stories_key = "RS:%s" % user.pk
            for h in off_page_hashes:
                read_pipe.sismember(read_stories_key, h)
            read_results = read_pipe.execute()
            off_page_read_hashes = {h for h, is_read in zip(off_page_hashes, read_results) if is_read}

    off_page_metadata = {}
    if off_page_hashes:
        # Build the list of fields to fetch from MongoDB
        only_fields = [
            "story_hash",
            "story_feed_id",
            "story_title",
            "story_date",
            "story_author_name",
            "story_tags",
            "image_urls",
        ]
        if include_expanded_data:
            only_fields.append("story_content_z")

        off_page_list = list(off_page_hashes)
        for batch_start in range(0, len(off_page_list), 100):
            batch = off_page_list[batch_start : batch_start + 100]
            for story in MStory.objects(story_hash__in=batch).only(*only_fields).order_by():
                feed = Feed.get_by_id(story.story_feed_id)
                meta = {
                    "story_hash": story.story_hash,
                    "story_feed_id": story.story_feed_id,
                    "story_title": story.story_title or "",
                    "story_date": story.story_date.strftime("%Y-%m-%d %H:%M") if story.story_date else "",
                    "story_timestamp": str(int(story.story_date.timestamp())) if story.story_date else "",
                    "feed_title": feed.feed_title if feed else "",
                    "story_authors": story.story_author_name or "",
                }

                # Compute intelligence score if classifiers are available
                if classifiers_context:
                    from apps.analyzer.models import (
                        apply_classifier_authors,
                        apply_classifier_feeds,
                        apply_classifier_tags,
                        apply_classifier_titles,
                    )
                    from apps.reader.models import UserSubscription

                    cf = classifiers_context
                    story_dict = {
                        "story_feed_id": story.story_feed_id,
                        "story_author_name": story.story_author_name or "",
                        "story_tags": story.story_tags or [],
                        "story_title": story.story_title or "",
                    }
                    intelligence = {
                        "feed": apply_classifier_feeds(cf.get("classifier_feeds", []), story.story_feed_id),
                        "author": apply_classifier_authors(
                            cf.get("classifier_authors", []),
                            story_dict,
                            folder_feed_ids=cf.get("folder_feed_ids"),
                        ),
                        "tags": apply_classifier_tags(
                            cf.get("classifier_tags", []),
                            story_dict,
                            folder_feed_ids=cf.get("folder_feed_ids"),
                        ),
                        "title": apply_classifier_titles(
                            cf.get("classifier_titles", []),
                            story_dict,
                            folder_feed_ids=cf.get("folder_feed_ids"),
                        ),
                    }
                    meta["intelligence"] = intelligence
                    meta["score"] = UserSubscription.score_story(intelligence)
                    meta["read_status"] = 1 if story.story_hash in off_page_read_hashes else 0
                else:
                    meta["intelligence"] = {"feed": 0, "author": 0, "tags": 0, "title": 0}
                    meta["score"] = 0
                    meta["read_status"] = 0

                # Always include image URLs for cluster stories
                image_urls = story.image_urls or []
                meta["image_urls"] = image_urls
                meta["secure_image_thumbnails"] = (
                    Feed.secure_image_thumbnails(image_urls) if image_urls else {}
                )

                # Include content preview only for expanded mode
                if include_expanded_data:
                    content = ""
                    if hasattr(story, "story_content_z") and story.story_content_z:
                        try:
                            content = zlib.decompress(story.story_content_z).decode("utf-8", errors="replace")
                        except Exception:
                            content = ""
                    if len(content) > 500:
                        content = content[:500]
                    meta["story_content"] = content

                off_page_metadata[story.story_hash] = meta

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
        # Need 2+ GUID-unique members (clusters may include GUID duplicates)
        unique_guids = set(story_guid_hash(h) for h in all_members)
        if len(unique_guids) < 2:
            continue

        # The representative is the highest-scoring story on this page
        page_group.sort(key=lambda s: s.get("score", 0), reverse=True)
        representative = page_group[0]
        representative_hashes.add(representative["story_hash"])

        # Mark other on-page members as clustered (to remove from results)
        for s in page_group[1:]:
            clustered_hashes.add(s["story_hash"])

        # Build cluster_stories from ALL other members (on-page and off-page),
        # skipping only the representative itself.
        cluster_stories = []
        for member_hash in all_members:
            if member_hash == representative["story_hash"]:
                continue

            if member_hash in page_stories_by_hash:
                # On-page member — already has intelligence, score, read_status
                s = page_stories_by_hash[member_hash]
                feed = Feed.get_by_id(s["story_feed_id"])
                entry = {
                    "story_hash": s["story_hash"],
                    "story_feed_id": s["story_feed_id"],
                    "story_title": s.get("story_title", ""),
                    "story_date": s.get("story_date", ""),
                    "story_timestamp": s.get("story_timestamp", ""),
                    "feed_title": feed.feed_title if feed else "",
                    "story_authors": s.get("story_authors", ""),
                    "intelligence": s.get("intelligence", {"feed": 0, "author": 0, "tags": 0, "title": 0}),
                    "score": s.get("score", 0),
                    "read_status": s.get("read_status", 0),
                }
                entry["image_urls"] = s.get("image_urls", [])
                entry["secure_image_thumbnails"] = s.get("secure_image_thumbnails", {})
                if include_expanded_data:
                    content = s.get("story_content", "")
                    if content and len(content) > 500:
                        content = content[:500]
                    entry["story_content"] = content
                cluster_stories.append(entry)
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


def attach_cluster_data_to_stories(stories, user):
    """Attach cluster member data to stories without deduplication.

    Unlike apply_clustering_to_stories() which removes duplicate cluster
    members, this function only enriches each story with its cluster_stories
    metadata. Designed for the briefing view where the curated story list
    should not be modified.

    Args:
        stories: list of story dicts (must have 'story_hash' and 'story_feed_id')
        user: User object

    Returns:
        None (modifies stories in place by setting 'cluster_stories' key)
    """
    if not stories:
        return

    from apps.reader.models import UserSubscription

    user_feed_ids = set(
        UserSubscription.objects.filter(user=user, active=True).values_list("feed_id", flat=True)
    )

    r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)

    # Batch lookup cluster IDs for all stories
    story_hashes = [s["story_hash"] for s in stories]
    pipe = r.pipeline()
    for h in story_hashes:
        pipe.get("sCL:%s" % h)
    cluster_ids = pipe.execute()

    hash_to_cluster = {}
    unique_cluster_ids = set()
    for h, cid in zip(story_hashes, cluster_ids):
        if cid:
            cid_str = cid.decode() if isinstance(cid, bytes) else cid
            hash_to_cluster[h] = cid_str
            unique_cluster_ids.add(cid_str)

    if not hash_to_cluster:
        return

    # Fetch all members for each cluster
    cluster_all_members = {}
    pipe = r.pipeline()
    for cid in unique_cluster_ids:
        pipe.zrange("zCL:%s" % cid, 0, -1)
    member_results = pipe.execute()
    for cid, members in zip(unique_cluster_ids, member_results):
        cluster_all_members[cid] = [m.decode() if isinstance(m, bytes) else m for m in members]

    # Collect member hashes that are NOT in the input stories and belong
    # to feeds the user subscribes to
    input_hashes = set(story_hashes)
    external_hashes = set()
    for cid, members in cluster_all_members.items():
        for h in members:
            if h not in input_hashes:
                member_feed_id = int(h.split(":", 1)[0]) if ":" in h else None
                if member_feed_id and member_feed_id in user_feed_ids:
                    external_hashes.add(h)

    # Fetch metadata from MongoDB for external members
    from apps.rss_feeds.models import Feed, MStory

    external_metadata = {}
    if external_hashes:
        only_fields = [
            "story_hash",
            "story_feed_id",
            "story_title",
            "story_date",
            "story_author_name",
            "story_tags",
            "image_urls",
        ]
        ext_list = list(external_hashes)
        for batch_start in range(0, len(ext_list), 100):
            batch = ext_list[batch_start : batch_start + 100]
            for story in MStory.objects(story_hash__in=batch).only(*only_fields).order_by():
                feed = Feed.get_by_id(story.story_feed_id)
                image_urls = story.image_urls or []
                external_metadata[story.story_hash] = {
                    "story_hash": story.story_hash,
                    "story_feed_id": story.story_feed_id,
                    "story_title": story.story_title or "",
                    "story_date": (story.story_date.strftime("%Y-%m-%d %H:%M") if story.story_date else ""),
                    "story_timestamp": (str(int(story.story_date.timestamp())) if story.story_date else ""),
                    "feed_title": feed.feed_title if feed else "",
                    "story_authors": story.story_author_name or "",
                    "intelligence": {"feed": 0, "author": 0, "tags": 0, "title": 0},
                    "score": 0,
                    "read_status": 0,
                    "image_urls": image_urls,
                    "secure_image_thumbnails": (
                        Feed.secure_image_thumbnails(image_urls) if image_urls else {}
                    ),
                }

    # Attach cluster_stories to each input story that has a cluster
    for story in stories:
        cid = hash_to_cluster.get(story["story_hash"])
        if not cid:
            continue
        all_members = cluster_all_members.get(cid, [])
        # Need 2+ GUID-unique members for a valid cluster
        unique_guids = set(story_guid_hash(h) for h in all_members)
        if len(unique_guids) < 2:
            continue

        cluster_stories = []
        for member_hash in all_members:
            if member_hash == story["story_hash"]:
                continue
            if member_hash in input_hashes:
                # Skip other curated stories — they appear independently in the briefing
                continue
            if member_hash in external_metadata:
                cluster_stories.append(external_metadata[member_hash])

        if cluster_stories:
            story["cluster_stories"] = cluster_stories
