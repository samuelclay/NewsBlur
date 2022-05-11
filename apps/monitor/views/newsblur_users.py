import datetime

from django.contrib.auth.models import User
from django.shortcuts import render
from django.views import View

from apps.profile.models import Profile, RNewUserQueue

class Users(View):

    def get(self, request):
        last_year = datetime.datetime.utcnow() - datetime.timedelta(days=365)
        last_month = datetime.datetime.utcnow() - datetime.timedelta(days=30)
        last_day = datetime.datetime.utcnow() - datetime.timedelta(minutes=60*24)

        data = {
            'all': User.objects.count(),
            'yearly': Profile.objects.filter(last_seen_on__gte=last_year).count(),
            'monthly': Profile.objects.filter(last_seen_on__gte=last_month).count(),
            'daily': Profile.objects.filter(last_seen_on__gte=last_day).count(),
            'premium': Profile.objects.filter(is_premium=True).count(),
            'archive': Profile.objects.filter(is_archive=True).count(),
            'pro': Profile.objects.filter(is_pro=True).count(),
            'queued': RNewUserQueue.user_count(),
        }
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
        return render(request, 'monitor/prometheus_data.html', context, content_type="text/plain")

