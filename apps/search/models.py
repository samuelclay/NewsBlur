import pyes
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
            q = pyes.query.FuzzyQuery('title', text)
            results = cls.ES.search(q)
            
        if not results.total:
            logging.user(user, "~FGSearch ~FCsaved stories~FG by content: ~SB%s" % text)
            q = pyes.query.FuzzyQuery('content', text)
            results = cls.ES.search(q)
            
        if not results.total:
            logging.user(user, "~FGSearch ~FCsaved stories~FG by author: ~SB%s" % text)
            q = pyes.query.FuzzyQuery('author', text)
            results = cls.ES.search(q)
            
        return results
