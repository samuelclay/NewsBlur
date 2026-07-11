"""Redis-backed storage for the curated Global Shared Stories river."""

import redis
from django.conf import settings


class RGlobalSharedStory:
    """
    The Global Shared Stories river, curated hourly instead of followed.

    Redis Key Structure:
    - Curated river: "global_shared:curated" -> sorted set {story_hash: story_date timestamp}
    - Last refresh: "global_shared:refresh_timestamp" -> unix timestamp

    The river accumulates: each hourly run appends its picks and older stories stay
    put, so a reader can scroll back through past selections. Only the oldest stories
    fall off, once the river passes MAX_LIST_SIZE.
    """

    CURATED_KEY = "global_shared:curated"
    REFRESH_TIMESTAMP_KEY = "global_shared:refresh_timestamp"
    MAX_LIST_SIZE = 10000

    @classmethod
    def _redis(cls):
        return redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)

    @staticmethod
    def _decode_members(members):
        return [member.decode() if isinstance(member, bytes) else member for member in members]

    @classmethod
    def add_stories(cls, story_dates):
        """Add {story_hash: timestamp} to the river, skipping stories already in it."""
        if not story_dates:
            return 0

        r = cls._redis()
        existing = set(cls._decode_members(r.zrange(cls.CURATED_KEY, 0, -1)))
        added = 0
        pipe = r.pipeline()
        for story_hash, timestamp in story_dates.items():
            if story_hash in existing:
                continue
            pipe.zadd(cls.CURATED_KEY, {story_hash: timestamp}, nx=True)
            added += 1
        pipe.zremrangebyrank(cls.CURATED_KEY, 0, -(cls.MAX_LIST_SIZE + 1))
        pipe.execute()

        return added

    @classmethod
    def curated_story_hashes(cls):
        """Every story hash currently in the river, for deduping new candidates."""
        return set(cls._decode_members(cls._redis().zrange(cls.CURATED_KEY, 0, -1)))

    @classmethod
    def set_refreshed(cls, timestamp):
        cls._redis().set(cls.REFRESH_TIMESTAMP_KEY, int(timestamp))

    @classmethod
    def get_story_hashes(cls, offset=0, limit=12, order="newest", read_filter="all", user_id=None):
        """Page through the river, optionally dropping stories this user has read."""
        r = cls._redis()

        if read_filter != "unread" or not user_id:
            if order == "oldest":
                results = r.zrange(cls.CURATED_KEY, offset, offset + limit - 1)
            else:
                results = r.zrevrange(cls.CURATED_KEY, offset, offset + limit - 1)
            return cls._decode_members(results)

        if order == "oldest":
            candidates = cls._decode_members(r.zrange(cls.CURATED_KEY, 0, -1))
        else:
            candidates = cls._decode_members(r.zrevrange(cls.CURATED_KEY, 0, -1))

        r2 = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
        pipe = r2.pipeline()
        for story_hash in candidates:
            pipe.sismember(f"RS:{user_id}", story_hash)
        read_states = pipe.execute()
        unread = [story_hash for story_hash, is_read in zip(candidates, read_states) if not is_read]

        return unread[offset : offset + limit]
