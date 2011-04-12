from utils import json_functions as json
from django.test.client import Client
from django.contrib.auth.models import User
from apps.rss_feeds.models import Feed, Story
from django.test import TestCase
from django.core import management
from pprint import pprint
# from apps.analyzer.classifier import FisherClassifier
from apps.analyzer.tokenizer import Tokenizer
from vendor.reverend.thomas import Bayes
from apps.analyzer.phrase_filter import PhraseFilter

class ClassifierTest(TestCase):
    
    fixtures = ['classifiers.json', 'brownstoner.json']
    
    def setUp(self):
        self.client = Client()
    # 
    # def test_filter(self):
    #     user = User.objects.all()
    #     feed = Feed.objects.all()
    #     
    #     management.call_command('loaddata', 'brownstoner.json', verbosity=0)
    #     response = self.client.get('/reader/refresh_feed', { "feed_id": 1, "force": True })
    #     management.call_command('loaddata', 'brownstoner2.json', verbosity=0)
    #     response = self.client.get('/reader/refresh_feed', { "feed_id": 1, "force": True })
    #     management.call_command('loaddata', 'gothamist1.json', verbosity=0)
    #     response = self.client.get('/reader/refresh_feed', { "feed_id": 4, "force": True })
    #     management.call_command('loaddata', 'gothamist2.json', verbosity=0)
    #     response = self.client.get('/reader/refresh_feed', { "feed_id": 4, "force": True })
    #     
    #     stories = Story.objects.filter(story_feed=feed[1]).order_by('-story_date')[:100]
    #     
    #     phrasefilter = PhraseFilter()
    #     for story in stories:
    #         # print story.story_title, story.id
    #         phrasefilter.run(story.story_title, story.id)
    # 
    #     phrasefilter.pare_phrases()
    #     phrasefilter.print_phrases()
    #     
    def test_train(self):
        user = User.objects.all()
        feed = Feed.objects.all()
        
        management.call_command('loaddata', 'brownstoner.json', verbosity=0)
        management.call_command('refresh_feed', force=1, feed=1, single_threaded=True, daemonize=False)
        management.call_command('loaddata', 'brownstoner2.json', verbosity=0)
        management.call_command('refresh_feed', force=1, feed=1, single_threaded=True, daemonize=False)
        
        stories = Story.objects.filter(story_feed=1)[:53]
        
        phrasefilter = PhraseFilter()
        for story in stories:
            # print story.story_title, story.id
            phrasefilter.run(story.story_title, story.id)

        phrasefilter.pare_phrases()
        phrases = phrasefilter.get_phrases()
        print phrases
        
        tokenizer = Tokenizer(phrases)
        classifier = Bayes(tokenizer) # FisherClassifier(user[0], feed[0], phrases)
        
        classifier.train('good', 'House of the Day: 393 Pacific St.')
        classifier.train('good', 'House of the Day: 393 Pacific St.')
        classifier.train('good', 'Condo of the Day: 393 Pacific St.')
        classifier.train('good', 'Co-op of the Day: 393 Pacific St. #3')
        classifier.train('good', 'Co-op of the Day: 393 Pacific St. #3')
        classifier.train('good', 'Development Watch: 393 Pacific St. #3')
        classifier.train('bad', 'Development Watch: 393 Pacific St. #3')
        classifier.train('bad', 'Development Watch: 393 Pacific St. #3')
        classifier.train('bad', 'Development Watch: 393 Pacific St. #3')
        classifier.train('bad', 'Streetlevel: 393 Pacific St. #3')
        
        guess = dict(classifier.guess('Co-op of the Day: 413 Atlantic'))
        self.assertTrue(guess['good'] > .99)
        self.assertTrue('bad' not in guess)
        
        guess = dict(classifier.guess('House of the Day: 413 Atlantic'))
        self.assertTrue(guess['good'] > .99)
        self.assertTrue('bad' not in guess)
        
        guess = dict(classifier.guess('Development Watch: Yatta'))
        self.assertTrue(guess['bad'] > .7)
        self.assertTrue(guess['good'] < .3)

        guess = dict(classifier.guess('Development Watch: 393 Pacific St.'))
        self.assertTrue(guess['bad'] > .7)
        self.assertTrue(guess['good'] < .3)
        
        guess = dict(classifier.guess('Streetlevel: 123 Carlton St.'))
        self.assertTrue(guess['bad'] > .99)
        self.assertTrue('good' not in guess)

        guess = classifier.guess('Extra, Extra')
        self.assertTrue('bad' not in guess)
        self.assertTrue('good' not in guess)
        
        guess = classifier.guess('Nothing doing: 393 Pacific St.')
        self.assertTrue('bad' not in guess)
        self.assertTrue('good' not in guess)
        