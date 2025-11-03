import datetime

from django.contrib.auth.models import User
from django.test import TestCase, TransactionTestCase
from django.test.client import Client
from django.urls import reverse

from apps.analyzer.models import (
    MClassifierAuthor,
    MClassifierFeed,
    MClassifierTag,
    MClassifierText,
    MClassifierTitle,
    apply_classifier_authors,
    apply_classifier_feeds,
    apply_classifier_tags,
    apply_classifier_texts,
    apply_classifier_titles,
    compute_story_score,
    get_classifiers_for_user,
)
from apps.reader.models import UserSubscription
from apps.rss_feeds.models import Feed
from utils import json_functions as json


class Test_Classifiers(TransactionTestCase):
    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
        "apps/rss_feeds/fixtures/rss_feeds.json",
    ]

    def setUp(self):
        self.client = Client()
        # Create user
        self.user = User.objects.create_user(username="testuser", password="testpass", email="test@test.com")
        self.feed = Feed.objects.get(pk=1)
        # Create subscription
        UserSubscription.objects.create(user=self.user, feed=self.feed, is_trained=False)

    def tearDown(self):
        # Clean up MongoDB classifiers
        MClassifierTitle.objects(user_id=self.user.pk).delete()
        MClassifierText.objects(user_id=self.user.pk).delete()
        MClassifierAuthor.objects(user_id=self.user.pk).delete()
        MClassifierTag.objects(user_id=self.user.pk).delete()
        MClassifierFeed.objects(user_id=self.user.pk).delete()

    def test_create_classifier_title(self):
        classifier = MClassifierTitle.objects.create(
            user_id=self.user.pk,
            feed_id=self.feed.pk,
            social_user_id=0,
            title="breaking news",
            score=1,
            creation_date=datetime.datetime.now(),
        )
        self.assertEqual(classifier.title, "breaking news")
        self.assertEqual(classifier.score, 1)
        self.assertEqual(classifier.user_id, self.user.pk)
        self.assertEqual(classifier.feed_id, self.feed.pk)

    def test_create_classifier_text(self):
        classifier = MClassifierText.objects.create(
            user_id=self.user.pk,
            feed_id=self.feed.pk,
            social_user_id=0,
            text="important announcement",
            score=1,
            creation_date=datetime.datetime.now(),
        )
        self.assertEqual(classifier.text, "important announcement")
        self.assertEqual(classifier.score, 1)
        self.assertEqual(classifier.user_id, self.user.pk)
        self.assertEqual(classifier.feed_id, self.feed.pk)

    def test_create_classifier_author(self):
        classifier = MClassifierAuthor.objects.create(
            user_id=self.user.pk,
            feed_id=self.feed.pk,
            social_user_id=0,
            author="John Doe",
            score=-1,
            creation_date=datetime.datetime.now(),
        )
        self.assertEqual(classifier.author, "John Doe")
        self.assertEqual(classifier.score, -1)

    def test_create_classifier_tag(self):
        classifier = MClassifierTag.objects.create(
            user_id=self.user.pk,
            feed_id=self.feed.pk,
            social_user_id=0,
            tag="technology",
            score=1,
            creation_date=datetime.datetime.now(),
        )
        self.assertEqual(classifier.tag, "technology")
        self.assertEqual(classifier.score, 1)

    def test_apply_classifier_titles(self):
        MClassifierTitle.objects.create(
            user_id=self.user.pk,
            feed_id=self.feed.pk,
            social_user_id=0,
            title="breaking",
            score=1,
            creation_date=datetime.datetime.now(),
        )

        story = {"story_feed_id": self.feed.pk, "story_title": "Breaking News: Major Update"}

        classifiers = list(MClassifierTitle.objects(user_id=self.user.pk, feed_id=self.feed.pk))
        score = apply_classifier_titles(classifiers, story)

        self.assertEqual(score, 1)

    def test_apply_classifier_titles_no_match(self):
        MClassifierTitle.objects.create(
            user_id=self.user.pk,
            feed_id=self.feed.pk,
            social_user_id=0,
            title="sports",
            score=1,
            creation_date=datetime.datetime.now(),
        )

        story = {"story_feed_id": self.feed.pk, "story_title": "Technology News"}

        classifiers = list(MClassifierTitle.objects(user_id=self.user.pk, feed_id=self.feed.pk))
        score = apply_classifier_titles(classifiers, story)

        self.assertEqual(score, 0)

    def test_apply_classifier_texts(self):
        MClassifierText.objects.create(
            user_id=self.user.pk,
            feed_id=self.feed.pk,
            social_user_id=0,
            text="important announcement",
            score=1,
            creation_date=datetime.datetime.now(),
        )

        story = {
            "story_feed_id": self.feed.pk,
            "story_title": "News Update",
            "story_content": "This is an important announcement about our new features.",
        }

        classifiers = list(MClassifierText.objects(user_id=self.user.pk, feed_id=self.feed.pk))
        score = apply_classifier_texts(classifiers, story)

        self.assertEqual(score, 1)

    def test_apply_classifier_texts_no_match(self):
        MClassifierText.objects.create(
            user_id=self.user.pk,
            feed_id=self.feed.pk,
            social_user_id=0,
            text="sports update",
            score=1,
            creation_date=datetime.datetime.now(),
        )

        story = {
            "story_feed_id": self.feed.pk,
            "story_title": "Technology News",
            "story_content": "New technology breakthrough announced today.",
        }

        classifiers = list(MClassifierText.objects(user_id=self.user.pk, feed_id=self.feed.pk))
        score = apply_classifier_texts(classifiers, story)

        self.assertEqual(score, 0)

    def test_apply_classifier_texts_no_content(self):
        MClassifierText.objects.create(
            user_id=self.user.pk,
            feed_id=self.feed.pk,
            social_user_id=0,
            text="important",
            score=1,
            creation_date=datetime.datetime.now(),
        )

        story = {"story_feed_id": self.feed.pk, "story_title": "News"}

        classifiers = list(MClassifierText.objects(user_id=self.user.pk, feed_id=self.feed.pk))
        score = apply_classifier_texts(classifiers, story)

        self.assertEqual(score, 0)

    def test_apply_classifier_texts_case_insensitive(self):
        MClassifierText.objects.create(
            user_id=self.user.pk,
            feed_id=self.feed.pk,
            social_user_id=0,
            text="IMPORTANT",
            score=1,
            creation_date=datetime.datetime.now(),
        )

        story = {
            "story_feed_id": self.feed.pk,
            "story_title": "News",
            "story_content": "This is an important message.",
        }

        classifiers = list(MClassifierText.objects(user_id=self.user.pk, feed_id=self.feed.pk))
        score = apply_classifier_texts(classifiers, story)

        self.assertEqual(score, 1)

    def test_apply_classifier_authors(self):
        MClassifierAuthor.objects.create(
            user_id=self.user.pk,
            feed_id=self.feed.pk,
            social_user_id=0,
            author="John Doe",
            score=-1,
            creation_date=datetime.datetime.now(),
        )

        story = {"story_feed_id": self.feed.pk, "story_authors": "John Doe"}

        classifiers = list(MClassifierAuthor.objects(user_id=self.user.pk, feed_id=self.feed.pk))
        score = apply_classifier_authors(classifiers, story)

        self.assertEqual(score, -1)

    def test_apply_classifier_tags(self):
        MClassifierTag.objects.create(
            user_id=self.user.pk,
            feed_id=self.feed.pk,
            social_user_id=0,
            tag="technology",
            score=1,
            creation_date=datetime.datetime.now(),
        )

        story = {"story_feed_id": self.feed.pk, "story_tags": ["technology", "news"]}

        classifiers = list(MClassifierTag.objects(user_id=self.user.pk, feed_id=self.feed.pk))
        score = apply_classifier_tags(classifiers, story)

        self.assertEqual(score, 1)

    def test_compute_story_score_with_title(self):
        MClassifierTitle.objects.create(
            user_id=self.user.pk,
            feed_id=self.feed.pk,
            social_user_id=0,
            title="important",
            score=1,
            creation_date=datetime.datetime.now(),
        )

        story = {
            "story_feed_id": self.feed.pk,
            "story_title": "Important News",
            "story_content": "Content here",
            "story_authors": "",
            "story_tags": [],
        }

        classifier_titles = list(MClassifierTitle.objects(user_id=self.user.pk, feed_id=self.feed.pk))
        classifier_texts = list(MClassifierText.objects(user_id=self.user.pk, feed_id=self.feed.pk))
        classifier_authors = list(MClassifierAuthor.objects(user_id=self.user.pk, feed_id=self.feed.pk))
        classifier_tags = list(MClassifierTag.objects(user_id=self.user.pk, feed_id=self.feed.pk))
        classifier_feeds = list(MClassifierFeed.objects(user_id=self.user.pk, feed_id=self.feed.pk))

        score = compute_story_score(
            story, classifier_titles, classifier_authors, classifier_tags, classifier_feeds, classifier_texts
        )

        self.assertEqual(score, 1)

    def test_compute_story_score_with_text(self):
        MClassifierText.objects.create(
            user_id=self.user.pk,
            feed_id=self.feed.pk,
            social_user_id=0,
            text="exclusive content",
            score=1,
            creation_date=datetime.datetime.now(),
        )

        story = {
            "story_feed_id": self.feed.pk,
            "story_title": "News Update",
            "story_content": "This article contains exclusive content about the industry.",
            "story_authors": "",
            "story_tags": [],
        }

        classifier_titles = list(MClassifierTitle.objects(user_id=self.user.pk, feed_id=self.feed.pk))
        classifier_texts = list(MClassifierText.objects(user_id=self.user.pk, feed_id=self.feed.pk))
        classifier_authors = list(MClassifierAuthor.objects(user_id=self.user.pk, feed_id=self.feed.pk))
        classifier_tags = list(MClassifierTag.objects(user_id=self.user.pk, feed_id=self.feed.pk))
        classifier_feeds = list(MClassifierFeed.objects(user_id=self.user.pk, feed_id=self.feed.pk))

        score = compute_story_score(
            story, classifier_titles, classifier_authors, classifier_tags, classifier_feeds, classifier_texts
        )

        self.assertEqual(score, 1)

    def test_compute_story_score_with_negative_author(self):
        MClassifierAuthor.objects.create(
            user_id=self.user.pk,
            feed_id=self.feed.pk,
            social_user_id=0,
            author="Bad Author",
            score=-1,
            creation_date=datetime.datetime.now(),
        )

        story = {
            "story_feed_id": self.feed.pk,
            "story_title": "News",
            "story_content": "Content",
            "story_authors": "Bad Author",
            "story_tags": [],
        }

        classifier_titles = list(MClassifierTitle.objects(user_id=self.user.pk, feed_id=self.feed.pk))
        classifier_texts = list(MClassifierText.objects(user_id=self.user.pk, feed_id=self.feed.pk))
        classifier_authors = list(MClassifierAuthor.objects(user_id=self.user.pk, feed_id=self.feed.pk))
        classifier_tags = list(MClassifierTag.objects(user_id=self.user.pk, feed_id=self.feed.pk))
        classifier_feeds = list(MClassifierFeed.objects(user_id=self.user.pk, feed_id=self.feed.pk))

        score = compute_story_score(
            story, classifier_titles, classifier_authors, classifier_tags, classifier_feeds, classifier_texts
        )

        self.assertEqual(score, -1)

    def test_compute_story_score_text_beats_title(self):
        # Both title and text match, should return text score since it's checked in same max/min logic
        MClassifierTitle.objects.create(
            user_id=self.user.pk,
            feed_id=self.feed.pk,
            social_user_id=0,
            title="news",
            score=1,
            creation_date=datetime.datetime.now(),
        )
        MClassifierText.objects.create(
            user_id=self.user.pk,
            feed_id=self.feed.pk,
            social_user_id=0,
            text="breaking",
            score=1,
            creation_date=datetime.datetime.now(),
        )

        story = {
            "story_feed_id": self.feed.pk,
            "story_title": "Breaking News Update",
            "story_content": "This is breaking news content.",
            "story_authors": "",
            "story_tags": [],
        }

        classifier_titles = list(MClassifierTitle.objects(user_id=self.user.pk, feed_id=self.feed.pk))
        classifier_texts = list(MClassifierText.objects(user_id=self.user.pk, feed_id=self.feed.pk))
        classifier_authors = list(MClassifierAuthor.objects(user_id=self.user.pk, feed_id=self.feed.pk))
        classifier_tags = list(MClassifierTag.objects(user_id=self.user.pk, feed_id=self.feed.pk))
        classifier_feeds = list(MClassifierFeed.objects(user_id=self.user.pk, feed_id=self.feed.pk))

        score = compute_story_score(
            story, classifier_titles, classifier_authors, classifier_tags, classifier_feeds, classifier_texts
        )

        self.assertEqual(score, 1)

    def test_get_classifiers_for_user(self):
        # Make user Pro to enable text classifiers
        self.user.profile.is_pro = True
        self.user.profile.save()

        MClassifierTitle.objects.create(
            user_id=self.user.pk,
            feed_id=self.feed.pk,
            social_user_id=0,
            title="important",
            score=1,
            creation_date=datetime.datetime.now(),
        )
        MClassifierText.objects.create(
            user_id=self.user.pk,
            feed_id=self.feed.pk,
            social_user_id=0,
            text="exclusive",
            score=1,
            creation_date=datetime.datetime.now(),
        )
        MClassifierAuthor.objects.create(
            user_id=self.user.pk,
            feed_id=self.feed.pk,
            social_user_id=0,
            author="Good Author",
            score=1,
            creation_date=datetime.datetime.now(),
        )

        classifiers = get_classifiers_for_user(self.user, feed_id=self.feed.pk)

        self.assertIn("titles", classifiers)
        self.assertIn("texts", classifiers)
        self.assertIn("authors", classifiers)
        self.assertIn("tags", classifiers)
        self.assertIn("feeds", classifiers)

        self.assertEqual(classifiers["titles"]["important"], 1)
        self.assertEqual(classifiers["texts"]["exclusive"], 1)
        self.assertEqual(classifiers["authors"]["Good Author"], 1)

    def test_text_classifiers_premium_tiers(self):
        # Create text classifier for testing
        MClassifierText.objects.create(
            user_id=self.user.pk,
            feed_id=self.feed.pk,
            social_user_id=0,
            text="exclusive",
            score=1,
            creation_date=datetime.datetime.now(),
        )
        MClassifierTitle.objects.create(
            user_id=self.user.pk,
            feed_id=self.feed.pk,
            social_user_id=0,
            title="important",
            score=1,
            creation_date=datetime.datetime.now(),
        )

        # Regular user should have text classifiers but they won't be applied to stories
        self.user.profile.is_premium = False
        self.user.profile.is_archive = False
        self.user.profile.is_pro = False
        self.user.profile.save()

        classifiers = get_classifiers_for_user(self.user, feed_id=self.feed.pk)
        self.assertEqual(len(classifiers["texts"]), 1)
        self.assertEqual(classifiers["texts"]["exclusive"], 1)
        self.assertEqual(len(classifiers["titles"]), 1)

        # Regular premium user should have text classifiers but they won't be applied to stories
        self.user.profile.is_premium = True
        self.user.profile.is_archive = False
        self.user.profile.is_pro = False
        self.user.profile.save()

        classifiers = get_classifiers_for_user(self.user, feed_id=self.feed.pk)
        self.assertEqual(len(classifiers["texts"]), 1)
        self.assertEqual(classifiers["texts"]["exclusive"], 1)
        self.assertEqual(len(classifiers["titles"]), 1)

        # Premium archive user should have text classifiers
        self.user.profile.is_premium = True
        self.user.profile.is_archive = True
        self.user.profile.is_pro = False
        self.user.profile.save()

        classifiers = get_classifiers_for_user(self.user, feed_id=self.feed.pk)
        self.assertEqual(len(classifiers["texts"]), 1)
        self.assertEqual(classifiers["texts"]["exclusive"], 1)
        self.assertEqual(len(classifiers["titles"]), 1)

    def test_save_classifier_title_endpoint(self):
        self.client.login(username="testuser", password="testpass")

        response = self.client.post(
            "/classifier/save/", {"feed_id": self.feed.pk, "like_title": ["important", "breaking"]}
        )

        content = json.decode(response.content)
        self.assertEqual(content["code"], 0)

        classifiers = list(MClassifierTitle.objects(user_id=self.user.pk, feed_id=self.feed.pk))
        self.assertEqual(len(classifiers), 2)
        self.assertEqual(classifiers[0].score, 1)

    def test_save_classifier_text_endpoint(self):
        self.client.login(username="testuser", password="testpass")

        response = self.client.post(
            "/classifier/save/",
            {"feed_id": self.feed.pk, "like_text": ["exclusive content", "important announcement"]},
        )

        content = json.decode(response.content)
        self.assertEqual(content["code"], 0)

        classifiers = list(MClassifierText.objects(user_id=self.user.pk, feed_id=self.feed.pk))
        self.assertEqual(len(classifiers), 2)
        self.assertEqual(classifiers[0].score, 1)

    def test_save_classifier_dislike_text_endpoint(self):
        self.client.login(username="testuser", password="testpass")

        response = self.client.post(
            "/classifier/save/", {"feed_id": self.feed.pk, "dislike_text": ["spam content"]}
        )

        content = json.decode(response.content)
        self.assertEqual(content["code"], 0)

        classifiers = list(MClassifierText.objects(user_id=self.user.pk, feed_id=self.feed.pk))
        self.assertEqual(len(classifiers), 1)
        self.assertEqual(classifiers[0].score, -1)
        self.assertEqual(classifiers[0].text, "spam content")

    def test_save_classifier_remove_text_endpoint(self):
        # First create a classifier
        MClassifierText.objects.create(
            user_id=self.user.pk,
            feed_id=self.feed.pk,
            social_user_id=0,
            text="test content",
            score=1,
            creation_date=datetime.datetime.now(),
        )

        self.client.login(username="testuser", password="testpass")

        # Remove it
        response = self.client.post(
            "/classifier/save/", {"feed_id": self.feed.pk, "remove_like_text": ["test content"]}
        )

        content = json.decode(response.content)
        self.assertEqual(content["code"], 0)

        classifiers = list(MClassifierText.objects(user_id=self.user.pk, feed_id=self.feed.pk))
        self.assertEqual(len(classifiers), 0)

    def test_save_classifier_marks_subscription_trained(self):
        self.client.login(username="testuser", password="testpass")

        usersub = UserSubscription.objects.get(user=self.user, feed=self.feed)
        self.assertFalse(usersub.is_trained)

        response = self.client.post(
            "/classifier/save/", {"feed_id": self.feed.pk, "like_text": ["important"]}
        )

        content = json.decode(response.content)
        self.assertEqual(content["code"], 0)

        usersub.refresh_from_db()
        self.assertTrue(usersub.is_trained)
        self.assertTrue(usersub.needs_unread_recalc)
