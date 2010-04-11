
"""
Tests for L{reverend.guessers.email}.
"""

import email
from unittest import TestCase

from reverend.guessers.email import EmailClassifier


class EmailClassifierTests(TestCase):
    """
    Tests for L{EmailClassifier}
    """
    def setUp(self):
        """
        Create a L{Message} and an L{EmailClassifier}.
        """
        self.classifier = EmailClassifier()
        self.message = email.Message.Message()


    def test_training(self):
        """
        L{EmailClassifier.train} accepts a pool name and a L{Message}
        instance and trains the classifier to put similar messages into that
        pool.
        """
        self.classifier.train("test", self.message)


    def test_guessing(self):
        """
        L{EmailClassifier.guess} accepts a L{Message} and returns a pool
        name.
        """
        self.classifier.guess(self.message)
