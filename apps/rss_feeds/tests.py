import unittest
from django.utils import simplejson as json
from django.test.client import Client

class FeedTest(unittest.TestCase):
    fixtures = ['feeds.json']
    
    def setUp(self):
        self.client = Client()

    def test_load_feeds(self):
        self.client.login(userame='conesus', password='test')
        response = self.client.get('/reader/refresh_feed', { "feed_id": 19, "force": True })
        response = self.client.get('/reader/refresh_feed', { "feed_id": 19, "force": True })
        response = self.client.get('/reader/load_single_feed', { "feed_id": 19 })
        
        print json.loads(response.content)[0]
