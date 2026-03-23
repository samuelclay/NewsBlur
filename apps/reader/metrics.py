"""Prometheus metrics helpers for reader load instrumentation."""

from prometheus_client import Counter, Histogram

READER_LOAD_REQUESTS = Counter(
    "newsblur_reader_load_requests_total",
    "Total feed and river reader load requests",
    ["endpoint", "read_filter"],
)

READER_LOAD_SLOW_REQUESTS = Counter(
    "newsblur_reader_load_slow_requests_total",
    "Total slow feed and river reader load requests",
    ["endpoint", "read_filter"],
)

READER_LOAD_PHASE_DURATION = Histogram(
    "newsblur_reader_load_phase_duration_seconds",
    "Duration of reader load phases",
    ["endpoint", "phase", "read_filter"],
    buckets=(0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2, 5, 10),
)

STORY_HASHES_DURATION = Histogram(
    "newsblur_story_hashes_duration_seconds",
    "Duration of UserSubscription.story_hashes calls",
    ["source", "read_filter"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2, 5),
)

UNREAD_CACHE_FEED_STATE = Counter(
    "newsblur_unread_cache_feed_state_total",
    "Observed unread-cache feed state during story_hashes calls",
    ["source", "state"],
)

UNREAD_CACHE_REBUILD_CALLS = Counter(
    "newsblur_unread_cache_rebuild_calls_total",
    "story_hashes calls that triggered one or more unread-cache rebuilds",
    ["source"],
)

UNREAD_CACHE_REBUILT_FEEDS = Counter(
    "newsblur_unread_cache_rebuilt_feeds_total",
    "Total feeds rebuilt in unread cache by reason",
    ["source", "reason"],
)

UNREAD_CACHE_REBUILD_FEEDS_PER_CALL = Histogram(
    "newsblur_unread_cache_rebuild_feeds_per_call",
    "Number of feeds rebuilt per story_hashes call",
    ["source"],
    buckets=(1, 2, 5, 10, 20, 50, 100, 250, 500, 1000),
)

UNREAD_CACHE_FAST_PATH = Counter(
    "newsblur_unread_cache_fast_path_total",
    "Single-feed paginated unread-cache fast path usage",
    ["source", "dirty"],
)


def normalize_reader_metrics_source(source):
    if source in {"feed_request", "river_request", "score_recalc"}:
        return source
    return "other"


def normalize_reader_metrics_read_filter(read_filter, query=False):
    if query:
        return "query"
    if read_filter in {"all", "unread", "starred"}:
        return read_filter
    return "other"
