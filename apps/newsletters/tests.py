"""Tests for email newsletter ingestion."""

import uuid
from unittest.mock import patch

from django.conf import settings
from django.contrib.auth.models import User
from django.contrib.sites.models import Site
from django.test import TestCase

from apps.newsletters.models import EmailNewsletter
from apps.reader.models import UserSubscription, UserSubscriptionFolders
from apps.rss_feeds.models import Feed, MStory


class Test_EmailNewsletter(TestCase):
    def setUp(self):
        self.patchers = [
            patch("apps.newsletters.models.redis.Redis"),
            patch("apps.rss_feeds.models.MStory.sync_redis"),
            patch("apps.social.models.MActivity.new_feed_subscription"),
            patch("apps.statistics.rtrending_subscriptions.RTrendingSubscription.add_subscription"),
            patch.object(EmailNewsletter, "_check_if_first_newsletter"),
            patch.object(EmailNewsletter, "_publish_to_subscribers"),
            patch.object(Feed, "count_subscribers"),
            patch.object(Feed, "setup_feed_for_premium_subscribers"),
            patch.object(Feed, "update", lambda feed, *args, **kwargs: feed),
        ]
        for patcher in self.patchers:
            patcher.start()
            self.addCleanup(patcher.stop)

        self.guid_prefix = "newsletter-test-%s" % uuid.uuid4().hex
        MStory.objects(story_guid__startswith=self.guid_prefix).delete()

        with patch("apps.profile.tasks.EmailNewPremiumTrial.delay"):
            self.user = User.objects.create_user(username="newsletteruser", email="")
        self.user.profile.secret_token = "abc123"
        self.user.profile.save()
        UserSubscriptionFolders.objects.create(user=self.user, folders="[]")
        Site.objects.update_or_create(
            id=settings.SITE_ID,
            defaults={"domain": "testserver", "name": "testserver"},
        )

    def tearDown(self):
        MStory.objects(story_guid__startswith=self.guid_prefix).delete()

    def receive(self, suffix, **overrides):
        params = {
            "recipient": "newsletteruser-abc123@newsletters.newsblur.com",
            "from": "Hipersonica - hipersonica+tier-list at substack.com "
            "<hipersonica_tier-list_at_substack_com_zjdml@simplelogin.co>",
            "subject": "Newsletter test",
            "body-plain": "Newsletter body",
            "timestamp": "1700000000",
            "signature": "%s-%s" % (self.guid_prefix, suffix),
        }
        params.update(overrides)
        return EmailNewsletter().receive_newsletter(params)

    def test_list_id_is_saved_and_used_as_feed_identity(self):
        first_story = self.receive(
            "list-id-1",
            **{
                "message-headers": '[["List-ID", "Hipersonica <hipersonica.substack.com>"], '
                '["List-Unsubscribe", "<https://example.com/unsubscribe>"]]',
            },
        )
        second_story = self.receive(
            "list-id-2",
            **{
                "from": "Hipersonica - hipersonica+valladolid-buenos-dias at substack.com "
                "<hipersonica_valladolid-buenos-dias_at_substack_c_wykwbb@simplelogin.co>",
                "message-headers": '[["List-ID", "Hipersonica <hipersonica.substack.com>"]]',
            },
        )

        feed_address = "newsletter:%s:list-id:hipersonica.substack.com" % self.user.pk
        feed = Feed.objects.get(feed_address=feed_address)
        self.assertEqual(first_story.story_feed_id, feed.pk)
        self.assertEqual(second_story.story_feed_id, feed.pk)
        self.assertEqual(MStory.objects(story_feed_id=feed.pk).count(), 2)

        stored_story = MStory.objects.get(story_guid="%s-list-id-1" % self.guid_prefix)
        self.assertEqual(stored_story.newsletter_identity, "list-id:hipersonica.substack.com")
        self.assertEqual(stored_story.newsletter_identity_source, "list-id")
        self.assertEqual(
            stored_story.newsletter_headers["List-Id"], ["Hipersonica <hipersonica.substack.com>"]
        )
        self.assertEqual(
            stored_story.newsletter_headers["List-Unsubscribe"],
            ["<https://example.com/unsubscribe>"],
        )

        self.assertEqual(UserSubscription.objects.filter(user=self.user, feed=feed).count(), 1)

    def test_existing_legacy_feed_is_readdressed_to_list_id_identity(self):
        legacy_address = (
            "newsletter:%s:hipersonica_tier-list_at_substack_com_zjdml@simplelogin.co" % self.user.pk
        )
        legacy_feed = Feed.objects.create(
            feed_address=legacy_address,
            feed_link="http://simplelogin.co",
            feed_title="Hipersonica - hipersonica+tier-list at substack.com",
            fetched_once=True,
            known_good=True,
        )
        UserSubscription.objects.create(user=self.user, feed=legacy_feed)

        story = self.receive(
            "legacy-list-id",
            **{"message-headers": '[["List-ID", "Hipersonica <hipersonica.substack.com>"]]'},
        )

        legacy_feed.refresh_from_db()
        self.assertEqual(
            legacy_feed.feed_address, "newsletter:%s:list-id:hipersonica.substack.com" % self.user.pk
        )
        self.assertEqual(story.story_feed_id, legacy_feed.pk)
        self.assertFalse(Feed.objects.filter(feed_address=legacy_address).exists())

    def test_sender_fallback_extracts_embedded_original_sender_for_any_domain(self):
        first_story = self.receive(
            "sender-1",
            **{
                "from": "Hipersonica - hipersonica+tier-list at substack.com "
                "<hipersonica_tier-list_at_substack_com_zjdml@relay.example>",
            },
        )
        second_story = self.receive(
            "sender-2",
            **{
                "from": "Hipersonica - hipersonica+valladolid-buenos-dias at substack.com "
                "<hipersonica_valladolid-buenos-dias_at_substack_c_wykwbb@another-relay.example>",
            },
        )

        feed = Feed.objects.get(feed_address="newsletter:%s:hipersonica@substack.com" % self.user.pk)
        self.assertEqual(first_story.story_feed_id, feed.pk)
        self.assertEqual(second_story.story_feed_id, feed.pk)
        self.assertEqual(MStory.objects(story_feed_id=feed.pk).count(), 2)

        stored_story = MStory.objects.get(story_guid="%s-sender-1" % self.guid_prefix)
        self.assertEqual(stored_story.newsletter_identity, "hipersonica@substack.com")
        self.assertEqual(stored_story.newsletter_identity_source, "sender")

    def test_sender_fallback_strips_plus_addressing_for_direct_senders(self):
        first_story = self.receive(
            "direct-sender-1",
            **{"from": "Hipersonica <hipersonica+tier-list@substack.com>"},
        )
        second_story = self.receive(
            "direct-sender-2",
            **{"from": "Hipersonica <hipersonica+valladolid-buenos-dias@substack.com>"},
        )

        feed = Feed.objects.get(feed_address="newsletter:%s:hipersonica@substack.com" % self.user.pk)
        self.assertEqual(first_story.story_feed_id, feed.pk)
        self.assertEqual(second_story.story_feed_id, feed.pk)
        self.assertEqual(MStory.objects(story_feed_id=feed.pk).count(), 2)
