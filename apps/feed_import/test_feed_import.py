import os
from django.test.client import Client
from django.test import TestCase
from django.contrib.auth.models import User
from django.urls import reverse
from apps.reader.models import UserSubscription, UserSubscriptionFolders
from apps.rss_feeds.models import merge_feeds, DuplicateFeed, Feed
from utils import json_functions as json_functions
import json
from django.core.management import call_command
class Test_Import(TestCase):
    fixtures = [
        'apps/rss_feeds/fixtures/initial_data.json',
        'opml_import.json'
    ]
    
    def setUp(self):
        self.client = Client()
            
    def test_opml_import(self):
        self.client.login(username='conesus', password='test')
        user = User.objects.get(username='conesus')
        
        # Verify user has no feeds
        subs = UserSubscription.objects.filter(user=user)
        self.assertEqual(subs.count(), 0)
        
        f = open(os.path.join(os.path.dirname(__file__), 'fixtures/opml.xml'))
        response = self.client.post(reverse('opml-upload'), {'file': f})
        self.assertEqual(response.status_code, 200)
        
        # Verify user now has feeds
        subs = UserSubscription.objects.filter(user=user)
        self.assertEqual(subs.count(), 54)
        
        usf = UserSubscriptionFolders.objects.get(user=user)
        print(json_functions.decode(usf.folders))
        self.assertEqual(json_functions.decode(usf.folders), [{'Tech': [4, 5, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28]}, 1, 2, 3, 6, {'New York': [1, 2, 3, 4, 5, 6, 7, 8, 9]}, {'tech': []}, {'Blogs': [29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, {'The Bloglets': [45, 46, 47, 48, 49]}]}, {'Cooking': [50, 51, 52, 53]}, 54])
                
    def test_opml_import__empty(self):
        self.client.login(username='conesus', password='test')
        user = User.objects.get(username='conesus')
        
        # Verify user has default feeds
        subs = UserSubscription.objects.filter(user=user)
        self.assertEqual(subs.count(), 0)

        response = self.client.post(reverse('opml-upload'))
        self.assertEqual(response.status_code, 200)
        
        # Verify user now has feeds
        subs = UserSubscription.objects.filter(user=user)

        self.assertEquals(subs.count(), 0)

class Test_Duplicate_Feeds(TestCase):
    fixtures = [
        'apps/rss_feeds/fixtures/initial_data.json',
    ]


    def test_duplicate_feeds(self):
        # had to load the feed data this way to hit the save() override.
        # it wouldn't work with loaddata or fixures

        with open('apps/feed_import/fixtures/duplicate_feeds.json') as json_file:
            feed_data = json.loads(json_file.read())
        feed_data_1 = feed_data[0]
        feed_data_2 = feed_data[1]
        feed_1 = Feed(**feed_data_1)
        feed_2 = Feed(**feed_data_2)
        feed_1.save()
        feed_2.save()

        call_command('loaddata', 'apps/feed_import/fixtures/subscriptions.json')

        user_1_feed_subscription = UserSubscription.objects.filter(user__id=1)[0].feed_id    
        user_2_feed_subscription = UserSubscription.objects.filter(user__id=2)[0].feed_id

        self.assertNotEqual(user_1_feed_subscription, user_2_feed_subscription)

        original_feed_id = merge_feeds(user_1_feed_subscription, user_2_feed_subscription)
    
        user_1_feed_subscription = UserSubscription.objects.filter(user__id=1)[0].feed_id    
        user_2_feed_subscription = UserSubscription.objects.filter(user__id=2)[0].feed_id
        self.assertEqual(user_1_feed_subscription, user_2_feed_subscription)
