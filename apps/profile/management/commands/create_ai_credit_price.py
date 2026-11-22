"""Create the Stripe meter and metered price that usage billing for AI credits bills with.

create_ai_credit_price.py: Run once per Stripe mode (test with DEBUG, live without), then put
the printed STRIPE_PRICE_AI_CREDITS in the secrets repo's settings. Running it again finds
what it made before instead of making another, by the meter's event name and the price's
lookup key. apps/analyzer/ai_credits.py reports overage credits to the meter.
"""

import stripe
from django.conf import settings
from django.core.management.base import BaseCommand

from apps.analyzer import ai_credits

PRICE_LOOKUP_KEY = "newsblur-ai-credit"


class Command(BaseCommand):
    help = "Create (or find) the Stripe meter and 1 cent metered price for AI credits."

    def handle(self, *args, **options):
        stripe.api_key = settings.STRIPE_SECRET

        meter = None
        for existing in stripe.billing.Meter.list(status="active", limit=100).auto_paging_iter():
            if existing.event_name == ai_credits.METER_EVENT_NAME:
                meter = existing
                break
        if not meter:
            meter = stripe.billing.Meter.create(
                display_name="NewsBlur AI credits",
                event_name=ai_credits.METER_EVENT_NAME,
                default_aggregation={"formula": "sum"},
                customer_mapping={"type": "by_id", "event_payload_key": "stripe_customer_id"},
                value_settings={"event_payload_key": "value"},
            )
            self.stdout.write("Created meter %s" % meter.id)
        else:
            self.stdout.write("Found meter %s" % meter.id)

        prices = stripe.Price.list(lookup_keys=[PRICE_LOOKUP_KEY], active=True, limit=1).data
        if prices:
            price = prices[0]
            self.stdout.write("Found price %s" % price.id)
        else:
            price = stripe.Price.create(
                currency="usd",
                unit_amount=int(round(ai_credits.CREDIT_USD * 100)),
                recurring={"interval": "month", "usage_type": "metered", "meter": meter.id},
                product_data={"name": "NewsBlur AI credits", "unit_label": "credit"},
                nickname="AI credit",
                lookup_key=PRICE_LOOKUP_KEY,
            )
            self.stdout.write("Created price %s" % price.id)

        self.stdout.write("")
        self.stdout.write('STRIPE_PRICE_AI_CREDITS = "%s"' % price.id)
