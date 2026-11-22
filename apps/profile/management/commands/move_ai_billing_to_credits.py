"""Move usage billing subscriptions from the per-classification prices to AI credits.

move_ai_billing_to_credits.py: Before AI credits, usage billing charged $0.0015 for every
story a text filter checked and $0.0075 for every image check, through two metered prices.
This swaps each subscription that still has them for the 1 cent AI credit price
(STRIPE_PRICE_AI_CREDITS) and the $10 billing threshold, keeping the subscription itself.
apps/analyzer/ai_credits.py then reports overage past the plan's credits to it. Run it after
the deploy that ships credits. Without --commit it only lists what it would change.
"""

import stripe
from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

from apps.analyzer import ai_credits
from apps.profile.models import Profile


class Command(BaseCommand):
    help = "Swap old per-classification usage billing prices for the AI credit price."

    def add_arguments(self, parser):
        parser.add_argument("--commit", action="store_true", help="Change the subscriptions.")

    def handle(self, *args, **options):
        if not ai_credits.is_billing_available():
            raise CommandError("STRIPE_PRICE_AI_CREDITS isn't set; run create_ai_credit_price first.")
        stripe.api_key = settings.STRIPE_SECRET
        old_price_ids = set(
            filter(None, [settings.STRIPE_PRICE_TEXT_CLASSIFICATION, settings.STRIPE_PRICE_IMAGE_CLASSIFICATION])
        )
        commit = options["commit"]
        moved = 0

        for profile in Profile.objects.filter(is_usage_billing=True).exclude(stripe_id=None).exclude(stripe_id=""):
            try:
                subscriptions = stripe.Subscription.list(customer=profile.stripe_id, status="active", limit=20)
            except stripe.error.StripeError as e:
                self.stdout.write("%s: couldn't list subscriptions: %s" % (profile.user.username, e))
                continue
            for subscription in subscriptions.data:
                items = subscription["items"].data
                old_items = [item for item in items if item.price and item.price.id in old_price_ids]
                if not old_items:
                    continue
                has_credit_price = any(
                    item.price and item.price.id == settings.STRIPE_PRICE_AI_CREDITS for item in items
                )
                changes = [{"id": item.id, "deleted": True} for item in old_items]
                if not has_credit_price:
                    changes.append({"price": settings.STRIPE_PRICE_AI_CREDITS})
                self.stdout.write(
                    "%s %s: %s %s"
                    % (
                        "Moving" if commit else "Would move",
                        profile.user.username,
                        subscription.id,
                        ", ".join(item.price.id for item in old_items),
                    )
                )
                if not commit:
                    continue
                try:
                    stripe.Subscription.modify(
                        subscription.id,
                        items=changes,
                        proration_behavior="none",
                        billing_thresholds={"amount_gte": ai_credits.BILLING_THRESHOLD_CENTS},
                    )
                    moved += 1
                except stripe.error.StripeError as e:
                    self.stdout.write("%s: couldn't move %s: %s" % (profile.user.username, subscription.id, e))

        self.stdout.write("Moved %s subscriptions" % moved if commit else "Dry run; pass --commit to move them")
