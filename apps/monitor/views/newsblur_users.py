import datetime

from django.contrib.auth.models import User
from django.shortcuts import render
from django.views import View

from apps.profile.models import Profile, RNewUserQueue
from apps.statistics.models import MStatistics

class Users(View):

    def get(self, request):
        last_year = datetime.datetime.utcnow() - datetime.timedelta(days=365)
        last_month = datetime.datetime.utcnow() - datetime.timedelta(days=30)
        last_day = datetime.datetime.utcnow() - datetime.timedelta(minutes=60*24)
        expiration_sec = 60*60 # 1 hour
        
        data = {
            'all': MStatistics.get('munin:users_count', 
                                   lambda: User.objects.count(), 
                                   set_default=True, expiration_sec=expiration_sec),
            'yearly': MStatistics.get('munin:users_yearly', 
                                      lambda: Profile.objects.filter(last_seen_on__gte=last_year).count(), 
                                      set_default=True, expiration_sec=expiration_sec),
            'monthly': MStatistics.get('munin:users_monthly', 
                                       lambda: Profile.objects.filter(last_seen_on__gte=last_month).count(),
                                       set_default=True, expiration_sec=expiration_sec),
            'daily': MStatistics.get('munin:users_daily', 
                                     lambda: Profile.objects.filter(last_seen_on__gte=last_day).count(),
                                     set_default=True, expiration_sec=expiration_sec),
            'premium': MStatistics.get('munin:users_premium', 
                                       lambda: Profile.objects.filter(is_premium=True).count(),
                                       set_default=True, expiration_sec=expiration_sec),
            'archive': MStatistics.get('munin:users_archive',
                                       lambda: Profile.objects.filter(is_archive=True).count(),
                                       set_default=True, expiration_sec=expiration_sec),
            'pro': MStatistics.get('munin:users_pro',
                                   lambda: Profile.objects.filter(is_pro=True).count(),
                                   set_default=True, expiration_sec=expiration_sec),
            'queued': MStatistics.get('munin:users_queued',
                                      lambda: RNewUserQueue.user_count(),
                                      set_default=True, expiration_sec=expiration_sec),
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

