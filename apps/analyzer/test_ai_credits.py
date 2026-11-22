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
    AI_CREDITS_USAGE_BILLING=True,
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
DEC_10 = datetime.datetime(2026, 12, 10, 9, 0)
JAN_1 = datetime.datetime(2027, 1, 1, 0, 5)
FEB_1 = datetime.datetime(2027, 2, 1, 0, 5)


class FakeStripeInvoices:
    """Stands in for the Stripe invoice calls ai_credits.charge_unbilled makes. `charged` holds
    the cents of every invoice paid and `cancelled` the invoices deleted or voided.
    `fail_create`, `fail_item`, `fail_finalize` and `decline` fail the next invoice at that step;
    a failed finalize goes through at Stripe but its response never comes back. `fail_retrieve`
    fails that many invoice lookups."""

    def __init__(self):
        self.charged = []
        self.cancelled = []
        self.items = {}
        self.status = {}
        self.fail_create = False
        self.fail_item = False
        self.fail_finalize = False
        self.fail_retrieve = 0
        self.decline = False

    @contextmanager
    def installed(self):
        with patch("stripe.Invoice.create", side_effect=self.create), patch(
            "stripe.InvoiceItem.create", side_effect=self.create_item
        ), patch("stripe.Invoice.finalize_invoice", side_effect=self.finalize), patch(
            "stripe.Invoice.pay", side_effect=self.pay
        ), patch(
            "stripe.Invoice.retrieve", side_effect=self.retrieve
        ), patch(
            "stripe.Invoice.delete", side_effect=self.cancel
        ), patch(
            "stripe.Invoice.void_invoice", side_effect=self.cancel
        ):
            yield self

    def create(self, **kwargs):
        if self.fail_create:
            self.fail_create = False
            raise stripe.error.APIConnectionError("Stripe is down")
        invoice_id = "in_%s" % uuid.uuid4().hex[:8]
        self.status[invoice_id] = "draft"
        return stripe.Invoice.construct_from({"id": invoice_id}, "sk_test")

    def create_item(self, invoice=None, amount=None, **kwargs):
        if self.fail_item:
            self.fail_item = False
            raise stripe.error.APIConnectionError("Stripe is down")
        self.items[invoice] = amount

    def finalize(self, invoice_id, **kwargs):
        self.status[invoice_id] = "open"
        if self.fail_finalize:
            self.fail_finalize = False
            raise stripe.error.APIConnectionError("The response never came back")

    def retrieve(self, invoice_id):
        if self.fail_retrieve:
            self.fail_retrieve -= 1
            raise stripe.error.APIConnectionError("Stripe is still down")
        return stripe.Invoice.construct_from({"id": invoice_id, "status": self.status[invoice_id]}, "sk_test")

    def cancel(self, invoice_id):
        self.cancelled.append(invoice_id)
        self.status[invoice_id] = "void"

    def pay(self, invoice_id):
        if self.decline:
            self.decline = False
            raise stripe.error.CardError("Your card was declined.", None, "card_declined")
        self.status[invoice_id] = "paid"
        self.charged.append(self.items[invoice_id])


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

    def run_immediate_charges(self):
        """Run the charge ai_credits queues at $10 of overage as it would run on Celery."""
        from apps.profile.tasks import ChargeAICreditOverage

        return patch(
            "apps.profile.tasks.ChargeAICreditOverage.delay",
            side_effect=lambda user_id, minimum: ChargeAICreditOverage(user_id, minimum),
        )

    def test_usage_billing_keeps_filters_running_and_charges_after_the_month(self):
        """Overage waits for the month to end, and only the first week of the next month charges
        it, so a reader who turns usage billing on mid-month isn't charged early."""
        self.turn_on_usage_billing()
        with FakeStripeInvoices().installed() as invoices, self.run_immediate_charges():
            with at(NOV_10):
                self.spend(5 + 150)
                self.assertEqual(self.jev_requests_for_new_stories(), 1)
                ai_credits.charge_last_month(self.profile())
            self.assertEqual(invoices.charged, [])
            with at(DEC_1):
                ai_credits.charge_last_month(self.profile())
                ai_credits.charge_last_month(self.profile())
            self.assertEqual(invoices.charged, [150], "Charged once, 150 credits at 1 cent")
        self.emailed.assert_not_called()

    def test_this_months_overage_waits_however_early_the_monthly_job_runs(self):
        """The job runs daily, so on Dec 3 it must still leave December's overage alone."""
        self.turn_on_usage_billing()
        with FakeStripeInvoices().installed() as invoices, self.run_immediate_charges():
            with at(datetime.datetime(2026, 12, 2, 9, 0)):
                self.spend(5 + 150)
            with at(datetime.datetime(2026, 12, 3, 9, 0)):
                ai_credits.charge_last_month(self.profile())
            self.assertEqual(invoices.charged, [])
            with at(JAN_1):
                ai_credits.charge_last_month(self.profile())
        self.assertEqual(invoices.charged, [150])

    def test_overage_under_a_dollar_waits_for_a_later_month(self):
        self.turn_on_usage_billing()
        with FakeStripeInvoices().installed() as invoices, self.run_immediate_charges():
            with at(DEC_10):
                self.spend(5 + 60)
            with at(JAN_1):
                ai_credits.charge_last_month(self.profile())
                self.assertEqual(invoices.charged, [])
                self.spend(5 + 45)
                self.assertEqual(ai_credits.state(self.profile())["unbilled_usd"], 1.05)
            with at(FEB_1):
                ai_credits.charge_last_month(self.profile())
        self.assertEqual(invoices.charged, [105])

    def test_ten_dollars_of_overage_is_charged_right_away(self):
        self.turn_on_usage_billing()
        with FakeStripeInvoices().installed() as invoices, self.run_immediate_charges():
            with at(NOV_10):
                self.spend(5 + 999.5)
                self.assertEqual(invoices.charged, [])
                self.spend(1)
                self.assertEqual(invoices.charged, [1000])
                self.assertEqual(ai_credits.state(self.profile())["unbilled_usd"], 0)
                self.spend(150)
            with at(DEC_1):
                ai_credits.charge_last_month(self.profile())
        self.assertEqual(invoices.charged, [1000, 150], "What came after is charged with the month")

    def test_the_monthly_limit_pauses_filters_and_caps_the_bill(self):
        self.turn_on_usage_billing(limit="2.00")
        with FakeStripeInvoices().installed() as invoices, self.run_immediate_charges():
            with at(NOV_10):
                self.spend(5 + 150)
                self.assertEqual(self.jev_requests_for_new_stories(), 1)
                self.spend(150)
                self.assertEqual(self.jev_requests_for_new_stories(), 0)
                self.assertEqual(ai_credits.state(self.profile())["pause_reason"], "limit")
            with at(DEC_1):
                ai_credits.charge_last_month(self.profile())
        self.assertEqual(invoices.charged, [200])
        self.assertEqual([c.args for c in self.emailed.call_args_list], [(self.user.pk, "limit")])

    def test_credits_stripe_couldnt_invoice_are_charged_next_time(self):
        self.turn_on_usage_billing()
        with FakeStripeInvoices().installed() as invoices:
            invoices.fail_create = True
            with at(NOV_10):
                self.spend(5 + 120)
            with at(DEC_1):
                ai_credits.charge_last_month(self.profile())
                self.assertEqual(ai_credits.state(self.profile())["unbilled_usd"], 1.2)
            with at(DEC_1 + datetime.timedelta(days=1)):
                ai_credits.charge_last_month(self.profile())
        self.assertEqual(invoices.charged, [120])

    def test_an_invoice_left_half_made_is_voided_before_the_credits_are_charged_again(self):
        """Finalizing can go through at Stripe with the response lost. That invoice is voided
        before the credits go back, so it can't collect them alongside the next charge."""
        self.turn_on_usage_billing()
        with FakeStripeInvoices().installed() as invoices:
            invoices.fail_finalize = True
            with at(NOV_10):
                self.spend(5 + 120)
            with at(DEC_1):
                ai_credits.charge_last_month(self.profile())
            self.assertEqual(len(invoices.cancelled), 1)
            self.assertEqual(invoices.charged, [])
            with at(DEC_1 + datetime.timedelta(days=1)):
                ai_credits.charge_last_month(self.profile())
        self.assertEqual(invoices.charged, [120])

    def test_an_invoice_stripe_couldnt_answer_about_is_settled_before_the_next_charge(self):
        """The invoice's line failed and Stripe couldn't be asked about the draft, so its credits
        are neither charged nor dropped: the next charge deletes the draft and charges them."""
        self.turn_on_usage_billing()
        with FakeStripeInvoices().installed() as invoices:
            invoices.fail_item = True
            invoices.fail_retrieve = 1
            with at(NOV_10):
                self.spend(5 + 120)
            with at(DEC_1):
                ai_credits.charge_last_month(self.profile())
                self.assertEqual(invoices.charged, [])
            with at(DEC_1 + datetime.timedelta(days=1)):
                ai_credits.charge_last_month(self.profile())
        self.assertEqual(len(invoices.cancelled), 1)
        self.assertEqual(invoices.charged, [120])

    def test_two_charges_settling_one_invoice_give_its_credits_back_once(self):
        """The immediate charge and the monthly one can settle the same pending invoice at
        once. The second finds it already voided, and must not give its credits back again."""
        self.turn_on_usage_billing()
        with FakeStripeInvoices().installed() as invoices:
            invoices.fail_item = True
            invoices.fail_retrieve = 1
            with at(NOV_10):
                self.spend(5 + 120)
            with at(DEC_1):
                ai_credits.charge_last_month(self.profile())
            self.assertEqual(ai_credits.unbilled_credits(self.profile()), 0)

            cancel_invoice = ai_credits._cancel_invoice
            overlapping = []

            def settle_again_meanwhile(invoice_id):
                if not overlapping:
                    overlapping.append(True)
                    ai_credits.settle_pending_invoices(self.profile())
                return cancel_invoice(invoice_id)

            with patch("apps.analyzer.ai_credits._cancel_invoice", side_effect=settle_again_meanwhile):
                ai_credits.settle_pending_invoices(self.profile())
        self.assertEqual(ai_credits.unbilled_credits(self.profile()), 120)

    def test_a_declined_card_turns_usage_billing_off(self):
        """The open invoice is Stripe's to retry, so the credits aren't charged again, and filters
        stop running past the plan's credits."""
        self.turn_on_usage_billing()
        with FakeStripeInvoices().installed() as invoices:
            invoices.decline = True
            with at(NOV_10):
                self.spend(5 + 120)
            with at(DEC_1):
                ai_credits.charge_last_month(self.profile())
                self.assertFalse(self.profile().is_usage_billing)
                self.assertEqual(ai_credits.state(self.profile())["unbilled_usd"], 0)
                self.spend(5.1)
                self.assertEqual(self.jev_requests_for_new_stories(), 0)

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
            AI_CREDITS_USAGE_BILLING=False,
            STRIPE_PRICE_TEXT_CLASSIFICATION="",
            STRIPE_PRICE_IMAGE_CLASSIFICATION="",
        ), at(NOV_10):
            self.spend(500)
            self.assertTrue(ai_credits.can_run(self.profile()))
            self.assertTrue(ai_credits.can_run(self.profile(free)))
            self.assertEqual(ai_credits.state(self.profile())["used"], 0)
