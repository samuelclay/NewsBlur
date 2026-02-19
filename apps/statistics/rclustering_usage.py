"""
Redis-based story clustering usage tracking.

Provides fast aggregation for Prometheus metrics by maintaining
counters in Redis that are updated in real-time when clustering
operations occur.

Key structure:
- clustering:{date}:clusters_found - daily cluster count
- clustering:{date}:stories_clustered - daily stories-in-clusters count
- clustering:{date}:mark_read_expanded - daily extra stories marked read via clusters
- clustering:alltime:clusters_found - cumulative cluster count (no expiry)
- clustering:alltime:stories_clustered - cumulative stories-in-clusters count (no expiry)
- clustering:alltime:mark_read_expanded - cumulative mark-read expanded count (no expiry)
- clustering:{date}:cluster_time_total_ms - daily sum of clustering durations in ms
- clustering:{date}:cluster_time_count - daily number of clustering runs
- clustering:alltime:cluster_time_total_ms - cumulative sum of clustering durations
- clustering:alltime:cluster_time_count - cumulative number of clustering runs

No TTL on keys - they are tiny counters worth keeping permanently.
"""

import datetime

import redis
from django.conf import settings


class RClusteringUsage:
    KEY_PREFIX = "clustering"
    METRICS = ["clusters_found", "stories_clustered", "mark_read_expanded"]
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
    def record_clusters(cls, clusters_count, stories_count):
        """Record clustering results after store_clusters_to_redis()."""
        r = cls._get_redis()
        date_key = cls._date_key()
        pipe = r.pipeline()

        pipe.incrby(f"{cls.KEY_PREFIX}:{date_key}:clusters_found", clusters_count)
        pipe.incrby(f"{cls.KEY_PREFIX}:alltime:clusters_found", clusters_count)
        pipe.incrby(f"{cls.KEY_PREFIX}:{date_key}:stories_clustered", stories_count)
        pipe.incrby(f"{cls.KEY_PREFIX}:alltime:stories_clustered", stories_count)

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
    def get_period_stats(cls, days=1):
        """Get aggregated counts for the last N days."""
        r = cls._get_redis()
        today = datetime.date.today()

        all_keys = []
        key_metadata = []

        for day_offset in range(days):
            date = today - datetime.timedelta(days=day_offset)
            date_key = cls._date_key(date)
            for metric in cls.METRICS + cls.TIMING_KEYS:
                key = f"{cls.KEY_PREFIX}:{date_key}:{metric}"
                all_keys.append(key)
                key_metadata.append(metric)

        values = r.mget(all_keys) if all_keys else []

        stats = {m: 0 for m in cls.METRICS + cls.TIMING_KEYS}
        for i, value in enumerate(values):
            if value is not None:
                stats[key_metadata[i]] += int(value)

        if stats["cluster_time_count"] > 0:
            stats["cluster_time_avg_ms"] = round(stats["cluster_time_total_ms"] / stats["cluster_time_count"])
        else:
            stats["cluster_time_avg_ms"] = 0

        return stats

    @classmethod
    def get_alltime_stats(cls):
        """Get all-time cumulative counts."""
        r = cls._get_redis()
        all_metrics = cls.METRICS + cls.TIMING_KEYS
        keys = [f"{cls.KEY_PREFIX}:alltime:{m}" for m in all_metrics]
        values = r.mget(keys)

        stats = {}
        for i, metric in enumerate(all_metrics):
            stats[metric] = int(values[i]) if values[i] is not None else 0

        if stats["cluster_time_count"] > 0:
            stats["cluster_time_avg_ms"] = round(stats["cluster_time_total_ms"] / stats["cluster_time_count"])
        else:
            stats["cluster_time_avg_ms"] = 0

        return stats
