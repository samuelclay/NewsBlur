"""Recommendation models: feed recommendations with user feedback and approval workflow."""

import datetime
import os
import tempfile
from collections import defaultdict

import mongoengine as mongo
from django.contrib.auth.models import User
from django.core.paginator import Paginator
from django.db import models
from django.db.models.signals import post_delete
from django.dispatch import receiver

from apps.reader.models import UserSubscription, UserSubscriptionFolders
from apps.rss_feeds.models import Feed
from utils import json_functions as json
from utils.story_functions import strip_tags


class MRecommendationFeedback(mongo.Document):
    user_id = mongo.IntField(required=True)
    story_hash = mongo.StringField(required=True)
    value = mongo.IntField(required=True, choices=(-1, 0, 1))
    surface = mongo.StringField(required=True, choices=("good_reads", "discovery"))
    story_feed_id = mongo.IntField(required=True)
    story_title = mongo.StringField()
    story_permalink = mongo.StringField()
    story_author = mongo.StringField()
    story_tags = mongo.ListField(mongo.StringField())
    story_excerpt = mongo.StringField()
    created_date = mongo.DateTimeField()
    updated_date = mongo.DateTimeField()

    meta = {
        "collection": "recommendation_feedback",
        "indexes": [
            {"fields": ["user_id", "story_hash"], "unique": True},
            ("user_id", "-updated_date"),
        ],
        "allow_inheritance": False,
    }

    @classmethod
    def record(cls, user_id, story, value, surface):
        if value not in (-1, 0, 1) or surface not in ("good_reads", "discovery"):
            raise ValueError("Invalid recommendation feedback")

        now = datetime.datetime.utcnow()
        # recommendations/models.py: Preserve training context when the RSS story is later trimmed.
        snapshot = dict(
            story_feed_id=story.story_feed_id,
            story_title=story.story_title or "",
            story_permalink=story.story_permalink or "",
            story_author=story.story_author_name or "",
            story_tags=story.story_tags or [],
            story_excerpt=strip_tags(story.original_text_str or "")[:6000],
        )
        feedback = cls.objects(user_id=user_id, story_hash=story.story_hash).modify(
            upsert=True,
            new=True,
            set__value=value,
            set__surface=surface,
            set__updated_date=now,
            set_on_insert__created_date=now,
            **{"set__%s" % field: content for field, content in snapshot.items()},
        )
        return feedback.value

    @classmethod
    def for_stories(cls, user_id, story_hashes):
        if not user_id or not story_hashes:
            return {}
        return {
            feedback.story_hash: feedback.value
            for feedback in cls.objects(user_id=user_id, story_hash__in=story_hashes).only(
                "story_hash", "value"
            )
        }


class MDiscoveryPreview(mongo.Document):
    """models.py: Persist the weekly allowance independently of evictable ranking caches."""

    user_id = mongo.IntField(required=True)
    week_start = mongo.DateTimeField(required=True)
    story_hashes = mongo.ListField(mongo.StringField(), max_length=3)
    generation = mongo.StringField(required=True)
    expires_date = mongo.DateTimeField(required=True)

    meta = {
        "collection": "discovery_preview",
        "indexes": [
            {"fields": ["user_id", "week_start"], "unique": True},
            {"fields": ["expires_date"], "expireAfterSeconds": 0},
        ],
        "allow_inheritance": False,
    }


class MDiscoveryTaste(mongo.Document):
    user_id = mongo.IntField(required=True, unique=True)
    revision = mongo.IntField(default=0)
    fingerprint = mongo.StringField(default="")
    rules = mongo.ListField(mongo.DictField())
    updated_date = mongo.DateTimeField()
    refresh_token = mongo.StringField(default="")
    refresh_until = mongo.DateTimeField(default=datetime.datetime.min)
    impact = mongo.DictField()
    meta = {"collection": "discovery_taste", "allow_inheritance": False}


class MDiscoveryModelBudget(mongo.Document):
    name = mongo.StringField(primary_key=True)
    committed = mongo.FloatField(default=0)
    calls = mongo.IntField(default=0)
    meta = {"collection": "discovery_model_budget", "allow_inheritance": False}


@receiver(post_delete, sender=User)
def delete_recommendation_feedback(sender, instance, **kwargs):
    MRecommendationFeedback.objects(user_id=instance.pk).delete()
    MDiscoveryPreview.objects(user_id=instance.pk).delete()
    MDiscoveryTaste.objects(user_id=instance.pk).delete()


class RecommendedFeed(models.Model):
    feed = models.ForeignKey(Feed, related_name="recommendations", on_delete=models.CASCADE)
    user = models.ForeignKey(User, related_name="recommendations", on_delete=models.CASCADE)
    description = models.TextField(null=True, blank=True)
    is_public = models.BooleanField(default=False)
    created_date = models.DateField(auto_now_add=True)
    approved_date = models.DateField(null=True)
    declined_date = models.DateField(null=True)
    twitter = models.CharField(max_length=50, null=True, blank=True)

    def __str__(self):
        return "%s (%s)" % (self.feed, self.approved_date or self.created_date)

    class Meta:
        ordering = ["-approved_date", "-created_date"]


class RecommendedFeedUserFeedback(models.Model):
    recommendation = models.ForeignKey(RecommendedFeed, related_name="feedback", on_delete=models.CASCADE)
    user = models.ForeignKey(User, related_name="feed_feedback", on_delete=models.CASCADE)
    score = models.IntegerField(default=0)
    created_date = models.DateField(auto_now_add=True)


class MFeedFolder(mongo.Document):
    feed_id = mongo.IntField()
    folder = mongo.StringField()
    count = mongo.IntField()

    meta = {
        "collection": "feed_folders",
        "indexes": ["feed_id", "folder"],
        "allow_inheritance": False,
    }

    def __str__(self):
        feed = Feed.get_by_id(self.feed_id)
        return "%s - %s (%s)" % (feed, self.folder, self.count)

    @classmethod
    def count_feed(cls, feed_id):
        feed = Feed.get_by_id(feed_id)
        print(feed)
        found_folders = defaultdict(int)
        user_ids = [sub["user_id"] for sub in UserSubscription.objects.filter(feed=feed).values("user_id")]
        usf = UserSubscriptionFolders.objects.filter(user_id__in=user_ids)
        for sub in usf:
            user_sub_folders = json.decode(sub.folders)
            folder_title = cls.feed_folder_parent(user_sub_folders, feed.pk)
            if not folder_title:
                continue
            found_folders[folder_title.lower()] += 1
            # print "%-20s - %s" % (folder_title if folder_title != '' else '[Top]', sub.user_id)
        print(sorted(list(found_folders.items()), key=lambda f: f[1], reverse=True))

    @classmethod
    def feed_folder_parent(cls, folders, feed_id, folder_title=""):
        for item in folders:
            if isinstance(item, int) and item == feed_id:
                return folder_title
            elif isinstance(item, dict):
                for f_k, f_v in list(item.items()):
                    sub_folder_title = cls.feed_folder_parent(f_v, feed_id, f_k)
                    if sub_folder_title:
                        return sub_folder_title
