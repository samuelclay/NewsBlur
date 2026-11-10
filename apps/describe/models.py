"""apps/describe/models.py: Mongo documents behind the Describe feed search.

A Describe search turns a written description of what someone wants to read
("reviews of iOS apps with lots of screenshots") into a ranked list of feeds.
Every search is stored per user so the history rail can replay it instantly
without re-running the pipeline in apps/describe/pipeline.py.
"""

import datetime

import mongoengine as mongo
from bson.objectid import ObjectId

# apps/describe/models.py: only the most recent searches are kept per user.
HISTORY_LIMIT = 20
# apps/describe/models.py: a finished search never shows more feeds than this.
MAX_RESULTS = 24

STATUS_QUEUED = "queued"
STATUS_RUNNING = "running"
STATUS_COMPLETE = "complete"
STATUS_ERROR = "error"

SOURCE_INDEX = "index"
SOURCE_WEB = "web"


class MDescribeSearch(mongo.Document):
    """One Describe search: the prompt, its progress and its ranked feed results.

    `results` holds light rows (feed id, scores, reasons, a few story titles).
    Feed details are hydrated on the way out by `hydrate_results` so a replayed
    search always shows current subscriber counts and favicons.
    """

    user_id = mongo.IntField(required=True)
    prompt = mongo.StringField(required=True)
    request_id = mongo.StringField(max_length=64)
    status = mongo.StringField(default=STATUS_QUEUED)
    phase = mongo.StringField(default=STATUS_QUEUED)
    phase_message = mongo.StringField()
    sub_queries = mongo.ListField(mongo.StringField())
    results = mongo.ListField(mongo.DictField())
    error = mongo.StringField()
    stats = mongo.DictField()
    created_date = mongo.DateTimeField(default=datetime.datetime.now)
    updated_date = mongo.DateTimeField(default=datetime.datetime.now)
    completed_date = mongo.DateTimeField()

    meta = {
        "collection": "describe_searches",
        "indexes": [
            {"fields": ["user_id", "-created_date"]},
            {"fields": ["request_id"]},
        ],
        "allow_inheritance": False,
        "strict": False,
    }

    def __str__(self):
        return f"{self.user_id}: {self.prompt[:60]} ({self.status}, {len(self.results)} feeds)"

    # Lifecycle ---------------------------------------------------------------

    @classmethod
    def start(cls, user_id, prompt, request_id, search_id=None):
        """Create a search, or reset an existing one in place for "Search again".

        Re-running keeps the prompt's single history entry and bumps it to the
        top of the rail. Older entries beyond HISTORY_LIMIT are trimmed.
        """
        search = None
        if search_id:
            search = cls.for_user(user_id, search_id)
        now = datetime.datetime.now()
        if search:
            search.prompt = prompt
            search.results = []
            search.sub_queries = []
            search.error = None
            search.stats = {}
            search.completed_date = None
            search.created_date = now
        else:
            search = cls(user_id=user_id, prompt=prompt, created_date=now)
        search.request_id = request_id
        search.status = STATUS_QUEUED
        search.phase = STATUS_QUEUED
        search.phase_message = ""
        search.updated_date = now
        search.save()
        cls.trim_history(user_id)
        return search

    @classmethod
    def for_user(cls, user_id, search_id):
        """Return the user's search with this id, or None when it isn't theirs."""
        if not search_id or not ObjectId.is_valid(str(search_id)):
            return None
        return cls.objects(id=ObjectId(str(search_id)), user_id=user_id).first()

    @classmethod
    def trim_history(cls, user_id):
        """Delete every search past the user's HISTORY_LIMIT most recent ones."""
        stale = cls.objects(user_id=user_id).order_by("-created_date").skip(HISTORY_LIMIT)
        stale_ids = [search.id for search in stale.only("id")]
        if stale_ids:
            cls.objects(id__in=stale_ids).delete()
        return len(stale_ids)

    @classmethod
    def history_for_user(cls, user_id):
        searches = cls.objects(user_id=user_id).order_by("-created_date")[:HISTORY_LIMIT]
        return [search.summary() for search in searches]

    def mark_running(self):
        self.status = STATUS_RUNNING
        self.touch()

    def mark_phase(self, phase, message=""):
        self.phase = phase
        self.phase_message = message
        self.touch()

    def mark_complete(self, stats=None):
        self.status = STATUS_COMPLETE
        self.phase = STATUS_COMPLETE
        self.phase_message = ""
        self.completed_date = datetime.datetime.now()
        if stats:
            self.stats = stats
        self.touch()

    def mark_error(self, error):
        self.status = STATUS_ERROR
        self.phase = STATUS_ERROR
        self.error = error
        self.completed_date = datetime.datetime.now()
        self.touch()

    def touch(self):
        """Persist the mutable fields in place.

        An atomic update (not save()) so a search the user deleted while the
        pipeline was still running stays deleted instead of being re-inserted.
        """
        self.updated_date = datetime.datetime.now()
        self.__class__.objects(id=self.id).update_one(
            set__status=self.status,
            set__phase=self.phase,
            set__phase_message=self.phase_message or "",
            set__sub_queries=list(self.sub_queries),
            set__results=list(self.results),
            set__error=self.error,
            set__stats=dict(self.stats or {}),
            set__updated_date=self.updated_date,
            set__completed_date=self.completed_date,
        )

    @property
    def is_running(self):
        return self.status in (STATUS_QUEUED, STATUS_RUNNING)

    @property
    def is_finished(self):
        return self.status in (STATUS_COMPLETE, STATUS_ERROR)

    # Serialization -----------------------------------------------------------

    def summary(self):
        """The light shape shown in the history rail."""
        return {
            "id": str(self.id),
            "prompt": self.prompt,
            "status": self.status,
            "phase": self.phase,
            "created_date": self.created_date.isoformat() if self.created_date else None,
            "completed_date": self.completed_date.isoformat() if self.completed_date else None,
            "result_count": len(self.results),
        }

    def to_payload(self, hydrate=True):
        """The full shape the Describe tab and the mobile apps render."""
        payload = self.summary()
        payload.update(
            {
                "request_id": self.request_id,
                "phase_message": self.phase_message,
                "sub_queries": list(self.sub_queries),
                "error": self.error,
                "stats": dict(self.stats or {}),
                "results": hydrate_results(self.results) if hydrate else list(self.results),
            }
        )
        return payload


class MDescribeUsage(mongo.Document):
    """One row per Describe search attempt, for the daily quota in apps/describe/usage.py."""

    user_id = mongo.IntField(required=True)
    search_id = mongo.StringField()
    request_id = mongo.StringField()
    plan_tier = mongo.StringField()
    over_quota = mongo.BooleanField(default=False)
    created_at = mongo.DateTimeField(default=datetime.datetime.utcnow)

    meta = {
        "collection": "describe_usage",
        "indexes": [
            {"fields": ["user_id", "-created_at"]},
            {"fields": ["-created_at"]},
        ],
        "allow_inheritance": False,
        "strict": False,
    }


def make_result_row(feed, source, matched_query="", similarity=None, stories=None):
    """Build the stored row for a feed found by the pipeline.

    Rows stay small on purpose: ids, scores, the judge's reason and three
    story titles. Everything else is hydrated per request.
    """
    stories = stories or []
    return {
        "feed_id": feed.pk,
        "feed_title": feed.feed_title,
        "feed_address": feed.feed_address,
        "feed_link": feed.feed_link,
        "source": source,
        "matched_query": matched_query,
        "similarity": round(similarity, 4) if similarity is not None else None,
        "score": None,
        "reason": None,
        "judged": False,
        "stories": [
            {
                "story_title": story.get("story_title") or "",
                "story_permalink": story.get("story_permalink") or "",
                "story_date": story["story_date"].isoformat()
                if isinstance(story.get("story_date"), datetime.datetime)
                else (story.get("story_date") or None),
            }
            for story in stories[:3]
        ],
    }


def sort_results(results):
    """Judged feeds first by score, then similarity; unjudged candidates after, by similarity."""

    def sort_key(row):
        judged = bool(row.get("judged"))
        score = row.get("score") if row.get("score") is not None else -1
        similarity = row.get("similarity") if row.get("similarity") is not None else -1
        return (0 if judged else 1, -score, -similarity)

    return sorted(results, key=sort_key)


def hydrate_results(results):
    """Attach current feed details (title, favicon, subscribers, freshness) to stored rows."""
    from apps.rss_feeds.models import Feed, MFeedIcon

    if not results:
        return []

    feed_ids = [row["feed_id"] for row in results if row.get("feed_id")]
    feeds = {feed.pk: feed for feed in Feed.objects.filter(pk__in=feed_ids)}
    icons = {icon.feed_id: icon for icon in MFeedIcon.objects.filter(feed_id__in=feed_ids)}

    hydrated = []
    for row in results:
        feed = feeds.get(row.get("feed_id"))
        if not feed:
            continue
        feed_dict = feed.canonical(full=True, include_favicon=False)
        icon = icons.get(feed.pk)
        if icon and icon.data:
            feed_dict["favicon"] = icon.data
            feed_dict["favicon_color"] = icon.color
        hydrated_row = dict(row)
        hydrated_row["feed"] = feed_dict
        hydrated.append(hydrated_row)
    return hydrated
