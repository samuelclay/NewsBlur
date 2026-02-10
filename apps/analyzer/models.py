import datetime
import re
import threading
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

# Regex timeout in seconds to prevent ReDoS attacks
REGEX_TIMEOUT = 0.1  # 100ms


def validate_regex_pattern(pattern):
    """
    Validate a regex pattern.
    Returns (is_valid, error_message).
    """
    try:
        re.compile(pattern)
        return True, None
    except re.error as e:
        return False, str(e)


def safe_regex_match(pattern, text, timeout=REGEX_TIMEOUT):
    """
    Safely perform regex matching with timeout protection.
    Returns True if pattern matches, False otherwise.
    Uses threading-based timeout (works on all platforms).
    """
    result = [False]
    exception = [None]

    def do_match():
        try:
            compiled = re.compile(pattern, re.IGNORECASE)
            if compiled.search(text):
                result[0] = True
        except Exception as e:
            exception[0] = e

    thread = threading.Thread(target=do_match)
    thread.daemon = True
    thread.start()
    thread.join(timeout)

    if thread.is_alive():
        # Thread is still running, regex timed out
        return False

    if exception[0]:
        # Regex raised an exception
        return False

    return result[0]


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
    is_regex = mongo.BooleanField(default=False)
    scope = mongo.StringField(default="feed", choices=("feed", "folder", "global"))
    folder_name = mongo.StringField(default="")
    creation_date = mongo.DateTimeField()

    meta = {
        "collection": "classifier_title",
        "indexes": [
            ("user_id", "feed_id"),
            "feed_id",
            ("user_id", "social_user_id"),
            "social_user_id",
            "is_regex",
            ("user_id", "scope", "folder_name"),
        ],
        "allow_inheritance": False,
        "strict": False,
    }

    def __str__(self):
        user = User.objects.get(pk=self.user_id)
        regex_indicator = " [regex]" if self.is_regex else ""
        return "%s - %s/%s: (%s) %s%s" % (
            user,
            self.feed_id,
            self.social_user_id,
            self.score,
            self.title[:30],
            regex_indicator,
        )


class MClassifierUrl(mongo.Document):
    user_id = mongo.IntField()
    feed_id = mongo.IntField()
    social_user_id = mongo.IntField()
    url = mongo.StringField(max_length=2048)  # URLs can be long
    score = mongo.IntField()
    is_regex = mongo.BooleanField(default=False)
    scope = mongo.StringField(default="feed", choices=("feed", "folder", "global"))
    folder_name = mongo.StringField(default="")
    creation_date = mongo.DateTimeField()

    meta = {
        "collection": "classifier_url",
        "indexes": [
            ("user_id", "feed_id"),
            "feed_id",
            ("user_id", "social_user_id"),
            "social_user_id",
            "is_regex",
            ("user_id", "scope", "folder_name"),
        ],
        "allow_inheritance": False,
        "strict": False,
    }

    def __str__(self):
        user = User.objects.get(pk=self.user_id)
        regex_indicator = " [regex]" if self.is_regex else ""
        return "%s - %s/%s: (%s) %s%s" % (
            user,
            self.feed_id,
            self.social_user_id,
            self.score,
            self.url[:50],
            regex_indicator,
        )


class MClassifierText(mongo.Document):
    user_id = mongo.IntField()
    feed_id = mongo.IntField()
    social_user_id = mongo.IntField()
    text = mongo.StringField(max_length=255)
    score = mongo.IntField()
    is_regex = mongo.BooleanField(default=False)
    scope = mongo.StringField(default="feed", choices=("feed", "folder", "global"))
    folder_name = mongo.StringField(default="")
    creation_date = mongo.DateTimeField()

    meta = {
        "collection": "classifier_text",
        "indexes": [
            ("user_id", "feed_id"),
            "feed_id",
            ("user_id", "social_user_id"),
            "social_user_id",
            "is_regex",
            ("user_id", "scope", "folder_name"),
        ],
        "allow_inheritance": False,
        "strict": False,
    }

    def __str__(self):
        user = User.objects.get(pk=self.user_id)
        regex_indicator = " [regex]" if self.is_regex else ""
        return "%s - %s/%s: (%s) %s%s" % (
            user,
            self.feed_id,
            self.social_user_id,
            self.score,
            self.text[:30],
            regex_indicator,
        )


class MClassifierAuthor(mongo.Document):
    user_id = mongo.IntField(unique_with=("feed_id", "social_user_id", "author"))
    feed_id = mongo.IntField()
    social_user_id = mongo.IntField()
    author = mongo.StringField(max_length=255)
    score = mongo.IntField()
    scope = mongo.StringField(default="feed", choices=("feed", "folder", "global"))
    folder_name = mongo.StringField(default="")
    creation_date = mongo.DateTimeField()

    meta = {
        "collection": "classifier_author",
        "indexes": [
            ("user_id", "feed_id"),
            "feed_id",
            ("user_id", "social_user_id"),
            "social_user_id",
            ("user_id", "scope", "folder_name"),
        ],
        "allow_inheritance": False,
        "strict": False,
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
    scope = mongo.StringField(default="feed", choices=("feed", "folder", "global"))
    folder_name = mongo.StringField(default="")
    creation_date = mongo.DateTimeField()

    meta = {
        "collection": "classifier_tag",
        "indexes": [
            ("user_id", "feed_id"),
            "feed_id",
            ("user_id", "social_user_id"),
            "social_user_id",
            ("user_id", "scope", "folder_name"),
        ],
        "allow_inheritance": False,
        "strict": False,
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
        "strict": False,
    }

    def __str__(self):
        user = User.objects.get(pk=self.user_id)
        if self.feed_id:
            feed = Feed.get_by_id(self.feed_id)
        else:
            feed = User.objects.get(pk=self.social_user_id)
        return "%s - %s/%s: (%s) %s" % (user, self.feed_id, self.social_user_id, self.score, feed)


def classifier_matches_story_feed(classifier, story_feed_id, folder_feed_ids=None):
    """Check if a classifier applies to a story based on its scope.

    Args:
        classifier: A classifier object with feed_id and optional scope/folder_name
        story_feed_id: The feed_id of the story being scored
        folder_feed_ids: Dict mapping folder_name -> set of feed_ids for folder-scoped classifiers

    Returns:
        True if the classifier applies to this story's feed
    """
    scope = getattr(classifier, "scope", "feed")
    if scope == "global":
        return True
    if scope == "folder":
        if folder_feed_ids is None:
            return False
        folder = getattr(classifier, "folder_name", "")
        feeds_in_folder = folder_feed_ids.get(folder, set())
        return story_feed_id in feeds_in_folder
    # scope == 'feed' (default)
    return classifier.feed_id == story_feed_id


def compute_story_score(
    story,
    classifier_titles,
    classifier_authors,
    classifier_tags,
    classifier_feeds,
    classifier_texts=None,
    classifier_urls=None,
    prompt_score=None,
    user_is_premium=False,
    user_is_pro=False,
    folder_feed_ids=None,
):
    if classifier_texts is None:
        classifier_texts = []
    if classifier_urls is None:
        classifier_urls = []

    intelligence = {
        "feed": apply_classifier_feeds(classifier_feeds, story["story_feed_id"]),
        "author": apply_classifier_authors(classifier_authors, story, folder_feed_ids=folder_feed_ids),
        "tags": apply_classifier_tags(classifier_tags, story, folder_feed_ids=folder_feed_ids),
        "title": apply_classifier_titles(classifier_titles, story, folder_feed_ids=folder_feed_ids),
        "title_regex": (
            apply_classifier_title_regex(classifier_titles, story, folder_feed_ids=folder_feed_ids)
            if user_is_pro
            else 0
        ),
        "text": apply_classifier_texts(classifier_texts, story, folder_feed_ids=folder_feed_ids),
        "text_regex": (
            apply_classifier_text_regex(classifier_texts, story, folder_feed_ids=folder_feed_ids)
            if user_is_pro
            else 0
        ),
        "url": apply_classifier_urls(
            classifier_urls, story, user_is_premium=user_is_premium, folder_feed_ids=folder_feed_ids
        ),
        "url_regex": (
            apply_classifier_url_regex(classifier_urls, story, folder_feed_ids=folder_feed_ids)
            if user_is_pro
            else 0
        ),
    }

    # Include AI prompt classifier score if provided
    if prompt_score is not None:
        intelligence["prompt"] = prompt_score

    score = 0

    # If we have a prompt score, it takes priority
    if "prompt" in intelligence and intelligence["prompt"] != 0:
        return intelligence["prompt"]

    # Otherwise use the traditional classifier logic
    score_max = max(
        intelligence["title"],
        intelligence["title_regex"],
        intelligence["author"],
        intelligence["tags"],
        intelligence["text"],
        intelligence["text_regex"],
        intelligence["url"],
        intelligence["url_regex"],
    )
    score_min = min(
        intelligence["title"],
        intelligence["title_regex"],
        intelligence["author"],
        intelligence["tags"],
        intelligence["text"],
        intelligence["text_regex"],
        intelligence["url"],
        intelligence["url_regex"],
    )
    if score_max > 0:
        score = score_max
    elif score_min < 0:
        score = score_min

    if score == 0:
        score = intelligence["feed"]

    return score


def apply_classifier_titles(classifiers, story, folder_feed_ids=None):
    """
    Apply title classifiers to a story (non-regex only).

    Args:
        classifiers: List of MClassifierTitle objects
        story: Story dict with 'story_feed_id' and 'story_title'
        folder_feed_ids: Dict mapping folder_name -> set of feed_ids for folder-scoped classifiers

    Returns:
        Score (1 for like, -1 for dislike, 0 for neutral)
    """
    score = 0
    story_title = story.get("story_title", "")
    if not story_title:
        return score

    story_title_lower = story_title.lower()

    for classifier in classifiers:
        if not classifier_matches_story_feed(classifier, story["story_feed_id"], folder_feed_ids):
            continue

        # Skip regex classifiers - they're handled by apply_classifier_regex
        if getattr(classifier, "is_regex", False):
            continue

        # Standard substring matching (case-insensitive)
        if classifier.title.lower() in story_title_lower:
            score = classifier.score
            if score > 0:
                return score

    return score


def apply_classifier_texts(classifiers, story, folder_feed_ids=None):
    """
    Apply text classifiers to a story (non-regex only).

    Args:
        classifiers: List of MClassifierText objects
        story: Story dict with 'story_feed_id' and 'story_content'
        folder_feed_ids: Dict mapping folder_name -> set of feed_ids for folder-scoped classifiers

    Returns:
        Score (1 for like, -1 for dislike, 0 for neutral)
    """
    score = 0
    story_content = story.get("story_content", "")
    if not story_content:
        return score

    story_content_lower = story_content.lower()

    for classifier in classifiers:
        if not classifier_matches_story_feed(classifier, story["story_feed_id"], folder_feed_ids):
            continue

        # Skip regex classifiers - they're handled by apply_classifier_regex
        if getattr(classifier, "is_regex", False):
            continue

        # Standard substring matching (case-insensitive)
        if classifier.text.lower() in story_content_lower:
            score = classifier.score
            if score > 0:
                return score

    return score


def apply_classifier_title_regex(classifiers, story, folder_feed_ids=None):
    """
    Apply title regex classifiers to a story. Matches title only.

    Args:
        classifiers: List of MClassifierTitle objects with is_regex=True
        story: Story dict with 'story_feed_id' and 'story_title'
        folder_feed_ids: Dict mapping folder_name -> set of feed_ids for folder-scoped classifiers

    Returns:
        Score (1 for like, -1 for dislike, 0 for neutral)
    """
    score = 0
    story_title = story.get("story_title", "")
    if not story_title:
        return score

    for classifier in classifiers:
        if not classifier_matches_story_feed(classifier, story["story_feed_id"], folder_feed_ids):
            continue

        if not getattr(classifier, "is_regex", False):
            continue

        if safe_regex_match(classifier.title, story_title):
            score = classifier.score
            if score > 0:
                return score

    return score


def apply_classifier_text_regex(classifiers, story, folder_feed_ids=None):
    """
    Apply text regex classifiers to a story. Matches content only.

    Args:
        classifiers: List of MClassifierText objects with is_regex=True
        story: Story dict with 'story_feed_id' and 'story_content'
        folder_feed_ids: Dict mapping folder_name -> set of feed_ids for folder-scoped classifiers

    Returns:
        Score (1 for like, -1 for dislike, 0 for neutral)
    """
    score = 0
    story_content = story.get("story_content", "")
    if not story_content:
        return score

    for classifier in classifiers:
        if not classifier_matches_story_feed(classifier, story["story_feed_id"], folder_feed_ids):
            continue

        if not getattr(classifier, "is_regex", False):
            continue

        if safe_regex_match(classifier.text, story_content):
            score = classifier.score
            if score > 0:
                return score

    return score


def apply_classifier_urls(classifiers, story, user_is_premium=False, folder_feed_ids=None):
    """
    Apply URL classifiers to a story (non-regex only).

    Args:
        classifiers: List of MClassifierUrl objects
        story: Story dict with 'story_feed_id' and 'story_permalink'
        user_is_premium: Whether the user has Premium subscription (required for URL filters)
        folder_feed_ids: Dict mapping folder_name -> set of feed_ids for folder-scoped classifiers

    Returns:
        Score (1 for like, -1 for dislike, 0 for neutral)
    """
    if not user_is_premium:
        return 0

    score = 0
    story_url = story.get("story_permalink", "")
    if not story_url:
        return score

    story_url_lower = story_url.lower()

    for classifier in classifiers:
        if not classifier_matches_story_feed(classifier, story["story_feed_id"], folder_feed_ids):
            continue

        # Skip regex classifiers - they're handled by apply_classifier_url_regex
        if getattr(classifier, "is_regex", False):
            continue

        # Standard substring matching (case-insensitive)
        if classifier.url.lower() in story_url_lower:
            score = classifier.score
            if score > 0:
                return score

    return score


def apply_classifier_url_regex(classifiers, story, folder_feed_ids=None):
    """
    Apply URL regex classifiers to a story. Matches permalink URL only.

    Args:
        classifiers: List of MClassifierUrl objects with is_regex=True
        story: Story dict with 'story_feed_id' and 'story_permalink'
        folder_feed_ids: Dict mapping folder_name -> set of feed_ids for folder-scoped classifiers

    Returns:
        Score (1 for like, -1 for dislike, 0 for neutral)
    """
    score = 0
    story_url = story.get("story_permalink", "")
    if not story_url:
        return score

    for classifier in classifiers:
        if not classifier_matches_story_feed(classifier, story["story_feed_id"], folder_feed_ids):
            continue

        if not getattr(classifier, "is_regex", False):
            continue

        if safe_regex_match(classifier.url, story_url):
            score = classifier.score
            if score > 0:
                return score

    return score


def apply_classifier_authors(classifiers, story, folder_feed_ids=None):
    score = 0
    for classifier in classifiers:
        if not classifier_matches_story_feed(classifier, story["story_feed_id"], folder_feed_ids):
            continue
        if story.get("story_authors") and classifier.author == story.get("story_authors"):
            # print 'Authors: %s -- %s' % (classifier.author, story['story_authors'])
            score = classifier.score
            if score > 0:
                return classifier.score
    return score


def apply_classifier_tags(classifiers, story, folder_feed_ids=None):
    score = 0
    for classifier in classifiers:
        if not classifier_matches_story_feed(classifier, story["story_feed_id"], folder_feed_ids):
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


SCOPED_CLASSIFIER_CLASSES = [
    MClassifierTitle,
    MClassifierText,
    MClassifierUrl,
    MClassifierAuthor,
    MClassifierTag,
]


def load_scoped_classifiers(user_id):
    """Load all global and folder-scoped classifiers for a user.

    Returns a dict with keys: 'titles', 'texts', 'urls', 'authors', 'tags'
    each containing a list of classifier objects with scope != 'feed'.
    """
    result = {
        "titles": [],
        "texts": [],
        "urls": [],
        "authors": [],
        "tags": [],
    }
    key_map = {
        MClassifierTitle: "titles",
        MClassifierText: "texts",
        MClassifierUrl: "urls",
        MClassifierAuthor: "authors",
        MClassifierTag: "tags",
    }
    for Cls in SCOPED_CLASSIFIER_CLASSES:
        classifiers = list(Cls.objects(user_id=user_id, scope__in=["folder", "global"]))
        result[key_map[Cls]] = classifiers
    return result


def get_classifiers_for_user(
    user,
    feed_id=None,
    social_user_id=None,
    classifier_feeds=None,
    classifier_authors=None,
    classifier_titles=None,
    classifier_tags=None,
    classifier_texts=None,
    classifier_urls=None,
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
    if classifier_urls is None:
        classifier_urls = list(MClassifierUrl.objects(**params))
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

    # Build titles dict - only non-regex patterns
    titles_dict = {}
    title_regex_dict = {}
    for t in classifier_titles:
        if getattr(t, "is_regex", False):
            title_regex_dict[t.title] = t.score
        else:
            titles_dict[t.title] = t.score

    # Build texts dict - only non-regex patterns
    texts_dict = {}
    text_regex_dict = {}
    for t in classifier_texts:
        if getattr(t, "is_regex", False):
            text_regex_dict[t.text] = t.score
        else:
            texts_dict[t.text] = t.score

    # Build urls dict - only non-regex patterns
    urls_dict = {}
    url_regex_dict = {}
    for u in classifier_urls:
        if getattr(u, "is_regex", False):
            url_regex_dict[u.url] = u.score
        else:
            urls_dict[u.url] = u.score

    # Build scope metadata for UI display
    def _scope_info(classifier):
        scope = getattr(classifier, "scope", "feed")
        if scope == "feed":
            return None
        return {"scope": scope, "folder_name": getattr(classifier, "folder_name", "")}

    titles_scope = {}
    for t in classifier_titles:
        info = _scope_info(t)
        if info:
            titles_scope[t.title] = info
    texts_scope = {}
    for t in classifier_texts:
        info = _scope_info(t)
        if info:
            texts_scope[t.text] = info
    urls_scope = {}
    for u in classifier_urls:
        info = _scope_info(u)
        if info:
            urls_scope[u.url] = info
    authors_scope = {}
    for a in classifier_authors:
        info = _scope_info(a)
        if info:
            authors_scope[a.author] = info
    tags_scope = {}
    for t in classifier_tags:
        info = _scope_info(t)
        if info:
            tags_scope[t.tag] = info

    payload = {
        "feeds": dict(feeds),
        "authors": dict([(a.author, a.score) for a in classifier_authors]),
        "titles": titles_dict,
        "title_regex": title_regex_dict,
        "tags": dict([(t.tag, t.score) for t in classifier_tags]),
        "texts": texts_dict,
        "text_regex": text_regex_dict,
        "urls": urls_dict,
        "url_regex": url_regex_dict,
        "titles_scope": titles_scope,
        "texts_scope": texts_scope,
        "urls_scope": urls_scope,
        "authors_scope": authors_scope,
        "tags_scope": tags_scope,
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
    classifier_urls=None,
    folder_feed_ids=None,
):
    def sort_by_feed(classifiers):
        """Sort classifiers by feed_id, distributing global/folder classifiers to all relevant feeds."""
        feed_classifiers = defaultdict(list)
        if classifiers:
            for classifier in classifiers:
                scope = getattr(classifier, "scope", "feed")
                if scope == "global":
                    # Global classifiers apply to all feed_ids
                    for fid in feed_ids or []:
                        feed_classifiers[fid].append(classifier)
                elif scope == "folder" and folder_feed_ids:
                    # Folder classifiers apply to feeds in their folder
                    folder = getattr(classifier, "folder_name", "")
                    for fid in folder_feed_ids.get(folder, set()):
                        if feed_ids is None or fid in feed_ids:
                            feed_classifiers[fid].append(classifier)
                else:
                    feed_classifiers[classifier.feed_id].append(classifier)
        return feed_classifiers

    classifiers = {}

    if feed_ids:
        classifier_feeds = sort_by_feed(classifier_feeds)
        classifier_authors = sort_by_feed(classifier_authors)
        classifier_titles = sort_by_feed(classifier_titles)
        classifier_tags = sort_by_feed(classifier_tags)
        classifier_texts = sort_by_feed(classifier_texts)
        classifier_urls = sort_by_feed(classifier_urls)

        for feed_id in feed_ids:
            classifiers[feed_id] = get_classifiers_for_user(
                user,
                feed_id=feed_id,
                classifier_feeds=classifier_feeds[feed_id],
                classifier_authors=classifier_authors[feed_id],
                classifier_titles=classifier_titles[feed_id],
                classifier_tags=classifier_tags[feed_id],
                classifier_texts=classifier_texts[feed_id],
                classifier_urls=classifier_urls[feed_id],
            )

    return classifiers
