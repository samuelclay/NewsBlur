import datetime

import mongoengine as mongo
import redis
from django.conf import settings


class MMediaPlaybackState(mongo.Document):
    """Persistent media player state: current item, position, and queue.

    Stores the user's media playback state so it persists across page reloads.
    The queue holds an ordered list of media items (audio/video/YouTube).
    Position is synced via WebSocket to Redis for fast reads, with durable
    state changes saved to MongoDB via HTTP endpoints.
    """

    user_id = mongo.IntField(unique=True)

    # Current playing item
    current_story_hash = mongo.StringField(default="")
    current_media_url = mongo.StringField(default="")
    current_media_type = mongo.StringField(default="")  # "audio", "video", "youtube"
    current_media_title = mongo.StringField(default="")
    current_feed_id = mongo.IntField(default=0)
    current_image_url = mongo.StringField(default="")
    current_position = mongo.FloatField(default=0)
    current_duration = mongo.FloatField(default=0)
    current_playback_rate = mongo.FloatField(default=1.0)
    current_volume = mongo.FloatField(default=1.0)
    is_playing = mongo.BooleanField(default=False)

    # Player settings
    skip_back_seconds = mongo.IntField(default=15)
    skip_forward_seconds = mongo.IntField(default=30)
    auto_play_next = mongo.BooleanField(default=True)
    remember_position = mongo.BooleanField(default=True)
    resume_on_load = mongo.BooleanField(default=True)

    # Queue: ordered list of media items
    # Each item: {story_hash, media_url, media_type, media_title, feed_id, image_url}
    queue = mongo.ListField(mongo.DictField())

    # History: last 10 played items with saved positions
    # Each item: {story_hash, media_url, media_type, media_title, feed_id, image_url, position, duration, played_at}
    history = mongo.ListField(mongo.DictField())

    updated_at = mongo.DateTimeField(default=datetime.datetime.now)

    meta = {
        "collection": "media_playback_state",
        "allow_inheritance": False,
        "indexes": ["user_id"],
    }

    def __str__(self):
        return f"MediaPlayback user={self.user_id} type={self.current_media_type} playing={self.is_playing}"

    def canonical(self):
        return {
            "current_story_hash": self.current_story_hash,
            "current_media_url": self.current_media_url,
            "current_media_type": self.current_media_type,
            "current_media_title": self.current_media_title,
            "current_feed_id": self.current_feed_id,
            "current_image_url": self.current_image_url,
            "current_position": self.current_position,
            "current_duration": self.current_duration,
            "current_playback_rate": self.current_playback_rate,
            "current_volume": self.current_volume,
            "is_playing": self.is_playing,
            "skip_back_seconds": self.skip_back_seconds,
            "skip_forward_seconds": self.skip_forward_seconds,
            "auto_play_next": self.auto_play_next,
            "remember_position": self.remember_position,
            "resume_on_load": self.resume_on_load,
            "queue": self.queue or [],
            "history": self.history or [],
        }

    @classmethod
    def get_user(cls, user_id):
        try:
            return cls.objects.get(user_id=user_id)
        except cls.DoesNotExist:
            return None

    @classmethod
    def get_or_create_user(cls, user_id):
        state = cls.get_user(user_id)
        if not state:
            state = cls.objects.create(user_id=user_id)
        return state

    @classmethod
    def save_playback_state(cls, user_id, **kwargs):
        state = cls.get_or_create_user(user_id)
        for key, value in kwargs.items():
            if hasattr(state, key) and key not in ("user_id", "meta"):
                setattr(state, key, value)
        state.updated_at = datetime.datetime.now()
        state.save()
        return state

    @classmethod
    def add_to_queue(cls, user_id, media_item, position=None):
        state = cls.get_or_create_user(user_id)
        queue = list(state.queue or [])
        # Prevent duplicates (same story_hash + media_url)
        queue = [
            q
            for q in queue
            if not (
                q.get("story_hash") == media_item.get("story_hash")
                and q.get("media_url") == media_item.get("media_url")
            )
        ]
        if "added_at" not in media_item:
            media_item["added_at"] = datetime.datetime.now().isoformat()
        if position is not None and 0 <= position <= len(queue):
            queue.insert(position, media_item)
        else:
            queue.append(media_item)
        state.queue = queue
        state.updated_at = datetime.datetime.now()
        state.save()
        return state

    @classmethod
    def remove_from_queue(cls, user_id, story_hash, media_url):
        state = cls.get_user(user_id)
        if not state:
            return None
        state.queue = [
            q
            for q in (state.queue or [])
            if not (q.get("story_hash") == story_hash and q.get("media_url") == media_url)
        ]
        state.updated_at = datetime.datetime.now()
        state.save()
        return state

    @classmethod
    def reorder_queue(cls, user_id, queue_order):
        """queue_order is a list of {story_hash, media_url} in desired order."""
        state = cls.get_user(user_id)
        if not state:
            return None
        queue_map = {}
        for item in state.queue or []:
            key = (item.get("story_hash"), item.get("media_url"))
            queue_map[key] = item
        new_queue = []
        for order_item in queue_order:
            key = (order_item.get("story_hash"), order_item.get("media_url"))
            if key in queue_map:
                new_queue.append(queue_map[key])
        state.queue = new_queue
        state.updated_at = datetime.datetime.now()
        state.save()
        return state

    @classmethod
    def add_to_history(cls, user_id, media_item):
        """Add a played item to history. Capped at 10 items, most recent first."""
        state = cls.get_or_create_user(user_id)
        history = list(state.history or [])
        # Remove existing entry for same item (deduplicate by story_hash + media_url)
        history = [
            h
            for h in history
            if not (
                h.get("story_hash") == media_item.get("story_hash")
                and h.get("media_url") == media_item.get("media_url")
            )
        ]
        if "played_at" not in media_item:
            media_item["played_at"] = datetime.datetime.now().isoformat()
        history.insert(0, media_item)
        history = history[:10]
        state.history = history
        state.updated_at = datetime.datetime.now()
        state.save()
        return state

    @classmethod
    def remove_from_history(cls, user_id, story_hash, media_url):
        state = cls.get_user(user_id)
        if not state:
            return None
        state.history = [
            h
            for h in (state.history or [])
            if not (h.get("story_hash") == story_hash and h.get("media_url") == media_url)
        ]
        state.updated_at = datetime.datetime.now()
        state.save()
        return state

    @classmethod
    def clear_history(cls, user_id):
        state = cls.get_user(user_id)
        if not state:
            return None
        state.history = []
        state.updated_at = datetime.datetime.now()
        state.save()
        return state

    @classmethod
    def clear_state(cls, user_id):
        state = cls.get_user(user_id)
        if state:
            state.delete()

    @classmethod
    def get_state_with_redis_position(cls, user_id):
        """Get playback state, preferring Redis position over MongoDB position."""
        state = cls.get_user(user_id)
        if not state:
            return None
        canonical = state.canonical()
        # Check Redis for fresher position data
        try:
            r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
            redis_key = f"media:playback:{user_id}"
            redis_data = r.hgetall(redis_key)
            if redis_data:
                if b"position" in redis_data:
                    canonical["current_position"] = float(redis_data[b"position"])
                if b"duration" in redis_data:
                    canonical["current_duration"] = float(redis_data[b"duration"])
                if b"is_playing" in redis_data:
                    canonical["is_playing"] = redis_data[b"is_playing"] == b"true"
                if b"playback_rate" in redis_data:
                    canonical["current_playback_rate"] = float(redis_data[b"playback_rate"])
                if b"volume" in redis_data:
                    canonical["current_volume"] = float(redis_data[b"volume"])
        except Exception:
            pass  # Fall back to MongoDB data if Redis is unavailable
        return canonical
