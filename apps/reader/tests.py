from utils import json_functions as json
from django.test.client import Client
from django.test import TestCase
from django.core.urlresolvers import reverse

class ReaderTest(TestCase):
    fixtures = ['reader.json', 'stories.json', '../../rss_feeds/fixtures/gawker1.json']
    
    def setUp(self):
        self.client = Client()
    
    def test_api_feeds(self):
        self.client.login(username='conesus', password='test')
        
        response = self.client.get(reverse('load-feeds'))
        content = json.decode(response.content)
        
        self.assertEquals(len(content['feeds']), 1)
        self.assertEquals(content['feeds']['1']['feed_title'], 'Gawker')
        self.assertEquals(content['folders'], [1, {'Tech': [4, 5, {'Deep Tech': [6, 7]}]}, 2, 3, 8, 9, {'Blogs': [8, 9]}])
        
    def test_delete_feed(self):
        self.client.login(username='conesus', password='test')
        
        response = self.client.get(reverse('load-feeds'))
        feeds = json.decode(response.content)
        self.assertEquals(feeds['folders'], [1, {'Tech': [4, 5, {'Deep Tech': [6, 7]}]}, 2, 3, 8, 9, {'Blogs': [8, 9]}])
        
        # Delete feed
        response = self.client.post(reverse('delete-feed'), {'feed_id': 1, 'in_folder': ''})
        response = json.decode(response.content)
        self.assertEquals(response['code'], 1)
        
        response = self.client.get(reverse('load-feeds'))
        feeds = json.decode(response.content)
        self.assertEquals(feeds['folders'], [{'Tech': [4, 5, {'Deep Tech': [6, 7]}]}, 2, 3, 8, 9, {'Blogs': [8, 9]}])
        
        # Delete feed
        response = self.client.post(reverse('delete-feed'), {'feed_id': 9, 'in_folder': 'Blogs'})
        response = json.decode(response.content)
        self.assertEquals(response['code'], 1)
        
        response = self.client.get(reverse('load-feeds'))
        feeds = json.decode(response.content)
        self.assertEquals(feeds['folders'], [{'Tech': [4, 5, {'Deep Tech': [6, 7]}]}, 2, 3, 8, 9, {'Blogs': [8]}])
        
        # Delete feed
        response = self.client.post(reverse('delete-feed'), {'feed_id': 5, 'in_folder': 'Tech'})
        response = json.decode(response.content)
        self.assertEquals(response['code'], 1)
        
        response = self.client.get(reverse('load-feeds'))
        feeds = json.decode(response.content)
        self.assertEquals(feeds['folders'], [{'Tech': [4, {'Deep Tech': [6, 7]}]}, 2, 3, 8, 9, {'Blogs': [8]}])
        
        # Delete feed
        response = self.client.post(reverse('delete-feed'), {'feed_id': 4, 'in_folder': 'Tech'})
        response = json.decode(response.content)
        self.assertEquals(response['code'], 1)
        
        response = self.client.get(reverse('load-feeds'))
        feeds = json.decode(response.content)
        self.assertEquals(feeds['folders'], [{'Tech': [{'Deep Tech': [6, 7]}]}, 2, 3, 8, 9, {'Blogs': [8]}])
        
        # Delete feed
        response = self.client.post(reverse('delete-feed'), {'feed_id': 8, 'in_folder': ''})
        response = json.decode(response.content)
        self.assertEquals(response['code'], 1)
        
        response = self.client.get(reverse('load-feeds'))
        feeds = json.decode(response.content)
        self.assertEquals(feeds['folders'], [{'Tech': [{'Deep Tech': [6, 7]}]}, 2, 3, 9, {'Blogs': [8]}])
        
    def test_load_single_feed(self):
        # from django.conf import settings
        # from django.db import connection
        # settings.DEBUG = True
        # connection.queries = []

        self.client.login(username='conesus', password='test')        
        response = self.client.get(reverse('load-single-feed', args=[1]))
        feed = json.decode(response.content)
        self.assertEquals(len(feed['feed_tags']), 0)
        self.assertEquals(len(feed['classifiers']['tags']), 0)
        # self.assert_(connection.queries)
        
        # settings.DEBUG = False