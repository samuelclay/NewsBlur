from utils import json_functions as json
from django.test.client import Client
from django.test import TestCase
from django.core import management
from pprint import pprint
from django.core.urlresolvers import reverse

class ReaderTest(TestCase):
    fixtures = ['reader.json', 'stories.json']
    
    def setUp(self):
        self.client = Client()
    
    def test_api_feeds(self):
        self.client.login(username='conesus', password='test')
        
        response = self.client.get(reverse('load-feeds'))
        pprint(json.decode(response.content))
        
    def test_delete_feed(self):
        self.client.login(username='conesus', password='test')
        
        response = self.client.get(reverse('load-feeds'))
        feeds = json.decode(response.content)
        self.assertEquals(len(feeds['folders']), 5)
        self.assertTrue(1 in feeds['folders'])
        self.assertEquals(feeds['folders'], [1, {u'Tech': [4, 5, {u'Deep Tech': [6, 7]}]}, 2, 3, {u'Blogs': [8, 9]}])
        
        # Delete feed
        response = self.client.post(reverse('delete-feed'), {'feed_id': 1})
        response = json.decode(response.content)
        self.assertEquals(response['code'], 1)
        
        response = self.client.get(reverse('load-feeds'))
        feeds = json.decode(response.content)
        self.assertEquals(len(feeds['folders']), 4)
        self.assertTrue(1 not in feeds['folders'])
        self.assertEquals(feeds['folders'], [{u'Tech': [4, 5, {u'Deep Tech': [6, 7]}]}, 2, 3, {u'Blogs': [8, 9]}])
        
        # Delete feed
        response = self.client.post(reverse('delete-feed'), {'feed_id': 9})
        response = json.decode(response.content)
        self.assertEquals(response['code'], 1)
        
        response = self.client.get(reverse('load-feeds'))
        feeds = json.decode(response.content)
        self.assertEquals(len(feeds['folders']), 4)
        self.assertTrue(1 not in feeds['folders'])
        self.assertEquals(feeds['folders'], [{u'Tech': [4, 5, {u'Deep Tech': [6, 7]}]}, 2, 3, {u'Blogs': [8]}])
        
        # Delete feed
        response = self.client.post(reverse('delete-feed'), {'feed_id': 5})
        response = json.decode(response.content)
        self.assertEquals(response['code'], 1)
        
        response = self.client.get(reverse('load-feeds'))
        feeds = json.decode(response.content)
        self.assertEquals(len(feeds['folders']), 4)
        self.assertTrue(1 not in feeds['folders'])
        self.assertEquals(feeds['folders'], [{u'Tech': [4, {u'Deep Tech': [6, 7]}]}, 2, 3, {u'Blogs': [8]}])
        
        # Delete feed
        response = self.client.post(reverse('delete-feed'), {'feed_id': 4})
        response = json.decode(response.content)
        self.assertEquals(response['code'], 1)
        
        response = self.client.get(reverse('load-feeds'))
        feeds = json.decode(response.content)
        self.assertEquals(len(feeds['folders']), 4)
        self.assertTrue(1 not in feeds['folders'])
        self.assertEquals(feeds['folders'], [{u'Tech': [{u'Deep Tech': [6, 7]}]}, 2, 3, {u'Blogs': [8]}])
        
        # Delete feed
        response = self.client.post(reverse('delete-feed'), {'feed_id': 8})
        response = json.decode(response.content)
        self.assertEquals(response['code'], 1)
        
        response = self.client.get(reverse('load-feeds'))
        feeds = json.decode(response.content)
        self.assertEquals(len(feeds['folders']), 4)
        self.assertTrue(1 not in feeds['folders'])
        self.assertEquals(feeds['folders'], [{u'Tech': [{u'Deep Tech': [6, 7]}]}, 2, 3, {u'Blogs': []}])
        
    def test_load_single_feed(self):
        from django.conf import settings
        from django.db import connection
        settings.DEBUG = True
        connection.queries = []

        self.client.login(username='conesus', password='test')        
        response = self.client.get(reverse('load-single-feed'), {'feed_id': 56})
        feed = json.decode(response.content)
        
        pprint(connection.queries)
        
        self.assert_(connection.queries)
        
        settings.DEBUG = False