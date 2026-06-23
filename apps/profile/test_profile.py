import datetime
from unittest.mock import MagicMock, call, patch

from django.conf import settings
from django.contrib.auth.models import User
from django.test import TestCase, override_settings
from django.test.client import Client
from django.urls import reverse

from apps.profile.models import PaymentHistory, Profile, StripeIds
from utils import json_functions as json


class Test_Profile(TestCase):
    def setUp(self):
        # MongoDB connection is handled by the test runner
        self.client = Client(HTTP_USER_AGENT="Mozilla/5.0")

    def tearDown(self):
        # Database cleanup is handled by the test runner
        pass

    def test_create_account(self):
        resp = self.client.get(reverse("load-feeds"))
        response = json.decode(resp.content)
        self.assertEquals(response["authenticated"], False)

        response = self.client.post(
            reverse("welcome-signup"),
            {
                "signup-username": "test",
                "signup-password": "password",
                "signup-email": "test@newsblur.com",
            },
        )
        self.assertEquals(response.status_code, 302)

        resp = self.client.get(reverse("load-feeds"))
        response = json.decode(resp.content)
        self.assertEquals(response["authenticated"], True)


class Test_TierProtection(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="tiertest", password="password", email="tier@test.com")
        self.profile = self.user.profile

    @patch("apps.profile.tasks.EmailNewPremium.delay")
    def test_activate_premium_does_not_downgrade_archive(self, mock_email):
        self.profile.is_premium = True
        self.profile.is_archive = True
        self.profile.is_pro = False
        self.profile.save()

        result = self.profile.activate_premium()

        self.profile.refresh_from_db()
        self.assertTrue(self.profile.is_archive)
        self.assertTrue(self.profile.is_premium)
        self.assertTrue(result)
        mock_email.assert_not_called()

    @patch("apps.profile.tasks.EmailNewPremium.delay")
    def test_activate_premium_does_not_downgrade_pro(self, mock_email):
        self.profile.is_premium = True
        self.profile.is_archive = True
        self.profile.is_pro = True
        self.profile.save()

        result = self.profile.activate_premium()

        self.profile.refresh_from_db()
        self.assertTrue(self.profile.is_pro)
        self.assertTrue(self.profile.is_archive)
        self.assertTrue(self.profile.is_premium)
        self.assertTrue(result)
        mock_email.assert_not_called()

    @patch("apps.profile.tasks.EmailNewPremium.delay")
    def test_activate_premium_works_for_free_user(self, mock_email):
        self.profile.is_premium = False
        self.profile.is_archive = False
        self.profile.is_pro = False
        self.profile.save()

        self.profile.activate_premium()

        self.profile.refresh_from_db()
        self.assertTrue(self.profile.is_premium)
        self.assertFalse(self.profile.is_archive)
        self.assertFalse(self.profile.is_pro)

    def test_plan_to_paypal_plan_id_pro_returns_paypal_id(self):
        plan_id = Profile.plan_to_paypal_plan_id("pro")
        self.assertTrue(
            plan_id.startswith("P-"), "Pro PayPal plan ID should start with 'P-', got: %s" % plan_id
        )


class Test_ArchiveRedisThrottling(TestCase):
    """Tests for premium archive upgrade Redis throttling (apps/profile/models.py activate_archive)."""

    def setUp(self):
        self.user = User.objects.create_user(
            username="archivetest", password="password", email="archive@test.com"
        )
        self.profile = self.user.profile

    @patch("apps.profile.models.SchedulePremiumSetup")
    @patch("apps.reader.models.UserSubscription.schedule_fetch_archive_feeds_for_user")
    @patch("apps.reader.models.UserSubscription.queue_new_feeds")
    def test_activate_archive_passes_allow_skip_resync_to_premium_setup(
        self, mock_queue_new, mock_schedule_archive, mock_schedule_premium
    ):
        """activate_archive should pass allow_skip_resync=True to SchedulePremiumSetup
        so that sync_redis is skipped for large feeds during the concurrent archive fetch."""
        self.profile.is_premium = False
        self.profile.is_archive = False
        self.profile.save()

        self.profile.activate_archive()

        mock_schedule_premium.apply_async.assert_called_once()
        kwargs = mock_schedule_premium.apply_async.call_args[1]["kwargs"]
        self.assertTrue(
            kwargs.get("allow_skip_resync"),
            "activate_archive must pass allow_skip_resync=True to SchedulePremiumSetup",
        )

    @patch("apps.profile.models.SchedulePremiumSetup")
    @patch("apps.reader.models.UserSubscription.schedule_fetch_archive_feeds_for_user")
    @patch("apps.reader.models.UserSubscription.queue_new_feeds")
    def test_activate_archive_schedules_archive_fetch(
        self, mock_queue_new, mock_schedule_archive, mock_schedule_premium
    ):
        """activate_archive should trigger the archive feed fetch."""
        self.profile.is_premium = False
        self.profile.is_archive = False
        self.profile.save()

        self.profile.activate_archive()

        mock_schedule_archive.assert_called_once_with(self.user.pk)

    @patch("apps.profile.models.SchedulePremiumSetup")
    @patch("apps.reader.models.UserSubscription.queue_new_feeds")
    @patch("apps.profile.tasks.EmailNewPremium.delay")
    def test_activate_premium_does_not_pass_allow_skip_resync(
        self, mock_email, mock_queue_new, mock_schedule_premium
    ):
        """activate_premium (non-archive) should NOT pass allow_skip_resync, because
        there is no concurrent archive fetch to conflict with."""
        self.profile.is_premium = False
        self.profile.is_archive = False
        self.profile.save()

        self.profile.activate_premium()

        mock_schedule_premium.apply_async.assert_called_once()
        kwargs = mock_schedule_premium.apply_async.call_args[1]["kwargs"]
        self.assertNotIn(
            "allow_skip_resync",
            kwargs,
            "activate_premium should not pass allow_skip_resync",
        )


class Test_UpgradePaths(TestCase):
    """Tier upgrade paths invoked from Stripe/PayPal/in-app webhooks.

    Sean Welsh hit the trial→premium regression in May 2026: the dedupe added
    in 4181413df short-circuited activate_premium for any user with
    is_premium=True, but trial users have is_premium=True too, so the trial
    flag never cleared and the new-premium email never fired.

    These tests cover every starting tier × every paid target so a future
    dedupe change can't silently regress trial conversions again.
    """

    def setUp(self):
        self.user = User.objects.create_user(
            username="upgradepaths", password="password", email="upgrade@test.com"
        )
        self.profile = self.user.profile

    def _start_patches(self):
        """Returns the started mocks as a dict keyed by the attribute name we care about."""
        email_premium = patch("apps.profile.tasks.EmailNewPremium.delay").start()
        email_pro = patch("apps.profile.tasks.EmailNewPremiumPro.delay").start()
        email_staff = patch("apps.profile.tasks.EmailStaffPremiumUpgrade.delay").start()
        schedule_setup = patch("apps.profile.models.SchedulePremiumSetup").start()
        queue_feeds = patch("apps.reader.models.UserSubscription.queue_new_feeds").start()
        archive_fetch = patch(
            "apps.reader.models.UserSubscription.schedule_fetch_archive_feeds_for_user"
        ).start()
        setup_history = patch.object(Profile, "setup_premium_history").start()
        self.addCleanup(patch.stopall)
        return {
            "email_premium": email_premium,
            "email_pro": email_pro,
            "email_staff": email_staff,
            "schedule_setup": schedule_setup,
            "queue_feeds": queue_feeds,
            "archive_fetch": archive_fetch,
            "setup_history": setup_history,
        }

    def _set_state(self, **kwargs):
        for k, v in kwargs.items():
            setattr(self.profile, k, v)
        self.profile.save()

    # --- free → paid ------------------------------------------------------

    def test_free_to_premium(self):
        m = self._start_patches()
        self._set_state(is_premium=False, is_premium_trial=None)

        result = self.profile.activate_premium()

        self.profile.refresh_from_db()
        self.assertTrue(result)
        self.assertTrue(self.profile.is_premium)
        self.assertFalse(self.profile.is_archive)
        self.assertFalse(self.profile.is_pro)
        m["email_premium"].assert_called_once_with(user_id=self.user.pk)
        # Staff only get archive/pro upgrade emails, not plain premium.
        m["email_staff"].assert_not_called()
        # Free→premium relies on the downstream charge.succeeded webhook to
        # sync history. Calling setup_premium_history here would double the
        # Stripe API calls per signup.
        m["setup_history"].assert_not_called()

    def test_free_to_archive(self):
        m = self._start_patches()
        self._set_state(is_premium=False, is_archive=False, is_premium_trial=None)

        result = self.profile.activate_archive()

        self.profile.refresh_from_db()
        self.assertTrue(result)
        self.assertTrue(self.profile.is_premium)
        self.assertTrue(self.profile.is_archive)
        self.assertFalse(self.profile.is_pro)
        m["email_staff"].assert_called_once()
        self.assertEqual(m["email_staff"].call_args.kwargs["previous_tier"], "free")

    def test_free_to_pro(self):
        m = self._start_patches()
        self._set_state(is_premium=False, is_archive=False, is_pro=False, is_premium_trial=None)

        result = self.profile.activate_pro()

        self.profile.refresh_from_db()
        self.assertTrue(result)
        self.assertTrue(self.profile.is_premium)
        self.assertTrue(self.profile.is_archive)
        self.assertTrue(self.profile.is_pro)
        m["email_pro"].assert_called_once_with(user_id=self.user.pk)
        self.assertEqual(m["email_staff"].call_args.kwargs["previous_tier"], "free")

    # --- trial → paid (the regression Sean hit) ---------------------------

    def test_trial_to_premium_clears_trial_flag(self):
        """The bug: trial users have is_premium=True, the old dedupe skipped them.

        After the fix, activate_premium must clear is_premium_trial, send the
        new-premium email, report 'trial' as the previous tier, and sync
        history so premium_expire flips off the trial date immediately.
        """
        m = self._start_patches()
        self._set_state(is_premium=True, is_premium_trial=True)

        result = self.profile.activate_premium()

        self.profile.refresh_from_db()
        self.assertTrue(result)
        self.assertTrue(self.profile.is_premium)
        self.assertFalse(self.profile.is_premium_trial, "trial flag must clear on paid upgrade")
        m["email_premium"].assert_called_once_with(user_id=self.user.pk)
        # Staff only get archive/pro upgrade emails, not plain premium.
        m["email_staff"].assert_not_called()
        m["setup_history"].assert_called_once()

    def test_trial_to_archive_clears_trial_flag(self):
        m = self._start_patches()
        self._set_state(is_premium=True, is_premium_trial=True, is_archive=False)

        result = self.profile.activate_archive()

        self.profile.refresh_from_db()
        self.assertTrue(result)
        self.assertTrue(self.profile.is_archive)
        self.assertFalse(self.profile.is_premium_trial)
        m["email_staff"].assert_called_once()
        self.assertEqual(m["email_staff"].call_args.kwargs["previous_tier"], "trial")

    def test_trial_to_pro_clears_trial_flag(self):
        m = self._start_patches()
        self._set_state(is_premium=True, is_premium_trial=True, is_pro=False)

        result = self.profile.activate_pro()

        self.profile.refresh_from_db()
        self.assertTrue(result)
        self.assertTrue(self.profile.is_pro)
        self.assertFalse(self.profile.is_premium_trial)
        m["email_pro"].assert_called_once_with(user_id=self.user.pk)
        self.assertEqual(m["email_staff"].call_args.kwargs["previous_tier"], "trial")

    # --- paid → higher paid tier -----------------------------------------

    def test_premium_to_archive(self):
        m = self._start_patches()
        self._set_state(is_premium=True, is_premium_trial=False, is_archive=False)

        result = self.profile.activate_archive()

        self.profile.refresh_from_db()
        self.assertTrue(result)
        self.assertTrue(self.profile.is_archive)
        self.assertEqual(m["email_staff"].call_args.kwargs["previous_tier"], "premium")

    def test_premium_to_pro(self):
        m = self._start_patches()
        self._set_state(is_premium=True, is_premium_trial=False, is_archive=False, is_pro=False)

        result = self.profile.activate_pro()

        self.profile.refresh_from_db()
        self.assertTrue(result)
        self.assertTrue(self.profile.is_pro)
        m["email_pro"].assert_called_once()
        self.assertEqual(m["email_staff"].call_args.kwargs["previous_tier"], "premium")

    def test_archive_to_pro(self):
        m = self._start_patches()
        self._set_state(is_premium=True, is_premium_trial=False, is_archive=True, is_pro=False)

        result = self.profile.activate_pro()

        self.profile.refresh_from_db()
        self.assertTrue(result)
        self.assertTrue(self.profile.is_pro)
        self.assertEqual(m["email_staff"].call_args.kwargs["previous_tier"], "archive")

    # --- idempotency: duplicate webhooks ---------------------------------

    def test_activate_premium_idempotent_for_paid_premium(self):
        """Stripe sometimes fires the same subscription event twice. The second
        activate_premium call must be a no-op: no email, no flag flips."""
        m = self._start_patches()
        self._set_state(is_premium=True, is_premium_trial=False)

        result = self.profile.activate_premium()

        self.assertTrue(result)
        m["email_premium"].assert_not_called()
        m["email_staff"].assert_not_called()

    def test_activate_archive_idempotent_for_paid_archive(self):
        m = self._start_patches()
        self._set_state(is_premium=True, is_archive=True, is_premium_trial=False)

        result = self.profile.activate_archive()

        self.assertTrue(result)
        m["email_staff"].assert_not_called()

    def test_activate_pro_idempotent_for_paid_pro(self):
        m = self._start_patches()
        self._set_state(is_premium=True, is_archive=True, is_pro=True, is_premium_trial=False)

        result = self.profile.activate_pro()

        self.assertTrue(result)
        m["email_pro"].assert_not_called()
        m["email_staff"].assert_not_called()

    # --- downgrade prevention --------------------------------------------

    def test_activate_premium_does_not_clear_archive(self):
        """A late-arriving customer.subscription.created event for the original
        premium plan must not strip archive/pro from a user who already
        upgraded past premium."""
        m = self._start_patches()
        self._set_state(is_premium=True, is_archive=True, is_premium_trial=False)

        result = self.profile.activate_premium()

        self.profile.refresh_from_db()
        self.assertTrue(result)
        self.assertTrue(self.profile.is_archive, "archive must survive late premium webhook")

    def test_activate_premium_does_not_clear_pro(self):
        m = self._start_patches()
        self._set_state(is_premium=True, is_archive=True, is_pro=True, is_premium_trial=False)

        result = self.profile.activate_premium()

        self.profile.refresh_from_db()
        self.assertTrue(result)
        self.assertTrue(self.profile.is_pro, "pro must survive late premium webhook")

    # --- concurrent webhook race ------------------------------------------

    def test_concurrent_trial_to_premium_only_emails_once(self):
        """Two Stripe webhooks fire activate_premium in parallel for the same
        trial→paid conversion. Only one should send the new-premium email and
        clear the flag; the second must dedupe."""
        m = self._start_patches()
        self._set_state(is_premium=True, is_premium_trial=True)

        # First call wins the atomic update and clears the trial flag.
        self.profile.activate_premium()

        # Second call: same in-memory profile still has stale is_premium_trial=True,
        # but the DB row was updated to is_premium_trial=False by the first call.
        # The select_for_update inside the atomic block must observe the fresh
        # row and short-circuit.
        second_profile = Profile.objects.get(pk=self.profile.pk)
        # Simulate webhook racing: caller still thinks user is on trial
        second_profile.is_premium_trial = True
        second_profile.activate_premium()

        self.assertEqual(m["email_premium"].call_count, 1, "new-premium email must send exactly once")
        m["email_staff"].assert_not_called()


class Test_SetupPremiumHistoryStripe(TestCase):
    """Tests for Stripe subscription handling in setup_premium_history (apps/profile/models.py)."""

    def setUp(self):
        self.user = User.objects.create_user(
            username="stripehisttest", password="password", email="stripehisttest@test.com"
        )
        self.profile = self.user.profile
        self.profile.stripe_id = "cus_test123"
        self.profile.save()

    def _make_plan(self, active=True, plan_id="price_premium"):
        plan = MagicMock()
        plan.active = active
        plan.id = plan_id
        return plan

    def _make_subscription(self, plan=None, cancel_at=None, items_data=None):
        sub = MagicMock()
        sub.plan = plan
        sub.cancel_at = cancel_at
        if items_data is not None:
            sub.get.return_value = MagicMock(data=items_data)
        else:
            sub.get.return_value = None
        return sub

    @patch("stripe.Subscription.list")
    @patch("stripe.Charge.list")
    @patch("stripe.Customer.retrieve")
    @patch.object(Profile, "retrieve_stripe_ids")
    @patch.object(Profile, "retrieve_paypal_ids")
    def test_stripe_subscription_with_none_plan_no_crash(
        self, mock_paypal_ids, mock_stripe_ids, mock_customer, mock_charges, mock_subs
    ):
        """Stripe subscriptions with plan=None should not raise AttributeError."""
        mock_customer.return_value = MagicMock(id="cus_test123")
        mock_charges.return_value = MagicMock(data=[])

        # Subscription with plan=None and no items fallback - the original crash
        sub = self._make_subscription(plan=None, items_data=None)
        mock_subs.return_value = MagicMock(data=[sub])

        from apps.profile.models import StripeIds

        StripeIds.objects.create(user=self.user, stripe_id="cus_test123")

        # Should not raise AttributeError: 'NoneType' object has no attribute 'active'
        self.profile.setup_premium_history()

    @patch("stripe.Subscription.list")
    @patch("stripe.Charge.list")
    @patch("stripe.Customer.retrieve")
    @patch.object(Profile, "retrieve_stripe_ids")
    @patch.object(Profile, "retrieve_paypal_ids")
    def test_stripe_subscription_with_none_plan_uses_items_fallback(
        self, mock_paypal_ids, mock_stripe_ids, mock_customer, mock_charges, mock_subs
    ):
        """Stripe subscriptions with plan=None should fall back to items.data[0].plan."""
        mock_customer.return_value = MagicMock(id="cus_test123")
        mock_charges.return_value = MagicMock(data=[])

        item_plan = self._make_plan(active=True, plan_id="price_premium_from_items")
        sub = self._make_subscription(plan=None, cancel_at=None, items_data=[MagicMock(plan=item_plan)])
        mock_subs.return_value = MagicMock(data=[sub])

        from apps.profile.models import StripeIds

        StripeIds.objects.create(user=self.user, stripe_id="cus_test123")

        self.profile.setup_premium_history()

        self.profile.refresh_from_db()
        self.assertEqual(self.profile.active_provider, "stripe")
        self.assertTrue(self.profile.premium_renewal)


class Test_StripeIdSync(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="stripeidsync",
            password="password",
            email="stripeidsync@test.com",
        )
        self.profile = self.user.profile
        self.profile.stripe_id = "cus_test123"
        self.profile.save()

    @patch("stripe.Customer.list")
    @patch("stripe.Customer.retrieve")
    def test_retrieve_stripe_ids_ignores_deleted_user(self, mock_customer_retrieve, mock_customer_list):
        mock_customer_retrieve.return_value = MagicMock(email="stripeidsync@test.com")
        mock_customer_list.side_effect = [
            [MagicMock(stripe_id="cus_test123")],
            [MagicMock(stripe_id="cus_test456")],
        ]

        # Keep the related user cached on the Profile instance so the stale-object
        # race matches the webhook path in apps/profile/models.py.
        self.assertEqual(self.profile.user.pk, self.user.pk)
        deleted_user_id = self.user.pk
        User.objects.filter(pk=deleted_user_id).delete()

        self.profile.retrieve_stripe_ids()

        self.assertFalse(StripeIds.objects.filter(user_id=deleted_user_id).exists())


class Test_AndroidSubscriptionActivation(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="androidsubtest",
            password="password",
            email="androidsub@test.com",
        )
        self.profile = self.user.profile

    @patch.object(Profile, "setup_premium_history")
    @patch.object(Profile, "activate_archive")
    def test_activate_android_archive_uses_product_id(self, mock_activate_archive, mock_setup):
        result = self.profile.activate_android_premium(
            order_id="GPA.1000-0000-0000-00001",
            product_id="nb.premium.archive.99",
        )

        self.assertTrue(result)
        mock_setup.assert_called_once()
        mock_activate_archive.assert_called_once()
        self.assertTrue(
            PaymentHistory.objects.filter(
                user=self.user,
                payment_identifier="GPA.1000-0000-0000-00001",
                payment_provider="android-archive",
            ).exists()
        )

    @patch.object(Profile, "setup_premium_history")
    @patch.object(Profile, "activate_pro")
    def test_activate_android_pro_uses_product_id(self, mock_activate_pro, mock_setup):
        result = self.profile.activate_android_premium(
            order_id="GPA.1000-0000-0000-00002",
            product_id="nb.premium.pro.299",
        )

        self.assertTrue(result)
        mock_setup.assert_called_once()
        mock_activate_pro.assert_called_once()
        self.assertTrue(
            PaymentHistory.objects.filter(
                user=self.user,
                payment_identifier="GPA.1000-0000-0000-00002",
                payment_provider="android-pro",
            ).exists()
        )

    def test_save_android_receipt_passes_product_id(self):
        self.client.login(username="androidsubtest", password="password")

        with patch.object(Profile, "activate_android_premium", return_value=True) as mock_activate:
            response = self.client.post(
                reverse("save-android-receipt"),
                {
                    "order_id": "GPA.1000-0000-0000-00003",
                    "product_id": "nb.premium.pro.299",
                },
            )

        self.assertEqual(response.status_code, 200)
        mock_activate.assert_called_once_with("GPA.1000-0000-0000-00003", product_id="nb.premium.pro.299")


class Test_ProratedProviderSwitchRefund(TestCase):
    """When an App Store / Google Play subscriber upgrades or switches to a
    Stripe subscription, the unused days of their store payment should be
    refunded against the new Stripe charge.
    """

    def setUp(self):
        self.user = User.objects.create_user(
            username="storeswitchtest",
            password="password",
            email="storeswitch@test.com",
        )
        self.profile = self.user.profile
        self.profile.stripe_id = "cus_storeswitch"
        self.profile.save()

    @patch("stripe.Refund.create")
    @patch("stripe.Charge.list")
    @patch.object(Profile, "stripe_customer")
    def test_refunds_unused_store_days_against_new_stripe_charge(
        self, mock_customer, mock_charges, mock_refund
    ):
        # Paid $36 for Android Premium 27 days ago, then upgraded to $99 Archive via Stripe
        PaymentHistory.objects.create(
            user=self.user,
            payment_date=datetime.datetime.now() - datetime.timedelta(days=27),
            payment_amount=36,
            payment_provider="android-subscription",
            payment_identifier="GPA.0000-0000-0000-00001",
        )
        mock_customer.return_value = MagicMock(id="cus_storeswitch")
        mock_charges.return_value = MagicMock(
            data=[MagicMock(id="ch_archive", amount=9900, amount_refunded=0)]
        )
        mock_refund.return_value = MagicMock(id="re_storeswitch")

        refunded = self.profile.refund_prorated_store_payment_for_provider_switch()

        # 338 of 365 unused days of $36 = $33.34
        mock_refund.assert_called_once_with(charge="ch_archive", amount=3334)
        self.assertAlmostEqual(refunded, 33.34, places=2)
        self.assertTrue(
            PaymentHistory.objects.filter(
                user=self.user,
                payment_provider="stripe",
                payment_amount=-33,
                payment_identifier="re_storeswitch",
                refunded=True,
            ).exists()
        )

    @patch("stripe.Refund.create")
    @patch("stripe.Charge.list")
    @patch.object(Profile, "stripe_customer")
    def test_no_refund_without_store_payment(self, mock_customer, mock_charges, mock_refund):
        # A plain free-to-Stripe signup has no store payment to prorate
        mock_customer.return_value = MagicMock(id="cus_storeswitch")
        mock_charges.return_value = MagicMock(
            data=[MagicMock(id="ch_archive", amount=9900, amount_refunded=0)]
        )

        refunded = self.profile.refund_prorated_store_payment_for_provider_switch()

        self.assertIsNone(refunded)
        mock_refund.assert_not_called()

    @patch("stripe.Refund.create")
    @patch("stripe.Charge.list")
    @patch.object(Profile, "stripe_customer")
    def test_no_double_refund_when_charge_already_refunded(self, mock_customer, mock_charges, mock_refund):
        # A retried webhook (or a manual refund) must not refund twice
        PaymentHistory.objects.create(
            user=self.user,
            payment_date=datetime.datetime.now() - datetime.timedelta(days=27),
            payment_amount=36,
            payment_provider="android-subscription",
        )
        mock_customer.return_value = MagicMock(id="cus_storeswitch")
        mock_charges.return_value = MagicMock(
            data=[MagicMock(id="ch_archive", amount=9900, amount_refunded=3334)]
        )

        refunded = self.profile.refund_prorated_store_payment_for_provider_switch()

        self.assertIsNone(refunded)
        mock_refund.assert_not_called()

    @patch("stripe.Refund.create")
    @patch("stripe.Charge.list")
    @patch.object(Profile, "stripe_customer")
    def test_no_refund_when_store_payment_too_old(self, mock_customer, mock_charges, mock_refund):
        # A store payment older than a year has no unused days left to refund
        PaymentHistory.objects.create(
            user=self.user,
            payment_date=datetime.datetime.now() - datetime.timedelta(days=400),
            payment_amount=36,
            payment_provider="ios-subscription",
        )
        mock_customer.return_value = MagicMock(id="cus_storeswitch")
        mock_charges.return_value = MagicMock(
            data=[MagicMock(id="ch_archive", amount=9900, amount_refunded=0)]
        )

        refunded = self.profile.refund_prorated_store_payment_for_provider_switch()

        self.assertIsNone(refunded)
        mock_refund.assert_not_called()


class Test_PremiumPricingMigration(TestCase):
    """Migrate grandfathered $12/$24 premium subscribers up to $36 (apps/profile/models.py).

    Covers the Stripe silent price switch (no early charge), the PayPal approval-link flow,
    both email variants, the cohort selection, idempotency, and the reconciliation that records
    upgraded/cancelled outcomes and cancels non-approving PayPal subscriptions.
    """

    def setUp(self):
        from django.core import mail

        mail.outbox = []
        self.user = User.objects.create_user(
            username="pricingmig", password="password", email="pricingmig@test.com"
        )
        self.profile = self.user.profile
        self.profile.is_premium = True
        self.profile.is_premium_trial = False
        self.profile.premium_renewal = True
        self.profile.active_provider = "stripe"
        self.profile.last_seen_on = datetime.datetime.now()
        self.profile.premium_expire = datetime.datetime.now() + datetime.timedelta(hours=60)
        self.profile.stripe_id = "cus_pricingmig"
        self.profile.save()
        # Default the redis lock to "proceed without lock" so tests don't depend on a live redis;
        # the dedicated lock tests override this to exercise the "skip" path.
        lock_patch = patch.object(Profile, "_acquire_pricing_lock", return_value=None)
        lock_patch.start()
        self.addCleanup(lock_patch.stop)

    def _add_payment(self, amount, days_ago=10, provider="stripe", refunded=None, user=None):
        return PaymentHistory.objects.create(
            user=user or self.user,
            payment_date=datetime.datetime.now() - datetime.timedelta(days=days_ago),
            payment_amount=amount,
            payment_provider=provider,
            refunded=refunded,
        )

    def _make_stripe_sub(self, plan_id="newsblur-premium-24", active=True):
        plan = MagicMock(active=active)
        plan.id = plan_id
        item = MagicMock()
        item.id = "si_1"
        item.plan = plan
        sub = MagicMock()
        sub.id = "sub_1"
        sub.plan = plan
        sub.__getitem__.side_effect = lambda key: {"items": {"data": [item]}}[key]
        return sub

    # --- Stripe silent price switch -----------------------------------------

    @patch("stripe.Subscription.modify")
    @patch("stripe.Subscription.list")
    @patch.object(Profile, "stripe_customer")
    @patch.object(Profile, "setup_premium_history")
    def test_stripe_switch_uses_no_proration_and_36_price(
        self, mock_history, mock_customer, mock_list, mock_modify
    ):
        mock_customer.return_value = MagicMock(id="cus_pricingmig")
        mock_list.return_value = MagicMock(data=[self._make_stripe_sub("newsblur-premium-24")])

        result = self.profile.switch_stripe_subscription("premium", proration_behavior="none")

        self.assertTrue(result)
        mock_modify.assert_called_once()
        _, kwargs = mock_modify.call_args
        self.assertEqual(kwargs["proration_behavior"], "none")
        self.assertNotIn("billing_cycle_anchor", kwargs)
        self.assertEqual(kwargs["items"][0]["price"], "newsblur-premium-36")

    @patch("stripe.Subscription.modify")
    @patch("stripe.Subscription.list")
    @patch.object(Profile, "stripe_customer")
    @patch.object(Profile, "setup_premium_history")
    def test_stripe_switch_default_still_always_invoice(
        self, mock_history, mock_customer, mock_list, mock_modify
    ):
        """The user-facing upgrade view depends on the always_invoice default; don't regress it."""
        mock_customer.return_value = MagicMock(id="cus_pricingmig")
        mock_list.return_value = MagicMock(data=[self._make_stripe_sub("newsblur-premium-24")])

        self.profile.switch_stripe_subscription("premium")

        _, kwargs = mock_modify.call_args
        self.assertEqual(kwargs["proration_behavior"], "always_invoice")

    @patch("stripe.Subscription.modify")
    @patch("stripe.Subscription.list")
    @patch.object(Profile, "stripe_customer")
    @patch.object(Profile, "setup_premium_history")
    def test_stripe_switch_noop_when_already_36(self, mock_history, mock_customer, mock_list, mock_modify):
        mock_customer.return_value = MagicMock(id="cus_pricingmig")
        mock_list.return_value = MagicMock(data=[self._make_stripe_sub("newsblur-premium-36")])

        result = self.profile.switch_stripe_subscription("premium", proration_behavior="none")

        self.assertTrue(result)
        mock_modify.assert_not_called()

    # --- PayPal approval link -----------------------------------------------

    @patch.object(Profile, "paypal_api")
    @patch.object(Profile, "retrieve_paypal_ids")
    def test_paypal_price_change_approval_url_uses_revise(self, mock_ids, mock_api):
        self.profile.paypal_sub_id = "I-SUB123"
        self.profile.save()
        api = MagicMock()
        api.post.return_value = {
            "links": [
                {"rel": "self", "href": "https://paypal/self"},
                {"rel": "approve", "href": "https://paypal/approve"},
            ]
        }
        mock_api.return_value = api

        url = self.profile.paypal_price_change_approval_url("premium")

        self.assertEqual(url, "https://paypal/approve")
        path, body = api.post.call_args[0]
        self.assertEqual(path, "/v1/billing/subscriptions/I-SUB123/revise")
        self.assertEqual(body["plan_id"], Profile.plan_to_paypal_plan_id("premium"))

    @patch.object(Profile, "paypal_api")
    @patch.object(Profile, "retrieve_paypal_ids")
    def test_paypal_price_change_approval_url_none_without_sub(self, mock_ids, mock_api):
        self.profile.paypal_sub_id = ""
        self.profile.save()

        self.assertIsNone(self.profile.paypal_price_change_approval_url("premium"))

    # --- Email variants render ----------------------------------------------

    def test_stripe_email_renders(self):
        from django.core import mail

        renewal = datetime.datetime(2026, 8, 1)
        self.profile.send_premium_pricing_upgrade_email(
            old_amount=24, renewal_date=renewal, variant="stripe", force=True
        )
        self.assertEqual(len(mail.outbox), 1)
        body = mail.outbox[0].body
        self.assertIn("$36", body)
        self.assertIn("$24", body)
        self.assertIn("August 1, 2026", body)

    def test_paypal_email_includes_approval_url(self):
        from django.core import mail

        self.profile.active_provider = "paypal"
        self.profile.save()
        self.profile.send_premium_pricing_upgrade_email(
            old_amount=12,
            renewal_date=datetime.datetime(2026, 8, 1),
            approval_url="https://paypal/approve-me",
            variant="paypal",
            force=True,
        )
        self.assertEqual(len(mail.outbox), 1)
        self.assertIn("https://paypal/approve-me", mail.outbox[0].body)

    def test_preview_sends_both_variants_no_record(self):
        from django.core import mail

        from apps.profile.models import MSentEmail

        self.profile.send_premium_pricing_upgrade_email(preview=True, old_amount=24)

        self.assertEqual(len(mail.outbox), 2)
        self.assertEqual(
            MSentEmail.objects.filter(
                receiver_user_id=self.user.pk, email_type="premium_pricing_upgrade"
            ).count(),
            0,
        )
        from apps.profile.models import PremiumPricingMigration

        self.assertFalse(PremiumPricingMigration.objects.filter(user=self.user).exists())

    def test_staff_would_cancel_email_renders(self):
        from django.core import mail

        self.profile.active_provider = "paypal"
        self.profile.paypal_sub_id = "I-SUB123"
        self.profile.save()
        self._add_payment(24, days_ago=400, provider="paypal")
        self._add_payment(24, days_ago=35, provider="paypal")

        self.profile.send_staff_pricing_would_cancel_email(
            old_amount=24, next_billing=datetime.datetime(2026, 8, 1)
        )

        self.assertEqual(len(mail.outbox), 1)
        msg = mail.outbox[0]
        self.assertIn("WOULD CANCEL", msg.subject)
        self.assertIn(self.user.username, msg.subject)
        self.assertIn("$24", msg.body)
        self.assertIn("I-SUB123", msg.body)
        self.assertTrue(len(msg.to) >= 1)  # sent to staff/admins

    # --- Cohort selection ----------------------------------------------------

    def test_cohort_dry_run_selects_only_grandfathered(self):
        from apps.profile.models import PremiumPricingMigration

        # Target: the setUp user, stripe, $24, in window, active.
        self._add_payment(24)

        # Excluded: already at $36.
        u36 = User.objects.create_user(username="at36", password="p", email="at36@test.com")
        p36 = u36.profile
        p36.is_premium = True
        p36.is_premium_trial = False
        p36.premium_renewal = True
        p36.active_provider = "stripe"
        p36.last_seen_on = datetime.datetime.now()
        p36.premium_expire = datetime.datetime.now() + datetime.timedelta(hours=60)
        p36.save()
        self._add_payment(36, user=u36)

        # Excluded: renewal off.
        uoff = User.objects.create_user(username="renewoff", password="p", email="off@test.com")
        poff = uoff.profile
        poff.is_premium = True
        poff.is_premium_trial = False
        poff.premium_renewal = False
        poff.active_provider = "stripe"
        poff.last_seen_on = datetime.datetime.now()
        poff.premium_expire = datetime.datetime.now() + datetime.timedelta(hours=60)
        poff.save()
        self._add_payment(24, user=uoff)

        processed = Profile.run_premium_pricing_migration(dry_run=True)

        self.assertEqual(processed, 1)
        self.assertFalse(PremiumPricingMigration.objects.exists())

    # --- Live run + idempotency ---------------------------------------------

    @patch.object(Profile, "switch_stripe_subscription", return_value=True)
    def test_live_run_is_idempotent(self, mock_switch):
        from django.core import mail

        from apps.profile.models import PremiumPricingMigration

        self._add_payment(24)

        Profile.run_premium_pricing_migration(only_username="pricingmig")
        Profile.run_premium_pricing_migration(only_username="pricingmig")

        rows = PremiumPricingMigration.objects.filter(user=self.user)
        self.assertEqual(rows.count(), 1)
        row = rows.first()
        self.assertEqual(row.status, "emailed")
        self.assertEqual(row.provider, "stripe")
        self.assertEqual(row.old_amount, 24)
        self.assertIsNotNone(row.price_switched_date)
        self.assertEqual(len(mail.outbox), 1)
        mock_switch.assert_called_once_with("premium", proration_behavior="none")

    @patch.object(Profile, "switch_stripe_subscription", return_value=True)
    def test_dry_run_makes_no_writes_or_switch(self, mock_switch):
        from django.core import mail

        from apps.profile.models import PremiumPricingMigration

        self._add_payment(24)
        Profile.run_premium_pricing_migration(dry_run=True, only_username="pricingmig")

        mock_switch.assert_not_called()
        self.assertFalse(PremiumPricingMigration.objects.filter(user=self.user).exists())
        self.assertEqual(len(mail.outbox), 0)

    # --- Reconciliation ------------------------------------------------------

    def _emailed_row(self, provider="stripe", renewal_offset_days=-1):
        from apps.profile.models import PremiumPricingMigration

        return PremiumPricingMigration.objects.create(
            user=self.user,
            provider=provider,
            old_amount=24,
            email_sent_date=datetime.datetime.now() - datetime.timedelta(days=2),
            renewal_date_at_send=datetime.datetime.now() + datetime.timedelta(days=renewal_offset_days),
            price_switched_date=datetime.datetime.now() - datetime.timedelta(days=2),
            status="emailed",
        )

    def test_reconcile_marks_upgraded_on_36_charge(self):
        row = self._emailed_row()
        self._add_payment(36, days_ago=0)  # charge after email_sent_date

        Profile.reconcile_premium_pricing_migration()

        row.refresh_from_db()
        self.assertEqual(row.status, "upgraded")

    def test_reconcile_marks_cancelled_when_renewal_off(self):
        row = self._emailed_row()
        self.profile.premium_renewal = False
        self.profile.save()

        Profile.reconcile_premium_pricing_migration()

        row.refresh_from_db()
        self.assertEqual(row.status, "cancelled")

    def _paypal_detail(self, plan_id="P-OLD-24", hours_until_billing=5, status="ACTIVE"):
        nb = (datetime.datetime.utcnow() + datetime.timedelta(hours=hours_until_billing)).strftime(
            "%Y-%m-%dT%H:%M:%SZ"
        )
        return {"status": status, "plan_id": plan_id, "billing_info": {"next_billing_time": nb}}

    @override_settings(PREMIUM_PRICING_PAYPAL_CANCEL_ENABLED=False)
    @patch.object(Profile, "send_staff_pricing_would_cancel_email")
    @patch.object(Profile, "cancel_premium_paypal")
    @patch.object(Profile, "paypal_subscription_detail")
    def test_reconcile_shadow_mode_notifies_staff_does_not_cancel(self, mock_detail, mock_cancel, mock_staff):
        # Default (shadow) mode: imminent non-approver -> notify staff, never touch PayPal.
        row = self._emailed_row(provider="paypal")
        mock_detail.return_value = self._paypal_detail(plan_id="P-OLD-24", hours_until_billing=5)

        Profile.reconcile_premium_pricing_migration()

        mock_cancel.assert_not_called()
        mock_staff.assert_called_once()
        row.refresh_from_db()
        self.assertEqual(row.status, "would_cancel")
        self.assertIsNotNone(row.would_cancel_date)

    @override_settings(PREMIUM_PRICING_PAYPAL_CANCEL_ENABLED=True)
    @patch.object(Profile, "send_staff_pricing_would_cancel_email")
    @patch.object(Profile, "cancel_premium_paypal")
    @patch.object(Profile, "paypal_subscription_detail")
    def test_reconcile_cancels_previous_shadow_paypal_row_when_enabled(
        self, mock_detail, mock_cancel, mock_staff
    ):
        # A row shadowed before cancellation was enabled must still be cancellable later.
        row = self._emailed_row(provider="paypal")
        row.status = "would_cancel"
        row.would_cancel_date = datetime.datetime.now() - datetime.timedelta(days=1)
        row.save()
        mock_detail.return_value = self._paypal_detail(plan_id="P-OLD-24", hours_until_billing=5)

        Profile.reconcile_premium_pricing_migration()

        mock_cancel.assert_called_once()
        mock_staff.assert_not_called()
        row.refresh_from_db()
        self.assertEqual(row.status, "cancelled")
        self.assertIsNotNone(row.paypal_canceled_date)

    @override_settings(PREMIUM_PRICING_PAYPAL_CANCEL_ENABLED=True)
    @patch.object(Profile, "send_staff_pricing_would_cancel_email")
    @patch.object(Profile, "cancel_premium_paypal")
    @patch.object(Profile, "paypal_subscription_detail")
    def test_reconcile_real_cancel_when_enabled(self, mock_detail, mock_cancel, mock_staff):
        # Only when explicitly enabled: imminent non-approver -> actually cancel.
        row = self._emailed_row(provider="paypal")
        mock_detail.return_value = self._paypal_detail(plan_id="P-OLD-24", hours_until_billing=5)

        Profile.reconcile_premium_pricing_migration()

        mock_cancel.assert_called_once()
        mock_staff.assert_not_called()
        row.refresh_from_db()
        self.assertEqual(row.status, "cancelled")
        self.assertIsNotNone(row.paypal_canceled_date)

    @patch.object(Profile, "send_staff_pricing_would_cancel_email")
    @patch.object(Profile, "cancel_premium_paypal")
    @patch.object(Profile, "paypal_subscription_detail")
    def test_reconcile_does_not_touch_approved_paypal(self, mock_detail, mock_cancel, mock_staff):
        # Approved the $36 plan -> leave it alone; it will renew at $36 and become upgraded.
        row = self._emailed_row(provider="paypal")
        mock_detail.return_value = self._paypal_detail(
            plan_id=Profile.plan_to_paypal_plan_id("premium"), hours_until_billing=5
        )

        Profile.reconcile_premium_pricing_migration()

        mock_cancel.assert_not_called()
        mock_staff.assert_not_called()
        row.refresh_from_db()
        self.assertEqual(row.status, "emailed")

    @patch.object(Profile, "send_staff_pricing_would_cancel_email")
    @patch.object(Profile, "cancel_premium_paypal")
    @patch.object(Profile, "paypal_subscription_detail")
    def test_reconcile_does_not_touch_paypal_when_charge_far_off(self, mock_detail, mock_cancel, mock_staff):
        # Not approved, but the next charge is far away -> wait, do not act early.
        row = self._emailed_row(provider="paypal")
        mock_detail.return_value = self._paypal_detail(plan_id="P-OLD-24", hours_until_billing=24 * 10)

        Profile.reconcile_premium_pricing_migration()

        mock_cancel.assert_not_called()
        mock_staff.assert_not_called()
        row.refresh_from_db()
        self.assertEqual(row.status, "emailed")

    def test_reconcile_no_double_count(self):
        row = self._emailed_row()
        self._add_payment(36, days_ago=0)

        Profile.reconcile_premium_pricing_migration()
        Profile.reconcile_premium_pricing_migration()

        row.refresh_from_db()
        self.assertEqual(row.status, "upgraded")

    # --- Redis lock (single-runner across the 3 beat schedulers) -------------

    @patch.object(Profile, "switch_stripe_subscription", return_value=True)
    @patch.object(Profile, "_acquire_pricing_lock", return_value="skip")
    def test_run_skips_when_lock_held(self, mock_lock, mock_switch):
        from apps.profile.models import PremiumPricingMigration

        self._add_payment(24)
        result = Profile.run_premium_pricing_migration(only_username="pricingmig")

        self.assertEqual(result, 0)
        mock_switch.assert_not_called()
        self.assertFalse(PremiumPricingMigration.objects.filter(user=self.user).exists())

    @patch.object(Profile, "cancel_premium_paypal")
    @patch.object(Profile, "_acquire_pricing_lock", return_value="skip")
    def test_reconcile_skips_when_lock_held(self, mock_lock, mock_cancel):
        row = self._emailed_row()
        self._add_payment(36, days_ago=0)

        result = Profile.reconcile_premium_pricing_migration()

        self.assertEqual(result, 0)
        mock_cancel.assert_not_called()
        row.refresh_from_db()
        self.assertEqual(row.status, "emailed")  # untouched

    # --- Resilience: a non-revisable PayPal sub or a per-user error must not crash the batch -----

    @patch.object(Profile, "paypal_api")
    @patch.object(Profile, "retrieve_paypal_ids")
    def test_paypal_approval_url_returns_none_on_api_error(self, mock_ids, mock_api):
        # PayPal revise raises ResourceInvalid (422) when a sub isn't active; we must return None,
        # not raise (which previously crashed the whole batch).
        import paypalrestsdk

        self.profile.paypal_sub_id = "I-SUB"
        self.profile.save()
        api = MagicMock()
        api.post.side_effect = paypalrestsdk.exceptions.ConnectionError(MagicMock())
        mock_api.return_value = api

        self.assertIsNone(self.profile.paypal_price_change_approval_url("premium"))

    @patch.object(Profile, "switch_stripe_subscription", side_effect=Exception("boom"))
    def test_run_isolates_per_user_errors(self, mock_switch):
        # A failure on one user must not abort the run; the row is left non-emailed (retryable).
        from apps.profile.models import PremiumPricingMigration

        self._add_payment(24)
        result = Profile.run_premium_pricing_migration(only_username="pricingmig")

        self.assertEqual(result, 0)
        row = PremiumPricingMigration.objects.filter(user=self.user).first()
        self.assertNotEqual(getattr(row, "status", None), "emailed")
