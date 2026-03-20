"""
Redis-based story clustering usage tracking.

Provides fast aggregation for Prometheus metrics by maintaining
HyperLogLogs and counters in Redis that are updated in real-time
when clustering operations occur.

Key structure (unique tracking via HyperLogLog):
- clustering:hcids:{date} - HLL of unique cluster IDs seen that day
- clustering:hsids:{date} - HLL of unique story hashes clustered that day
  Both have 35-day TTL. PFCOUNT across multiple keys gives deduplicated
  counts in O(N) with ~0.81% error, using 12KB/day instead of 5MB/day.

Key structure (operation counters):
- clustering:{date}:mark_read_expanded - daily extra stories marked read via clusters
- clustering:alltime:mark_read_expanded - cumulative mark-read expanded count (no expiry)
- clustering:{date}:cluster_time_total_ms - daily sum of clustering durations in ms
- clustering:{date}:cluster_time_count - daily number of clustering runs
- clustering:alltime:cluster_time_total_ms - cumulative sum of clustering durations
- clustering:alltime:cluster_time_count - cumulative number of clustering runs
"""

import datetime

import redis
from django.conf import settings

# rclustering_usage.py: 14-day cluster TTL means "alltime" = last 14 days
CLUSTER_TTL_DAYS = 14
HLL_TTL_SECONDS = 35 * 24 * 60 * 60


class RClusteringUsage:
    KEY_PREFIX = "clustering"
    METRICS = ["unique_clusters", "unique_stories", "mark_read_expanded"]
    TIMING_KEYS = ["cluster_time_total_ms", "cluster_time_count"]
    ES_KEYS = ["es_query_count", "es_query_total_ms", "es_stories_compared"]

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
        """Record unique cluster IDs and story hashes into daily HyperLogLogs.

        PFADD naturally deduplicates, so re-discovering the same cluster
        across multiple feed updates only counts it once per day (~0.81% error).
        Uses 12KB per key instead of ~5MB for 130K-member SETs.
        """
        if not cluster_ids:
            return
        r = cls._get_redis()
        date_key = cls._date_key()
        cid_key = f"{cls.KEY_PREFIX}:hcids:{date_key}"
        sid_key = f"{cls.KEY_PREFIX}:hsids:{date_key}"
        pipe = r.pipeline()

        pipe.pfadd(cid_key, *cluster_ids)
        pipe.pfadd(sid_key, *story_hashes)
        pipe.expire(cid_key, HLL_TTL_SECONDS)
        pipe.expire(sid_key, HLL_TTL_SECONDS)
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
    def record_es_stats(cls, es_stats):
        """Record per-invocation ES query stats for Grafana."""
        if not es_stats or es_stats.get("query_count", 0) == 0 and es_stats.get("stories_compared", 0) == 0:
            return
        r = cls._get_redis()
        date_key = cls._date_key()
        pipe = r.pipeline()

        qc = es_stats.get("query_count", 0)
        total_ms = int(es_stats.get("total_ms", 0))
        stories = es_stats.get("stories_compared", 0)

        pipe.incrby(f"{cls.KEY_PREFIX}:{date_key}:es_query_count", qc)
        pipe.incrby(f"{cls.KEY_PREFIX}:{date_key}:es_query_total_ms", total_ms)
        pipe.incrby(f"{cls.KEY_PREFIX}:{date_key}:es_stories_compared", stories)
        pipe.incrby(f"{cls.KEY_PREFIX}:alltime:es_query_count", qc)
        pipe.incrby(f"{cls.KEY_PREFIX}:alltime:es_query_total_ms", total_ms)
        pipe.incrby(f"{cls.KEY_PREFIX}:alltime:es_stories_compared", stories)

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
    def get_period_stats(cls, days=1):
        """Get aggregated counts for the last N days.

        unique_clusters and unique_stories use PFCOUNT across daily HyperLogLogs,
        which is O(N) in keys and returns deduplicated counts (~0.81% error).
        mark_read_expanded and timing come from summing daily counters.
        """
        r = cls._get_redis()
        today = datetime.date.today()

        cid_keys = []
        sid_keys = []
        counter_keys = []
        counter_metadata = []
        counter_metrics = ["mark_read_expanded"] + cls.TIMING_KEYS + cls.ES_KEYS

        for day_offset in range(days):
            date = today - datetime.timedelta(days=day_offset)
            date_key = cls._date_key(date)
            cid_keys.append(f"{cls.KEY_PREFIX}:hcids:{date_key}")
            sid_keys.append(f"{cls.KEY_PREFIX}:hsids:{date_key}")
            for metric in counter_metrics:
                counter_keys.append(f"{cls.KEY_PREFIX}:{date_key}:{metric}")
                counter_metadata.append(metric)

        # rclustering_usage.py: PFCOUNT handles multi-key union natively in O(N)
        stats = {
            "unique_clusters": r.pfcount(*cid_keys) if cid_keys else 0,
            "unique_stories": r.pfcount(*sid_keys) if sid_keys else 0,
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

        if stats.get("es_query_count", 0) > 0:
            stats["es_query_avg_ms"] = round(stats["es_query_total_ms"] / stats["es_query_count"])
        else:
            stats["es_query_avg_ms"] = 0

        return stats

    @classmethod
    def get_alltime_stats(cls):
        """Get all-time stats. Since clusters expire after 14 days,
        'alltime' for unique counts = PFCOUNT of last 14 days of HLLs."""
        r = cls._get_redis()
        today = datetime.date.today()

        cid_keys = []
        sid_keys = []
        for day_offset in range(CLUSTER_TTL_DAYS):
            date = today - datetime.timedelta(days=day_offset)
            date_key = cls._date_key(date)
            cid_keys.append(f"{cls.KEY_PREFIX}:hcids:{date_key}")
            sid_keys.append(f"{cls.KEY_PREFIX}:hsids:{date_key}")

        # rclustering_usage.py: PFCOUNT handles multi-key union natively in O(N)
        stats = {
            "unique_clusters": r.pfcount(*cid_keys) if cid_keys else 0,
            "unique_stories": r.pfcount(*sid_keys) if sid_keys else 0,
        }

        # Cumulative counters for mark_read, timing, and ES stats
        alltime_metrics = ["mark_read_expanded"] + cls.TIMING_KEYS + cls.ES_KEYS
        keys = [f"{cls.KEY_PREFIX}:alltime:{m}" for m in alltime_metrics]
        values = r.mget(keys)
        for i, metric in enumerate(alltime_metrics):
            stats[metric] = int(values[i]) if values[i] is not None else 0

        if stats["cluster_time_count"] > 0:
            stats["cluster_time_avg_ms"] = round(stats["cluster_time_total_ms"] / stats["cluster_time_count"])
        else:
            stats["cluster_time_avg_ms"] = 0

        if stats.get("es_query_count", 0) > 0:
            stats["es_query_avg_ms"] = round(stats["es_query_total_ms"] / stats["es_query_count"])
        else:
            stats["es_query_avg_ms"] = 0

        return stats
