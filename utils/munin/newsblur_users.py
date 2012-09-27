#!/usr/bin/env python 
from utils.munin.base import MuninGraph


class NBMuninGraph(MuninGraph):

    @property
    def graph_config(self):
        return {
            'graph_category' : 'NewsBlur',
            'graph_title' : 'NewsBlur Users',
            'graph_vlabel' : 'users',
            'all.label': 'all',
            'monthly.label': 'monthly',
            'daily.label': 'daily',
            'premium.label': 'premium',
        }

    def calculate_metrics(self):
        import datetime
        from django.contrib.auth.models import User
        from apps.profile.models import Profile

        last_month = datetime.datetime.utcnow() - datetime.timedelta(days=30)
        last_day = datetime.datetime.utcnow() - datetime.timedelta(minutes=60*24)

        return {
            'all': User.objects.count(),
            'monthly': Profile.objects.filter(last_seen_on__gte=last_month).count(),
            'daily': Profile.objects.filter(last_seen_on__gte=last_day).count(),
            'premium': Profile.objects.filter(is_premium=True).count(),
        }

if __name__ == '__main__':
    NBMuninGraph().run()
