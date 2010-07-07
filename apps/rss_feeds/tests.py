from utils import json
from django.test.client import Client
from django.test import TestCase
from django.core import management
from apps.rss_feeds.models import Feed, Story
# from pprint import pprint

class FeedTest(TestCase):
    fixtures = ['rss_feeds.json']
    
    def setUp(self):
        self.client = Client()

    def test_load_feeds__gawker(self):
        self.client.login(username='conesus', password='test')
        
        management.call_command('loaddata', 'gawker1.json', verbosity=0)
        
        feed = Feed.objects.get(feed_link__contains='gawker')
        stories = Story.objects.filter(story_feed=feed)
        self.assertEquals(stories.count(), 0)
        
        management.call_command('refresh_feed', force=1, feed=1, single_threaded=True, daemonize=False)
        
        stories = Story.objects.filter(story_feed=feed)
        self.assertEquals(stories.count(), 38)
        
        management.call_command('loaddata', 'gawker2.json', verbosity=0)
        management.call_command('refresh_feed', force=1, feed=1, single_threaded=True, daemonize=False)
        
        # Test: 1 changed char in content
        stories = Story.objects.filter(story_feed=feed)
        self.assertEquals(stories.count(), 38)
        
        response = self.client.post('/reader/load_single_feed', { "feed_id": 1 })
        feed = json.decode(response.content)        
        self.assertEquals(len(feed['stories']), 30)
        
    def test_load_feeds__gothamist(self):
        self.client.login(username='conesus', password='test')
        
        management.call_command('loaddata', 'gothamist_aug_2009_1.json', verbosity=0)
        
        feed = Feed.objects.get(feed_link__contains='gothamist')
        stories = Story.objects.filter(story_feed=feed)
        self.assertEquals(stories.count(), 0)
        
        management.call_command('refresh_feed', force=1, feed=4, single_threaded=True, daemonize=False)
        
        stories = Story.objects.filter(story_feed=feed)
        self.assertEquals(stories.count(), 42)
        
        response = self.client.post('/reader/load_single_feed', { "feed_id": 4 })
        content = json.decode(response.content)
        self.assertEquals(len(content['stories']), 30)
        
        management.call_command('loaddata', 'gothamist_aug_2009_2.json', verbosity=0)
        management.call_command('refresh_feed', force=1, feed=4, single_threaded=True, daemonize=False)
        
        stories = Story.objects.filter(story_feed=feed)
        self.assertEquals(stories.count(), 42)
        
        response = self.client.get('/reader/load_single_feed', { "feed_id": 4 })
        # print [c['story_title'] for c in json.decode(response.content)]
        content = json.decode(response.content)
        # Test: 1 changed char in title
        self.assertEquals(len(content['stories']), 30)
        
    def test_load_feeds__slashdot(self):
        self.client.login(username='conesus', password='test')
        
        management.call_command('loaddata', 'slashdot1.json', verbosity=0)
        
        feed = Feed.objects.get(feed_link__contains='slashdot')
        stories = Story.objects.filter(story_feed=feed)
        self.assertEquals(stories.count(), 0)
        
        management.call_command('refresh_feed', force=1, feed=5, single_threaded=True, daemonize=False)
        
        stories = Story.objects.filter(story_feed=feed)
        self.assertEquals(stories.count(), 38)
        
        management.call_command('loaddata', 'slashdot2.json', verbosity=0)
        management.call_command('refresh_feed', force=1, feed=5, single_threaded=True, daemonize=False)
        
        stories = Story.objects.filter(story_feed=feed)
        self.assertEquals(stories.count(), 38)
        
        response = self.client.post('/reader/load_single_feed', { "feed_id": 5 })
        
        # pprint([c['story_title'] for c in json.decode(response.content)])
        feed = json.decode(response.content)
        
        # Test: 1 changed char in title
        self.assertEquals(len(feed['stories']), 30)
        
    def test_load_feeds__brokelyn__invalid_xml(self):
        self.client.login(username='conesus', password='test')
        
        management.call_command('loaddata', 'brokelyn.json', verbosity=0)
        management.call_command('refresh_feed', force=1, feed=6, single_threaded=True, daemonize=False)
        
        response = self.client.post('/reader/load_single_feed', { "feed_id": 6 })
        
        # pprint([c['story_title'] for c in json.decode(response.content)])
        feed = json.decode(response.content)
        
        # Test: 1 changed char in title
        self.assertEquals(len(feed['stories']), 10)