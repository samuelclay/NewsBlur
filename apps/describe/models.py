"""apps/describe/models.py: Mongo documents behind the Describe feed search.

A Describe search turns a written description of what someone wants to read
("reviews of iOS apps with lots of screenshots") into a ranked list of feeds.
Every search is stored per user so the history rail can replay it instantly
without re-running the pipeline in apps/describe/pipeline.py.
"""

import datetime
import html
import re

import mongoengine as mongo
from bson.objectid import ObjectId
from django.utils.html import escape, strip_tags
from django.utils.translation import gettext

# apps/describe/models.py: only the most recent searches are kept per user.
HISTORY_LIMIT = 20
# apps/describe/models.py: a finished search never shows more feeds than this.
MAX_RESULTS = 24

# apps/describe/models.py: a search that has not written progress for this long has lost its task
# (worker killed, task dropped, hard time limit). The task's hard limit is 420 seconds and the
# longest single step is a 120 second model call with one retry, so ten quiet minutes means dead.
STALE_AFTER_SECONDS = 600

STATUS_QUEUED = "queued"
STATUS_RUNNING = "running"
STATUS_COMPLETE = "complete"
STATUS_ERROR = "error"

# apps/describe/models.py: plain text kept per story for the card's content preview (three lines at most).
STORY_PREVIEW_CHARS = 300
FIRST_IMAGE_RE = re.compile(r"<img[^>]+src=[\"']([^\"']+)[\"']", re.IGNORECASE)

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
        search = cls.objects(id=ObjectId(str(search_id)), user_id=user_id).first()
        if search:
            search.expire_if_stale()
        return search

    @classmethod
    def running_for_user(cls, user_id):
        """The user's search that is still queued or running, if any. Stuck ones are expired first."""
        for search in cls.objects(user_id=user_id, status__in=[STATUS_QUEUED, STATUS_RUNNING]):
            if not search.expire_if_stale():
                return search
        return None

    @classmethod
    def trim_history(cls, user_id):
        """Delete every search past the user's HISTORY_LIMIT most recent ones."""
        stale = cls.objects(user_id=user_id).order_by("-created_date", "-id").skip(HISTORY_LIMIT)
        stale_ids = [search.id for search in stale.only("id")]
        if stale_ids:
            cls.objects(id__in=stale_ids).delete()
        return len(stale_ids)

    @classmethod
    def history_for_user(cls, user_id):
        searches = list(cls.objects(user_id=user_id).order_by("-created_date", "-id")[:HISTORY_LIMIT])
        for search in searches:
            search.expire_if_stale()
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
        self.refund_usage()

    def expire_if_stale(self):
        """Fail a search whose task went quiet, so it never blocks its owner. Returns True when expired.

        The update is conditional on the search still being unfinished and still
        quiet, so a task that writes progress at the same moment wins.
        """
        if not self.is_running:
            return False
        now = datetime.datetime.now()
        cutoff = now - datetime.timedelta(seconds=STALE_AFTER_SECONDS)
        if self.updated_date and self.updated_date > cutoff:
            return False
        message = gettext("This search stopped before it finished. Search again to retry.")
        expired = self.__class__.objects(
            id=self.id, status__in=[STATUS_QUEUED, STATUS_RUNNING], updated_date__lte=cutoff
        ).update_one(
            set__status=STATUS_ERROR,
            set__phase=STATUS_ERROR,
            set__error=message,
            set__completed_date=now,
            set__updated_date=now,
        )
        self.reload()
        if not expired:
            return False
        self.refund_usage()
        return True

    def refund_usage(self):
        """A search that failed does not count against the daily quota in apps/describe/usage.py."""
        if self.request_id:
            MDescribeUsage.objects(
                user_id=self.user_id, request_id=self.request_id, over_quota=False
            ).delete()

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


def story_snapshot(story):
    """The stored form of one story: what the Add Site feed card needs to draw its story preview.

    add_site_view.js render_feed_card reads story_title, image_urls and
    story_content, the same keys Feed.get_stories gives the other Discover
    tabs. A whole story body is far too big to keep on every row, so the
    content is cut down to its first image and a short run of plain text.
    """
    content = story.get("story_content") or ""
    images = [url for url in (story.get("image_urls") or []) if url][:1]
    if not images:
        first_image = FIRST_IMAGE_RE.search(content)
        if first_image:
            images = [first_image.group(1)]
    text = " ".join(html.unescape(strip_tags(content)).split())[:STORY_PREVIEW_CHARS]
    story_date = story.get("story_date")
    return {
        "story_title": story.get("story_title") or "",
        "story_permalink": story.get("story_permalink") or "",
        "story_date": story_date.isoformat()
        if isinstance(story_date, datetime.datetime)
        else (story_date or None),
        "image_urls": images,
        "story_content": escape(text),
    }


def make_result_row(feed, source, matched_query="", similarity=None, stories=None):
    """Build the stored row for a feed found by the pipeline.

    Rows stay small on purpose: ids, scores, the judge's reason and three
    story snapshots. Everything else is hydrated per request.
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
        "stories": [story_snapshot(story) for story in stories[:3]],
    }


def make_unsaved_row(row_key, preview, matched_query=""):
    """Build the stored row for a site the web hunt found that NewsBlur has no Feed for.

    `row_key` is a negative number that identifies the row within its search,
    since there is no feed id yet. See apps/describe/web_preview.py: the Feed is
    only created when someone subscribes to or previews the site.
    """
    row = {
        "feed_id": row_key,
        "feed_title": preview["feed_title"],
        "feed_address": preview["feed_address"],
        "feed_link": preview["feed_link"],
        "tagline": preview.get("tagline") or "",
        "unsaved": True,
        "source": SOURCE_WEB,
        "matched_query": matched_query,
        "similarity": None,
        "score": None,
        "reason": None,
        "judged": False,
        "stories": [story_snapshot(story) for story in (preview.get("stories") or [])[:3]],
    }
    return row


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

    feed_ids = [row["feed_id"] for row in results if not row.get("unsaved") and row.get("feed_id")]
    feeds = {feed.pk: feed for feed in Feed.objects.filter(pk__in=feed_ids)}

    # apps/describe/models.py: an unsaved web find becomes a real feed once someone subscribes to
    # or previews it, so look for one at its address before falling back to the stored snapshot.
    unsaved_addresses = [row["feed_address"] for row in results if row.get("unsaved")]
    saved_since = {}
    if unsaved_addresses:
        created = Feed.objects.filter(feed_address__in=unsaved_addresses, branch_from_feed=None)
        for feed in created.order_by("num_subscribers"):
            saved_since[feed.feed_address] = feed

    icon_feed_ids = feed_ids + [feed.pk for feed in saved_since.values()]
    icons = {icon.feed_id: icon for icon in MFeedIcon.objects.filter(feed_id__in=icon_feed_ids)}

    hydrated = []
    for row in results:
        if row.get("unsaved"):
            feed = saved_since.get(row["feed_address"])
            if not feed:
                hydrated_row = dict(row)
                hydrated_row["feed"] = {
                    "feed_title": row["feed_title"],
                    "feed_address": row["feed_address"],
                    "feed_link": row["feed_link"],
                    "tagline": row.get("tagline") or "",
                    "num_subscribers": 0,
                }
                hydrated.append(hydrated_row)
                continue
        else:
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
