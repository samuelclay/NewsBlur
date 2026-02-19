"""
Redis-based story clustering usage tracking.

Provides fast aggregation for Prometheus metrics by maintaining
SETs and counters in Redis that are updated in real-time when
clustering operations occur.

Key structure (unique tracking via SETs):
- clustering:cids:{date} - SET of unique cluster IDs seen that day
- clustering:sids:{date} - SET of unique story hashes clustered that day
  Both have 35-day TTL. For multi-day ranges, SUNIONSTORE + SCARD gives
  deduplicated counts across days.

Key structure (operation counters):
- clustering:{date}:mark_read_expanded - daily extra stories marked read via clusters
- clustering:alltime:mark_read_expanded - cumulative mark-read expanded count (no expiry)
- clustering:{date}:cluster_time_total_ms - daily sum of clustering durations in ms
- clustering:{date}:cluster_time_count - daily number of clustering runs
- clustering:alltime:cluster_time_total_ms - cumulative sum of clustering durations
- clustering:alltime:cluster_time_count - cumulative number of clustering runs
"""

import datetime
import uuid

import redis
from django.conf import settings

# rclustering_usage.py: 14-day cluster TTL means "alltime" = last 14 days
CLUSTER_TTL_DAYS = 14
SET_TTL_SECONDS = 35 * 24 * 60 * 60


class RClusteringUsage:
    KEY_PREFIX = "clustering"
    METRICS = ["unique_clusters", "unique_stories", "mark_read_expanded"]
    TIMING_KEYS = ["cluster_time_total_ms", "cluster_time_count"]

    @classmethod
    def _get_redis(cls):
        return redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)

    @classmethod
    def _date_key(cls, date=None):
        if date is None:
            date = datetime.date.today()
        return date.strftime("%Y-%m-%d")

    @classmethod
    def record_cluster_ids(cls, cluster_ids, story_hashes):
        """Record unique cluster IDs and story hashes into daily SETs.

        SADD naturally deduplicates, so re-discovering the same cluster
        across multiple feed updates only counts it once per day.
        """
        if not cluster_ids:
            return
        r = cls._get_redis()
        date_key = cls._date_key()
        cid_key = f"{cls.KEY_PREFIX}:cids:{date_key}"
        sid_key = f"{cls.KEY_PREFIX}:sids:{date_key}"
        pipe = r.pipeline()

        for cid in cluster_ids:
            pipe.sadd(cid_key, cid)
        for sh in story_hashes:
            pipe.sadd(sid_key, sh)

        pipe.expire(cid_key, SET_TTL_SECONDS)
        pipe.expire(sid_key, SET_TTL_SECONDS)
        pipe.execute()

    @classmethod
    def record_mark_read(cls, count):
        """Record extra stories marked read via cluster expansion."""
        if count <= 0:
            return
        r = cls._get_redis()
        date_key = cls._date_key()
        pipe = r.pipeline()

        pipe.incrby(f"{cls.KEY_PREFIX}:{date_key}:mark_read_expanded", count)
        pipe.incrby(f"{cls.KEY_PREFIX}:alltime:mark_read_expanded", count)

        pipe.execute()

    @classmethod
    def record_timing(cls, duration_ms):
        """Record clustering task duration for Grafana timing panel."""
        r = cls._get_redis()
        date_key = cls._date_key()
        pipe = r.pipeline()

        pipe.incrby(f"{cls.KEY_PREFIX}:{date_key}:cluster_time_total_ms", int(duration_ms))
        pipe.incrby(f"{cls.KEY_PREFIX}:{date_key}:cluster_time_count", 1)
        pipe.incrby(f"{cls.KEY_PREFIX}:alltime:cluster_time_total_ms", int(duration_ms))
        pipe.incrby(f"{cls.KEY_PREFIX}:alltime:cluster_time_count", 1)

        pipe.execute()

    @classmethod
    def _sunioncard(cls, r, keys):
        """SUNIONSTORE to a temp key, SCARD it, then delete. Returns unique count."""
        if not keys:
            return 0
        if len(keys) == 1:
            return r.scard(keys[0])
        tmp_key = f"{cls.KEY_PREFIX}:_tmp:{uuid.uuid4().hex[:8]}"
        r.sunionstore(tmp_key, *keys)
        count = r.scard(tmp_key)
        r.delete(tmp_key)
        return count

    @classmethod
    def get_period_stats(cls, days=1):
        """Get aggregated counts for the last N days.

        unique_clusters and unique_stories come from SUNION of daily SETs.
        mark_read_expanded and timing come from summing daily counters.
        """
        r = cls._get_redis()
        today = datetime.date.today()

        # Collect daily SET keys for unique counting
        cid_keys = []
        sid_keys = []
        counter_keys = []
        counter_metadata = []
        counter_metrics = ["mark_read_expanded"] + cls.TIMING_KEYS

        for day_offset in range(days):
            date = today - datetime.timedelta(days=day_offset)
            date_key = cls._date_key(date)
            cid_keys.append(f"{cls.KEY_PREFIX}:cids:{date_key}")
            sid_keys.append(f"{cls.KEY_PREFIX}:sids:{date_key}")
            for metric in counter_metrics:
                counter_keys.append(f"{cls.KEY_PREFIX}:{date_key}:{metric}")
                counter_metadata.append(metric)

        # Unique counts from SETs
        stats = {
            "unique_clusters": cls._sunioncard(r, cid_keys),
            "unique_stories": cls._sunioncard(r, sid_keys),
        }

        # Sum counters for mark_read and timing
        values = r.mget(counter_keys) if counter_keys else []
        for m in counter_metrics:
            stats[m] = 0
        for i, value in enumerate(values):
            if value is not None:
                stats[counter_metadata[i]] += int(value)

        if stats["cluster_time_count"] > 0:
            stats["cluster_time_avg_ms"] = round(stats["cluster_time_total_ms"] / stats["cluster_time_count"])
        else:
            stats["cluster_time_avg_ms"] = 0

        return stats

    @classmethod
    def get_alltime_stats(cls):
        """Get all-time stats. Since clusters expire after 14 days,
        'alltime' for unique counts = union of last 14 days."""
        r = cls._get_redis()

        # Unique counts: union of last CLUSTER_TTL_DAYS daily sets
        today = datetime.date.today()
        cid_keys = []
        sid_keys = []
        for day_offset in range(CLUSTER_TTL_DAYS):
            date = today - datetime.timedelta(days=day_offset)
            date_key = cls._date_key(date)
            cid_keys.append(f"{cls.KEY_PREFIX}:cids:{date_key}")
            sid_keys.append(f"{cls.KEY_PREFIX}:sids:{date_key}")

        stats = {
            "unique_clusters": cls._sunioncard(r, cid_keys),
            "unique_stories": cls._sunioncard(r, sid_keys),
        }

        # Cumulative counters for mark_read and timing
        alltime_metrics = ["mark_read_expanded"] + cls.TIMING_KEYS
        keys = [f"{cls.KEY_PREFIX}:alltime:{m}" for m in alltime_metrics]
        values = r.mget(keys)
        for i, metric in enumerate(alltime_metrics):
            stats[metric] = int(values[i]) if values[i] is not None else 0

        if stats["cluster_time_count"] > 0:
            stats["cluster_time_avg_ms"] = round(stats["cluster_time_total_ms"] / stats["cluster_time_count"])
        else:
            stats["cluster_time_avg_ms"] = 0

        return stats
