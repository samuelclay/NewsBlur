import datetime
import time
import traceback

import dateutil.parser
import stripe
from django.conf import settings
from django.core.management.base import BaseCommand
from django.db.models import Q

from apps.profile.models import PaymentHistory, Profile
from utils import log as logging


class Command(BaseCommand):
    help = "Audit payment history against Stripe/PayPal APIs and fix discrepancies."

    def add_arguments(self, parser):
        parser.add_argument(
            "-u",
            "--username",
            type=str,
            default=None,
            help="Audit a specific user by username",
        )
        parser.add_argument(
            "--dry-run",
            action="store_true",
            default=False,
            help="Report only, don't fix discrepancies",
        )
        parser.add_argument(
            "-o",
            "--offset",
            type=int,
            default=0,
            help="Skip first N users (for restarting interrupted runs)",
        )
        parser.add_argument(
            "-b",
            "--batch-size",
            type=int,
            default=50,
            help="Users per batch (default: 50)",
        )

    def handle(self, *args, **options):
        username = options["username"]
        dry_run = options["dry_run"]
        offset = options["offset"]
        batch_size = options["batch_size"]

        stripe.api_key = settings.STRIPE_SECRET

        if username:
            try:
                profile = Profile.objects.get(user__username=username)
            except Profile.DoesNotExist:
                self.stderr.write(f"User '{username}' not found")
                return
            result = self.audit_user(profile, dry_run=dry_run)
            self.print_user_result(profile, result)
            return

        profiles = Profile.objects.filter(is_premium=True).order_by("user__pk")
        total_users = profiles.count()
        self.stdout.write(f"Auditing {total_users} premium users (offset={offset}, batch_size={batch_size})")
        if dry_run:
            self.stdout.write("DRY RUN: no changes will be made")

        total_discrepancies = 0
        total_missing = 0
        total_fixed = 0
        users_with_issues = []
        processed = 0

        batch_num = offset // batch_size
        current_offset = offset

        while current_offset < total_users:
            batch_num += 1
            end = current_offset + batch_size
            batch_profiles = profiles[current_offset:end]
            batch_list = list(batch_profiles)
            if not batch_list:
                break

            pk_start = batch_list[0].user.pk
            pk_end = batch_list[-1].user.pk
            batch_end = current_offset + len(batch_list) - 1
            self.stdout.write(
                f"\n[batch {batch_num}] Processing users "
                f"{current_offset}-{batch_end} "
                f"(pk range {pk_start}-{pk_end})..."
            )

            batch_discrepancies = 0
            batch_missing = 0

            for profile in batch_list:
                try:
                    result = self.audit_user(profile, dry_run=dry_run)
                except Exception as e:
                    self.stderr.write(f"  Error auditing {profile.user.username}: {e}")
                    traceback.print_exc()
                    time.sleep(0.5)
                    continue

                if result["missing_payments"]:
                    batch_discrepancies += 1
                    total_discrepancies += 1
                    missing_count = len(result["missing_payments"])
                    batch_missing += missing_count
                    total_missing += missing_count
                    if not dry_run:
                        total_fixed += result["fixed_count"]
                    users_with_issues.append(profile.user.username)
                    self.print_user_result(profile, result)

                processed += 1
                time.sleep(0.5)

            current_offset += batch_size
            self.stdout.write(
                f"[batch {batch_num}] {batch_discrepancies} users with discrepancies, "
                f"{batch_missing} missing payments found"
            )
            self.stdout.write(
                f"[progress] {processed}/{total_users} users processed, offset={current_offset} to resume"
            )

        self.stdout.write(f"\n{'='*60}")
        self.stdout.write("AUDIT COMPLETE")
        self.stdout.write(f"  Users audited: {processed}")
        self.stdout.write(f"  Users with discrepancies: {total_discrepancies}")
        self.stdout.write(f"  Total missing payments: {total_missing}")
        if not dry_run:
            self.stdout.write(f"  Total payments fixed: {total_fixed}")
        if users_with_issues:
            self.stdout.write(f"  Affected users: {', '.join(users_with_issues)}")

    def audit_user(self, profile, dry_run=False):
        result = {
            "missing_payments": [],
            "extra_local": [],
            "fixed_count": 0,
        }

        # Discover all customer IDs
        if profile.stripe_id:
            try:
                profile.retrieve_stripe_ids()
            except Exception as e:
                logging.debug(f"  Error retrieving stripe IDs for {profile.user.username}: {e}")
        profile.retrieve_paypal_ids()

        # Fetch Stripe payments from API
        api_stripe_payments = {}
        if profile.stripe_id:
            for stripe_id_model in profile.user.stripe_ids.all():
                try:
                    stripe_customer = stripe.Customer.retrieve(stripe_id_model.stripe_id)
                    charges = stripe.Charge.list(customer=stripe_customer.id).data
                    for charge in charges:
                        if charge.status == "failed":
                            continue
                        created = datetime.datetime.fromtimestamp(charge.created)
                        date_key = created.date()
                        if date_key not in api_stripe_payments:
                            api_stripe_payments[date_key] = {
                                "date": created,
                                "amount": charge.amount / 100.0,
                                "refunded": True if charge.refunded else None,
                                "provider": "stripe",
                            }
                except stripe.error.InvalidRequestError as e:
                    logging.debug(
                        f"  Stripe error for {profile.user.username} ({stripe_id_model.stripe_id}): {e}"
                    )
                except Exception as e:
                    logging.debug(
                        f"  Stripe error for {profile.user.username} ({stripe_id_model.stripe_id}): {e}"
                    )

        # Fetch PayPal payments from API
        api_paypal_payments = {}
        if profile.paypal_sub_id:
            paypal_api = profile.paypal_api()
            if paypal_api:
                for paypal_id_model in profile.user.paypal_ids.all():
                    paypal_id = paypal_id_model.paypal_sub_id
                    try:
                        start_date = datetime.datetime(2009, 1, 1).strftime("%Y-%m-%dT%H:%M:%S.000Z")
                        end_date = datetime.datetime.now().strftime("%Y-%m-%dT%H:%M:%S.000Z")
                        transactions = paypal_api.get(
                            f"/v1/billing/subscriptions/{paypal_id}/transactions"
                            f"?start_time={start_date}&end_time={end_date}"
                        )
                        if transactions and "transactions" in transactions:
                            for txn in transactions["transactions"]:
                                if txn["status"] not in [
                                    "COMPLETED",
                                    "PARTIALLY_REFUNDED",
                                    "REFUNDED",
                                ]:
                                    continue
                                created = dateutil.parser.parse(txn["time"]).date()
                                if created not in api_paypal_payments:
                                    refunded = None
                                    if txn["status"] in ["PARTIALLY_REFUNDED", "REFUNDED"]:
                                        refunded = True
                                    api_paypal_payments[created] = {
                                        "date": created,
                                        "amount": int(
                                            float(txn["amount_with_breakdown"]["gross_amount"]["value"])
                                        ),
                                        "refunded": refunded,
                                        "provider": "paypal",
                                    }
                    except Exception as e:
                        logging.debug(f"  PayPal error for {profile.user.username} ({paypal_id}): {e}")

            # Also check IPN records
            from paypal.standard.ipn.models import PayPalIPN

            ipns = PayPalIPN.objects.filter(
                Q(custom=profile.user.username)
                | Q(payer_email=profile.user.email)
                | Q(custom=profile.user.pk)
            ).order_by("-payment_date")
            for ipn in ipns:
                if ipn.txn_type != "subscr_payment":
                    continue
                created = ipn.payment_date.date()
                if created not in api_paypal_payments:
                    api_paypal_payments[created] = {
                        "date": created,
                        "amount": int(ipn.payment_gross) if ipn.payment_gross else 0,
                        "refunded": None,
                        "provider": "paypal",
                    }

        # Compare with local PaymentHistory
        local_payments = PaymentHistory.objects.filter(user=profile.user)
        local_stripe_dates = set()
        local_paypal_dates = set()
        for payment in local_payments:
            if payment.payment_provider == "stripe":
                local_stripe_dates.add(payment.payment_date.date())
            elif payment.payment_provider == "paypal":
                local_paypal_dates.add(payment.payment_date.date())

        # Find missing Stripe payments (in API but not local)
        for date_key, payment_data in api_stripe_payments.items():
            if date_key not in local_stripe_dates:
                result["missing_payments"].append(payment_data)
                if not dry_run:
                    try:
                        PaymentHistory.objects.get_or_create(
                            user=profile.user,
                            payment_date=payment_data["date"],
                            payment_amount=payment_data["amount"],
                            payment_provider="stripe",
                            refunded=payment_data["refunded"],
                        )
                        result["fixed_count"] += 1
                    except PaymentHistory.MultipleObjectsReturned:
                        pass

        # Find missing PayPal payments (in API/IPN but not local)
        for date_key, payment_data in api_paypal_payments.items():
            if date_key not in local_paypal_dates:
                result["missing_payments"].append(payment_data)
                if not dry_run:
                    try:
                        PaymentHistory.objects.get_or_create(
                            user=profile.user,
                            payment_date=payment_data["date"],
                            payment_amount=payment_data["amount"],
                            payment_provider="paypal",
                            refunded=payment_data["refunded"],
                        )
                        result["fixed_count"] += 1
                    except PaymentHistory.MultipleObjectsReturned:
                        pass

        # Find extra local payments (local but not in API -- informational only, never delete)
        for date_key in local_stripe_dates:
            if date_key not in api_stripe_payments:
                result["extra_local"].append({"date": date_key, "provider": "stripe"})
        for date_key in local_paypal_dates:
            if date_key not in api_paypal_payments:
                result["extra_local"].append({"date": date_key, "provider": "paypal"})

        return result

    def print_user_result(self, profile, result):
        username = profile.user.username
        if result["missing_payments"]:
            self.stdout.write(f"\n  {username}: {len(result['missing_payments'])} missing payments")
            for p in result["missing_payments"]:
                self.stdout.write(f"    MISSING: {p['date']} ${p['amount']} ({p['provider']})")
            if result["fixed_count"]:
                self.stdout.write(f"    FIXED: {result['fixed_count']} payments added")
        if result["extra_local"]:
            self.stdout.write(f"  {username}: {len(result['extra_local'])} extra local payments (not in API)")
            for p in result["extra_local"]:
                self.stdout.write(f"    EXTRA: {p['date']} ({p['provider']}) - kept, not deleted")
