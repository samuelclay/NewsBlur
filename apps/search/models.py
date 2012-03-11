import pyes
from django.conf import settings

class Search:
    
    ES = settings.ELASTICSEARCH
    
    @classmethod
    def create_elasticsearch_mapping(cls):
        cls.ES.create_index("story-index")
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
            'feed_id': {
                'store': 'yes',
                'type': 'integer'
            },
            'date': {
                'store': 'yes',
                'type': 'date',
            }
        }
        cls.ES.put_mapping("story-type", {'properties': mapping}, ["story-index"])
        
    @classmethod
    def index(cls, story_id, story_title, story_content, story_author, story_date):
        doc = {
            "content": story_content,
            "title": story_title,
            "author": story_author,
            "date": story_date
        }
        cls.ES.index(doc, "story-index", "story-type", story_id)
        
    @classmethod
    def query(cls, text):
        q = pyes.query.StringQuery(text)
        results = cls.ES.search(q)
        return results
