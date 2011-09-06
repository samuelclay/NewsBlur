from django.test.client import Client
from apps.rss_feeds.models import MStory
from django.test import TestCase
from django.core import management
# from apps.analyzer.classifier import FisherClassifier
import nltk
from itertools import groupby
from apps.analyzer.tokenizer import Tokenizer
from vendor.reverend.thomas import Bayes
from apps.analyzer.phrase_filter import PhraseFilter


class QuadgramCollocationFinder(nltk.collocations.AbstractCollocationFinder):
    """A tool for the finding and ranking of quadgram collocations or other association measures. 
    It is often useful to use from_words() rather thanconstructing an instance directly.
    """
    def __init__(self, word_fd, quadgram_fd, trigram_fd, bigram_fd, wildcard_fd):
        """Construct a TrigramCollocationFinder, given FreqDists for appearances of words, bigrams, two words with any word between them,and trigrams."""
        nltk.collocations.AbstractCollocationFinder.__init__(self, word_fd, quadgram_fd)
        self.trigram_fd = trigram_fd
        self.bigram_fd = bigram_fd
        self.wildcard_fd = wildcard_fd
        
    @classmethod
    def from_words(cls, words):
        wfd = nltk.probability.FreqDist()
        qfd = nltk.probability.FreqDist()
        tfd = nltk.probability.FreqDist()
        bfd = nltk.probability.FreqDist()
        wildfd = nltk.probability.FreqDist()
        
        for w1, w2, w3 ,w4 in nltk.util.ingrams(words, 4, pad_right=True):
            wfd.inc(w1)
            if w4 is None:
                continue
            else:
                qfd.inc((w1,w2,w3,w4))
            bfd.inc((w1,w2))
            tfd.inc((w1,w2,w3))
            wildfd.inc((w1,w3,w4))
            wildfd.inc((w1,w2,w4))
            
        return cls(wfd, qfd, tfd, bfd, wildfd)
    
    def score_ngram(self, score_fn, w1, w2, w3, w4):
        n_all = self.word_fd.N()
        n_iiii = self.ngram_fd[(w1, w2, w3, w4)]
        if not n_iiii:
            return
        n_iiix = self.bigram_fd[(w1, w2)]
        n_iixi = self.bigram_fd[(w2, w3)]
        n_ixii = self.bigram_fd[(w3, w4)]
        n_xiii = self.bigram_fd[(w3, w4)]
        n_iixx = self.word_fd[w1]
        n_ixix = self.word_fd[w2]
        n_ixxi = self.word_fd[w3]
        n_ixxx = self.word_fd[w4]
        n_xiix = self.trigram_fd[(w1, w2)]
        n_xixi = self.trigram_fd[(w2, w3)]
        n_xxii = self.trigram_fd[(w3, w4)]
        n_xxxi = self.trigram_fd[(w3, w4)]
        return score_fn(n_iiii,
                        (n_iiix, n_iixi, n_ixii, n_xiii),
                        (n_iixx, n_ixix, n_ixxi, n_ixxx),
                        (n_xiix, n_xixi, n_xxii, n_xxxi),
                        n_all)

    
class CollocationTest(TestCase):
    
    fixtures = ['brownstoner.json']
    
    def setUp(self):
        self.client = Client()
        
    def test_bigrams(self):
        # bigram_measures = nltk.collocations.BigramAssocMeasures()
        trigram_measures = nltk.collocations.TrigramAssocMeasures()

        tokens = [
            'Co-op', 'of', 'the', 'day',
            'House', 'of', 'the', 'day',
            'Condo', 'of', 'the', 'day',
            'Development', 'Watch',
            'Co-op', 'of', 'the', 'day',
        ]
        finder = nltk.collocations.TrigramCollocationFinder.from_words(tokens)
        
        finder.apply_freq_filter(2)
        
        # return the 10 n-grams with the highest PMI
        print finder.nbest(trigram_measures.pmi, 10)

        titles = [
            'Co-op of the day',
            'Condo of the day',
            'Co-op of the day',
            'House of the day',
            'Development Watch',
            'Streetlevel',
        ]

        tokens = nltk.tokenize.word(' '.join(titles))
        ngrams = nltk.ngrams(tokens, 4)
        d = [key for key, group in groupby(sorted(ngrams)) if len(list(group)) >= 2]
        print d

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
        # user = User.objects.all()
        # feed = Feed.objects.all()
        
        management.call_command('loaddata', 'brownstoner.json', verbosity=0)
        management.call_command('refresh_feed', force=1, feed=1, single_threaded=True, daemonize=False)
        management.call_command('loaddata', 'brownstoner2.json', verbosity=0)
        management.call_command('refresh_feed', force=1, feed=1, single_threaded=True, daemonize=False)
        
        stories = MStory.objects(story_feed_id=1)[:53]
        
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
        