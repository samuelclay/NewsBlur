from unittest.mock import patch

from django.conf import settings
from django.contrib.auth.models import User
from django.test import TestCase
from django.test.client import Client
from django.urls import reverse

from apps.profile.models import Profile
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
        self.assertTrue(plan_id.startswith("P-"), "Pro PayPal plan ID should start with 'P-', got: %s" % plan_id)
