"""Tests for MCP usage metrics."""

from newsblur_mcp import metrics


class FakePipeline:
    def __init__(self, redis_client):
        self.redis_client = redis_client

    def incr(self, key):
        self.redis_client.counters[key] = self.redis_client.counters.get(key, 0) + 1
        return self

    def expireat(self, key, expiry):
        self.redis_client.expirations[key] = expiry
        return self

    def sadd(self, key, value):
        self.redis_client.sets.setdefault(key, set()).add(value)
        return self

    def execute(self):
        return []


class FakeRedis:
    def __init__(self):
        self.counters = {}
        self.sets = {}
        self.expirations = {}

    def pipeline(self):
        return FakePipeline(self)


def test_record_mcp_usage_counts_requests_and_unique_users(monkeypatch):
    fake_redis = FakeRedis()
    monkeypatch.setattr(metrics, "_get_redis", lambda: fake_redis)
    monkeypatch.setattr(metrics, "_date_key", lambda date=None: "2026-05-02")
    monkeypatch.setattr(metrics, "_expiry_timestamp", lambda date=None: 1770000000)

    metrics.record_mcp_usage("42")
    metrics.record_mcp_usage("42")
    metrics.record_mcp_usage()

    assert fake_redis.counters["mcp_usage:2026-05-02:requests"] == 3
    assert fake_redis.counters["mcp_usage:alltime:requests"] == 3
    assert fake_redis.sets["mcp_usage:2026-05-02:users"] == {"42"}
    assert fake_redis.sets["mcp_usage:alltime:users"] == {"42"}
    assert fake_redis.expirations["mcp_usage:2026-05-02:requests"] == 1770000000
    assert fake_redis.expirations["mcp_usage:2026-05-02:users"] == 1770000000
