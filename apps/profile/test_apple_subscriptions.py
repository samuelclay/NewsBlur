import datetime
from unittest.mock import patch

from django.contrib.auth.models import User
from django.test import TestCase

from apps.profile.apple_subscriptions import apply_verified_apple_transaction
from apps.profile.models import PaymentHistory, Profile


class Test_AppleSubscriptions(TestCase):
    real_setup_premium_history = staticmethod(Profile.setup_premium_history)

    def setUp(self):
        for target in (
            "apps.profile.tasks.EmailNewPremiumTrial.delay",
            "apps.profile.tasks.EmailNewPremium.delay",
            "apps.profile.tasks.EmailNewPremiumPro.delay",
            "apps.profile.tasks.EmailStaffPremiumUpgrade.delay",
            "apps.profile.models.SchedulePremiumSetup.apply_async",
            "apps.profile.models.UserSubscription.queue_new_feeds",
            "apps.profile.models.UserSubscription.schedule_fetch_archive_feeds_for_user",
            "apps.profile.models.Profile.setup_premium_history",
        ):
            patcher = patch(target)
            patcher.start()
            self.addCleanup(patcher.stop)
        self.now = datetime.datetime.now().replace(microsecond=0)
        self.user = User.objects.create_user(username="apple-renewal")
        Profile.objects.filter(user=self.user).update(
            is_premium=False, is_premium_trial=False, premium_expire=self.now - datetime.timedelta(days=5)
        )
        self.original = PaymentHistory.objects.create(
            user=self.user,
            payment_date=self.now - datetime.timedelta(days=370),
            payment_amount=36,
            payment_provider="ios-subscription",
            payment_identifier="1000000000001",
        )
        self.purchase = self.now - datetime.timedelta(days=2)
        self.expiration = self.purchase + datetime.timedelta(days=365)
        self.payload = {
            "environment": "Production",
            "productId": "newsblur_premium_auto_renew_36",
            "transactionId": "1000000000002",
            "originalTransactionId": self.original.payment_identifier,
            "purchaseDate": int(self.purchase.timestamp() * 1000),
            "expiresDate": int(self.expiration.timestamp() * 1000),
        }

    def apply(self, **changes):
        return apply_verified_apple_transaction({**self.payload, **changes}, now=self.now)

    def test_renewal_restores_free_account_with_verified_expiration(self):
        self.assertEqual(self.apply()["status"], "processed")
        profile = Profile.objects.get(user=self.user)
        self.assertTrue(profile.is_premium)
        self.assertFalse(profile.is_premium_trial)
        self.assertEqual(profile.premium_expire, self.expiration)
        payment = PaymentHistory.objects.get(payment_identifier=self.payload["transactionId"])
        self.assertEqual(payment.payment_date, self.purchase)
        self.assertEqual(payment.apple_expires_date, self.expiration)
        self.assertEqual(payment.apple_original_transaction_id, self.payload["originalTransactionId"])

    def test_replay_does_not_duplicate_payment_or_extend_expiration(self):
        self.apply()
        self.assertEqual(self.apply()["status"], "duplicate")
        self.assertEqual(PaymentHistory.objects.filter(user=self.user).count(), 2)
        self.assertEqual(Profile.objects.get(user=self.user).premium_expire, self.expiration)

    def test_out_of_order_event_does_not_shorten_later_entitlement(self):
        later = self.expiration + datetime.timedelta(days=30)
        Profile.objects.filter(user=self.user).update(is_premium=True, premium_expire=later)
        self.apply()
        self.assertEqual(Profile.objects.get(user=self.user).premium_expire, later)

    def test_paid_cross_tier_purchase_is_left_for_manual_reconciliation(self):
        previous_expiration = self.now + datetime.timedelta(days=300)
        Profile.objects.filter(user=self.user).update(is_premium=True, premium_expire=previous_expiration)
        expiration = self.now + datetime.timedelta(days=30)
        result = self.apply(productId="newsblur_premium_pro", expiresDate=int(expiration.timestamp() * 1000))
        self.assertEqual(result["reason"], "cross-tier")
        profile = Profile.objects.get(user=self.user)
        self.assertFalse(profile.is_pro)
        self.assertEqual(profile.premium_expire, previous_expiration)

    def test_ambiguous_mapping_is_rejected(self):
        other = User.objects.create_user(username="other-apple-renewal")
        PaymentHistory.objects.create(
            user=other,
            payment_date=self.now,
            payment_amount=36,
            payment_provider="ios-subscription",
            payment_identifier=self.original.payment_identifier,
        )
        self.assertEqual(self.apply()["status"], "ambiguous")
        self.assertFalse(Profile.objects.get(user=self.user).is_premium)

    def test_unmatched_mapping_is_rejected(self):
        self.assertEqual(self.apply(originalTransactionId="999", transactionId="998")["status"], "unmatched")

    def test_same_period_legacy_receipt_is_reconciled_without_losing_mapping(self):
        self.original.payment_date = self.purchase + datetime.timedelta(days=1)
        self.original.save()
        self.apply()
        self.original.refresh_from_db()
        self.assertEqual(PaymentHistory.objects.filter(user=self.user).count(), 1)
        self.assertEqual(self.original.payment_identifier, self.payload["transactionId"])
        self.assertEqual(self.original.apple_original_transaction_id, self.payload["originalTransactionId"])
        self.assertEqual(self.original.payment_date, self.purchase)
        self.assertEqual(self.apply(transactionId="1000000000003")["status"], "processed")

    def test_legacy_client_replay_matches_verified_original_id(self):
        self.original.delete()
        PaymentHistory.objects.create(
            user=self.user,
            payment_date=self.purchase,
            payment_amount=36,
            payment_provider="ios-subscription",
            payment_identifier=self.payload["transactionId"],
            apple_original_transaction_id=self.payload["originalTransactionId"],
            apple_expires_date=self.expiration,
        )
        self.assertFalse(self.user.profile.activate_ios_premium(self.payload["originalTransactionId"]))
        self.assertEqual(PaymentHistory.objects.filter(user=self.user).count(), 1)

    def test_ineligible_transactions_do_not_write_payments(self):
        for changes in (
            {"environment": "Sandbox"},
            {"revocationDate": self.payload["purchaseDate"]},
            {"isUpgraded": True},
            {"expiresDate": int((self.now - datetime.timedelta(days=1)).timestamp() * 1000)},
            {"productId": "unknown"},
        ):
            with self.subTest(changes=changes):
                self.assertEqual(self.apply(**changes)["status"], "ignored")
        self.assertEqual(PaymentHistory.objects.filter(user=self.user).count(), 1)
        self.assertFalse(Profile.objects.get(user=self.user).is_premium)

    def test_archive_and_pro_activate_correct_tier(self):
        for product, archive, pro in (
            ("newsblur_premium_archive", True, False),
            ("newsblur_premium_pro", True, True),
        ):
            with self.subTest(product=product):
                Profile.objects.filter(user=self.user).update(
                    is_premium=False, is_archive=False, is_pro=False
                )
                self.apply(productId=product, transactionId=product)
                profile = Profile.objects.get(user=self.user)
                self.assertEqual(profile.is_archive, archive)
                self.assertEqual(profile.is_pro, pro)
                self.assertEqual(profile.premium_expire, self.expiration)

    def test_lifetime_entitlement_is_preserved(self):
        Profile.objects.filter(user=self.user).update(is_premium=True, premium_expire=None)
        self.assertEqual(self.apply()["reason"], "lifetime")
        self.assertIsNone(Profile.objects.get(user=self.user).premium_expire)
        self.assertEqual(PaymentHistory.objects.filter(user=self.user).count(), 1)

    def test_lower_tier_cannot_extend_higher_tier(self):
        expiry = self.now + datetime.timedelta(days=3)
        Profile.objects.filter(user=self.user).update(
            is_premium=True, is_archive=True, is_pro=True, premium_expire=expiry
        )
        self.apply()
        profile = Profile.objects.get(user=self.user)
        self.assertTrue(profile.is_pro)
        self.assertEqual(profile.premium_expire, expiry)

    def test_verified_expiration_is_not_reinferred_from_price_or_cadence(self):
        self.apply()
        payments = PaymentHistory.objects.filter(user=self.user)
        expiration, lifetime, count = Profile.premium_expire_from_payments(payments)
        self.assertEqual(expiration, self.expiration)
        self.assertFalse(lifetime)
        self.assertEqual(count, 1)

    def test_invalid_dates_raise_without_writes(self):
        with self.assertRaises(ValueError):
            self.apply(purchaseDate="not-a-date")
        self.assertEqual(PaymentHistory.objects.filter(user=self.user).count(), 1)

    def test_original_id_client_replay_near_period_end_is_not_another_payment(self):
        self.apply()
        payment = PaymentHistory.objects.get(payment_identifier=self.payload["transactionId"])
        payment.payment_date = self.now - datetime.timedelta(days=340)
        payment.apple_expires_date = self.now + datetime.timedelta(days=25)
        payment.save()
        self.assertFalse(self.user.profile.activate_ios_premium(self.payload["originalTransactionId"]))
        self.assertEqual(PaymentHistory.objects.filter(user=self.user).count(), 2)

    def test_history_dedup_keeps_verified_record_and_exact_expiration(self):
        self.apply()
        signed = PaymentHistory.objects.get(payment_identifier=self.payload["transactionId"])
        for identifier in (self.payload["transactionId"], "different-legacy-receipt"):
            PaymentHistory.objects.create(
                user=self.user,
                payment_date=self.purchase - datetime.timedelta(seconds=1),
                payment_amount=36,
                payment_provider="ios-subscription",
                payment_identifier=identifier,
            )
        self.real_setup_premium_history(self.user.profile)
        self.assertTrue(PaymentHistory.objects.filter(pk=signed.pk).exists())
        self.assertEqual(PaymentHistory.objects.filter(user=self.user).count(), 2)
        self.assertEqual(Profile.objects.get(user=self.user).premium_expire, self.expiration)

    def test_prior_legacy_monthly_payment_cannot_infer_extra_year(self):
        self.original.payment_date = self.purchase - datetime.timedelta(days=30)
        self.original.payment_provider = "ios-pro-subscription"
        self.original.payment_amount = 29
        self.original.save()
        expiration = self.purchase + datetime.timedelta(days=30)
        self.apply(productId="newsblur_premium_pro", expiresDate=int(expiration.timestamp() * 1000))
        calculated, _, count = Profile.premium_expire_from_payments(
            PaymentHistory.objects.filter(user=self.user)
        )
        self.assertEqual(calculated, expiration)
        self.assertEqual(count, 1)

    def test_two_distinct_verified_same_day_transactions_survive_history_sync(self):
        self.apply()
        self.apply(transactionId="1000000000003")
        self.real_setup_premium_history(self.user.profile)
        self.assertEqual(
            PaymentHistory.objects.filter(user=self.user, apple_expires_date__isnull=False).count(), 2
        )

    def test_stale_replay_preserves_verified_renewal_extension(self):
        extension = self.expiration + datetime.timedelta(days=14)
        self.apply(expiresDate=int(extension.timestamp() * 1000))
        self.apply()
        self.assertEqual(
            PaymentHistory.objects.get(payment_identifier=self.payload["transactionId"]).apple_expires_date,
            extension,
        )
        self.assertEqual(Profile.objects.get(user=self.user).premium_expire, extension)

    def test_retry_after_activation_failure_repairs_existing_payment(self):
        with patch.object(Profile, "activate_premium", side_effect=RuntimeError("activation failed")):
            with self.assertRaises(RuntimeError):
                self.apply()
        self.assertTrue(
            PaymentHistory.objects.filter(payment_identifier=self.payload["transactionId"]).exists()
        )
        self.assertFalse(Profile.objects.get(user=self.user).is_premium)
        self.assertEqual(self.apply()["status"], "duplicate")
        self.assertTrue(Profile.objects.get(user=self.user).is_premium)
        self.assertEqual(PaymentHistory.objects.filter(user=self.user).count(), 2)

    def test_finalization_preserves_concurrent_paid_or_lifetime_extension(self):
        for expiration in (self.expiration + datetime.timedelta(days=30), None):
            with self.subTest(expiration=expiration):
                Profile.objects.filter(user=self.user).update(is_premium=False, premium_expire=self.now)

                def concurrent_renewal():
                    Profile.objects.filter(user=self.user).update(is_premium=True, premium_expire=expiration)

                with patch.object(Profile, "activate_premium", side_effect=concurrent_renewal):
                    self.apply()
                self.assertEqual(Profile.objects.get(user=self.user).premium_expire, expiration)

    def test_finalization_preserves_concurrent_tier_change(self):
        pro_expiration = self.now + datetime.timedelta(days=30)

        def concurrent_upgrade():
            Profile.objects.filter(user=self.user).update(
                is_premium=True, is_archive=True, is_pro=True, premium_expire=pro_expiration
            )

        with patch.object(Profile, "activate_premium", side_effect=concurrent_upgrade):
            self.apply()
        self.assertEqual(Profile.objects.get(user=self.user).premium_expire, pro_expiration)
