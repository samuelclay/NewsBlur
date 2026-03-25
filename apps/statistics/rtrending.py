import datetime

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
    - Running counters: "fRT:total:{date}", "sRTc:total:{date}", "fRTc:total:{date}"

    All data is stored in date-partitioned sorted sets for efficient aggregation.
    Reader counts (sRTc/fRTc) track unique read events to measure reach vs depth.
    All keys expire after 8 days for automatic cleanup.
    """

    MIN_READ_TIME_SECONDS = 3
    TTL_DAYS = 8

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
    def add_read_time(cls, story_hash, read_time_seconds):
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

        pipe.execute()

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
