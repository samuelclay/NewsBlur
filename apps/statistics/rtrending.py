import datetime
import logging
import math
import re
import zlib
from collections import Counter, defaultdict
from urllib.parse import urlparse

import redis
from django.conf import settings


class RTrendingStory:
    """
    Tracks accumulated read time for stories and feeds to identify trending content.

    Redis Key Structure:
    - Story read time sorted set by day: "sRTi:{date}" -> sorted set {story_hash: total_seconds}
    - Feed read time sorted set by day: "fRT:{date}" -> sorted set {feed_id: total_seconds}
    - Story reader count by day: "sRTc:{date}" -> sorted set {story_hash: reader_count}
    - Feed reader count by day: "fRTc:{date}" -> sorted set {feed_id: reader_count}
    - Exact per-user dwell shards: "sRTud:{date}:{shard}" -> {story_hash|user_id: seconds}
    - Quality-action shards: "sRTqa:{date}:{shard}" -> set {story_hash|user_id}
    - Running counters: "fRT:total:{date}", "sRTc:total:{date}", "fRTc:total:{date}"

    All data is stored in date-partitioned sorted sets for efficient aggregation.
    Reader counts (sRTc/fRTc) track unique read events to measure reach vs depth.
    All keys expire after 8 days for automatic cleanup.
    """

    MIN_READ_TIME_SECONDS = 3
    MEANINGFUL_READ_TIME_SECONDS = 10
    GOOD_READ_TIME_SECONDS = 30
    MAX_READ_TIME_SECONDS = 20 * 60
    TTL_DAYS = 8
    USER_EVENT_SHARDS = 16
    USER_DURATION_PREFIX = "sRTud"
    QUALITY_ACTION_PREFIX = "sRTqa"

    MIN_DISTINCT_READERS = 2
    MIN_LONG_READERS = 2
    MIN_LONG_WORDS = 600
    MIN_GOOD_READERS = 2
    MIN_GOOD_WORDS = 250
    GOOD_READ_FALLBACK_READERS = 4
    DIVERSITY_BLOCK_SIZE = 12
    MAX_TOPIC_PER_BLOCK = 3

    @classmethod
    def _get_top_merged(cls, r, prefix, days, limit):
        """Get top items by reading top-N from each daily key and merging in Python.

        No ZUNIONSTORE — just pipelined ZREVRANGE reads. O(days * fetch_limit).
        Overfetches from each day to minimize ranking errors from fragmentation.
        """
        today = datetime.date.today().strftime("%Y-%m-%d")

        if days == 1:
            return r.zrevrange(f"{prefix}:{today}", 0, limit - 1, withscores=True)

        fetch_limit = max(limit * 3, 100)
        pipe = r.pipeline()
        for i in range(days):
            day = (datetime.date.today() - datetime.timedelta(days=i)).strftime("%Y-%m-%d")
            pipe.zrevrange(f"{prefix}:{day}", 0, fetch_limit - 1, withscores=True)
        daily_results = pipe.execute()

        merged = {}
        for results in daily_results:
            for member, score in results:
                key = member.decode() if isinstance(member, bytes) else member
                merged[key] = merged.get(key, 0) + score

        sorted_results = sorted(merged.items(), key=lambda x: -x[1])
        return [(member, score) for member, score in sorted_results[:limit]]

    @classmethod
    def _get_scores_for_members(cls, r, prefix, days, members):
        """Get summed scores for specific members across daily sorted sets.

        Single pipelined call for all members across all days.
        """
        today = datetime.date.today().strftime("%Y-%m-%d")

        if days == 1:
            pipe = r.pipeline()
            for m in members:
                pipe.zscore(f"{prefix}:{today}", m)
            values = pipe.execute()
            return {m: int(v) if v else 0 for m, v in zip(members, values)}

        pipe = r.pipeline()
        for i in range(days):
            day = (datetime.date.today() - datetime.timedelta(days=i)).strftime("%Y-%m-%d")
            for m in members:
                pipe.zscore(f"{prefix}:{day}", m)
        all_values = pipe.execute()

        scores = {m: 0 for m in members}
        idx = 0
        for i in range(days):
            for m in members:
                val = all_values[idx]
                if val:
                    scores[m] += int(val)
                idx += 1
        return scores

    @classmethod
    def add_read_time(cls, story_hash, read_time_seconds, user_id=None):
        """
        Add read time for a story. Filters out reads < 3 seconds.
        Updates story-level, feed-level, and story index aggregates.
        """
        if read_time_seconds < cls.MIN_READ_TIME_SECONDS:
            return

        try:
            feed_id = story_hash.split(":")[0]
            feed_id = int(feed_id)
        except (ValueError, IndexError, AttributeError):
            return

        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        today = datetime.date.today().strftime("%Y-%m-%d")
        ttl_seconds = cls.TTL_DAYS * 24 * 60 * 60

        pipe = r.pipeline()

        # Daily sorted sets
        pipe.zincrby(f"fRT:{today}", int(read_time_seconds), str(feed_id))
        pipe.expire(f"fRT:{today}", ttl_seconds)
        pipe.zincrby(f"sRTi:{today}", int(read_time_seconds), story_hash)
        pipe.expire(f"sRTi:{today}", ttl_seconds)
        pipe.zincrby(f"sRTc:{today}", 1, story_hash)
        pipe.expire(f"sRTc:{today}", ttl_seconds)
        pipe.zincrby(f"fRTc:{today}", 1, str(feed_id))
        pipe.expire(f"fRTc:{today}", ttl_seconds)

        # Running counters for aggregate totals
        pipe.incrby(f"fRT:total:{today}", int(read_time_seconds))
        pipe.expire(f"fRT:total:{today}", ttl_seconds)
        pipe.incr(f"sRTc:total:{today}")
        pipe.expire(f"sRTc:total:{today}", ttl_seconds)
        pipe.incr(f"fRTc:total:{today}")
        pipe.expire(f"fRTc:total:{today}", ttl_seconds)

        if user_id:
            duration = min(int(read_time_seconds), cls.MAX_READ_TIME_SECONDS)
            shard = cls._story_shard(story_hash)
            member = cls._story_user_member(story_hash, user_id)
            duration_key = f"{cls.USER_DURATION_PREFIX}:{today}:{shard}"
            pipe.zadd(duration_key, {member: duration}, gt=True)
            pipe.expire(duration_key, ttl_seconds)

        pipe.execute()

    @classmethod
    def _story_shard(cls, story_hash):
        return zlib.crc32(story_hash.encode("utf-8")) % cls.USER_EVENT_SHARDS

    @staticmethod
    def _story_user_member(story_hash, user_id):
        return f"{story_hash}|{user_id}"

    @staticmethod
    def _split_story_user_member(member):
        if isinstance(member, bytes):
            member = member.decode()
        if "|" not in member:
            return None, None
        return member.rsplit("|", 1)

    @classmethod
    def record_quality_action(cls, story_hash, user_id):
        """Record one unique commitment action per user/story/day.

        Saves, shares, and positive story training intentionally share one
        dedupe set so repeated actions from the same account cannot amplify a
        story's Good Reads score.
        """
        if not story_hash or not user_id or ":" not in story_hash:
            return

        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        today = datetime.date.today().strftime("%Y-%m-%d")
        ttl_seconds = cls.TTL_DAYS * 24 * 60 * 60
        shard = cls._story_shard(story_hash)
        key = f"{cls.QUALITY_ACTION_PREFIX}:{today}:{shard}"
        pipe = r.pipeline()
        pipe.sadd(key, cls._story_user_member(story_hash, user_id))
        pipe.expire(key, ttl_seconds)
        pipe.execute()

    @classmethod
    def get_distinct_user_durations(cls, days=7, min_seconds=None):
        """Return maximum observed dwell for each distinct user/story pair."""
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        min_seconds = min_seconds if min_seconds is not None else cls.MIN_READ_TIME_SECONDS

        pipe = r.pipeline()
        for i in range(days):
            day = (datetime.date.today() - datetime.timedelta(days=i)).strftime("%Y-%m-%d")
            for shard in range(cls.USER_EVENT_SHARDS):
                pipe.zrangebyscore(
                    f"{cls.USER_DURATION_PREFIX}:{day}:{shard}",
                    min_seconds,
                    "+inf",
                    withscores=True,
                )

        durations = defaultdict(dict)
        for entries in pipe.execute():
            for member, seconds in entries:
                story_hash, user_id = cls._split_story_user_member(member)
                if not story_hash or not user_id:
                    continue
                seconds = int(seconds)
                durations[story_hash][user_id] = max(
                    durations[story_hash].get(user_id, 0),
                    seconds,
                )
        return dict(durations)

    @classmethod
    def get_quality_action_users(cls, days=7):
        """Return distinct users who saved, shared, or positively trained each story."""
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        pipe = r.pipeline()
        for i in range(days):
            day = (datetime.date.today() - datetime.timedelta(days=i)).strftime("%Y-%m-%d")
            for shard in range(cls.USER_EVENT_SHARDS):
                pipe.smembers(f"{cls.QUALITY_ACTION_PREFIX}:{day}:{shard}")

        actions = defaultdict(set)
        for entries in pipe.execute():
            for member in entries:
                story_hash, user_id = cls._split_story_user_member(member)
                if story_hash and user_id:
                    actions[story_hash].add(user_id)
        return dict(actions)

    @staticmethod
    def required_long_read_seconds(word_count):
        """Require 25% of estimated reading time, bounded to 45s-3m."""
        estimated_seconds = max(60, (word_count / 240.0) * 60)
        return int(min(180, max(45, estimated_seconds * 0.25)))

    @classmethod
    def good_read_qualifies(cls, deep_reader_count, action_count):
        return deep_reader_count >= cls.MIN_GOOD_READERS and (
            action_count >= 1 or deep_reader_count >= cls.GOOD_READ_FALLBACK_READERS
        )

    @classmethod
    def diversify_candidates(cls, candidates, block_size=None, small_feed_slots=0):
        """Preserve score order while enforcing source and topic diversity blocks."""
        block_size = block_size or cls.DIVERSITY_BLOCK_SIZE
        remaining = list(candidates)
        diversified = []
        seen_clusters = set()
        seen_titles = set()

        while remaining:
            block = []
            deferred = []
            feed_ids = set()
            domains = set()
            publishers = set()
            topic_counts = defaultdict(int)

            prioritized = []
            if small_feed_slots:
                prioritized = [
                    candidate for candidate in remaining if 0 < candidate.get("active_subscribers", 0) <= 50
                ][:small_feed_slots]
            prioritized_hashes = {candidate["story_hash"] for candidate in prioritized}
            ordered_remaining = prioritized + [
                candidate for candidate in remaining if candidate["story_hash"] not in prioritized_hashes
            ]

            for candidate in ordered_remaining:
                cluster_id = candidate.get("cluster_id")
                title_key = candidate.get("title_key")
                if cluster_id and cluster_id in seen_clusters:
                    continue
                if title_key and title_key in seen_titles:
                    continue
                if len(block) >= block_size:
                    deferred.append(candidate)
                    continue

                feed_id = candidate.get("feed_id")
                domain = candidate.get("domain")
                publisher = candidate.get("publisher")
                topic = candidate.get("topic")
                capped_topic = topic and topic != "other"
                if (
                    feed_id in feed_ids
                    or (domain and domain in domains)
                    or (publisher and publisher in publishers)
                    or (capped_topic and topic_counts[topic] >= cls.MAX_TOPIC_PER_BLOCK)
                ):
                    deferred.append(candidate)
                    continue

                block.append(candidate)
                feed_ids.add(feed_id)
                if domain:
                    domains.add(domain)
                if publisher:
                    publishers.add(publisher)
                if capped_topic:
                    topic_counts[topic] += 1
                if cluster_id:
                    seen_clusters.add(cluster_id)
                if title_key:
                    seen_titles.add(title_key)

            if not block:
                break
            diversified.extend(block)
            remaining = deferred

        return cls.cap_source_share(diversified)

    @staticmethod
    def cap_source_share(candidates, max_share=0.10):
        """Remove lowest-ranked repeats until no source exceeds the requested share."""
        capped = list(candidates)
        while len(capped) >= 10:
            source_limit = max(1, math.floor(len(capped) * max_share))
            source_counts = {
                field: Counter(candidate.get(field) for candidate in capped if candidate.get(field))
                for field in ("feed_id", "domain", "publisher")
            }
            if all(count <= source_limit for counts in source_counts.values() for count in counts.values()):
                break

            kept_counts = {field: Counter() for field in source_counts}
            filtered = []
            for candidate in capped:
                if any(
                    candidate.get(field) and kept_counts[field][candidate[field]] >= source_limit
                    for field in kept_counts
                ):
                    continue
                filtered.append(candidate)
                for field in kept_counts:
                    if candidate.get(field):
                        kept_counts[field][candidate[field]] += 1

            if len(filtered) == len(capped):
                break
            capped = filtered

        return capped

    @classmethod
    def get_story_read_time(cls, story_hash, days=7):
        """Get total read time for a story over the past N days."""
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)

        pipe = r.pipeline()
        for i in range(days):
            day = (datetime.date.today() - datetime.timedelta(days=i)).strftime("%Y-%m-%d")
            pipe.zscore(f"sRTi:{day}", story_hash)

        total = 0
        for val in pipe.execute():
            if val:
                try:
                    total += int(val)
                except (ValueError, TypeError):
                    pass
        return total

    @classmethod
    def get_trending_feeds(cls, days=7, limit=50):
        """Get top trending feeds based on accumulated read time over past N days."""
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        result = cls._get_top_merged(r, "fRT", days, limit)
        return [(int(feed_id), int(score)) for feed_id, score in result]

    @classmethod
    def get_feed_read_time(cls, feed_id, days=7):
        """Get total read time for a specific feed over the past N days."""
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)

        pipe = r.pipeline()
        for i in range(days):
            day = (datetime.date.today() - datetime.timedelta(days=i)).strftime("%Y-%m-%d")
            pipe.zscore(f"fRT:{day}", str(feed_id))

        total = 0
        for val in pipe.execute():
            if val:
                try:
                    total += int(val)
                except (ValueError, TypeError):
                    pass
        return total

    @classmethod
    def get_trending_stories(cls, days=7, limit=50):
        """Get top trending stories based on accumulated read time over past N days."""
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        result = cls._get_top_merged(r, "sRTi", days, limit)
        return [
            (story_hash.decode() if isinstance(story_hash, bytes) else story_hash, int(score))
            for story_hash, score in result
        ]

    @classmethod
    def get_stories_for_feed(cls, feed_id, days=7, limit=20):
        """Get top stories for a specific feed based on read time."""
        all_stories = cls.get_trending_stories(days=days, limit=500)
        feed_prefix = f"{feed_id}:"
        feed_stories = [(h, s) for h, s in all_stories if h.startswith(feed_prefix)]
        return feed_stories[:limit]

    @classmethod
    def get_story_reader_count(cls, story_hash, days=7):
        """Get total reader count for a story over the past N days."""
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)

        pipe = r.pipeline()
        for i in range(days):
            day = (datetime.date.today() - datetime.timedelta(days=i)).strftime("%Y-%m-%d")
            pipe.zscore(f"sRTc:{day}", story_hash)

        total = 0
        for val in pipe.execute():
            if val:
                try:
                    total += int(val)
                except (ValueError, TypeError):
                    pass
        return total

    @classmethod
    def get_trending_stories_detailed(cls, days=7, limit=50):
        """Get trending stories with full metrics: total seconds, reader count, and avg per reader."""
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)

        # Get top stories by read time (merged across days)
        time_results = cls._get_top_merged(r, "sRTi", days, limit)

        if not time_results:
            return []

        story_hashes = [(sh.decode() if isinstance(sh, bytes) else sh) for sh, _ in time_results]
        time_map = {(sh.decode() if isinstance(sh, bytes) else sh): int(score) for sh, score in time_results}

        # Get reader counts for those stories (pipelined across days)
        count_map = cls._get_scores_for_members(r, "sRTc", days, story_hashes)

        results = []
        for story_hash in story_hashes:
            total_seconds = time_map.get(story_hash, 0)
            reader_count = count_map.get(story_hash, 0)

            try:
                feed_id = int(story_hash.split(":")[0])
            except (ValueError, IndexError):
                feed_id = 0

            results.append(
                {
                    "story_hash": story_hash,
                    "feed_id": feed_id,
                    "total_seconds": total_seconds,
                    "reader_count": reader_count,
                    "avg_seconds_per_reader": total_seconds / reader_count if reader_count > 0 else 0,
                }
            )

        return results

    @classmethod
    def get_trending_feeds_detailed(cls, days=7, limit=50):
        """Get trending feeds with full metrics: total seconds, reader count, and avg per reader."""
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)

        # Get top feeds by read time (merged across days)
        time_results = cls._get_top_merged(r, "fRT", days, limit)

        if not time_results:
            return []

        feed_ids = [(fid.decode() if isinstance(fid, bytes) else fid) for fid, _ in time_results]
        time_map = {
            (fid.decode() if isinstance(fid, bytes) else fid): int(score) for fid, score in time_results
        }

        # Get reader counts for those feeds (pipelined across days)
        count_map = cls._get_scores_for_members(r, "fRTc", days, feed_ids)

        results = []
        for feed_id_str in feed_ids:
            try:
                feed_id = int(feed_id_str)
            except ValueError:
                continue

            total_seconds = time_map.get(feed_id_str, 0)
            reader_count = count_map.get(feed_id_str, 0)

            results.append(
                {
                    "feed_id": feed_id,
                    "total_seconds": total_seconds,
                    "reader_count": reader_count,
                    "avg_seconds_per_reader": total_seconds / reader_count if reader_count > 0 else 0,
                }
            )

        return results

    @classmethod
    def get_trending_feeds_normalized(cls, days=7, limit=50, min_subscribers=1, max_subscribers=None):
        """Get trending feeds normalized by subscriber count to surface hidden gems."""
        from apps.rss_feeds.models import Feed

        trending = cls.get_trending_feeds(days=days, limit=500)
        if not trending:
            return []

        feed_ids = [feed_id for feed_id, _ in trending]
        feeds = Feed.objects.filter(pk__in=feed_ids).values("pk", "num_subscribers")
        subscriber_map = {f["pk"]: max(f["num_subscribers"], 1) for f in feeds}

        results = []
        for feed_id, total_seconds in trending:
            subs = subscriber_map.get(feed_id, 1)
            if subs < min_subscribers:
                continue
            if max_subscribers and subs > max_subscribers:
                continue

            results.append(
                {
                    "feed_id": feed_id,
                    "total_seconds": total_seconds,
                    "num_subscribers": subs,
                    "seconds_per_subscriber": total_seconds / subs,
                }
            )

        results.sort(key=lambda x: x["seconds_per_subscriber"], reverse=True)
        return results[:limit]

    @classmethod
    def get_long_reads(cls, days=7, limit=50, min_readers=3):
        """Get stories sorted by average read time, filtered by minimum reader count."""
        all_stories = cls.get_trending_stories_detailed(days=days, limit=limit * 5)
        filtered = [s for s in all_stories if s["reader_count"] >= min_readers]
        filtered.sort(key=lambda x: x["avg_seconds_per_reader"], reverse=True)
        return filtered[:limit]

    # --- Permanent trending lists ---
    # Base sorted sets preserve the existing transition history. Hourly refreshes
    # add only stories qualified by exact user telemetry, then materialize a
    # deterministic diverse order into Redis lists for serving.

    WELL_READ_KEY = "trending:well_read"
    LONG_READS_KEY = "trending:long_reads"
    GOOD_READS_KEY = "trending:good_reads"
    WELL_READ_DIVERSE_KEY = "trending:well_read:diverse"
    LONG_READS_DIVERSE_KEY = "trending:long_reads:diverse"
    GOOD_READS_DIVERSE_KEY = "trending:good_reads:diverse"
    DIVERSITY_METRICS_KEY = "trending:diversity_metrics"
    REFRESH_TIMESTAMP_KEY = "trending:refresh_timestamp"
    MAX_LIST_SIZE = 10000

    TOPIC_KEYWORDS = {
        "technology": r"\b(ai|android|code|developer|hack|security|software|technology|windows)\b",
        "science": r"\b(astronomy|biology|climate|earth|medicine|physics|science|space|weather)\b",
        "sports & games": r"\b(football|game|gaming|soccer|sport|world cup|xbox)\b",
        "business & work": r"\b(business|economy|finance|job|labor|money|tax|trade|work)\b",
        "politics & law": r"\b(court|democracy|election|government|law|politics|senate|trump)\b",
        "culture & history": r"\b(art|book|culture|film|history|music|reading)\b",
    }

    @classmethod
    def refresh_trending_lists(cls, days=7):
        """Add exact-reader candidates and rebuild diverse serving orders."""
        from apps.briefing.scoring import _estimate_word_count
        from apps.rss_feeds.models import Feed, MStory

        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        durations = cls.get_distinct_user_durations(days=days, min_seconds=cls.MEANINGFUL_READ_TIME_SECONDS)
        actions = cls.get_quality_action_users(days=days)

        if not durations:
            cls.materialize_diverse_lists()
            return {"well_read": 0, "long_reads": 0, "good_reads": 0}

        well_read_ranked = []
        long_prefilter = []
        good_prefilter = []
        for story_hash, user_durations in durations.items():
            meaningful = [
                seconds for seconds in user_durations.values() if seconds >= cls.MEANINGFUL_READ_TIME_SECONDS
            ]
            if len(meaningful) >= cls.MIN_DISTINCT_READERS:
                well_read_ranked.append((story_hash, len(meaningful), sum(meaningful)))

            good_deep = [
                seconds for seconds in user_durations.values() if seconds >= cls.GOOD_READ_TIME_SECONDS
            ]
            if len(good_deep) >= cls.MIN_LONG_READERS:
                sorted_deep = sorted(good_deep, reverse=True)
                long_prefilter.append((story_hash, sorted_deep[1], len(sorted_deep)))
                if cls.good_read_qualifies(len(sorted_deep), len(actions.get(story_hash, set()))):
                    good_prefilter.append(
                        (story_hash, bool(actions.get(story_hash)), sorted_deep[1], len(sorted_deep))
                    )

        well_read_ranked.sort(key=lambda item: (item[1], item[2], item[0]), reverse=True)
        well_read_hashes = [item[0] for item in well_read_ranked[:200]]
        long_prefilter.sort(key=lambda item: (item[1], item[2], item[0]), reverse=True)
        good_prefilter.sort(key=lambda item: (item[1], item[2], item[3], item[0]), reverse=True)

        content_hashes = {item[0] for item in long_prefilter[:2000]}
        content_hashes.update(item[0] for item in good_prefilter[:2000])
        content_hashes.update(well_read_hashes)
        stories = {
            story.story_hash: story
            # rtrending.py: Clear MStory's default -story_date ordering. This lookup is keyed
            # into a dict by story_hash, so the sort is pure waste, and with no index backing
            # story_hash__in sorted by story_date, Mongo does a blocking in-memory sort that
            # blew past its 32MB limit once these lists grew large enough.
            for story in MStory.objects(story_hash__in=list(content_hashes))
            .order_by()
            .only(
                "story_hash",
                "story_date",
                "story_title",
                "story_feed_id",
                "story_tags",
                "story_content",
                "story_content_z",
            )
        }

        long_ranked = []
        for story_hash, _, _ in long_prefilter[:2000]:
            story = stories.get(story_hash)
            if not story:
                continue
            word_count = _estimate_word_count(story)
            if word_count < cls.MIN_LONG_WORDS:
                continue
            required_seconds = cls.required_long_read_seconds(word_count)
            deep_durations = [
                seconds for seconds in durations[story_hash].values() if seconds >= required_seconds
            ]
            if len(deep_durations) < cls.MIN_LONG_READERS:
                continue
            estimated_seconds = max(60, (word_count / 240.0) * 60)
            completion = sum(min(seconds / estimated_seconds, 1.25) for seconds in deep_durations) / len(
                deep_durations
            )
            confidence = 1 - math.exp(-len(deep_durations) / 5.0)
            score = completion * math.log1p(word_count) * confidence
            long_ranked.append((story_hash, score))
        long_ranked.sort(key=lambda item: (item[1], item[0]), reverse=True)
        long_read_hashes = [item[0] for item in long_ranked[:50]]

        # Good Reads has a distinct quality and novelty score, but may overlap the
        # other feeds. Excluding Widely Read would remove every two-reader Good Read.
        good_story_hashes = [item[0] for item in good_prefilter[:2000]]
        good_feed_ids = {stories[h].story_feed_id for h in good_story_hashes if h in stories}
        feeds = {
            feed.pk: feed
            for feed in Feed.objects.filter(pk__in=good_feed_ids).only(
                "pk", "active_subscribers", "num_subscribers"
            )
        }
        max_active = max([feed.active_subscribers or 0 for feed in feeds.values()] + [1])
        good_ranked = []
        for story_hash in good_story_hashes:
            story = stories.get(story_hash)
            if not story:
                continue
            word_count = _estimate_word_count(story)
            if word_count < cls.MIN_GOOD_WORDS:
                continue
            deep_durations = [
                seconds for seconds in durations[story_hash].values() if seconds >= cls.GOOD_READ_TIME_SECONDS
            ]
            action_count = len(actions.get(story_hash, set()))
            if not cls.good_read_qualifies(len(deep_durations), action_count):
                continue

            estimated_seconds = max(60, (word_count / 240.0) * 60)
            completion = sum(
                min(seconds / estimated_seconds, 1.25) / 1.25 for seconds in deep_durations
            ) / len(deep_durations)
            confidence = 1 - math.exp(-max(0, len(deep_durations) - 1) / 8.0)
            action_score = min(math.log1p(action_count) / math.log(4), 1) if action_count else 0
            substance = min(math.log1p(word_count) / math.log(2001), 1)
            quality = (0.45 * completion) + (0.25 * confidence) + (0.20 * action_score) + (0.10 * substance)
            feed = feeds.get(story.story_feed_id)
            active_subscribers = feed.active_subscribers if feed and feed.active_subscribers else 0
            novelty = 1 - min(math.log1p(active_subscribers) / math.log1p(max_active), 1)
            score = quality * (0.65 + (0.35 * novelty))
            good_ranked.append((story_hash, score))
        good_ranked.sort(key=lambda item: (item[1], item[0]), reverse=True)
        selected_good_hashes = [item[0] for item in good_ranked[:100]]

        selected = {
            cls.WELL_READ_KEY: well_read_hashes,
            cls.LONG_READS_KEY: long_read_hashes,
            cls.GOOD_READS_KEY: selected_good_hashes,
        }
        all_selected_hashes = set().union(*selected.values())
        story_dates = {
            story_hash: stories[story_hash].story_date.timestamp()
            for story_hash in all_selected_hashes
            if story_hash in stories and stories[story_hash].story_date
        }

        existing_by_key = {key: set(cls._decode_members(r.zrange(key, 0, -1))) for key in selected}
        added = {}
        pipe = r.pipeline()
        for key, story_hashes in selected.items():
            added[key] = 0
            for story_hash in story_hashes:
                if story_hash not in story_dates or story_hash in existing_by_key[key]:
                    continue
                pipe.zadd(key, {story_hash: story_dates[story_hash]}, nx=True)
                added[key] += 1
            pipe.zremrangebyrank(key, 0, -(cls.MAX_LIST_SIZE + 1))
        pipe.execute()

        cls.materialize_diverse_lists()
        logging.debug(
            "Trending lists refreshed from distinct readers: +%s well-read, +%s long-reads, +%s good-reads"
            % (
                added[cls.WELL_READ_KEY],
                added[cls.LONG_READS_KEY],
                added[cls.GOOD_READS_KEY],
            )
        )
        return {
            "well_read": added[cls.WELL_READ_KEY],
            "long_reads": added[cls.LONG_READS_KEY],
            "good_reads": added[cls.GOOD_READS_KEY],
        }

    @classmethod
    def materialize_diverse_lists(cls):
        for base_key, diverse_key in [
            (cls.WELL_READ_KEY, cls.WELL_READ_DIVERSE_KEY),
            (cls.LONG_READS_KEY, cls.LONG_READS_DIVERSE_KEY),
            (cls.GOOD_READS_KEY, cls.GOOD_READS_DIVERSE_KEY),
        ]:
            cls._materialize_diverse_list(base_key, diverse_key)
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        r.set(cls.REFRESH_TIMESTAMP_KEY, int(datetime.datetime.now().timestamp()))

    @classmethod
    def _materialize_diverse_list(cls, base_key, diverse_key):
        from apps.clustering.models import normalize_title
        from apps.discover.models import PopularFeed
        from apps.rss_feeds.models import Feed, MStory

        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        story_hashes = cls._decode_members(r.zrevrange(base_key, 0, cls.MAX_LIST_SIZE - 1))
        if not story_hashes:
            r.delete(diverse_key)
            cls._store_diversity_metrics(base_key, [])
            return []

        stories = {
            story.story_hash: story
            for story in MStory.objects(story_hash__in=story_hashes)
            .order_by()
            .only("story_hash", "story_feed_id", "story_title", "story_tags")
        }
        feed_ids = {story.story_feed_id for story in stories.values()}
        feeds = {
            feed.pk: feed
            for feed in Feed.objects.filter(pk__in=feed_ids).only(
                "pk",
                "feed_title",
                "feed_link",
                "feed_address",
                "branch_from_feed",
                "active_subscribers",
            )
        }
        categories = dict(
            PopularFeed.objects.filter(feed_id__in=feed_ids, is_active=True)
            .order_by("feed_id", "sort_order")
            .values_list("feed_id", "category")
        )

        cluster_redis = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
        pipe = cluster_redis.pipeline()
        for story_hash in story_hashes:
            pipe.get(f"sCL:{story_hash}")
        cluster_values = pipe.execute()
        clusters = {
            story_hash: value.decode() if isinstance(value, bytes) else value
            for story_hash, value in zip(story_hashes, cluster_values)
            if value
        }

        candidates = []
        for story_hash in story_hashes:
            story = stories.get(story_hash)
            if not story:
                continue
            feed = feeds.get(story.story_feed_id)
            if not feed:
                continue
            domain = cls._feed_domain(feed.feed_link or feed.feed_address)
            publisher = normalize_title(feed.feed_title or "")
            candidates.append(
                {
                    "story_hash": story_hash,
                    "feed_id": feed.branch_from_feed_id or feed.pk,
                    "domain": domain,
                    "publisher": publisher,
                    "topic": cls._story_topic(story, categories.get(feed.pk)),
                    "cluster_id": clusters.get(story_hash),
                    "title_key": normalize_title(story.story_title or ""),
                    "active_subscribers": feed.active_subscribers or 0,
                }
            )

        small_feed_slots = 4 if base_key == cls.GOOD_READS_KEY else 0
        diversified = cls.diversify_candidates(candidates, small_feed_slots=small_feed_slots)
        ordered_hashes = [candidate["story_hash"] for candidate in diversified]
        temp_key = f"{diverse_key}:building"
        pipe = r.pipeline()
        pipe.delete(temp_key)
        if ordered_hashes:
            pipe.rpush(temp_key, *ordered_hashes)
            pipe.rename(temp_key, diverse_key)
        else:
            pipe.delete(diverse_key)
        pipe.execute()
        cls._store_diversity_metrics(base_key, diversified)
        return ordered_hashes

    @classmethod
    def _store_diversity_metrics(cls, base_key, candidates):
        list_name = base_key.rsplit(":", 1)[-1]
        sample = candidates[:50]
        publisher_counts = Counter(
            candidate.get("publisher") or candidate.get("domain") or str(candidate.get("feed_id"))
            for candidate in sample
        )
        sample_size = len(sample)
        top_share = max(publisher_counts.values(), default=0) / sample_size if sample_size else 0
        hhi = sum((count / sample_size) ** 2 for count in publisher_counts.values()) if sample_size else 0
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        r.hset(
            cls.DIVERSITY_METRICS_KEY,
            mapping={
                f"{list_name}:size": len(candidates),
                f"{list_name}:unique_publishers_50": len(publisher_counts),
                f"{list_name}:top_publisher_share_50": f"{top_share:.4f}",
                f"{list_name}:publisher_hhi_50": f"{hhi:.4f}",
            },
        )

    @staticmethod
    def _feed_domain(url):
        if not url:
            return ""
        parsed = urlparse(url if "://" in url else f"https://{url}")
        return (parsed.hostname or "").lower().removeprefix("www.")

    @classmethod
    def _story_topic(cls, story, popular_category=None):
        if popular_category:
            return popular_category.lower()
        text = " ".join([story.story_title or ""] + list(story.story_tags or [])).lower()
        for topic, pattern in cls.TOPIC_KEYWORDS.items():
            if re.search(pattern, text):
                return topic
        return "other"

    @staticmethod
    def _decode_members(members):
        return [member.decode() if isinstance(member, bytes) else member for member in members]

    @classmethod
    def get_well_read_story_hashes(cls, offset=0, limit=12, order="newest", read_filter="all", user_id=None):
        return cls._get_permanent_list_hashes(
            cls.WELL_READ_KEY,
            cls.WELL_READ_DIVERSE_KEY,
            offset,
            limit,
            order,
            read_filter,
            user_id,
        )

    @classmethod
    def get_long_read_story_hashes(cls, offset=0, limit=12, order="newest", read_filter="all", user_id=None):
        return cls._get_permanent_list_hashes(
            cls.LONG_READS_KEY,
            cls.LONG_READS_DIVERSE_KEY,
            offset,
            limit,
            order,
            read_filter,
            user_id,
        )

    @classmethod
    def get_good_read_story_hashes(cls, offset=0, limit=12, order="newest", read_filter="all", user_id=None):
        return cls._get_permanent_list_hashes(
            cls.GOOD_READS_KEY,
            cls.GOOD_READS_DIVERSE_KEY,
            offset,
            limit,
            order,
            read_filter,
            user_id,
        )

    @classmethod
    def _get_permanent_list_hashes(cls, key, diverse_key, offset, limit, order, read_filter, user_id):
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        has_diverse_list = bool(r.exists(diverse_key))

        if read_filter == "all" or not user_id:
            if has_diverse_list:
                if order == "oldest":
                    total = r.llen(diverse_key)
                    start = max(total - offset - limit, 0)
                    stop = max(total - offset - 1, -1)
                    results = list(reversed(r.lrange(diverse_key, start, stop))) if stop >= 0 else []
                else:
                    results = r.lrange(diverse_key, offset, offset + limit - 1)
            elif order == "oldest":
                results = r.zrange(key, offset, offset + limit - 1)
            else:
                results = r.zrevrange(key, offset, offset + limit - 1)
            return cls._decode_members(results)

        if has_diverse_list:
            candidates = cls._decode_members(r.lrange(diverse_key, 0, -1))
            if order == "oldest":
                candidates.reverse()
        elif order == "oldest":
            candidates = cls._decode_members(r.zrange(key, 0, -1))
        else:
            candidates = cls._decode_members(r.zrevrange(key, 0, -1))

        r2 = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
        pipe = r2.pipeline()
        for story_hash in candidates:
            pipe.sismember(f"RS:{user_id}", story_hash)
        read_states = pipe.execute()
        unread = [story_hash for story_hash, is_read in zip(candidates, read_states) if not is_read]
        return unread[offset : offset + limit]
