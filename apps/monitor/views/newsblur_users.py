import datetime

from django.contrib.auth.models import User
from django.shortcuts import render
from django.views import View

from apps.profile.models import PremiumPricingMigration, Profile, RNewUserQueue
from apps.statistics.models import MStatistics


class Users(View):
    def get(self, request):
        last_year = datetime.datetime.utcnow() - datetime.timedelta(days=365)
        last_month = datetime.datetime.utcnow() - datetime.timedelta(days=30)
        last_day = datetime.datetime.utcnow() - datetime.timedelta(minutes=60 * 24)
        expiration_sec = 60 * 60  # 1 hour
        expiration_sec_short = 60 * 5  # 5 minutes

        data = {
            "all": MStatistics.get(
                "munin:users_count",
                lambda: User.objects.count(),
                set_default=True,
                expiration_sec=expiration_sec,
            ),
            "yearly": MStatistics.get(
                "munin:users_yearly",
                lambda: Profile.objects.filter(last_seen_on__gte=last_year).count(),
                set_default=True,
                expiration_sec=expiration_sec,
            ),
            "monthly": MStatistics.get(
                "munin:users_monthly",
                lambda: Profile.objects.filter(last_seen_on__gte=last_month).count(),
                set_default=True,
                expiration_sec=expiration_sec,
            ),
            "daily": MStatistics.get(
                "munin:users_daily",
                lambda: Profile.objects.filter(last_seen_on__gte=last_day).count(),
                set_default=True,
                expiration_sec=expiration_sec,
            ),
            "premium": MStatistics.get(
                "munin:users_premium",
                lambda: Profile.objects.filter(is_premium=True).count(),
                set_default=True,
                expiration_sec=expiration_sec,
            ),
            "premium_from_trial": MStatistics.get(
                "munin:users_premium_from_trial",
                lambda: Profile.objects.filter(is_premium=True, is_premium_trial=False).count(),
                set_default=True,
                expiration_sec=expiration_sec,
            ),
            "premium_non_trial": MStatistics.get(
                "munin:users_premium_non_trial",
                lambda: Profile.objects.filter(is_premium=True).exclude(is_premium_trial=True).count(),
                set_default=True,
                expiration_sec=expiration_sec,
            ),
            "archive": MStatistics.get(
                "munin:users_archive",
                lambda: Profile.objects.filter(is_archive=True).count(),
                set_default=True,
                expiration_sec=expiration_sec_short,
            ),
            "pro": MStatistics.get(
                "munin:users_pro",
                lambda: Profile.objects.filter(is_pro=True).count(),
                set_default=True,
                expiration_sec=expiration_sec_short,
            ),
            "usage_billing": MStatistics.get(
                "munin:users_usage_billing",
                lambda: Profile.objects.filter(is_usage_billing=True).count(),
                set_default=True,
                expiration_sec=expiration_sec_short,
            ),
            "trial": MStatistics.get(
                "munin:users_trial",
                lambda: Profile.objects.filter(is_premium=True, is_premium_trial=True).count(),
                set_default=True,
                expiration_sec=expiration_sec,
            ),
            "queued": MStatistics.get(
                "munin:users_queued",
                lambda: RNewUserQueue.user_count(),
                set_default=True,
                expiration_sec=expiration_sec,
            ),
            "grandfathered": MStatistics.get(
                "munin:users_grandfathered",
                lambda: Profile.objects.filter(is_grandfathered=True).count(),
                set_default=True,
                expiration_sec=expiration_sec,
            ),
            "grandfathered_heavy": MStatistics.get(
                "munin:users_grandfathered_heavy",
                lambda: Profile.objects.filter(
                    is_grandfathered=True,
                    grandfather_expires__isnull=False,
                    grandfather_expires__gt=datetime.datetime.now(datetime.timezone.utc),
                ).count(),
                set_default=True,
                expiration_sec=expiration_sec,
            ),
            "premium_pricing_upgrades_stripe": MStatistics.get(
                "munin:users_premium_pricing_upgrades_stripe",
                lambda: PremiumPricingMigration.objects.filter(status="upgraded", provider="stripe").count(),
                set_default=True,
                expiration_sec=expiration_sec,
            ),
            # There is deliberately no premium_pricing_upgrades_paypal counterpart. Grandfathered
            # PayPal subs are legacy IPN and can't be revised in place, so they can never reach
            # status="upgraded" -- a PayPal subscriber who takes the new price does it by
            # resubscribing, which is already counted by premium_pricing_resubscribed_paypal below.
            "premium_pricing_cancellations_stripe": MStatistics.get(
                "munin:users_premium_pricing_cancellations_stripe",
                lambda: PremiumPricingMigration.objects.filter(status="cancelled", provider="stripe").count(),
                set_default=True,
                expiration_sec=expiration_sec,
            ),
            "premium_pricing_cancellations_paypal": MStatistics.get(
                "munin:users_premium_pricing_cancellations_paypal",
                lambda: PremiumPricingMigration.objects.filter(status="cancelled", provider="paypal").count(),
                set_default=True,
                expiration_sec=expiration_sec,
            ),
            # Dormant PayPal payers we chose NOT to force-cancel: they'd almost never resubscribe,
            # so leaving them on the grandfathered plan preserves revenue we would otherwise forfeit.
            # Only PayPal reaches the dormancy guard (Stripe is switched silently), so this is the
            # full skipped_dormant count.
            "premium_pricing_skipped_dormant_paypal": MStatistics.get(
                "munin:users_premium_pricing_skipped_dormant_paypal",
                lambda: PremiumPricingMigration.objects.filter(
                    status="skipped_dormant", provider="paypal"
                ).count(),
                set_default=True,
                expiration_sec=expiration_sec,
            ),
            # Switched to $36 and emailed, but the renewal charge hasn't landed yet (in-flight).
            "premium_pricing_awaiting_charge": MStatistics.get(
                "munin:users_premium_pricing_awaiting_charge",
                lambda: PremiumPricingMigration.objects.filter(status="emailed").count(),
                set_default=True,
                expiration_sec=expiration_sec,
            ),
            # PayPal subscribers we opened a row for but never reached: no approval link could be
            # created and cancelling was off at the time, so they were left on the grandfathered
            # rate. They only get retried when their renewal comes back around a year later, so this
            # is the backlog the migration has quietly skipped rather than work in progress.
            "premium_pricing_pending_paypal": MStatistics.get(
                "munin:users_premium_pricing_pending_paypal",
                lambda: PremiumPricingMigration.objects.filter(status="pending", provider="paypal").count(),
                set_default=True,
                expiration_sec=expiration_sec,
            ),
        }
        # There are no upgrades_12/upgrades_24 splits: every Stripe subscription in this campaign was
        # grandfathered at $24, and the $12 rows are all PayPal, which can never reach
        # status="upgraded" (see above). The split was zero on one side and a duplicate of
        # premium_pricing_upgrades_stripe on the other.

        # Cancelled subscribers (esp. PayPal non-approvers) who came back with a fresh paid sub,
        # keyed by the actual origin -> destination x tier move (e.g.
        # premium_pricing_switch_paypal_to_stripe_premium). Only non-zero switches are emitted, so the
        # panel shows the moves that actually happened rather than a wall of zeros. A resubscribe keeps
        # status="cancelled" and never lands in the upgrades_* metrics above.
        resubscribed_switches = MStatistics.get(
            "munin:users_premium_pricing_resubscribed_switches",
            PremiumPricingMigration.resubscribed_switches,
            set_default=True,
            expiration_sec=expiration_sec,
        )
        for switch, count in resubscribed_switches.items():
            data["premium_pricing_switch_%s" % switch] = count
        data["premium_pricing_resubscribed_total"] = sum(resubscribed_switches.values())

        # Of the subscribers we cancelled (PayPal non-approvers are forcibly cancelled), how many
        # have come back vs are still gone -- charts the resubscribe rate against the forced
        # cancellations (premium_pricing_cancellations_<origin>) on the same panel.
        resubscribe_funnel = MStatistics.get(
            "munin:users_premium_pricing_resubscribe_funnel",
            PremiumPricingMigration.resubscribe_funnel,
            set_default=True,
            expiration_sec=expiration_sec,
        )
        for key, count in resubscribe_funnel.items():
            data["premium_pricing_%s" % key] = count

        # Bottom line: yearly dollars gained and lost by the migration versus what these subscribers
        # used to pay. Emitted here rather than derived in Grafana because the arithmetic needs each
        # row's own old rate ($12 or $24) and destination tier, which the counter metrics flatten
        # away (apps/profile/models.py revenue_delta).
        revenue = MStatistics.get(
            "munin:users_premium_pricing_revenue",
            PremiumPricingMigration.revenue_delta,
            set_default=True,
            expiration_sec=expiration_sec,
        )
        for key, amount in revenue.items():
            data["premium_pricing_%s" % key] = amount

        chart_name = "users"
        chart_type = "counter"

        formatted_data = {}
        for k, v in data.items():
            formatted_data[k] = f'{chart_name}{{category="{k}"}} {v}'
        context = {
            "data": formatted_data,
            "chart_name": chart_name,
            "chart_type": chart_type,
        }
        return render(request, "monitor/prometheus_data.html", context, content_type="text/plain")
