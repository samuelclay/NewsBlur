import pyes
from django.conf import settings

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
    def index(cls, user_id, story_id, story_title, story_content, story_author, story_date):
        doc = {
            "content": story_content,
            "title": story_title,
            "author": story_author,
            "date": story_date,
            "user_ids": user_id,
        }
        cls.ES.index(doc, "%s-index" % cls.name, "%s-type" % cls.name, story_id)
        
    @classmethod
    def query(cls, user_id, text):
        cls.ES.refresh()
        q = pyes.query.StringQuery(text)
        results = cls.ES.search(q)
        return results
