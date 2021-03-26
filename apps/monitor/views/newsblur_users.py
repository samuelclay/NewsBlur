import datetime

from django.contrib.auth.models import User
from django.http import JsonResponse
from django.views import View

from apps.profile.models import Profile, RNewUserQueue

class Users(View):

    def get(self, request):
        last_month = datetime.datetime.utcnow() - datetime.timedelta(days=30)
        last_day = datetime.datetime.utcnow() - datetime.timedelta(minutes=60*24)

        return JsonResponse({
            'all': User.objects.count(),
            'monthly': Profile.objects.filter(last_seen_on__gte=last_month).count(),
            'daily': Profile.objects.filter(last_seen_on__gte=last_day).count(),
            'premium': Profile.objects.filter(is_premium=True).count(),
            'queued': RNewUserQueue.user_count(),
        })
