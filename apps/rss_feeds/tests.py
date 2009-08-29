from django.utils import simplejson as json
from django.test.client import Client
from django.test import TestCase
from django.core import management

class FeedTest(TestCase):
    fixtures = ['rss_feeds.json']
    
    def setUp(self):
        self.client = Client()

    # def test_load_feeds__changed_story_title(self):
    #     self.client.login(userame='conesus', password='test')
    #     
    #     management.call_command('loaddata', 'gawker1.json', verbosity=0)
    #     response = self.client.get('/reader/refresh_feed', { "feed_id": 1, "force": True })
    #     
    #     management.call_command('loaddata', 'gawker2.json', verbosity=0)
    #     response = self.client.get('/reader/refresh_feed', { "feed_id": 1, "force": True })
    #     
    #     response = self.client.get('/reader/load_single_feed', { "feed_id": 1 })
    #     print [c['story_title'] for c in json.loads(response.content)]
    #     # print json.loads(response.content)[0]

    def test_load_feeds__gothamist__changed_story_title(self):
        self.client.login(userame='conesus', password='test')
        
        management.call_command('loaddata', 'gothamist1.json', verbosity=0)
        response = self.client.get('/reader/refresh_feed', { "feed_id": 4, "force": True })
        
        management.call_command('loaddata', 'gothamist2.json', verbosity=0)
        response = self.client.get('/reader/refresh_feed', { "feed_id": 4, "force": True })
        
        response = self.client.get('/reader/load_single_feed', { "feed_id": 4 })
        print [c['story_title'] for c in json.loads(response.content)]
        # print json.loads(response.content)[0]
