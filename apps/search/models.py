import time
import datetime
import pyes
import redis
import mongoengine as mongo
from pyes.query import MatchQuery
from django.conf import settings
from django.contrib.auth.models import User
from apps.search.tasks import IndexSubscriptionsForSearch
from utils import log as logging

class MUserSearch(mongo.Document):
    '''Search index state of a user's subscriptions.'''
    user_id                  = mongo.IntField(unique=True)
    last_search_date         = mongo.DateTimeField()
    subscriptions_indexed    = mongo.BooleanField()
    subscriptions_indexing   = mongo.BooleanField()
    
    meta = {
        'collection': 'user_search',
        'indexes': ['user_id'],
        'index_drop_dups': True,
        'allow_inheritance': False,
    }
    
    @classmethod
    def get_user(cls, user_id):
        try:
            user_search = cls.objects.get(user_id=user_id)
        except cls.DoesNotExist:
            user_search = cls.objects.create(user_id=user_id)
        
        return user_search
    
    def touch_search_date(self):
        if not self.subscriptions_indexed and not self.subscriptions_indexing:
            self.schedule_index_subscriptions_for_search()
            self.subscriptions_indexing = True

        self.last_search_date = datetime.datetime.now()
        self.save()

    def schedule_index_subscriptions_for_search(self):
        IndexSubscriptionsForSearch.apply_async(kwargs=dict(user_id=self.user_id))
        
    # Should be run as a background task
    def index_subscriptions_for_search(self):
        from apps.rss_feeds.models import Feed
        from apps.reader.models import UserSubscription
        
        SearchStory.create_elasticsearch_mapping()
        
        start = time.time()
        not_found = 0
        processed = 0
        user = User.objects.get(pk=self.user_id)
        r = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
        r.publish(user.username, 'search_index_complete:start')
        throttle = time.time()
        
        subscriptions = UserSubscription.objects.filter(user=user)
        total = subscriptions.count()
        logging.user(user, "~FCIndexing ~SB%s feeds~SN for ~SB~FB%s~FC~SN..." % 
                     (total, user.username))
        
        for sub in subscriptions:
            try:
                feed = sub.feed
            except Feed.DoesNotExist:
                not_found += 1
                continue
            
            feed.index_stories_for_search()
            processed += 1
            
            # Throttle notifications to client as to not flood them
            if time.time() - throttle > 0.05:
                r.publish(user.username, 'search_index_complete:%.4s' % (float(processed)/total))
                throttle = time.time()
        
        duration = time.time() - start
        logging.user(user, "~FCIndexed ~SB%s/%s feeds~SN for ~SB~FB%s~FC~SN in ~FM~SB%s~FC~SN sec." % 
                     (processed, total, user.username, round(duration, 2)))
        r.publish(user.username, 'search_index_complete:done')
        
        self.subscriptions_indexed = True
        self.subscriptions_indexing = False
        self.save()
    
    @classmethod
    def remove_all(cls):
        for user_search in cls.objects.all():
            user_search.remove()
    
    def remove(self):
        from apps.rss_feeds.models import Feed
        from apps.reader.models import UserSubscription

        user = User.objects.get(pk=self.user_id)
        subscriptions = UserSubscription.objects.filter(user=self.user_id, 
                                                        feed__search_indexed=True)
        total = subscriptions.count()
        removed = 0
        
        for sub in subscriptions:
            try:
                feed = sub.feed
            except Feed.DoesNotExist:
                continue
            feed.search_indexed = False
            feed.save()
            removed += 1
            
        logging.user(user, "~FCRemoved ~SB%s/%s feed's search indexes~SN for ~SB~FB%s~FC~SN." % 
                     (removed, total, user.username))
        self.delete()

class SearchStory:
    
    ES = pyes.ES(settings.ELASTICSEARCH_HOSTS)
    name = "stories"
    
    @classmethod
    def index_name(cls):
        return "%s-index" % cls.name
        
    @classmethod
    def type_name(cls):
        return "%s-type" % cls.name
        
    @classmethod
    def create_elasticsearch_mapping(cls, delete=False):
        if delete:
            cls.ES.indices.delete_index_if_exists("%s-index" % cls.name)
        cls.ES.indices.create_index_if_missing("%s-index" % cls.name)
        mapping = { 
            'title': {
                'boost': 3.0,
                'index': 'analyzed',
                'store': 'no',
                'type': 'string',
                'analyzer': 'snowball',
            },
            'content': {
                'boost': 1.0,
                'index': 'analyzed',
                'store': 'no',
                'type': 'string',
                'analyzer': 'snowball',
            },
            'author': {
                'boost': 1.0,
                'index': 'analyzed',
                'store': 'no',
                'type': 'string',   
                'analyzer': 'keyword',
            },
            'feed_id': {
                'store': 'no',
                'type': 'integer'
            },
            'date': {
                'store': 'no',
                'type': 'date',
            }
        }
        cls.ES.indices.put_mapping("%s-type" % cls.name, {
            'properties': mapping,
            '_source': {'enabled': False},
        }, ["%s-index" % cls.name])
        
    @classmethod
    def index(cls, story_hash, story_title, story_content, story_author, story_feed_id, 
              story_date):
        doc = {
            "content"   : story_content,
            "title"     : story_title,
            "author"    : story_author,
            "feed_id"   : story_feed_id,
            "date"      : story_date,
        }
        cls.ES.index(doc, "%s-index" % cls.name, "%s-type" % cls.name, story_hash)
    
    @classmethod
    def remove(cls, story_hash):
        cls.ES.delete("%s-index" % cls.name, "%s-type" % cls.name, story_hash)
        
    @classmethod
    def query(cls, feed_ids, query, order, offset, limit):
        cls.create_elasticsearch_mapping()
        cls.ES.indices.refresh()
        
        sort     = "date:desc" if order == "newest" else "date:asc"
        string_q = pyes.query.StringQuery(query, default_operator="AND")
        feed_q   = pyes.query.TermsQuery('feed_id', feed_ids)
        q        = pyes.query.BoolQuery(must=[string_q, feed_q])
        results  = cls.ES.search(q, indices=cls.index_name(), doc_types=[cls.type_name()],
                                 partial_fields={}, sort=sort, start=offset, size=limit)
        logging.info("~FGSearch ~FCstories~FG for: ~SB%s (across %s feed%s)" % 
                     (query, len(feed_ids), 's' if len(feed_ids) != 1 else ''))
        
        return [r.get_id() for r in results]


class SearchFeed:
    
    ES = pyes.ES(settings.ELASTICSEARCH_HOSTS)
    name = "feeds"
    
    @classmethod
    def index_name(cls):
        return "%s-index" % cls.name
        
    @classmethod
    def type_name(cls):
        return "%s-type" % cls.name
        
    @classmethod
    def create_elasticsearch_mapping(cls, delete=False):
        if delete:
            cls.ES.indices.delete_index_if_exists("%s-index" % cls.name)
        settings =  {
            "index" : {
                "analysis": {
                    "analyzer": {
                        "edgengram_analyzer": {
                            "filter": ["edgengram"],
                            "tokenizer": "lowercase",
                            "type": "custom"
                        },
                        "ngram_analyzer": {
                            "filter": ["ngram"],
                            "tokenizer": "lowercase",
                            "type": "custom"
                        }
                    },
                    "filter": {
                        "edgengram": {
                            "max_gram": "15",
                            "min_gram": "2",
                            "type": "edgeNGram"
                        },
                        "ngram": {
                            "max_gram": "15",
                            "min_gram": "3",
                            "type": "nGram"
                        }
                    },
                    "tokenizer": {
                        "edgengram_tokenizer": {
                            "max_gram": "15",
                            "min_gram": "2",
                            "side": "front",
                            "type": "edgeNGram"
                        },
                        "ngram_tokenizer": {
                            "max_gram": "15",
                            "min_gram": "3",
                            "type": "nGram"
                        }
                    }
                }
            }
        }
        cls.ES.indices.create_index_if_missing("%s-index" % cls.name, settings)

        mapping = {
            "address": {
                "analyzer": "edgengram_analyzer",
                "store": True,
                "term_vector": "with_positions_offsets",
                "type": "string"
            },
            "feed_id": {
                "store": True,
                "type": "string"
            },
            "num_subscribers": {
                "index": "analyzed",
                "store": True,
                "type": "long"
            },
            "title": {
                "analyzer": "edgengram_analyzer",
                "store": True,
                "term_vector": "with_positions_offsets",
                "type": "string"
            }
        }
        cls.ES.indices.put_mapping("%s-type" % cls.name, {
            'properties': mapping,
            '_source': {'enabled': False},
        }, ["%s-index" % cls.name])
        
    @classmethod
    def index(cls, feed_id, title, address, link, num_subscribers):
        doc = {
            "feed_id"           : feed_id,
            "title"             : title,
            "address"           : address,
            "link"              : link,
            "num_subscribers"   : num_subscribers,
        }
        cls.ES.index(doc, "%s-index" % cls.name, "%s-type" % cls.name, feed_id)
        
    @classmethod
    def query(cls, text):
        cls.ES.default_indices = cls.index_name()
        cls.ES.indices.refresh()
        
        logging.info("~FGSearch ~FCfeeds~FG by address: ~SB%s" % text)
        q = MatchQuery('address', text, operator="and", type="phrase")
        results = cls.ES.search(query=q, sort="num_subscribers:desc", size=5,
                                doc_types=[cls.type_name()])

        if not results.total:
            logging.info("~FGSearch ~FCfeeds~FG by title: ~SB%s" % text)
            q = MatchQuery('title', text, operator="and")
            results = cls.ES.search(query=q, sort="num_subscribers:desc", size=5,
                                    doc_types=[cls.type_name()])
            
        if not results.total:
            logging.info("~FGSearch ~FCfeeds~FG by link: ~SB%s" % text)
            q = MatchQuery('link', text, operator="and")
            results = cls.ES.search(query=q, sort="num_subscribers:desc", size=5,
                                    doc_types=[cls.type_name()])
            
        return results
