import re
import time
import datetime
import pymongo
import elasticsearch
import redis
import urllib3
import celery
import html
import mongoengine as mongo
from django.conf import settings
from django.contrib.auth.models import User
from apps.search.tasks import IndexSubscriptionsForSearch
from apps.search.tasks import FinishIndexSubscriptionsForSearch
from apps.search.tasks import IndexSubscriptionsChunkForSearch
from apps.search.tasks import IndexFeedsForSearch
from utils import log as logging
from utils.feed_functions import chunks

class MUserSearch(mongo.Document):
    '''Search index state of a user's subscriptions.'''
    user_id                  = mongo.IntField(unique=True)
    last_search_date         = mongo.DateTimeField()
    subscriptions_indexed    = mongo.BooleanField()
    subscriptions_indexing   = mongo.BooleanField()
    
    meta = {
        'collection': 'user_search',
        'indexes': ['user_id'],
        'allow_inheritance': False,
    }
    
    @classmethod
    def get_user(cls, user_id, create=True):
        try:
            user_search = cls.objects.read_preference(pymongo.ReadPreference.PRIMARY)\
                                     .get(user_id=user_id)
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

    def schedule_index_subscriptions_for_search(self):
        IndexSubscriptionsForSearch.apply_async(kwargs=dict(user_id=self.user_id), 
                                                queue='search_indexer')
        
    # Should be run as a background task
    def index_subscriptions_for_search(self):
        from apps.rss_feeds.models import Feed
        from apps.reader.models import UserSubscription
        
        SearchStory.create_elasticsearch_mapping()
        
        start = time.time()
        user = User.objects.get(pk=self.user_id)
        r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
        r.publish(user.username, 'search_index_complete:start')
        
        subscriptions = UserSubscription.objects.filter(user=user).only('feed')
        total = subscriptions.count()
        
        feed_ids = []
        for sub in subscriptions:
            try:
                feed_ids.append(sub.feed.pk)
            except Feed.DoesNotExist:
                continue
        
        feed_id_chunks = [c for c in chunks(feed_ids, 6)]
        logging.user(user, "~FCIndexing ~SB%s feeds~SN in %s chunks..." %
                     (total, len(feed_id_chunks)))
        
        search_chunks = [IndexSubscriptionsChunkForSearch.s(feed_ids=feed_id_chunk,
                                                            user_id=self.user_id
                                                            ).set(queue='search_indexer')
                         for feed_id_chunk in feed_id_chunks]
        callback = FinishIndexSubscriptionsForSearch.s(user_id=self.user_id,
                                                       start=start).set(queue='search_indexer')
        celery.chord(search_chunks)(callback)

    def finish_index_subscriptions_for_search(self, start):
        from apps.reader.models import UserSubscription
        
        r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
        user = User.objects.get(pk=self.user_id)
        subscriptions = UserSubscription.objects.filter(user=user).only('feed')
        total = subscriptions.count()
        duration = time.time() - start

        logging.user(user, "~FCIndexed ~SB%s feeds~SN in ~FM~SB%s~FC~SN sec." % 
                     (total, round(duration, 2)))
        r.publish(user.username, 'search_index_complete:done')
        
        self.subscriptions_indexed = True
        self.subscriptions_indexing = False
        self.save()
    
    def index_subscriptions_chunk_for_search(self, feed_ids):
        from apps.rss_feeds.models import Feed
        r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
        user = User.objects.get(pk=self.user_id)

        logging.user(user, "~FCIndexing %s feeds..." % len(feed_ids))

        for feed_id in feed_ids:
            feed = Feed.get_by_id(feed_id)
            if not feed: continue
            
            feed.index_stories_for_search()
            
        r.publish(user.username, 'search_index_complete:feeds:%s' % 
                  ','.join([str(f) for f in feed_ids]))
    
    @classmethod
    def schedule_index_feeds_for_search(cls, feed_ids, user_id):
        user_search = cls.get_user(user_id, create=False)
        if (not user_search or 
            not user_search.subscriptions_indexed or 
            user_search.subscriptions_indexing):
            # User hasn't searched before.
            return
        
        if not isinstance(feed_ids, list):
            feed_ids = [feed_ids]
        IndexFeedsForSearch.apply_async(kwargs=dict(feed_ids=feed_ids, user_id=user_id), 
                                        queue='search_indexer')
    
    @classmethod
    def index_feeds_for_search(cls, feed_ids, user_id):
        from apps.rss_feeds.models import Feed
        user = User.objects.get(pk=user_id)

        logging.user(user, "~SB~FCIndexing %s~FC by request..." % feed_ids)

        for feed_id in feed_ids:
            feed = Feed.get_by_id(feed_id)
            if not feed: continue
            
            feed.index_stories_for_search()
        
    @classmethod
    def remove_all(cls, drop_index=False):
        # You only need to drop the index if there is data you want to clear.
        # A new search server won't need this, as there isn't anything to drop.
        if drop_index:
            logging.info(" ---> ~FRRemoving stories search index...")
            SearchStory.drop()
            
        user_searches = cls.objects.all()
        logging.info(" ---> ~SN~FRRemoving ~SB%s~SN user searches..." % user_searches.count())
        for user_search in user_searches:
            try:
                user_search.remove()
            except Exception as e:
                print(" ****> Error on search removal: %s" % e)
        
    def remove(self):
        from apps.rss_feeds.models import Feed
        from apps.reader.models import UserSubscription

        user = User.objects.get(pk=self.user_id)
        subscriptions = UserSubscription.objects.filter(user=self.user_id)
        total = subscriptions.count()
        removed = 0
        
        for sub in subscriptions:
            try:
                feed = sub.feed
            except Feed.DoesNotExist:
                continue
            if not feed.search_indexed:
                continue
            feed.search_indexed = False
            feed.save()
            removed += 1
            
        logging.user(user, "~FCRemoved ~SB%s/%s feed's search indexes~SN for ~SB~FB%s~FC~SN." % 
                     (removed, total, user.username))
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
        if settings.DOCKERBUILD or getattr(settings, 'ES_IGNORE_TYPE', True):
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

        if cls.ES().indices.exists(cls.index_name()):
            return
        
        try:
            cls.ES().indices.create(cls.index_name())
            logging.debug(" ---> ~FCCreating search index for ~FM%s" % cls.index_name())
        except elasticsearch.exceptions.RequestError as e:
            logging.debug(" ***> ~FRCould not create search index for ~FM%s: %s" % (cls.index_name(), e))
            return
        except (elasticsearch.exceptions.ConnectionError, 
                urllib3.exceptions.NewConnectionError,
                urllib3.exceptions.ConnectTimeoutError) as e:
            logging.debug(
                f" ***> ~FRNo search server available for creating story mapping: {e}")
            return

        mapping = {
            'title': {
                'store': False,
                'type': 'text',
                'analyzer': 'snowball',
                "term_vector": "yes",
            },
            'content': {
                'store': False,
                'type': 'text',
                'analyzer': 'snowball',
                "term_vector": "yes",
            },
            'tags': {
                'store': False,
                "type": "text",
                "fields": {
                    "raw": {
                        "type": "text",
                        "analyzer": "keyword",
                        "term_vector": "yes"
                    }
                }
            },
            'author': {
                'store': False,
                'type': 'text',
                'analyzer': 'default',
            },
            'feed_id': {
                'store': False,
                'type': 'integer'
            },
            'date': {
                'store': False,
                'type': 'date',
            }
        }
        cls.ES().indices.put_mapping(body={
            'properties': mapping,
        }, index=cls.index_name())
        cls.ES().indices.flush(cls.index_name())

    @classmethod
    def index(cls, story_hash, story_title, story_content, story_tags, story_author, story_feed_id,
              story_date):
        cls.create_elasticsearch_mapping()

        doc = {
            "content": story_content,
            "title": story_title,
            "tags": ', '.join(story_tags),
            "author": story_author,
            "feed_id": story_feed_id,
            "date": story_date,
        }
        try:
            cls.ES().create(index=cls.index_name(), id=story_hash,
                            body=doc, doc_type=cls.doc_type())
        except (elasticsearch.exceptions.ConnectionError,
                urllib3.exceptions.NewConnectionError) as e:
            logging.debug(
                f" ***> ~FRNo search server available for story indexing: {e}")
        except elasticsearch.exceptions.ConflictError as e:
            logging.debug(f" ***> ~FBAlready indexed story: {e}")
        # if settings.DEBUG:
        #     logging.debug(f" ***> ~FBIndexed {story_hash}")

    @classmethod
    def remove(cls, story_hash):
        if not cls.ES().exists(index=cls.index_name(), id=story_hash, doc_type=cls.doc_type()):
            return

        try:
            cls.ES().delete(index=cls.index_name(), id=story_hash, doc_type=cls.doc_type())
        except elasticsearch.exceptions.NotFoundError:
            cls.ES().delete(index=cls.index_name(), id=story_hash, doc_type='story-type')
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
            query = re.sub(r'([^\s\w_\-])+', ' ', query) # Strip non-alphanumeric
        query = html.unescape(query)

        body = {
            "query": {
                "bool": {
                    "must": [
                        {"query_string": { "query": query, "default_operator": "AND" }},
                        {"terms": { "feed_id": feed_ids[:2000] }},
                    ]
                }
            },
            'sort': [{'date': {'order': 'desc' if order == "newest" else "asc"}}],
            'from': offset,
            'size': limit
        }
        try:
            results  = cls.ES().search(body=body, index=cls.index_name(), doc_type=cls.doc_type())
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

        logging.info(" ---> ~FG~SNSearch ~FCstories~FG for: ~SB%s~SN, ~SB%s~SN results (across %s feed%s)" % 
                     (query, len(results['hits']['hits']), len(feed_ids), 's' if len(feed_ids) != 1 else ''))
        
        try:
            result_ids = [r['_id'] for r in results['hits']['hits']]
        except Exception as e:
            logging.info(" ---> ~FRInvalid search query \"%s\": %s" % (query, e))
            return []
        
        return result_ids
    
    @classmethod
    def global_query(cls, query, order, offset, limit, strip=False):
        cls.create_elasticsearch_mapping()
        cls.ES().indices.flush()
        
        if strip:
            query = re.sub(r'([^\s\w_\-])+', ' ', query) # Strip non-alphanumeric
        query = html.unescape(query)

        body = {
            "query": {
                "bool": {
                    "must": [
                        {"query_string": { "query": query, "default_operator": "AND" }},
                    ]
                }
            },
            'sort': [{'date': {'order': 'desc' if order == "newest" else "asc"}}],
            'from': offset,
            'size': limit
        }
        try:
            results  = cls.ES().search(body=body, index=cls.index_name(), doc_type=cls.doc_type())
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

        logging.info(" ---> ~FG~SNSearch ~FCstories~FG for: ~SB%s~SN (across all feeds)" % 
                     (query))
        
        try:
            result_ids = [r['_id'] for r in results['hits']['hits']]
        except Exception as e:
            logging.info(" ---> ~FRInvalid search query \"%s\": %s" % (query, e))
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
                    "filter": [{
                        "more_like_this": {
                            "fields": [ "title", "content" ],
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
                    },{
                        "terms": { "feed_id": feed_ids[:2000] }
                    }],
                }
            },
            'sort': [{'date': {'order': 'desc' if order == "newest" else "asc"}}],
            'from': offset,
            'size': limit
        }
        try:
            results  = cls.ES().search(body=body, index=cls.index_name(), doc_type=cls.doc_type())
        except elasticsearch.exceptions.RequestError as e:
            logging.debug(" ***> ~FRNo search server available for querying: %s" % e)
            return []

        logging.info(" ---> ~FG~SNMore like this ~FCstories~FG for: ~SB%s~SN, ~SB%s~SN results (across %s feed%s)" % 
                     (story_hash, len(results['hits']['hits']), len(feed_ids), 's' if len(feed_ids) != 1 else ''))
        
        try:
            result_ids = [r['_id'] for r in results['hits']['hits']]
        except Exception as e:
            logging.info(" ---> ~FRInvalid search query \"%s\": %s" % (query, e))
            return []
        
        return result_ids


class SearchFeed:
    
    _es_client = None
    name = "feeds"

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
        if settings.DOCKERBUILD or getattr(settings, 'ES_IGNORE_TYPE', True):
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

        if cls.ES().indices.exists(cls.index_name()):
            return

        index_settings = {
            "index" : {
                "analysis": {
                    "analyzer": {
                        "edgengram_analyzer": {
                            "filter": ["edgengram_analyzer"],
                            "tokenizer": "lowercase",
                            "type": "custom"
                        },
                    },
                    "filter": {
                        "edgengram_analyzer": {
                            "max_gram": "15",
                            "min_gram": "1",
                            "type": "edge_ngram"
                        },
                    }
                }
            }
        }

        try:
            cls.ES().indices.create(cls.index_name(), body={"settings": index_settings})
            logging.debug(" ---> ~FCCreating search index for ~FM%s" % cls.index_name())
        except elasticsearch.exceptions.RequestError as e:
            logging.debug(" ***> ~FRCould not create search index for ~FM%s: %s" % (cls.index_name(), e))
            return
        except (elasticsearch.exceptions.ConnectionError, 
                urllib3.exceptions.NewConnectionError, 
                urllib3.exceptions.ConnectTimeoutError) as e:
            logging.debug(f" ***> ~FRNo search server available for creating feed mapping: {e}")
            return
       
        mapping = {
            "feed_address": {
                'analyzer': 'snowball',
                "store": False,
                "term_vector": "with_positions_offsets",
                "type": "text"
            },
            "feed_id": {
                "store": True,
                "type": "text"
            },
            "num_subscribers": {
                "store": True,
                "type": "long"
            },
            "title": {
                "analyzer": "snowball",
                "store": False,
                "term_vector": "with_positions_offsets",
                "type": "text"
            },
            "link": {
                "analyzer": "snowball",
                "store": False,
                "term_vector": "with_positions_offsets",
                "type": "text"
            }
        }
        cls.ES().indices.put_mapping(body={
            'properties': mapping,
        }, index=cls.index_name())
        cls.ES().indices.flush(cls.index_name())

    @classmethod
    def index(cls, feed_id, title, address, link, num_subscribers):
        doc = {
            "feed_id": feed_id,
            "title": title,
            "feed_address": address,
            "link": link,
            "num_subscribers": num_subscribers,
        }
        try:
            cls.ES().create(index=cls.index_name(), id=feed_id, body=doc, doc_type=cls.doc_type())
        except (elasticsearch.exceptions.ConnectionError, 
                urllib3.exceptions.NewConnectionError) as e:
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
                        {"match": { "address": { "query": text, 'cutoff_frequency': "0.0005", 'minimum_should_match': "75%" } }},
                        {"match": { "title": { "query": text, 'cutoff_frequency': "0.0005", 'minimum_should_match': "75%" } }},
                        {"match": { "link": { "query": text, 'cutoff_frequency': "0.0005", 'minimum_should_match': "75%" } }},
                    ]
                }
            },
            'sort': [{'num_subscribers': {'order': 'desc'}}],
        }
        try:
            results  = cls.ES().search(body=body, index=cls.index_name(), doc_type=cls.doc_type())
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
        
        logging.info("~FGSearch ~FCfeeds~FG: ~SB%s~SN, ~SB%s~SN results" % (text, len(results['hits']['hits'])))

        return results['hits']['hits']
    
    @classmethod
    def export_csv(cls):
        import djqscsv
        from apps.rss_feeds.models import Feed

        qs = Feed.objects.filter(num_subscribers__gte=20).values('id', 'feed_title', 'feed_address', 'feed_link', 'num_subscribers')
        csv = djqscsv.render_to_csv_response(qs).content
        f = open('feeds.csv', 'w+')
        f.write(csv)
        f.close()
        
