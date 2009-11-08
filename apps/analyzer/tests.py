from utils import json
from django.test.client import Client
from django.contrib.auth.models import User
from apps.rss_feeds.models import Feed
from django.test import TestCase
from django.core import management
from pprint import pprint
from apps.analyzer.classifier import FisherClassifier

class ClassifierTest(TestCase):
    
    fixtures = ['classifiers.json', 'brownstoner.json']
    
    def setUp(self):
        self.client = Client()

    def test_train(self):
        user = User.objects.all()
        feed = Feed.objects.all()
        classifier = FisherClassifier(user[0], feed[0])
        
        classifier.train('House of the Day: 393 Pacific St.', 'good')
        classifier.train('Coop of the Day: 393 Pacific St. #3', 'good')
        classifier.train('Development Watch: 393 Pacific St. #3', 'bad')
        
        c1 = classifier.classify('Condo of the Day: Yatta')
        self.assertEquals(c1.category, "good")
        
        