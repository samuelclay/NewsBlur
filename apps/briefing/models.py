import datetime
import hashlib
import time

import mongoengine as mongo
import redis
from django.conf import settings
from django.contrib.auth.models import User

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


class MBriefingPreferences(mongo.Document):
    """Per-user briefing configuration stored in MongoDB."""

    user_id = mongo.IntField(unique=True)
    frequency = mongo.StringField(choices=["daily", "twice_daily", "weekly"], default="daily")
    preferred_time = mongo.StringField(default=None)  # "HH:MM" in user's timezone, null = auto-detect
    enabled = mongo.BooleanField(default=True)
    briefing_feed_id = mongo.IntField(default=None)

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
            prefs = cls(user_id=user_id)
            prefs.save()
            return prefs


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

    # apps/briefing/models.py: Ensure user is subscribed (for unread counts)
    try:
        usersub = UserSubscription.objects.get(user=user, feed=feed)
    except UserSubscription.DoesNotExist:
        usersub = UserSubscription.objects.create(user=user, feed=feed)
        logging.debug(" ---> Created briefing subscription for user %s" % user.pk)

    # apps/briefing/models.py: Cache the feed_id in preferences
    prefs = MBriefingPreferences.get_or_create(user.pk)
    if prefs.briefing_feed_id != feed.pk:
        prefs.briefing_feed_id = feed.pk
        prefs.save()

    return feed


def create_briefing_story(feed, user, summary_html, briefing_date, curated_story_hashes):
    """
    Create an MStory in the briefing feed with the AI summary, and an MBriefing record
    linking the summary to the curated stories.

    Returns (MBriefing, MStory) tuple.
    """
    from apps.notifications.models import MUserFeedNotification
    from apps.notifications.tasks import QueueNotifications
    from apps.reader.models import UserSubscription

    guid = "daily-briefing-%s-%s" % (user.pk, briefing_date.strftime("%Y-%m-%d-%H%M"))
    story_hash = MStory.ensure_story_hash(guid, feed.pk)

    try:
        story = MStory.objects.get(story_hash=story_hash)
    except MStory.DoesNotExist:
        story = MStory(
            story_feed_id=feed.pk,
            story_date=briefing_date,
            story_title="Daily Briefing — %s" % briefing_date.strftime("%B %d, %Y"),
            story_content=summary_html,
            story_author_name="NewsBlur",
            story_permalink="https://newsblur.com/briefing/%s/%s" % (user.pk, briefing_date.strftime("%Y-%m-%d")),
            story_guid=guid,
        )
        story.save()

    # apps/briefing/models.py: Update unread counts
    try:
        usersub = UserSubscription.objects.get(user=user, feed=feed)
        usersub.needs_unread_recalc = True
        usersub.save(update_fields=["needs_unread_recalc"])
    except UserSubscription.DoesNotExist:
        pass

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

    # apps/briefing/models.py: Notify via Redis pubsub for real-time update
    r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
    r.publish(user.username, "reload:%s" % feed.pk)

    # apps/briefing/models.py: Trigger push notifications if configured
    if MUserFeedNotification.feed_has_users(feed.pk) > 0:
        QueueNotifications.delay(feed.pk, 1)

    logging.debug(
        " ---> Created briefing for user %s: %s curated stories"
        % (user.pk, len(curated_story_hashes))
    )

    return briefing, story
