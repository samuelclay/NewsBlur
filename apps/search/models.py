import pyes
from pyes.query import FilteredQuery, FuzzyQuery, TextQuery, PrefixQuery
from pyes.filters import RangeFilter
from pyes.utils import ESRange
from django.conf import settings
from django.contrib.auth.models import User
from utils import log as logging

class SearchStarredStory:
    
    ES = pyes.ES(settings.ELASTICSEARCH_HOSTS)
    name = "starred-stories"
    
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
        results = cls.ES.search(q)
        logging.user(user, "~FGSearch ~FCsaved stories~FG for: ~SB%s" % text)
        
        if not results.total:
            logging.user(user, "~FGSearch ~FCsaved stories~FG by title: ~SB%s" % text)
            q = FuzzyQuery('title', text)
            results = cls.ES.search(q)
            
        if not results.total:
            logging.user(user, "~FGSearch ~FCsaved stories~FG by content: ~SB%s" % text)
            q = FuzzyQuery('content', text)
            results = cls.ES.search(q)
            
        if not results.total:
            logging.user(user, "~FGSearch ~FCsaved stories~FG by author: ~SB%s" % text)
            q = FuzzyQuery('author', text)
            results = cls.ES.search(q)
            
        return results


class SearchFeed:
    
    ES = pyes.ES(settings.ELASTICSEARCH_HOSTS)
    name = "feeds"
    
    @classmethod
    def create_elasticsearch_mapping(cls):
        try:
            cls.ES.delete_index("%s-index" % cls.name)
        except pyes.TypeMissingException:
            print "Index missing, can't delete: %s-index" % cls.name
            
        settings =  {
            "index" : {
              "analysis" : {
                "analyzer" : {
                  "url_analyzer" : {
                    "type" : "custom",
                    "tokenizer" : "urls",
                    "filter"    : ["stop", "url_stop"]
                  }
                },
                "tokenizer": {
                    "urls": {
                        "type": "uax_url_email",
                        "max_token_length": 255,
                    }
                },
                "filter" : {
                  "url_stop" : {
                    "type" : "stop",
                    "stopwords" : ["http", "https"]
                  },
                  "url_ngram" : {
                    "type" : "nGram",
                    "min_gram" : 2,
                    "max_gram" : 20,
                  }
                }
              }
            }
          }
        cls.ES.create_index("%s-index" % cls.name, settings)
        mapping = { 
            'address': {
                'boost': 3.0,
                'index': 'analyzed',
                'store': 'yes',
                'type': 'string',
                "term_vector" : "with_positions_offsets",
                "analyzer": "url_analyzer",
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
                "analyzer": "url_analyzer",
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
        cls.ES.put_mapping("%s-type" % cls.name, {'properties': mapping}, ["%s-index" % cls.name])
        
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
        cls.ES.refresh()
        
        sub_filter = RangeFilter(qrange=ESRange('num_subscribers', 2))
        logging.info("~FGSearch ~FCfeeds~FG by address: ~SB%s" % text)
        q = TextQuery('address', text)
        results = cls.ES.search(FilteredQuery(q, sub_filter), sort="num_subscribers:desc", size=5)

        if not results.total:
            logging.info("~FGSearch ~FCfeeds~FG by title: ~SB%s" % text)
            q = PrefixQuery('title', text)
            results = cls.ES.search(FilteredQuery(q, sub_filter), sort="num_subscribers:desc", size=5)
            
        if not results.total:
            logging.info("~FGSearch ~FCfeeds~FG by link: ~SB%s" % text)
            q = TextQuery('link.partial', text)
            results = cls.ES.search(FilteredQuery(q, sub_filter), sort="num_subscribers:desc", size=5)
            
        return results
