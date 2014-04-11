import pyes
from pyes.query import FuzzyQuery, MatchQuery, PrefixQuery
from django.conf import settings
from django.contrib.auth.models import User
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
        cls.ES.create_index("%s-index" % cls.name)
        mapping = { 
            'title': {
                'boost': 2.0,
                'index': 'analyzed',
                'store': 'yes',
                'type': 'string',
                "term_vector" : "with_positions_offsets"
            },
            'content': {
                'boost': 1.0,
                'index': 'analyzed',
                'store': 'yes',
                'type': 'string',
                "term_vector" : "with_positions_offsets"
            },
            'author': {
                'boost': 1.0,
                'index': 'analyzed',
                'store': 'yes',
                'type': 'string',   
            },
            'db_id': {
                'index': 'not_analyzed',
                'store': 'yes',
                'type': 'string',   
            },
            'feed_id': {
                'store': 'yes',
                'type': 'integer'
            },
            'date': {
                'store': 'yes',
                'type': 'date',
            },
            'user_ids': {
                'index': 'not_analyzed',
                'store': 'yes',
                'type': 'integer',
                'index_name': 'user_id'
            }
        }
        cls.ES.put_mapping("%s-type" % cls.name, {'properties': mapping}, ["%s-index" % cls.name])
        
    @classmethod
    def index(cls, user_id, story_id, story_title, story_content, story_author, story_date, db_id):
        doc = {
            "content": story_content,
            "title": story_title,
            "author": story_author,
            "date": story_date,
            "user_ids": user_id,
            "db_id": db_id,
        }
        cls.ES.index(doc, "%s-index" % cls.name, "%s-type" % cls.name, story_id)
        
    @classmethod
    def query(cls, user_id, text):
        user = User.objects.get(pk=user_id)
        cls.ES.refresh()
        q = pyes.query.StringQuery(text)
        print q.serialized(), cls.index_name, cls.type_name
        results = cls.ES.search(q, indices=cls.index_name, doc_types=[cls.type_name])
        logging.user(user, "~FGSearch ~FCstories~FG for: ~SB%s" % text)
        
        if not results.total:
            logging.user(user, "~FGSearch ~FCstories~FG by title: ~SB%s" % text)
            q = FuzzyQuery('title', text)
            results = cls.ES.search(q)
            
        if not results.total:
            logging.user(user, "~FGSearch ~FCstories~FG by content: ~SB%s" % text)
            q = FuzzyQuery('content', text)
            results = cls.ES.search(q)
            
        if not results.total:
            logging.user(user, "~FGSearch ~FCstories~FG by author: ~SB%s" % text)
            q = FuzzyQuery('author', text)
            results = cls.ES.search(q)
            
        return results


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
                 "filter": {
                    "nGram_filter": {
                       "type": "nGram",
                       "min_gram": 2,
                       "max_gram": 20,
                       "token_chars": [
                          "letter",
                          "digit",
                          "punctuation",
                          "symbol"
                       ]
                    }
                 },
                 "analyzer": {
                    "nGram_analyzer": {
                       "type": "custom",
                       "tokenizer": "whitespace",
                       "filter": [
                          "lowercase",
                          "asciifolding",
                          "nGram_filter"
                       ]
                    },
                    "whitespace_analyzer": {
                       "type": "custom",
                       "tokenizer": "whitespace",
                       "filter": [
                          "lowercase",
                          "asciifolding"
                       ]
                    }
                 }
              }
          }
        }
        cls.ES.indices.create_index("%s-index" % cls.name, settings)

        mapping = { 
            'address': {
                'boost': 3.0,
                'index': 'analyzed',
                'store': 'yes',
                'type': 'string',
                "term_vector" : "with_positions_offsets",
                "index_analyzer": "nGram_analyzer",
                "search_analyzer": "whitespace_analyzer"
            },
            'title': {
                'boost': 2.0,
                'index': 'analyzed',
                'store': 'yes',
                'type': 'string',
                "term_vector" : "with_positions_offsets",
            },
            'link': {
                'boost': 1.0,
                'index': 'analyzed',
                'store': 'yes',
                'type': 'string',
                "term_vector" : "with_positions_offsets",
                "index_analyzer": "nGram_analyzer",
                "search_analyzer": "whitespace_analyzer"
            },
            'num_subscribers': {
                'boost': 1.0,
                'index': 'not_analyzed',
                'store': 'yes',
                'type': 'integer',
            },
            'feed_id': {
                'store': 'yes',
                'type': 'integer',
            },
        }
        cls.ES.indices.put_mapping("%s-type" % cls.name, {'properties': mapping}, ["%s-index" % cls.name])
        
    @classmethod
    def index(cls, feed_id, title, address, link, num_subscribers):
        doc = {
            "feed_id": feed_id,
            "title": title,
            "address": address,
            "link": link,
            "num_subscribers": num_subscribers,
        }
        cls.ES.index(doc, "%s-index" % cls.name, "%s-type" % cls.name, feed_id)
        
    @classmethod
    def query(cls, text):
        cls.ES.default_indices = cls.index_name()
        cls.ES.indices.refresh()
        
        logging.info("~FGSearch ~FCfeeds~FG by address: ~SB%s" % text)
        q = MatchQuery('address.partial', text, type='phrase')
        print q.serialize(), cls.index_name(), cls.type_name()
        results = cls.ES.search(query=q, sort="num_subscribers:desc", size=5,
                                doc_types=[cls.type_name()])

        if not results.total:
            logging.info("~FGSearch ~FCfeeds~FG by title: ~SB%s" % text)
            q = PrefixQuery('title', text)
            print q.serialize()
            results = cls.ES.search(query=q, sort="num_subscribers:desc", size=5,
                                    doc_types=[cls.type_name()])
            
        if not results.total:
            logging.info("~FGSearch ~FCfeeds~FG by link: ~SB%s" % text)
            q = PrefixQuery('link.partial', text)
            print q.serialize()
            results = cls.ES.search(query=q, sort="num_subscribers:desc", size=5,
                                    doc_types=[cls.type_name()])
            
        return results
