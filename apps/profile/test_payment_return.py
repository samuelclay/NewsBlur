"""The page shown after a checkout, a plan switch or a new trial, and the status it polls
(apps/profile/views.py render_payment_return and profile_is_premium)."""

from unittest.mock import MagicMock, patch

import paypalrestsdk
from django.contrib.auth.models import User
from django.core import mail
from django.core.cache import cache
from django.test import TestCase
from django.test.client import Client

from apps.profile.models import Profile
from apps.profile.views import PAYMENT_RETURN_LAST_RETRY, PAYMENT_RETURN_SYNC_RETRY
from apps.reader.models import UserSubscription
from apps.rss_feeds.models import Feed
from utils import json_functions as json


class Test_PaymentReturn(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="returning", password="password", email="returning@test.com"
        )
        self.client = Client(HTTP_USER_AGENT="Mozilla/5.0")
        self.client.login(username="returning", password="password")
        # The minute-long holds on reading the provider outlive a test run, and user ids repeat across runs.
        cache.delete_many(
            ["payment_return_sync:%s:%s" % (self.user.pk, stage) for stage in ("early", "last")]
        )

    def _set_plan(self, **flags):
        Profile.objects.filter(user=self.user).update(**flags)

    def _add_sites(self, on, off):
        for number in range(on + off):
            feed = Feed.objects.create(feed_address="https://return.example/%s" % number, num_subscribers=1)
            UserSubscription.objects.create(user=self.user, feed=feed, active=number < on)

    def _status(self, **params):
        params.setdefault("retries", 0)
        return json.decode(self.client.get("/profile/is_premium", params).content)

    # --- when the page may leave --------------------------------------------

    def test_muted_sites_do_not_keep_a_paid_account_waiting(self):
        self._set_plan(is_premium=True, is_premium_trial=False)
        self._add_sites(on=2, off=1)

        first = self._status(plan="premium")
        self.assertFalse(first["ready"], "one poll can't tell a muted site from one still being turned on")

        second = self._status(plan="premium", retries=1, activated=first["activated_subs"])
        self.assertTrue(second["ready"])
        self.assertEqual((second["activated_subs"], second["total_subs"]), (2, 3))

    def test_the_page_stays_while_sites_are_still_turning_on(self):
        self._set_plan(is_premium=True, is_premium_trial=False)
        self._add_sites(on=2, off=1)

        status = self._status(plan="premium", retries=1, activated=1)

        self.assertFalse(status["ready"])

    def test_the_page_waits_for_the_plan_it_was_opened_for(self):
        self._set_plan(is_premium=True, is_archive=True, is_premium_trial=False)

        self.assertTrue(self._status(plan="archive")["ready"])
        self.assertFalse(self._status(plan="archive_extra")["ready"])
        self.assertFalse(self._status(plan="pro")["ready"])

    def test_a_trial_is_not_yet_the_paid_plan(self):
        self._set_plan(is_premium=True, is_premium_trial=True)

        self.assertTrue(self._status(plan="trial")["ready"])
        self.assertFalse(self._status(plan="premium")["ready"])
        self.assertFalse(self._status()["ready"], "a page that names no plan waits for a paid one")

    def test_sites_that_are_off_are_not_listed_as_on(self):
        self._set_plan(is_premium=True, is_premium_trial=False)
        self._add_sites(on=2, off=1)
        on_feed_ids = set(
            UserSubscription.objects.filter(user=self.user, active=True).values_list("feed_id", flat=True)
        )

        self.assertEqual(set(self._status(plan="premium")["active_feed_ids"]), on_feed_ids)

    # --- a late or lost provider notification -------------------------------

    def _activate_archive(self):
        self._set_plan(is_premium=True, is_archive=True, is_premium_trial=False)

    def test_a_late_notification_is_caught_up_from_the_provider(self):
        self._set_plan(is_premium=True, is_premium_trial=False)

        with patch.object(Profile, "setup_premium_history") as sync:
            self._status(plan="archive", retries=PAYMENT_RETURN_SYNC_RETRY - 1)
            sync.assert_not_called()

            sync.side_effect = lambda *args, **kwargs: self._activate_archive()
            status = self._status(plan="archive", retries=PAYMENT_RETURN_SYNC_RETRY)

        sync.assert_called_once()
        self.assertTrue(status["ready"])
        self.assertEqual(status["code"], 0)

    def test_repeated_polls_share_a_read_and_the_last_poll_gets_a_fresh_one(self):
        self._set_plan(is_premium=True, is_premium_trial=False)

        with patch.object(Profile, "setup_premium_history") as sync:
            self._status(plan="pro", retries=PAYMENT_RETURN_SYNC_RETRY)
            self._status(plan="pro", retries=PAYMENT_RETURN_SYNC_RETRY)
            self.assertEqual(sync.call_count, 1)

            self._status(plan="pro", retries=PAYMENT_RETURN_LAST_RETRY)
            self._status(plan="pro", retries=PAYMENT_RETURN_LAST_RETRY)
            self.assertEqual(sync.call_count, 2, "the last poll reads the provider once more, and only once")

    def test_a_provider_that_cannot_be_reached_leaves_the_page_waiting(self):
        self._set_plan(is_premium=True, is_premium_trial=False)
        unreachable = paypalrestsdk.exceptions.ConnectionError(MagicMock(status_code=503, reason="down"))

        with patch.object(Profile, "setup_premium_history", side_effect=unreachable):
            response = self.client.get(
                "/profile/is_premium", {"plan": "pro", "retries": PAYMENT_RETURN_SYNC_RETRY}
            )

        self.assertEqual(response.status_code, 200)
        self.assertFalse(json.decode(response.content)["ready"])

    def test_an_account_already_on_its_plan_is_not_read_from_the_provider_again(self):
        self._activate_archive()

        with patch.object(Profile, "setup_premium_history") as sync:
            self._status(plan="archive", retries=PAYMENT_RETURN_SYNC_RETRY)
            self._status(plan="archive", retries=PAYMENT_RETURN_LAST_RETRY)

        sync.assert_not_called()

    def test_the_last_poll_stops_the_page_and_tells_staff_which_plan_never_arrived(self):
        self._set_plan(is_premium=True, is_premium_trial=False)

        with patch.object(Profile, "setup_premium_history") as sync:
            status = self._status(plan="pro", retries=PAYMENT_RETURN_LAST_RETRY)

        sync.assert_called_once()
        self.assertEqual(status["code"], -1)
        self.assertFalse(status["ready"])
        self.assertEqual(len(mail.outbox), 1)
        self.assertIn("pro", mail.outbox[0].subject.lower())
        self.assertIn("returning", mail.outbox[0].subject)

    def test_the_last_poll_is_quiet_when_the_plan_arrived(self):
        self._activate_archive()
        self._add_sites(on=1, off=1)

        status = self._status(plan="archive", retries=PAYMENT_RETURN_LAST_RETRY)

        self.assertEqual(status["code"], -1)
        self.assertTrue(status["plan_active"])
        self.assertEqual(len(mail.outbox), 0)

    # --- which plan each return address waits for ---------------------------

    def test_each_return_address_renders_and_waits_for_its_plan(self):
        self._add_sites(on=1, off=1)
        expected = [
            ("/profile/stripe_return", None),
            ("/profile/stripe_return?plan=archive_extra", "archive_extra"),
            ("/profile/stripe_return?plan=premium&switched=1", "premium"),
            ("/profile/stripe_return?plan=enterprise", None),
            ("/profile/paypal_return", None),
            ("/profile/paypal_archive_return", "archive"),
            ("/profile/paypal_archive_return?plan=archive_extra", "archive_extra"),
            ("/profile/paypal_archive_return?plan=pro", "archive"),
            ("/profile/paypal_pro_return", "pro"),
        ]

        for address, plan in expected:
            response = self.client.get(address)
            self.assertEqual(response.status_code, 200, address)
            self.assertEqual(response.context["plan"], plan, address)
            self.assertEqual(len(response.context["sites"]), 2, address)
