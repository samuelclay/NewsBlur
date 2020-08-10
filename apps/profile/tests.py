from utils import json_functions as json
from django.test.client import Client
from django.test import TestCase
from django.core.urlresolvers import reverse
from django.conf import settings
from mongoengine.connection import connect, disconnect

class ProfiuleTest(TestCase):
    fixtures = ['rss_feeds.json']
    
    def setUp(self):
        disconnect()
        settings.MONGODB = connect('test_newsblur')
        self.client = Client(HTTP_USER_AGENT='Mozilla/5.0')

    def tearDown(self):
        settings.MONGODB.drop_database('test_newsblur')
            
    def test_create_account(self):
        response = self.client.post(reverse('welcome-signup'), {
            'signup_username': 'test',
            'signup_password': 'password',
            'signup_email': 'test@newsblur.com',
        })
        
        