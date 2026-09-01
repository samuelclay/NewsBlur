"""Redis-backed storage for the curated Global Shared Stories river."""

import redis
from django.conf import settings


class RGlobalSharedStory:
    """
    The Global Shared Stories river, curated hourly instead of followed.

    Redis Key Structure:
    - Curated river: "global_shared:curated" -> sorted set {story_hash: story_date timestamp}
    - Last refresh: "global_shared:refresh_timestamp" -> unix timestamp
    - Considered stories: "global_shared:considered" -> sorted set {story_hash: considered timestamp}
    - Muted users: "global_shared:muted_user_ids" -> set of user ids barred from the river
    - Curation lock: "global_shared:curation_lock" -> held for the hour so one run curates it

    The river accumulates: each hourly run appends its picks and older stories stay
    put, so a reader can scroll back through past selections. Only the oldest stories
    fall off, once the river passes MAX_LIST_SIZE.

    A story shown to the curator is remembered in the considered set whether or not it
    was picked. Without that memory, a rejected story stayed a candidate for the whole
    lookback window and got re-judged every run until it eventually won one, which let
    weak and spammy shares grind their way into the river.
    """

    CURATED_KEY = "global_shared:curated"
    REFRESH_TIMESTAMP_KEY = "global_shared:refresh_timestamp"
    CONSIDERED_KEY = "global_shared:considered"
    MUTED_KEY = "global_shared:muted_user_ids"
    CURATION_LOCK_KEY = "global_shared:curation_lock"
    MAX_LIST_SIZE = 10000
    # apps/social/rglobal.py: Longer than curation.CANDIDATE_HOURS, so a judged story ages out
    # of the candidate window before its considered marker expires and can never be re-judged.
    CONSIDERED_TTL_HOURS = 24
    # apps/social/rglobal.py: Just under the hourly schedule, so the next run can always
    # acquire the lock while a duplicate run in the same hour never can.
    CURATION_LOCK_SECONDS = 55 * 60

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
    def remove_stories(cls, story_hashes):
        """Pull stories out of the river, e.g. when purging a spammer's shares."""
        if not story_hashes:
            return 0

        return cls._redis().zrem(cls.CURATED_KEY, *story_hashes)

    @classmethod
    def mark_considered(cls, story_hashes, timestamp):
        """Remember stories the curator has judged so a rejection is final, not a retry."""
        if not story_hashes:
            return

        r = cls._redis()
        pipe = r.pipeline()
        pipe.zadd(cls.CONSIDERED_KEY, {story_hash: timestamp for story_hash in story_hashes})
        pipe.zremrangebyscore(cls.CONSIDERED_KEY, "-inf", timestamp - cls.CONSIDERED_TTL_HOURS * 3600)
        pipe.execute()

    @classmethod
    def considered_story_hashes(cls):
        """Every story hash the curator has already judged, picked or not."""
        return set(cls._decode_members(cls._redis().zrange(cls.CONSIDERED_KEY, 0, -1)))

    @classmethod
    def muted_user_ids(cls):
        """Users whose shares never enter the river, no matter what they share."""
        return set(int(user_id) for user_id in cls._decode_members(cls._redis().smembers(cls.MUTED_KEY)))

    @classmethod
    def mute_user(cls, user_id):
        cls._redis().sadd(cls.MUTED_KEY, user_id)

    @classmethod
    def unmute_user(cls, user_id):
        cls._redis().srem(cls.MUTED_KEY, user_id)

    @classmethod
    def acquire_curation_lock(cls, timeout=CURATION_LOCK_SECONDS):
        """
        Claim this hour's curation run. Returns False when another run already has it,
        which happens when multiple celery beats fire the same hourly task.
        """
        return bool(cls._redis().set(cls.CURATION_LOCK_KEY, "locked", nx=True, ex=timeout))

    @classmethod
    def release_curation_lock(cls):
        cls._redis().delete(cls.CURATION_LOCK_KEY)

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
