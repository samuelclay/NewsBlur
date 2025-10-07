import base64
import csv
import datetime
import difflib
import hashlib
import html
import math
import os
import pickle
import random
import re
import time
import urllib.parse
import zlib
from collections import defaultdict
from operator import itemgetter

import bson
import mongoengine as mongo
import numpy as np
import pymongo
import redis
import requests
from bs4 import BeautifulSoup
from bson.objectid import ObjectId
from django.conf import settings
from django.contrib.auth.models import User
from django.contrib.sites.models import Site
from django.core.management.base import BaseCommand, CommandError
from django.db import IntegrityError, models
from django.db.models.query import QuerySet
from django.db.utils import DatabaseError
from django.template.defaultfilters import slugify
from django.urls import reverse
from django.utils.encoding import DjangoUnicodeDecodeError, smart_bytes, smart_str
from mongoengine.errors import ValidationError
from mongoengine.queryset import NotUniqueError, OperationError, Q

from apps.rss_feeds.tasks import (
    IndexDiscoverStories,
    PushFeeds,
    ScheduleCountTagsForUser,
    UpdateFeeds,
)
from apps.rss_feeds.text_importer import TextImporter
from apps.search.models import DiscoverStory, SearchFeed, SearchStory
from apps.statistics.rstats import RStats
from utils import feedfinder_forman, feedfinder_pilgrim
from utils import json_functions as json
from utils import log as logging
from utils import urlnorm
from utils.feed_functions import (
    TimeoutError,
    levenshtein_distance,
    relative_timesince,
    seconds_timesince,
    strip_underscore_from_feed_address,
    timelimit,
)
from utils.fields import AutoOneToOneField
from utils.story_functions import (
    create_imageproxy_signed_url,
    htmldiff,
    prep_for_search,
    strip_comments,
    strip_comments__lxml,
    strip_tags,
)
from vendor.timezones.utilities import localtime_for_timezone

ENTRY_NEW, ENTRY_UPDATED, ENTRY_SAME, ENTRY_ERR = list(range(4))


class Feed(models.Model):
    feed_address = models.URLField(max_length=764, db_index=True)
    feed_address_locked = models.BooleanField(default=False, blank=True, null=True)
    feed_link = models.URLField(max_length=1000, default="", blank=True, null=True)
    feed_link_locked = models.BooleanField(default=False)
    hash_address_and_link = models.CharField(max_length=64, unique=True)
    feed_title = models.CharField(max_length=255, default="[Untitled]", blank=True, null=True)
    is_push = models.BooleanField(default=False, blank=True, null=True)
    active = models.BooleanField(default=True, db_index=True)
    num_subscribers = models.IntegerField(default=-1)
    active_subscribers = models.IntegerField(default=-1, db_index=True)
    premium_subscribers = models.IntegerField(default=-1)
    archive_subscribers = models.IntegerField(default=0, null=True, blank=True)
    pro_subscribers = models.IntegerField(default=0, null=True, blank=True)
    active_premium_subscribers = models.IntegerField(default=-1)
    branch_from_feed = models.ForeignKey(
        "Feed", blank=True, null=True, db_index=True, on_delete=models.CASCADE
    )
    last_update = models.DateTimeField(db_index=True)
    next_scheduled_update = models.DateTimeField()
    last_story_date = models.DateTimeField(null=True, blank=True)
    fetched_once = models.BooleanField(default=False)
    known_good = models.BooleanField(default=False)
    has_feed_exception = models.BooleanField(default=False, db_index=True)
    has_page_exception = models.BooleanField(default=False, db_index=True)
    has_page = models.BooleanField(default=True)
    exception_code = models.IntegerField(default=0)
    errors_since_good = models.IntegerField(default=0)
    min_to_decay = models.IntegerField(default=0)
    days_to_trim = models.IntegerField(default=90)
    creation = models.DateField(auto_now_add=True)
    etag = models.CharField(max_length=255, blank=True, null=True)
    last_modified = models.DateTimeField(null=True, blank=True)
    stories_last_month = models.IntegerField(default=0)
    average_stories_per_month = models.IntegerField(default=0)
    last_load_time = models.IntegerField(default=0)
    favicon_color = models.CharField(max_length=6, null=True, blank=True)
    favicon_not_found = models.BooleanField(default=False)
    s3_page = models.BooleanField(default=False, blank=True, null=True)
    s3_icon = models.BooleanField(default=False, blank=True, null=True)
    search_indexed = models.BooleanField(default=None, null=True, blank=True)
    discover_indexed = models.BooleanField(default=None, null=True, blank=True)
    fs_size_bytes = models.IntegerField(null=True, blank=True)
    archive_count = models.IntegerField(null=True, blank=True)
    similar_feeds = models.ManyToManyField(
        "self", related_name="feeds_by_similarity", symmetrical=False, blank=True
    )
    is_forbidden = models.BooleanField(blank=True, null=True)
    date_forbidden = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = "feeds"
        ordering = ["feed_title"]
        # unique_together=[('feed_address', 'feed_link')]

    def __str__(self):
        if not self.feed_title:
            self.feed_title = "[Untitled]"
            self.save()
        return "%s%s: %s - %s/%s/%s/%s/%s %s stories (%s bytes)" % (
            self.pk,
            (" [B: %s]" % self.branch_from_feed.pk if self.branch_from_feed else ""),
            self.feed_title,
            self.num_subscribers,
            self.active_subscribers,
            self.active_premium_subscribers,
            self.archive_subscribers,
            self.pro_subscribers,
            self.archive_count,
            self.fs_size_bytes,
        )

    @property
    def title(self):
        title = self.feed_title or "[Untitled]"
        if self.active_premium_subscribers >= 1:
            title = "%s*" % title[:29]
        return title

    @property
    def log_title(self):
        return self.__str__()

    @property
    def permalink(self):
        return "%s/site/%s/%s" % (settings.NEWSBLUR_URL, self.pk, slugify(self.feed_title.lower()[:50]))

    @property
    def favicon_url(self):
        if settings.BACKED_BY_AWS["icons_on_s3"] and self.s3_icon:
            return "https://s3.amazonaws.com/%s/%s.png" % (settings.S3_ICONS_BUCKET_NAME, self.pk)
        return reverse("feed-favicon", kwargs={"feed_id": self.pk})

    @property
    def favicon_url_fqdn(self):
        if settings.BACKED_BY_AWS["icons_on_s3"] and self.s3_icon:
            return self.favicon_url
        return "https://%s%s" % (Site.objects.get_current().domain, self.favicon_url)

    @property
    def s3_pages_key(self):
        return "%s.gz.html" % self.pk

    @property
    def s3_icons_key(self):
        return "%s.png" % self.pk

    @property
    def unread_cutoff(self):
        if self.archive_subscribers and self.archive_subscribers > 0:
            return datetime.datetime.utcnow() - datetime.timedelta(days=settings.DAYS_OF_UNREAD_ARCHIVE)
        if self.premium_subscribers > 0:
            return datetime.datetime.utcnow() - datetime.timedelta(days=settings.DAYS_OF_UNREAD)

        return datetime.datetime.utcnow() - datetime.timedelta(days=settings.DAYS_OF_UNREAD_FREE)

    @classmethod
    def days_of_story_hashes_for_feed(cls, feed_id):
        try:
            feed = cls.objects.only("archive_subscribers").get(pk=feed_id)
            return feed.days_of_story_hashes
        except cls.DoesNotExist:
            return settings.DAYS_OF_STORY_HASHES

    @property
    def days_of_story_hashes(self):
        if self.archive_subscribers and self.archive_subscribers > 0:
            return settings.DAYS_OF_STORY_HASHES_ARCHIVE
        return settings.DAYS_OF_STORY_HASHES

    @property
    def story_hashes_in_unread_cutoff(self):
        r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
        current_time = int(time.time() + 60 * 60 * 24)
        unread_cutoff = self.unread_cutoff.strftime("%s")
        story_hashes = r.zrevrangebyscore("zF:%s" % self.pk, current_time, unread_cutoff)

        return story_hashes

    @classmethod
    def generate_hash_address_and_link(cls, feed_address, feed_link):
        if not feed_address:
            feed_address = ""
        if not feed_link:
            feed_link = ""
        return hashlib.sha1((feed_address + feed_link).encode(encoding="utf-8")).hexdigest()

    @property
    def is_newsletter(self):
        return self.feed_address.startswith("newsletter:") or self.feed_address.startswith(
            "http://newsletter:"
        )

    def canonical(self, full=False, include_favicon=True):
        feed = {
            "id": self.pk,
            "feed_title": self.feed_title,
            "feed_address": self.feed_address,
            "feed_link": self.feed_link,
            "num_subscribers": self.num_subscribers,
            "updated": relative_timesince(self.last_update),
            "updated_seconds_ago": seconds_timesince(self.last_update),
            "fs_size_bytes": self.fs_size_bytes,
            "archive_count": self.archive_count,
            "last_story_date": self.last_story_date,
            "last_story_seconds_ago": seconds_timesince(self.last_story_date),
            "stories_last_month": self.stories_last_month,
            "average_stories_per_month": self.average_stories_per_month,
            "min_to_decay": self.min_to_decay,
            "subs": self.num_subscribers,
            "is_push": self.is_push,
            "is_newsletter": self.is_newsletter,
            "fetched_once": self.fetched_once,
            "search_indexed": self.search_indexed,
            "discover_indexed": self.discover_indexed,
            "not_yet_fetched": not self.fetched_once,  # Legacy. Doh.
            "favicon_color": self.favicon_color,
            "favicon_fade": self.favicon_fade(),
            "favicon_border": self.favicon_border(),
            "favicon_text_color": self.favicon_text_color(),
            "favicon_fetching": self.favicon_fetching,
            "favicon_url": self.favicon_url,
            "s3_page": self.s3_page,
            "s3_icon": self.s3_icon,
            "disabled_page": not self.has_page,
            "similar_feeds": [f["pk"] for f in self.similar_feeds.values("pk")],
        }

        if include_favicon:
            try:
                feed_icon = MFeedIcon.objects.get(feed_id=self.pk)
                feed["favicon"] = feed_icon.data
            except MFeedIcon.DoesNotExist:
                pass
        if self.has_page_exception or self.has_feed_exception:
            feed["has_exception"] = True
            feed["exception_type"] = "feed" if self.has_feed_exception else "page"
            feed["exception_code"] = self.exception_code
        elif full:
            feed["has_exception"] = False
            feed["exception_type"] = None
            feed["exception_code"] = self.exception_code

        if full:
            feed["average_stories_per_month"] = self.average_stories_per_month
            feed["tagline"] = self.data.feed_tagline
            feed["feed_tags"] = json.decode(self.data.popular_tags) if self.data.popular_tags else []
            feed["feed_authors"] = json.decode(self.data.popular_authors) if self.data.popular_authors else []

        return feed

    def save(self, *args, **kwargs):
        if not self.last_update:
            self.last_update = datetime.datetime.utcnow()
        if not self.next_scheduled_update:
            self.next_scheduled_update = datetime.datetime.utcnow()
        self.fix_google_alerts_urls()

        feed_address = self.feed_address or ""
        feed_link = self.feed_link or ""
        self.hash_address_and_link = self.generate_hash_address_and_link(feed_address, feed_link)

        max_feed_title = Feed._meta.get_field("feed_title").max_length
        if len(self.feed_title) > max_feed_title:
            self.feed_title = self.feed_title[:max_feed_title]
        max_feed_address = Feed._meta.get_field("feed_address").max_length
        if len(feed_address) > max_feed_address:
            self.feed_address = feed_address[:max_feed_address]
        max_feed_link = Feed._meta.get_field("feed_link").max_length
        if len(feed_link) > max_feed_link:
            self.feed_link = feed_link[:max_feed_link]

        try:
            super(Feed, self).save(*args, **kwargs)
        except IntegrityError as e:
            logging.debug(" ---> ~FRFeed save collision (%s), checking dupe hash..." % e)
            feed_address = self.feed_address or ""
            feed_link = self.feed_link or ""
            hash_address_and_link = self.generate_hash_address_and_link(feed_address, feed_link)
            logging.debug(" ---> ~FRNo dupes, checking hash collision: %s" % hash_address_and_link)
            duplicate_feeds = Feed.objects.filter(hash_address_and_link=hash_address_and_link)

            if not duplicate_feeds:
                duplicate_feeds = Feed.objects.filter(
                    feed_address=self.feed_address, feed_link=self.feed_link
                )
            if not duplicate_feeds:
                # Feed has been deleted. Just ignore it.
                logging.debug(
                    " ***> Changed to: %s - %s: %s" % (self.feed_address, self.feed_link, duplicate_feeds)
                )
                logging.debug(" ***> [%-30s] Feed deleted (%s)." % (self.log_title[:30], self.pk))
                return

            for duplicate_feed in duplicate_feeds:
                if duplicate_feed.pk != self.pk:
                    logging.debug(
                        " ---> ~FRFound different feed (%s), merging %s in..." % (duplicate_feeds[0], self.pk)
                    )
                    feed = Feed.get_by_id(merge_feeds(duplicate_feeds[0].pk, self.pk))
                    return feed
            else:
                logging.debug(" ---> ~FRFeed is its own dupe? %s == %s" % (self, duplicate_feeds))
        except DatabaseError as e:
            logging.debug(
                " ---> ~FBFeed update failed, no change: %s / %s..." % (kwargs.get("update_fields", None), e)
            )
            pass

        return self

    @classmethod
    def index_all_for_search(cls, offset=0, subscribers=2):
        if not offset:
            SearchFeed.create_elasticsearch_mapping(delete=True)

        last_pk = cls.objects.latest("pk").pk
        for f in range(offset, last_pk, 10):
            print(
                " ---> {f} / {last_pk} ({pct}%)".format(
                    f=f, last_pk=last_pk, pct=str(float(f) / last_pk * 100)[:2]
                )
            )
            feeds = Feed.objects.filter(
                pk__in=range(f, f + 10), active=True, active_subscribers__gte=subscribers
            ).values_list("pk")
            for (feed_id,) in feeds:
                Feed.objects.get(pk=feed_id).index_feed_for_search()

    def index_feed_for_search(self):
        min_subscribers = 1
        if settings.DEBUG:
            min_subscribers = 0
        if self.num_subscribers > min_subscribers and not self.branch_from_feed and not self.is_newsletter:
            SearchFeed.index(
                feed_id=self.pk,
                title=self.feed_title,
                address=self.feed_address,
                link=self.feed_link,
                num_subscribers=self.num_subscribers,
                content_vector=SearchFeed.generate_feed_content_vector(self.pk),
            )

    def index_stories_for_search(self, force=False):
        if self.search_indexed and not force:
            return

        stories = MStory.objects(story_feed_id=self.pk)
        for story in stories:
            story.index_story_for_search()

        self.search_indexed = True
        self.save()

    def index_stories_for_discover(self, force=False):
        if self.discover_indexed and not force:
            return

        # If there are no premium archive subscribers, don't index stories for discover.
        if not self.archive_subscribers or self.archive_subscribers <= 0:
            logging.debug(f" ---> ~FBNo premium archive subscribers, skipping discover index for {self}")
            return

        stories = MStory.objects(story_feed_id=self.pk)
        for index, story in enumerate(stories):
            if index % 100 == 0:
                logging.debug(f" ---> ~FBIndexing discover story {index} of {len(stories)} in {self}")
            story.index_story_for_discover()

        self.discover_indexed = True
        self.save()

    def sync_redis(self, allow_skip_resync=False):
        return MStory.sync_feed_redis(self.pk, allow_skip_resync=allow_skip_resync)

    def expire_redis(self, r=None):
        if not r:
            r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)

        r.expire("F:%s" % self.pk, self.days_of_story_hashes * 24 * 60 * 60)
        r.expire("zF:%s" % self.pk, self.days_of_story_hashes * 24 * 60 * 60)

    @classmethod
    def low_volume_feeds(cls, feed_ids, stories_per_month=30):
        try:
            stories_per_month = int(stories_per_month)
        except ValueError:
            stories_per_month = 30
        feeds = Feed.objects.filter(pk__in=feed_ids, average_stories_per_month__lte=stories_per_month).only(
            "pk"
        )

        return [f.pk for f in feeds]

    @classmethod
    def autocomplete(self, prefix, limit=5):
        results = SearchFeed.query(prefix)
        feed_ids = [result["_source"]["feed_id"] for result in results[:5]]

        # results = SearchQuerySet().autocomplete(address=prefix).order_by('-num_subscribers')[:limit]
        #
        # if len(results) < limit:
        #     results += SearchQuerySet().autocomplete(title=prefix).order_by('-num_subscribers')[:limit-len(results)]
        #
        return feed_ids

    @classmethod
    def find_or_create(cls, feed_address, feed_link, defaults=None, **kwargs):
        feeds = cls.objects.filter(feed_address=feed_address, feed_link=feed_link)
        if feeds:
            return feeds[0], False

        if feed_link and feed_link.endswith("/"):
            feeds = cls.objects.filter(feed_address=feed_address, feed_link=feed_link[:-1])
            if feeds:
                return feeds[0], False

        try:
            feed = cls.objects.get(feed_address=feed_address, feed_link=feed_link)
            return feed, False
        except cls.DoesNotExist:
            feed = cls(**defaults)
            feed = feed.save()
            return feed, True

    @classmethod
    def merge_feeds(cls, *args, **kwargs):
        return merge_feeds(*args, **kwargs)

    def fix_google_alerts_urls(self):
        if self.feed_address.startswith("http://user/") and "/state/com.google/alerts/" in self.feed_address:
            match = re.match(r"http://user/(\d+)/state/com.google/alerts/(\d+)", self.feed_address)
            if match:
                user_id, alert_id = match.groups()
                self.feed_address = "http://www.google.com/alerts/feeds/%s/%s" % (user_id, alert_id)

    def set_is_forbidden(self):
        self.is_forbidden = True
        self.date_forbidden = datetime.datetime.now()

        return self.save()

    @classmethod
    def schedule_feed_fetches_immediately(cls, feed_ids, user_id=None):
        if settings.DEBUG:
            logging.info(
                " ---> ~SN~FMSkipping the scheduling immediate fetch of ~SB%s~SN feeds (in DEBUG)..."
                % len(feed_ids)
            )
            return

        if user_id:
            user = User.objects.get(pk=user_id)
            logging.user(user, "~SN~FMScheduling immediate fetch of ~SB%s~SN feeds..." % len(feed_ids))
        else:
            logging.debug(" ---> ~SN~FMScheduling immediate fetch of ~SB%s~SN feeds..." % len(feed_ids))

        if len(feed_ids) > 100:
            logging.debug(" ---> ~SN~FMFeeds scheduled: %s" % feed_ids)
        day_ago = datetime.datetime.now() - datetime.timedelta(days=1)
        feeds = Feed.objects.filter(pk__in=feed_ids)
        for feed in feeds:
            if feed.active_subscribers <= 0:
                feed.count_subscribers()
            if not feed.active or feed.next_scheduled_update < day_ago:
                feed.schedule_feed_fetch_immediately(verbose=False)

    @property
    def favicon_fetching(self):
        return bool(not (self.favicon_not_found or self.favicon_color))

    @classmethod
    def get_feed_by_url(self, *args, **kwargs):
        return self.get_feed_from_url(*args, **kwargs)

    @classmethod
    def get_feed_from_url(
        cls, url, create=True, aggressive=False, fetch=True, offset=0, user=None, interactive=False
    ):
        feed = None
        without_rss = False
        original_url = url

        if url and url.startswith("newsletter:"):
            try:
                return cls.objects.get(feed_address=url)
            except cls.MultipleObjectsReturned:
                return cls.objects.filter(feed_address=url)[0]
        if url and re.match("(https?://)?twitter.com/\w+/?", url):
            without_rss = True
        if url and re.match(r"(https?://)?(www\.)?facebook.com/\w+/?$", url):
            without_rss = True
        # Turn url @username@domain.com into domain.com/users/username.rss
        if url and url.startswith("@") and "@" in url[1:]:
            username, domain = url[1:].split("@")
            url = f"https://{domain}/users/{username}.rss"
        if url and "youtube.com/user/" in url:
            username = re.search("youtube.com/user/(\w+)", url).group(1)
            url = "http://gdata.youtube.com/feeds/base/users/%s/uploads" % username
            without_rss = True
        if url and "youtube.com/@" in url:
            username = url.split("youtube.com/@")[1]
            url = "http://gdata.youtube.com/feeds/base/users/%s/uploads" % username
            without_rss = True
        if url and "youtube.com/channel/" in url:
            channel_id = re.search("youtube.com/channel/([-_\w]+)", url).group(1)
            url = "https://www.youtube.com/feeds/videos.xml?channel_id=%s" % channel_id
            without_rss = True
        if url and "youtube.com/feeds" in url:
            without_rss = True
        if url and "youtube.com/playlist" in url:
            without_rss = True

        def criteria(key, value):
            if aggressive:
                return {"%s__icontains" % key: value}
            else:
                return {"%s" % key: value}

        def by_url(address):
            feed = (
                cls.objects.filter(branch_from_feed=None)
                .filter(**criteria("feed_address", address))
                .order_by("-num_subscribers")
            )
            logging.debug(f" ---> Feeds found by address: {feed}")
            if not feed:
                duplicate_feed = DuplicateFeed.objects.filter(**criteria("duplicate_address", address))
                if duplicate_feed and len(duplicate_feed) > offset:
                    feed = [duplicate_feed[offset].feed]
                logging.debug(
                    f" ---> Feeds found by duplicate address: {duplicate_feed} {feed} (offset: {offset})"
                )
            if not feed and aggressive:
                feed = (
                    cls.objects.filter(branch_from_feed=None)
                    .filter(**criteria("feed_link", address))
                    .order_by("-num_subscribers")
                )
                logging.debug(f" ---> Feeds found by link: {feed}")

            return feed

        @timelimit(10)
        def _feedfinder_forman(url):
            found_feed_urls = feedfinder_forman.find_feeds(url)
            logging.debug(f" ---> Feeds found by forman: {found_feed_urls}")
            return found_feed_urls

        @timelimit(10)
        def _feedfinder_pilgrim(url):
            found_feed_urls = feedfinder_pilgrim.feeds(url)
            logging.debug(f" ---> Feeds found by pilgrim: {found_feed_urls}")
            return found_feed_urls

        # Normalize and check for feed_address, dupes, and feed_link
        url = urlnorm.normalize(url)
        if not url:
            logging.debug(" ---> ~FRCouldn't normalize url: ~SB%s" % url)
            return

        feed = by_url(url)
        found_feed_urls = []

        if interactive:
            import pdb

            pdb.set_trace()

        # Create if it looks good
        if feed and len(feed) > offset:
            feed = feed[offset]
        else:
            try:
                found_feed_urls = _feedfinder_forman(url)
            except TimeoutError:
                logging.debug("   ---> Feed finder timed out...")
                found_feed_urls = []
            if not found_feed_urls:
                try:
                    found_feed_urls = _feedfinder_pilgrim(url)
                except TimeoutError:
                    logging.debug("   ---> Feed finder old timed out...")
                    found_feed_urls = []

            if len(found_feed_urls):
                feed_finder_url = found_feed_urls[0]
                logging.debug(" ---> Found feed URLs for %s: %s" % (url, found_feed_urls))
                feed = by_url(feed_finder_url)
                if feed and len(feed) > offset:
                    feed = feed[offset]
                    logging.debug(" ---> Feed exists (%s), updating..." % (feed))
                    feed = feed.update()
                elif create:
                    logging.debug(" ---> Feed doesn't exist, creating: %s" % (feed_finder_url))
                    feed = cls.objects.create(feed_address=feed_finder_url)
                    feed = feed.update()
            elif without_rss:
                logging.debug(" ---> Found without_rss feed: %s / %s" % (url, original_url))
                feed = cls.objects.create(feed_address=url, feed_link=original_url)
                feed = feed.update(requesting_user_id=user.pk if user else None)

        # Check for JSON feed
        if not feed and fetch and create:
            try:
                r = requests.get(url)
            except (requests.ConnectionError, requests.models.InvalidURL):
                r = None
            if r and "application/json" in r.headers.get("Content-Type"):
                feed = cls.objects.create(feed_address=url)
                feed = feed.update()

        # Still nothing? Maybe the URL has some clues.
        if not feed and fetch and len(found_feed_urls):
            feed_finder_url = found_feed_urls[0]
            feed = by_url(feed_finder_url)
            if not feed and create:
                feed = cls.objects.create(feed_address=feed_finder_url)
                feed = feed.update()
            elif feed and len(feed) > offset:
                feed = feed[offset]

        # Not created and not within bounds, so toss results.
        if isinstance(feed, QuerySet):
            logging.debug(" ---> ~FRNot created and not within bounds, tossing: ~SB%s" % feed)
            return

        return feed

    @classmethod
    def task_feeds(cls, feeds, queue_size=12, verbose=True):
        if not feeds:
            return
        r = redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)

        if isinstance(feeds, Feed):
            if verbose:
                logging.debug(" ---> ~SN~FBTasking feed: ~SB%s" % feeds)
            feeds = [feeds.pk]
        elif verbose:
            logging.debug(" ---> ~SN~FBTasking ~SB~FC%s~FB~SN feeds..." % len(feeds))

        if isinstance(feeds, QuerySet):
            feeds = [f.pk for f in feeds]

        r.srem("queued_feeds", *feeds)
        now = datetime.datetime.now().strftime("%s")
        p = r.pipeline()
        for feed_id in feeds:
            p.zadd("tasked_feeds", {feed_id: now})
        p.execute()

        # for feed_ids in (feeds[pos:pos + queue_size] for pos in xrange(0, len(feeds), queue_size)):
        for feed_id in feeds:
            UpdateFeeds.apply_async(args=(feed_id,), queue="update_feeds")

    @classmethod
    def drain_task_feeds(cls):
        r = redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)

        tasked_feeds = r.zrange("tasked_feeds", 0, -1)
        if tasked_feeds:
            logging.debug(" ---> ~FRDraining %s tasked feeds..." % len(tasked_feeds))
            r.sadd("queued_feeds", *tasked_feeds)
            r.zremrangebyrank("tasked_feeds", 0, -1)
        else:
            logging.debug(" ---> No tasked feeds to drain")

        errored_feeds = r.zrange("error_feeds", 0, -1)
        if errored_feeds:
            logging.debug(" ---> ~FRDraining %s errored feeds..." % len(errored_feeds))
            r.sadd("queued_feeds", *errored_feeds)
            r.zremrangebyrank("error_feeds", 0, -1)
        else:
            logging.debug(" ---> No errored feeds to drain")

    def update_all_statistics(self, has_new_stories=False, force=False, delay_fetch_sec=None):
        recount = not self.counts_converted_to_redis
        count_extra = False
        if random.random() < 0.01 or not self.data.popular_tags or not self.data.popular_authors:
            count_extra = True

        self.count_subscribers(recount=recount)
        self.calculate_last_story_date()

        # if force or count_extra:
        #     self.count_similar_feeds()

        if force or has_new_stories or count_extra:
            self.save_feed_stories_last_month()

        if not self.fs_size_bytes or not self.archive_count:
            self.count_fs_size_bytes()

        if force or (has_new_stories and count_extra):
            self.save_popular_authors()
            self.save_popular_tags()
            self.save_feed_story_history_statistics()

        self.set_next_scheduled_update(delay_fetch_sec=delay_fetch_sec)

    def calculate_last_story_date(self):
        last_story_date = None

        try:
            latest_story = (
                MStory.objects(story_feed_id=self.pk)
                .limit(1)
                .order_by("-story_date")
                .only("story_date")
                .first()
            )
            if latest_story:
                last_story_date = latest_story.story_date
        except MStory.DoesNotExist:
            pass

        if not last_story_date or seconds_timesince(last_story_date) < 0:
            last_story_date = datetime.datetime.now()

        if last_story_date != self.last_story_date:
            self.last_story_date = last_story_date
            self.save(update_fields=["last_story_date"])

    @classmethod
    def setup_feeds_for_premium_subscribers(cls, feed_ids):
        logging.info(f" ---> ~SN~FMScheduling immediate premium setup of ~SB{len(feed_ids)}~SN feeds...")

        feeds = Feed.objects.filter(pk__in=feed_ids)
        for feed in feeds:
            feed.setup_feed_for_premium_subscribers()

    def setup_feed_for_premium_subscribers(self, allow_skip_resync=False):
        self.count_subscribers()
        self.count_similar_feeds()
        self.set_next_scheduled_update()
        self.sync_redis(allow_skip_resync=allow_skip_resync)

    def schedule_fetch_archive_feed(self):
        from apps.profile.tasks import FetchArchiveFeedsChunk

        logging.debug(f"~FC~SBScheduling fetch of archive feed ~SB{self.log_title}")
        FetchArchiveFeedsChunk.apply_async(
            kwargs=dict(feed_ids=[self.pk]),
            queue="search_indexer",
            time_limit=settings.MAX_SECONDS_ARCHIVE_FETCH_SINGLE_FEED,
        )

    def check_feed_link_for_feed_address(self):
        # Skip checking test fixtures with placeholder paths
        if "%(NEWSBLUR_DIR)s" in self.feed_address:
            return False, self

        @timelimit(10)
        def _1():
            feed_address = None
            feed = self
            found_feed_urls = []
            try:
                logging.debug(" ---> Checking: %s" % self.feed_address)
                found_feed_urls = feedfinder_forman.find_feeds(self.feed_address)
                if found_feed_urls:
                    feed_address = found_feed_urls[0]
            except KeyError:
                pass
            if not len(found_feed_urls) and self.feed_link:
                found_feed_urls = feedfinder_forman.find_feeds(self.feed_link)
                if len(found_feed_urls) and found_feed_urls[0] != self.feed_address:
                    feed_address = found_feed_urls[0]

            if feed_address:
                if any(
                    ignored_domain in feed_address
                    for ignored_domain in [
                        "feedburner.com/atom.xml",
                        "feedburner.com/feed/",
                        "feedsportal.com",
                    ]
                ):
                    logging.debug("  ---> Feed points to 'Wierdo' or 'feedsportal', ignoring.")
                    return False, self
                try:
                    self.feed_address = strip_underscore_from_feed_address(feed_address)
                    feed = self.save()
                    feed.count_subscribers()
                    # feed.schedule_feed_fetch_immediately() # Don't fetch as it can get stuck in a loop
                    feed.has_feed_exception = False
                    feed.active = True
                    feed = feed.save()
                except IntegrityError:
                    original_feed = Feed.objects.get(feed_address=feed_address, feed_link=self.feed_link)
                    original_feed.has_feed_exception = False
                    original_feed.active = True
                    original_feed.save()
                    merge_feeds(original_feed.pk, self.pk)
            return feed_address, feed

        if self.feed_address_locked:
            return False, self

        try:
            feed_address, feed = _1()
        except TimeoutError as e:
            logging.debug("   ---> [%-30s] Feed address check timed out..." % (self.log_title[:30]))
            self.save_feed_history(505, "Timeout", e)
            feed = self
            feed_address = None

        return bool(feed_address), feed

    def save_feed_history(self, status_code, message, exception=None, date=None):
        fetch_history = MFetchHistory.add(
            feed_id=self.pk,
            fetch_type="feed",
            code=int(status_code),
            date=date,
            message=message,
            exception=exception,
        )

        if status_code not in (200, 304):
            self.errors_since_good += 1
            self.count_errors_in_history("feed", status_code, fetch_history=fetch_history)
            self.set_next_scheduled_update()
        elif self.has_feed_exception or self.errors_since_good:
            self.errors_since_good = 0
            self.has_feed_exception = False
            self.active = True
            self.save()

    def save_page_history(self, status_code, message, exception=None, date=None):
        fetch_history = MFetchHistory.add(
            feed_id=self.pk,
            fetch_type="page",
            code=int(status_code),
            date=date,
            message=message,
            exception=exception,
        )

        if status_code not in (200, 304):
            self.count_errors_in_history("page", status_code, fetch_history=fetch_history)
        elif self.has_page_exception or not self.has_page:
            self.has_page_exception = False
            self.has_page = True
            self.active = True
            self.save()

    def save_raw_feed(self, raw_feed, fetch_date):
        MFetchHistory.add(feed_id=self.pk, fetch_type="raw_feed", code=200, message=raw_feed, date=fetch_date)

    def count_errors_in_history(self, exception_type="feed", status_code=None, fetch_history=None):
        if not fetch_history:
            fetch_history = MFetchHistory.feed(self.pk)
        fh = fetch_history[exception_type + "_fetch_history"]
        non_errors = [h for h in fh if h["status_code"] and int(h["status_code"]) in (200, 304)]
        errors = [h for h in fh if h["status_code"] and int(h["status_code"]) not in (200, 304)]

        if len(non_errors) == 0 and len(errors) > 1:
            self.active = True
            if exception_type == "feed":
                self.has_feed_exception = True
                # self.active = False # No longer, just geometrically fetch
            elif exception_type == "page":
                self.has_page_exception = True
            self.exception_code = status_code or int(errors[0])
            self.save()
        elif self.exception_code > 0:
            self.active = True
            self.exception_code = 0
            if exception_type == "feed":
                self.has_feed_exception = False
            elif exception_type == "page":
                self.has_page_exception = False
            self.save()

        logging.debug(
            "   ---> [%-30s] ~FBCounting any errors in history: %s (%s non errors)"
            % (self.log_title[:30], len(errors), len(non_errors))
        )

        return errors, non_errors

    def count_redirects_in_history(self, fetch_type="feed", fetch_history=None):
        logging.debug("   ---> [%-30s] Counting redirects in history..." % (self.log_title[:30]))
        if not fetch_history:
            fetch_history = MFetchHistory.feed(self.pk)
        fh = fetch_history[fetch_type + "_fetch_history"]
        redirects = [h for h in fh if h["status_code"] and int(h["status_code"]) in (301, 302)]
        non_redirects = [h for h in fh if h["status_code"] and int(h["status_code"]) not in (301, 302)]

        return redirects, non_redirects

    @property
    def original_feed_id(self):
        if self.branch_from_feed:
            return self.branch_from_feed.pk
        else:
            return self.pk

    @property
    def counts_converted_to_redis(self):
        SUBSCRIBER_EXPIRE_DATE = datetime.datetime.now() - datetime.timedelta(days=settings.SUBSCRIBER_EXPIRE)
        subscriber_expire = int(SUBSCRIBER_EXPIRE_DATE.strftime("%s"))
        r = redis.Redis(connection_pool=settings.REDIS_FEED_SUB_POOL)
        total_key = "s:%s" % self.original_feed_id
        premium_key = "sp:%s" % self.original_feed_id
        last_recount = r.zscore(total_key, -1)  # Need to subtract this extra when counting subs

        # Check for expired feeds with no active users who would have triggered a cleanup
        if last_recount and last_recount > subscriber_expire:
            return True
        elif last_recount:
            logging.info(
                "   ---> [%-30s] ~SN~FBFeed has expired redis subscriber counts (%s < %s), clearing..."
                % (self.log_title[:30], last_recount, subscriber_expire)
            )
            r.delete(total_key, -1)
            r.delete(premium_key, -1)

        return False

    def count_subscribers(self, recount=True, verbose=False):
        if recount or not self.counts_converted_to_redis:
            from apps.profile.models import Profile

            Profile.count_feed_subscribers(feed_id=self.pk)
        SUBSCRIBER_EXPIRE_DATE = datetime.datetime.now() - datetime.timedelta(days=settings.SUBSCRIBER_EXPIRE)
        subscriber_expire = int(SUBSCRIBER_EXPIRE_DATE.strftime("%s"))
        now = int(datetime.datetime.now().strftime("%s"))
        r = redis.Redis(connection_pool=settings.REDIS_FEED_SUB_POOL)
        total = 0
        active = 0
        premium = 0
        archive = 0
        pro = 0
        active_premium = 0

        # Include all branched feeds in counts
        feed_ids = [f["id"] for f in Feed.objects.filter(branch_from_feed=self.original_feed_id).values("id")]
        feed_ids.append(self.original_feed_id)
        feed_ids = list(set(feed_ids))

        if self.counts_converted_to_redis:
            # For each branched feed, count different subscribers
            for feed_id in feed_ids:
                pipeline = r.pipeline()

                # now+1 ensures `-1` flag will be corrected for later with - 1
                total_key = "s:%s" % feed_id
                premium_key = "sp:%s" % feed_id
                archive_key = "sarchive:%s" % feed_id
                pro_key = "spro:%s" % feed_id
                pipeline.zcard(total_key)
                pipeline.zcount(total_key, subscriber_expire, now + 1)
                pipeline.zcard(premium_key)
                pipeline.zcount(premium_key, subscriber_expire, now + 1)
                pipeline.zcard(archive_key)
                pipeline.zcard(pro_key)

                results = pipeline.execute()

                # -1 due to counts_converted_to_redis using key=-1 for last_recount date
                total += max(0, results[0] - 1)
                active += max(0, results[1] - 1)
                premium += max(0, results[2] - 1)
                active_premium += max(0, results[3] - 1)
                archive += max(0, results[4] - 1)
                pro += max(0, results[5] - 1)

            original_num_subscribers = self.num_subscribers
            original_active_subs = self.active_subscribers
            original_premium_subscribers = self.premium_subscribers
            original_active_premium_subscribers = self.active_premium_subscribers
            original_archive_subscribers = self.archive_subscribers
            original_pro_subscribers = self.pro_subscribers
            logging.info(
                "   ---> [%-30s] ~SN~FBCounting subscribers from ~FCredis~FB: ~FMt:~SB~FM%s~SN a:~SB%s~SN p:~SB%s~SN ap:~SB%s~SN archive:~SB%s~SN pro:~SB%s ~SN~FC%s"
                % (
                    self.log_title[:30],
                    total,
                    active,
                    premium,
                    active_premium,
                    archive,
                    pro,
                    "(%s branches)" % (len(feed_ids) - 1) if len(feed_ids) > 1 else "",
                )
            )
        else:
            from apps.reader.models import UserSubscription

            subs = UserSubscription.objects.filter(feed__in=feed_ids)
            original_num_subscribers = self.num_subscribers
            total = subs.count()

            active_subs = UserSubscription.objects.filter(
                feed__in=feed_ids, active=True, user__profile__last_seen_on__gte=SUBSCRIBER_EXPIRE_DATE
            )
            original_active_subs = self.active_subscribers
            active = active_subs.count()

            premium_subs = UserSubscription.objects.filter(
                feed__in=feed_ids, active=True, user__profile__is_premium=True
            )
            original_premium_subscribers = self.premium_subscribers
            premium = premium_subs.count()

            archive_subs = UserSubscription.objects.filter(
                feed__in=feed_ids, active=True, user__profile__is_archive=True
            )
            original_archive_subscribers = self.archive_subscribers
            archive = archive_subs.count()

            pro_subs = UserSubscription.objects.filter(
                feed__in=feed_ids, active=True, user__profile__is_pro=True
            )
            original_pro_subscribers = self.pro_subscribers
            pro = pro_subs.count()

            active_premium_subscribers = UserSubscription.objects.filter(
                feed__in=feed_ids,
                active=True,
                user__profile__is_premium=True,
                user__profile__last_seen_on__gte=SUBSCRIBER_EXPIRE_DATE,
            )
            original_active_premium_subscribers = self.active_premium_subscribers
            active_premium = active_premium_subscribers.count()
            logging.debug(
                "   ---> [%-30s] ~SN~FBCounting subscribers from ~FYpostgres~FB: ~FMt:~SB~FM%s~SN a:~SB%s~SN p:~SB%s~SN ap:~SB%s~SN archive:~SB%s~SN pro:~SB%s"
                % (self.log_title[:30], total, active, premium, active_premium, archive, pro)
            )

        if settings.DOCKERBUILD:
            # Local installs enjoy 100% active feeds
            active = total

        # If any counts have changed, save them
        self.num_subscribers = total
        self.active_subscribers = active
        self.premium_subscribers = premium
        self.active_premium_subscribers = active_premium
        self.archive_subscribers = archive
        self.pro_subscribers = pro
        if (
            self.num_subscribers != original_num_subscribers
            or self.active_subscribers != original_active_subs
            or self.premium_subscribers != original_premium_subscribers
            or self.active_premium_subscribers != original_active_premium_subscribers
            or self.archive_subscribers != original_archive_subscribers
            or self.pro_subscribers != original_pro_subscribers
        ):
            if original_premium_subscribers == -1 or original_active_premium_subscribers == -1:
                self.save()
            else:
                self.save(
                    update_fields=[
                        "num_subscribers",
                        "active_subscribers",
                        "premium_subscribers",
                        "active_premium_subscribers",
                        "archive_subscribers",
                        "pro_subscribers",
                    ]
                )

        if verbose:
            if self.num_subscribers <= 1:
                print(".", end=" ")
            else:
                print(
                    "\n %s> %s subscriber%s: %s"
                    % (
                        "-" * min(self.num_subscribers, 20),
                        self.num_subscribers,
                        "" if self.num_subscribers == 1 else "s",
                        self.feed_title,
                    ),
                    end=" ",
                )

    def count_similar_feeds(self, feed_ids=None, force=False, offset=0, limit=5):
        if not force and self.similar_feeds.count() and offset == 0:
            logging.debug(f"Found {self.similar_feeds.count()} cached similar feeds for {self}")
            return self.similar_feeds.all()[:limit]

        if not feed_ids:
            feed_ids = [self.pk]
        if self.pk not in feed_ids:
            feed_ids.append(self.pk)

        results = self.find_similar_feeds(feed_ids=feed_ids, offset=offset, limit=limit)

        similar_feeds = []
        if offset == 0:
            feed_ids = [result["_source"]["feed_id"] for result in results]
            similar_feeds = Feed.objects.filter(pk__in=feed_ids).distinct("feed_title")
            try:
                self.similar_feeds.set(similar_feeds)
            except IntegrityError:
                logging.debug(f" ---> ~FRIntegrity error adding similar feed: {feed_ids}")
                pass
        else:
            feed_ids = [result["_source"]["feed_id"] for result in results]
            similar_feeds = Feed.objects.filter(pk__in=feed_ids).distinct("feed_title")
            if self.similar_feeds.count() < 5:
                self.similar_feeds.add(*similar_feeds[: 5 - self.similar_feeds.count()])
        return similar_feeds

    @classmethod
    def find_similar_feeds(cls, feed_ids=None, offset=0, limit=5):
        combined_content_vector = SearchFeed.generate_combined_feed_content_vector(feed_ids)
        results = SearchFeed.vector_query(
            combined_content_vector, feed_ids_to_exclude=feed_ids, offset=offset, max_results=limit
        )
        logging.debug(
            f"Found {len(results)} recommendations for feeds {feed_ids}: {[r['_id'] for r in results]}"
        )

        return results

    def _split_favicon_color(self, color=None):
        if not color:
            color = self.favicon_color
        if not color:
            return None, None, None
        splitter = lambda s, p: [s[i : i + p] for i in range(0, len(s), p)]
        red, green, blue = splitter(color[:6], 2)
        return red, green, blue

    def favicon_fade(self):
        return self.adjust_color(adjust=30)

    def adjust_color(self, color=None, adjust=0):
        red, green, blue = self._split_favicon_color(color=color)
        if red and green and blue:
            fade_red = hex(min(int(red, 16) + adjust, 255))[2:].zfill(2)
            fade_green = hex(min(int(green, 16) + adjust, 255))[2:].zfill(2)
            fade_blue = hex(min(int(blue, 16) + adjust, 255))[2:].zfill(2)
            return "%s%s%s" % (fade_red, fade_green, fade_blue)

    def favicon_border(self):
        red, green, blue = self._split_favicon_color()
        if red and green and blue:
            fade_red = hex(min(int(int(red, 16) * 0.75), 255))[2:].zfill(2)
            fade_green = hex(min(int(int(green, 16) * 0.75), 255))[2:].zfill(2)
            fade_blue = hex(min(int(int(blue, 16) * 0.75), 255))[2:].zfill(2)
            return "%s%s%s" % (fade_red, fade_green, fade_blue)

    def favicon_text_color(self):
        # Color format: {r: 1, g: .5, b: 0}
        def contrast(color1, color2):
            lum1 = luminosity(color1)
            lum2 = luminosity(color2)
            if lum1 > lum2:
                return (lum1 + 0.05) / (lum2 + 0.05)
            else:
                return (lum2 + 0.05) / (lum1 + 0.05)

        def luminosity(color):
            r = color["red"]
            g = color["green"]
            b = color["blue"]
            val = lambda c: c / 12.92 if c <= 0.02928 else math.pow(((c + 0.055) / 1.055), 2.4)
            red = val(r)
            green = val(g)
            blue = val(b)
            return 0.2126 * red + 0.7152 * green + 0.0722 * blue

        red, green, blue = self._split_favicon_color()
        if red and green and blue:
            color = {
                "red": int(red, 16) / 256.0,
                "green": int(green, 16) / 256.0,
                "blue": int(blue, 16) / 256.0,
            }
            white = {
                "red": 1,
                "green": 1,
                "blue": 1,
            }
            grey = {
                "red": 0.5,
                "green": 0.5,
                "blue": 0.5,
            }

            if contrast(color, white) > contrast(color, grey):
                return "white"
            else:
                return "black"

    def fill_out_archive_stories(self, force=False, starting_page=1):
        """
        Starting from page 1 and iterating through N pages, determine whether
        page(i) matches page(i-1) and if there are any new stories.
        """
        before_story_count = MStory.objects(story_feed_id=self.pk).count()

        if not force and not self.archive_subscribers:
            logging.debug(
                "   ---> [%-30s] ~FBNot filling out archive stories, no archive subscribers"
                % (self.log_title[:30])
            )
            return before_story_count, before_story_count

        self.update(archive_page=starting_page)

        after_story_count = MStory.objects(story_feed_id=self.pk).count()
        logging.debug(
            "   ---> [%-30s] ~FCFilled out archive, ~FM~SB%s~SN new stories~FC, total of ~SB%s~SN stories"
            % (self.log_title[:30], after_story_count - before_story_count, after_story_count)
        )

    def save_feed_stories_last_month(self, verbose=False):
        month_ago = datetime.datetime.utcnow() - datetime.timedelta(days=30)
        stories_last_month = MStory.objects(story_feed_id=self.pk, story_date__gte=month_ago).count()
        if self.stories_last_month != stories_last_month:
            self.stories_last_month = stories_last_month
            self.save(update_fields=["stories_last_month"])

        if verbose:
            print(f"  ---> {self.feed} [{self.pk}]: {self.stories_last_month} stories last month")

    def save_feed_story_history_statistics(self, current_counts=None):
        """
        Fills in missing months between earlier occurances and now.

        Save format: [('YYYY-MM, #), ...]
        Example output: [(2010-12, 123), (2011-01, 146)]
        """
        now = datetime.datetime.utcnow()
        min_year = now.year
        total = 0
        month_count = 0
        if not current_counts:
            current_counts = self.data.story_count_history and json.decode(self.data.story_count_history)

        if isinstance(current_counts, dict):
            current_counts = current_counts["months"]

        if not current_counts:
            current_counts = []

        # Count stories, aggregate by year and month. Map Reduce!
        map_f = """
            function() {
                var date = (this.story_date.getFullYear()) + "-" + (this.story_date.getMonth()+1);
                var hour = this.story_date.getUTCHours();
                var day = this.story_date.getDay();
                emit(this.story_hash, {'month': date, 'hour': hour, 'day': day});
            }
        """
        reduce_f = """
            function(key, values) {
                return values;
            }
        """
        dates = defaultdict(int)
        hours = defaultdict(int)
        days = defaultdict(int)
        results = MStory.objects(story_feed_id=self.pk).map_reduce(map_f, reduce_f, output="inline")
        for result in results:
            dates[result.value["month"]] += 1
            hours[int(result.value["hour"])] += 1
            days[int(result.value["day"])] += 1
            year = int(re.findall(r"(\d{4})-\d{1,2}", result.value["month"])[0])
            if year < min_year and year > 2000:
                min_year = year

        # Add on to existing months, always amending up, never down. (Current month
        # is guaranteed to be accurate, since trim_feeds won't delete it until after
        # a month. Hacker News can have 1,000+ and still be counted.)
        for current_month, current_count in current_counts:
            year = int(re.findall(r"(\d{4})-\d{1,2}", current_month)[0])
            if current_month not in dates or dates[current_month] < current_count:
                dates[current_month] = current_count
            if year < min_year and year > 2000:
                min_year = year

        # Assemble a list with 0's filled in for missing months,
        # trimming left and right 0's.
        months = []
        start = False
        for year in range(min_year, now.year + 1):
            for month in range(1, 12 + 1):
                if datetime.datetime(year, month, 1) < now:
                    key = "%s-%s" % (year, month)
                    if dates.get(key) or start:
                        start = True
                        months.append((key, dates.get(key, 0)))
                        total += dates.get(key, 0)
                        if dates.get(key, 0) > 0:
                            month_count += 1  # Only count months that have stories for the average
        original_story_count_history = self.data.story_count_history
        self.data.story_count_history = json.encode({"months": months, "hours": hours, "days": days})
        if self.data.story_count_history != original_story_count_history:
            self.data.save(update_fields=["story_count_history"])

        original_average_stories_per_month = self.average_stories_per_month
        if not total or not month_count:
            self.average_stories_per_month = 0
        else:
            self.average_stories_per_month = int(round(total / float(month_count)))
        if self.average_stories_per_month != original_average_stories_per_month:
            self.save(update_fields=["average_stories_per_month"])

    def save_classifier_counts(self):
        from apps.analyzer.models import (
            MClassifierAuthor,
            MClassifierFeed,
            MClassifierTag,
            MClassifierTitle,
        )

        def calculate_scores(cls, facet):
            map_f = """
                function() {
                    emit(this["%s"], {
                        pos: this.score>0 ? this.score : 0, 
                        neg: this.score<0 ? Math.abs(this.score) : 0
                    });
                }
            """ % (
                facet
            )
            reduce_f = """
                function(key, values) {
                    var result = {pos: 0, neg: 0};
                    values.forEach(function(value) {
                        result.pos += value.pos;
                        result.neg += value.neg;
                    });
                    return result;
                }
            """
            scores = []
            res = cls.objects(feed_id=self.pk).map_reduce(map_f, reduce_f, output="inline")
            for r in res:
                facet_values = dict([(k, int(v)) for k, v in r.value.items()])
                facet_values[facet] = r.key
                if facet_values["pos"] + facet_values["neg"] >= 1:
                    scores.append(facet_values)
            scores = sorted(scores, key=lambda v: v["neg"] - v["pos"])

            return scores

        scores = {}
        for cls, facet in [
            (MClassifierTitle, "title"),
            (MClassifierAuthor, "author"),
            (MClassifierTag, "tag"),
            (MClassifierFeed, "feed_id"),
        ]:
            scores[facet] = calculate_scores(cls, facet)
            if facet == "feed_id" and scores[facet]:
                scores["feed"] = scores[facet]
                del scores["feed_id"]
            elif not scores[facet]:
                del scores[facet]

        if scores:
            self.data.feed_classifier_counts = json.encode(scores)
            self.data.save()

        return scores

    @property
    def user_agent(self):
        feed_parts = urllib.parse.urlparse(self.feed_address)
        if feed_parts.netloc.find(".tumblr.com") != -1:
            # Certain tumblr feeds will redirect to tumblr's login page when fetching.
            # A known workaround is using facebook's user agent.
            return "facebookexternalhit/1.0 (+http://www.facebook.com/externalhit_uatext.php)"

        ua = "NewsBlur Feed Fetcher - %s subscriber%s - %s %s" % (
            self.num_subscribers,
            "s" if self.num_subscribers != 1 else "",
            self.permalink,
            self.fake_user_agent,
        )

        return ua

    @property
    def fake_user_agent(self):
        ua = (
            '("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
            "AppleWebKit/605.1.15 (KHTML, like Gecko) "
            'Version/14.0.1 Safari/605.1.15")'
        )

        return ua

    def fetch_headers(self, fake=False):
        headers = {
            "User-Agent": self.user_agent if not fake else self.fake_user_agent,
            "Accept": "application/atom+xml, application/rss+xml, application/xml;q=0.8, text/xml;q=0.6, */*;q=0.2",
            "Accept-Encoding": "gzip, deflate",
        }

        return headers

    def update(self, **kwargs):
        try:
            from utils import feed_fetcher
        except ImportError as e:
            logging.info(" ***> ~BR~FRImportError: %s" % e)
            return
        r = redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)
        original_feed_id = int(self.pk)

        options = {
            "verbose": kwargs.get("verbose"),
            "timeout": 10,
            "single_threaded": kwargs.get("single_threaded", True),
            "force": kwargs.get("force"),
            "force_fp": kwargs.get("force_fp"),
            "compute_scores": kwargs.get("compute_scores", True),
            "mongodb_replication_lag": kwargs.get("mongodb_replication_lag", None),
            "fake": kwargs.get("fake"),
            "quick": kwargs.get("quick"),
            "updates_off": kwargs.get("updates_off"),
            "debug": kwargs.get("debug"),
            "fpf": kwargs.get("fpf"),
            "feed_xml": kwargs.get("feed_xml"),
            "requesting_user_id": kwargs.get("requesting_user_id", None),
            "archive_page": kwargs.get("archive_page", None),
        }

        if getattr(settings, "TEST_DEBUG", False) and "NEWSBLUR_DIR" in self.feed_address:
            print(" ---> Testing feed fetch: %s" % self.log_title)
            # options['force_fp'] = True # No, why would this be needed?
            original_feed_address = self.feed_address
            original_feed_link = self.feed_link
            self.feed_address = self.feed_address.replace("%(NEWSBLUR_DIR)s", settings.NEWSBLUR_DIR)
            if self.feed_link:
                self.feed_link = self.feed_link.replace("%(NEWSBLUR_DIR)s", settings.NEWSBLUR_DIR)
            if self.feed_address != original_feed_address or self.feed_link != original_feed_link:
                self.save(update_fields=["feed_address", "feed_link"])

        if self.is_newsletter:
            feed = self.update_newsletter_icon()
        else:
            disp = feed_fetcher.Dispatcher(options, 1)
            disp.add_jobs([[self.pk]])
            feed = disp.run_jobs()

        if feed:
            feed = Feed.get_by_id(feed.pk)
        if feed:
            feed.last_update = datetime.datetime.utcnow()
            feed.set_next_scheduled_update()
            r.zadd("fetched_feeds_last_hour", {feed.pk: int(datetime.datetime.now().strftime("%s"))})

        if not feed or original_feed_id != feed.pk:
            logging.info(
                " ---> ~FRFeed changed id, removing %s from tasked_feeds queue..." % original_feed_id
            )
            r.zrem("tasked_feeds", original_feed_id)
            r.zrem("error_feeds", original_feed_id)
        if feed:
            r.zrem("tasked_feeds", feed.pk)
            r.zrem("error_feeds", feed.pk)

        return feed

    def update_newsletter_icon(self):
        from apps.rss_feeds.icon_importer import IconImporter

        icon_importer = IconImporter(self)
        icon_importer.save()

        return self

    @classmethod
    def get_by_id(cls, feed_id, feed_address=None):
        try:
            feed = Feed.objects.get(pk=feed_id)
            return feed
        except Feed.DoesNotExist:
            # Feed has been merged after updating. Find the right feed.
            duplicate_feeds = DuplicateFeed.objects.filter(duplicate_feed_id=feed_id)
            if duplicate_feeds:
                return duplicate_feeds[0].feed
            if feed_address:
                duplicate_feeds = DuplicateFeed.objects.filter(duplicate_address=feed_address)
                if duplicate_feeds:
                    return duplicate_feeds[0].feed

    @classmethod
    def get_by_name(cls, query, limit=1):
        results = SearchFeed.query(query)
        feed_ids = [result.feed_id for result in results]

        if limit == 1:
            return Feed.get_by_id(feed_ids[0])
        else:
            return [Feed.get_by_id(f) for f in feed_ids][:limit]

    def add_update_stories(self, stories, existing_stories, verbose=False, updates_off=False):
        ret_values = dict(new=0, updated=0, same=0, error=0)
        error_count = self.error_count
        new_story_hashes = [s.get("story_hash") for s in stories]
        discover_story_ids = []

        if settings.DEBUG or verbose:
            logging.debug(
                "   ---> [%-30s] ~FBChecking ~SB%s~SN new/updated against ~SB%s~SN stories"
                % (self.log_title[:30], len(stories), len(list(existing_stories.keys())))
            )

        @timelimit(5)
        def _1(story, story_content, existing_stories, new_story_hashes):
            existing_story, story_has_changed = self._exists_story(
                story, story_content, existing_stories, new_story_hashes
            )
            return existing_story, story_has_changed

        for story in stories:
            if verbose:
                logging.debug(
                    "   ---> [%-30s] ~FBChecking ~SB%s~SN / ~SB%s"
                    % (self.log_title[:30], story.get("title"), story.get("guid"))
                )

            story_content = story.get("story_content")
            if error_count:
                story_content = strip_comments__lxml(story_content)
            else:
                story_content = strip_comments(story_content)
            story_tags = self.get_tags(story)
            story_link = self.get_permalink(story)
            replace_story_date = False

            try:
                existing_story, story_has_changed = _1(
                    story, story_content, existing_stories, new_story_hashes
                )
            except TimeoutError:
                logging.debug(
                    "   ---> [%-30s] ~SB~FRExisting story check timed out..." % (self.log_title[:30])
                )
                existing_story = None
                story_has_changed = False

            if existing_story is None:
                if settings.DEBUG and verbose:
                    logging.debug(
                        "   ---> New story in feed (%s - %s): %s"
                        % (self.feed_title, story.get("title"), len(story_content))
                    )

                s = MStory(
                    story_feed_id=self.pk,
                    story_date=story.get("published"),
                    story_title=story.get("title"),
                    story_content=story_content,
                    story_author_name=story.get("author"),
                    story_permalink=story_link,
                    story_guid=story.get("guid"),
                    story_tags=story_tags,
                )
                try:
                    s.save()
                    ret_values["new"] += 1
                    s.publish_to_subscribers()
                except (IntegrityError, OperationError) as e:
                    ret_values["error"] += 1
                    if settings.DEBUG:
                        logging.info(
                            "   ---> [%-30s] ~SN~FRIntegrityError on new story: %s - %s"
                            % (self.feed_title[:30], story.get("guid"), e)
                        )
                if self.search_indexed and s:
                    s.index_story_for_search()
                if s and s.story_hash:
                    discover_story_ids.append(s.story_hash)
            elif existing_story and story_has_changed and not updates_off and ret_values["updated"] < 3:
                # update story
                original_content = None
                try:
                    if existing_story and existing_story.id:
                        try:
                            existing_story = MStory.objects.get(id=existing_story.id)
                        except ValidationError:
                            existing_story, _ = MStory.find_story(
                                existing_story.story_feed_id, existing_story.id, original_only=True
                            )
                    elif existing_story and existing_story.story_hash:
                        existing_story, _ = MStory.find_story(
                            existing_story.story_feed_id, existing_story.story_hash, original_only=True
                        )
                    else:
                        raise MStory.DoesNotExist
                except (MStory.DoesNotExist, OperationError) as e:
                    ret_values["error"] += 1
                    if verbose:
                        logging.info(
                            "   ---> [%-30s] ~SN~FROperation on existing story: %s - %s"
                            % (self.feed_title[:30], story.get("guid"), e)
                        )
                    continue
                if existing_story.story_original_content_z:
                    original_content = zlib.decompress(existing_story.story_original_content_z)
                elif existing_story.story_content_z:
                    original_content = zlib.decompress(existing_story.story_content_z)
                if story_content and len(story_content) > 10:
                    if "<code" in story_content:
                        # Don't mangle stories with code, just use new
                        story_content_diff = story_content
                    else:
                        story_content_diff = htmldiff(smart_str(original_content), smart_str(story_content))
                else:
                    story_content_diff = original_content
                # logging.debug("\t\tDiff: %s %s %s" % diff.getStats())
                # logging.debug("\t\tDiff content: %s" % diff.getDiff())
                # if existing_story.story_title != story.get('title'):
                #    logging.debug('\tExisting title / New: : \n\t\t- %s\n\t\t- %s' % (existing_story.story_title, story.get('title')))
                if existing_story.story_hash != story.get("story_hash"):
                    self.update_story_with_new_guid(existing_story, story.get("guid"))

                if verbose:
                    logging.debug(
                        "- Updated story in feed (%s - %s): %s / %s"
                        % (self.feed_title, story.get("title"), len(story_content_diff), len(story_content))
                    )

                existing_story.story_feed = self.pk
                existing_story.story_title = story.get("title")
                existing_story.story_content = story_content_diff
                existing_story.story_latest_content = story_content
                existing_story.story_original_content = original_content
                existing_story.story_author_name = story.get("author")
                existing_story.story_permalink = story_link
                existing_story.story_guid = story.get("guid")
                existing_story.story_tags = story_tags
                existing_story.original_text_z = None  # Reset Text view cache
                # Do not allow publishers to change the story date once a story is published.
                # Leads to incorrect unread story counts.
                if replace_story_date:
                    existing_story.story_date = story.get("published")  # Really shouldn't do this.
                existing_story.extract_image_urls(force=True)
                try:
                    existing_story.save()
                    ret_values["updated"] += 1
                except (IntegrityError, OperationError):
                    ret_values["error"] += 1
                    if verbose:
                        logging.info(
                            "   ---> [%-30s] ~SN~FRIntegrityError on updated story: %s"
                            % (self.feed_title[:30], story.get("title")[:30])
                        )
                except ValidationError:
                    ret_values["error"] += 1
                    if verbose:
                        logging.info(
                            "   ---> [%-30s] ~SN~FRValidationError on updated story: %s"
                            % (self.feed_title[:30], story.get("title")[:30])
                        )
                if self.search_indexed:
                    existing_story.index_story_for_search()
                if existing_story.story_hash:
                    discover_story_ids.append(existing_story.story_hash)
            else:
                ret_values["same"] += 1
                if verbose:
                    logging.debug(
                        "Unchanged story (%s): %s / %s "
                        % (story.get("story_hash"), story.get("guid"), story.get("title"))
                    )

        # If there are no premium archive subscribers, don't index stories for discover.
        if discover_story_ids:
            if self.archive_subscribers and self.archive_subscribers > 0:
                # IndexDiscoverStories.apply_async(
                # Run immediately
                IndexDiscoverStories.apply(
                    kwargs=dict(story_ids=discover_story_ids),
                    queue="discover_indexer",
                    time_limit=settings.MAX_SECONDS_ARCHIVE_FETCH_SINGLE_FEED,
                )
            else:
                logging.debug(
                    f" ---> ~FBNo premium archive subscribers, skipping discover indexing for {discover_story_ids} for {self}"
                )

        return ret_values

    def update_story_with_new_guid(self, existing_story, new_story_guid):
        from apps.reader.models import RUserStory
        from apps.social.models import MSharedStory

        existing_story.remove_from_redis()
        existing_story.remove_from_search_index()

        old_hash = existing_story.story_hash
        new_hash = MStory.ensure_story_hash(new_story_guid, self.pk)
        RUserStory.switch_hash(feed=self, old_hash=old_hash, new_hash=new_hash)

        shared_stories = MSharedStory.objects.filter(story_feed_id=self.pk, story_hash=old_hash)
        for story in shared_stories:
            story.story_guid = new_story_guid
            story.story_hash = new_hash
            try:
                story.save()
            except NotUniqueError:
                # Story is already shared, skip.
                pass

    def save_popular_tags(self, feed_tags=None, verbose=False):
        if not feed_tags:
            all_tags = MStory.objects(story_feed_id=self.pk, story_tags__exists=True).item_frequencies(
                "story_tags"
            )
            feed_tags = sorted(
                [(k, v) for k, v in list(all_tags.items()) if int(v) > 0], key=itemgetter(1), reverse=True
            )[:25]
        popular_tags = json.encode(feed_tags)
        if verbose:
            print("Found %s tags: %s" % (len(feed_tags), popular_tags))

        # TODO: This len() bullshit will be gone when feeds move to mongo
        #       On second thought, it might stay, because we don't want
        #       popular tags the size of a small planet. I'm looking at you
        #       Tumblr writers.
        if len(popular_tags) < 1024:
            if self.data.popular_tags != popular_tags:
                self.data.popular_tags = popular_tags
                self.data.save(update_fields=["popular_tags"])
            return

        tags_list = []
        if feed_tags and isinstance(feed_tags, str):
            tags_list = json.decode(feed_tags)
        if len(tags_list) >= 1:
            self.save_popular_tags(tags_list[:-1])

    def save_popular_authors(self, feed_authors=None):
        if not feed_authors:
            authors = defaultdict(int)
            for story in MStory.objects(story_feed_id=self.pk).only("story_author_name"):
                authors[story.story_author_name] += 1
            feed_authors = sorted(
                [(k, v) for k, v in list(authors.items()) if k], key=itemgetter(1), reverse=True
            )[:20]

        popular_authors = json.encode(feed_authors)
        if len(popular_authors) < 1023:
            if self.data.popular_authors != popular_authors:
                self.data.popular_authors = popular_authors
                self.data.save(update_fields=["popular_authors"])
            return

        if len(feed_authors) > 1:
            self.save_popular_authors(feed_authors=feed_authors[:-1])

    @classmethod
    def trim_old_stories(cls, start=0, verbose=True, dryrun=False, total=0, end=None):
        now = datetime.datetime.now()
        month_ago = now - datetime.timedelta(days=settings.DAYS_OF_STORY_HASHES)
        feed_count = end or Feed.objects.latest("pk").pk

        for feed_id in range(start, feed_count):
            if feed_id % 1000 == 0:
                print(
                    "\n\n -------------------------- %s (%s deleted so far) --------------------------\n\n"
                    % (feed_id, total)
                )
            try:
                feed = Feed.objects.get(pk=feed_id)
            except Feed.DoesNotExist:
                continue
            # Ensure only feeds with no active subscribers are being trimmed
            if (
                feed.active_subscribers <= 0
                and (not feed.archive_subscribers or feed.archive_subscribers <= 0)
                and (not feed.last_story_date or feed.last_story_date < month_ago)
            ):
                # 1 month since last story = keep 5 stories, >6 months since, only keep 1 story
                months_ago = 6
                if feed.last_story_date:
                    months_ago = int((now - feed.last_story_date).days / 30.0)
                cutoff = max(1, 6 - months_ago)
                if dryrun:
                    print(" DRYRUN: %s cutoff - %s" % (cutoff, feed))
                else:
                    total += MStory.trim_feed(feed=feed, cutoff=cutoff, verbose=verbose)
            else:
                if dryrun:
                    print(" DRYRUN: %s/%s cutoff - %s" % (cutoff, feed.story_cutoff, feed))
                else:
                    total += feed.trim_feed(verbose=verbose)

        print(" ---> Deleted %s stories in total." % total)

    @property
    def story_cutoff(self):
        return self.number_of_stories_to_store()

    def number_of_stories_to_store(self, pre_archive=False):
        if self.archive_subscribers and self.archive_subscribers > 0 and not pre_archive:
            return 10000

        cutoff = 500
        if self.active_subscribers <= 0:
            cutoff = 25
        elif self.active_premium_subscribers < 1:
            cutoff = 100
        elif self.active_premium_subscribers <= 2:
            cutoff = 200
        elif self.active_premium_subscribers <= 5:
            cutoff = 300
        elif self.active_premium_subscribers <= 10:
            cutoff = 350
        elif self.active_premium_subscribers <= 15:
            cutoff = 400
        elif self.active_premium_subscribers <= 20:
            cutoff = 450

        if self.active_subscribers and self.average_stories_per_month < 5 and self.stories_last_month < 5:
            cutoff /= 2
        if (
            self.active_premium_subscribers <= 1
            and self.average_stories_per_month <= 1
            and self.stories_last_month <= 1
        ):
            cutoff /= 2

        r = redis.Redis(connection_pool=settings.REDIS_FEED_READ_POOL)
        pipeline = r.pipeline()
        read_stories_per_week = []
        now = datetime.datetime.now()

        # Check to see how many stories have been read each week since the feed's days of story hashes
        for weeks_back in range(2 * int(math.floor(settings.DAYS_OF_STORY_HASHES / 7))):
            weeks_ago = now - datetime.timedelta(days=7 * weeks_back)
            week_of_year = weeks_ago.strftime("%Y-%U")
            feed_read_key = "fR:%s:%s" % (self.pk, week_of_year)
            pipeline.get(feed_read_key)
        read_stories_per_week = pipeline.execute()
        read_stories_last_month = sum([int(rs) for rs in read_stories_per_week if rs])
        if not pre_archive and read_stories_last_month == 0:
            original_cutoff = cutoff
            cutoff = min(cutoff, 10)
            try:
                logging.debug(
                    "   ---> [%-30s] ~FBTrimming down to ~SB%s (instead of %s)~SN stories (~FM%s~FB)"
                    % (
                        self.log_title[:30],
                        cutoff,
                        original_cutoff,
                        (
                            self.last_story_date.strftime("%Y-%m-%d")
                            if self.last_story_date
                            else "No last story date"
                        ),
                    )
                )
            except ValueError as e:
                logging.debug("   ***> [%-30s] Error trimming: %s" % (self.log_title[:30], e))
                pass

        if getattr(settings, "OVERRIDE_STORY_COUNT_MAX", None):
            cutoff = settings.OVERRIDE_STORY_COUNT_MAX

        return int(cutoff)

    def trim_feed(self, verbose=False, cutoff=None):
        if not cutoff:
            cutoff = self.story_cutoff

        stories_removed = MStory.trim_feed(feed=self, cutoff=cutoff, verbose=verbose)

        if not self.fs_size_bytes:
            self.count_fs_size_bytes()

        return stories_removed

    def count_fs_size_bytes(self):
        stories = MStory.objects.filter(story_feed_id=self.pk)
        sum_bytes = 0
        count = 0

        for story in stories:
            count += 1
            story_with_content = story.to_mongo()
            if story_with_content.get("story_content_z", None):
                story_with_content["story_content"] = zlib.decompress(story_with_content["story_content_z"])
                del story_with_content["story_content_z"]
            if story_with_content.get("original_page_z", None):
                story_with_content["original_page"] = zlib.decompress(story_with_content["original_page_z"])
                del story_with_content["original_page_z"]
            if story_with_content.get("original_text_z", None):
                story_with_content["original_text"] = zlib.decompress(story_with_content["original_text_z"])
                del story_with_content["original_text_z"]
            if story_with_content.get("story_latest_content_z", None):
                story_with_content["story_latest_content"] = zlib.decompress(
                    story_with_content["story_latest_content_z"]
                )
                del story_with_content["story_latest_content_z"]
            if story_with_content.get("story_original_content_z", None):
                story_with_content["story_original_content"] = zlib.decompress(
                    story_with_content["story_original_content_z"]
                )
                del story_with_content["story_original_content_z"]
            sum_bytes += len(bson.BSON.encode(story_with_content))

        self.fs_size_bytes = sum_bytes
        self.archive_count = count
        self.save()

        return sum_bytes

    def purge_feed_stories(self, update=True):
        MStory.purge_feed_stories(feed=self, cutoff=self.story_cutoff)
        if update:
            self.update()

    def purge_author(self, author):
        all_stories = MStory.objects.filter(story_feed_id=self.pk)
        author_stories = MStory.objects.filter(story_feed_id=self.pk, story_author_name__iexact=author)
        logging.debug(
            " ---> Deleting %s of %s stories in %s by '%s'."
            % (author_stories.count(), all_stories.count(), self, author)
        )
        author_stories.delete()

    def purge_tag(self, tag):
        all_stories = MStory.objects.filter(story_feed_id=self.pk)
        tagged_stories = MStory.objects.filter(story_feed_id=self.pk, story_tags__icontains=tag)
        logging.debug(
            " ---> Deleting %s of %s stories in %s by '%s'."
            % (tagged_stories.count(), all_stories.count(), self, tag)
        )
        tagged_stories.delete()

    # @staticmethod
    # def clean_invalid_ids():
    #     history = MFeedFetchHistory.objects(status_code=500, exception__contains='InvalidId:')
    #     urls = set()
    #     for h in history:
    #         u = re.split('InvalidId: (.*?) is not a valid ObjectId\\n$', h.exception)[1]
    #         urls.add((h.feed_id, u))
    #
    #     for f, u in urls:
    #         print "db.stories.remove({\"story_feed_id\": %s, \"_id\": \"%s\"})" % (f, u)

    def get_stories(self, offset=0, limit=25, order="newest", force=False):
        if order == "newest":
            stories_db = MStory.objects(story_feed_id=self.pk)[offset : offset + limit]
        elif order == "oldest":
            stories_db = MStory.objects(story_feed_id=self.pk).order_by("story_date")[offset : offset + limit]
        stories = self.format_stories(stories_db, self.pk)

        return stories

    @classmethod
    def find_feed_stories(cls, feed_ids, query, order="newest", offset=0, limit=25):
        story_ids = SearchStory.query(feed_ids=feed_ids, query=query, order=order, offset=offset, limit=limit)
        stories_db = MStory.objects(story_hash__in=story_ids).order_by(
            "-story_date" if order == "newest" else "story_date"
        )
        stories = cls.format_stories(stories_db)

        return stories

    @classmethod
    def query_popularity(cls, query, limit, order="newest"):
        popularity = {}
        seen_feeds = set()
        feed_title_to_id = dict()

        # Collect stories, sort by feed
        story_ids = SearchStory.global_query(query, order=order, offset=0, limit=limit)
        for story_hash in story_ids:
            feed_id, story_id = MStory.split_story_hash(story_hash)
            feed = Feed.get_by_id(feed_id)
            if not feed:
                continue
            if feed.feed_title in seen_feeds:
                feed_id = feed_title_to_id[feed.feed_title]
            else:
                feed_title_to_id[feed.feed_title] = feed_id
            seen_feeds.add(feed.feed_title)
            if feed_id not in popularity:
                # feed.update_all_statistics()
                # classifiers = feed.save_classifier_counts()
                well_read_score = feed.well_read_score()
                popularity[feed_id] = {
                    "feed_title": feed.feed_title,
                    "feed_url": feed.feed_link,
                    "num_subscribers": feed.num_subscribers,
                    "feed_id": feed.pk,
                    "story_ids": [],
                    "authors": {},
                    "read_pct": well_read_score["read_pct"],
                    "reader_count": well_read_score["reader_count"],
                    "story_count": well_read_score["story_count"],
                    "reach_score": well_read_score["reach_score"],
                    "share_count": well_read_score["share_count"],
                    "ps": 0,
                    "ng": 0,
                    "classifiers": json.decode(feed.data.feed_classifier_counts),
                }
                if popularity[feed_id]["classifiers"]:
                    for classifier in popularity[feed_id]["classifiers"].get("feed", []):
                        if int(classifier["feed_id"]) == int(feed_id):
                            popularity[feed_id]["ps"] = classifier["pos"]
                            popularity[feed_id]["ng"] = -1 * classifier["neg"]
            popularity[feed_id]["story_ids"].append(story_hash)

        sorted_popularity = sorted(list(popularity.values()), key=lambda x: x["reach_score"], reverse=True)

        # Extract story authors from feeds
        for feed in sorted_popularity:
            story_ids = feed["story_ids"]
            stories_db = MStory.objects(story_hash__in=story_ids)
            stories = cls.format_stories(stories_db)
            for story in stories:
                story["story_permalink"] = story["story_permalink"][:250]
                if story["story_authors"] not in feed["authors"]:
                    feed["authors"][story["story_authors"]] = {
                        "name": story["story_authors"],
                        "count": 0,
                        "ps": 0,
                        "ng": 0,
                        "tags": {},
                        "stories": [],
                    }
                author = feed["authors"][story["story_authors"]]
                seen = False
                for seen_story in author["stories"]:
                    if seen_story["url"] == story["story_permalink"]:
                        seen = True
                        break
                else:
                    author["stories"].append(
                        {
                            "title": story["story_title"],
                            "url": story["story_permalink"],
                            "date": story["story_date"],
                        }
                    )
                    author["count"] += 1
                if seen:
                    continue  # Don't recount tags

                if feed["classifiers"]:
                    for classifier in feed["classifiers"].get("author", []):
                        if classifier["author"] == author["name"]:
                            author["ps"] = classifier["pos"]
                            author["ng"] = -1 * classifier["neg"]

                for tag in story["story_tags"]:
                    if tag not in author["tags"]:
                        author["tags"][tag] = {"name": tag, "count": 0, "ps": 0, "ng": 0}
                    author["tags"][tag]["count"] += 1
                    if feed["classifiers"]:
                        for classifier in feed["classifiers"].get("tag", []):
                            if classifier["tag"] == tag:
                                author["tags"][tag]["ps"] = classifier["pos"]
                                author["tags"][tag]["ng"] = -1 * classifier["neg"]

            sorted_authors = sorted(list(feed["authors"].values()), key=lambda x: x["count"])
            feed["authors"] = sorted_authors

        # pprint(sorted_popularity)
        return sorted_popularity

    def well_read_score(self, user_id=None):
        """Average percentage of stories read vs published across recently active subscribers"""
        from apps.reader.models import UserSubscription
        from apps.social.models import MSharedStory

        r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
        p = r.pipeline()

        shared_stories = MSharedStory.objects(story_feed_id=self.pk).count()

        subscribing_users = UserSubscription.objects.filter(feed_id=self.pk).values("user_id")
        subscribing_user_ids = [sub["user_id"] for sub in subscribing_users]

        for sub_user_id in subscribing_user_ids:
            if user_id and sub_user_id != user_id:
                continue
            user_rs = "RS:%s:%s" % (user_id, self.pk)
            p.scard(user_rs)

        counts = p.execute()
        counts = [c for c in counts if c > 0]
        reader_count = len(counts)

        now = datetime.datetime.now().strftime("%s")
        unread_cutoff = self.unread_cutoff.strftime("%s")
        story_count = len(r.zrangebyscore("zF:%s" % self.pk, max=now, min=unread_cutoff))
        if reader_count and story_count:
            average_pct = (sum(counts) / float(reader_count)) / float(story_count)
        else:
            average_pct = 0

        reach_score = round(average_pct * reader_count * story_count)

        return {
            "read_pct": average_pct,
            "reader_count": reader_count,
            "reach_score": reach_score,
            "story_count": story_count,
            "share_count": shared_stories,
        }

    @classmethod
    def xls_query_popularity(cls, queries, limit):
        import xlsxwriter
        from xlsxwriter.utility import xl_rowcol_to_cell

        if isinstance(queries, str):
            queries = [q.strip() for q in queries.split(",")]

        title = "NewsBlur-%s.xlsx" % slugify("-".join(queries))
        workbook = xlsxwriter.Workbook(title)
        bold = workbook.add_format({"bold": 1})
        date_format = workbook.add_format({"num_format": "mmm d yyyy"})
        unread_format = workbook.add_format({"font_color": "#E0E0E0"})

        for query in queries:
            worksheet = workbook.add_worksheet(query)
            row = 1
            col = 0
            worksheet.write(0, col, "Publisher", bold)
            worksheet.set_column(col, col, 15)
            col += 1
            worksheet.write(0, col, "Feed URL", bold)
            worksheet.set_column(col, col, 20)
            col += 1
            worksheet.write(0, col, "Reach score", bold)
            worksheet.write_comment(
                0,
                col,
                "Feeds are sorted based on this score. It's simply the # of readers * # of stories in the past 30 days * the percentage of stories that are actually read.",
            )
            worksheet.set_column(col, col, 9)
            col += 1
            worksheet.write(0, col, "# subs", bold)
            worksheet.write_comment(0, col, "Total number of subscribers on NewsBlur, not necessarily active")
            worksheet.set_column(col, col, 5)
            col += 1
            worksheet.write(0, col, "# readers", bold)
            worksheet.write_comment(
                0,
                col,
                "Total number of active subscribers who have read a story from the feed in the past 30 days.",
            )
            worksheet.set_column(col, col, 8)
            col += 1
            worksheet.write(0, col, "read pct", bold)
            worksheet.write_comment(
                0,
                col,
                "Of the active subscribers reading this feed in the past 30 days, this is the percentage of stories the average subscriber reads. Values over 100 pct signify that the feed has many shared stories, which throws off the number slightly but not significantly.",
            )
            worksheet.set_column(col, col, 8)
            col += 1
            worksheet.write(0, col, "# stories 30d", bold)
            worksheet.write_comment(
                0,
                col,
                "It's important to ignore feeds that haven't published anything in the last 30 days, which is why this is part of the Reach Score.",
            )
            worksheet.set_column(col, col, 10)
            col += 1
            worksheet.write(0, col, "# shared", bold)
            worksheet.write_comment(
                0,
                col,
                "Number of stories from this feed that were shared on NewsBlur. This is a strong signal of interest although it is not included in the Reach Score.",
            )
            worksheet.set_column(col, col, 7)
            col += 1
            worksheet.write(0, col, "# feed pos", bold)
            worksheet.write_comment(
                0,
                col,
                "Number of times this feed was trained with a thumbs up. Users use training to hide stories they don't want to see while highlighting those that they do.",
            )
            worksheet.set_column(col, col, 8)
            col += 1
            worksheet.write(0, col, "# feed neg", bold)
            worksheet.write_comment(
                0,
                col,
                "Number of times this feed was trained with a thumbs down. Users use training to hide stories they don't want to see while highlighting those that they do.",
            )
            worksheet.set_column(col, col, 8)
            col += 1
            worksheet.write(0, col, "Author", bold)
            worksheet.set_column(col, col, 15)
            col += 1
            worksheet.write(0, col, "# author pos", bold)
            worksheet.write_comment(
                0,
                col,
                "Number of times this author was trained with a thumbs up. Users use training to hide stories they don't want to see while highlighting those that they do.",
            )
            worksheet.set_column(col, col, 10)
            col += 1
            worksheet.write(0, col, "# author neg", bold)
            worksheet.write_comment(
                0,
                col,
                "Number of times this author was trained with a thumbs down. Users use training to hide stories they don't want to see while highlighting those that they do.",
            )
            worksheet.set_column(col, col, 10)
            col += 1
            worksheet.write(0, col, "Story title", bold)
            worksheet.set_column(col, col, 30)
            col += 1
            worksheet.write(0, col, "Story URL", bold)
            worksheet.set_column(col, col, 20)
            col += 1
            worksheet.write(0, col, "Story date", bold)
            worksheet.set_column(col, col, 10)
            col += 1
            worksheet.write(0, col, "Tag", bold)
            worksheet.set_column(col, col, 15)
            col += 1
            worksheet.write(0, col, "Tag count", bold)
            worksheet.write_comment(
                0,
                col,
                "Number of times this tag is used in other stories that also contain the search query.",
            )
            worksheet.set_column(col, col, 8)
            col += 1
            worksheet.write(0, col, "# tag pos", bold)
            worksheet.write_comment(
                0,
                col,
                "Number of times this tag was trained with a thumbs up. Users use training to hide stories they don't want to see while highlighting those that they do.",
            )
            worksheet.set_column(col, col, 7)
            col += 1
            worksheet.write(0, col, "# tag neg", bold)
            worksheet.write_comment(
                0,
                col,
                "Number of times this tag was trained with a thumbs down. Users use training to hide stories they don't want to see while highlighting those that they do.",
            )
            worksheet.set_column(col, col, 7)
            col += 1
            popularity = cls.query_popularity(query, limit=limit)

            for feed in popularity:
                col = 0
                worksheet.write(row, col, feed["feed_title"])
                col += 1
                worksheet.write_url(row, col, feed.get("feed_url") or "")
                col += 1
                worksheet.conditional_format(
                    row,
                    col,
                    row,
                    col + 8,
                    {"type": "cell", "criteria": "==", "value": 0, "format": unread_format},
                )
                worksheet.write(
                    row,
                    col,
                    "=%s*%s*%s"
                    % (
                        xl_rowcol_to_cell(row, col + 2),
                        xl_rowcol_to_cell(row, col + 3),
                        xl_rowcol_to_cell(row, col + 4),
                    ),
                )
                col += 1
                worksheet.write(row, col, feed["num_subscribers"])
                col += 1
                worksheet.write(row, col, feed["reader_count"])
                col += 1
                worksheet.write(row, col, feed["read_pct"])
                col += 1
                worksheet.write(row, col, feed["story_count"])
                col += 1
                worksheet.write(row, col, feed["share_count"])
                col += 1
                worksheet.write(row, col, feed["ps"])
                col += 1
                worksheet.write(row, col, feed["ng"])
                col += 1
                for author in feed["authors"]:
                    row += 1
                    worksheet.conditional_format(
                        row,
                        col,
                        row,
                        col + 2,
                        {"type": "cell", "criteria": "==", "value": 0, "format": unread_format},
                    )
                    worksheet.write(row, col, author["name"])
                    worksheet.write(row, col + 1, author["ps"])
                    worksheet.write(row, col + 2, author["ng"])
                    for story in author["stories"]:
                        worksheet.write(row, col + 3, story["title"])
                        worksheet.write_url(row, col + 4, story["url"])
                        worksheet.write_datetime(row, col + 5, story["date"], date_format)
                        row += 1
                    for tag in list(author["tags"].values()):
                        worksheet.conditional_format(
                            row,
                            col + 7,
                            row,
                            col + 9,
                            {"type": "cell", "criteria": "==", "value": 0, "format": unread_format},
                        )
                        worksheet.write(row, col + 6, tag["name"])
                        worksheet.write(row, col + 7, tag["count"])
                        worksheet.write(row, col + 8, tag["ps"])
                        worksheet.write(row, col + 9, tag["ng"])
                        row += 1
        workbook.close()
        return title

    def find_stories(self, query, order="newest", offset=0, limit=25):
        story_ids = SearchStory.query(
            feed_ids=[self.pk], query=query, order=order, offset=offset, limit=limit
        )
        stories_db = MStory.objects(story_hash__in=story_ids).order_by(
            "-story_date" if order == "newest" else "story_date"
        )

        stories = self.format_stories(stories_db, self.pk)

        return stories

    @classmethod
    def format_stories(cls, stories_db, feed_id=None, include_permalinks=False):
        stories = []

        for story_db in stories_db:
            story = cls.format_story(story_db, feed_id, include_permalinks=include_permalinks)
            stories.append(story)

        return stories

    @classmethod
    def format_story(cls, story_db, feed_id=None, text=False, include_permalinks=False, show_changes=False):
        if isinstance(story_db.story_content_z, str):
            story_db.story_content_z = base64.b64decode(story_db.story_content_z)

        story_content = ""
        latest_story_content = None
        has_changes = False
        if (
            not show_changes
            and hasattr(story_db, "story_latest_content_z")
            and story_db.story_latest_content_z
        ):
            try:
                latest_story_content = smart_str(zlib.decompress(story_db.story_latest_content_z))
            except DjangoUnicodeDecodeError:
                latest_story_content = zlib.decompress(story_db.story_latest_content_z)
        if story_db.story_content_z:
            story_content = smart_str(zlib.decompress(story_db.story_content_z))

        if "<ins" in story_content or "<del" in story_content:
            has_changes = True
        if not show_changes and latest_story_content:
            story_content = latest_story_content

        story_title = story_db.story_title
        blank_story_title = False
        if not story_title:
            blank_story_title = True
            if story_content:
                story_title = strip_tags(story_content)
            if not story_title and story_db.story_permalink:
                story_title = story_db.story_permalink
            if story_title and len(story_title) > 80:
                story_title = story_title[:80] + "..."

        story = {}
        story["story_hash"] = getattr(story_db, "story_hash", None)
        story["story_tags"] = story_db.story_tags or []
        story["story_date"] = story_db.story_date.replace(tzinfo=None)
        story["story_timestamp"] = story_db.story_date.strftime("%s")
        story["story_authors"] = story_db.story_author_name or ""
        story["story_title"] = story_title
        if blank_story_title:
            story["story_title_blank"] = True
        story["story_content"] = story_content
        story["story_permalink"] = story_db.story_permalink
        story["image_urls"] = story_db.image_urls
        story["secure_image_urls"] = cls.secure_image_urls(story_db.image_urls)
        story["secure_image_thumbnails"] = cls.secure_image_thumbnails(story_db.image_urls)
        story["story_feed_id"] = feed_id or story_db.story_feed_id
        story["has_modifications"] = has_changes
        story["comment_count"] = story_db.comment_count if hasattr(story_db, "comment_count") else 0
        story["comment_user_ids"] = story_db.comment_user_ids if hasattr(story_db, "comment_user_ids") else []
        story["share_count"] = story_db.share_count if hasattr(story_db, "share_count") else 0
        story["share_user_ids"] = story_db.share_user_ids if hasattr(story_db, "share_user_ids") else []
        story["guid_hash"] = story_db.guid_hash if hasattr(story_db, "guid_hash") else None
        if hasattr(story_db, "source_user_id"):
            story["source_user_id"] = story_db.source_user_id
        story["id"] = story_db.story_guid or story_db.story_date
        if hasattr(story_db, "starred_date"):
            story["starred_date"] = story_db.starred_date
        if hasattr(story_db, "user_tags"):
            story["user_tags"] = story_db.user_tags
        if hasattr(story_db, "user_notes"):
            story["user_notes"] = story_db.user_notes
        if hasattr(story_db, "highlights"):
            story["highlights"] = story_db.highlights
        if hasattr(story_db, "shared_date"):
            story["shared_date"] = story_db.shared_date
        if hasattr(story_db, "comments"):
            story["comments"] = story_db.comments
        if hasattr(story_db, "user_id"):
            story["user_id"] = story_db.user_id
        if include_permalinks and hasattr(story_db, "blurblog_permalink"):
            story["blurblog_permalink"] = story_db.blurblog_permalink()
        if text:
            soup = BeautifulSoup(story["story_content"], features="lxml")
            text = "".join(soup.findAll(text=True))
            text = re.sub(r"\n+", "\n\n", text)
            text = re.sub(r"\t+", "\t", text)
            story["text"] = text

        return story

    @classmethod
    def secure_image_urls(cls, urls):
        signed_urls = [
            create_imageproxy_signed_url(settings.IMAGES_URL, settings.IMAGES_SECRET_KEY, url) for url in urls
        ]
        return dict(zip(urls, signed_urls))

    @classmethod
    def secure_image_thumbnails(cls, urls, size=192):
        signed_urls = [
            create_imageproxy_signed_url(settings.IMAGES_URL, settings.IMAGES_SECRET_KEY, url, size)
            for url in urls
        ]
        return dict(zip(urls, signed_urls))

    def get_tags(self, entry):
        fcat = []
        if "tags" in entry:
            for tcat in entry.tags:
                term = None
                if hasattr(tcat, "label") and tcat.label:
                    term = tcat.label
                elif hasattr(tcat, "term") and tcat.term:
                    term = tcat.term
                if not term or "CDATA" in term:
                    continue
                qcat = term.strip()
                if "," in qcat or "/" in qcat:
                    qcat = qcat.replace(",", "/").split("/")
                else:
                    qcat = [qcat]
                for zcat in qcat:
                    tagname = zcat.lower()
                    while "  " in tagname:
                        tagname = tagname.replace("  ", " ")
                    tagname = tagname.strip()
                    if not tagname or tagname == " ":
                        continue
                    fcat.append(tagname)
        fcat = [strip_tags(t)[:250] for t in fcat[:12]]
        return fcat

    @classmethod
    def get_permalink(cls, entry):
        link = entry.get("link")
        if not link:
            links = entry.get("links")
            if links:
                link = links[0].get("href")
        if not link:
            link = entry.get("id")
        return link

    def _exists_story(self, story, story_content, existing_stories, new_story_hashes, lightweight=False):
        story_in_system = None
        story_has_changed = False
        story_link = self.get_permalink(story)
        existing_stories_hashes = list(existing_stories.keys())
        story_pub_date = story.get("published")
        # story_published_now = story.get('published_now', False)
        # start_date = story_pub_date - datetime.timedelta(hours=8)
        # end_date = story_pub_date + datetime.timedelta(hours=8)

        for existing_story in list(existing_stories.values()):
            content_ratio = 0
            # existing_story_pub_date = existing_story.story_date

            if isinstance(existing_story.id, str):
                # Correcting a MongoDB bug
                existing_story.story_guid = existing_story.id

            if story.get("story_hash") == existing_story.story_hash:
                story_in_system = existing_story
            elif (
                story.get("story_hash") in existing_stories_hashes
                and story.get("story_hash") != existing_story.story_hash
            ):
                # Story already exists but is not this one
                continue
            elif (
                existing_story.story_hash in new_story_hashes
                and story.get("story_hash") != existing_story.story_hash
            ):
                # Story coming up later
                continue

            if "story_latest_content_z" in existing_story:
                existing_story_content = smart_str(zlib.decompress(existing_story.story_latest_content_z))
            elif "story_latest_content" in existing_story:
                existing_story_content = existing_story.story_latest_content
            elif "story_content_z" in existing_story:
                existing_story_content = smart_str(zlib.decompress(existing_story.story_content_z))
            elif "story_content" in existing_story:
                existing_story_content = existing_story.story_content
            else:
                existing_story_content = ""

            # Title distance + content distance, checking if story changed
            story_title_difference = abs(levenshtein_distance(story.get("title"), existing_story.story_title))

            title_ratio = difflib.SequenceMatcher(
                None, story.get("title", ""), existing_story.story_title
            ).ratio()
            if title_ratio < 0.75:
                continue

            story_timedelta = existing_story.story_date - story_pub_date
            # logging.debug('Story pub date: %s %s (%s, %s)' % (existing_story.story_date, story_pub_date, title_ratio, story_timedelta))
            if abs(story_timedelta.days) >= 2:
                continue

            seq = difflib.SequenceMatcher(None, story_content, existing_story_content)

            similar_length_min = 1000
            if existing_story.story_permalink == story_link and existing_story.story_title == story.get(
                "title"
            ):
                similar_length_min = 20

            # Skip content check if already failed due to a timeout. This way we catch titles
            if lightweight:
                continue

            if (
                seq
                and story_content
                and len(story_content) > similar_length_min
                and existing_story_content
                and seq.real_quick_ratio() > 0.9
                and seq.quick_ratio() > 0.95
            ):
                content_ratio = seq.ratio()

            if story_title_difference > 0 and content_ratio > 0.98:
                story_in_system = existing_story
                if story_title_difference > 0 or content_ratio < 1.0:
                    if settings.DEBUG:
                        logging.debug(
                            "   ---> Title difference - %s/%s (%s): %s"
                            % (
                                story.get("title"),
                                existing_story.story_title,
                                story_title_difference,
                                content_ratio,
                            )
                        )
                    story_has_changed = True
                    break

            # More restrictive content distance, still no story match
            if not story_in_system and content_ratio > 0.98:
                if settings.DEBUG:
                    logging.debug(
                        "   ---> Content difference - %s/%s (%s): %s"
                        % (
                            story.get("title"),
                            existing_story.story_title,
                            story_title_difference,
                            content_ratio,
                        )
                    )
                story_in_system = existing_story
                story_has_changed = True
                break

            if story_in_system and not story_has_changed:
                if story_content != existing_story_content:
                    if settings.DEBUG:
                        logging.debug(
                            "   ---> Content difference - %s (%s)/%s (%s)"
                            % (
                                story.get("title"),
                                len(story_content),
                                existing_story.story_title,
                                len(existing_story_content),
                            )
                        )
                    story_has_changed = True
                if story_link != existing_story.story_permalink:
                    if settings.DEBUG:
                        logging.debug(
                            "   ---> Permalink difference - %s/%s"
                            % (story_link, existing_story.story_permalink)
                        )
                    story_has_changed = True
                # if story_pub_date != existing_story.story_date:
                #     story_has_changed = True
                break

        # if story_has_changed or not story_in_system:
        #     print 'New/updated story: %s' % (story),
        return story_in_system, story_has_changed

    def get_next_scheduled_update(self, force=False, verbose=True, premium_speed=False, pro_speed=False):
        if self.min_to_decay and not force and not premium_speed:
            if verbose:
                logging.debug(
                    "   ---> [%-30s] Using cached min_to_decay: %s min"
                    % (self.log_title[:30], self.min_to_decay)
                )
            return self.min_to_decay

        from apps.notifications.models import MUserFeedNotification

        if premium_speed:
            self.active_premium_subscribers += 1
        if pro_speed:
            self.pro_subscribers += 1

        spd = self.stories_last_month / 30.0
        # Weighted subscriber calculation: premium users count fully, regular users count as 1/10
        subs = self.active_premium_subscribers + (
            (self.active_subscribers - self.active_premium_subscribers) / 10.0
        )
        notification_count = MUserFeedNotification.objects.filter(feed_id=self.pk).count()

        if verbose:
            logging.debug(
                "   ---> [%-30s] ~FBWeighted subscriber calculation:~SN %.1f = %s premium + (%s-%s)/10 regular"
                % (
                    self.log_title[:30],
                    subs,
                    self.active_premium_subscribers,
                    self.active_subscribers,
                    self.active_premium_subscribers,
                )
            )
        # Calculate sub counts:
        #   SELECT COUNT(*) FROM feeds WHERE active_premium_subscribers > 10 AND stories_last_month >= 30;
        #   SELECT COUNT(*) FROM feeds WHERE active_premium_subscribers > 1 AND active_premium_subscribers < 10 AND stories_last_month >= 30;
        #   SELECT COUNT(*) FROM feeds WHERE active_premium_subscribers = 1 AND stories_last_month >= 30;
        # SpD > 1  Subs > 10: t = 6         # 4267   * 1440/6  =      1024080
        # SpD > 1  Subs > 1:  t = 15        # 18973  * 1440/15 =      1821408
        # SpD > 1  Subs = 1:  t = 60        # 65503  * 1440/60 =      1572072
        #   SELECT COUNT(*) FROM feeds WHERE active_premium_subscribers > 1 AND stories_last_month < 30 AND stories_last_month > 0;
        #   SELECT COUNT(*) FROM feeds WHERE active_premium_subscribers = 1 AND stories_last_month < 30 AND stories_last_month > 0;
        # SpD < 1  Subs > 1:  t = 60        # 77618  * 1440/60 =      1862832
        # SpD < 1  Subs = 1:  t = 60 * 12   # 282186 * 1440/(60*12) = 564372
        #   SELECT COUNT(*) FROM feeds WHERE active_premium_subscribers > 1 AND stories_last_month = 0;
        #   SELECT COUNT(*) FROM feeds WHERE active_subscribers > 0 AND active_premium_subscribers <= 1 AND stories_last_month = 0;
        # SpD = 0  Subs > 1:  t = 60 * 3    # 30158  * 1440/(60*3) =  241264
        # SpD = 0  Subs = 1:  t = 60 * 24   # 514131 * 1440/(60*24) = 514131
        if spd >= 1:
            if subs >= 10:
                total = 6
                decay_reason = "High activity: >=1 story/day, >=10 weighted subs"
            elif subs > 1:
                total = 15
                decay_reason = "Good activity: >=1 story/day, >1 weighted subs"
            else:
                total = 45
                decay_reason = "Moderate activity: >=1 story/day, <=1 weighted subs"
        elif spd > 0:
            if subs > 1:
                total = 60 - (spd * 60)
                decay_reason = (
                    "Low activity: <1 story/day (%.2f), >1 weighted subs, formula: 60-(%.2f*60)=%.1f"
                    % (spd, spd, total)
                )
            else:
                total = 60 * 6 - (spd * 60 * 6)
                decay_reason = (
                    "Very low activity: <1 story/day (%.2f), <=1 weighted subs, formula: 360-(%.2f*360)=%.1f"
                    % (spd, spd, total)
                )
        elif spd == 0:
            if subs > 1:
                total = 60 * 6
                decay_reason = "No stories: 0 stories/month, >1 weighted subs"
            elif subs == 1:
                total = 60 * 12
                decay_reason = "No stories: 0 stories/month, =1 weighted subs"
            else:
                total = 60 * 24
                decay_reason = "No stories: 0 stories/month, <1 weighted subs"
            months_since_last_story = seconds_timesince(self.last_story_date) / (60 * 60 * 24 * 30)
            total *= max(1, months_since_last_story)
            if months_since_last_story > 1:
                decay_reason += ", multiplied by %.1f months since last story" % months_since_last_story

        if verbose:
            logging.debug(
                "   ---> [%-30s] ~FBBase decay calculation:~SN %s min - %s"
                % (self.log_title[:30], total, decay_reason)
            )
        # updates_per_day_delay = 3 * 60 / max(.25, ((max(0, self.active_subscribers)**.2)
        #                                             * (self.stories_last_month**0.25)))
        # if self.active_premium_subscribers > 0:
        #     updates_per_day_delay /= min(self.active_subscribers+self.active_premium_subscribers, 4)
        # updates_per_day_delay = int(updates_per_day_delay)

        # Lots of subscribers = lots of updates
        # 24 hours for 0 subscribers.
        # 4 hours for 1 subscriber.
        # .5 hours for 2 subscribers.
        # .25 hours for 3 subscribers.
        # 1 min for 10 subscribers.
        # subscriber_bonus = 6 * 60 / max(.167, max(0, self.active_subscribers)**3)
        # if self.premium_subscribers > 0:
        #     subscriber_bonus /= min(self.active_subscribers+self.premium_subscribers, 5)
        # subscriber_bonus = int(subscriber_bonus)

        original_total = total
        adjustments = []

        if self.is_push:
            fetch_history = MFetchHistory.feed(self.pk)
            if len(fetch_history["push_history"]):
                before_push = total
                total = total * 12
                adjustments.append("Push feed penalty: %s min -> %s min (x12)" % (before_push, total))

        # Any notifications means a 30 min minumum
        if notification_count > 0:
            before_notif = total
            total = min(total, 30)
            if before_notif != total:
                adjustments.append(
                    "Notification boost: %s min -> %s min (30 min max for %s notifications)"
                    % (before_notif, total, notification_count)
                )

        # 4 hour max for premiums, 48 hour max for free
        if subs >= 1:
            before_cap = total
            total = min(total, 60 * 4 * 1)
            if before_cap != total:
                adjustments.append(
                    "Premium cap: %s min -> %s min (4 hour max with %.1f weighted subs)"
                    % (before_cap, total, subs)
                )
        else:
            before_cap = total
            total = min(total, 60 * 24 * 2)
            if before_cap != total:
                adjustments.append("Free cap: %s min -> %s min (48 hour max)" % (before_cap, total))

        # Craigslist feeds get 6 hours minimum
        if "craigslist" in self.feed_address:
            before_cl = total
            total = max(total, 60 * 6)
            if before_cl != total:
                adjustments.append("Craigslist minimum: %s min -> %s min (6 hour min)" % (before_cl, total))

        # Twitter feeds get 2 hours minimum
        if "twitter" in self.feed_address:
            before_tw = total
            total = max(total, 60 * 2)
            if before_tw != total:
                adjustments.append("Twitter minimum: %s min -> %s min (2 hour min)" % (before_tw, total))

        # Pro subscribers get absolute minimum
        if self.pro_subscribers and self.pro_subscribers >= 1:
            before_pro = total
            if self.stories_last_month == 0:
                total = min(total, 60)
                if before_pro != total:
                    adjustments.append(
                        "Pro boost (no stories): %s min -> %s min (60 min max for %s pro subs)"
                        % (before_pro, total, self.pro_subscribers)
                    )
            else:
                total = min(total, settings.PRO_MINUTES_BETWEEN_FETCHES)
                if before_pro != total:
                    adjustments.append(
                        "Pro boost: %s min -> %s min (%s min max for %s pro subs)"
                        % (before_pro, total, settings.PRO_MINUTES_BETWEEN_FETCHES, self.pro_subscribers)
                    )

        # Forbidden feeds get a min of 6 hours
        if self.is_forbidden:
            before_forbidden = total
            if self.num_subscribers > 1000:
                hours = 3
            elif self.num_subscribers > 100:
                hours = 6
            elif self.num_subscribers > 1:
                hours = 12
            else:
                hours = 18
            total = max(total, hours * 60)
            if before_forbidden != total:
                adjustments.append(
                    "Forbidden penalty: %s min -> %s min (%s hour min for %s subs)"
                    % (before_forbidden, total, hours, self.num_subscribers)
                )

        if verbose and adjustments:
            logging.debug(
                "   ---> [%-30s] ~FBDecay adjustments applied:~SN\n         %s"
                % (self.log_title[:30], "\n         ".join(adjustments))
            )

        if verbose:
            logging.debug(
                "   ---> [%-30s] Fetched every %s min - Subs: %s/%s/%s/%s/%s Stories/day: %s"
                % (
                    self.log_title[:30],
                    total,
                    self.num_subscribers,
                    self.active_subscribers,
                    self.active_premium_subscribers,
                    self.archive_subscribers,
                    self.pro_subscribers,
                    spd,
                )
            )
        return total

    def set_next_scheduled_update(self, verbose=False, skip_scheduling=False, delay_fetch_sec=None):
        r = redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)

        # Use Cache-Control max-age if provided
        if delay_fetch_sec is not None:
            minutes_until_next_fetch = delay_fetch_sec / 60
            base_total = minutes_until_next_fetch
            if verbose:
                logging.debug(
                    "   ---> [%-30s] ~FBScheduling feed fetch using cache-control: "
                    "~SB%s minutes" % (self.log_title[:30], minutes_until_next_fetch)
                )
        else:
            # Log subscriber counts for debugging
            if verbose:
                from apps.notifications.models import MUserFeedNotification

                notification_count = MUserFeedNotification.objects.filter(feed_id=self.pk).count()
                spd = self.stories_last_month / 30.0
                months_since_last_story = (
                    seconds_timesince(self.last_story_date) / (60 * 60 * 24 * 30)
                    if self.last_story_date
                    else 999
                )

                logging.debug(
                    "   ---> [%-30s] ~FBCalculating decay time with:~SN\n"
                    "         Subscribers: total=%s, active=%s, active_premium=%s, pro=%s, archive=%s\n"
                    "         Stories: last_month=%s (%.2f/day), last_story_date=%s (%.1f months ago)\n"
                    "         State: is_push=%s, is_forbidden=%s, notifications=%s, errors_since_good=%s"
                    % (
                        self.log_title[:30],
                        self.num_subscribers,
                        self.active_subscribers,
                        self.active_premium_subscribers,
                        self.pro_subscribers,
                        self.archive_subscribers,
                        self.stories_last_month,
                        spd,
                        self.last_story_date,
                        months_since_last_story,
                        self.is_push,
                        self.is_forbidden,
                        notification_count,
                        self.errors_since_good,
                    )
                )

            minutes_until_next_fetch = self.get_next_scheduled_update(force=True, verbose=verbose)
            base_total = minutes_until_next_fetch
            error_count = self.error_count

            if error_count:
                original_total = minutes_until_next_fetch
                minutes_until_next_fetch = minutes_until_next_fetch * error_count
                minutes_until_next_fetch = min(minutes_until_next_fetch, 60 * 24 * 7)
                if verbose:
                    logging.debug(
                        "   ---> [%-30s] ~FBScheduling feed fetch geometrically: "
                        "~SB%s errors (errors_since_good=%s + redis_errors). Time adjusted from %s to %s min"
                        % (
                            self.log_title[:30],
                            error_count,
                            self.errors_since_good,
                            original_total,
                            minutes_until_next_fetch,
                        )
                    )

        random_factor = random.randint(0, int(minutes_until_next_fetch)) / 4
        if minutes_until_next_fetch <= 5:
            # 5 min fetches should be between 5 and 10 minutes
            random_factor = random.randint(0, int(minutes_until_next_fetch))

        if verbose and delay_fetch_sec is None:
            logging.debug(
                "   ---> [%-30s] ~FBFinal decay calculation:~SN base=%s min, with_errors=%s min, random_factor=%.1f min"
                % (self.log_title[:30], base_total, minutes_until_next_fetch, random_factor)
            )

            # Explain why this specific time was chosen
            reasons = []
            if self.active_premium_subscribers >= 1:
                reasons.append("has %s active premium subscriber(s)" % self.active_premium_subscribers)
            if self.pro_subscribers >= 1:
                reasons.append("has %s pro subscriber(s)" % self.pro_subscribers)
            if self.is_push:
                reasons.append("is push feed")
            if self.is_forbidden:
                reasons.append("is forbidden (rate limited)")
            if error_count > 0:
                reasons.append("has %s error(s)" % error_count)
            if self.stories_last_month == 0:
                reasons.append("no stories in last month")

            if reasons:
                logging.debug(
                    "   ---> [%-30s] ~FBReasons for %s min decay:~SN %s"
                    % (self.log_title[:30], minutes_until_next_fetch, ", ".join(reasons))
                )

        next_scheduled_update = datetime.datetime.utcnow() + datetime.timedelta(
            minutes=minutes_until_next_fetch + random_factor
        )
        original_min_to_decay = self.min_to_decay
        self.min_to_decay = minutes_until_next_fetch

        delta = self.next_scheduled_update - datetime.datetime.now()
        minutes_to_next_fetch_current = (delta.seconds + (delta.days * 24 * 3600)) / 60
        if minutes_to_next_fetch_current > self.min_to_decay or not skip_scheduling:
            self.next_scheduled_update = next_scheduled_update
            if self.active_subscribers >= 1:
                r.zadd("scheduled_updates", {self.pk: self.next_scheduled_update.strftime("%s")})
            r.zrem("tasked_feeds", self.pk)
            r.srem("queued_feeds", self.pk)

            if verbose:
                logging.debug(
                    "   ---> [%-30s] ~FBScheduled next update for:~SN %s (in %.1f min)"
                    % (self.log_title[:30], next_scheduled_update, minutes_until_next_fetch + random_factor)
                )

        updated_fields = ["last_update", "next_scheduled_update"]
        if self.min_to_decay != original_min_to_decay:
            updated_fields.append("min_to_decay")
        self.save(update_fields=updated_fields)

    @property
    def error_count(self):
        r = redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)
        fetch_errors = int(r.zscore("error_feeds", self.pk) or 0)

        return fetch_errors + self.errors_since_good

    def schedule_feed_fetch_immediately(self, verbose=True):
        r = redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)
        if not self.num_subscribers:
            logging.debug(
                "   ---> [%-30s] Not scheduling feed fetch immediately, no subs." % (self.log_title[:30])
            )
            return self

        if verbose:
            logging.debug("   ---> [%-30s] Scheduling feed fetch immediately..." % (self.log_title[:30]))

        self.next_scheduled_update = datetime.datetime.utcnow()
        r.zadd("scheduled_updates", {self.pk: self.next_scheduled_update.strftime("%s")})

        return self.save()

    def setup_push(self):
        from apps.push.models import PushSubscription

        try:
            push = self.push
        except PushSubscription.DoesNotExist:
            self.is_push = False
        else:
            self.is_push = push.verified
        self.save()

    def queue_pushed_feed_xml(self, xml, latest_push_date_delta=None):
        r = redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)
        queue_size = r.llen("push_feeds")

        if latest_push_date_delta:
            latest_push_date_delta = "%s" % str(latest_push_date_delta).split(".", 2)[0]

        if queue_size > 1000:
            self.schedule_feed_fetch_immediately()
        else:
            logging.debug(
                "   ---> [%-30s] [%s] ~FB~SBQueuing pushed stories, last pushed %s..."
                % (self.log_title[:30], self.pk, latest_push_date_delta)
            )
            self.set_next_scheduled_update()
            PushFeeds.apply_async(args=(self.pk, xml), queue="push_feeds")

    # def calculate_collocations_story_content(self,
    #                                          collocation_measures=TrigramAssocMeasures,
    #                                          collocation_finder=TrigramCollocationFinder):
    #     stories = MStory.objects.filter(story_feed_id=self.pk)
    #     story_content = ' '.join([s.story_content for s in stories if s.story_content])
    #     return self.calculate_collocations(story_content, collocation_measures, collocation_finder)
    #
    # def calculate_collocations_story_title(self,
    #                                        collocation_measures=BigramAssocMeasures,
    #                                        collocation_finder=BigramCollocationFinder):
    #     stories = MStory.objects.filter(story_feed_id=self.pk)
    #     story_titles = ' '.join([s.story_title for s in stories if s.story_title])
    #     return self.calculate_collocations(story_titles, collocation_measures, collocation_finder)
    #
    # def calculate_collocations(self, content,
    #                            collocation_measures=TrigramAssocMeasures,
    #                            collocation_finder=TrigramCollocationFinder):
    #     content = re.sub(r'&#8217;', '\'', content)
    #     content = re.sub(r'&amp;', '&', content)
    #     try:
    #         content = unicode(BeautifulStoneSoup(content,
    #                           convertEntities=BeautifulStoneSoup.HTML_ENTITIES))
    #     except ValueError, e:
    #         print "ValueError, ignoring: %s" % e
    #     content = re.sub(r'</?\w+\s+[^>]*>', '', content)
    #     content = re.split(r"[^A-Za-z-'&]+", content)
    #
    #     finder = collocation_finder.from_words(content)
    #     finder.apply_freq_filter(3)
    #     best = finder.nbest(collocation_measures.pmi, 10)
    #     phrases = [' '.join(phrase) for phrase in best]
    #
    #     return phrases


# class FeedCollocations(models.Model):
#     feed = models.ForeignKey(Feed)
#     phrase = models.CharField(max_length=500)


class FeedData(models.Model):
    feed = AutoOneToOneField(Feed, related_name="data", on_delete=models.CASCADE)
    feed_tagline = models.CharField(max_length=1024, blank=True, null=True)
    story_count_history = models.TextField(blank=True, null=True)
    feed_classifier_counts = models.TextField(blank=True, null=True)
    popular_tags = models.CharField(max_length=1024, blank=True, null=True)
    popular_authors = models.CharField(max_length=2048, blank=True, null=True)

    def save(self, *args, **kwargs):
        if self.feed_tagline and len(self.feed_tagline) >= 1000:
            self.feed_tagline = self.feed_tagline[:1000]

        try:
            super(FeedData, self).save(*args, **kwargs)
        except (IntegrityError, OperationError):
            if hasattr(self, "id") and self.id:
                self.delete()
        except DatabaseError as e:
            # Nothing updated
            logging.debug(" ---> ~FRNothing updated in FeedData (%s): %s" % (self.feed, e))
            pass


class MFeedIcon(mongo.Document):
    feed_id = mongo.IntField(primary_key=True)
    color = mongo.StringField(max_length=6)
    data = mongo.StringField()
    icon_url = mongo.StringField()
    not_found = mongo.BooleanField(default=False)

    meta = {
        "collection": "feed_icons",
        "allow_inheritance": False,
    }

    @classmethod
    def get_feed(cls, feed_id, create=True):
        try:
            feed_icon = cls.objects.read_preference(pymongo.ReadPreference.PRIMARY).get(feed_id=feed_id)
        except cls.DoesNotExist:
            if create:
                feed_icon = cls.objects.create(feed_id=feed_id)
            else:
                feed_icon = None

        return feed_icon

    def save(self, *args, **kwargs):
        if self.icon_url:
            self.icon_url = str(self.icon_url)
        try:
            return super(MFeedIcon, self).save(*args, **kwargs)
        except (IntegrityError, OperationError):
            # print "Error on Icon: %s" % e
            if hasattr(self, "_id"):
                self.delete()


class MFeedPage(mongo.Document):
    feed_id = mongo.IntField(primary_key=True)
    page_data = mongo.BinaryField()

    meta = {
        "collection": "feed_pages",
        "allow_inheritance": False,
    }

    def page(self):
        try:
            return zlib.decompress(self.page_data)
        except zlib.error as e:
            logging.debug(" ***> Zlib decompress error: %s" % e)
            self.page_data = None
            self.save()
            return

    @classmethod
    def get_data(cls, feed_id):
        data = None
        feed_page = cls.objects(feed_id=feed_id)
        if feed_page:
            page_data_z = feed_page[0].page_data
            if page_data_z:
                try:
                    data = zlib.decompress(page_data_z)
                except zlib.error as e:
                    logging.debug(" ***> Zlib decompress error: %s" % e)
                    feed_page.page_data = None
                    feed_page.save()
                    return

        if not data:
            dupe_feed = DuplicateFeed.objects.filter(duplicate_feed_id=feed_id)
            if dupe_feed:
                feed = dupe_feed[0].feed
                feed_page = MFeedPage.objects.filter(feed_id=feed.pk)
                if feed_page:
                    page_data_z = feed_page[0].page_data
                    if page_data_z:
                        data = zlib.decompress(feed_page[0].page_data)

        return data


class MStory(mongo.Document):
    """A feed item"""

    story_feed_id = mongo.IntField()
    story_date = mongo.DateTimeField()
    story_title = mongo.StringField(max_length=1024)
    story_content = mongo.StringField()
    story_content_z = mongo.BinaryField()
    story_original_content = mongo.StringField()
    story_original_content_z = mongo.BinaryField()
    story_latest_content = mongo.StringField()
    story_latest_content_z = mongo.BinaryField()
    original_text_z = mongo.BinaryField()
    original_page_z = mongo.BinaryField()
    story_content_type = mongo.StringField(max_length=255)
    story_author_name = mongo.StringField()
    story_permalink = mongo.StringField()
    story_guid = mongo.StringField()
    story_hash = mongo.StringField()
    image_urls = mongo.ListField(mongo.StringField(max_length=1024))
    story_tags = mongo.ListField(mongo.StringField(max_length=250))
    comment_count = mongo.IntField()
    comment_user_ids = mongo.ListField(mongo.IntField())
    share_count = mongo.IntField()
    share_user_ids = mongo.ListField(mongo.IntField())

    meta = {
        "collection": "stories",
        "indexes": [
            ("story_feed_id", "-story_date"),
            {
                "fields": ["story_hash"],
                "unique": True,
            },
        ],
        "ordering": ["-story_date"],
        "allow_inheritance": False,
        "cascade": False,
        "strict": False,
    }

    RE_STORY_HASH = re.compile(r"^(\d{1,10}):(\w{6})$")
    RE_RS_KEY = re.compile(r"^RS:(\d+):(\d+)$")

    def __str__(self):
        content = self.story_content_z if self.story_content_z else ""
        return f"{self.story_hash}: {self.story_title[:20]} ({len(self.story_content_z) if self.story_content_z else 0} bytes)"

    @property
    def guid_hash(self):
        return hashlib.sha1((self.story_guid).encode(encoding="utf-8")).hexdigest()[:6]

    @classmethod
    def guid_hash_unsaved(self, guid):
        return hashlib.sha1(guid.encode(encoding="utf-8")).hexdigest()[:6]

    @property
    def feed_guid_hash(self):
        return "%s:%s" % (self.story_feed_id, self.guid_hash)

    @classmethod
    def feed_guid_hash_unsaved(cls, feed_id, guid):
        return "%s:%s" % (feed_id, cls.guid_hash_unsaved(guid))

    @property
    def decoded_story_title(self):
        return html.unescape(self.story_title)

    @property
    def story_content_str(self):
        story_content = self.story_content
        if not story_content and self.story_content_z:
            story_content = smart_str(zlib.decompress(self.story_content_z))
        else:
            story_content = smart_str(story_content)

        return story_content

    def save(self, *args, **kwargs):
        story_title_max = MStory._fields["story_title"].max_length
        story_content_type_max = MStory._fields["story_content_type"].max_length
        self.story_hash = self.feed_guid_hash

        self.extract_image_urls()

        if self.story_content:
            self.story_content_z = zlib.compress(smart_bytes(self.story_content))
            self.story_content = None
        if self.story_original_content:
            self.story_original_content_z = zlib.compress(smart_bytes(self.story_original_content))
            self.story_original_content = None
        if self.story_latest_content:
            self.story_latest_content_z = zlib.compress(smart_bytes(self.story_latest_content))
            self.story_latest_content = None
        if self.story_title and len(self.story_title) > story_title_max:
            self.story_title = self.story_title[:story_title_max]
        if self.story_content_type and len(self.story_content_type) > story_content_type_max:
            self.story_content_type = self.story_content_type[:story_content_type_max]

        super(MStory, self).save(*args, **kwargs)

        self.sync_redis()

        return self

    def delete(self, *args, **kwargs):
        self.remove_from_redis()
        self.remove_from_search_index()

        super(MStory, self).delete(*args, **kwargs)

    def publish_to_subscribers(self):
        try:
            r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
            r.publish(
                "%s:story" % (self.story_feed_id), "%s,%s" % (self.story_hash, self.story_date.strftime("%s"))
            )
        except redis.ConnectionError:
            logging.debug(
                "   ***> [%-30s] ~BMRedis is unavailable for real-time."
                % (Feed.get_by_id(self.story_feed_id).title[:30],)
            )

    @classmethod
    def purge_feed_stories(cls, feed, cutoff, verbose=True):
        stories = cls.objects(story_feed_id=feed.pk)
        logging.debug(" ---> Deleting %s stories from %s" % (stories.count(), feed))
        if stories.count() > cutoff * 1.25:
            logging.debug(" ***> ~FRToo many stories in %s, not purging..." % (feed))
            return
        stories.delete()

    @classmethod
    def index_all_for_search(cls, offset=0, search=False, discover=False):
        if not offset:
            if search:
                logging.debug("Re-creating search index")
                SearchStory.create_elasticsearch_mapping(delete=True)
            if discover:
                logging.debug("Re-creating discover index")
                DiscoverStory.create_elasticsearch_mapping(delete=True)

        last_pk = Feed.objects.latest("pk").pk
        for f in range(offset, last_pk, 1000):
            logging.debug(" ---> %s / %s (%.2s%%)" % (f, last_pk, float(f) / last_pk * 100))
            feeds = Feed.objects.filter(
                pk__in=list(range(f, f + 1000)), active=True, active_subscribers__gte=1
            ).values_list("pk")
            for (f,) in feeds:
                stories = cls.objects.filter(story_feed_id=f)
                if not len(stories):
                    continue
                logging.debug(
                    f"Indexing {len(stories)} stories in feed {f} for {'search' if search else 'discover' if discover else 'both search and discover'}"
                )
                for s, story in enumerate(stories):
                    if s % 100 == 0:
                        logging.debug(f" ---> Indexing story {s} of {len(stories)} in feed {f}")
                    if search:
                        story.index_story_for_search()
                    if discover:
                        story.index_story_for_discover()

    def index_story_for_search(self):
        story_content = self.story_content or ""
        if self.story_content_z:
            story_content = zlib.decompress(self.story_content_z)
        SearchStory.index(
            story_hash=self.story_hash,
            story_title=self.story_title,
            story_content=prep_for_search(story_content),
            story_tags=self.story_tags,
            story_author=self.story_author_name,
            story_feed_id=self.story_feed_id,
            story_date=self.story_date,
        )

    @classmethod
    def index_stories_for_discover(cls, story_hashes, verbose=False):
        logging.debug(f" ---> ~FBIndexing {len(story_hashes)} stories for ~FC~SBdiscover")
        for story_hash in story_hashes:
            try:
                story = cls.objects.get(story_hash=story_hash)
                story.index_story_for_discover(verbose=verbose)
            except cls.DoesNotExist:
                logging.debug(f" ---> ~FBStory not found for discover indexing: {story_hash}")

    def index_story_for_discover(self, verbose=False):
        DiscoverStory.index(
            story_hash=self.story_hash,
            story_feed_id=self.story_feed_id,
            story_date=self.story_date,
            verbose=verbose,
        )

    def remove_from_search_index(self):
        try:
            SearchStory.remove(self.story_hash)
            DiscoverStory.remove(self.story_hash)
        except Exception:
            pass

    @classmethod
    def trim_feed(cls, cutoff, feed_id=None, feed=None, verbose=True):
        extra_stories_count = 0
        cutoff = int(cutoff)
        if not feed_id and not feed:
            return extra_stories_count

        if not feed_id:
            feed_id = feed.pk
        if not feed:
            feed = feed_id

        stories = cls.objects(story_feed_id=feed_id).only("story_date").order_by("-story_date")

        if stories.count() > cutoff:
            logging.debug(
                "   ---> [%-30s] ~FMFound %s stories. Trimming to ~SB%s~SN..."
                % (str(feed)[:30], stories.count(), cutoff)
            )
            try:
                story_trim_date = stories[cutoff].story_date
                if story_trim_date == stories[0].story_date:
                    # Handle case where every story is the same time
                    story_trim_date = story_trim_date - datetime.timedelta(seconds=1)
            except IndexError as e:
                logging.debug(" ***> [%-30s] ~BRError trimming feed: %s" % (str(feed)[:30], e))
                return extra_stories_count

            extra_stories = cls.objects(story_feed_id=feed_id, story_date__lte=story_trim_date)
            extra_stories_count = extra_stories.count()
            shared_story_count = 0
            for story in extra_stories:
                if story.share_count:
                    shared_story_count += 1
                    extra_stories_count -= 1
                    continue
                story.delete()
            if verbose:
                existing_story_count = cls.objects(story_feed_id=feed_id).count()
                logging.debug(
                    "   ---> Deleted %s stories, %s (%s shared) left."
                    % (extra_stories_count, existing_story_count, shared_story_count)
                )

        return extra_stories_count

    @classmethod
    def find_story(cls, story_feed_id=None, story_id=None, story_hash=None, original_only=False):
        from apps.social.models import MSharedStory

        original_found = False
        if story_hash:
            story_id = story_hash
        story_hash = cls.ensure_story_hash(story_id, story_feed_id)
        if not story_feed_id:
            story_feed_id, _ = cls.split_story_hash(story_hash)
        if isinstance(story_id, ObjectId):
            story = cls.objects(id=story_id).limit(1).first()
        else:
            story = cls.objects(story_hash=story_hash).limit(1).first()

        if story:
            original_found = True
        if not story and not original_only:
            story = (
                MSharedStory.objects.filter(story_feed_id=story_feed_id, story_hash=story_hash)
                .limit(1)
                .first()
            )
        if not story and not original_only:
            story = (
                MStarredStory.objects.filter(story_feed_id=story_feed_id, story_hash=story_hash)
                .limit(1)
                .first()
            )

        return story, original_found

    @classmethod
    def find_by_id(cls, story_ids):
        from apps.social.models import MSharedStory

        count = len(story_ids)
        multiple = isinstance(story_ids, list) or isinstance(story_ids, tuple)

        stories = list(cls.objects(id__in=story_ids))
        if len(stories) < count:
            shared_stories = list(MSharedStory.objects(id__in=story_ids))
            stories.extend(shared_stories)

        if not multiple:
            stories = stories[0]

        return stories

    @classmethod
    def find_by_story_hashes(cls, story_hashes):
        from apps.social.models import MSharedStory

        count = len(story_hashes)
        multiple = isinstance(story_hashes, list) or isinstance(story_hashes, tuple)

        stories = list(cls.objects(story_hash__in=story_hashes))
        if len(stories) < count:
            hashes_found = [s.story_hash for s in stories]
            remaining_hashes = list(set(story_hashes) - set(hashes_found))
            story_feed_ids = [h.split(":")[0] for h in remaining_hashes]
            shared_stories = list(
                MSharedStory.objects(story_feed_id__in=story_feed_ids, story_hash__in=remaining_hashes)
            )
            stories.extend(shared_stories)

        if not multiple:
            stories = stories[0]

        return stories

    @classmethod
    def ensure_story_hash(cls, story_id, story_feed_id):
        if not cls.RE_STORY_HASH.match(story_id):
            story_id = "%s:%s" % (
                story_feed_id,
                hashlib.sha1(story_id.encode(encoding="utf-8")).hexdigest()[:6],
            )

        return story_id

    @classmethod
    def split_story_hash(cls, story_hash):
        matches = cls.RE_STORY_HASH.match(story_hash)
        if matches:
            groups = matches.groups()
            return groups[0], groups[1]
        return None, None

    @classmethod
    def split_rs_key(cls, rs_key):
        matches = cls.RE_RS_KEY.match(rs_key)
        if matches:
            groups = matches.groups()
            return groups[0], groups[1]
        return None, None

    @classmethod
    def story_hashes(cls, story_ids):
        story_hashes = []
        for story_id in story_ids:
            story_hash = cls.ensure_story_hash(story_id)
            if not story_hash:
                continue
            story_hashes.append(story_hash)

        return story_hashes

    def sync_redis(self, r=None):
        if not r:
            r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
        feed = Feed.get_by_id(self.story_feed_id)

        if self.id and self.story_date > feed.unread_cutoff:
            feed_key = "F:%s" % self.story_feed_id
            r.sadd(feed_key, self.story_hash)
            r.expire(feed_key, feed.days_of_story_hashes * 24 * 60 * 60)

            r.zadd("z" + feed_key, {self.story_hash: time.mktime(self.story_date.timetuple())})
            r.expire("z" + feed_key, feed.days_of_story_hashes * 24 * 60 * 60)

    def remove_from_redis(self, r=None):
        if not r:
            r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
        if self.id:
            r.srem("F:%s" % self.story_feed_id, self.story_hash)
            r.zrem("zF:%s" % self.story_feed_id, self.story_hash)

    @classmethod
    def sync_feed_redis(cls, story_feed_id, allow_skip_resync=False):
        r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
        feed = Feed.get_by_id(story_feed_id)
        stories = cls.objects.filter(story_feed_id=story_feed_id, story_date__gte=feed.unread_cutoff)

        if allow_skip_resync and stories.count() > 1000:
            logging.debug(
                f" ---> [{feed.log_title[:30]}] ~FYSkipping resync of ~SB{stories.count()}~SN stories because it already had archive subscribers"
            )
            return

        # Don't delete redis keys because they take time to rebuild and subs can
        # be counted incorrectly during that time.
        # r.delete('F:%s' % story_feed_id)
        # r.delete('zF:%s' % story_feed_id)

        logging.info(
            "   ---> [%-30s] ~FMSyncing ~SB%s~SN stories to redis"
            % (feed and feed.log_title[:30] or story_feed_id, stories.count())
        )
        p = r.pipeline()
        for story in stories:
            story.sync_redis(r=p)
        p.execute()

    def count_comments(self):
        from apps.social.models import MSharedStory

        params = {
            "story_guid": self.story_guid,
            "story_feed_id": self.story_feed_id,
        }
        comments = MSharedStory.objects.filter(has_comments=True, **params).only("user_id")
        shares = MSharedStory.objects.filter(**params).only("user_id")
        self.comment_count = comments.count()
        self.comment_user_ids = [c["user_id"] for c in comments]
        self.share_count = shares.count()
        self.share_user_ids = [s["user_id"] for s in shares]
        self.save()

    def extract_image_urls(self, force=False, text=False):
        if self.image_urls and not force and not text:
            return self.image_urls

        story_content = None
        if not text:
            story_content = self.story_content_str
        elif text:
            if self.original_text_z:
                story_content = smart_str(zlib.decompress(self.original_text_z))
        if not story_content:
            return

        try:
            soup = BeautifulSoup(story_content, features="lxml")
        except UserWarning as e:
            logging.debug(" ---> ~FBWarning on BS4: ~SB%s" % str(e)[:100])
            return
        except ValueError:
            if not text:
                return self.extract_image_urls(force=force, text=True)
            else:
                return

        images = soup.findAll("img")

        # Add youtube thumbnail and insert appropriately before/after images.
        # Give the Youtube a bit of an edge.
        video_thumbnails = soup.findAll(
            "iframe", src=lambda x: x and any(y in x for y in ["youtube.com", "ytimg.com"])
        )
        for video_thumbnail in video_thumbnails:
            video_src = video_thumbnail.get("src")
            video_id = re.search(".*?youtube.com/embed/([A-Za-z0-9\-_]+)", video_src)
            if not video_id:
                video_id = re.search(".*?youtube.com/v/([A-Za-z0-9\-_]+)", video_src)
            if not video_id:
                video_id = re.search(".*?ytimg.com/vi/([A-Za-z0-9\-_]+)", video_src)
            if not video_id:
                video_id = re.search(".*?youtube.com/watch\?v=([A-Za-z0-9\-_]+)", video_src)
            if not video_id:
                logging.debug(f" ***> Couldn't find youtube url in {video_thumbnail}: {video_src}")
                continue
            video_img_url = f"https://img.youtube.com/vi/{video_id.groups()[0]}/0.jpg"
            iframe_index = story_content.index("<iframe")
            try:
                img_index = story_content.index("<img") * 3
            except ValueError:
                img_index = None
            if not img_index or iframe_index < img_index:
                images.insert(0, video_img_url)
            else:
                images.append(video_img_url)

        if not images:
            if not text:
                return self.extract_image_urls(force=force, text=True)
            else:
                return

        image_urls = self.image_urls
        if not image_urls:
            image_urls = []

        for image in images:
            if isinstance(image, str):
                image_url = image
            else:
                image_url = image.get("src")
            if not image_url:
                continue
            if image_url and len(image_url) >= 1024:
                continue
            if "feedburner.com" in image_url:
                continue
            try:
                image_url = urllib.parse.urljoin(self.story_permalink, image_url)
            except ValueError:
                continue
            image_urls.append(image_url)

        if not image_urls:
            if not text:
                return self.extract_image_urls(force=force, text=True)
            else:
                return

        if text:
            urls = []
            for url in image_urls:
                if "http://" in url[1:] or "https://" in url[1:]:
                    continue
                urls.append(url)
            image_urls = urls

        ordered_image_urls = []
        for image_url in list(set(image_urls)):
            if "feedburner" in image_url:
                ordered_image_urls.append(image_url)
            else:
                ordered_image_urls.insert(0, image_url)
        image_urls = ordered_image_urls

        if len(image_urls):
            self.image_urls = [u for u in image_urls if u]
        else:
            return

        max_length = MStory.image_urls.field.max_length
        while len("".join(self.image_urls)) > max_length:
            if len(self.image_urls) <= 1:
                self.image_urls[0] = self.image_urls[0][: max_length - 1]
                break
            else:
                self.image_urls.pop()

        return self.image_urls

    def fetch_original_text(self, force=False, request=None, debug=False):
        original_text_z = self.original_text_z

        if not original_text_z or force:
            feed = Feed.get_by_id(self.story_feed_id)
            self.extract_image_urls(force=force, text=False)
            ti = TextImporter(self, feed=feed, request=request, debug=debug)
            original_doc = ti.fetch(return_document=True)
            original_text = original_doc.get("content") if original_doc else None
            self.extract_image_urls(force=force, text=True)
            self.save()
        else:
            logging.user(request, "~FYFetching ~FGoriginal~FY story text, ~SBfound.")
            original_text = zlib.decompress(original_text_z)

        return original_text

    def fetch_original_page(self, force=False, request=None, debug=False):
        from apps.rss_feeds.page_importer import PageImporter

        if not self.original_page_z or force:
            feed = Feed.get_by_id(self.story_feed_id)
            importer = PageImporter(request=request, feed=feed, story=self)
            original_page = importer.fetch_story()
        else:
            logging.user(request, "~FYFetching ~FGoriginal~FY story page, ~SBfound.")
            original_page = zlib.decompress(self.original_page_z)

        return original_page

    def fetch_similar_stories(self, feed_ids=None, offset=0, limit=5):
        combined_content_vector = DiscoverStory.generate_combined_story_content_vector([self.story_hash])
        results = DiscoverStory.vector_query(
            combined_content_vector,
            feed_ids_to_include=feed_ids,
            story_hashes_to_exclude=[self.story_hash],
            offset=offset,
            max_results=limit,
        )
        logging.debug(
            f"Found {len(results)} recommendations for stories related to {self}: {[r['_id'] for r in results]}"
        )

        return results


class MStarredStory(mongo.DynamicDocument):
    """Like MStory, but not inherited due to large overhead of _cls and _type in
    mongoengine's inheritance model on every single row."""

    user_id = mongo.IntField(unique_with=("story_guid",))
    starred_date = mongo.DateTimeField()
    starred_updated = mongo.DateTimeField()
    story_feed_id = mongo.IntField()
    story_date = mongo.DateTimeField()
    story_title = mongo.StringField(max_length=1024)
    story_content = mongo.StringField()
    story_content_z = mongo.BinaryField()
    story_original_content = mongo.StringField()
    story_original_content_z = mongo.BinaryField()
    original_text_z = mongo.BinaryField()
    story_content_type = mongo.StringField(max_length=255)
    story_author_name = mongo.StringField()
    story_permalink = mongo.StringField()
    story_guid = mongo.StringField()
    story_hash = mongo.StringField()
    story_tags = mongo.ListField(mongo.StringField(max_length=250))
    user_notes = mongo.StringField()
    user_tags = mongo.ListField(mongo.StringField(max_length=128))
    highlights = mongo.ListField(mongo.StringField(max_length=16384))
    image_urls = mongo.ListField(mongo.StringField(max_length=1024))

    meta = {
        "collection": "starred_stories",
        "indexes": [
            ("user_id", "-starred_date"),
            ("user_id", "story_feed_id"),
            ("user_id", "story_hash"),
            "story_feed_id",
        ],
        "ordering": ["-starred_date"],
        "allow_inheritance": False,
        "strict": False,
    }

    def __unicode__(self):
        try:
            user = User.objects.get(pk=self.user_id)
            username = user.username
        except User.DoesNotExist:
            username = "[deleted]"
        return "%s: %s (%s)" % (username, self.story_title[:20], self.story_feed_id)

    def save(self, *args, **kwargs):
        if self.story_content:
            self.story_content_z = zlib.compress(smart_bytes(self.story_content))
            self.story_content = None
        if self.story_original_content:
            self.story_original_content_z = zlib.compress(smart_bytes(self.story_original_content))
            self.story_original_content = None
        self.story_hash = self.feed_guid_hash
        self.starred_updated = datetime.datetime.now()

        return super(MStarredStory, self).save(*args, **kwargs)

    @classmethod
    def find_stories(cls, query, user_id, tag=None, offset=0, limit=25, order="newest"):
        stories_db = cls.objects(
            Q(user_id=user_id)
            & (
                Q(story_title__icontains=query)
                | Q(story_author_name__icontains=query)
                | Q(story_tags__icontains=query)
            )
        )
        if tag:
            stories_db = stories_db.filter(user_tags__contains=tag)

        stories_db = stories_db.order_by("%sstarred_date" % ("-" if order == "newest" else ""))[
            offset : offset + limit
        ]
        stories = Feed.format_stories(stories_db)

        return stories

    @classmethod
    def find_stories_by_user_tag(cls, user_tag, user_id, offset=0, limit=25):
        stories_db = cls.objects(Q(user_id=user_id), Q(user_tags__icontains=user_tag)).order_by(
            "-starred_date"
        )[offset : offset + limit]
        stories = Feed.format_stories(stories_db)

        return stories

    @classmethod
    def trim_old_stories(cls, stories=10, days=90, dryrun=False):
        print(" ---> Fetching starred story counts...")
        stats = settings.MONGODB.newsblur.starred_stories.aggregate(
            [
                {
                    "$group": {
                        "_id": "$user_id",
                        "stories": {"$sum": 1},
                    },
                },
                {
                    "$match": {"stories": {"$gte": stories}},
                },
            ]
        )
        month_ago = datetime.datetime.now() - datetime.timedelta(days=days)
        user_ids = list(stats)
        user_ids = sorted(user_ids, key=lambda x: x["stories"], reverse=True)
        print(" ---> Found %s users with more than %s starred stories" % (len(user_ids), stories))

        total = 0
        for stat in user_ids:
            try:
                user = User.objects.select_related("profile").get(pk=stat["_id"])
            except User.DoesNotExist:
                user = None

            if user and (user.profile.is_premium or user.profile.last_seen_on > month_ago):
                continue

            total += stat["stories"]
            username = "%s (%s)" % (user and user.username or " - ", stat["_id"])
            print(
                " ---> %19.19s: %-20.20s %s stories"
                % (user and user.profile.last_seen_on or "Deleted", username, stat["stories"])
            )
            if not dryrun and stat["_id"]:
                cls.objects.filter(user_id=stat["_id"]).delete()
            elif not dryrun and stat["_id"] == 0:
                print(" ---> Deleting unstarred stories (user_id = 0)")
                cls.objects.filter(user_id=stat["_id"]).delete()

        print(" ---> Deleted %s stories in total." % total)

    @property
    def guid_hash(self):
        return hashlib.sha1(self.story_guid.encode(encoding="utf-8")).hexdigest()[:6]

    @property
    def feed_guid_hash(self):
        return "%s:%s" % (self.story_feed_id or "0", self.guid_hash)

    def fetch_original_text(self, force=False, request=None, debug=False):
        original_text_z = self.original_text_z
        feed = Feed.get_by_id(self.story_feed_id)

        if not original_text_z or force:
            ti = TextImporter(self, feed=feed, request=request, debug=debug)
            original_text = ti.fetch()
        else:
            logging.user(request, "~FYFetching ~FGoriginal~FY story text, ~SBfound.")
            original_text = zlib.decompress(original_text_z)

        return original_text

    def fetch_original_page(self, force=False, request=None, debug=False):
        return None


class MStarredStoryCounts(mongo.Document):
    user_id = mongo.IntField()
    tag = mongo.StringField(max_length=128)
    feed_id = mongo.IntField()
    is_highlights = mongo.BooleanField()
    slug = mongo.StringField(max_length=128)
    count = mongo.IntField(default=0)

    meta = {
        "collection": "starred_stories_counts",
        "indexes": ["user_id"],
        "ordering": ["tag"],
        "allow_inheritance": False,
    }

    def __unicode__(self):
        if self.tag:
            return "Tag: %s (%s)" % (self.tag, self.count)
        elif self.feed_id:
            return "Feed: %s (%s)" % (self.feed_id, self.count)
        elif self.is_highlights:
            return "Highlights: %s (%s)" % (self.is_highlights, self.count)

        return "%s/%s/%s" % (self.tag, self.feed_id, self.is_highlights)

    @property
    def rss_url(self, secret_token=None):
        if self.feed_id:
            return

        if not secret_token:
            user = User.objects.select_related("profile").get(pk=self.user_id)
            secret_token = user.profile.secret_token

        slug = self.slug if self.slug else ""
        if not self.slug and self.tag:
            slug = slugify(self.tag)
            self.slug = slug
            self.save()

        return "%s/reader/starred_rss/%s/%s/%s" % (settings.NEWSBLUR_URL, self.user_id, secret_token, slug)

    @classmethod
    def user_counts(cls, user_id, include_total=False, try_counting=True):
        counts = cls.objects.filter(user_id=user_id)
        counts = sorted(
            [
                {
                    "tag": c.tag,
                    "count": c.count,
                    "is_highlights": c.is_highlights,
                    "feed_address": c.rss_url,
                    "active": True,
                    "feed_id": c.feed_id,
                }
                for c in counts
            ],
            key=lambda x: (x.get("tag", "") or "").lower(),
        )

        total = 0
        feed_total = 0
        for c in counts:
            if not c["tag"] and not c["feed_id"] and not c["is_highlights"]:
                total = c["count"]
            if c["feed_id"]:
                feed_total += c["count"]

        if try_counting and (total != feed_total or not len(counts)):
            user = User.objects.get(pk=user_id)
            logging.user(
                user, "~FC~SBCounting~SN saved stories (%s total vs. %s counted)..." % (total, feed_total)
            )
            cls.count_for_user(user_id)
            return cls.user_counts(user_id, include_total=include_total, try_counting=False)

        if include_total:
            return counts, total
        return counts

    @classmethod
    def schedule_count_tags_for_user(cls, user_id):
        ScheduleCountTagsForUser.apply_async(kwargs=dict(user_id=user_id))

    @classmethod
    def count_for_user(cls, user_id, total_only=False):
        user_tags = []
        user_feeds = []
        highlights = 0

        if not total_only:
            cls.objects(user_id=user_id).delete()
            try:
                user_tags = cls.count_tags_for_user(user_id)
                highlights = cls.count_highlights_for_user(user_id)
                user_feeds = cls.count_feeds_for_user(user_id)
            except pymongo.errors.OperationFailure as e:
                logging.debug(" ---> ~FBOperationError on mongo: ~SB%s" % e)

        total_stories_count = MStarredStory.objects(user_id=user_id).count()
        cls.objects(user_id=user_id, tag=None, feed_id=None, is_highlights=None).update_one(
            set__count=total_stories_count, upsert=True
        )

        return dict(total=total_stories_count, tags=user_tags, feeds=user_feeds, highlights=highlights)

    @classmethod
    def count_tags_for_user(cls, user_id):
        all_tags = MStarredStory.objects(user_id=user_id, user_tags__exists=True).item_frequencies(
            "user_tags"
        )
        user_tags = sorted(
            [(k, v) for k, v in list(all_tags.items()) if int(v) > 0 and k],
            key=lambda x: x[0].lower(),
            reverse=True,
        )

        for tag, count in list(dict(user_tags).items()):
            cls.objects(user_id=user_id, tag=tag, slug=slugify(tag)).update_one(set__count=count, upsert=True)

        return user_tags

    @classmethod
    def count_highlights_for_user(cls, user_id):
        highlighted_count = MStarredStory.objects(
            user_id=user_id, highlights__exists=True, __raw__={"$where": "this.highlights.length > 0"}
        ).count()
        if highlighted_count > 0:
            cls.objects(user_id=user_id, is_highlights=True, slug="highlights").update_one(
                set__count=highlighted_count, upsert=True
            )
        else:
            cls.objects(user_id=user_id, is_highlights=True, slug="highlights").delete()

        return highlighted_count

    @classmethod
    def count_feeds_for_user(cls, user_id):
        all_feeds = MStarredStory.objects(user_id=user_id).item_frequencies("story_feed_id")
        user_feeds = dict([(k, v) for k, v in list(all_feeds.items()) if v])

        # Clean up None'd and 0'd feed_ids, so they can be counted against the total
        if user_feeds.get(None, False):
            user_feeds[0] = user_feeds.get(0, 0)
            user_feeds[0] += user_feeds.get(None)
            del user_feeds[None]
        if user_feeds.get(0, False):
            user_feeds[-1] = user_feeds.get(0, 0)
            del user_feeds[0]

        too_many_feeds = False if len(user_feeds) < 1000 else True
        for feed_id, count in list(user_feeds.items()):
            if too_many_feeds and count <= 1:
                continue
            cls.objects(user_id=user_id, feed_id=feed_id, slug="feed:%s" % feed_id).update_one(
                set__count=count, upsert=True
            )

        return user_feeds

    @classmethod
    def adjust_count(cls, user_id, feed_id=None, tag=None, highlights=None, amount=0):
        params = dict(user_id=user_id)
        if feed_id:
            params["feed_id"] = feed_id
        if tag:
            params["tag"] = tag
        if highlights:
            params["is_highlights"] = True

        cls.objects(**params).update_one(inc__count=amount, upsert=True)
        try:
            story_count = cls.objects.get(**params)
        except cls.MultipleObjectsReturned:
            story_count = cls.objects(**params).first()
        if story_count and story_count.count <= 0:
            story_count.delete()


class MSavedSearch(mongo.Document):
    user_id = mongo.IntField()
    query = mongo.StringField(max_length=1024)
    feed_id = mongo.StringField()
    slug = mongo.StringField(max_length=128)

    meta = {
        "collection": "saved_searches",
        "indexes": [
            "user_id",
            {
                "fields": ["user_id", "feed_id", "query"],
                "unique": True,
            },
        ],
        "ordering": ["query"],
        "allow_inheritance": False,
    }

    @property
    def rss_url(self, secret_token=None):
        if not secret_token:
            user = User.objects.select_related("profile").get(pk=self.user_id)
            secret_token = user.profile.secret_token

        slug = self.slug if self.slug else ""
        return "%s/reader/saved_search/%s/%s/%s" % (settings.NEWSBLUR_URL, self.user_id, secret_token, slug)

    @classmethod
    def user_searches(cls, user_id):
        searches = cls.objects.filter(user_id=user_id)
        searches = sorted(
            [
                {
                    "query": s.query,
                    "feed_address": s.rss_url,
                    "feed_id": s.feed_id,
                    "active": True,
                }
                for s in searches
            ],
            key=lambda x: (x.get("query", "") or "").lower(),
        )
        return searches

    @classmethod
    def save_search(cls, user_id, feed_id, query):
        user = User.objects.get(pk=user_id)
        params = dict(user_id=user_id, feed_id=feed_id, query=query, slug=slugify(query))
        try:
            saved_search = cls.objects.get(**params)
            logging.user(user, "~FRSaved search already exists: ~SB%s" % query)
        except cls.DoesNotExist:
            logging.user(user, "~FCCreating a saved search: ~SB%s~SN/~SB%s" % (feed_id, query))
            saved_search = cls.objects.create(**params)

        return saved_search

    @classmethod
    def delete_search(cls, user_id, feed_id, query):
        user = User.objects.get(pk=user_id)
        params = dict(user_id=user_id, feed_id=feed_id, query=query)
        try:
            saved_search = cls.objects.get(**params)
            logging.user(user, "~FCDeleting saved search: ~SB%s" % query)
            saved_search.delete()
        except cls.DoesNotExist:
            logging.user(user, "~FRCan't delete saved search, missing: ~SB%s~SN/~SB%s" % (feed_id, query))
        except cls.MultipleObjectsReturned:
            logging.user(
                user, "~FRFound multiple saved searches, deleting: ~SB%s~SN/~SB%s" % (feed_id, query)
            )
            cls.objects(**params).delete()


class MFetchHistory(mongo.Document):
    feed_id = mongo.IntField(unique=True)
    feed_fetch_history = mongo.DynamicField()
    page_fetch_history = mongo.DynamicField()
    push_history = mongo.DynamicField()
    raw_feed_history = mongo.DynamicField()

    meta = {
        "db_alias": "nbanalytics",
        "collection": "fetch_history",
        "allow_inheritance": False,
    }

    @classmethod
    def feed(cls, feed_id, timezone=None, fetch_history=None):
        if not fetch_history:
            try:
                fetch_history = cls.objects.read_preference(pymongo.ReadPreference.PRIMARY).get(
                    feed_id=feed_id
                )
            except cls.DoesNotExist:
                fetch_history = cls.objects.create(feed_id=feed_id)
        history = {}

        for fetch_type in ["feed_fetch_history", "page_fetch_history", "push_history"]:
            history[fetch_type] = getattr(fetch_history, fetch_type)
            if not history[fetch_type]:
                history[fetch_type] = []
            for f, fetch in enumerate(history[fetch_type]):
                date_key = "push_date" if fetch_type == "push_history" else "fetch_date"
                history[fetch_type][f] = {
                    date_key: localtime_for_timezone(fetch[0], timezone).strftime("%Y-%m-%d %H:%M:%S"),
                    "status_code": fetch[1],
                    "message": fetch[2],
                }
        return history

    @classmethod
    def add(cls, feed_id, fetch_type, date=None, message=None, code=None, exception=None):
        if not date:
            date = datetime.datetime.now()
        try:
            fetch_history = cls.objects.read_preference(pymongo.ReadPreference.PRIMARY).get(feed_id=feed_id)
        except cls.DoesNotExist:
            fetch_history = cls.objects.create(feed_id=feed_id)

        if fetch_type == "feed":
            history = fetch_history.feed_fetch_history or []
        elif fetch_type == "page":
            history = fetch_history.page_fetch_history or []
        elif fetch_type == "push":
            history = fetch_history.push_history or []
        elif fetch_type == "raw_feed":
            history = fetch_history.raw_feed_history or []

        history = [[date, code, message]] + history
        any_exceptions = any([c for d, c, m in history if c not in [200, 304]])
        if any_exceptions:
            history = history[:25]
        elif fetch_type == "raw_feed":
            history = history[:10]
        else:
            history = history[:5]

        if fetch_type == "feed":
            fetch_history.feed_fetch_history = history
        elif fetch_type == "page":
            fetch_history.page_fetch_history = history
        elif fetch_type == "push":
            fetch_history.push_history = history
        elif fetch_type == "raw_feed":
            fetch_history.raw_feed_history = history

        fetch_history.save()

        if fetch_type == "feed":
            RStats.add("feed_fetch")

        return cls.feed(feed_id, fetch_history=fetch_history)


class DuplicateFeed(models.Model):
    duplicate_address = models.CharField(max_length=764, db_index=True)
    duplicate_link = models.CharField(max_length=764, null=True, db_index=True)
    duplicate_feed_id = models.CharField(max_length=255, null=True, db_index=True)
    feed = models.ForeignKey(Feed, related_name="duplicate_addresses", on_delete=models.CASCADE)

    def __str__(self):
        return "%s: %s / %s" % (self.feed, self.duplicate_address, self.duplicate_link)

    def canonical(self):
        return {
            "duplicate_address": self.duplicate_address,
            "duplicate_link": self.duplicate_link,
            "duplicate_feed_id": self.duplicate_feed_id,
            "feed_id": self.feed_id,
        }

    def save(self, *args, **kwargs):
        max_address = DuplicateFeed._meta.get_field("duplicate_address").max_length
        if len(self.duplicate_address) > max_address:
            self.duplicate_address = self.duplicate_address[:max_address]
        max_link = DuplicateFeed._meta.get_field("duplicate_link").max_length
        if self.duplicate_link and len(self.duplicate_link) > max_link:
            self.duplicate_link = self.duplicate_link[:max_link]

        super(DuplicateFeed, self).save(*args, **kwargs)


def merge_feeds(original_feed_id, duplicate_feed_id, force=False):
    from apps.reader.models import UserSubscription
    from apps.social.models import MSharedStory

    if original_feed_id == duplicate_feed_id:
        logging.info(" ***> Merging the same feed. Ignoring...")
        return original_feed_id
    try:
        original_feed = Feed.objects.get(pk=original_feed_id)
        duplicate_feed = Feed.objects.get(pk=duplicate_feed_id)
    except Feed.DoesNotExist:
        logging.info(" ***> Already deleted feed: %s" % duplicate_feed_id)
        return original_feed_id

    heavier_dupe = original_feed.num_subscribers < duplicate_feed.num_subscribers
    branched_original = original_feed.branch_from_feed and not duplicate_feed.branch_from_feed
    if (heavier_dupe or branched_original) and not force:
        original_feed, duplicate_feed = duplicate_feed, original_feed
        original_feed_id, duplicate_feed_id = duplicate_feed_id, original_feed_id
        if branched_original:
            original_feed.feed_address = strip_underscore_from_feed_address(duplicate_feed.feed_address)

    logging.info(
        " ---> Feed: [%s - %s] %s - %s"
        % (original_feed_id, duplicate_feed_id, original_feed, original_feed.feed_link)
    )
    logging.info(
        "            Orig ++> %s: (%s subs) %s / %s %s"
        % (
            original_feed.pk,
            original_feed.num_subscribers,
            original_feed.feed_address,
            original_feed.feed_link,
            " [B: %s]" % original_feed.branch_from_feed.pk if original_feed.branch_from_feed else "",
        )
    )
    logging.info(
        "            Dupe --> %s: (%s subs) %s / %s %s"
        % (
            duplicate_feed.pk,
            duplicate_feed.num_subscribers,
            duplicate_feed.feed_address,
            duplicate_feed.feed_link,
            " [B: %s]" % duplicate_feed.branch_from_feed.pk if duplicate_feed.branch_from_feed else "",
        )
    )

    original_feed.branch_from_feed = None

    user_subs = UserSubscription.objects.filter(feed=duplicate_feed).order_by("-pk")
    for user_sub in user_subs:
        user_sub.switch_feed(original_feed, duplicate_feed)

    def delete_story_feed(model, feed_field="feed_id"):
        duplicate_stories = model.objects(**{feed_field: duplicate_feed.pk})
        # if duplicate_stories.count():
        #     logging.info(" ---> Deleting %s %s" % (duplicate_stories.count(), model))
        duplicate_stories.delete()

    delete_story_feed(MStory, "story_feed_id")
    delete_story_feed(MFeedPage, "feed_id")

    try:
        DuplicateFeed.objects.create(
            duplicate_address=duplicate_feed.feed_address,
            duplicate_link=duplicate_feed.feed_link,
            duplicate_feed_id=duplicate_feed.pk,
            feed=original_feed,
        )
    except (IntegrityError, OperationError) as e:
        logging.info(" ***> Could not save DuplicateFeed: %s" % e)

    # Switch this dupe feed's dupe feeds over to the new original.
    duplicate_feeds_duplicate_feeds = DuplicateFeed.objects.filter(feed=duplicate_feed)
    for dupe_feed in duplicate_feeds_duplicate_feeds:
        dupe_feed.feed = original_feed
        dupe_feed.duplicate_feed_id = duplicate_feed.pk
        dupe_feed.save()

    logging.debug(
        " ---> Dupe subscribers (%s): %s, Original subscribers (%s): %s"
        % (duplicate_feed.pk, duplicate_feed.num_subscribers, original_feed.pk, original_feed.num_subscribers)
    )
    if duplicate_feed.pk != original_feed.pk:
        duplicate_feed.delete()
    else:
        logging.debug(" ***> Duplicate feed is the same as original feed. Panic!")
    logging.debug(" ---> Deleted duplicate feed: %s/%s" % (duplicate_feed, duplicate_feed_id))
    original_feed.branch_from_feed = None
    original_feed.count_subscribers()
    original_feed.save()
    logging.debug(" ---> Now original subscribers: %s" % (original_feed.num_subscribers))

    MSharedStory.switch_feed(original_feed_id, duplicate_feed_id)

    return original_feed_id


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
