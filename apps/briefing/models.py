import datetime

import mongoengine as mongo
import redis
from django.conf import settings

from apps.rss_feeds.models import Feed, MStory
from utils import log as logging


class MBriefing(mongo.Document):
    """
    A single generated briefing for a user.

    Each briefing corresponds to one AI-generated summary story plus
    a set of curated story hashes from the user's feeds.
    """

    user_id = mongo.IntField()
    briefing_feed_id = mongo.IntField()
    summary_story_hash = mongo.StringField()
    curated_story_hashes = mongo.ListField(mongo.StringField())
    briefing_date = mongo.DateTimeField()
    period_start = mongo.DateTimeField()
    generated_at = mongo.DateTimeField()
    frequency = mongo.StringField(choices=["daily", "twice_daily", "weekly"], default="daily")
    status = mongo.StringField(choices=["pending", "generating", "complete", "failed"], default="pending")

    meta = {
        "collection": "briefings",
        "indexes": [
            ("user_id", "-briefing_date"),
            {"fields": ["summary_story_hash"], "unique": True, "sparse": True},
        ],
        "ordering": ["-briefing_date"],
        "allow_inheritance": False,
    }

    def __str__(self):
        return "Briefing for user %s on %s (%s stories)" % (
            self.user_id,
            self.briefing_date,
            len(self.curated_story_hashes),
        )

    @classmethod
    def latest_for_user(cls, user_id, limit=10):
        return cls.objects.filter(user_id=user_id, status="complete").order_by("-briefing_date")[:limit]

    @classmethod
    def exists_for_period(cls, user_id, period_start, period_end):
        return cls.objects.filter(
            user_id=user_id,
            briefing_date__gte=period_start,
            briefing_date__lte=period_end,
        ).count() > 0


BRIEFING_SECTION_DEFINITIONS = [
    {"key": "trending_unread", "name": "Stories you missed", "subtitle": "Popular stories you haven't read yet", "default": True},
    {"key": "long_read", "name": "Long reads for later", "subtitle": "Longer articles worth setting time aside for", "default": True},
    {"key": "classifier_match", "name": "Based on your interests", "subtitle": "Stories matching your trained topics and authors", "default": True},
    {"key": "follow_up", "name": "Follow-ups", "subtitle": "New posts from feeds you recently read", "default": True},
    {"key": "trending_global", "name": "Trending across NewsBlur", "subtitle": "Widely-read stories from across the platform", "default": True},
    {"key": "duplicates", "name": "Common stories", "subtitle": "Stories covered by multiple feeds", "default": False},
    {"key": "quick_catchup", "name": "Quick catch-up", "subtitle": "TL;DR of the most important stories", "default": False},
    {"key": "emerging_topics", "name": "Emerging topics", "subtitle": "Topics getting increasing coverage", "default": False},
    {"key": "contrarian_views", "name": "Contrarian views", "subtitle": "Different perspectives on the same topic", "default": False},
]

VALID_SECTION_KEYS = {s["key"] for s in BRIEFING_SECTION_DEFINITIONS}
# models.py: Custom sections use keys custom_1 through custom_5
VALID_SECTION_KEYS.update({"custom_%d" % i for i in range(1, 6)})

DEFAULT_SECTIONS = {s["key"]: s["default"] for s in BRIEFING_SECTION_DEFINITIONS}

MAX_CUSTOM_SECTIONS = 5


class MBriefingPreferences(mongo.Document):
    """Per-user briefing configuration stored in MongoDB."""

    user_id = mongo.IntField(unique=True)
    frequency = mongo.StringField(choices=["daily", "twice_daily", "weekly"], default="daily")
    preferred_time = mongo.StringField(default=None)  # "HH:MM" in user's timezone, null = auto-detect
    preferred_day = mongo.StringField(default=None)  # Day of week for weekly frequency (sun, mon, tue, etc.)
    enabled = mongo.BooleanField(default=False)
    briefing_feed_id = mongo.IntField(default=None)
    story_count = mongo.IntField(default=20)
    summary_length = mongo.StringField(choices=["short", "medium", "detailed"], default="medium")
    story_sources = mongo.StringField(default="all")  # "all" or "folder:FolderName"
    read_filter = mongo.StringField(choices=["unread", "focus"], default="unread")  # unread or focus stories
    summary_style = mongo.StringField(choices=["editorial", "bullets", "headlines"], default="editorial")
    include_read = mongo.BooleanField(default=False)  # False = unread only, True = include read stories
    sections = mongo.DictField(default=None)  # {"trending_unread": True, "custom_1": True, ...} or None for defaults
    custom_section_prompts = mongo.ListField(mongo.StringField(), default=None)  # Up to 5 custom prompts

    meta = {
        "collection": "briefing_preferences",
        "indexes": ["user_id"],
        "allow_inheritance": False,
    }

    def __str__(self):
        return "BriefingPrefs for user %s: %s at %s" % (
            self.user_id,
            self.frequency,
            self.preferred_time or "auto",
        )

    @classmethod
    def get_or_create(cls, user_id):
        try:
            return cls.objects.get(user_id=user_id)
        except cls.DoesNotExist:
            try:
                prefs = cls(user_id=user_id)
                prefs.save()
                return prefs
            except mongo.NotUniqueError:
                return cls.objects.get(user_id=user_id)


def ensure_briefing_feed(user):
    """
    Ensure a briefing feed exists for the user, creating one if needed.
    Returns the Feed instance.

    Follows the newsletter pattern from apps/newsletters/models.py:63-74.
    Does NOT add to UserSubscriptionFolders — the sidebar entry is fixed in the template.
    """
    from apps.reader.models import UserSubscription

    feed_address = "daily-briefing:%s" % user.pk

    try:
        feed = Feed.objects.get(feed_address=feed_address)
    except Feed.MultipleObjectsReturned:
        feed = Feed.objects.filter(feed_address=feed_address).first()
    except Feed.DoesNotExist:
        feed = Feed.objects.create(
            feed_address=feed_address,
            feed_link="",
            feed_title="Daily Briefing",
            fetched_once=True,
            known_good=True,
        )
        feed.update()
        logging.debug(" ---> Created briefing feed %s for user %s" % (feed.pk, user.pk))

        r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
        r.publish(user.username, "reload:%s" % feed.pk)

    if not UserSubscription.objects.filter(user=user, feed=feed).exists():
        UserSubscription.objects.create(user=user, feed=feed)
        logging.debug(" ---> Created briefing subscription for user %s" % user.pk)

    prefs = MBriefingPreferences.get_or_create(user.pk)
    if prefs.briefing_feed_id != feed.pk:
        prefs.briefing_feed_id = feed.pk
        prefs.save()

    return feed


def create_briefing_story(feed, user, summary_html, briefing_date, curated_story_hashes):
    """
    Create or update an MStory in the briefing feed with the AI summary, and an MBriefing
    record linking the summary to the curated stories.

    If a briefing already exists for the same day, overwrites it instead of creating a duplicate.

    Returns (MBriefing, MStory) tuple.
    """
    import pytz

    from apps.notifications.models import MUserFeedNotification
    from apps.notifications.tasks import QueueNotifications
    from apps.reader.models import UserSubscription

    # models.py: Convert UTC briefing_date to user's local timezone for the title
    user_tz = pytz.timezone(str(user.profile.timezone))
    local_date = pytz.utc.localize(briefing_date).astimezone(user_tz)
    title = "Daily Briefing — %s" % local_date.strftime("%B %-d, %Y")

    day_start = briefing_date.replace(hour=0, minute=0, second=0, microsecond=0)
    day_end = day_start + datetime.timedelta(days=1)
    existing_briefing = MBriefing.objects.filter(
        user_id=user.pk,
        briefing_date__gte=day_start,
        briefing_date__lte=day_end,
    ).first()

    if existing_briefing and existing_briefing.summary_story_hash:
        try:
            story = MStory.objects.get(story_hash=existing_briefing.summary_story_hash)
            story.story_content = summary_html
            story.story_date = briefing_date
            story.story_title = title
            story.save()
        except MStory.DoesNotExist:
            existing_briefing = None

    if not existing_briefing or not existing_briefing.summary_story_hash:
        guid = "daily-briefing-%s-%s" % (user.pk, briefing_date.strftime("%Y-%m-%d-%H%M"))
        story = MStory(
            story_feed_id=feed.pk,
            story_date=briefing_date,
            story_title=title,
            story_content=summary_html,
            story_author_name="NewsBlur",
            story_permalink="https://newsblur.com/briefing/%s/%s" % (user.pk, briefing_date.strftime("%Y-%m-%d")),
            story_guid=guid,
        )
        story.save()

    try:
        usersub = UserSubscription.objects.get(user=user, feed=feed)
        usersub.needs_unread_recalc = True
        usersub.save(update_fields=["needs_unread_recalc"])
    except UserSubscription.DoesNotExist:
        pass

    if existing_briefing:
        existing_briefing.curated_story_hashes = curated_story_hashes
        existing_briefing.briefing_date = briefing_date
        existing_briefing.generated_at = datetime.datetime.utcnow()
        existing_briefing.status = "complete"
        existing_briefing.save()
        briefing = existing_briefing
    else:
        briefing = MBriefing(
            user_id=user.pk,
            briefing_feed_id=feed.pk,
            summary_story_hash=story.story_hash,
            curated_story_hashes=curated_story_hashes,
            briefing_date=briefing_date,
            period_start=briefing_date - datetime.timedelta(days=1),
            generated_at=datetime.datetime.utcnow(),
            status="complete",
        )
        briefing.save()

    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    r.publish(user.username, "reload:%s" % feed.pk)

    if MUserFeedNotification.feed_has_users(feed.pk) > 0:
        QueueNotifications.delay(feed.pk, 1)

    logging.debug(
        " ---> %s briefing for user %s: %s curated stories"
        % ("Updated" if existing_briefing else "Created", user.pk, len(curated_story_hashes))
    )

    return briefing, story
