from utils import json
from django.test.client import Client
from django.contrib.auth.models import User
from apps.rss_feeds.models import Feed, Story
from django.test import TestCase
from django.core import management
from pprint import pprint
from apps.analyzer.classifier import FisherClassifier
from apps.analyzer.phrase_filter import PhraseFilter

class ClassifierTest(TestCase):
    
    fixtures = ['classifiers.json', 'brownstoner.json']
    
    def setUp(self):
        self.client = Client()

    def test_filter(self):
        user = User.objects.all()
        feed = Feed.objects.all()
        
        management.call_command('loaddata', 'brownstoner.json', verbosity=0)
        response = self.client.get('/reader/refresh_feed', { "feed_id": 1, "force": True })
        management.call_command('loaddata', 'brownstoner2.json', verbosity=0)
        response = self.client.get('/reader/refresh_feed', { "feed_id": 1, "force": True })
        management.call_command('loaddata', 'gothamist1.json', verbosity=0)
        response = self.client.get('/reader/refresh_feed', { "feed_id": 4, "force": True })
        management.call_command('loaddata', 'gothamist2.json', verbosity=0)
        response = self.client.get('/reader/refresh_feed', { "feed_id": 4, "force": True })
        
        stories = Story.objects.filter(story_feed=feed[1]).order_by('-story_date')[:100]
        
        phrasefilter = PhraseFilter()
        for story in stories:
            print story.story_title, story.id
            phrasefilter.run(story.story_title, story.id)

        phrasefilter.pare_phrases()
        phrasefilter.print_phrases()
        
    def test_train(self):
        user = User.objects.all()
        feed = Feed.objects.all()
        
        management.call_command('loaddata', 'brownstoner.json', verbosity=0)
        response = self.client.get('/reader/refresh_feed', { "feed_id": 1, "force": True })
        
        phrases = [
            "House of the Day",
            "of the Day",
            "Coop of the Day",
            "Condo of the Day",
            "Development Watch",
            "Atlantic Yards",
            "Streetlevel"
        ]
        
        classifier = FisherClassifier(user[0], feed[0], phrases)
        
        stories = Story.objects.filter(story_feed=feed[0]).order_by('-story_date')[:20]
        
        
        classifier.train('House of the Day: 393 Pacific St.', 'good')
        classifier.train('House of the Day: 393 Pacific St.', 'good')
        classifier.train('Condo of the Day: 393 Pacific St.', 'good')
        classifier.train('Condo of the Day: 393 Pacific St.', 'good')
        classifier.train('Condo of the Day: 393 Pacific St.', 'good')
        classifier.train('Condo of the Day: 393 Pacific St.', 'good')
        classifier.train('Condo of the Day: 393 Pacific St.', 'good')
        classifier.train('Coop of the Day: 393 Pacific St. #3', 'good')
        classifier.train('Coop of the Day: 393 Pacific St. #3', 'good')
        classifier.train('Development Watch: 393 Pacific St. #3', 'bad')
        classifier.train('Development Watch: 393 Pacific St. #3', 'bad')
        classifier.train('Development Watch: 393 Pacific St. #3', 'bad')
        # classifier.train('Streetlevel: 393 Pacific St. #3', 'good')
        
        c1 = classifier.classify('Condo of the Day: 413 Atlantic')
        self.assertEquals(c1.category, "good")
        c1_prob = classifier.fisher_probability('Condo of the Day: 413 Atlantic', 'good')
        print c1_prob
        
        c2 = classifier.classify('Development Watch: Yatta')
        self.assertEquals(c2.category, "bad")
        c2 = classifier.classify('Development Watch: 393 Pacific St.')
        self.assertEquals(c2.category, "bad")
        c2_prob = classifier.fisher_probability('Development Watch: Yatta', 'good')
        self.assertTrue(c2_prob < .5)
        print c2_prob

        c4 = classifier.classify('Nothing doing: 393 Pacific St.')
        c4_prob = classifier.fisher_probability('Nothing doing: 393 Pacific St.', 'good')
        print c4_prob
        self.assertEquals(c4.category, "good")
        self.assertTrue(c4_prob == .5)
        
        