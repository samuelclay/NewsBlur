from utils import json_functions as json
from django.test.client import Client
from django.test import TestCase
from django.core.urlresolvers import reverse
from django.conf import settings
from mongoengine.connection import connect, disconnect

class ReaderTest(TestCase):
    fixtures = ['../../rss_feeds/fixtures/rss_feeds.json', 
                'subscriptions.json', 'stories.json', 
                '../../rss_feeds/fixtures/gawker1.json']
    
    
    def setUp(self):
        disconnect()
        settings.MONGODB = connect('test_newsblur')
        self.client = Client()

    def tearDown(self):
        settings.MONGODB.drop_database('test_newsblur')
            
    def test_api_feeds(self):
        self.client.login(username='conesus', password='test')
        
        response = self.client.get(reverse('load-feeds'))
        content = json.decode(response.content)
        
        self.assertEquals(len(content['feeds']), 10)
        self.assertEquals(content['feeds']['1']['feed_title'], 'Gawker')
        self.assertEquals(content['folders'], [{'Tech': [1, 4, 5, {'Deep Tech': [6, 7]}]}, 2, 3, 8, 9, {'Blogs': [8, 9]}, 1])
        
    def test_delete_feed(self):
        self.client.login(username='conesus', password='test')
        
        response = self.client.get(reverse('load-feeds'))
        feeds = json.decode(response.content)
        self.assertEquals(feeds['folders'], [{'Tech': [1, 4, 5, {'Deep Tech': [6, 7]}]}, 2, 3, 8, 9, {'Blogs': [8, 9]}, 1])
        
        # Delete feed
        response = self.client.post(reverse('delete-feed'), {'feed_id': 1, 'in_folder': ''})
        response = json.decode(response.content)
        self.assertEquals(response['code'], 1)
        
        response = self.client.get(reverse('load-feeds'))
        feeds = json.decode(response.content)
        self.assertEquals(feeds['folders'], [2, 3, 8, 9, {'Tech': [1, 4, 5, {'Deep Tech': [6, 7]}]}, {'Blogs': [8, 9]}])
        
        # Delete feed
        response = self.client.post(reverse('delete-feed'), {'feed_id': 9, 'in_folder': 'Blogs'})
        response = json.decode(response.content)
        self.assertEquals(response['code'], 1)
        
        response = self.client.get(reverse('load-feeds'))
        feeds = json.decode(response.content)
        self.assertEquals(feeds['folders'], [2, 3, 8, 9, {'Tech': [1, 4, 5, {'Deep Tech': [6, 7]}]}, {'Blogs': [8]}])
        
        # Delete feed
        response = self.client.post(reverse('delete-feed'), {'feed_id': 5, 'in_folder': 'Tech'})
        response = json.decode(response.content)
        self.assertEquals(response['code'], 1)
        
        response = self.client.get(reverse('load-feeds'))
        feeds = json.decode(response.content)
        self.assertEquals(feeds['folders'], [2, 3, 8, 9, {'Tech': [1, 4, {'Deep Tech': [6, 7]}]}, {'Blogs': [8]}])
        
        # Delete feed
        response = self.client.post(reverse('delete-feed'), {'feed_id': 4, 'in_folder': 'Tech'})
        response = json.decode(response.content)
        self.assertEquals(response['code'], 1)
        
        response = self.client.get(reverse('load-feeds'))
        feeds = json.decode(response.content)
        self.assertEquals(feeds['folders'], [2, 3, 8, 9, {'Tech': [1, {'Deep Tech': [6, 7]}]}, {'Blogs': [8]}])
        
        # Delete feed
        response = self.client.post(reverse('delete-feed'), {'feed_id': 8, 'in_folder': ''})
        response = json.decode(response.content)
        self.assertEquals(response['code'], 1)
        
        response = self.client.get(reverse('load-feeds'))
        feeds = json.decode(response.content)
        self.assertEquals(feeds['folders'], [2, 3, 9, {'Tech': [1, {'Deep Tech': [6, 7]}]}, {'Blogs': [8]}])

    def test_delete_feed__multiple_folders(self):
        self.client.login(username='conesus', password='test')
        
        response = self.client.get(reverse('load-feeds'))
        feeds = json.decode(response.content)
        self.assertEquals(feeds['folders'], [{'Tech': [1, 4, 5, {'Deep Tech': [6, 7]}]}, 2, 3, 8, 9, {'Blogs': [8, 9]}, 1])
        
        # Delete feed
        response = self.client.post(reverse('delete-feed'), {'feed_id': 1})
        response = json.decode(response.content)
        self.assertEquals(response['code'], 1)
        
        response = self.client.get(reverse('load-feeds'))
        feeds = json.decode(response.content)
        self.assertEquals(feeds['folders'], [2, 3, 8, 9, {'Tech': [1, 4, 5, {'Deep Tech': [6, 7]}]}, {'Blogs': [8, 9]}])
    
    def test_move_feeds_by_folder(self):
        self.client.login(username='Dejal', password='test')
        
        response = self.client.get(reverse('load-feeds'))
        feeds = json.decode(response.content)
        self.assertEquals(feeds['folders'], [5299728, 644144, 1187026, {"Brainiacs & Opinion": [569, 38, 3581, 183139, 1186180, 15]}, {"Science & Technology": [731503, 140145, 1272495, 76, 161, 39, {"Hacker": [5985150, 3323431]}]}, {"Humor": [212379, 3530, 5994357]}, {"Videos": [3240, 5168]}])
        
        # Move feeds by folder
        response = self.client.post(reverse('move-feeds-by-folder-to-folder'), {u'feeds_by_folder': u'[\n  [\n    "5994357",\n    "Humor"\n  ],\n  [\n    "3530",\n    "Humor"\n  ]\n]', u'to_folder': u'Brainiacs & Opinion'})
        response = json.decode(response.content)
        self.assertEquals(response['code'], 1)
        
        response = self.client.get(reverse('load-feeds'))
        feeds = json.decode(response.content)
        self.assertEquals(feeds['folders'], [5299728, 644144, 1187026, {"Brainiacs & Opinion": [569, 38, 3581, 183139, 1186180, 15, 5994357, 3530]}, {"Science & Technology": [731503, 140145, 1272495, 76, 161, 39, {"Hacker": [5985150, 3323431]}]}, {"Humor": [212379]}, {"Videos": [3240, 5168]}])
        
    def test_load_single_feed(self):
        # from django.conf import settings
        # from django.db import connection
        # settings.DEBUG = True
        # connection.queries = []

        self.client.login(username='conesus', password='test')        
        url = reverse('load-single-feed', kwargs=dict(feed_id=1))
        response = self.client.get(url)
        feed = json.decode(response.content)
        self.assertEquals(len(feed['feed_tags']), 0)
        self.assertEquals(len(feed['classifiers']['tags']), 0)
        # self.assert_(connection.queries)
        
        # settings.DEBUG = False