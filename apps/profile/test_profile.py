from unittest.mock import MagicMock, call, patch

from django.conf import settings
from django.contrib.auth.models import User
from django.test import TestCase
from django.test.client import Client
from django.urls import reverse

from apps.profile.models import PaymentHistory, Profile
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
