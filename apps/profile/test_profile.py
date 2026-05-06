from unittest.mock import MagicMock, call, patch

from django.conf import settings
from django.contrib.auth.models import User
from django.test import TestCase
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
        archive_fetch = patch("apps.reader.models.UserSubscription.schedule_fetch_archive_feeds_for_user").start()
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
        m["email_staff"].assert_called_once()
        self.assertEqual(m["email_staff"].call_args.kwargs["previous_tier"], "free")
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
        m["email_staff"].assert_called_once()
        self.assertEqual(m["email_staff"].call_args.kwargs["previous_tier"], "trial")
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
        self.assertEqual(m["email_staff"].call_count, 1, "staff email must send exactly once")


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
