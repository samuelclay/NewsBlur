import os
from django.test.client import Client
from django.test import TestCase
from django.contrib.auth.models import User
from django.core.urlresolvers import reverse
from apps.reader.models import UserSubscription, UserSubscriptionFolders
from apps.feed_import.models import GoogleReaderImporter
from utils import json_functions as json

class ImportTest(TestCase):
    fixtures = ['opml_import.json']
    
    def setUp(self):
        self.client = Client()
            
    def test_opml_import(self):
        self.client.login(username='conesus', password='test')
        user = User.objects.get(username='conesus')
        
        # Verify user has no feeds
        subs = UserSubscription.objects.filter(user=user)
        self.assertEquals(subs.count(), 0)
        
        f = open(os.path.join(os.path.dirname(__file__), 'fixtures/opml.xml'))
        response = self.client.post(reverse('opml-upload'), {'file': f})
        self.assertEquals(response.status_code, 200)
        
        # Verify user now has feeds
        subs = UserSubscription.objects.filter(user=user)
        self.assertEquals(subs.count(), 54)
        
    def test_opml_import__empty(self):
        self.client.login(username='conesus', password='test')
        user = User.objects.get(username='conesus')
        
        # Verify user has default feeds
        subs = UserSubscription.objects.filter(user=user)
        self.assertEquals(subs.count(), 0)

        response = self.client.post(reverse('opml-upload'))
        self.assertEquals(response.status_code, 200)
        
        # Verify user now has feeds
        subs = UserSubscription.objects.filter(user=user)
        self.assertEquals(subs.count(), 0)
    
    def test_google_reader_import(self):
        self.client.login(username='conesus', password='test')
        user = User.objects.get(username='conesus')
        f = open(os.path.join(os.path.dirname(__file__), 'fixtures/google_reader.xml'))
        xml = f.read()
        f.close()
        
        reader_importer = GoogleReaderImporter(user, xml=xml)
        reader_importer.import_feeds()

        subs = UserSubscription.objects.filter(user=user)
        self.assertEquals(subs.count(), 66)
        
        usf = UserSubscriptionFolders.objects.get(user=user)
        print json.decode(usf.folders)
        self.assertEquals(json.decode(usf.folders), [{u'Tech': [4, 5, 2, 9, 10, 12, 13, 14, 20, 23, 24, 26, 27, 28, 31, 32, 33, 34, 48, 49, 62, 64]}, 1, 2, 3, 6, {u'Blogs': [1, 3, 25, 29, 30, 39, 40, 41, 50, 55, 57, 58, 59, 60, 66]}, {u'Blogs \u2014 Tumblrs': [5, 21, 37, 38, 53, 54, 63, 65]}, {u'Blogs \u2014 The Bloglets': [6, 16, 22, 35, 51, 56]}, {u'New York': [7, 8, 17, 18, 19, 36, 45, 47, 52, 61]}, {u'Cooking': [11, 15, 42, 43, 46]}, 44])
        