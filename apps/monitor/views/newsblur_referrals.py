import datetime

from django.shortcuts import render
from django.views import View

from apps.profile.models import MGiftCode, MReferral
from apps.statistics.models import MStatistics


class Referrals(View):
    def get(self, request):
        expiration_sec = 60 * 5  # 5 minutes

        data = {
            "total_referrals": MStatistics.get(
                "munin:referrals_total",
                lambda: MReferral.objects.count(),
                set_default=True,
                expiration_sec=expiration_sec,
            ),
            "pending_referrals": MStatistics.get(
                "munin:referrals_pending",
                lambda: MReferral.objects(status="pending").count(),
                set_default=True,
                expiration_sec=expiration_sec,
            ),
            "converted_referrals": MStatistics.get(
                "munin:referrals_converted",
                lambda: MReferral.objects(status="converted").count(),
                set_default=True,
                expiration_sec=expiration_sec,
            ),
            "total_gifts": MStatistics.get(
                "munin:gifts_total",
                lambda: MGiftCode.objects.count(),
                set_default=True,
                expiration_sec=expiration_sec,
            ),
            "redeemed_gifts": MStatistics.get(
                "munin:gifts_redeemed",
                lambda: MGiftCode.objects(redeemed_date__ne=None).count(),
                set_default=True,
                expiration_sec=expiration_sec,
            ),
            "staff_gifts": MStatistics.get(
                "munin:gifts_staff",
                lambda: MGiftCode.objects(is_staff_gift=True).count(),
                set_default=True,
                expiration_sec=expiration_sec,
            ),
            "refunded_gifts": MStatistics.get(
                "munin:gifts_refunded",
                lambda: MGiftCode.objects(stripe_refund_id__ne=None).count(),
                set_default=True,
                expiration_sec=expiration_sec,
            ),
        }
        chart_name = "referrals"
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
