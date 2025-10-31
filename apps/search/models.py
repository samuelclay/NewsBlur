import datetime
import html
import re
import time
import zlib

import celery
import elasticsearch
import mongoengine as mongo
import numpy as np
import pymongo
import redis
import urllib3
from django.conf import settings
from django.contrib.auth.models import User
from openai import APITimeoutError, OpenAI

from apps.search.projection_matrix import project_vector
from apps.search.tasks import (
    FinishIndexSubscriptionsForDiscover,
    FinishIndexSubscriptionsForSearch,
    IndexFeedsForSearch,
    IndexSubscriptionsChunkForDiscover,
    IndexSubscriptionsChunkForSearch,
    IndexSubscriptionsForDiscover,
    IndexSubscriptionsForSearch,
)
from utils import log as logging
from utils.ai_functions import setup_openai_model
from utils.feed_functions import chunks


class MUserSearch(mongo.Document):
    """Search index state of a user's subscriptions."""

    user_id = mongo.IntField(unique=True)
    last_search_date = mongo.DateTimeField()
    last_discover_date = mongo.DateTimeField(null=True, blank=True)
    subscriptions_indexed = mongo.BooleanField(default=False)
    subscriptions_indexing = mongo.BooleanField(default=False)
    discover_indexed = mongo.BooleanField(default=False)
    discover_indexing = mongo.BooleanField(default=False)
    discover_indexing_date = mongo.DateTimeField(null=True, blank=True)

    meta = {
        "collection": "user_search",
        "indexes": ["user_id"],
        "allow_inheritance": False,
    }

    def __str__(self):
        user = User.objects.get(pk=self.user_id)
        return f"{user.username} ({self.user_id}), {'' if self.subscriptions_indexed else 'not '}indexed, {'' if self.subscriptions_indexing else 'not '}indexing, {'' if self.discover_indexed else 'not '}discover indexed, {'' if self.discover_indexing else 'not '}discover indexing"

    @classmethod
    def get_user(cls, user_id, create=True):
        try:
            user_search = cls.objects.read_preference(pymongo.ReadPreference.PRIMARY).get(user_id=user_id)
        except cls.DoesNotExist:
            if create:
                user_search = cls.objects.create(user_id=user_id)
            else:
                user_search = None

        return user_search

    def touch_search_date(self):
        if not self.subscriptions_indexed and not self.subscriptions_indexing:
            self.schedule_index_subscriptions_for_search()
            self.subscriptions_indexing = True

        self.last_search_date = datetime.datetime.now()
        self.save()

    def touch_discover_date(self):
        if not self.discover_indexed and not self.discover_indexing:
            self.schedule_index_subscriptions_for_discover()
            self.discover_indexing_date = datetime.datetime.now()
            self.discover_indexing = True
        one_day = 60 * 60 * 24
        indexing_expired = (
            self.discover_indexing_date is None
            or (datetime.datetime.now() - self.discover_indexing_date).total_seconds() > one_day
        )
        if not self.discover_indexed and self.discover_indexing and indexing_expired:
            user = User.objects.get(pk=self.user_id)
            if self.discover_indexing_date:
                logging.user(
                    user,
                    f"~FCScheduling indexing ~SBdiscover~SN for ~SB%s~SN because it's been more than one day ({(datetime.datetime.now() - self.discover_indexing_date).total_seconds()})..."
                    % self.user_id,
                )
            else:
                logging.user(
                    user,
                    f"~FCScheduling indexing ~SBdiscover~SN for ~SB%s~SN, because it's never been indexed..."
                    % self.user_id,
                )
            self.schedule_index_subscriptions_for_discover()
            self.discover_indexing = True
            self.discover_indexing_date = datetime.datetime.now()

        self.last_discover_date = datetime.datetime.now()
        self.save()

    def schedule_index_subscriptions_for_search(self):
        IndexSubscriptionsForSearch.apply_async(
            kwargs=dict(user_id=self.user_id),
            queue="search_indexer",
            time_limit=settings.MAX_SECONDS_COMPLETE_ARCHIVE_FETCH,
        )

    def schedule_index_subscriptions_for_discover(self):
        IndexSubscriptionsForDiscover.apply_async(
            kwargs=dict(user_id=self.user_id),
            queue="discover_indexer",
            time_limit=settings.MAX_SECONDS_COMPLETE_ARCHIVE_FETCH,
        )

    # Should be run as a background task
    def index_subscriptions_for_search(self):
        self.index_subscriptions_for("search")

    # Should be run as a background task
    def index_subscriptions_for_discover(self):
        self.index_subscriptions_for("discover")

    def index_subscriptions_for(self, search_type):
        from apps.reader.models import UserSubscription
        from apps.rss_feeds.models import Feed

        if search_type == "search":
            SearchStory.create_elasticsearch_mapping()
        elif search_type == "discover":
            DiscoverStory.create_elasticsearch_mapping()

        start = time.time()
        user = User.objects.get(pk=self.user_id)
        r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
        r.publish(user.username, f"{search_type}_index_complete:start")

        subscriptions = UserSubscription.objects.filter(user=user).only("feed")
        total = subscriptions.count()

        feed_ids = []
        for sub in subscriptions:
            try:
                feed_ids.append(sub.feed.pk)
            except Feed.DoesNotExist:
                continue

        feed_id_chunks = [c for c in chunks(feed_ids, 6)]
        logging.user(
            user, f"~FCIndexing ~SB{total} feeds~SN for {search_type} in {len(feed_id_chunks)} chunks..."
        )

        if search_type == "search":
            # Create search indexing tasks
            search_chunks = [
                IndexSubscriptionsChunkForSearch.s(feed_ids=feed_id_chunk, user_id=self.user_id).set(
                    queue="search_indexer"
                )
                for feed_id_chunk in feed_id_chunks
            ]
            # Create the finish callbacks
            finish_search = FinishIndexSubscriptionsForSearch.s(user_id=self.user_id, start=start).set(
                queue="search_indexer"
            )
            celery.chord(search_chunks)(finish_search)
        elif search_type == "discover":
            # Create discover indexing tasks
            discover_chunks = [
                IndexSubscriptionsChunkForDiscover.s(feed_ids=feed_id_chunk, user_id=self.user_id).set(
                    queue="discover_indexer",
                    time_limit=settings.MAX_SECONDS_COMPLETE_ARCHIVE_FETCH,
                )
                for feed_id_chunk in feed_id_chunks
            ]
            finish_discover = FinishIndexSubscriptionsForDiscover.s(
                user_id=self.user_id, start=start, total=total
            ).set(queue="discover_indexer")
            celery.chord(discover_chunks)(finish_discover)

    def finish_index_subscriptions_for_search(self, start):
        from apps.reader.models import UserSubscription

        r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
        user = User.objects.get(pk=self.user_id)
        subscriptions = UserSubscription.objects.filter(user=user).only("feed")
        total = subscriptions.count()
        duration = time.time() - start

        logging.user(user, "~FCIndexed ~SB%s feeds~SN in ~FM~SB%s~FC~SN sec." % (total, round(duration, 2)))
        r.publish(user.username, "search_index_complete:done")

        self.subscriptions_indexed = True
        self.subscriptions_indexing = False
        self.save()

    def finish_index_subscriptions_for_discover(self, start, total):
        from apps.rss_feeds.models import Feed

        r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
        user = User.objects.get(pk=self.user_id)
        r.publish(user.username, "discover_index_complete:done")

        duration = time.time() - start
        logging.user(
            user,
            "~FCIndexed ~SB%s feeds~SN for discover in ~FM~SB%s~FC~SN sec." % (total, round(duration, 2)),
        )

        self.discover_indexed = True
        self.discover_indexing = False
        self.save()

    def index_subscriptions_chunk_for_search(self, feed_ids):
        from apps.rss_feeds.models import Feed

        r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
        user = User.objects.get(pk=self.user_id)

        logging.user(user, "~FCIndexing %s feeds..." % len(feed_ids))

        for feed_id in feed_ids:
            feed = Feed.get_by_id(feed_id)
            if not feed:
                continue

            feed.index_stories_for_search()

        r.publish(user.username, "search_index_complete:feeds:%s" % ",".join([str(f) for f in feed_ids]))

    def index_subscriptions_chunk_for_discover(self, feed_ids):
        from apps.rss_feeds.models import Feed

        r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
        user = User.objects.get(pk=self.user_id)

        logging.user(user, "~FCIndexing %s feeds for discover..." % len(feed_ids))

        for feed_id in feed_ids:
            feed = Feed.get_by_id(feed_id)
            if not feed:
                continue

            feed.index_stories_for_discover()

        r.publish(user.username, "discover_index_complete:feeds:%s" % ",".join([str(f) for f in feed_ids]))

    @classmethod
    def schedule_index_feeds_for_search(cls, feed_ids, user_id):
        user_search = cls.get_user(user_id, create=False)
        if not user_search or not user_search.subscriptions_indexed or user_search.subscriptions_indexing:
            # User hasn't searched before.
            return

        if not isinstance(feed_ids, list):
            feed_ids = [feed_ids]
        IndexFeedsForSearch.apply_async(
            kwargs=dict(feed_ids=feed_ids, user_id=user_id), queue="search_indexer"
        )

    @classmethod
    def index_feeds_for_search(cls, feed_ids, user_id):
        from apps.rss_feeds.models import Feed

        user = User.objects.get(pk=user_id)

        logging.user(user, "~SB~FCIndexing %s~FC by request..." % feed_ids)

        for feed_id in feed_ids:
            feed = Feed.get_by_id(feed_id)
            if not feed:
                continue

            feed.index_stories_for_search()

    @classmethod
    def remove_all(cls, drop_index=False, search=True, discover=True):
        # You only need to drop the index if there is data you want to clear.
        # A new search server won't need this, as there isn't anything to drop.
        if drop_index:
            logging.info(" ---> ~FRRemoving stories search index...")
            SearchStory.drop()

        user_searches = cls.objects.all()
        logging.info(" ---> ~SN~FRRemoving ~SB%s~SN user searches..." % user_searches.count())
        for user_search in user_searches:
            try:
                user_search.remove(search=search, discover=discover)
            except Exception as e:
                print(" ****> Error on search removal: %s" % e)

    def remove(self, search=True, discover=True):
        from apps.reader.models import UserSubscription
        from apps.rss_feeds.models import Feed

        user = User.objects.get(pk=self.user_id)
        subscriptions = UserSubscription.objects.filter(user=self.user_id)
        total = subscriptions.count()
        removed = 0

        for sub in subscriptions:
            try:
                feed = sub.feed
            except Feed.DoesNotExist:
                continue
            if search and not discover and not feed.search_indexed:
                continue
            if discover and not search and not feed.discover_indexed:
                continue
            if search and discover and not feed.search_indexed and not feed.discover_indexed:
                continue
            if search:
                feed.search_indexed = False
                feed.search_indexing = False
            if discover:
                feed.discover_indexed = False
                feed.discover_indexing = False
            feed.save()
            removed += 1

        logging.user(
            user,
            f"~FCRemoved ~SB{removed}/{total} feed's {'search' if search and not discover else 'discover' if discover and not search else 'search+discover' if search and discover else 'neither'} indexes~SN for ~SB~FB{user.username}~FC~SN.",
        )
        self.delete()


class SearchStory:
    _es_client = None
    name = "stories"

    @classmethod
    def ES(cls):
        if cls._es_client is None:
            cls._es_client = elasticsearch.Elasticsearch(settings.ELASTICSEARCH_STORY_HOST)
            cls.create_elasticsearch_mapping()
        return cls._es_client

    @classmethod
    def index_name(cls):
        return "%s-index" % cls.name

    @classmethod
    def doc_type(cls):
        if settings.DOCKERBUILD or getattr(settings, "ES_IGNORE_TYPE", True):
            return None
        return "%s-type" % cls.name

    @classmethod
    def create_elasticsearch_mapping(cls, delete=False):
        if delete:
            logging.debug(" ---> ~FRDeleting search index for ~FM%s" % cls.index_name())
            try:
                cls.ES().indices.delete(cls.index_name())
            except elasticsearch.exceptions.NotFoundError:
                logging.debug(f" ---> ~FBCan't delete {cls.index_name()} index, doesn't exist...")

        try:
            if cls.ES().indices.exists(cls.index_name()):
                return
        except (elasticsearch.exceptions.ConnectionError, urllib3.exceptions.NewConnectionError) as e:
            logging.debug(f" ***> ~FRNo search server available for index mapping check: {e}")
            return

        mapping = {
            "title": {
                "store": False,
                "type": "text",
                "analyzer": "snowball",
                "term_vector": "yes",
            },
            "content": {
                "store": False,
                "type": "text",
                "analyzer": "snowball",
                "term_vector": "yes",
            },
            "tags": {
                "store": False,
                "type": "text",
                "fields": {"raw": {"type": "text", "analyzer": "keyword", "term_vector": "yes"}},
            },
            "author": {
                "store": False,
                "type": "text",
                "analyzer": "default",
            },
            "feed_id": {"store": False, "type": "integer"},
            "date": {
                "store": False,
                "type": "date",
            },
        }

        try:
            cls.ES().indices.create(
                cls.index_name(), body={"mappings": {"_source": {"enabled": False}, "properties": mapping}}
            )
            logging.debug(" ---> ~FCCreating search index for ~FM%s" % cls.index_name())
        except elasticsearch.exceptions.RequestError as e:
            logging.debug(" ***> ~FRCould not create search index for ~FM%s: %s" % (cls.index_name(), e))
            return
        except (
            elasticsearch.exceptions.ConnectionError,
            urllib3.exceptions.NewConnectionError,
            urllib3.exceptions.ConnectTimeoutError,
        ) as e:
            logging.debug(f" ***> ~FRNo search server available for creating story mapping: {e}")
            return

        cls.ES().indices.flush(cls.index_name())

    @classmethod
    def index(
        cls,
        story_hash,
        story_title,
        story_content,
        story_tags,
        story_author,
        story_feed_id,
        story_date,
    ):
        cls.create_elasticsearch_mapping()

        doc = {
            "content": story_content,
            "title": story_title,
            "tags": ", ".join(story_tags),
            "author": story_author,
            "feed_id": story_feed_id,
            "date": story_date,
        }
        try:
            cls.ES().create(
                index=cls.index_name(), id=story_hash, body=doc, doc_type=cls.doc_type(), ignore=409
            )
        except (elasticsearch.exceptions.ConnectionError, urllib3.exceptions.NewConnectionError) as e:
            logging.debug(f" ***> ~FRNo search server available for story indexing: {e}")
        # if settings.DEBUG:
        #     logging.debug(f" ***> ~FBIndexed {story_hash}")

    @classmethod
    def remove(cls, story_hash):
        if not cls.ES().exists(index=cls.index_name(), id=story_hash, doc_type=cls.doc_type()):
            return

        try:
            cls.ES().delete(index=cls.index_name(), id=story_hash, doc_type=cls.doc_type())
        except elasticsearch.exceptions.NotFoundError:
            cls.ES().delete(index=cls.index_name(), id=story_hash, doc_type="story-type")
        except elasticsearch.exceptions.NotFoundError as e:
            logging.debug(f" ***> ~FRNo search server available for story deletion: {e}")

    @classmethod
    def drop(cls):
        try:
            cls.ES().indices.delete(cls.index_name())
        except elasticsearch.exceptions.NotFoundError:
            logging.debug(" ***> ~FBNo index found, nothing to drop.")

    @classmethod
    def query(cls, feed_ids, query, order, offset, limit, strip=False):
        try:
            cls.ES().indices.flush(cls.index_name())
        except elasticsearch.exceptions.NotFoundError as e:
            logging.debug(f" ***> ~FRNo search server available: {e}")
            return []

        if strip:
            query = re.sub(r"([^\s\w_\-])+", " ", query)  # Strip non-alphanumeric
        query = html.unescape(query)

        body = {
            "query": {
                "bool": {
                    "must": [
                        {"query_string": {"query": query, "default_operator": "AND"}},
                        {"terms": {"feed_id": feed_ids[:2000]}},
                    ]
                }
            },
            "sort": [{"date": {"order": "desc" if order == "newest" else "asc"}}],
            "from": offset,
            "size": limit,
        }
        try:
            results = cls.ES().search(body=body, index=cls.index_name(), doc_type=cls.doc_type())
        except elasticsearch.exceptions.RequestError as e:
            logging.debug(" ***> ~FRNo search server available for querying: %s" % e)
            return []

        # s = elasticsearch_dsl.Search(using=cls.ES(), index=cls.index_name())
        # string_q = elasticsearch_dsl.Q('query_string', query=query, default_operator="AND")
        # feed_q = elasticsearch_dsl.Q('terms', feed_id=feed_ids[:2000])
        # search_q = string_q & feed_q
        # s = s.query(search_q)
        # s = s.sort(sort)[offset:offset+limit]
        # results = s.execute()

        # string_q = pyes.query.QueryStringQuery(query, default_operator="AND")
        # feed_q   = pyes.query.TermsQuery('feed_id', feed_ids[:2000])
        # q        = pyes.query.BoolQuery(must=[string_q, feed_q])
        # try:
        #     results  = cls.ES().search(q, indices=cls.index_name(),
        #                                partial_fields={}, sort=sort, start=offset, size=limit)
        # except elasticsearch.exceptions.ConnectionError:
        #     logging.debug(" ***> ~FRNo search server available.")
        #     return []

        logging.info(
            " ---> ~FG~SNSearch ~FCstories~FG for: ~SB%s~SN, ~SB%s~SN results (across %s feed%s)"
            % (query, len(results["hits"]["hits"]), len(feed_ids), "s" if len(feed_ids) != 1 else "")
        )

        try:
            result_ids = [r["_id"] for r in results["hits"]["hits"]]
        except Exception as e:
            logging.info(' ---> ~FRInvalid search query "%s": %s' % (query, e))
            return []

        return result_ids

    @classmethod
    def global_query(cls, query, order, offset, limit, strip=False):
        cls.create_elasticsearch_mapping()
        cls.ES().indices.flush()

        if strip:
            query = re.sub(r"([^\s\w_\-])+", " ", query)  # Strip non-alphanumeric
        query = html.unescape(query)

        body = {
            "query": {
                "bool": {
                    "must": [
                        {"query_string": {"query": query, "default_operator": "AND"}},
                    ]
                }
            },
            "sort": [{"date": {"order": "desc" if order == "newest" else "asc"}}],
            "from": offset,
            "size": limit,
        }
        try:
            results = cls.ES().search(body=body, index=cls.index_name(), doc_type=cls.doc_type())
        except elasticsearch.exceptions.RequestError as e:
            logging.debug(" ***> ~FRNo search server available for querying: %s" % e)
            return []

        # sort     = "date:desc" if order == "newest" else "date:asc"
        # string_q = pyes.query.QueryStringQuery(query, default_operator="AND")
        # try:
        #     results  = cls.ES().search(string_q, indices=cls.index_name(),
        #                                partial_fields={}, sort=sort, start=offset, size=limit)
        # except elasticsearch.exceptions.ConnectionError:
        #     logging.debug(" ***> ~FRNo search server available.")
        #     return []

        logging.info(" ---> ~FG~SNSearch ~FCstories~FG for: ~SB%s~SN (across all feeds)" % (query))

        try:
            result_ids = [r["_id"] for r in results["hits"]["hits"]]
        except Exception as e:
            logging.info(' ---> ~FRInvalid search query "%s": %s' % (query, e))
            return []

        return result_ids

    @classmethod
    def more_like_this(cls, feed_ids, story_hash, order, offset, limit):
        try:
            cls.ES().indices.flush(cls.index_name())
        except elasticsearch.exceptions.NotFoundError as e:
            logging.debug(f" ***> ~FRNo search server available: {e}")
            return []

        body = {
            "query": {
                "bool": {
                    "filter": [
                        {
                            "more_like_this": {
                                "fields": ["title", "content"],
                                "like": [
                                    {
                                        "_index": cls.index_name(),
                                        "_id": story_hash,
                                    }
                                ],
                                "min_term_freq": 3,
                                "min_doc_freq": 2,
                                "min_word_length": 4,
                            },
                        },
                        {"terms": {"feed_id": feed_ids[:2000]}},
                    ],
                }
            },
            "sort": [{"date": {"order": "desc" if order == "newest" else "asc"}}],
            "from": offset,
            "size": limit,
        }
        try:
            results = cls.ES().search(body=body, index=cls.index_name(), doc_type=cls.doc_type())
        except elasticsearch.exceptions.RequestError as e:
            logging.debug(" ***> ~FRNo search server available for querying: %s" % e)
            return []

        logging.info(
            " ---> ~FG~SNMore like this ~FCstories~FG for: ~SB%s~SN, ~SB%s~SN results (across %s feed%s)"
            % (story_hash, len(results["hits"]["hits"]), len(feed_ids), "s" if len(feed_ids) != 1 else "")
        )

        try:
            result_ids = [r["_id"] for r in results["hits"]["hits"]]
        except Exception as e:
            logging.info(' ---> ~FRInvalid more like this query "%s": %s' % (story_hash, e))
            return []

        return result_ids

    @classmethod
    def debug_index(cls, show_data=True, show_source=False):
        """Debug method to inspect index fields and entries.

        Args:
            show_data: If True, will show sample documents. Defaults to False to avoid large outputs.
        """
        try:
            # Check if index exists
            if not cls.ES().indices.exists(cls.index_name()):
                logging.info(f"~FR Index {cls.index_name()} does not exist")
                return

            # Get index mapping
            mapping = cls.ES().indices.get_mapping(index=cls.index_name())
            logging.info(f"~FB Index mapping for {cls.index_name()}:")
            logging.info(
                f"Properties: {list(mapping[cls.index_name()]['mappings'].get('properties', {}).keys())}"
            )
            logging.info(f"Full mapping: {mapping}")

            # Get index settings
            settings = cls.ES().indices.get_settings(index=cls.index_name())
            logging.info(f"~FB Index settings:")
            logging.info(settings)

            # Get index stats
            stats = cls.ES().indices.stats(index=cls.index_name())
            total_docs = stats["indices"][cls.index_name()]["total"]["docs"]["count"]
            logging.info(f"~FG Total documents in index: {total_docs}")

            if show_data:
                # Sample some documents
                body = {
                    "query": {"match_all": {}},
                    "size": 3,  # Limit to 3 documents for sample
                    "sort": [{"date": {"order": "desc"}}],
                }
                results = cls.ES().search(body=body, index=cls.index_name())

                logging.info("~FB Sample documents:")
                for hit in results["hits"]["hits"]:
                    logging.info(f"Document ID: {hit['_id']}")
                    logging.info(f"Fields: {list(hit.get('_source', {}).keys())}")
                    if show_source:
                        logging.info(f"Content: {hit.get('_source', {})}")
                    logging.info("---")

        except elasticsearch.exceptions.NotFoundError as e:
            logging.info(f"~FR Error accessing index: {e}")
        except Exception as e:
            logging.info(f"~FR Unexpected error: {e}")


class DiscoverStory:
    _es_client = None
    name = "discover-stories-openai"

    @classmethod
    def ES(cls):
        if cls._es_client is None:
            cls._es_client = elasticsearch.Elasticsearch(settings.ELASTICSEARCH_DISCOVER_HOST)
            cls.create_elasticsearch_mapping()
        return cls._es_client

    @classmethod
    def index_name(cls):
        return "%s-index" % cls.name

    @classmethod
    def doc_type(cls):
        if settings.DOCKERBUILD or getattr(settings, "ES_IGNORE_TYPE", True):
            return None
        return "%s-type" % cls.name

    @classmethod
    def create_elasticsearch_mapping(cls, delete=False):
        if delete:
            logging.debug(" ---> ~FRDeleting search index for ~FM%s" % cls.index_name())
            try:
                cls.ES().indices.delete(cls.index_name())
            except elasticsearch.exceptions.NotFoundError:
                logging.debug(f" ---> ~FBCan't delete {cls.index_name()} index, doesn't exist...")

        try:
            if cls.ES().indices.exists(cls.index_name()):
                return
        except (elasticsearch.exceptions.ConnectionError, urllib3.exceptions.NewConnectionError) as e:
            logging.debug(f" ***> ~FRNo search server available for index mapping check: {e}")
            return

        mapping = {
            "feed_id": {"store": False, "type": "integer"},
            "date": {
                "store": False,
                "type": "date",
            },
            "content_vector": {
                "type": "dense_vector",
                "dims": 256,  # Reduced from openai embedding size of 1536 to 256
                "index": True,
                "index_options": {"type": "bbq_hnsw"},  # Use bbq_hnsw index options for faster search
            },
        }

        try:
            cls.ES().indices.create(
                cls.index_name(), body={"mappings": {"_source": {"enabled": True}, "properties": mapping}}
            )
            logging.debug(" ---> ~FCCreating search index for ~FM%s" % cls.index_name())
        except elasticsearch.exceptions.RequestError as e:
            logging.debug(" ***> ~FRCould not create search index for ~FM%s: %s" % (cls.index_name(), e))
            return
        except (
            elasticsearch.exceptions.ConnectionError,
            urllib3.exceptions.NewConnectionError,
            urllib3.exceptions.ConnectTimeoutError,
        ) as e:
            logging.debug(f" ***> ~FRNo search server available for creating story mapping: {e}")
            return

        cls.ES().indices.flush(cls.index_name())

    @classmethod
    def index(
        cls,
        story_hash,
        story_feed_id,
        story_date,
        story_content_vector=None,
        verbose=False,
    ):
        cls.create_elasticsearch_mapping()

        # Check if already indexed to avoid expensive vector generation
        try:
            if cls.ES().exists(index=cls.index_name(), id=story_hash, doc_type=cls.doc_type()):
                if verbose:
                    logging.debug(f" ---> ~FBStory already indexed: {story_hash}")
                return
        except (elasticsearch.exceptions.ConnectionError, urllib3.exceptions.NewConnectionError) as e:
            logging.debug(f" ***> ~FRNo search server available for checking discover story: {e}")
            return

        if not story_content_vector:
            story_content_vector = cls.generate_story_content_vector(story_hash)

        if not story_content_vector:
            logging.debug(f" ***> ~FRNo content vector found for story {story_hash}")
            return

        doc = {
            "feed_id": story_feed_id,
            "date": story_date,
            "content_vector": story_content_vector,
        }
        try:
            if verbose:
                logging.debug(f" ---> ~SN~FCIndexing discover story: ~SB~FC{story_hash}")
            cls.ES().create(index=cls.index_name(), id=story_hash, body=doc, doc_type=cls.doc_type(), ignore=409)
        except (elasticsearch.exceptions.ConnectionError, urllib3.exceptions.NewConnectionError) as e:
            logging.debug(f" ***> ~FRNo search server available for discover story indexing: {e}")
        # if settings.DEBUG:
        #     logging.debug(f" ***> ~FBIndexed {story_hash}")

    @classmethod
    def remove(cls, story_hash):
        if not cls.ES().exists(index=cls.index_name(), id=story_hash, doc_type=cls.doc_type()):
            return

        try:
            cls.ES().delete(index=cls.index_name(), id=story_hash, doc_type=cls.doc_type())
        except elasticsearch.exceptions.NotFoundError:
            cls.ES().delete(index=cls.index_name(), id=story_hash, doc_type="story-type")
        except elasticsearch.exceptions.NotFoundError as e:
            logging.debug(f" ***> ~FRNo search server available for story deletion: {e}")

    @classmethod
    def drop(cls):
        try:
            cls.ES().indices.delete(cls.index_name())
        except elasticsearch.exceptions.NotFoundError:
            logging.debug(" ***> ~FBNo index found, nothing to drop.")

    @classmethod
    def vector_query(
        cls,
        query_vector,
        offset=0,
        max_results=10,
        feed_ids_to_include=None,
        feed_ids_to_exclude=None,
        story_hashes_to_exclude=None,
    ):
        try:
            cls.ES().indices.flush(index=cls.index_name())
        except elasticsearch.exceptions.NotFoundError as e:
            logging.debug(f" ***> ~FRNo search server available: {e}")
            return []

        must_clauses = [
            {
                "script_score": {
                    "query": {"match_all": {}},
                    "script": {
                        "source": "cosineSimilarity(params.query_vector, 'content_vector') + 1.0",
                        "params": {"query_vector": query_vector},
                    },
                }
            }
        ]
        must_not_clauses = []

        if feed_ids_to_include:
            must_clauses.append({"terms": {"feed_id": feed_ids_to_include}})
        if feed_ids_to_exclude:
            must_not_clauses.append({"terms": {"feed_id": feed_ids_to_exclude}})
        if story_hashes_to_exclude:
            must_not_clauses.append({"ids": {"values": story_hashes_to_exclude}})

        clauses = {}
        if must_clauses:
            clauses["must"] = must_clauses
        if must_not_clauses:
            clauses["must_not"] = must_not_clauses

        body = {
            "query": {
                "bool": clauses,
            },
            "size": max_results,
            "from": offset,
        }

        logging.debug(f"~FBVector query: {body}")
        try:
            results = cls.ES().search(body=body, index=cls.index_name())
        except elasticsearch.exceptions.RequestError as e:
            logging.debug(" ***> ~FRNo search server available for querying: %s" % e)
            return []

        logging.info(
            f"~FGVector search ~FCstories~FG: ~SB{max_results}~SN requested{f'~SB offset {offset}~SN' if offset else ''}, ~SB{len(results['hits']['hits'])}~SN results"
        )

        return results["hits"]["hits"]

    @classmethod
    def fetch_story_content_vector(cls, story_hash):
        # Fetch the content vector from ES for the specified story_hash
        try:
            cls.ES().indices.flush(index=cls.index_name())
        except elasticsearch.exceptions.NotFoundError as e:
            logging.debug(f" ***> ~FRNo search server available: {e}")
            return []

        body = {"query": {"ids": {"values": [story_hash]}}}
        try:
            results = cls.ES().search(body=body, index=cls.index_name(), doc_type=cls.doc_type())
        except elasticsearch.exceptions.RequestError as e:
            logging.debug(" ***> ~FRNo search server available for querying: %s" % e)
            return []
        # logging.debug(f"Results: {results}")
        if len(results["hits"]["hits"]) == 0:
            logging.debug(f" ---> ~FRNo content vector found for story {story_hash}")
            return []
        return results["hits"]["hits"][0]["_source"]["content_vector"]

    @classmethod
    def generate_combined_story_content_vector(cls, story_hashes):
        vectors = []
        for story_hash in story_hashes:
            vector = cls.fetch_story_content_vector(story_hash)
            if not vector:
                vector = cls.generate_story_content_vector(story_hash)
            vectors.append(vector)

        combined_vector = np.mean(vectors, axis=0)
        normalized_combined_vector = combined_vector / np.linalg.norm(combined_vector)

        return normalized_combined_vector

    @classmethod
    def generate_story_content_vector(cls, story_hash):
        from apps.rss_feeds.models import MStory

        try:
            story = MStory.objects.get(story_hash=story_hash)
        except MStory.DoesNotExist:
            logging.debug(f" ***> ~FRNo story found for {story_hash}")
            return []

        story_title = story.story_title
        story_tags = ", ".join(story.story_tags)
        story_content = ""
        if story.story_original_content_z:
            story_content = zlib.decompress(story.story_original_content_z)
        elif story.story_content_z:
            story_content = zlib.decompress(story.story_content_z)
        else:
            story_content = story.story_content
        story_text = f"{story_title} {story_tags} {story_content}"

        # Remove URLs
        story_text = re.sub(r"http\S+", "", story_text)

        # Remove special characters
        story_text = re.sub(r"[^\w\s]", "", story_text)

        # Convert to lowercase
        story_text = story_text.lower()

        # Remove extra whitespace
        story_text = " ".join(story_text.split())

        # Send to OpenAI
        model_name = "text-embedding-3-small"
        encoding = setup_openai_model(model_name)

        # Truncate the text to the maximum number of tokens
        max_tokens = 8191  # Maximum for text-embedding-3-small
        encoded_text = encoding.encode(story_text)
        truncated_tokens = encoded_text[:max_tokens]
        truncated_text = encoding.decode(truncated_tokens)

        client = OpenAI(api_key=settings.OPENAI_API_KEY)

        try:
            response = client.embeddings.create(model=model_name, input=truncated_text)
        except APITimeoutError as e:
            logging.debug(f" ***> ~FROpenAI API timeout: {e}")
            return []
        story_embedding = response.data[0].embedding

        # Project the embedding down to 256 dimensions
        projected_embedding = project_vector(story_embedding)

        return projected_embedding.tolist()

    @classmethod
    def debug_index(cls, show_data=True, show_source=False):
        """Debug method to inspect index fields and entries.

        Args:
            show_data: If True, will show sample documents. Defaults to False to avoid large outputs.
        """
        try:
            # Check if index exists
            if not cls.ES().indices.exists(cls.index_name()):
                logging.info(f"~FR Index {cls.index_name()} does not exist")
                return

            # Get index mapping
            mapping = cls.ES().indices.get_mapping(index=cls.index_name())
            logging.info(f"~FB Index mapping for {cls.index_name()}:")
            logging.info(
                f"Properties: {list(mapping[cls.index_name()]['mappings'].get('properties', {}).keys())}"
            )
            logging.info(f"Full mapping: {mapping}")

            # Get index settings
            settings = cls.ES().indices.get_settings(index=cls.index_name())
            logging.info(f"~FB Index settings:")
            logging.info(settings)

            # Get index stats
            stats = cls.ES().indices.stats(index=cls.index_name())
            total_docs = stats["indices"][cls.index_name()]["total"]["docs"]["count"]
            logging.info(f"~FG Total documents in index: {total_docs}")

            if show_data:
                # Sample some documents
                body = {
                    "query": {"match_all": {}},
                    "size": 3,  # Limit to 3 documents for sample
                    "sort": [{"date": {"order": "desc"}}],
                }
                results = cls.ES().search(body=body, index=cls.index_name())

                logging.info("~FB Sample documents:")
                for hit in results["hits"]["hits"]:
                    logging.info(f"Document ID: {hit['_id']}")
                    logging.info(f"Fields: {list(hit.get('_source', {}).keys())}")
                    if show_source:
                        logging.info(f"Content: {hit.get('_source', {})}")
                    logging.info("---")

        except elasticsearch.exceptions.NotFoundError as e:
            logging.info(f"~FR Error accessing index: {e}")
        except Exception as e:
            logging.info(f"~FR Unexpected error: {e}")


class SearchFeed:
    _es_client = None
    name = "discover-feeds-openai"
    model = None

    @classmethod
    def ES(cls):
        if cls._es_client is None:
            cls._es_client = elasticsearch.Elasticsearch(settings.ELASTICSEARCH_FEED_HOST)
            cls.create_elasticsearch_mapping()
        return cls._es_client

    @classmethod
    def index_name(cls):
        # feeds-index
        return "%s-index" % cls.name

    @classmethod
    def doc_type(cls):
        if settings.DOCKERBUILD or getattr(settings, "ES_IGNORE_TYPE", True):
            return None
        return "%s-type" % cls.name

    @classmethod
    def create_elasticsearch_mapping(cls, delete=False):
        if delete:
            logging.debug(" ---> ~FRDeleting search index for ~FM%s" % cls.index_name())
            try:
                cls.ES().indices.delete(cls.index_name())
            except elasticsearch.exceptions.NotFoundError:
                logging.debug(f" ---> ~FBCan't delete {cls.index_name()} index, doesn't exist...")

        try:
            if cls.ES().indices.exists(cls.index_name()):
                return
        except (elasticsearch.exceptions.ConnectionError, urllib3.exceptions.NewConnectionError) as e:
            logging.debug(f" ***> ~FRNo search server available for index mapping check: {e}")
            return

        index_settings = {
            "index": {
                "analysis": {
                    "analyzer": {
                        "edgengram_analyzer": {
                            "filter": ["edgengram_analyzer"],
                            "tokenizer": "lowercase",
                            "type": "custom",
                        },
                    },
                    "filter": {
                        "edgengram_analyzer": {"max_gram": "15", "min_gram": "1", "type": "edge_ngram"},
                    },
                }
            }
        }

        try:
            cls.ES().indices.create(cls.index_name(), body={"settings": index_settings})
            logging.debug(" ---> ~FCCreating search index for ~FM%s" % cls.index_name())
        except elasticsearch.exceptions.RequestError as e:
            logging.debug(" ***> ~FRCould not create search index for ~FM%s: %s" % (cls.index_name(), e))
            return
        except (
            elasticsearch.exceptions.ConnectionError,
            urllib3.exceptions.NewConnectionError,
            urllib3.exceptions.ConnectTimeoutError,
        ) as e:
            logging.debug(f" ***> ~FRNo search server available for creating feed mapping: {e}")
            return

        mapping = {
            "feed_address": {
                "analyzer": "snowball",
                "store": False,
                "term_vector": "with_positions_offsets",
                "type": "text",
            },
            "feed_id": {"store": True, "type": "text"},
            "num_subscribers": {"store": True, "type": "long"},
            "title": {
                "analyzer": "snowball",
                "store": False,
                "term_vector": "with_positions_offsets",
                "type": "text",
            },
            "link": {
                "analyzer": "snowball",
                "store": False,
                "term_vector": "with_positions_offsets",
                "type": "text",
            },
            "content_vector": {
                "type": "dense_vector",
                "dims": 1536,  # Numbers of dims from text-embedding-3-small
            },
        }
        cls.ES().indices.put_mapping(
            body={
                "properties": mapping,
            },
            index=cls.index_name(),
        )
        cls.ES().indices.flush(cls.index_name())

    @classmethod
    def index(cls, feed_id, title, address, link, num_subscribers, content_vector):
        doc = {
            "feed_id": feed_id,
            "title": title,
            "feed_address": address,
            "link": link,
            "num_subscribers": num_subscribers,
            "content_vector": content_vector,
        }
        try:
            cls.ES().create(index=cls.index_name(), id=feed_id, body=doc, doc_type=cls.doc_type(), ignore=409)
        except (elasticsearch.exceptions.ConnectionError, urllib3.exceptions.NewConnectionError) as e:
            logging.debug(f" ***> ~FRNo search server available for feed indexing: {e}")

    @classmethod
    def drop(cls):
        try:
            cls.ES().indices.delete(cls.index_name())
        except elasticsearch.exceptions.NotFoundError:
            logging.debug(" ***> ~FBNo index found, nothing to drop.")

    @classmethod
    def query(cls, text, max_subscribers=5):
        try:
            cls.ES().indices.flush(index=cls.index_name())
        except elasticsearch.exceptions.NotFoundError as e:
            logging.debug(f" ***> ~FRNo search server available: {e}")
            return []

        if settings.DEBUG:
            max_subscribers = 1

        body = {
            "query": {
                "bool": {
                    "should": [
                        {
                            "match": {
                                "address": {
                                    "query": text,
                                    "minimum_should_match": "75%",
                                }
                            }
                        },
                        {
                            "match": {
                                "title": {
                                    "query": text,
                                    "minimum_should_match": "75%",
                                }
                            }
                        },
                        {
                            "match": {
                                "link": {
                                    "query": text,
                                    "minimum_should_match": "75%",
                                }
                            }
                        },
                    ]
                }
            },
            "sort": [{"num_subscribers": {"order": "desc"}}],
        }
        try:
            results = cls.ES().search(body=body, index=cls.index_name(), doc_type=cls.doc_type())
        except elasticsearch.exceptions.RequestError as e:
            logging.debug(" ***> ~FRNo search server available for querying: %s" % e)
            return []

        # s = elasticsearch_dsl.Search(using=cls.ES(), index=cls.index_name())
        # address = elasticsearch_dsl.Q('match', address=text)
        # link = elasticsearch_dsl.Q('match', link=text)
        # title = elasticsearch_dsl.Q('match', title=text)
        # search_q = address | link | title
        # s = s.query(search_q).extra(cutoff_frequency="0.0005", minimum_should_match="75%")
        # s = s.sort("-num_subscribers")
        # body = s.to_dict()
        # print(f"Before: {body}")
        # results = s.execute()

        # q = pyes.query.BoolQuery()
        # q.add_should(pyes.query.MatchQuery('address', text, analyzer="simple", cutoff_frequency=0.0005, minimum_should_match="75%"))
        # q.add_should(pyes.query.MatchQuery('link', text, analyzer="simple", cutoff_frequency=0.0005, minimum_should_match="75%"))
        # q.add_should(pyes.query.MatchQuery('title', text, analyzer="simple", cutoff_frequency=0.0005, minimum_should_match="75%"))
        # q = pyes.Search(q, min_score=1)
        # results = cls.ES().search(query=q, size=max_subscribers, sort="num_subscribers:desc")

        logging.info(
            "~FGSearch ~FCfeeds~FG: ~SB%s~SN, ~SB%s~SN results" % (text, len(results["hits"]["hits"]))
        )

        return results["hits"]["hits"]

    @classmethod
    def vector_query(cls, query_vector, offset=0, max_results=10, feed_ids_to_exclude=None):
        try:
            cls.ES().indices.flush(index=cls.index_name())
        except elasticsearch.exceptions.NotFoundError as e:
            logging.debug(f" ***> ~FRNo search server available: {e}")
            return []

        must_not_clauses = []
        if feed_ids_to_exclude:
            must_not_clauses.append({"terms": {"feed_id": feed_ids_to_exclude}})

        body = {
            "query": {
                "bool": {
                    "must": {
                        "script_score": {
                            "query": {"match_all": {}},
                            "script": {
                                "source": "cosineSimilarity(params.query_vector, 'content_vector') + 1.0",
                                "params": {"query_vector": query_vector},
                            },
                        }
                    },
                    "must_not": must_not_clauses,
                }
            },
            "size": max_results,
            "from": offset,
        }
        try:
            results = cls.ES().search(body=body, index=cls.index_name(), doc_type=cls.doc_type())
        except elasticsearch.exceptions.RequestError as e:
            logging.debug(" ***> ~FRNo search server available for querying: %s" % e)
            return []

        logging.info(
            f"~FGVector search ~FCfeeds~FG: ~SB{max_results}~SN requested{f'~SB offset {offset}~SN' if offset else ''}, ~SB{len(results['hits']['hits'])}~SN results"
        )

        return results["hits"]["hits"]

    @classmethod
    def fetch_feed_content_vector(cls, feed_id):
        # Fetch the content vector from ES for the specified feed_id
        try:
            cls.ES().indices.flush(index=cls.index_name())
        except (elasticsearch.exceptions.NotFoundError, elasticsearch.exceptions.ConnectionError) as e:
            logging.debug(f" ***> ~FRNo search server available: {e}")
            return []

        body = {"query": {"term": {"feed_id": feed_id}}}

        try:
            results = cls.ES().search(body=body, index=cls.index_name(), doc_type=cls.doc_type())
        except elasticsearch.exceptions.RequestError as e:
            logging.debug(" ***> ~FRNo search server available for querying: %s" % e)
            return []

        # logging.debug(f"Results: {results}")
        if len(results["hits"]["hits"]) == 0:
            logging.debug(f" ---> ~FRNo content vector found for feed {feed_id}")
            return []

        return results["hits"]["hits"][0]["_source"]["content_vector"]

    @classmethod
    def generate_combined_feed_content_vector(cls, feed_ids):
        vectors = []
        for feed_id in feed_ids:
            vector = cls.fetch_feed_content_vector(feed_id)
            if not vector:
                vector = cls.generate_feed_content_vector(feed_id)
            vectors.append(vector)

        combined_vector = np.mean(vectors, axis=0)
        normalized_combined_vector = combined_vector / np.linalg.norm(combined_vector)

        return normalized_combined_vector

    @classmethod
    def generate_feed_content_vector(cls, feed_id):
        from apps.rss_feeds.models import Feed

        feed = Feed.objects.get(id=feed_id)

        stories = feed.get_stories()
        stories_text = ""
        for story in stories:
            stories_text += f"{story['story_title']} {' '.join([tag for tag in story['story_tags']])}"
        text = f"{feed.feed_title} {feed.data.feed_tagline} {stories_text}"

        # Remove URLs
        text = re.sub(r"http\S+", "", text)

        # Remove special characters
        text = re.sub(r"[^\w\s]", "", text)

        # Convert to lowercase
        text = text.lower()

        # Remove extra whitespace
        text = " ".join(text.split())

        # Send to OpenAI
        model_name = "text-embedding-3-small"
        encoding = setup_openai_model(model_name)

        # Truncate the text to the maximum number of tokens
        max_tokens = 8191  # Maximum for text-embedding-3-small
        encoded_text = encoding.encode(text)
        truncated_tokens = encoded_text[:max_tokens]
        truncated_text = encoding.decode(truncated_tokens)

        client = OpenAI(api_key=settings.OPENAI_API_KEY)

        response = client.embeddings.create(model=model_name, input=truncated_text)

        embedding = response.data[0].embedding
        # normalized_embedding = np.array(embedding) / np.linalg.norm(embedding)

        return embedding

    @classmethod
    def export_csv(cls):
        import djqscsv

        from apps.rss_feeds.models import Feed

        qs = Feed.objects.filter(num_subscribers__gte=20).values(
            "id", "feed_title", "feed_address", "feed_link", "num_subscribers"
        )
        csv = djqscsv.render_to_csv_response(qs).content
        f = open("feeds.csv", "w+")
        f.write(csv)
        f.close()

    @classmethod
    def debug_index(cls, show_data=True, show_source=False):
        """Debug method to inspect index fields and entries.

        Args:
            show_data: If True, will show sample documents. Defaults to False to avoid large outputs.
        """
        try:
            # Check if index exists
            if not cls.ES().indices.exists(cls.index_name()):
                logging.info(f"~FR Index {cls.index_name()} does not exist")
                return

            # Get index mapping
            mapping = cls.ES().indices.get_mapping(index=cls.index_name())
            logging.info(f"~FB Index mapping for {cls.index_name()}:")
            logging.info(
                f"Properties: {list(mapping[cls.index_name()]['mappings'].get('properties', {}).keys())}"
            )
            logging.info(f"Full mapping: {mapping}")

            # Get index settings
            settings = cls.ES().indices.get_settings(index=cls.index_name())
            logging.info(f"~FB Index settings:")
            logging.info(settings)

            # Get index stats
            stats = cls.ES().indices.stats(index=cls.index_name())
            total_docs = stats["indices"][cls.index_name()]["total"]["docs"]["count"]
            logging.info(f"~FG Total documents in index: {total_docs}")

            if show_data:
                # Sample some documents
                body = {
                    "query": {"match_all": {}},
                    "size": 3,  # Limit to 3 documents for sample
                    "sort": [{"num_subscribers": {"order": "desc"}}],
                }
                results = cls.ES().search(body=body, index=cls.index_name())

                logging.info("~FB Sample documents:")
                for hit in results["hits"]["hits"]:
                    logging.info(f"Document ID: {hit['_id']}")
                    logging.info(f"Fields: {list(hit.get('_source', {}).keys())}")
                    if show_source:
                        logging.info(f"Content: {hit.get('_source', {})}")
                    logging.info("---")

        except elasticsearch.exceptions.NotFoundError as e:
            logging.info(f"~FR Error accessing index: {e}")
        except Exception as e:
            logging.info(f"~FR Unexpected error: {e}")
