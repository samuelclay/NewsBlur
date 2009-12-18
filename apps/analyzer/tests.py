from utils import json
from django.test.client import Client
from django.contrib.auth.models import User
from apps.rss_feeds.models import Feed, Story
from django.test import TestCase
from django.core import management
from pprint import pprint
# from apps.analyzer.classifier import FisherClassifier
from apps.analyzer.tokenizer import Tokenizer
from utils.reverend.thomas import Bayes
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
        response = self.client.get('/reader/refresh_feed', { "feed_id": 1, "force": True })
        management.call_command('loaddata', 'brownstoner2.json', verbosity=0)
        response = self.client.get('/reader/refresh_feed', { "feed_id": 1, "force": True })
        
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
        # classifier.train('Development Watch: 393 Pacific St. #3', 'bad')
        # classifier.train('Streetlevel: 393 Pacific St. #3', 'good')
        
        c1 = classifier.guess('Co-op of the Day: 413 Atlantic')
        self.assertEquals(c1[0][0], "good")
        print c1
        
        c1 = classifier.guess('House of the Day: 413 Atlantic')
        self.assertEquals(c1[0][0], "good")
        print c1
        
        c2 = classifier.guess('Development Watch: Yatta')
        print c2
        self.assertEquals(c2[0][0], "bad")

        c2 = classifier.guess('Development Watch: 393 Pacific St.')
        print c2

        c3 = classifier.guess('Extra, Extra')
        print c3
        
        c4 = classifier.guess('Nothing doing: 393 Pacific St.')
        print c4
        