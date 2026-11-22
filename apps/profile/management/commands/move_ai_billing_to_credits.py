"""Move readers on the old per-classification usage billing to AI credits.

move_ai_billing_to_credits.py: Before AI credits, usage billing charged $0.0015 for every story
a text filter checked and $0.0075 for every image check, through a metered subscription. AI
credits charge the card on file with invoices instead (apps/analyzer/ai_credits.py
charge_unbilled). For each reader with usage billing, this makes the subscription's card the
customer's card for invoices and ends the subscription when its current period does, so
usage already counted at the old prices is billed as usual and nothing after it is. A reader
without a card left on file has usage billing turned off. Run it after the deploy that ships
credits. Without --commit it only lists what it would change.
"""

import stripe
from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

from apps.analyzer import ai_credits
from apps.profile.models import Profile


class Command(BaseCommand):
    help = "End old per-classification usage billing subscriptions and keep their cards for AI credits."

    def add_arguments(self, parser):
        parser.add_argument("--commit", action="store_true", help="Change the subscriptions.")

    def handle(self, *args, **options):
        if not ai_credits.is_billing_available():
            raise CommandError("AI_CREDITS_USAGE_BILLING isn't on in settings.")
        stripe.api_key = settings.STRIPE_SECRET
        commit = options["commit"]
        moved = 0

        profiles = Profile.objects.filter(is_usage_billing=True).exclude(stripe_id=None).exclude(stripe_id="")
        for profile in profiles:
            username = profile.user.username
            try:
                customer = stripe.Customer.retrieve(profile.stripe_id)
                subscriptions = stripe.Subscription.list(
                    customer=profile.stripe_id, status="active", limit=20
                )
            except stripe.error.StripeError as e:
                self.stdout.write("%s: couldn't read Stripe: %s" % (username, e))
                continue
            card = (customer.get("invoice_settings") or {}).get("default_payment_method")
            old_subscriptions = [s for s in subscriptions.data if Profile.is_usage_billing_subscription(s)]
            for subscription in old_subscriptions:
                card = card or subscription.get("default_payment_method")
            self.stdout.write(
                "%s %s: ending %s at period end, %s"
                % (
                    "Moving" if commit else "Would move",
                    username,
                    ", ".join(s.id for s in old_subscriptions) or "no old subscription",
                    "keeping card %s" % card if card else "no card, turning usage billing off",
                )
            )
            if not commit:
                continue
            try:
                if card:
                    stripe.Customer.modify(
                        profile.stripe_id, invoice_settings={"default_payment_method": card}
                    )
                for subscription in old_subscriptions:
                    stripe.Subscription.modify(subscription.id, cancel_at_period_end=True)
            except stripe.error.StripeError as e:
                self.stdout.write("%s: couldn't move: %s" % (username, e))
                continue
            if not card:
                profile.is_usage_billing = False
                profile.save()
            moved += 1

        self.stdout.write("Moved %s readers" % moved if commit else "Dry run; pass --commit to move them")
