import datetime
import re
import time
from operator import itemgetter
from pprint import pprint

import celery
import mongoengine as mongo
import pymongo
import redis
from django.conf import settings
from django.contrib.auth.models import User
from django.core.cache import cache
from django.db import IntegrityError, models
from django.db.models import Count, Q
from django.template.defaultfilters import slugify
from mongoengine.queryset import NotUniqueError, OperationError

from apps.analyzer.models import (
    MClassifierAuthor,
    MClassifierFeed,
    MClassifierTag,
    MClassifierTitle,
    apply_classifier_authors,
    apply_classifier_feeds,
    apply_classifier_tags,
    apply_classifier_titles,
)
from apps.analyzer.tfidf import tfidf
from apps.reader.managers import UserSubscriptionManager
from apps.rss_feeds.models import DuplicateFeed, Feed, MStory
from apps.rss_feeds.tasks import NewFeeds
from utils import json_functions as json
from utils import log as logging
from utils.feed_functions import add_object_to_folder, chunks


def unread_cutoff_default():
    return datetime.datetime.utcnow() - datetime.timedelta(days=settings.DAYS_OF_UNREAD)


class UserSubscription(models.Model):
    """
    A feed which a user has subscribed to. Carries all of the cached information
    about the subscription, including unread counts of the three primary scores.

    Also has a dirty flag (needs_unread_recalc) which means that the unread counts
    are not accurate and need to be calculated with `self.calculate_feed_scores()`.
    """

    user = models.ForeignKey(User, related_name="subscriptions", on_delete=models.CASCADE)
    feed = models.ForeignKey(Feed, related_name="subscribers", on_delete=models.CASCADE)
    user_title = models.CharField(max_length=255, null=True, blank=True)
    active = models.BooleanField(default=False)
    last_read_date = models.DateTimeField(default=unread_cutoff_default)
    mark_read_date = models.DateTimeField(default=unread_cutoff_default)
    unread_count_neutral = models.IntegerField(default=0)
    unread_count_positive = models.IntegerField(default=0)
    unread_count_negative = models.IntegerField(default=0)
    unread_count_updated = models.DateTimeField(default=datetime.datetime.now)
    oldest_unread_story_date = models.DateTimeField(default=datetime.datetime.now)
    needs_unread_recalc = models.BooleanField(default=False)
    feed_opens = models.IntegerField(default=0)
    is_trained = models.BooleanField(default=False)

    objects = UserSubscriptionManager()

    def __str__(self):
        return "[%s (%s): %s (%s)] " % (self.user.username, self.user.pk, self.feed.feed_title, self.feed.pk)

    class Meta:
        unique_together = ("user", "feed")

    def canonical(self, full=False, include_favicon=True, classifiers=None):
        feed = self.feed.canonical(full=full, include_favicon=include_favicon)
        feed["feed_title"] = self.user_title or feed["feed_title"]
        feed["ps"] = self.unread_count_positive
        feed["nt"] = self.unread_count_neutral
        feed["ng"] = self.unread_count_negative
        feed["active"] = self.active
        feed["feed_opens"] = self.feed_opens
        feed["subscribed"] = True
        if classifiers:
            feed["classifiers"] = classifiers

        return feed

    def save(self, *args, **kwargs):
        user_title_max = self._meta.get_field("user_title").max_length
        if self.user_title and len(self.user_title) > user_title_max:
            self.user_title = self.user_title[:user_title_max]
        try:
            super(UserSubscription, self).save(*args, **kwargs)
        except IntegrityError:
            duplicate_feeds = DuplicateFeed.objects.filter(duplicate_feed_id=self.feed_id)
            for duplicate_feed in duplicate_feeds:
                already_subscribed = UserSubscription.objects.filter(user=self.user, feed=duplicate_feed.feed)
                if not already_subscribed:
                    self.feed = duplicate_feed.feed
                    super(UserSubscription, self).save(*args, **kwargs)
                    break
            else:
                if self and self.id:
                    self.delete()

    @classmethod
    def subs_for_feeds(cls, user_id, feed_ids=None, read_filter="unread"):
        usersubs = cls.objects
        if read_filter == "unread":
            usersubs = usersubs.filter(Q(unread_count_neutral__gt=0) | Q(unread_count_positive__gt=0))
        if not feed_ids:
            usersubs = usersubs.filter(user=user_id, active=True).only(
                "feed", "mark_read_date", "is_trained", "needs_unread_recalc"
            )
        else:
            usersubs = usersubs.filter(user=user_id, active=True, feed__in=feed_ids).only(
                "feed", "mark_read_date", "is_trained", "needs_unread_recalc"
            )

        return usersubs

    @classmethod
    def story_hashes(
        cls,
        user_id,
        feed_ids=None,
        usersubs=None,
        read_filter="unread",
        order="newest",
        include_timestamps=False,
        group_by_feed=False,
        cutoff_date=None,
        across_all_feeds=True,
        store_stories_key=None,
        offset=0,
        limit=500,
    ):
        r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
        pipeline = r.pipeline()
        user = User.objects.get(pk=user_id)
        story_hashes = {} if group_by_feed else []
        is_archive = user.profile.is_archive

        if not feed_ids and not across_all_feeds:
            return story_hashes

        if not usersubs:
            usersubs = cls.subs_for_feeds(user_id, feed_ids=feed_ids, read_filter=read_filter)
            if not usersubs:
                usersubs = cls.subs_for_feeds(user_id, feed_ids=feed_ids, read_filter="all")
            feed_ids = [sub.feed_id for sub in usersubs]
            if not feed_ids:
                return story_hashes

        current_time = int(time.time() + 60 * 60 * 24)
        if not cutoff_date:
            cutoff_date = user.profile.unread_cutoff
        feed_counter = 0
        unread_ranked_stories_keys = []

        read_dates = dict()
        needs_unread_recalc = dict()
        manual_unread_pipeline = r.pipeline()
        manual_unread_feed_oldest_date = dict()
        oldest_manual_unread = None
        # usersub_count = len(usersubs)
        for us in usersubs:
            read_dates[us.feed_id] = int(max(us.mark_read_date, cutoff_date).strftime("%s"))
            if read_filter == "unread":
                needs_unread_recalc[us.feed_id] = us.needs_unread_recalc  # or usersub_count == 1
                user_manual_unread_stories_feed_key = f"uU:{user_id}:{us.feed_id}"
                manual_unread_pipeline.exists(user_manual_unread_stories_feed_key)
                user_unread_ranked_stories_key = f"zU:{user_id}:{us.feed_id}"
                manual_unread_pipeline.exists(user_unread_ranked_stories_key)
        if read_filter == "unread":
            results = manual_unread_pipeline.execute()
            for i, us in enumerate(usersubs):
                if results[i * 2]:  # user_manual_unread_stories_feed_key
                    user_manual_unread_stories_feed_key = f"uU:{user_id}:{us.feed_id}"
                    oldest_manual_unread = r.zrevrange(
                        user_manual_unread_stories_feed_key, -1, -1, withscores=True
                    )
                    manual_unread_feed_oldest_date[us.feed_id] = int(oldest_manual_unread[0][1])
                if read_filter == "unread" and not results[i * 2 + 1]:  # user_unread_ranked_stories_key
                    needs_unread_recalc[us.feed_id] = True

        for feed_id_group in chunks(feed_ids, 500):
            pipeline = r.pipeline()
            for feed_id in feed_id_group:
                stories_key = "F:%s" % feed_id
                sorted_stories_key = "zF:%s" % feed_id
                read_stories_key = "RS:%s:%s" % (user_id, feed_id)
                unread_stories_key = "U:%s:%s" % (user_id, feed_id)
                unread_ranked_stories_key = "zU:%s:%s" % (user_id, feed_id)
                user_manual_unread_stories_feed_key = f"uU:{user_id}:{feed_id}"

                max_score = current_time
                if read_filter == "unread":
                    min_score = read_dates[feed_id]
                    # if needs_unread_recalc[feed_id]:
                    #     pipeline.sdiffstore(unread_stories_key, stories_key, read_stories_key)
                    #     # pipeline.expire(unread_stories_key, unread_cutoff_diff.days*24*60*60)
                    #     pipeline.expire(unread_stories_key, 1*60*60) # 1 hour
                else:
                    min_score = 0

                if order == "oldest":
                    byscorefunc = pipeline.zrangebyscore
                else:
                    byscorefunc = pipeline.zrevrangebyscore
                    min_score, max_score = max_score, min_score

                ranked_stories_key = unread_ranked_stories_key
                if read_filter == "unread":
                    if needs_unread_recalc[feed_id]:
                        pipeline.zdiffstore(unread_ranked_stories_key, [sorted_stories_key, read_stories_key])
                        # pipeline.expire(unread_ranked_stories_key, unread_cutoff_diff.days*24*60*60)
                        pipeline.expire(unread_ranked_stories_key, 1 * 60 * 60)  # 1 hours
                        if order == "oldest":
                            pipeline.zremrangebyscore(ranked_stories_key, 0, min_score - 1)
                            pipeline.zremrangebyscore(ranked_stories_key, max_score + 1, 2 * max_score)
                        else:
                            pipeline.zremrangebyscore(ranked_stories_key, 0, max_score - 1)
                            pipeline.zremrangebyscore(ranked_stories_key, min_score + 1, 2 * min_score)
                else:
                    ranked_stories_key = sorted_stories_key

                # If archive premium user has manually marked an older story as unread
                if is_archive and feed_id in manual_unread_feed_oldest_date and read_filter == "unread":
                    if order == "oldest":
                        min_score = manual_unread_feed_oldest_date[feed_id]
                    else:
                        max_score = manual_unread_feed_oldest_date[feed_id]

                    pipeline.zunionstore(
                        unread_ranked_stories_key,
                        [unread_ranked_stories_key, user_manual_unread_stories_feed_key],
                        aggregate="MAX",
                    )

                if settings.DEBUG and False:
                    debug_stories = r.zrevrange(unread_ranked_stories_key, 0, -1, withscores=True)
                    print(
                        (
                            " ---> Story hashes (%s/%s - %s/%s) %s stories: %s"
                            % (
                                min_score,
                                datetime.datetime.fromtimestamp(min_score).strftime("%Y-%m-%d %T"),
                                max_score,
                                datetime.datetime.fromtimestamp(max_score).strftime("%Y-%m-%d %T"),
                                len(debug_stories),
                                debug_stories,
                            )
                        )
                    )

                if not store_stories_key:
                    byscorefunc(
                        ranked_stories_key,
                        min_score,
                        max_score,
                        withscores=include_timestamps,
                        start=offset,
                        num=limit,
                    )
                unread_ranked_stories_keys.append(ranked_stories_key)

            results = pipeline.execute()

            if not store_stories_key:
                for hashes in results:
                    if not isinstance(hashes, list):
                        continue
                    if group_by_feed:
                        story_hashes[feed_ids[feed_counter]] = hashes
                        feed_counter += 1
                    else:
                        story_hashes.extend(hashes)

        if store_stories_key:
            chunk_count = 0
            chunk_size = 1000
            if len(unread_ranked_stories_keys) < chunk_size:
                r.zunionstore(store_stories_key, unread_ranked_stories_keys)
            else:
                pipeline = r.pipeline()
                for unread_ranked_stories_keys_group in chunks(unread_ranked_stories_keys, chunk_size):
                    pipeline.zunionstore(
                        f"{store_stories_key}-chunk{chunk_count}",
                        unread_ranked_stories_keys_group,
                        aggregate="MAX",
                    )
                    chunk_count += 1
                pipeline.execute()
                r.zunionstore(
                    store_stories_key,
                    [f"{store_stories_key}-chunk{i}" for i in range(chunk_count)],
                    aggregate="MAX",
                )
                pipeline = r.pipeline()
                for i in range(chunk_count):
                    pipeline.delete(f"{store_stories_key}-chunk{i}")
                pipeline.execute()

        if not store_stories_key:
            return story_hashes

    def get_stories(self, offset=0, limit=6, order="newest", read_filter="all", cutoff_date=None):
        r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
        unread_ranked_stories_key = "zU:%s:%s" % (self.user_id, self.feed_id)

        if offset and r.exists(unread_ranked_stories_key):
            byscorefunc = r.zrevrange
            if order == "oldest":
                byscorefunc = r.zrange
            story_hashes = byscorefunc(unread_ranked_stories_key, start=offset, end=offset + limit)[:limit]
        else:
            story_hashes = UserSubscription.story_hashes(
                self.user.pk,
                feed_ids=[self.feed.pk],
                order=order,
                read_filter=read_filter,
                offset=offset,
                limit=limit,
                cutoff_date=cutoff_date,
            )

        story_date_order = "%sstory_date" % ("" if order == "oldest" else "-")
        mstories = MStory.objects(story_hash__in=story_hashes).order_by(story_date_order)
        stories = Feed.format_stories(mstories)
        return stories

    @classmethod
    def feed_stories(
        cls,
        user_id,
        feed_ids=None,
        offset=0,
        limit=6,
        order="newest",
        read_filter="all",
        usersubs=None,
        cutoff_date=None,
        all_feed_ids=None,
        cache_prefix="",
    ):
        rt = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
        across_all_feeds = False

        if order == "oldest":
            range_func = rt.zrange
        else:
            range_func = rt.zrevrange

        if feed_ids is None:
            across_all_feeds = True
            feed_ids = []
        if not all_feed_ids:
            all_feed_ids = [f for f in feed_ids]

        # feeds_string = ""
        feeds_string = ",".join(str(f) for f in sorted(all_feed_ids))[:30]
        ranked_stories_keys = "%szU:%s:feeds:%s" % (cache_prefix, user_id, feeds_string)
        unread_ranked_stories_keys = "%szhU:%s:feeds:%s" % (cache_prefix, user_id, feeds_string)
        stories_cached = rt.exists(ranked_stories_keys)
        unreads_cached = True if read_filter == "unread" else rt.exists(unread_ranked_stories_keys)
        if offset and stories_cached:
            story_hashes = range_func(ranked_stories_keys, offset, offset + limit)
            if read_filter == "unread":
                unread_story_hashes = story_hashes
            elif unreads_cached:
                unread_story_hashes = range_func(unread_ranked_stories_keys, 0, offset + limit)
            else:
                unread_story_hashes = []
            return story_hashes, unread_story_hashes
        else:
            rt.delete(ranked_stories_keys)
            rt.delete(unread_ranked_stories_keys)

        cls.story_hashes(
            user_id,
            feed_ids=feed_ids,
            read_filter=read_filter,
            order=order,
            include_timestamps=False,
            usersubs=usersubs,
            cutoff_date=cutoff_date,
            across_all_feeds=across_all_feeds,
            store_stories_key=ranked_stories_keys,
        )
        story_hashes = range_func(ranked_stories_keys, offset, limit)

        if read_filter == "unread":
            unread_feed_story_hashes = story_hashes
            rt.zunionstore(unread_ranked_stories_keys, [ranked_stories_keys])
        else:
            cls.story_hashes(
                user_id,
                feed_ids=feed_ids,
                read_filter="unread",
                order=order,
                include_timestamps=True,
                cutoff_date=cutoff_date,
                store_stories_key=unread_ranked_stories_keys,
            )
            unread_feed_story_hashes = range_func(unread_ranked_stories_keys, offset, limit)

        rt.expire(ranked_stories_keys, 60 * 60)
        rt.expire(unread_ranked_stories_keys, 60 * 60)

        return story_hashes, unread_feed_story_hashes

    def oldest_manual_unread_story_date(self, r=None):
        if not r:
            r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)

        user_manual_unread_stories_feed_key = f"uU:{self.user_id}:{self.feed_id}"
        oldest_manual_unread = r.zrevrange(user_manual_unread_stories_feed_key, -1, -1, withscores=True)

        return oldest_manual_unread

    @classmethod
    def truncate_river(cls, user_id, feed_ids, read_filter, cache_prefix=""):
        rt = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_TEMP_POOL)

        feeds_string = ",".join(str(f) for f in sorted(feed_ids))[:30]
        ranked_stories_keys = "%szU:%s:feeds:%s" % (cache_prefix, user_id, feeds_string)
        unread_ranked_stories_keys = "%szhU:%s:feeds:%s" % (cache_prefix, user_id, feeds_string)
        stories_cached = rt.exists(ranked_stories_keys)
        unreads_cached = rt.exists(unread_ranked_stories_keys)
        truncated = 0
        if stories_cached:
            truncated += rt.zcard(ranked_stories_keys)
            rt.delete(ranked_stories_keys)
        # else:
        #     logging.debug(" ***> ~FRNo stories cached, can't truncate: %s / %s" % (User.objects.get(pk=user_id), feed_ids))

        if unreads_cached:
            truncated += rt.zcard(unread_ranked_stories_keys)
            rt.delete(unread_ranked_stories_keys)
        # else:
        #     logging.debug(" ***> ~FRNo unread stories cached, can't truncate: %s / %s" % (User.objects.get(pk=user_id), feed_ids))

        return truncated

    @classmethod
    def add_subscription(
        cls, user, feed_address, folder=None, bookmarklet=False, auto_active=True, skip_fetch=False
    ):
        feed = None
        us = None

        logging.user(
            user,
            "~FRAdding URL: ~SB%s (in %s) %s"
            % (feed_address, folder, "~FCAUTO-ADD" if not auto_active else ""),
        )

        feed = Feed.get_feed_from_url(feed_address, user=user)

        if not feed:
            code = -1
            if bookmarklet:
                message = "This site does not have an RSS feed. Nothing is linked to from this page."
            else:
                message = "This address does not point to an RSS feed or a website with an RSS feed."
        else:
            allow_skip_resync = False
            if user.profile.is_archive and feed.active_premium_subscribers != 0:
                # Skip resync if there are already active archive subscribers
                allow_skip_resync = True

            us, subscription_created = cls.objects.get_or_create(
                feed=feed,
                user=user,
                defaults={
                    "needs_unread_recalc": True,
                    "active": auto_active,
                },
            )
            code = 1
            message = ""

        if us:
            user_sub_folders_object, created = UserSubscriptionFolders.objects.get_or_create(
                user=user, defaults={"folders": "[]"}
            )
            if created:
                user_sub_folders = []
            else:
                user_sub_folders = json.decode(user_sub_folders_object.folders)
            user_sub_folders = add_object_to_folder(feed.pk, folder, user_sub_folders)
            user_sub_folders_object.folders = json.encode(user_sub_folders)
            user_sub_folders_object.save()

            if auto_active or user.profile.is_premium:
                us.active = True
                us.save()

            if not skip_fetch and feed.last_update < datetime.datetime.utcnow() - datetime.timedelta(days=1):
                feed = feed.update(verbose=True)

            from apps.social.models import MActivity

            MActivity.new_feed_subscription(user_id=user.pk, feed_id=feed.pk, feed_title=feed.title)

            feed.setup_feed_for_premium_subscribers(allow_skip_resync=allow_skip_resync)
            feed.count_subscribers()

            if feed.archive_count:
                feed.schedule_fetch_archive_feed()

            r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
            r.publish(user.username, "reload:feeds")

        return code, message, us

    @classmethod
    def feeds_with_updated_counts(cls, user, feed_ids=None, check_fetch_status=False, force=False):
        feeds = {}
        silent = not getattr(settings, "TEST_DEBUG", False)

        # Get subscriptions for user
        user_subs = cls.objects.select_related("feed").filter(user=user, active=True)
        feed_ids = [
            f for f in feed_ids if f and not any(f.startswith(prefix) for prefix in ["river", "saved"])
        ]
        if feed_ids:
            user_subs = user_subs.filter(feed__in=feed_ids)

        for i, sub in enumerate(user_subs):
            # Count unreads if subscription is stale.
            if (
                force
                or sub.needs_unread_recalc
                or sub.unread_count_updated < user.profile.unread_cutoff
                or sub.oldest_unread_story_date < user.profile.unread_cutoff
            ):
                sub = sub.calculate_feed_scores(silent=silent, force=force)
            if not sub:
                continue  # TODO: Figure out the correct sub and give it a new feed_id

            feed_id = sub.feed_id
            feeds[feed_id] = {
                "ps": sub.unread_count_positive,
                "nt": sub.unread_count_neutral,
                "ng": sub.unread_count_negative,
                "id": feed_id,
            }
            if not sub.feed.fetched_once or check_fetch_status:
                feeds[feed_id]["fetched_once"] = sub.feed.fetched_once
                feeds[feed_id]["not_yet_fetched"] = not sub.feed.fetched_once  # Legacy. Dammit.
            if sub.feed.favicon_fetching:
                feeds[feed_id]["favicon_fetching"] = True
            if sub.feed.has_feed_exception or sub.feed.has_page_exception:
                feeds[feed_id]["has_exception"] = True
                feeds[feed_id]["exception_type"] = "feed" if sub.feed.has_feed_exception else "page"
                feeds[feed_id]["feed_address"] = sub.feed.feed_address
                feeds[feed_id]["exception_code"] = sub.feed.exception_code

        return feeds

    @classmethod
    def queue_new_feeds(cls, user, new_feeds=None):
        if not isinstance(user, User):
            user = User.objects.get(pk=user)

        if not new_feeds:
            new_feeds = cls.objects.filter(user=user, feed__fetched_once=False, active=True).values("feed_id")
            new_feeds = list(set([f["feed_id"] for f in new_feeds]))

        if not new_feeds:
            return

        logging.user(user, "~BB~FW~SBQueueing NewFeeds: ~FC(%s) %s" % (len(new_feeds), new_feeds))
        size = 4
        for t in (new_feeds[pos : pos + size] for pos in range(0, len(new_feeds), size)):
            NewFeeds.apply_async(args=(t,), queue="new_feeds")

    @classmethod
    def refresh_stale_feeds(cls, user, exclude_new=False):
        if not isinstance(user, User):
            user = User.objects.get(pk=user)

        stale_cutoff = datetime.datetime.now() - datetime.timedelta(days=settings.SUBSCRIBER_EXPIRE)

        # TODO: Refactor below using last_update from REDIS_FEED_UPDATE_POOL
        stale_feeds = UserSubscription.objects.filter(
            user=user, active=True, feed__last_update__lte=stale_cutoff
        )
        if exclude_new:
            stale_feeds = stale_feeds.filter(feed__fetched_once=True)
        all_feeds = UserSubscription.objects.filter(user=user, active=True)

        logging.user(
            user, "~FG~BBRefreshing stale feeds: ~SB%s/%s" % (stale_feeds.count(), all_feeds.count())
        )

        for sub in stale_feeds:
            sub.feed.fetched_once = False
            sub.feed.save()

        if stale_feeds:
            stale_feeds = list(set([f.feed_id for f in stale_feeds]))
            cls.queue_new_feeds(user, new_feeds=stale_feeds)

    @classmethod
    def schedule_fetch_archive_feeds_for_user(cls, user_id):
        from apps.profile.tasks import FetchArchiveFeedsForUser

        FetchArchiveFeedsForUser.apply_async(
            kwargs=dict(user_id=user_id),
            queue="search_indexer",
            time_limit=settings.MAX_SECONDS_COMPLETE_ARCHIVE_FETCH,
        )

    # Should be run as a background task
    @classmethod
    def fetch_archive_feeds_for_user(cls, user_id):
        from apps.profile.tasks import FetchArchiveFeedsChunk, FinishFetchArchiveFeeds

        start_time = time.time()
        user = User.objects.get(pk=user_id)
        r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
        r.publish(user.username, "fetch_archive:start")

        subscriptions = UserSubscription.objects.filter(user=user).only("feed")
        total = subscriptions.count()

        feed_ids = []
        starting_story_count = 0
        for sub in subscriptions:
            try:
                feed_ids.append(sub.feed.pk)
            except Feed.DoesNotExist:
                continue
            starting_story_count += MStory.objects(story_feed_id=sub.feed.pk).count()

        feed_id_chunks = [c for c in chunks(feed_ids, 1)]
        logging.user(
            user,
            "~FCFetching archive stories from ~SB%s feeds~SN in %s chunks..." % (total, len(feed_id_chunks)),
        )

        search_chunks = [
            FetchArchiveFeedsChunk.s(feed_ids=feed_id_chunk, user_id=user_id)
            .set(queue="search_indexer")
            .set(
                time_limit=settings.MAX_SECONDS_ARCHIVE_FETCH_SINGLE_FEED,
                soft_time_limit=settings.MAX_SECONDS_ARCHIVE_FETCH_SINGLE_FEED - 30,
            )
            for feed_id_chunk in feed_id_chunks
        ]
        callback = FinishFetchArchiveFeeds.s(
            user_id=user_id, start_time=start_time, starting_story_count=starting_story_count
        ).set(queue="search_indexer")
        celery.chord(search_chunks)(callback)

    @classmethod
    def fetch_archive_feeds_chunk(cls, feed_ids, user_id=None):
        from apps.rss_feeds.models import Feed

        r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
        if user_id:
            user = User.objects.get(pk=user_id)
            logging.user(user, "~FCFetching archive stories from %s feeds..." % len(feed_ids))
        else:
            logging.debug("~FCFetching archive stories from %s feeds..." % len(feed_ids))

        for feed_id in feed_ids:
            feed = Feed.get_by_id(feed_id)
            if not feed:
                continue

            feed.fill_out_archive_stories()

        if user_id:
            r.publish(user.username, "fetch_archive:feeds:%s" % ",".join([str(f) for f in feed_ids]))

    @classmethod
    def finish_fetch_archive_feeds(cls, user_id, start_time, starting_story_count):
        r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
        user = User.objects.get(pk=user_id)
        subscriptions = UserSubscription.objects.filter(user=user).only("feed")
        total = subscriptions.count()
        duration = time.time() - start_time

        ending_story_count = 0
        pre_archive_count = 0
        for sub in subscriptions:
            try:
                ending_story_count += MStory.objects(story_feed_id=sub.feed.pk).count()
                pre_archive_count += Feed.get_by_id(sub.feed.pk).number_of_stories_to_store(pre_archive=True)
            except Feed.DoesNotExist:
                continue

        new_story_count = ending_story_count - starting_story_count
        logging.user(
            user,
            f"~FCFinished archive feed fetches for ~SB~FG{subscriptions.count()} feeds~FC~SN: ~FG~SB{new_story_count:,} new~SB~FC, ~FG{ending_story_count:,} total (pre-archive: {pre_archive_count:,} stories)",
        )

        logging.user(
            user,
            "~FCFetched archive stories from ~SB%s feeds~SN in ~FM~SB%s~FC~SN sec."
            % (total, round(duration, 2)),
        )
        r.publish(user.username, "fetch_archive:done")

        return ending_story_count, min(pre_archive_count, starting_story_count)

    @classmethod
    def identify_deleted_feed_users(cls, old_feed_id):
        users = UserSubscriptionFolders.objects.filter(folders__contains=old_feed_id).only("user")
        user_ids = [usf.user_id for usf in users]
        f = open("utils/backups/users.txt", "w")
        f.write("\n".join([str(u) for u in user_ids]))

        return user_ids

    @classmethod
    def recreate_deleted_feed(cls, new_feed_id, old_feed_id=None, skip=0):
        user_ids = sorted([int(u) for u in open("utils/backups/users.txt").read().split("\n") if u])

        count = len(user_ids)

        for i, user_id in enumerate(user_ids):
            if i < skip:
                continue
            if i % 1000 == 0:
                print("\n\n ------------------------------------------------")
                print("\n ---> %s/%s (%s%%)" % (i, count, round(float(i) / count)))
                print("\n ------------------------------------------------\n")
            try:
                user = User.objects.get(pk=user_id)
            except User.DoesNotExist:
                print(" ***> %s has no account" % user_id)
                continue
            us, created = UserSubscription.objects.get_or_create(
                user_id=user_id,
                feed_id=new_feed_id,
                defaults={"needs_unread_recalc": True, "active": True, "is_trained": True},
            )
            if not created:
                print(" ***> %s already subscribed" % user.username)
            try:
                usf = UserSubscriptionFolders.objects.get(user_id=user_id)
                usf.add_missing_feeds()
            except UserSubscriptionFolders.DoesNotExist:
                print(" ***> %s has no USF" % user.username)

            # Move classifiers
            if old_feed_id:
                classifier_count = 0
                for classifier_type in (MClassifierAuthor, MClassifierFeed, MClassifierTag, MClassifierTitle):
                    classifiers = classifier_type.objects.filter(user_id=user_id, feed_id=old_feed_id)
                    classifier_count += classifiers.count()
                    for classifier in classifiers:
                        classifier.feed_id = new_feed_id
                        try:
                            classifier.save()
                        except NotUniqueError:
                            continue
                    if classifier_count:
                        print(" Moved %s classifiers for %s" % (classifier_count, user.username))

    def trim_read_stories(self, r=None):
        if not r:
            r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)

        read_stories_key = "RS:%s:%s" % (self.user_id, self.feed_id)
        stale_story_hashes = r.sdiff(read_stories_key, "F:%s" % self.feed_id)
        if not stale_story_hashes:
            return

        logging.user(
            self.user,
            "~FBTrimming ~FR%s~FB read stories (~SB%s~SN)..." % (len(stale_story_hashes), self.feed_id),
        )
        r.srem(read_stories_key, *stale_story_hashes)
        r.srem("RS:%s" % self.feed_id, *stale_story_hashes)

    @classmethod
    def trim_user_read_stories(self, user_id):
        user = User.objects.get(pk=user_id)
        r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
        subs = UserSubscription.objects.filter(user_id=user_id).only("feed")
        if not subs:
            return

        key = "RS:%s" % user_id
        feeds = [f.feed_id for f in subs]
        old_rs = r.smembers(key)
        old_count = len(old_rs)
        if not old_count:
            logging.user(user, "~FBTrimming all read stories, ~SBnone found~SN.")
            return

        # r.sunionstore("%s:backup" % key, key)
        # r.expire("%s:backup" % key, 60*60*24)
        r.sunionstore(key, *["%s:%s" % (key, f) for f in feeds])
        new_rs = r.smembers(key)

        missing_rs = []
        missing_count = 0
        feed_re = re.compile(r"(\d+):.*?")
        for i, rs in enumerate(old_rs):
            if i and i % 1000 == 0:
                if missing_rs:
                    r.sadd(key, *missing_rs)
                missing_count += len(missing_rs)
                missing_rs = []
            found = feed_re.search(rs)
            if not found:
                print(" ---> Not found: %s" % rs)
                continue
            rs_feed_id = found.groups()[0]
            if int(rs_feed_id) not in feeds:
                missing_rs.append(rs)

        if missing_rs:
            r.sadd(key, *missing_rs)
        missing_count += len(missing_rs)
        new_count = len(new_rs)
        new_total = new_count + missing_count
        logging.user(
            user,
            "~FBTrimming ~FR%s~FB/%s (~SB%s sub'ed ~SN+ ~SB%s unsub'ed~SN saved)"
            % (old_count - new_total, old_count, new_count, missing_count),
        )

    def mark_feed_read(self, cutoff_date=None):
        if (
            self.unread_count_negative == 0
            and self.unread_count_neutral == 0
            and self.unread_count_positive == 0
            and not self.needs_unread_recalc
        ):
            return

        recount = True
        # Use the latest story to get last read time.
        if cutoff_date:
            cutoff_date = cutoff_date + datetime.timedelta(seconds=1)
        else:
            now = datetime.datetime.now()
            latest_story = (
                MStory.objects(story_feed_id=self.feed.pk, story_date__lte=now)
                .order_by("-story_date")
                .only("story_date")
                .limit(1)
            )
            if latest_story and len(latest_story) >= 1:
                cutoff_date = latest_story[0]["story_date"] + datetime.timedelta(seconds=1)
            else:
                cutoff_date = datetime.datetime.utcnow()
                recount = False

        if cutoff_date > self.mark_read_date or cutoff_date > self.oldest_unread_story_date:
            self.last_read_date = cutoff_date
            self.mark_read_date = cutoff_date
            self.oldest_unread_story_date = cutoff_date
        else:
            logging.user(
                self.user,
                "Not marking %s as read: %s > %s/%s"
                % (self, cutoff_date, self.mark_read_date, self.oldest_unread_story_date),
            )

        if not recount:
            self.unread_count_negative = 0
            self.unread_count_positive = 0
            self.unread_count_neutral = 0
            self.unread_count_updated = datetime.datetime.utcnow()
            self.needs_unread_recalc = False
        else:
            self.needs_unread_recalc = True

        self.save()

        return True

    def mark_newer_stories_read(self, cutoff_date):
        if (
            self.unread_count_negative == 0
            and self.unread_count_neutral == 0
            and self.unread_count_positive == 0
            and not self.needs_unread_recalc
        ):
            return

        cutoff_date = cutoff_date - datetime.timedelta(seconds=1)
        story_hashes = UserSubscription.story_hashes(
            self.user.pk,
            feed_ids=[self.feed.pk],
            order="newest",
            read_filter="unread",
            cutoff_date=cutoff_date,
        )
        data = self.mark_story_ids_as_read(story_hashes, aggregated=True)
        return data

    def mark_story_ids_as_read(self, story_hashes, request=None, aggregated=False):
        data = dict(code=0, payload=story_hashes)
        r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)

        if not request:
            request = self.user

        if not self.needs_unread_recalc:
            self.needs_unread_recalc = True
            self.save(update_fields=["needs_unread_recalc"])

        if len(story_hashes) > 1:
            logging.user(request, "~FYRead %s stories in feed: %s" % (len(story_hashes), self.feed))
        else:
            logging.user(request, "~FYRead story (%s) in feed: %s" % (story_hashes, self.feed))
            RUserStory.aggregate_mark_read(self.feed_id)

        for story_hash in set(story_hashes):
            # logging.user(request, "~FYRead story: %s" % (story_hash))
            RUserStory.mark_read(self.user_id, self.feed_id, story_hash, aggregated=aggregated)
            r.publish(self.user.username, "story:read:%s" % story_hash)

            if self.user.profile.is_archive:
                RUserUnreadStory.mark_read(self.user_id, story_hash)

        r.publish(self.user.username, "feed:%s" % self.feed_id)

        self.last_read_date = datetime.datetime.now()
        self.save(update_fields=["last_read_date"])

        return data

    def invert_read_stories_after_unread_story(self, story, request=None):
        data = dict(code=1)
        unread_cutoff = self.user.profile.unread_cutoff
        if self.mark_read_date > unread_cutoff:
            unread_cutoff = self.mark_read_date
        if story.story_date > unread_cutoff:
            return data

        # Check if user is archive and story is outside unread cutoff
        if self.user.profile.is_archive and story.story_date < self.user.profile.unread_cutoff:
            RUserUnreadStory.mark_unread(
                user_id=self.user_id,
                story_hash=story.story_hash,
                story_date=story.story_date,
            )
            data["story_hashes"] = [story.story_hash]
            return data

        # Story is outside the mark as read range, so invert all stories before.
        newer_stories = MStory.objects(
            story_feed_id=story.story_feed_id, story_date__gte=story.story_date, story_date__lte=unread_cutoff
        ).only("story_hash")
        newer_stories = [s.story_hash for s in newer_stories]
        self.mark_read_date = story.story_date - datetime.timedelta(minutes=1)
        self.needs_unread_recalc = True
        self.save()

        # Mark stories as read only after the mark_read_date has been moved, otherwise
        # these would be ignored.
        data = self.mark_story_ids_as_read(newer_stories, request=request, aggregated=True)

        return data

    def calculate_feed_scores(self, silent=False, stories=None, force=False):
        # now = datetime.datetime.strptime("2009-07-06 22:30:03", "%Y-%m-%d %H:%M:%S")
        now = datetime.datetime.now()
        oldest_unread_story_date = now

        if self.user.profile.last_seen_on < self.user.profile.unread_cutoff and not force:
            if not silent and settings.DEBUG:
                logging.info(" ---> [%s] SKIPPING Computing scores: %s (1 week+)" % (self.user, self.feed))
            return self
        ong = self.unread_count_negative
        ont = self.unread_count_neutral
        ops = self.unread_count_positive
        oousd = self.oldest_unread_story_date
        ucu = self.unread_count_updated
        onur = self.needs_unread_recalc
        oit = self.is_trained

        # if not self.feed.fetched_once:
        #     if not silent:
        #         logging.info(' ---> [%s] NOT Computing scores: %s' % (self.user, self.feed))
        #     self.needs_unread_recalc = False
        #     self.save()
        #     return

        feed_scores = dict(negative=0, neutral=0, positive=0)

        # Two weeks in age. If mark_read_date is older, mark old stories as read.
        date_delta = self.user.profile.unread_cutoff
        if date_delta < self.mark_read_date:
            date_delta = self.mark_read_date
        else:
            self.mark_read_date = date_delta

        if self.is_trained:
            if not stories:
                stories = cache.get("S:v3:%s" % self.feed_id)

            unread_story_hashes = self.story_hashes(
                user_id=self.user_id,
                feed_ids=[self.feed_id],
                usersubs=[self],
                read_filter="unread",
                cutoff_date=self.user.profile.unread_cutoff,
            )

            if not stories:
                try:
                    stories_db = MStory.objects(story_hash__in=unread_story_hashes)
                    stories = Feed.format_stories(stories_db, self.feed_id)
                except pymongo.errors.OperationFailure as e:
                    stories_db = MStory.objects(story_hash__in=unread_story_hashes)[:100]
                    stories = Feed.format_stories(stories_db, self.feed_id)
                except pymongo.errors.OperationFailure as e:
                    stories_db = MStory.objects(story_hash__in=unread_story_hashes)[:25]
                    stories = Feed.format_stories(stories_db, self.feed_id)

            unread_stories = []
            for story in stories:
                # if story['story_date'] < date_delta:
                #     continue
                if story["story_hash"] in unread_story_hashes:
                    unread_stories.append(story)
                    if story["story_date"] < oldest_unread_story_date:
                        oldest_unread_story_date = story["story_date"]

            # if not silent:
            #     logging.info(' ---> [%s]    Format stories: %s' % (self.user, datetime.datetime.now() - now))

            classifier_feeds = list(
                MClassifierFeed.objects(user_id=self.user_id, feed_id=self.feed_id, social_user_id=0)
            )
            classifier_authors = list(MClassifierAuthor.objects(user_id=self.user_id, feed_id=self.feed_id))
            classifier_titles = list(MClassifierTitle.objects(user_id=self.user_id, feed_id=self.feed_id))
            classifier_tags = list(MClassifierTag.objects(user_id=self.user_id, feed_id=self.feed_id))

            if (
                not len(classifier_feeds)
                and not len(classifier_authors)
                and not len(classifier_titles)
                and not len(classifier_tags)
            ):
                self.is_trained = False

            # if not silent:
            #     logging.info(' ---> [%s]    Classifiers: %s (%s)' % (self.user, datetime.datetime.now() - now, classifier_feeds.count() + classifier_authors.count() + classifier_tags.count() + classifier_titles.count()))

            scores = {
                "feed": apply_classifier_feeds(classifier_feeds, self.feed),
            }

            for story in unread_stories:
                scores.update(
                    {
                        "author": apply_classifier_authors(classifier_authors, story),
                        "tags": apply_classifier_tags(classifier_tags, story),
                        "title": apply_classifier_titles(classifier_titles, story),
                    }
                )

                max_score = max(scores["author"], scores["tags"], scores["title"])
                min_score = min(scores["author"], scores["tags"], scores["title"])
                if max_score > 0:
                    feed_scores["positive"] += 1
                elif min_score < 0:
                    feed_scores["negative"] += 1
                else:
                    if scores["feed"] > 0:
                        feed_scores["positive"] += 1
                    elif scores["feed"] < 0:
                        feed_scores["negative"] += 1
                    else:
                        feed_scores["neutral"] += 1
        else:
            unread_story_hashes = self.story_hashes(
                user_id=self.user_id,
                feed_ids=[self.feed_id],
                usersubs=[self],
                read_filter="unread",
                include_timestamps=True,
                cutoff_date=date_delta,
            )

            feed_scores["neutral"] = len(unread_story_hashes)
            if feed_scores["neutral"]:
                oldest_unread_story_date = datetime.datetime.fromtimestamp(unread_story_hashes[-1][1])

        if not silent or settings.DEBUG:
            logging.user(
                self.user,
                "~FBUnread count (~SB%s~SN%s): ~SN(~FC%s~FB/~FC%s~FB/~FC%s~FB) ~SBto~SN (~FC%s~FB/~FC%s~FB/~FC%s~FB)"
                % (
                    self.feed_id,
                    "/~FMtrained~FB" if self.is_trained else "",
                    ong,
                    ont,
                    ops,
                    feed_scores["negative"],
                    feed_scores["neutral"],
                    feed_scores["positive"],
                ),
            )

        self.unread_count_positive = feed_scores["positive"]
        self.unread_count_neutral = feed_scores["neutral"]
        self.unread_count_negative = feed_scores["negative"]
        self.unread_count_updated = datetime.datetime.now()
        self.oldest_unread_story_date = oldest_unread_story_date
        self.needs_unread_recalc = False

        update_fields = []
        if self.unread_count_positive != ops:
            update_fields.append("unread_count_positive")
        if self.unread_count_neutral != ont:
            update_fields.append("unread_count_neutral")
        if self.unread_count_negative != ong:
            update_fields.append("unread_count_negative")
        if self.unread_count_updated != ucu:
            update_fields.append("unread_count_updated")
        if self.oldest_unread_story_date != oousd:
            update_fields.append("oldest_unread_story_date")
        if self.needs_unread_recalc != onur:
            update_fields.append("needs_unread_recalc")
        if self.is_trained != oit:
            update_fields.append("is_trained")
        if len(update_fields):
            self.save(update_fields=update_fields)

        if self.unread_count_positive == 0 and self.unread_count_neutral == 0:
            self.mark_feed_read()

        if not silent:
            logging.user(
                self.user,
                "~FC~SNComputing scores: %s (~SB%s~SN/~SB%s~SN/~SB%s~SN)"
                % (self.feed, feed_scores["negative"], feed_scores["neutral"], feed_scores["positive"]),
            )

        self.trim_read_stories()

        return self

    @staticmethod
    def score_story(scores):
        max_score = max(scores["author"], scores["tags"], scores["title"])
        min_score = min(scores["author"], scores["tags"], scores["title"])

        if max_score > 0:
            return 1
        elif min_score < 0:
            return -1

        return scores["feed"]

    def switch_feed(self, new_feed, old_feed):
        # Rewrite feed in subscription folders
        try:
            user_sub_folders = UserSubscriptionFolders.objects.get(user=self.user)
        except Exception as e:
            logging.info(" *** ---> UserSubscriptionFolders error: %s" % e)
            return

        logging.info("      ===> %s " % self.user)

        # Switch read stories
        RUserStory.switch_feed(user_id=self.user_id, old_feed_id=old_feed.pk, new_feed_id=new_feed.pk)
        RUserUnreadStory.switch_feed(user_id=self.user_id, old_feed_id=old_feed.pk, new_feed_id=new_feed.pk)

        def switch_feed_for_classifier(model):
            duplicates = model.objects(feed_id=old_feed.pk, user_id=self.user_id)
            if duplicates.count():
                logging.info(" ---> Switching %s %s" % (duplicates.count(), model))
            for duplicate in duplicates:
                duplicate.feed_id = new_feed.pk
                if duplicate.social_user_id is None:
                    duplicate.social_user_id = 0
                try:
                    duplicate.save()
                    pass
                except (IntegrityError, OperationError):
                    logging.info("      !!!!> %s already exists" % duplicate)
                    duplicate.delete()

        switch_feed_for_classifier(MClassifierTitle)
        switch_feed_for_classifier(MClassifierAuthor)
        switch_feed_for_classifier(MClassifierFeed)
        switch_feed_for_classifier(MClassifierTag)

        # Switch to original feed for the user subscription
        self.feed = new_feed
        self.needs_unread_recalc = True
        try:
            UserSubscription.objects.get(user=self.user, feed=new_feed)
        except UserSubscription.DoesNotExist:
            self.save()
            user_sub_folders.rewrite_feed(new_feed, old_feed)
        else:
            # except (IntegrityError, OperationError):
            logging.info("      !!!!> %s already subscribed" % self.user)
            self.delete()
            return

    @classmethod
    def collect_orphan_feeds(cls, user):
        us = cls.objects.filter(user=user)
        try:
            usf = UserSubscriptionFolders.objects.get(user=user)
        except UserSubscriptionFolders.DoesNotExist:
            return
        us_feed_ids = set([sub.feed_id for sub in us])
        folders = json.decode(usf.folders)

        def collect_ids(folders, found_ids):
            for item in folders:
                # print ' --> %s' % item
                if isinstance(item, int):
                    # print ' --> Adding feed: %s' % item
                    found_ids.add(item)
                elif isinstance(item, dict):
                    # print ' --> Descending folder dict: %s' % item.values()
                    found_ids.update(collect_ids(list(item.values()), found_ids))
                elif isinstance(item, list):
                    # print ' --> Descending folder list: %s' % len(item)
                    found_ids.update(collect_ids(item, found_ids))
            # print ' --> Returning: %s' % found_ids
            return found_ids

        found_ids = collect_ids(folders, set())
        diff = len(us_feed_ids) - len(found_ids)
        if diff > 0:
            logging.info(
                " ---> Collecting orphans on %s. %s feeds with %s orphans"
                % (user.username, len(us_feed_ids), diff)
            )
            orphan_ids = us_feed_ids - found_ids
            folders.extend(list(orphan_ids))
            usf.folders = json.encode(folders)
            usf.save()

    @classmethod
    def all_subs_needs_unread_recalc(cls, user_id):
        subs = cls.objects.filter(user=user_id)
        total = len(subs)
        needed_recalc = 0
        for sub in subs:
            if not sub.needs_unread_recalc:
                sub.needs_unread_recalc = True
                sub.save()
                needed_recalc += 1

        logging.debug(f" ---> Relcaculated {needed_recalc} of {total} subscriptions for user_id: {user_id}")

    @classmethod
    def verify_feeds_scheduled(cls, user_id):
        r = redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)
        user = User.objects.get(pk=user_id)
        subs = cls.objects.filter(user=user)
        feed_ids = [sub.feed.pk for sub in subs]

        p = r.pipeline()
        for feed_id in feed_ids:
            p.zscore("scheduled_updates", feed_id)
            p.zscore("error_feeds", feed_id)
        results = p.execute()

        p = r.pipeline()
        for feed_id in feed_ids:
            p.zscore("queued_feeds", feed_id)
        try:
            results_queued = p.execute()
        except:
            results_queued = [False for x in range(len(feed_ids))]

        safety_net = []
        for f, feed_id in enumerate(feed_ids):
            scheduled_updates = results[f * 2]
            error_feeds = results[f * 2 + 1]
            queued_feeds = results_queued[f]
            if not scheduled_updates and not queued_feeds and not error_feeds:
                safety_net.append(feed_id)

        if not safety_net:
            return

        logging.user(user, "~FBFound ~FR%s unscheduled feeds~FB, scheduling immediately..." % len(safety_net))
        for feed_id in safety_net:
            feed = Feed.get_by_id(feed_id)
            feed.schedule_feed_fetch_immediately()

    @classmethod
    def count_subscribers_to_other_subscriptions(cls, feed_id):
        # feeds = defaultdict(int)
        subscribing_users = (
            cls.objects.filter(feed=feed_id).values("user", "feed_opens").order_by("-feed_opens")[:25]
        )
        print("Got subscribing users")
        subscribing_user_ids = [sub["user"] for sub in subscribing_users]
        print("Got subscribing user ids")
        cofeeds = (
            cls.objects.filter(user__in=subscribing_user_ids)
            .values("feed")
            .annotate(user_count=Count("user"))
            .order_by("-user_count")[:200]
        )
        print("Got cofeeds: %s" % len(cofeeds))
        # feed_subscribers = Feed.objects.filter(pk__in=[f['feed'] for f in cofeeds]).values('pk', 'num_subscribers')
        # max_local_subscribers = float(max([f['user_count'] for f in cofeeds]))
        # max_total_subscribers = float(max([f['num_subscribers'] for f in feed_subscribers]))
        # feed_subscribers = dict([(s['pk'], float(s['num_subscribers'])) for s in feed_subscribers])
        # pctfeeds = [(f['feed'],
        #              f['user_count'],
        #              feed_subscribers[f['feed']],
        #              f['user_count']/max_total_subscribers,
        #              f['user_count']/max_local_subscribers,
        #              max_local_subscribers,
        #              max_total_subscribers) for f in cofeeds]
        # print pctfeeds[:5]
        # orderedpctfeeds = sorted(pctfeeds, key=lambda f: .5*f[3]+.5*f[4], reverse=True)[:8]
        # pprint([(Feed.get_by_id(o[0]), o[1], o[2], o[3], o[4]) for o in orderedpctfeeds])

        users_by_feeds = {}
        for feed in [f["feed"] for f in cofeeds]:
            users_by_feeds[feed] = [
                u["user"] for u in cls.objects.filter(feed=feed, user__in=subscribing_user_ids).values("user")
            ]
        print("Got users_by_feeds")

        table = tfidf()
        for feed in list(users_by_feeds.keys()):
            table.addDocument(feed, users_by_feeds[feed])
        print("Got table")

        sorted_table = sorted(table.similarities(subscribing_user_ids), key=itemgetter(1), reverse=True)[:8]
        pprint([(Feed.get_by_id(o[0]), o[1]) for o in sorted_table])

        return table
        # return cofeeds


class RUserStory:
    @classmethod
    def mark_story_hashes_read(cls, user_id, story_hashes, username=None, r=None, s=None):
        if not r:
            r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
        if not s:
            s = redis.Redis(connection_pool=settings.REDIS_POOL)
        ps = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
        if not username:
            username = User.objects.get(pk=user_id).username

        p = r.pipeline()
        feed_ids = set()
        friend_ids = set()

        if not isinstance(story_hashes, list):
            story_hashes = [story_hashes]

        single_story = len(story_hashes) == 1

        for story_hash in story_hashes:
            feed_id, _ = MStory.split_story_hash(story_hash)
            feed_ids.add(feed_id)

            if single_story:
                cls.aggregate_mark_read(feed_id)

            # Find other social feeds with this story to update their counts
            friend_key = "F:%s:F" % (user_id)
            share_key = "S:%s" % (story_hash)
            friends_with_shares = [int(f) for f in s.sinter(share_key, friend_key)]
            friend_ids.update(friends_with_shares)
            cls.mark_read(
                user_id,
                feed_id,
                story_hash,
                social_user_ids=friends_with_shares,
                r=p,
                username=username,
                ps=ps,
            )

        p.execute()

        return list(feed_ids), list(friend_ids)

    @classmethod
    def mark_story_hash_unread(cls, user, story_hash, r=None, s=None, ps=None):
        if not r:
            r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
        if not s:
            s = redis.Redis(connection_pool=settings.REDIS_POOL)
        if not ps:
            ps = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)

        friend_ids = set()
        feed_id, _ = MStory.split_story_hash(story_hash)

        # Find other social feeds with this story to update their counts
        friend_key = "F:%s:F" % (user.pk)
        share_key = "S:%s" % (story_hash)
        friends_with_shares = [int(f) for f in s.sinter(share_key, friend_key)]
        friend_ids.update(friends_with_shares)
        cls.mark_unread(
            user.pk,
            feed_id,
            story_hash,
            social_user_ids=friends_with_shares,
            r=r,
            username=user.username,
            ps=ps,
        )

        return feed_id, list(friend_ids)

    @classmethod
    def aggregate_mark_read(cls, feed_id):
        if not feed_id:
            logging.debug(" ***> ~BR~FWNo feed_id on aggregate mark read. Ignoring.")
            return

        r = redis.Redis(connection_pool=settings.REDIS_FEED_READ_POOL)
        week_of_year = datetime.datetime.now().strftime("%Y-%U")
        feed_read_key = "fR:%s:%s" % (feed_id, week_of_year)

        r.incr(feed_read_key)
        # This settings.DAYS_OF_STORY_HASHES doesn't need to consider potential pro subscribers
        # because the feed_read_key is really only used for statistics and not unreads
        r.expire(feed_read_key, 2 * settings.DAYS_OF_STORY_HASHES * 24 * 60 * 60)

    @classmethod
    def mark_read(
        cls,
        user_id,
        story_feed_id,
        story_hash,
        social_user_ids=None,
        aggregated=False,
        r=None,
        username=None,
        ps=None,
    ):
        if not r:
            r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)

        story_hash = MStory.ensure_story_hash(story_hash, story_feed_id=story_feed_id)

        if not story_hash:
            return

        def redis_commands(key):
            r.sadd(key, story_hash)
            r.expire(key, Feed.days_of_story_hashes_for_feed(story_feed_id) * 24 * 60 * 60)

        all_read_stories_key = "RS:%s" % (user_id)
        redis_commands(all_read_stories_key)

        read_story_key = "RS:%s:%s" % (user_id, story_feed_id)
        redis_commands(read_story_key)

        if ps and username:
            ps.publish(username, "story:read:%s" % story_hash)

        if social_user_ids:
            for social_user_id in social_user_ids:
                social_read_story_key = "RS:%s:B:%s" % (user_id, social_user_id)
                redis_commands(social_read_story_key)

        feed_id, _ = MStory.split_story_hash(story_hash)

        # Don't remove unread stories from zU because users are actively paging through
        # unread_stories_key = f"U:{user_id}:{story_feed_id}"
        # unread_ranked_stories_key = f"zU:{user_id}:{story_feed_id}"
        # r.srem(unread_stories_key, story_hash)
        # r.zrem(unread_ranked_stories_key, story_hash)

        if not aggregated:
            key = "lRS:%s" % user_id
            r.lpush(key, story_hash)
            r.ltrim(key, 0, 1000)
            r.expire(key, Feed.days_of_story_hashes_for_feed(story_feed_id) * 24 * 60 * 60)

    @staticmethod
    def story_can_be_marked_unread_by_user(story, user):
        message = None
        if story.story_date < user.profile.unread_cutoff and not user.profile.is_archive:
            # if user.profile.is_archive:
            #     message = "Story is more than %s days old, change your days of unreads under Preferences." % (
            #               user.profile.days_of_unread)
            if user.profile.is_premium:
                message = (
                    "Story is more than %s days old. Premium Archive accounts can mark any story as unread."
                    % (settings.DAYS_OF_UNREAD)
                )
            elif story.story_date > user.profile.unread_cutoff_premium:
                message = (
                    "Story is older than %s days. Premium has %s days, and Premium Archive can mark anything unread."
                    % (settings.DAYS_OF_UNREAD_FREE, settings.DAYS_OF_UNREAD)
                )
            else:
                message = (
                    "Story is more than %s days old, only Premium Archive can mark older stories unread."
                    % (settings.DAYS_OF_UNREAD_FREE)
                )
        return message

    @staticmethod
    def mark_unread(user_id, story_feed_id, story_hash, social_user_ids=None, r=None, username=None, ps=None):
        if not r:
            r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)

        story_hash = MStory.ensure_story_hash(story_hash, story_feed_id=story_feed_id)

        if not story_hash:
            return

        def redis_commands(key):
            r.srem(key, story_hash)
            r.expire(key, Feed.days_of_story_hashes_for_feed(story_feed_id) * 24 * 60 * 60)

        all_read_stories_key = "RS:%s" % (user_id)
        redis_commands(all_read_stories_key)

        read_story_key = "RS:%s:%s" % (user_id, story_feed_id)
        redis_commands(read_story_key)

        read_stories_list_key = "lRS:%s" % user_id
        r.lrem(read_stories_list_key, 1, story_hash)

        if ps and username:
            ps.publish(username, "story:unread:%s" % story_hash)

        if social_user_ids:
            for social_user_id in social_user_ids:
                social_read_story_key = "RS:%s:B:%s" % (user_id, social_user_id)
                redis_commands(social_read_story_key)

    @staticmethod
    def get_stories(user_id, feed_id, r=None):
        if not r:
            r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
        story_hashes = r.smembers("RS:%s:%s" % (user_id, feed_id))
        return story_hashes

    @staticmethod
    def get_read_stories(user_id, offset=0, limit=12, order="newest"):
        r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
        key = "lRS:%s" % user_id

        if order == "oldest":
            count = r.llen(key)
            if offset >= count:
                return []
            offset = max(0, count - (offset + limit))
            story_hashes = r.lrange(key, offset, offset + limit)
        elif order == "newest":
            story_hashes = r.lrange(key, offset, offset + limit)

        return story_hashes

    @classmethod
    def switch_feed(cls, user_id, old_feed_id, new_feed_id):
        r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
        p = r.pipeline()

        story_hashes = UserSubscription.story_hashes(user_id, feed_ids=[old_feed_id])
        # story_hashes = cls.get_stories(user_id, old_feed_id, r=r)

        for story_hash in story_hashes:
            _, hash_story = MStory.split_story_hash(story_hash)
            new_story_hash = "%s:%s" % (new_feed_id, hash_story)
            read_feed_key = "RS:%s:%s" % (user_id, new_feed_id)
            p.sadd(read_feed_key, new_story_hash)
            p.expire(read_feed_key, Feed.days_of_story_hashes_for_feed(new_feed_id) * 24 * 60 * 60)

            read_user_key = "RS:%s" % (user_id)
            p.sadd(read_user_key, new_story_hash)
            p.expire(read_user_key, Feed.days_of_story_hashes_for_feed(new_feed_id) * 24 * 60 * 60)

        p.execute()

        if len(story_hashes) > 0:
            logging.info(" ---> %s read stories" % len(story_hashes))

    @classmethod
    def switch_hash(cls, feed, old_hash, new_hash):
        r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
        p = r.pipeline()

        usersubs = UserSubscription.objects.filter(feed_id=feed.pk, last_read_date__gte=feed.unread_cutoff)
        logging.info(" ---> ~SB%s usersubs~SN to switch read story hashes..." % len(usersubs))
        for sub in usersubs:
            rs_key = "RS:%s:%s" % (sub.user.pk, feed.pk)
            read = r.sismember(rs_key, old_hash)
            if read:
                p.sadd(rs_key, new_hash)
                p.expire(rs_key, feed.days_of_story_hashes * 24 * 60 * 60)

                read_user_key = "RS:%s" % sub.user.pk
                p.sadd(read_user_key, new_hash)
                p.expire(read_user_key, feed.days_of_story_hashes * 24 * 60 * 60)

        p.execute()

    @classmethod
    def read_story_count(cls, user_id):
        r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
        key = "RS:%s" % user_id
        count = r.scard(key)
        return count


class UserSubscriptionFolders(models.Model):
    """
    A JSON list of folders and feeds for while a user has subscribed. The list
    is a recursive descent of feeds and folders in folders. Used to layout
    the feeds and folders in the Reader's feed navigation pane.
    """

    user = models.OneToOneField(User, on_delete=models.CASCADE)
    folders = models.TextField(default="[]")

    def __str__(self):
        return "[%s]: %s" % (
            self.user,
            len(self.folders),
        )

    class Meta:
        verbose_name_plural = "folders"
        verbose_name = "folder"

    @classmethod
    def compact_for_user(cls, user_id):
        user = User.objects.get(pk=user_id)
        try:
            usf = UserSubscriptionFolders.objects.get(user=user)
        except UserSubscriptionFolders.DoesNotExist:
            return

        usf.compact()

    def compact(self):
        folders = json.decode(self.folders)

        def _compact(folder):
            new_folder = []
            for item in folder:
                if isinstance(item, int) and item not in new_folder:
                    new_folder.append(item)
                elif isinstance(item, dict):
                    for f_k, f_v in list(item.items()):
                        # Check every existing folder at that level to see if it already exists
                        for ef, existing_folder in enumerate(new_folder):
                            if type(existing_folder) == dict and list(existing_folder.keys())[0] == f_k:
                                existing_folder_feed_ids = [
                                    f for f in list(existing_folder.values())[0] if type(f) == int
                                ]
                                merged = []
                                for merge_val in existing_folder_feed_ids:
                                    merged.append(merge_val)
                                for merge_val in f_v:
                                    if type(merge_val) == int:
                                        if merge_val not in existing_folder_feed_ids:
                                            merged.append(merge_val)
                                    else:
                                        merged.append(merge_val)
                                if f_v != existing_folder_feed_ids:
                                    logging.info(
                                        f" ---> ~FRFound repeat folder: {f_k} \n\t"
                                        f"~FBExisting: {f_v}\n\t"
                                        f"~FCMerging: {list(existing_folder.values())[0]}\n\t"
                                        f"~FYBecomes: {merged}"
                                    )
                                    new_folder[ef] = {f_k: _compact(merged)}
                                else:
                                    logging.info(
                                        f" ---> ~FRFound repeat folder ~FY{f_k}~FR, no difference in feeds"
                                    )
                                break
                        else:
                            # If no match, then finally we can add the folder
                            new_folder.append({f_k: _compact(f_v)})
            return new_folder

        new_folders = _compact(folders)
        compact_msg = " ---> Compacting from %s to %s" % (folders, new_folders)
        new_folders = json.encode(new_folders)
        if json.encode(self.folders) != json.encode(new_folders):
            logging.info(compact_msg)
            logging.info(" ---> Compacting from %s bytes to %s bytes" % (len(self.folders), len(new_folders)))
            self.folders = new_folders
            self.save()

    def add_folder(self, parent_folder, folder):
        if self.folders:
            user_sub_folders = json.decode(self.folders)
        else:
            user_sub_folders = []
        obj = {folder: []}
        user_sub_folders = add_object_to_folder(obj, parent_folder, user_sub_folders)
        self.folders = json.encode(user_sub_folders)
        self.save()

    def arranged_folders(self):
        user_sub_folders = json.decode(self.folders)

        def _arrange_folder(folder):
            folder_feeds = []
            folder_folders = []
            for item in folder:
                if isinstance(item, int):
                    folder_feeds.append(item)
                elif isinstance(item, dict):
                    for f_k, f_v in list(item.items()):
                        arranged_folder = _arrange_folder(f_v)
                        folder_folders.append({f_k: arranged_folder})

            arranged_folder = folder_feeds + folder_folders
            return arranged_folder

        return _arrange_folder(user_sub_folders)

    def flatten_folders(self, feeds=None, inactive_feeds=None):
        folders = json.decode(self.folders)
        flat_folders = {" ": []}
        if feeds and not inactive_feeds:
            inactive_feeds = []

        def _flatten_folders(items, parent_folder="", depth=0):
            for item in items:
                if isinstance(item, int) and (not feeds or (item in feeds or item in inactive_feeds)):
                    if not parent_folder:
                        parent_folder = " "
                    if parent_folder in flat_folders:
                        flat_folders[parent_folder].append(item)
                    else:
                        flat_folders[parent_folder] = [item]
                elif isinstance(item, dict):
                    for folder_name in item:
                        folder = item[folder_name]
                        flat_folder_name = "%s%s%s" % (
                            parent_folder if parent_folder and parent_folder != " " else "",
                            " - " if parent_folder and parent_folder != " " else "",
                            folder_name,
                        )
                        flat_folders[flat_folder_name] = []
                        _flatten_folders(folder, flat_folder_name, depth + 1)

        _flatten_folders(folders)

        return flat_folders

    def delete_feed(self, feed_id, in_folder, commit_delete=True):
        feed_id = int(feed_id)

        def _find_feed_in_folders(old_folders, folder_name="", multiples_found=False, deleted=False):
            new_folders = []
            for k, folder in enumerate(old_folders):
                if isinstance(folder, int):
                    if (
                        folder == feed_id
                        and in_folder is not None
                        and ((in_folder not in folder_name) or (in_folder in folder_name and deleted))
                    ):
                        multiples_found = True
                        logging.user(
                            self.user,
                            "~FB~SBDeleting feed, and a multiple has been found in '%s' / '%s' %s"
                            % (folder_name, in_folder, "(deleted)" if deleted else ""),
                        )
                    if folder == feed_id and (in_folder is None or in_folder in folder_name) and not deleted:
                        logging.user(
                            self.user, "~FBDelete feed: %s'th item: %s folders/feeds" % (k, len(old_folders))
                        )
                        deleted = True
                    else:
                        new_folders.append(folder)
                elif isinstance(folder, dict):
                    for f_k, f_v in list(folder.items()):
                        nf, multiples_found, deleted = _find_feed_in_folders(
                            f_v, f_k, multiples_found, deleted
                        )
                        new_folders.append({f_k: nf})

            return new_folders, multiples_found, deleted

        user_sub_folders = self.arranged_folders()
        user_sub_folders, multiples_found, deleted = _find_feed_in_folders(user_sub_folders)
        self.folders = json.encode(user_sub_folders)
        self.save()

        if not multiples_found and deleted and commit_delete:
            user_sub = None
            try:
                user_sub = UserSubscription.objects.get(user=self.user, feed=feed_id)
            except (Feed.DoesNotExist, UserSubscription.DoesNotExist):
                duplicate_feed = DuplicateFeed.objects.filter(duplicate_feed_id=feed_id)
                if duplicate_feed:
                    try:
                        user_sub = UserSubscription.objects.get(user=self.user, feed=duplicate_feed[0].feed)
                    except (Feed.DoesNotExist, UserSubscription.DoesNotExist):
                        return
            if user_sub:
                user_sub.delete()

    def delete_folder(self, folder_to_delete, in_folder, feed_ids_in_folder, commit_delete=True):
        def _find_folder_in_folders(old_folders, folder_name, feeds_to_delete, deleted_folder=None):
            new_folders = []
            for k, folder in enumerate(old_folders):
                if isinstance(folder, int):
                    new_folders.append(folder)
                    if folder in feeds_to_delete:
                        feeds_to_delete.remove(folder)
                elif isinstance(folder, dict):
                    for f_k, f_v in list(folder.items()):
                        if f_k == folder_to_delete and (in_folder in folder_name or in_folder is None):
                            logging.user(
                                self.user,
                                "~FBDeleting folder '~SB%s~SN' in '%s': %s" % (f_k, folder_name, folder),
                            )
                            deleted_folder = folder
                        else:
                            nf, feeds_to_delete, deleted_folder = _find_folder_in_folders(
                                f_v, f_k, feeds_to_delete, deleted_folder
                            )
                            new_folders.append({f_k: nf})

            return new_folders, feeds_to_delete, deleted_folder

        user_sub_folders = json.decode(self.folders)
        user_sub_folders, feeds_to_delete, deleted_folder = _find_folder_in_folders(
            user_sub_folders, "", feed_ids_in_folder
        )
        self.folders = json.encode(user_sub_folders)
        self.save()

        if commit_delete:
            UserSubscription.objects.filter(user=self.user, feed__in=feeds_to_delete).delete()

        return deleted_folder

    def delete_feeds_by_folder(self, feeds_by_folder):
        logging.user(
            self.user, "~FBDeleting ~FR~SB%s~SN feeds~FB: ~SB%s" % (len(feeds_by_folder), feeds_by_folder)
        )
        for feed_id, in_folder in feeds_by_folder:
            self.delete_feed(feed_id, in_folder)

        return self

    def rename_folder(self, folder_to_rename, new_folder_name, in_folder):
        def _find_folder_in_folders(old_folders, folder_name):
            new_folders = []
            for k, folder in enumerate(old_folders):
                if isinstance(folder, int):
                    new_folders.append(folder)
                elif isinstance(folder, dict):
                    for f_k, f_v in list(folder.items()):
                        nf = _find_folder_in_folders(f_v, f_k)
                        if f_k == folder_to_rename and in_folder in folder_name:
                            logging.user(
                                self.user,
                                "~FBRenaming folder '~SB%s~SN' in '%s' to: ~SB%s"
                                % (f_k, folder_name, new_folder_name),
                            )
                            f_k = new_folder_name
                        new_folders.append({f_k: nf})

            return new_folders

        user_sub_folders = json.decode(self.folders)
        user_sub_folders = _find_folder_in_folders(user_sub_folders, "")
        self.folders = json.encode(user_sub_folders)
        self.save()

    def move_feed_to_folders(self, feed_id, in_folders=None, to_folders=None):
        logging.user(
            self.user, "~FBMoving feed '~SB%s~SN' in '%s' to: ~SB%s" % (feed_id, in_folders, to_folders)
        )
        user_sub_folders = json.decode(self.folders)
        for in_folder in in_folders:
            self.delete_feed(feed_id, in_folder, commit_delete=False)
        user_sub_folders = json.decode(self.folders)
        for to_folder in to_folders:
            user_sub_folders = add_object_to_folder(int(feed_id), to_folder, user_sub_folders)
        self.folders = json.encode(user_sub_folders)
        self.save()

        return self

    def move_feed_to_folder(self, feed_id, in_folder=None, to_folder=None):
        logging.user(
            self.user, "~FBMoving feed '~SB%s~SN' in '%s' to: ~SB%s" % (feed_id, in_folder, to_folder)
        )
        user_sub_folders = json.decode(self.folders)
        self.delete_feed(feed_id, in_folder, commit_delete=False)
        user_sub_folders = json.decode(self.folders)
        user_sub_folders = add_object_to_folder(int(feed_id), to_folder, user_sub_folders)
        self.folders = json.encode(user_sub_folders)
        self.save()

        return self

    def move_folder_to_folder(self, folder_name, in_folder=None, to_folder=None):
        logging.user(
            self.user, "~FBMoving folder '~SB%s~SN' in '%s' to: ~SB%s" % (folder_name, in_folder, to_folder)
        )
        user_sub_folders = json.decode(self.folders)
        deleted_folder = self.delete_folder(folder_name, in_folder, [], commit_delete=False)
        user_sub_folders = json.decode(self.folders)
        user_sub_folders = add_object_to_folder(deleted_folder, to_folder, user_sub_folders)
        self.folders = json.encode(user_sub_folders)
        self.save()

        return self

    def move_feeds_by_folder_to_folder(self, feeds_by_folder, to_folder):
        logging.user(
            self.user, "~FBMoving ~SB%s~SN feeds to folder: ~SB%s" % (len(feeds_by_folder), to_folder)
        )
        for feed_id, in_folder in feeds_by_folder:
            feed_id = int(feed_id)
            self.move_feed_to_folder(feed_id, in_folder, to_folder)

        return self

    def rewrite_feed(self, original_feed, duplicate_feed):
        def rewrite_folders(folders, original_feed, duplicate_feed):
            new_folders = []

            for k, folder in enumerate(folders):
                if isinstance(folder, int):
                    if folder == duplicate_feed.pk:
                        # logging.info("              ===> Rewrote %s'th item: %s" % (k+1, folders))
                        new_folders.append(original_feed.pk)
                    else:
                        new_folders.append(folder)
                elif isinstance(folder, dict):
                    for f_k, f_v in list(folder.items()):
                        new_folders.append({f_k: rewrite_folders(f_v, original_feed, duplicate_feed)})

            return new_folders

        folders = json.decode(self.folders)
        folders = rewrite_folders(folders, original_feed, duplicate_feed)
        self.folders = json.encode(folders)
        self.save()

    def flat(self):
        folders = json.decode(self.folders)

        def _flat(folder, feeds=None):
            if not feeds:
                feeds = []
            for item in folder:
                if isinstance(item, int) and item not in feeds:
                    feeds.append(item)
                elif isinstance(item, dict):
                    for f_k, f_v in list(item.items()):
                        feeds.extend(_flat(f_v))
            return feeds

        return _flat(folders)

    def feed_ids_under_folder_slug(self, slug):
        folders = json.decode(self.folders)

        def _feeds(folder, found=False, folder_title=None):
            feeds = []
            local_found = False
            for item in folder:
                if isinstance(item, int) and item not in feeds and found:
                    feeds.append(item)
                elif isinstance(item, dict):
                    for f_k, f_v in list(item.items()):
                        if slugify(f_k) == slug:
                            found = True
                            local_found = True
                            folder_title = f_k
                        found_feeds, folder_title = _feeds(f_v, found, folder_title)
                        feeds.extend(found_feeds)
                        if local_found:
                            found = False
                            local_found = False
            return feeds, folder_title

        return _feeds(folders)

    @classmethod
    def add_all_missing_feeds(cls):
        usf = cls.objects.all().order_by("pk")
        total = usf.count()

        for i, f in enumerate(usf):
            print("%s/%s: %s" % (i, total, f))
            f.add_missing_feeds()

    @classmethod
    def add_missing_feeds_for_user(cls, user_id):
        user = User.objects.get(pk=user_id)
        try:
            usf = UserSubscriptionFolders.objects.get(user=user)
        except UserSubscriptionFolders.DoesNotExist:
            return

        usf.add_missing_feeds()

    def add_missing_feeds(self):
        all_feeds = self.flat()
        subs = [us.feed_id for us in UserSubscription.objects.filter(user=self.user).only("feed")]

        missing_subs = set(all_feeds) - set(subs)
        if missing_subs:
            logging.debug(
                " ---> %s is missing %s subs. Adding %s..." % (self.user, len(missing_subs), missing_subs)
            )
            for feed_id in missing_subs:
                feed = Feed.get_by_id(feed_id)
                if feed:
                    if feed_id != feed.pk:
                        logging.debug(
                            " ---> %s doesn't match %s, rewriting to remove %s..."
                            % (feed_id, feed.pk, feed_id)
                        )
                        # Clear out duplicate sub in folders before subscribing to feed
                        duplicate_feed = Feed.get_by_id(feed_id)
                        duplicate_feed.pk = feed_id
                        self.rewrite_feed(feed, duplicate_feed)
                    us, _ = UserSubscription.objects.get_or_create(
                        user=self.user, feed=feed, defaults={"needs_unread_recalc": True}
                    )
                    if not us.needs_unread_recalc:
                        us.needs_unread_recalc = True
                        us.save()
                elif feed_id and not feed:
                    # No feed found for subscription, remove subscription
                    logging.debug(" ---> %s: No feed found, removing subscription: %s" % (self.user, feed_id))
                    self.delete_feed(feed_id, None, commit_delete=False)

        missing_folder_feeds = set(subs) - set(all_feeds)
        if missing_folder_feeds:
            user_sub_folders = json.decode(self.folders)
            logging.debug(
                " ---> %s is missing %s folder feeds. Adding %s..."
                % (self.user, len(missing_folder_feeds), missing_folder_feeds)
            )
            for feed_id in missing_folder_feeds:
                feed = Feed.get_by_id(feed_id)
                if feed and feed.pk == feed_id:
                    user_sub_folders = add_object_to_folder(feed_id, "", user_sub_folders)
            self.folders = json.encode(user_sub_folders)
            self.save()

    def auto_activate(self):
        if self.user.profile.is_premium:
            return

        active_count = UserSubscription.objects.filter(user=self.user, active=True).count()
        if active_count:
            return

        all_feeds = self.flat()
        if not all_feeds:
            return

        for feed in all_feeds[:64]:
            try:
                sub = UserSubscription.objects.get(user=self.user, feed=feed)
            except UserSubscription.DoesNotExist:
                continue
            sub.active = True
            sub.save()
            if sub.feed.active_subscribers <= 0:
                sub.feed.count_subscribers()


class Feature(models.Model):
    """
    Simple blog-like feature board shown to all users on the home page.
    """

    description = models.TextField(default="")
    date = models.DateTimeField(default=datetime.datetime.now)

    def __str__(self):
        return "[%s] %s" % (self.date, self.description[:50])

    class Meta:
        ordering = ["-date"]


class RUserUnreadStory:
    """Model to store manually unread stories that are older than a user's unread_cutoff
    (same as days_of_unread). This is built for Premium Archive purposes.

    If a story is marked as unread but is within the unread_cutoff, no need to add a
    UserUnreadStory instance as it will be automatically marked as read according to
    the user's days_of_unread preference.
    """

    @classmethod
    def mark_unread(cls, user_id, story_hash, story_date, r=None):
        if not r:
            r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
        if isinstance(story_date, float):
            story_date = int(story_date)
        if not isinstance(story_date, int):
            story_date = int(time.mktime(story_date.timetuple()))

        feed_id, _ = MStory.split_story_hash(story_hash)
        user_manual_unread_stories_key = f"uU:{user_id}"
        user_manual_unread_stories_feed_key = f"uU:{user_id}:{feed_id}"

        r.zadd(user_manual_unread_stories_key, {story_hash: story_date})
        r.zadd(user_manual_unread_stories_feed_key, {story_hash: story_date})

    @classmethod
    def mark_read(cls, user_id, story_hashes, r=None):
        if not isinstance(story_hashes, list):
            story_hashes = [story_hashes]
        if not r:
            r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)

        pipeline = r.pipeline()
        for story_hash in story_hashes:
            feed_id, _ = MStory.split_story_hash(story_hash)

            user_manual_unread_stories_key = f"uU:{user_id}"
            user_manual_unread_stories_feed_key = f"uU:{user_id}:{feed_id}"

            pipeline.zrem(user_manual_unread_stories_key, story_hash)
            pipeline.zrem(user_manual_unread_stories_feed_key, story_hash)
        pipeline.execute()

    @classmethod
    def unreads(cls, user_id, story_hash):
        if not isinstance(story_hash, list):
            story_hash = [story_hash]

        user_unread_stories = cls.objects.filter(user_id=user_id, story_hash__in=story_hash)

        return user_unread_stories

    @staticmethod
    def get_stories_and_dates(user_id, feed_id, r=None):
        if not r:
            r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)

        user_manual_unread_stories_feed_key = f"uU:{user_id}:{feed_id}"
        story_hashes = r.zrange(user_manual_unread_stories_feed_key, 0, -1, withscores=True)

        return story_hashes

    @classmethod
    def switch_feed(cls, user_id, old_feed_id, new_feed_id):
        r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
        p = r.pipeline()
        story_hashes = cls.get_stories_and_dates(user_id, old_feed_id, r=r)

        for story_hash, story_timestamp in story_hashes:
            _, hash_story = MStory.split_story_hash(story_hash)
            new_story_hash = "%s:%s" % (new_feed_id, hash_story)
            # read_feed_key = "RS:%s:%s" % (user_id, new_feed_id)
            # user_manual_unread_stories_feed_key = f"uU:{user_id}:{new_feed_id}"
            cls.mark_unread(user_id, new_story_hash, story_timestamp, r=p)

        p.execute()

        if len(story_hashes) > 0:
            logging.info(" ---> %s archived unread stories" % len(story_hashes))
