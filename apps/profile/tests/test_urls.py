"""
URL tests for the profile app.

Tests URL resolution and basic access patterns for all profile endpoints.
"""

import pytest
from django.test import Client, TransactionTestCase
from django.urls import resolve, reverse


class Test_ProfileURLResolution(TransactionTestCase):
    """Test that all profile URLs resolve correctly."""

    def test_get_preference_resolves(self):
        """Test get preference URL resolves."""
        url = "/profile/get_preferences"
        resolved = resolve(url)
        assert resolved.func.__name__ == "get_preference"

    def test_set_preference_resolves(self):
        """Test set preference URL resolves."""
        url = "/profile/set_preference/"
        resolved = resolve(url)
        assert resolved.func.__name__ == "set_preference"

    def test_set_account_settings_resolves(self):
        """Test set account settings URL resolves."""
        url = "/profile/set_account_settings/"
        resolved = resolve(url)
        assert resolved.func.__name__ == "set_account_settings"

    def test_get_view_setting_resolves(self):
        """Test get view setting URL resolves."""
        url = "/profile/get_view_setting/"
        resolved = resolve(url)
        assert resolved.func.__name__ == "get_view_setting"

    def test_set_view_setting_resolves(self):
        """Test set view setting URL resolves."""
        url = "/profile/set_view_setting/"
        resolved = resolve(url)
        assert resolved.func.__name__ == "set_view_setting"

    def test_clear_view_setting_resolves(self):
        """Test clear view setting URL resolves."""
        url = "/profile/clear_view_setting/"
        resolved = resolve(url)
        assert resolved.func.__name__ == "clear_view_setting"

    def test_set_collapsed_folders_resolves(self):
        """Test set collapsed folders URL resolves."""
        url = "/profile/set_collapsed_folders/"
        resolved = resolve(url)
        assert resolved.func.__name__ == "set_collapsed_folders"

    def test_paypal_form_resolves(self):
        """Test paypal form URL resolves."""
        url = "/profile/paypal_form/"
        resolved = resolve(url)
        assert resolved.func.__name__ == "paypal_form"

    def test_paypal_return_resolves(self):
        """Test paypal return URL resolves."""
        url = reverse("paypal-return")
        resolved = resolve(url)
        assert resolved.view_name == "paypal-return"

    def test_paypal_archive_return_resolves(self):
        """Test paypal archive return URL resolves."""
        url = reverse("paypal-archive-return")
        resolved = resolve(url)
        assert resolved.view_name == "paypal-archive-return"

    def test_paypal_pro_return_resolves(self):
        """Test paypal pro return URL resolves."""
        url = reverse("paypal-pro-return")
        resolved = resolve(url)
        assert resolved.view_name == "paypal-pro-return"

    def test_stripe_return_resolves(self):
        """Test stripe return URL resolves."""
        url = reverse("stripe-return")
        resolved = resolve(url)
        assert resolved.view_name == "stripe-return"

    def test_switch_stripe_subscription_resolves(self):
        """Test switch stripe subscription URL resolves."""
        url = reverse("switch-stripe-subscription")
        resolved = resolve(url)
        assert resolved.view_name == "switch-stripe-subscription"

    def test_switch_paypal_subscription_resolves(self):
        """Test switch paypal subscription URL resolves."""
        url = reverse("switch-paypal-subscription")
        resolved = resolve(url)
        assert resolved.view_name == "switch-paypal-subscription"

    def test_profile_is_premium_resolves(self):
        """Test profile is premium URL resolves."""
        url = reverse("profile-is-premium")
        resolved = resolve(url)
        assert resolved.view_name == "profile-is-premium"

    def test_profile_is_premium_archive_resolves(self):
        """Test profile is premium archive URL resolves."""
        url = reverse("profile-is-premium-archive")
        resolved = resolve(url)
        assert resolved.view_name == "profile-is-premium-archive"

    def test_activate_premium_trial_resolves(self):
        """Test activate premium trial URL resolves."""
        url = reverse("activate-premium-trial")
        resolved = resolve(url)
        assert resolved.view_name == "activate-premium-trial"

    def test_paypal_ipn_resolves(self):
        """Test paypal IPN URL resolves."""
        url = reverse("paypal-ipn")
        resolved = resolve(url)
        assert resolved.view_name == "paypal-ipn"

    def test_paypal_webhooks_resolves(self):
        """Test paypal webhooks URL resolves."""
        url = reverse("paypal-webhooks")
        resolved = resolve(url)
        assert resolved.view_name == "paypal-webhooks"

    def test_stripe_form_resolves(self):
        """Test stripe form URL resolves."""
        url = reverse("stripe-form")
        resolved = resolve(url)
        assert resolved.view_name == "stripe-form"

    def test_stripe_checkout_resolves(self):
        """Test stripe checkout URL resolves."""
        url = reverse("stripe-checkout")
        resolved = resolve(url)
        assert resolved.view_name == "stripe-checkout"

    def test_profile_activities_resolves(self):
        """Test profile activities URL resolves."""
        url = reverse("profile-activities")
        resolved = resolve(url)
        assert resolved.view_name == "profile-activities"

    def test_profile_payment_history_resolves(self):
        """Test profile payment history URL resolves."""
        url = reverse("profile-payment-history")
        resolved = resolve(url)
        assert resolved.view_name == "profile-payment-history"

    def test_profile_invoice_resolves(self):
        """Test profile invoice URL resolves."""
        url = reverse("profile-invoice", kwargs={"payment_id": "1"})
        resolved = resolve(url)
        assert resolved.view_name == "profile-invoice"

    def test_profile_cancel_premium_resolves(self):
        """Test profile cancel premium URL resolves."""
        url = reverse("profile-cancel-premium")
        resolved = resolve(url)
        assert resolved.view_name == "profile-cancel-premium"

    def test_profile_refund_premium_resolves(self):
        """Test profile refund premium URL resolves."""
        url = reverse("profile-refund-premium")
        resolved = resolve(url)
        assert resolved.view_name == "profile-refund-premium"

    def test_profile_never_expire_premium_resolves(self):
        """Test profile never expire premium URL resolves."""
        url = reverse("profile-never-expire-premium")
        resolved = resolve(url)
        assert resolved.view_name == "profile-never-expire-premium"

    def test_profile_upgrade_premium_resolves(self):
        """Test profile upgrade premium URL resolves."""
        url = reverse("profile-upgrade-premium")
        resolved = resolve(url)
        assert resolved.view_name == "profile-upgrade-premium"

    def test_save_ios_receipt_resolves(self):
        """Test save iOS receipt URL resolves."""
        url = reverse("save-ios-receipt")
        resolved = resolve(url)
        assert resolved.view_name == "save-ios-receipt"

    def test_save_android_receipt_resolves(self):
        """Test save Android receipt URL resolves."""
        url = reverse("save-android-receipt")
        resolved = resolve(url)
        assert resolved.view_name == "save-android-receipt"

    def test_profile_update_payment_history_resolves(self):
        """Test profile update payment history URL resolves."""
        url = reverse("profile-update-payment-history")
        resolved = resolve(url)
        assert resolved.view_name == "profile-update-payment-history"

    def test_profile_delete_account_resolves(self):
        """Test profile delete account URL resolves."""
        url = reverse("profile-delete-account")
        resolved = resolve(url)
        assert resolved.view_name == "profile-delete-account"

    def test_profile_forgot_password_return_resolves(self):
        """Test profile forgot password return URL resolves."""
        url = reverse("profile-forgot-password-return")
        resolved = resolve(url)
        assert resolved.view_name == "profile-forgot-password-return"

    def test_profile_forgot_password_resolves(self):
        """Test profile forgot password URL resolves."""
        url = reverse("profile-forgot-password")
        resolved = resolve(url)
        assert resolved.view_name == "profile-forgot-password"

    def test_profile_delete_starred_stories_resolves(self):
        """Test profile delete starred stories URL resolves."""
        url = reverse("profile-delete-starred-stories")
        resolved = resolve(url)
        assert resolved.view_name == "profile-delete-starred-stories"

    def test_profile_count_starred_stories_resolves(self):
        """Test profile count starred stories URL resolves."""
        url = reverse("profile-count-starred-stories")
        resolved = resolve(url)
        assert resolved.view_name == "profile-count-starred-stories"

    def test_profile_count_shared_stories_resolves(self):
        """Test profile count shared stories URL resolves."""
        url = reverse("profile-count-shared-stories")
        resolved = resolve(url)
        assert resolved.view_name == "profile-count-shared-stories"

    def test_profile_delete_shared_stories_resolves(self):
        """Test profile delete shared stories URL resolves."""
        url = reverse("profile-delete-shared-stories")
        resolved = resolve(url)
        assert resolved.view_name == "profile-delete-shared-stories"

    def test_profile_delete_all_sites_resolves(self):
        """Test profile delete all sites URL resolves."""
        url = reverse("profile-delete-all-sites")
        resolved = resolve(url)
        assert resolved.view_name == "profile-delete-all-sites"

    def test_profile_email_optout_resolves(self):
        """Test profile email optout URL resolves."""
        url = reverse("profile-email-optout")
        resolved = resolve(url)
        assert resolved.view_name == "profile-email-optout"

    def test_profile_ios_subscription_status_resolves(self):
        """Test profile iOS subscription status URL resolves."""
        url = reverse("profile-ios-subscription-status")
        resolved = resolve(url)
        assert resolved.view_name == "profile-ios-subscription-status"

    def test_trigger_error_resolves(self):
        """Test trigger error URL resolves."""
        url = reverse("trigger-error")
        resolved = resolve(url)
        assert resolved.view_name == "trigger-error"


class Test_ProfileURLAccess(TransactionTestCase):
    """Test access patterns for profile URLs."""

    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
    ]

    def setUp(self):
        from django.contrib.auth.models import User

        self.client = Client()
        self.user = User.objects.create_user(username="testuser", password="testpass", email="test@test.com")

    def test_get_preference_authenticated(self):
        """Test authenticated access to get preference."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get("/profile/get_preferences")
        assert response.status_code == 200

    def test_profile_is_premium_authenticated(self):
        """Test authenticated access to profile is premium."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("profile-is-premium"), {"retries": "0"})
        assert response.status_code == 200

        # Verify response contains expected fields
        data = response.json()
        assert "is_premium" in data
        assert "is_premium_archive" in data
        assert "code" in data

    def test_profile_activities_authenticated(self):
        """Test authenticated access to profile activities."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("profile-activities"))
        assert response.status_code == 200

    def test_profile_payment_history_authenticated(self):
        """Test authenticated access to profile payment history."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("profile-payment-history"))
        assert response.status_code == 200

    def test_profile_count_starred_stories_authenticated(self):
        """Test authenticated access to count starred stories."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("profile-count-starred-stories"))
        assert response.status_code == 200

    def test_profile_count_shared_stories_authenticated(self):
        """Test authenticated access to count shared stories."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("profile-count-shared-stories"))
        assert response.status_code == 200

    def test_forgot_password_anonymous(self):
        """Test anonymous access to forgot password."""
        response = self.client.get(reverse("profile-forgot-password"))
        assert response.status_code in [200, 302]

    def test_email_optout_anonymous(self):
        """Test anonymous access to email optout."""
        response = self.client.get(reverse("profile-email-optout"))
        assert response.status_code in [200, 302, 400]


class Test_ProfileURLPOST(TransactionTestCase):
    """Test POST endpoints for profile URLs."""

    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
    ]

    def setUp(self):
        from django.contrib.auth.models import User

        self.client = Client()
        self.user = User.objects.create_user(username="testuser", password="testpass", email="test@test.com")

    def test_set_preference_post(self):
        """Test POST to set preference."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.post("/profile/set_preference/", {"preference": "test", "value": "123"})
        assert response.status_code in [200, 302, 400]

    def test_set_account_settings_post(self):
        """Test POST to set account settings."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.post("/profile/set_account_settings/", {"username": "testuser"})
        assert response.status_code in [200, 302, 400]

    def test_set_view_setting_post(self):
        """Test POST to set view setting."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.post("/profile/set_view_setting/", {"feed_id": "1", "setting": "split"})
        assert response.status_code in [200, 302, 400]

    def test_set_collapsed_folders_post(self):
        """Test POST to set collapsed folders and verify database persistence."""
        self.client.login(username="testuser", password="testpass")

        collapsed_folders_json = '["folder1", "folder2"]'
        response = self.client.post("/profile/set_collapsed_folders/", {"collapsed_folders": collapsed_folders_json})
        assert response.status_code == 200

        # Verify database state
        self.user.profile.refresh_from_db()
        assert self.user.profile.collapsed_folders == collapsed_folders_json

    def test_activate_premium_trial_post(self):
        """Test POST to activate premium trial."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.post(reverse("activate-premium-trial"))
        assert response.status_code in [200, 302, 400]

    def test_forgot_password_post(self):
        """Test POST to forgot password."""
        response = self.client.post(reverse("profile-forgot-password"), {"email": "test@test.com"})
        assert response.status_code in [200, 302, 400]

    def test_delete_starred_stories_post(self):
        """Test POST to delete starred stories."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.post(reverse("profile-delete-starred-stories"), {"timestamp": "0"})
        assert response.status_code in [200, 302, 400]

    def test_delete_shared_stories_post(self):
        """Test POST to delete shared stories."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.post(reverse("profile-delete-shared-stories"), {"timestamp": "0"})
        assert response.status_code in [200, 302, 400]
