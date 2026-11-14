"""In-memory stand-in for the Redis commands the RedListen code uses, for tests.

utils/redlisten.py, utils/redlisten_poller.py, utils/reddit_post_cache.py and
utils/reddit_fetcher.py keep budgets, stats and cached posts in Redis. Their tests
(apps/rss_feeds/test_redlisten.py, apps/rss_feeds/test_reddit_fetcher.py) run against
this instead, so they need neither a server nor fakeredis. Values come back as strings,
like a client created with decode_responses=True. See apps/rss_feeds/fake_redis.py.
"""


class FakeRedis:
    def __init__(self):
        self.data = {}
        self.ttls = {}

    def get(self, key):
        return self.data.get(key)

    def set(self, key, value, ex=None, nx=False):
        if nx and key in self.data:
            return None
        self.data[key] = str(value)
        if ex:
            self.ttls[key] = ex
        return True

    def delete(self, *keys):
        removed = 0
        for key in keys:
            if self.data.pop(key, None) is not None:
                removed += 1
            self.ttls.pop(key, None)
        return removed

    def exists(self, key):
        return int(key in self.data)

    def incr(self, key):
        value = int(self.data.get(key) or 0) + 1
        self.data[key] = str(value)
        return value

    def expire(self, key, seconds):
        if key not in self.data:
            return False
        self.ttls[key] = seconds
        return True

    def ttl(self, key):
        if key not in self.data:
            return -2
        return self.ttls.get(key, -1)

    def hgetall(self, key):
        return dict(self.data.get(key) or {})

    def hincrby(self, key, field, amount=1):
        hash_ = self.data.setdefault(key, {})
        hash_[field] = str(int(hash_.get(field) or 0) + amount)
        return int(hash_[field])

    def hset(self, key, field=None, value=None, mapping=None):
        hash_ = self.data.setdefault(key, {})
        if field is not None:
            hash_[field] = str(value)
        for name, item in (mapping or {}).items():
            hash_[name] = str(item)
        return 1

    def hdel(self, key, *fields):
        hash_ = self.data.get(key) or {}
        return sum(1 for field in fields if hash_.pop(field, None) is not None)

    def zadd(self, key, mapping, gt=False):
        zset = self.data.setdefault(key, {})
        for member, score in mapping.items():
            if gt and str(member) in zset and float(score) <= zset[str(member)]:
                continue
            zset[str(member)] = float(score)
        return len(mapping)

    def zrangebyscore(self, key, minimum, maximum):
        low = float("-inf") if minimum == "-inf" else float(minimum)
        high = float("inf") if maximum == "+inf" else float(maximum)
        zset = self.data.get(key) or {}
        return [
            member for member, score in sorted(zset.items(), key=lambda kv: kv[1]) if low <= score <= high
        ]

    def zrem(self, key, *members):
        zset = self.data.get(key) or {}
        return sum(1 for member in members if zset.pop(str(member), None) is not None)

    def zremrangebyscore(self, key, minimum, maximum):
        removed = self.zrangebyscore(key, minimum, maximum)
        return self.zrem(key, *removed) if removed else 0

    def zscore(self, key, member):
        return (self.data.get(key) or {}).get(str(member))

    def pipeline(self, transaction=True):
        return FakePipeline(self)


class FakePipeline:
    """Queues commands and runs them in order on execute(), returning their results. Tests
    run single-threaded, so execute() is as atomic as Redis's MULTI/EXEC."""

    def __init__(self, redis_):
        self.redis = redis_
        self.calls = []

    def __getattr__(self, name):
        def queue(*args, **kwargs):
            self.calls.append((name, args, kwargs))
            return self

        return queue

    def execute(self):
        results = [getattr(self.redis, name)(*args, **kwargs) for name, args, kwargs in self.calls]
        self.calls = []
        return results
