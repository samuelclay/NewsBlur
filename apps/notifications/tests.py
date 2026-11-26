import datetime
from unittest.mock import MagicMock, patch

import redis
import requests
from django.conf import settings
from django.contrib.auth.models import User
from django.core import mail
from django.test import TestCase
from django.test.utils import override_settings
from google.auth import exceptions as google_auth_exceptions
from pymongo.collection import Collection

from apps.analyzer.models import MClassifierPrompt
from apps.notifications import models as notification_models
from apps.notifications.models import MUserAndroidTokens, MUserClassifierNotification, MUserFeedNotification
from apps.reader.models import UserSubscription, UserSubscriptionFolders
from apps.rss_feeds.models import Feed, MStory
from utils import json_functions as json

# apps/notifications/tests.py: stands in for the Firebase service account key that models.py reads from
# settings.FCM_SERVICE_ACCOUNT_INFO. The private key is fake, so no real credentials can be built from it.
FCM_TEST_SERVICE_ACCOUNT = {
    "project_id": "newsblur-fcm-test",
    "client_email": "fcm-test@newsblur-fcm-test.iam.gserviceaccount.com",
    "token_uri": "https://oauth2.googleapis.com/token",
    "private_key": "not a real key",
}
FCM_TEST_SEND_URL = "https://fcm.googleapis.com/v1/projects/newsblur-fcm-test/messages:send"


class FakeNotificationRedis:
    def __init__(self):
        self.store = {}

    def setex(self, key, ttl, value):
        self.store[key] = value
        return True

    def set(self, key, value, ex=None, nx=False):
        if nx and key in self.store:
            return False
        self.store[key] = value
        return True

    def exists(self, key):
        return key in self.store


def fcm_response(status_code, body):
    """apps/notifications/tests.py: a real requests.Response, so models.py parses it the way it parses FCM's."""
    response = requests.Response()
    response.status_code = status_code
    response._content = body if isinstance(body, bytes) else json.encode(body).encode("utf-8")
    return response


def fcm_error(status_code, status, fcm_error_code=None):
    """apps/notifications/tests.py: the error body FCM HTTP v1 answers with. The top-level status is the
    generic Google API one (NOT_FOUND), and FCM's own code (UNREGISTERED) sits in an FcmError detail."""
    error = {"code": status_code, "message": "FCM said no.", "status": status}
    if fcm_error_code:
        error["details"] = [
            {"@type": "type.googleapis.com/google.firebase.fcm.v1.FcmError", "errorCode": fcm_error_code}
        ]
    return fcm_response(status_code, {"error": error})


class FakeFCMSession:
    """apps/notifications/tests.py: stands in for the AuthorizedSession that send_android in models.py posts
    through, so no test contacts Google. Answers 200 unless a token has its own outcome, and raises the
    outcome when it is an exception."""

    def __init__(self, outcomes=None, on_send=None):
        self.requests = []
        self.outcomes = outcomes or {}
        self.on_send = on_send

    def post(self, url, json=None, timeout=None, **kwargs):
        self.requests.append({"url": url, "json": json, "timeout": timeout})
        token = json["message"]["token"]
        if self.on_send:
            self.on_send(token)
        outcome = self.outcomes.get(
            token, fcm_response(200, {"name": "projects/newsblur-fcm-test/messages/1"})
        )
        if isinstance(outcome, Exception):
            raise outcome
        return outcome

    def sent_tokens(self):
        return [request["json"]["message"]["token"] for request in self.requests]


class Test_EmailNotifications(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="notifytest",
            password="testpass",
            email="notify@example.com",
        )

    def make_feed(self, feed_address, feed_title):
        return Feed.objects.create(
            feed_address=feed_address,
            feed_link="https://example.com",
            feed_title=feed_title,
            fetched_once=True,
            known_good=True,
        )

    def send_email_subject(self, feed, story_title):
        usersub = UserSubscription.objects.create(user=self.user, feed=feed, active=True)
        notification = MUserFeedNotification(user_id=self.user.pk, feed_id=feed.pk, is_email=True)
        story = {
            "story_title": story_title,
            "story_content": "<p>Summary</p>",
        }

        with patch("apps.notifications.models.redis.Redis") as mock_redis_cls, patch(
            "apps.notifications.models.render_to_string", return_value=""
        ), patch("apps.notifications.models.Site.objects.get_current") as mock_get_current, patch(
            "apps.notifications.models.EmailMultiAlternatives"
        ) as mock_email_cls:
            mock_redis = mock_redis_cls.return_value
            mock_redis.hget.return_value = 1
            mock_get_current.return_value.domain = "newsblur.com"

            notification.send_email(story, usersub)

        return mock_email_cls.call_args[0][0]

    def test_story_notification_subject_includes_feed_title(self):
        feed = self.make_feed("https://example.com/feed.xml", "Example Feed")

        subject = self.send_email_subject(feed, "A Regular Story")

        self.assertEqual(subject, "Example Feed: A Regular Story")

    def test_daily_briefing_email_subject_uses_story_title_without_feed_prefix(self):
        feed = self.make_feed("daily-briefing:%s" % self.user.pk, "Daily Briefing")

        subject = self.send_email_subject(feed, "Morning Daily Briefing - May 8, 2026")

        self.assertEqual(subject, "Morning Daily Briefing - May 8, 2026")

    def test_prompt_classifier_notification_matches_on_ai_score(self):
        """Natural Language classifier notifications fire off cached AI scores."""
        feed = self.make_feed("https://example.com/ai.xml", "AI Feed")
        notif = MUserClassifierNotification(
            user_id=self.user.pk,
            classifier_type="prompt",
            classifier_value="AI and machine learning",
            scope="feed",
            feed_id=feed.pk,
            is_email=True,
        )
        story = {"story_hash": "%s:abc123" % feed.pk, "story_feed_id": feed.pk}

        # AI scored the story as a match (1) for this prompt -> notify
        self.assertTrue(
            notif.matches_story(story, feed.pk, prompt_scores={notif.pk: {story["story_hash"]: 1}})
        )
        # AI scored it neutral (0) -> no match
        self.assertFalse(
            notif.matches_story(story, feed.pk, prompt_scores={notif.pk: {story["story_hash"]: 0}})
        )
        # No cached AI score at all -> no match
        self.assertFalse(notif.matches_story(story, feed.pk, prompt_scores={}))
        # A match in a different feed must not fire a feed-scoped notification
        self.assertFalse(
            notif.matches_story(story, feed.pk + 1, prompt_scores={notif.pk: {story["story_hash"]: 1}})
        )

    def test_image_prompt_classifier_notification_matches_on_ai_score(self):
        """Image classifier notifications match the same way as text prompts."""
        feed = self.make_feed("https://example.com/img.xml", "Image Feed")
        notif = MUserClassifierNotification(
            user_id=self.user.pk,
            classifier_type="image_prompt",
            classifier_value="charts and graphs",
            scope="feed",
            feed_id=feed.pk,
            is_ios=True,
        )
        story = {"story_hash": "%s:def456" % feed.pk, "story_feed_id": feed.pk}

        self.assertTrue(
            notif.matches_story(story, feed.pk, prompt_scores={notif.pk: {story["story_hash"]: 1}})
        )
        self.assertFalse(notif.matches_story(story, feed.pk, prompt_scores={}))

    def test_prompt_notification_applies_to_feed_scope(self):
        """A folder-scoped prompt notification only covers feeds inside its folder."""
        in_folder = self.make_feed("https://example.com/in.xml", "In Folder")
        out_folder = self.make_feed("https://example.com/out.xml", "Out of Folder")
        notif = MUserClassifierNotification(
            user_id=self.user.pk,
            classifier_type="prompt",
            classifier_value="space exploration",
            scope="folder",
            folder_name="Science",
            is_email=True,
        )
        folder_feed_ids = {"Science": {in_folder.pk}}

        # Folder scope covers a feed inside the folder, not one outside it.
        # The matcher relies on this so it never warms billable AI scoring for
        # feeds a folder-scoped prompt notification can never fire on.
        self.assertTrue(notif.applies_to_feed(in_folder.pk, folder_feed_ids))
        self.assertFalse(notif.applies_to_feed(out_folder.pk, folder_feed_ids))
        # Folder scope with no folder map resolves to no coverage
        self.assertFalse(notif.applies_to_feed(in_folder.pk, None))

        # Global scope covers any feed
        notif.scope = "global"
        self.assertTrue(notif.applies_to_feed(out_folder.pk, None))

    def test_feed_notification_does_not_send_email_after_classifier_email(self):
        feed = self.make_feed("https://example.com/dedupe.xml", "Dedupe Feed")
        usersub = UserSubscription.objects.create(user=self.user, feed=feed, active=True)
        notification = MUserFeedNotification(user_id=self.user.pk, feed_id=feed.pk, is_email=True)
        story = {
            "story_title": "Duplicate Alert",
            "story_hash": "dedupe:%s:1" % feed.pk,
            "story_feed_id": feed.pk,
            "story_content": "<p>Summary</p>",
            "story_tags": [],
        }
        fake_redis = FakeNotificationRedis()

        with patch("apps.notifications.models.redis.Redis", return_value=fake_redis):
            MUserClassifierNotification.mark_story_sent(self.user.pk, story["story_hash"], is_email=True)

            with patch.object(MUserFeedNotification, "send_email") as mock_send_email:
                sent = notification.push_story_notification(story, {}, usersub)

        self.assertFalse(sent)
        mock_send_email.assert_not_called()


class Test_PromptNotificationFolderScope(TestCase):
    """apps/notifications/tests.py: push_classifier_notifications warms prompt scores with
    MClassifierPrompt.classify_stories. A prompt scoped to a folder must not run or bill
    there for a site outside that folder, even when another prompt notification does
    apply to the site."""

    def setUp(self):
        self.user = User.objects.create_user(
            username="notifyfolder", password="testpass", email="notifyfolder@example.com"
        )
        self.user.profile.is_archive = True
        self.user.profile.is_usage_billing = True
        self.user.profile.last_seen_on = datetime.datetime.now()
        self.user.profile.save()
        self.feed = Feed.objects.create(
            feed_address="https://example.com/robots.xml",
            feed_link="https://example.com",
            feed_title="Robots Weekly",
            fetched_once=True,
            known_good=True,
        )
        self.science_feed = Feed.objects.create(
            feed_address="https://example.com/science.xml",
            feed_link="https://example.com",
            feed_title="Science Daily",
            fetched_once=True,
            known_good=True,
        )
        UserSubscription.objects.create(user=self.user, feed=self.feed, active=True)
        UserSubscription.objects.create(user=self.user, feed=self.science_feed, active=True)
        UserSubscriptionFolders.objects.create(
            user=self.user, folders=json.encode([{"Science": [self.science_feed.pk]}, self.feed.pk])
        )

        self.global_prompt = MClassifierPrompt.objects.create(
            user_id=self.user.pk, feed_id=0, folder_id="", prompt="robots", classifier_type="focus"
        )
        self.science_prompt = MClassifierPrompt.objects.create(
            user_id=self.user.pk, feed_id=0, folder_id="Science", prompt="space", classifier_type="focus"
        )
        self.notification = MUserClassifierNotification.objects.create(
            user_id=self.user.pk,
            classifier_type="prompt",
            classifier_value="robots",
            scope="global",
            is_email=True,
        )

        self.story = MStory(
            story_feed_id=self.feed.pk,
            story_date=datetime.datetime.now(),
            story_title="A robot lands on the moon",
            story_content="Robots in space.",
            story_guid="notifyfolder-robot-moon",
            story_permalink="https://example.com/robot-moon",
        )
        self.story.save()
        # The test Redis may hold another test's stories for this feed id, so the new
        # story must be the only one push_classifier_notifications finds in zF.
        self.r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
        self.r.delete("zF:%s" % self.feed.pk)
        self.r.zadd("zF:%s" % self.feed.pk, {self.story.story_hash: 1})

    def tearDown(self):
        self.r.delete("zF:%s" % self.feed.pk)
        self.story.delete()
        for prompt in (self.global_prompt, self.science_prompt):
            MClassifierPrompt.invalidate_cache(
                self.user.pk, str(prompt.id), feed_ids=[self.feed.pk, self.science_feed.pk]
            )
        MClassifierPrompt.objects(user_id=self.user.pk).delete()
        MUserClassifierNotification.objects(user_id=self.user.pk).delete()

    def test_folder_prompt_is_not_warmed_for_a_feed_outside_its_folder(self):
        block = MagicMock()
        block.type = "tool_use"
        block.name = "classify_stories"
        block.input = {"classifications": [{"id": self.story.story_hash, "classification": 1}]}

        with patch("apps.ask_ai.providers.AnthropicProvider.is_configured", return_value=True), patch(
            "utils.ai_functions.anthropic.Anthropic"
        ) as MockAnthropic, patch(
            "utils.ai_functions.LLMCostTracker.record_usage"
        ) as record_usage, patch.object(
            MUserClassifierNotification,
            "claim_story_channels",
            return_value={"email": False, "web": False, "ios": False, "android": False},
        ) as claim:
            create = MockAnthropic.return_value.messages.create
            create.return_value.content = [block]
            MUserClassifierNotification.push_classifier_notifications(self.feed.pk, 1)

        asked = [call.kwargs["system"] for call in create.call_args_list]
        self.assertEqual(len(asked), 1, "Only the global prompt applies to Robots Weekly")
        self.assertIn("robots", asked[0])
        self.assertNotIn("space", asked[0])
        self.assertEqual(record_usage.call_count, 1)
        # The global prompt's verdict still drives the notification.
        claim.assert_called_once()


class Test_AndroidTokenEndpoint(TestCase):
    """apps/notifications/tests.py: the Android app registers its FCM token at /notifications/android_token/
    (set_android_token in views.py), on every launch and from every device the user owns."""

    def setUp(self):
        self.user = User.objects.create_user(
            username="androidtoken", password="testpass", email="androidtoken@example.com"
        )
        self.client.force_login(self.user)

    def tearDown(self):
        MUserAndroidTokens.objects(user_id=self.user.pk).delete()

    def register(self, **params):
        response = self.client.post("/notifications/android_token/", params)
        self.assertEqual(response.status_code, 200)
        return json.decode(response.content)

    def saved_tokens(self):
        tokens = MUserAndroidTokens.objects(user_id=self.user.pk).first()
        return list(tokens.android_tokens) if tokens else []

    def test_token_is_stored_once_per_device(self):
        self.register(token="token-pixel")
        self.register(token="token-pixel")
        self.assertEqual(self.saved_tokens(), ["token-pixel"])

        self.register(token="token-tablet")
        self.assertEqual(self.saved_tokens(), ["token-pixel", "token-tablet"])

    def test_only_the_newest_tokens_are_kept(self):
        limit = MUserAndroidTokens.MAX_TOKENS_PER_USER
        for number in range(limit + 1):
            self.register(token="token-%s" % number)

        # tests.py: send_android posts to every token, so the oldest registration makes room for the newest.
        self.assertEqual(self.saved_tokens(), ["token-%s" % number for number in range(1, limit + 1)])

    def test_device_that_keeps_checking_in_outlives_the_cap(self):
        limit = MUserAndroidTokens.MAX_TOKENS_PER_USER
        for number in range(limit):
            self.register(token="token-%s" % number)

        # tests.py: the app sends its token again every day, so the first phone is still in use.
        self.register(token="token-0")
        self.register(token="token-new")

        self.assertIn("token-0", self.saved_tokens())
        self.assertNotIn("token-1", self.saved_tokens())
        self.assertEqual(len(self.saved_tokens()), limit)

    def test_refreshing_a_token_keeps_a_registration_that_lands_meanwhile(self):
        # tests.py: a second token is saved after the first, so sending the first again has to move it.
        self.register(token="token-pixel")
        self.register(token="token-watch")
        update_one = Collection.update_one
        interleaved = []

        def update_one_after_another_device(collection, *args, **kwargs):
            # tests.py: a second device's registration lands just before this request's first write.
            if collection.name == MUserAndroidTokens._get_collection_name() and not interleaved:
                interleaved.append(True)
                update_one(
                    collection, {"user_id": self.user.pk}, {"$push": {"android_tokens": "token-tablet"}}
                )
            return update_one(collection, *args, **kwargs)

        with patch.object(Collection, "update_one", update_one_after_another_device):
            self.register(token="token-pixel")

        self.assertEqual(self.saved_tokens(), ["token-watch", "token-tablet", "token-pixel"])

    def test_overlapping_registrations_of_one_token_store_it_once(self):
        self.register(token="token-pixel")
        self.register(token="token-tablet")
        update_one = Collection.update_one
        overlapping = []

        def update_one_while_the_same_token_registers(collection, *args, **kwargs):
            # tests.py: the app can send its token from two places at once. Here the other request runs in full
            # just before each write of this one.
            if collection.name == MUserAndroidTokens._get_collection_name() and not overlapping:
                overlapping.append(True)
                MUserAndroidTokens.register_token(self.user.pk, "token-pixel")
                overlapping.pop()
            return update_one(collection, *args, **kwargs)

        with patch.object(Collection, "update_one", update_one_while_the_same_token_registers):
            self.register(token="token-pixel")

        self.assertEqual(self.saved_tokens(), ["token-tablet", "token-pixel"])

    def test_two_first_registrations_at_once_are_both_kept(self):
        insert_one = Collection.insert_one
        raced = []

        def insert_one_after_another_device(collection, document, *args, **kwargs):
            # tests.py: a second device creates the user's token document a moment before this request does.
            if collection.name == MUserAndroidTokens._get_collection_name() and not raced:
                raced.append(True)
                insert_one(collection, {"user_id": self.user.pk, "android_tokens": ["token-tablet"]})
            return insert_one(collection, document, *args, **kwargs)

        with patch.object(Collection, "insert_one", insert_one_after_another_device):
            self.register(token="token-pixel")

        self.assertEqual(self.saved_tokens(), ["token-tablet", "token-pixel"])

    def test_missing_token_is_refused_without_a_server_error(self):
        self.assertEqual(self.register()["code"], -1)
        self.assertEqual(self.register(token="")["code"], -1)
        self.assertEqual(self.saved_tokens(), [])


class Test_AndroidNotifications(TestCase):
    """apps/notifications/tests.py: send_android in models.py pushes a story to each of the user's Android
    devices through Firebase Cloud Messaging. Every test swaps the FCM session for FakeFCMSession."""

    def setUp(self):
        self.user = User.objects.create_user(
            username="androidpush", password="testpass", email="androidpush@example.com"
        )
        self.feed = Feed.objects.create(
            feed_address="https://example.com/android.xml",
            feed_link="https://example.com",
            feed_title="Android Feed",
            fetched_once=True,
            known_good=True,
        )
        self.usersub = UserSubscription.objects.create(user=self.user, feed=self.feed, active=True)
        MUserAndroidTokens.objects.create(
            user_id=self.user.pk, android_tokens=["token-pixel", "token-tablet"]
        )
        self.notification = MUserFeedNotification(user_id=self.user.pk, feed_id=self.feed.pk, is_android=True)
        self.story = {
            "story_title": "A robot lands on the moon",
            "story_hash": "%s:a1b2c3" % self.feed.pk,
            "story_feed_id": self.feed.pk,
            "story_content": "<p>Robots in space.</p>",
            "story_tags": [],
        }

    def tearDown(self):
        MUserAndroidTokens.objects(user_id=self.user.pk).delete()

    def push(self, session, service_account_info=FCM_TEST_SERVICE_ACCOUNT):
        with override_settings(FCM_SERVICE_ACCOUNT_INFO=service_account_info), patch(
            "apps.notifications.models.fcm_session", return_value=session
        ) as build_session:
            self.notification.send_android(self.story, self.user)
        return build_session

    def saved_tokens(self):
        return list(MUserAndroidTokens.objects.get(user_id=self.user.pk).android_tokens)

    def test_each_device_gets_one_data_only_high_priority_message(self):
        session = FakeFCMSession()

        self.push(session)

        self.assertEqual(session.sent_tokens(), ["token-pixel", "token-tablet"])
        for request in session.requests:
            self.assertEqual(request["url"], FCM_TEST_SEND_URL)
            message = request["json"]["message"]
            # tests.py: FCM rejects a message whose data values are not strings, so models.py has to send
            # the feed and user ids as text.
            self.assertEqual(
                message["data"],
                {
                    "story_hash": self.story["story_hash"],
                    "story_feed_id": str(self.feed.pk),
                    "user_id": str(self.user.pk),
                },
            )
            # tests.py: the Android app draws the notification itself, so models.py must not ask FCM to.
            self.assertNotIn("notification", message)
            self.assertNotIn("notification", message["android"])
            self.assertEqual(message["android"]["priority"], "HIGH")
            self.assertTrue(request["timeout"], "A push without a timeout can hang the notification task")

    def test_token_from_another_sender_is_removed(self):
        session = FakeFCMSession({"token-tablet": fcm_error(403, "PERMISSION_DENIED", "SENDER_ID_MISMATCH")})

        self.push(session)

        self.assertEqual(self.saved_tokens(), ["token-pixel"])

    def test_tokens_survive_every_failure_that_is_not_a_dead_token(self):
        failures = {
            # tests.py: a payload bug in models.py would get INVALID_ARGUMENT for every user, so pruning on
            # it would wipe everyone's tokens.
            "malformed request": fcm_error(400, "INVALID_ARGUMENT", "INVALID_ARGUMENT"),
            "not found without an FCM code": fcm_error(404, "NOT_FOUND"),
            "sender not allowed": fcm_error(403, "PERMISSION_DENIED"),
            "throttled": fcm_error(429, "RESOURCE_EXHAUSTED", "QUOTA_EXCEEDED"),
            "FCM internal error": fcm_error(500, "INTERNAL", "INTERNAL"),
            "FCM overloaded": fcm_error(503, "UNAVAILABLE", "UNAVAILABLE"),
            "gateway error page": fcm_response(502, b"<html>Bad Gateway</html>"),
            "timeout": requests.exceptions.Timeout("FCM did not answer"),
            "connection dropped": requests.exceptions.ConnectionError("connection reset"),
            "OAuth token refused": google_auth_exceptions.RefreshError("invalid_grant"),
            "OAuth endpoint unreachable": google_auth_exceptions.TransportError("unreachable"),
        }
        for name, failure in failures.items():
            with self.subTest(name):
                # tests.py: each case starts from both tokens, so a token pruned by mistake fails only its
                # own case.
                MUserAndroidTokens.objects(user_id=self.user.pk).update(
                    set__android_tokens=["token-pixel", "token-tablet"]
                )
                session = FakeFCMSession({"token-pixel": failure})

                self.push(session)

                self.assertEqual(self.saved_tokens(), ["token-pixel", "token-tablet"])
                # tests.py: one device's failure must not cost the user's other device its push.
                self.assertEqual(session.sent_tokens(), ["token-pixel", "token-tablet"])

    def test_token_registered_during_a_push_survives_the_pruning_of_a_dead_one(self):
        self.client.force_login(self.user)

        def register_new_phone(token):
            if token == "token-pixel":
                self.client.post("/notifications/android_token/", {"token": "token-new-phone"})

        session = FakeFCMSession(
            {"token-pixel": fcm_error(404, "NOT_FOUND", "UNREGISTERED")}, on_send=register_new_phone
        )

        self.push(session)

        self.assertEqual(self.saved_tokens(), ["token-tablet", "token-new-phone"])

    def test_nothing_is_sent_until_fcm_credentials_are_configured(self):
        session = FakeFCMSession()

        build_session = self.push(session, service_account_info=None)

        self.assertEqual(session.requests, [])
        build_session.assert_not_called()

    def test_nothing_is_sent_to_a_user_without_android_tokens(self):
        MUserAndroidTokens.objects(user_id=self.user.pk).delete()
        session = FakeFCMSession()

        build_session = self.push(session)

        self.assertEqual(session.requests, [])
        build_session.assert_not_called()

    def test_nothing_is_sent_when_the_android_channel_is_off(self):
        self.notification.is_android = False
        session = FakeFCMSession()

        self.push(session)

        self.assertEqual(session.requests, [])

    def test_unreadable_service_account_key_does_not_raise(self):
        notification_models.fcm_session.cache_clear()
        self.addCleanup(notification_models.fcm_session.cache_clear)
        session = FakeFCMSession()

        # tests.py: FCM_TEST_SERVICE_ACCOUNT's private key is not a key, so google-auth refuses to build
        # credentials from it when models.py asks for the session.
        with override_settings(FCM_SERVICE_ACCOUNT_INFO=FCM_TEST_SERVICE_ACCOUNT), patch(
            "apps.notifications.models.AuthorizedSession", return_value=session
        ):
            self.notification.send_android(self.story, self.user)

        self.assertEqual(session.requests, [])
        self.assertEqual(self.saved_tokens(), ["token-pixel", "token-tablet"])

    def test_one_fcm_session_serves_every_push(self):
        notification_models.fcm_session.cache_clear()
        self.addCleanup(notification_models.fcm_session.cache_clear)
        session = FakeFCMSession()

        with override_settings(FCM_SERVICE_ACCOUNT_INFO=FCM_TEST_SERVICE_ACCOUNT), patch(
            "apps.notifications.models.service_account.Credentials.from_service_account_info"
        ), patch("apps.notifications.models.AuthorizedSession", return_value=session) as build_session:
            self.notification.send_android(self.story, self.user)
            self.notification.send_android(self.story, self.user)

        # tests.py: a session per push would fetch a new OAuth token from Google for every notification.
        self.assertEqual(build_session.call_count, 1)
        self.assertEqual(len(session.requests), 4)

    def test_failed_android_push_does_not_stop_the_email(self):
        self.notification.is_email = True
        session = FakeFCMSession(
            {
                "token-pixel": requests.exceptions.ConnectionError("connection reset"),
                "token-tablet": fcm_error(500, "INTERNAL", "INTERNAL"),
            }
        )

        with override_settings(FCM_SERVICE_ACCOUNT_INFO=FCM_TEST_SERVICE_ACCOUNT), patch(
            "apps.notifications.models.fcm_session", return_value=session
        ), patch("apps.notifications.models.redis.Redis") as mock_redis_cls:
            mock_redis_cls.return_value.hget.return_value = 1
            sent = self.notification.push_story_notification(self.story, {}, self.usersub)

        self.assertTrue(sent)
        self.assertEqual(session.sent_tokens(), ["token-pixel", "token-tablet"])
        self.assertEqual(len(mail.outbox), 1)
        self.assertIn("A robot lands on the moon", mail.outbox[0].subject)


class Test_AndroidClassifierNotifications(TestCase):
    """apps/notifications/tests.py: push_classifier_notifications in models.py sends through a transient
    MUserFeedNotification, so a classifier match has to reach the user's Android devices as well."""

    def setUp(self):
        self.user = User.objects.create_user(
            username="androidclassifier", password="testpass", email="androidclassifier@example.com"
        )
        self.user.profile.is_archive = True
        self.user.profile.last_seen_on = datetime.datetime.now()
        self.user.profile.save()
        self.feed = Feed.objects.create(
            feed_address="https://example.com/android-classifier.xml",
            feed_link="https://example.com",
            feed_title="Android Classifier Feed",
            fetched_once=True,
            known_good=True,
        )
        UserSubscription.objects.create(user=self.user, feed=self.feed, active=True)
        MUserAndroidTokens.objects.create(user_id=self.user.pk, android_tokens=["token-pixel"])
        MUserClassifierNotification.objects.create(
            user_id=self.user.pk,
            classifier_type="title",
            classifier_value="robot",
            scope="feed",
            feed_id=self.feed.pk,
            is_android=True,
        )
        self.story = MStory(
            story_feed_id=self.feed.pk,
            story_date=datetime.datetime.now(),
            story_title="A robot lands on the moon",
            story_content="Robots in space.",
            story_guid="androidclassifier-robot-moon",
            story_permalink="https://example.com/robot-moon",
        )
        self.story.save()

    def tearDown(self):
        self.story.delete()
        MUserClassifierNotification.objects(user_id=self.user.pk).delete()
        MUserAndroidTokens.objects(user_id=self.user.pk).delete()

    def test_classifier_match_is_pushed_to_android(self):
        session = FakeFCMSession()

        # tests.py: the test run shares the dev Redis, so the feed's story list comes from a mock instead.
        with override_settings(FCM_SERVICE_ACCOUNT_INFO=FCM_TEST_SERVICE_ACCOUNT), patch(
            "apps.notifications.models.fcm_session", return_value=session
        ), patch("apps.notifications.models.redis.Redis") as mock_redis_cls:
            mock_redis_cls.return_value.zrange.return_value = [self.story.story_hash]
            sent_count, user_count = MUserClassifierNotification.push_classifier_notifications(
                self.feed.pk, 1
            )

        self.assertEqual((sent_count, user_count), (1, 1))
        self.assertEqual(session.sent_tokens(), ["token-pixel"])
        self.assertEqual(
            session.requests[0]["json"]["message"]["data"],
            {
                "story_hash": self.story.story_hash,
                "story_feed_id": str(self.feed.pk),
                "user_id": str(self.user.pk),
            },
        )
