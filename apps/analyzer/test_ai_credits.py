"""Tests for monthly AI credits and usage billing past them (apps/analyzer/ai_credits.py)."""

import datetime
import uuid
from contextlib import contextmanager
from unittest.mock import patch

import redis
import stripe
from django.conf import settings
from django.contrib.auth.models import User
from django.core import mail
from django.test import TransactionTestCase, override_settings

from apps.analyzer import ai_credits
from apps.analyzer.models import MClassifierPrompt
from apps.profile.models import Profile
from apps.reader.models import UserSubscription
from apps.rss_feeds.models import Feed

AI_CREDIT_SETTINGS = dict(
    STRIPE_PRICE_AI_CREDITS="price_ai_credit",
    STRIPE_PRICE_TEXT_CLASSIFICATION="price_text_classifier",
    STRIPE_PRICE_IMAGE_CLASSIFICATION="price_image_classifier",
)


def isolate_ai_credits(test):
    """Count a test's AI credits under Redis keys of its own, with Stripe usage billing set up.

    test_ai_credits.py: Test user ids repeat across runs in the shared dev Redis, and CI's
    settings have no Stripe prices, which would make credits unlimited (ai_credits.is_unlimited).
    """
    prefix = "AICRTEST%s" % uuid.uuid4().hex[:8]
    prefix_patch = patch.object(ai_credits, "KEY_PREFIX", prefix)
    prefix_patch.start()
    test.addCleanup(prefix_patch.stop)
    credit_settings = override_settings(**AI_CREDIT_SETTINGS)
    credit_settings.enable()
    test.addCleanup(credit_settings.disable)

    def delete_keys():
        r = redis.Redis(connection_pool=settings.REDIS_POOL)
        for key in r.scan_iter(match=prefix + ":*"):
            r.delete(key)

    test.addCleanup(delete_keys)


@contextmanager
def at(when):
    """Run as if the reader's clock reads `when`."""
    with patch("apps.analyzer.ai_credits._now_local", return_value=when):
        yield


NOV_10 = datetime.datetime(2026, 11, 10, 9, 0)
DEC_1 = datetime.datetime(2026, 12, 1, 0, 5)


class Test_AICredits(TransactionTestCase):
    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
        "apps/rss_feeds/fixtures/rss_feeds.json",
    ]

    def setUp(self):
        isolate_ai_credits(self)
        self.user = self.make_user("creditreader", is_premium=True)
        self.feed = Feed.objects.get(pk=1)
        UserSubscription.objects.create(user=self.user, feed=self.feed, is_trained=True, active=True)
        self.prompt = MClassifierPrompt.objects.create(
            user_id=self.user.pk, feed_id=self.feed.pk, prompt="sports", classifier_type="hidden"
        )
        email_patch = patch("apps.profile.tasks.EmailAICreditsPaused.delay")
        self.emailed = email_patch.start()
        self.addCleanup(email_patch.stop)

    def tearDown(self):
        MClassifierPrompt.objects(user_id=self.user.pk).delete()

    def make_user(self, username, **tier):
        user = User.objects.create_user(username=username, password="x", email="%s@test.com" % username)
        flags = dict(is_premium=False, is_archive=False, is_pro=False)
        flags.update(tier)
        Profile.objects.filter(user=user).update(**flags)
        return user

    def profile(self, user=None):
        return Profile.objects.get(user=user or self.user)

    def spend(self, credits, user=None):
        """The reader's filters run up this many credits of Jev requests."""
        ai_credits.spend((user or self.user).pk, "story_classification", credits * ai_credits.CREDIT_USD)

    def turn_on_usage_billing(self, limit=None):
        Profile.objects.filter(user=self.user).update(
            is_usage_billing=True, stripe_id="cus_credits", usage_billing_limit=limit
        )

    def jev_requests_for_new_stories(self):
        """How many Jev requests a fetch with new stories makes for the reader."""
        from apps.analyzer.test_jev import fake_jev

        stories = [
            {
                "story_hash": "%s:credit%s" % (self.feed.pk, uuid.uuid4().hex[:8]),
                "story_feed_id": self.feed.pk,
                "story_title": "Dodgers win in the 10th",
                "story_content": "<p>Baseball.</p>",
                "image_urls": [],
            }
        ]
        with fake_jev() as api:
            MClassifierPrompt.classify_stories(self.user.pk, stories)
        return len(api.requests)

    def test_filters_pause_when_the_plans_credits_run_out_until_the_1st(self):
        with at(NOV_10):
            self.spend(4.9)
            self.assertEqual(self.jev_requests_for_new_stories(), 1)
            self.spend(0.2)
            self.assertEqual(self.jev_requests_for_new_stories(), 0)
            state = ai_credits.state(self.profile())
            self.assertEqual(state["pause_reason"], "credits")
            self.assertEqual(state["resets_on"], "2026-12-01")
        # The reader still subscribes to the feed, so their filters are picked up again.
        self.assertIn(self.user.pk, MClassifierPrompt.feed_has_prompt_subscribers(self.feed.pk))
        with at(DEC_1):
            self.assertEqual(self.jev_requests_for_new_stories(), 1)

    def test_each_plan_runs_on_its_own_credits(self):
        """Premium Pro sets is_archive too, so it has to be told apart before Archive."""
        archive = self.make_user("creditarchive", is_premium=True, is_archive=True)
        pro = self.make_user("creditpro", is_premium=True, is_archive=True, is_pro=True)
        free = self.make_user("creditfree")
        UserSubscription.objects.create(user=free, feed=self.feed, is_trained=True, active=True)
        MClassifierPrompt.objects.create(user_id=free.pk, feed_id=self.feed.pk, prompt="sports")
        self.addCleanup(lambda: MClassifierPrompt.objects(user_id=free.pk).delete())
        with at(NOV_10):
            for user in (self.user, archive, pro):
                self.spend(60, user=user)
            self.assertFalse(ai_credits.can_run(self.profile()))
            self.assertFalse(ai_credits.can_run(self.profile(archive)))
            self.assertTrue(ai_credits.can_run(self.profile(pro)))
            self.assertFalse(ai_credits.can_run(self.profile(free)))
        self.assertNotIn(free.pk, MClassifierPrompt.feed_has_prompt_subscribers(self.feed.pk))

    def test_running_out_emails_the_reader_once_a_month(self):
        free = self.make_user("creditfreemail")
        with at(NOV_10):
            self.spend(4.9)
            self.emailed.assert_not_called()
            self.spend(0.2)
            self.spend(1)
            self.spend(3, user=free)
        self.assertEqual([c.args for c in self.emailed.call_args_list], [(self.user.pk, "credits")])
        with at(DEC_1):
            self.spend(5.1)
        self.assertEqual(self.emailed.call_count, 2)

    def test_the_paused_email_says_why_and_links_to_usage_billing(self):
        mail.outbox = []
        Profile.objects.filter(user=self.user).update(usage_billing_limit="2.00")
        with at(NOV_10):
            self.spend(5.1)
            self.profile().send_ai_credits_paused_email("credits")
            self.profile().send_ai_credits_paused_email("limit")
        self.assertEqual(len(mail.outbox), 2)
        credits_email, limit_email = mail.outbox
        self.assertIn("December 1", credits_email.body)
        self.assertIn("usage billing", credits_email.body)
        self.assertIn("$2.00", limit_email.body)
        for email in mail.outbox:
            self.assertIn("?next=ai_credits", email.body)

    @patch("stripe.billing.MeterEvent.create")
    def test_usage_billing_keeps_filters_running_and_bills_whole_dollars(self, meter_event):
        self.turn_on_usage_billing()
        with at(NOV_10):
            self.spend(5 + 99.5)
            self.assertEqual(self.jev_requests_for_new_stories(), 1)
            meter_event.assert_not_called()
            self.spend(1)
        meter_event.assert_called_once()
        self.assertEqual(meter_event.call_args.kwargs["event_name"], ai_credits.METER_EVENT_NAME)
        self.assertEqual(
            meter_event.call_args.kwargs["payload"], {"stripe_customer_id": "cus_credits", "value": "100"}
        )
        self.emailed.assert_not_called()

    @patch("stripe.billing.MeterEvent.create")
    def test_overage_under_a_dollar_waits_for_a_later_month(self, meter_event):
        self.turn_on_usage_billing()
        with at(NOV_10):
            self.spend(5 + 60)
        meter_event.assert_not_called()
        with at(DEC_1):
            self.spend(5 + 45)
            self.assertEqual(ai_credits.state(self.profile())["unbilled_usd"], 0.05)
        self.assertEqual([c.kwargs["payload"]["value"] for c in meter_event.call_args_list], ["100"])

    @patch("stripe.billing.MeterEvent.create")
    def test_the_monthly_limit_pauses_filters_and_caps_the_bill(self, meter_event):
        self.turn_on_usage_billing(limit="2.00")
        with at(NOV_10):
            self.spend(5 + 150)
            self.assertEqual(self.jev_requests_for_new_stories(), 1)
            self.spend(150)
            self.assertEqual(self.jev_requests_for_new_stories(), 0)
            self.assertEqual(ai_credits.state(self.profile())["pause_reason"], "limit")
        billed = sum(int(c.kwargs["payload"]["value"]) for c in meter_event.call_args_list)
        self.assertEqual(billed, 200)
        self.assertEqual([c.args for c in self.emailed.call_args_list], [(self.user.pk, "limit")])

    @patch("stripe.billing.MeterEvent.create")
    def test_credits_stripe_didnt_take_are_reported_again(self, meter_event):
        meter_event.side_effect = [stripe.error.APIConnectionError("Stripe is down"), None]
        self.turn_on_usage_billing()
        with at(NOV_10):
            self.spend(5 + 100)
            self.spend(0.01)
        self.assertEqual([c.kwargs["payload"]["value"] for c in meter_event.call_args_list], ["100", "100"])
        self.assertEqual(ai_credits.state(self.profile())["unbilled_usd"], 0.0)

    def test_the_forecast_follows_the_pace_since_filters_started(self):
        """Filters that started yesterday project from yesterday, not from a whole week."""
        Profile.objects.filter(user=self.user).update(is_archive=True)
        with at(datetime.datetime(2026, 11, 20, 8, 0)):
            self.spend(10)
        with at(datetime.datetime(2026, 11, 21, 8, 0)):
            self.spend(10)
        with at(datetime.datetime(2026, 11, 21, 12, 0)):
            forecast = ai_credits.state(self.profile())["forecast"]
        # 20 credits over a day and a half: the other 30 last until the evening of the 23rd.
        self.assertEqual(forecast["runs_out_on"], "2026-11-23")
        self.assertEqual(forecast["credits_per_day"], 13.33)
        # Through Nov 30 that pace spends about 147 credits, 97 past the plan's 50.
        self.assertEqual(forecast["overage_usd"], 0.97)

    def test_a_server_without_stripe_billing_never_counts_credits(self):
        """A self-hosted NewsBlur pays Jev itself, so filters run for everyone."""
        free = self.make_user("creditselfhosted")
        with override_settings(
            STRIPE_PRICE_AI_CREDITS="",
            STRIPE_PRICE_TEXT_CLASSIFICATION="",
            STRIPE_PRICE_IMAGE_CLASSIFICATION="",
        ), at(NOV_10):
            self.spend(500)
            self.assertTrue(ai_credits.can_run(self.profile()))
            self.assertTrue(ai_credits.can_run(self.profile(free)))
            self.assertEqual(ai_credits.state(self.profile())["used"], 0)
