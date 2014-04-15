import pyes
from pyes.query import MatchQuery
from django.conf import settings
from utils import log as logging

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
    def create_elasticsearch_mapping(cls):
        cls.ES.indices.delete_index_if_exists("%s-index" % cls.name)
        cls.ES.indices.create_index("%s-index" % cls.name)
        mapping = { 
            'title': {
                'boost': 2.0,
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
        cls.ES.indices.put_mapping("%s-type" % cls.name, {'properties': mapping}, ["%s-index" % cls.name])
        
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
    def query(cls, feed_ids, query):
        cls.ES.indices.refresh()

        string_q = pyes.query.StringQuery(query, default_operator="AND")
        feed_q   = pyes.query.TermsQuery('feed_id', feed_ids)
        q        = pyes.query.BoolQuery(must=[string_q, feed_q])
        results  = cls.ES.search(q, indices=cls.index_name(), doc_types=[cls.type_name()])
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
    def create_elasticsearch_mapping(cls):
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
        cls.ES.indices.create_index("%s-index" % cls.name, settings)

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
        cls.ES.indices.put_mapping("%s-type" % cls.name, {'properties': mapping}, ["%s-index" % cls.name])
        
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
