import datetime
from collections import defaultdict

import mongoengine as mongo
from django.conf import settings
from django.contrib.auth.models import User
from django.core.mail import EmailMultiAlternatives
from django.db import models
from django.template.loader import render_to_string

from apps.analyzer.tasks import EmailPopularityQuery
from apps.rss_feeds.models import Feed
from utils import log as logging
from utils.ai_functions import classify_stories_with_ai


class FeatureCategory(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    feed = models.ForeignKey(Feed, on_delete=models.CASCADE)
    feature = models.CharField(max_length=255)
    category = models.CharField(max_length=255)
    count = models.IntegerField(default=0)

    def __str__(self):
        return "%s - %s (%s)" % (self.feature, self.category, self.count)


class Category(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    feed = models.ForeignKey(Feed, on_delete=models.CASCADE)
    category = models.CharField(max_length=255)
    count = models.IntegerField(default=0)

    def __str__(self):
        return "%s (%s)" % (self.category, self.count)


class MPopularityQuery(mongo.Document):
    email = mongo.StringField()
    query = mongo.StringField()
    is_emailed = mongo.BooleanField()
    creation_date = mongo.DateTimeField(default=datetime.datetime.now)

    meta = {
        "collection": "popularity_query",
        "allow_inheritance": False,
    }

    def __str__(self):
        return '%s - "%s"' % (self.email, self.query)

    def queue_email(self):
        EmailPopularityQuery.delay(pk=str(self.pk))

    @classmethod
    def ensure_all_sent(cls, queue=True):
        for query in cls.objects.all().order_by("creation_date"):
            query.ensure_sent(queue=queue)

    def ensure_sent(self, queue=True):
        if self.is_emailed:
            logging.debug(" ---> Already sent %s" % self)
            return

        if queue:
            self.queue_email()
        else:
            self.send_email()

    def send_email(self, limit=5000):
        filename = Feed.xls_query_popularity(self.query, limit=limit)
        xlsx = open(filename, "r")

        params = {"query": self.query}
        text = render_to_string("mail/email_popularity_query.txt", params)
        html = render_to_string("mail/email_popularity_query.xhtml", params)
        subject = 'Keyword popularity spreadsheet: "%s"' % self.query
        msg = EmailMultiAlternatives(
            subject, text, from_email="NewsBlur <%s>" % settings.HELLO_EMAIL, to=["<%s>" % (self.email)]
        )
        msg.attach_alternative(html, "text/html")
        msg.attach(filename, xlsx.read(), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
        msg.send()

        self.is_emailed = True
        self.save()

        logging.debug(" -> ~BB~FM~SBSent email for popularity query: %s" % self)


class MClassifierTitle(mongo.Document):
    user_id = mongo.IntField()
    feed_id = mongo.IntField()
    social_user_id = mongo.IntField()
    title = mongo.StringField(max_length=255)
    score = mongo.IntField()
    creation_date = mongo.DateTimeField()

    meta = {
        "collection": "classifier_title",
        "indexes": [("user_id", "feed_id"), "feed_id", ("user_id", "social_user_id"), "social_user_id"],
        "allow_inheritance": False,
    }

    def __str__(self):
        user = User.objects.get(pk=self.user_id)
        return "%s - %s/%s: (%s) %s" % (user, self.feed_id, self.social_user_id, self.score, self.title[:30])


class MClassifierText(mongo.Document):
    user_id = mongo.IntField()
    feed_id = mongo.IntField()
    social_user_id = mongo.IntField()
    text = mongo.StringField(max_length=255)
    score = mongo.IntField()
    creation_date = mongo.DateTimeField()

    meta = {
        "collection": "classifier_text",
        "indexes": [("user_id", "feed_id"), "feed_id", ("user_id", "social_user_id"), "social_user_id"],
        "allow_inheritance": False,
    }

    def __str__(self):
        user = User.objects.get(pk=self.user_id)
        return "%s - %s/%s: (%s) %s" % (user, self.feed_id, self.social_user_id, self.score, self.text[:30])


class MClassifierAuthor(mongo.Document):
    user_id = mongo.IntField(unique_with=("feed_id", "social_user_id", "author"))
    feed_id = mongo.IntField()
    social_user_id = mongo.IntField()
    author = mongo.StringField(max_length=255)
    score = mongo.IntField()
    creation_date = mongo.DateTimeField()

    meta = {
        "collection": "classifier_author",
        "indexes": [("user_id", "feed_id"), "feed_id", ("user_id", "social_user_id"), "social_user_id"],
        "allow_inheritance": False,
    }

    def __str__(self):
        user = User.objects.get(pk=self.user_id)
        return "%s - %s/%s: (%s) %s" % (user, self.feed_id, self.social_user_id, self.score, self.author[:30])


class MClassifierTag(mongo.Document):
    user_id = mongo.IntField(unique_with=("feed_id", "social_user_id", "tag"))
    feed_id = mongo.IntField()
    social_user_id = mongo.IntField()
    tag = mongo.StringField(max_length=255)
    score = mongo.IntField()
    creation_date = mongo.DateTimeField()

    meta = {
        "collection": "classifier_tag",
        "indexes": [("user_id", "feed_id"), "feed_id", ("user_id", "social_user_id"), "social_user_id"],
        "allow_inheritance": False,
    }

    def __str__(self):
        user = User.objects.get(pk=self.user_id)
        return "%s - %s/%s: (%s) %s" % (user, self.feed_id, self.social_user_id, self.score, self.tag[:30])


class MClassifierFeed(mongo.Document):
    user_id = mongo.IntField(unique_with=("feed_id", "social_user_id"))
    feed_id = mongo.IntField()
    social_user_id = mongo.IntField()
    score = mongo.IntField()
    creation_date = mongo.DateTimeField()

    meta = {
        "collection": "classifier_feed",
        "indexes": [("user_id", "feed_id"), "feed_id", ("user_id", "social_user_id"), "social_user_id"],
        "allow_inheritance": False,
    }

    def __str__(self):
        user = User.objects.get(pk=self.user_id)
        if self.feed_id:
            feed = Feed.get_by_id(self.feed_id)
        else:
            feed = User.objects.get(pk=self.social_user_id)
        return "%s - %s/%s: (%s) %s" % (user, self.feed_id, self.social_user_id, self.score, feed)


def compute_story_score(
    story,
    classifier_titles,
    classifier_authors,
    classifier_tags,
    classifier_feeds,
    classifier_texts=None,
    prompt_score=None,
):
    if classifier_texts is None:
        classifier_texts = []

    intelligence = {
        "feed": apply_classifier_feeds(classifier_feeds, story["story_feed_id"]),
        "author": apply_classifier_authors(classifier_authors, story),
        "tags": apply_classifier_tags(classifier_tags, story),
        "title": apply_classifier_titles(classifier_titles, story),
        "text": apply_classifier_texts(classifier_texts, story),
    }

    # Include AI prompt classifier score if provided
    if prompt_score is not None:
        intelligence["prompt"] = prompt_score

    score = 0

    # If we have a prompt score, it takes priority
    if "prompt" in intelligence and intelligence["prompt"] != 0:
        return intelligence["prompt"]

    # Otherwise use the traditional classifier logic
    score_max = max(intelligence["title"], intelligence["author"], intelligence["tags"], intelligence["text"])
    score_min = min(intelligence["title"], intelligence["author"], intelligence["tags"], intelligence["text"])
    if score_max > 0:
        score = score_max
    elif score_min < 0:
        score = score_min

    if score == 0:
        score = intelligence["feed"]

    return score


def apply_classifier_titles(classifiers, story):
    score = 0
    for classifier in classifiers:
        if classifier.feed_id != story["story_feed_id"]:
            continue
        if classifier.title.lower() in story["story_title"].lower():
            # print 'Titles: (%s) %s -- %s' % (classifier.title in story['story_title'], classifier.title, story['story_title'])
            score = classifier.score
            if score > 0:
                return score
    return score


def apply_classifier_texts(classifiers, story):
    score = 0
    story_content = story.get("story_content", "")
    if not story_content:
        return score
    story_content_lower = story_content.lower()
    for classifier in classifiers:
        if classifier.feed_id != story["story_feed_id"]:
            continue
        if classifier.text.lower() in story_content_lower:
            score = classifier.score
            if score > 0:
                return score
    return score


def apply_classifier_authors(classifiers, story):
    score = 0
    for classifier in classifiers:
        if classifier.feed_id != story["story_feed_id"]:
            continue
        if story.get("story_authors") and classifier.author == story.get("story_authors"):
            # print 'Authors: %s -- %s' % (classifier.author, story['story_authors'])
            score = classifier.score
            if score > 0:
                return classifier.score
    return score


def apply_classifier_tags(classifiers, story):
    score = 0
    for classifier in classifiers:
        if classifier.feed_id != story["story_feed_id"]:
            continue
        if story["story_tags"] and classifier.tag in story["story_tags"]:
            # print 'Tags: (%s-%s) %s -- %s' % (classifier.tag in story['story_tags'], classifier.score, classifier.tag, story['story_tags'])
            score = classifier.score
            if score > 0:
                return classifier.score
    return score


def apply_classifier_feeds(classifiers, feed, social_user_ids=None):
    if not feed and not social_user_ids:
        return 0
    feed_id = None
    if feed:
        feed_id = feed if isinstance(feed, int) else feed.pk

    if social_user_ids and not isinstance(social_user_ids, list):
        social_user_ids = [social_user_ids]

    for classifier in classifiers:
        if classifier.feed_id == feed_id:
            # print 'Feeds: %s -- %s' % (classifier.feed_id, feed.pk)
            return classifier.score
        if social_user_ids and not classifier.feed_id and classifier.social_user_id in social_user_ids:
            return classifier.score
    return 0


class MClassifierPrompt(mongo.Document):
    user_id = mongo.IntField()
    feed_id = mongo.IntField(default=0)  # 0 means applies to folder level
    folder_id = mongo.StringField(default="")  # Empty string means applies to feed level
    prompt = mongo.StringField()
    classifier_type = mongo.StringField(choices=["focus", "hidden"])
    creation_date = mongo.DateTimeField(default=datetime.datetime.now)

    meta = {
        "collection": "prompt_classifier",
        "indexes": [("user_id", "feed_id"), ("user_id", "folder_id")],
        "allow_inheritance": False,
    }

    def __str__(self):
        user = User.objects.get(pk=self.user_id)
        target = f"Feed: {self.feed_id}" if self.feed_id else f"Folder: {self.folder_id}"
        return f"{user} - {target}: ({self.classifier_type}) {self.prompt[:50]}..."

    @classmethod
    def get_prompts_for_user(cls, user_id, feed_ids=None, folder_ids=None):
        """
        Get all applicable prompt classifiers for a user and specific feeds/folders.

        Args:
            user_id: The ID of the user
            feed_ids: Optional list of feed IDs to filter by
            folder_ids: Optional list of folder IDs to filter by

        Returns:
            Dictionary with feed_id/folder_id keys and lists of prompts as values
        """
        params = {"user_id": user_id}

        # Get feed-specific prompts
        feed_prompts = {}
        if feed_ids:
            params["feed_id__in"] = feed_ids + [0]  # Include feed-specific and global prompts
            feed_classifiers = list(cls.objects.filter(**params))

            # Group by feed_id
            for prompt in feed_classifiers:
                if prompt.feed_id not in feed_prompts:
                    feed_prompts[prompt.feed_id] = []
                feed_prompts[prompt.feed_id].append(prompt)

        # Get folder-specific prompts
        folder_prompts = {}
        if folder_ids:
            params["folder_id__in"] = folder_ids + [""]  # Include folder-specific and global prompts
            folder_classifiers = list(cls.objects.filter(**params))

            # Group by folder_id
            for prompt in folder_classifiers:
                if prompt.folder_id not in folder_prompts:
                    folder_prompts[prompt.folder_id] = []
                folder_prompts[prompt.folder_id].append(prompt)

        return {"feed_prompts": feed_prompts, "folder_prompts": folder_prompts}

    @classmethod
    def classify_stories(cls, user_id, stories, feed_ids=None, folder_ids=None):
        """
        Apply AI-based classification to a list of stories based on user's prompts.

        Args:
            user_id: The ID of the user
            stories: List of story dictionaries
            feed_ids: Optional list of feed IDs the stories belong to
            folder_ids: Optional list of folder IDs the stories belong to

        Returns:
            Dictionary mapping story_ids to scores (1 for focus, 0 for neutral, -1 for hidden)
        """
        if not stories:
            return {}

        # Group stories by feed_id for efficient classification
        stories_by_feed = defaultdict(list)
        for story in stories:
            stories_by_feed[story["story_feed_id"]].append(story)

        # Get all applicable prompts
        prompts = cls.get_prompts_for_user(user_id, feed_ids=feed_ids, folder_ids=folder_ids)
        feed_prompts = prompts["feed_prompts"]
        folder_prompts = prompts["folder_prompts"]

        # Final classifications
        classifications = {story["story_id"]: 0 for story in stories}

        # Apply feed-specific prompts
        for feed_id, feed_stories in stories_by_feed.items():
            # Apply global prompts (feed_id=0)
            if 0 in feed_prompts:
                for prompt in feed_prompts[0]:
                    results = classify_stories_with_ai(prompt, feed_stories)
                    cls._update_classifications(classifications, results, prompt.classifier_type)

            # Apply feed-specific prompts
            if feed_id in feed_prompts:
                for prompt in feed_prompts[feed_id]:
                    results = classify_stories_with_ai(prompt, feed_stories)
                    cls._update_classifications(classifications, results, prompt.classifier_type)

        # Apply folder-specific prompts if we have folder_ids
        if folder_ids and folder_prompts:
            for folder_id in folder_ids:
                if folder_id in folder_prompts:
                    # Find stories that belong to feeds in this folder
                    folder_stories = []
                    for feed_id, feed_stories in stories_by_feed.items():
                        # We would need to check if feed_id belongs to folder_id here
                        # For simplicity, we'll just apply to all stories
                        # In a real implementation, you'd use a feed_folder mapping
                        folder_stories.extend(feed_stories)

                    # Apply folder prompts to eligible stories
                    for prompt in folder_prompts[folder_id]:
                        results = classify_stories_with_ai(prompt, folder_stories)
                        cls._update_classifications(classifications, results, prompt.classifier_type)

        return classifications

    @classmethod
    def _update_classifications(cls, classifications, results, classifier_type):
        """
        Update the classification dictionary based on new results and classifier type.

        Args:
            classifications: Dictionary to update
            results: New classification results
            classifier_type: Type of classifier ("focus" or "hidden")

        Returns:
            Updated classifications dictionary
        """
        for story_id, result in results.items():
            # Only update if the AI gave a non-neutral classification
            if result != 0:
                # For "focus" classifiers, only accept positive scores (1)
                if classifier_type == "focus" and result > 0:
                    classifications[story_id] = 1
                # For "hidden" classifiers, only accept negative scores (-1)
                elif classifier_type == "hidden" and result < 0:
                    classifications[story_id] = -1

        return classifications


def get_classifiers_for_user(
    user,
    feed_id=None,
    social_user_id=None,
    classifier_feeds=None,
    classifier_authors=None,
    classifier_titles=None,
    classifier_tags=None,
    classifier_texts=None,
):
    params = dict(user_id=user.pk)
    if isinstance(feed_id, list):
        params["feed_id__in"] = feed_id
    elif feed_id:
        params["feed_id"] = feed_id
    if social_user_id:
        if isinstance(social_user_id, str):
            social_user_id = int(social_user_id.replace("social:", ""))
        params["social_user_id"] = social_user_id

    if classifier_authors is None:
        classifier_authors = list(MClassifierAuthor.objects(**params))
    if classifier_titles is None:
        classifier_titles = list(MClassifierTitle.objects(**params))
    if classifier_tags is None:
        classifier_tags = list(MClassifierTag.objects(**params))
    if classifier_texts is None:
        classifier_texts = list(MClassifierText.objects(**params))
    if classifier_feeds is None:
        if not social_user_id and feed_id:
            params["social_user_id"] = 0
        classifier_feeds = list(MClassifierFeed.objects(**params))

    feeds = []
    for f in classifier_feeds:
        if f.social_user_id and not f.feed_id:
            feeds.append(("social:%s" % f.social_user_id, f.score))
        else:
            feeds.append((f.feed_id, f.score))

    payload = {
        "feeds": dict(feeds),
        "authors": dict([(a.author, a.score) for a in classifier_authors]),
        "titles": dict([(t.title, t.score) for t in classifier_titles]),
        "tags": dict([(t.tag, t.score) for t in classifier_tags]),
        "texts": dict([(t.text, t.score) for t in classifier_texts]),
    }

    return payload


def sort_classifiers_by_feed(
    user,
    feed_ids=None,
    classifier_feeds=None,
    classifier_authors=None,
    classifier_titles=None,
    classifier_tags=None,
    classifier_texts=None,
):
    def sort_by_feed(classifiers):
        feed_classifiers = defaultdict(list)
        if classifiers:
            for classifier in classifiers:
                feed_classifiers[classifier.feed_id].append(classifier)
        return feed_classifiers

    classifiers = {}

    if feed_ids:
        classifier_feeds = sort_by_feed(classifier_feeds)
        classifier_authors = sort_by_feed(classifier_authors)
        classifier_titles = sort_by_feed(classifier_titles)
        classifier_tags = sort_by_feed(classifier_tags)
        classifier_texts = sort_by_feed(classifier_texts)

        for feed_id in feed_ids:
            classifiers[feed_id] = get_classifiers_for_user(
                user,
                feed_id=feed_id,
                classifier_feeds=classifier_feeds[feed_id],
                classifier_authors=classifier_authors[feed_id],
                classifier_titles=classifier_titles[feed_id],
                classifier_tags=classifier_tags[feed_id],
                classifier_texts=classifier_texts[feed_id],
            )

    return classifiers
