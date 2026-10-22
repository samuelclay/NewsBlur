import datetime

import mongoengine as mongo

# Story length buckets for analytics, by the story's estimated audio length at 1x (apps/monitor/views/newsblur_listen.py).
LENGTH_BUCKETS = (
    ("under_2", 2 * 60),
    ("2_to_5", 5 * 60),
    ("5_to_10", 10 * 60),
    ("10_to_20", 20 * 60),
    ("over_20", None),
)


def length_bucket(seconds):
    for bucket, upper in LENGTH_BUCKETS:
        if upper is None or seconds < upper:
            return bucket
    return LENGTH_BUCKETS[-1][0]


class MListenUsage(mongo.Document):
    """One served Listen segment or voice preview, or a refused request, for caps, daily samples and analytics.

    `seconds` is the estimated audio length. Only freshly generated segments (`cached=False`) count against the
    monthly cap; samples count stories, cached or not. Refusals (`kind="denied"`) record which limit was hit in
    `reason` and never count toward anything. See apps/listen/usage.py.
    """

    user_id = mongo.IntField(required=True)
    kind = mongo.StringField(choices=("segment", "preview", "denied"), default="segment")
    reason = mongo.StringField()  # denied only: sample_limit, cap_reached, preview_ended, preview_limit
    story_hash = mongo.StringField()
    manifest_id = mongo.StringField()
    segment_index = mongo.IntField()
    characters = mongo.IntField(default=0)
    seconds = mongo.FloatField(default=0)
    cached = mongo.BooleanField(default=False)
    is_sample = mongo.BooleanField(default=False)
    plan_tier = mongo.StringField()  # free, premium, archive, pro
    voice_id = mongo.StringField()
    model = mongo.StringField()
    language = mongo.StringField()
    created_at = mongo.DateTimeField(default=datetime.datetime.utcnow)

    meta = {
        "collection": "listen_usage",
        "indexes": [
            {"fields": ["user_id", "-created_at"]},
            {"fields": ["-created_at"]},
            {"fields": ["kind", "-created_at"]},
        ],
        "allow_inheritance": False,
    }


class MListenDaily(mongo.Document):
    """Time a user actually spent listening to one story on one day (UTC), reported by the players through
    POST /listen/progress (apps/listen/views.py). One document per user, story and day, incremented in place.

    `audio_seconds` is how far playback advanced through the story's audio at 1x; `listen_seconds` is wall-clock
    listening time, so their ratio is the average playback speed.
    """

    user_id = mongo.IntField(required=True)
    date = mongo.StringField(required=True)  # YYYY-MM-DD, UTC
    story_hash = mongo.StringField(required=True)
    feed_id = mongo.IntField()
    language = mongo.StringField()
    voice_id = mongo.StringField()
    voice_name = mongo.StringField()
    voice_source = mongo.StringField()  # curated, library, premade
    delivery = mongo.StringField()  # steady, natural, expressive, custom
    plan_tier = mongo.StringField()
    is_preview = mongo.BooleanField(default=False)
    preview_completed = mongo.BooleanField(default=False)
    story_seconds = mongo.FloatField(default=0)
    length_bucket = mongo.StringField()
    audio_seconds = mongo.FloatField(default=0)
    listen_seconds = mongo.FloatField(default=0)
    finished = mongo.BooleanField(default=False)
    created_at = mongo.DateTimeField(default=datetime.datetime.utcnow)
    updated_at = mongo.DateTimeField(default=datetime.datetime.utcnow)

    meta = {
        "collection": "listen_daily",
        "indexes": [
            {"fields": ["user_id", "date", "story_hash"], "unique": True},
            {"fields": ["date"]},
        ],
        "allow_inheritance": False,
    }
