#!/srv/newsblur/venv/newsblur3/bin/python
from utils.munin.base import MuninGraph
import os
os.environ["DJANGO_SETTINGS_MODULE"] = "newsblur_web.settings"
import django
django.setup()

class NBMuninGraph(MuninGraph):

    @property
    def graph_config(self):
        return {
            'graph_category' : 'NewsBlur',
            'graph_title' : 'NewsBlur Users',
            'graph_vlabel' : 'users',
            'graph_args' : '-l 0',
            'all.label': 'all',
            'monthly.label': 'monthly',
            'daily.label': 'daily',
            'premium.label': 'premium',
            'queued.label': 'queued',
        }

    def calculate_metrics(self):
        import datetime
        from django.contrib.auth.models import User
        from apps.profile.models import Profile, RNewUserQueue

        last_month = datetime.datetime.utcnow() - datetime.timedelta(days=30)
        last_day = datetime.datetime.utcnow() - datetime.timedelta(minutes=60*24)

        return {
            'all': User.objects.count(),
            'monthly': Profile.objects.filter(last_seen_on__gte=last_month).count(),
            'daily': Profile.objects.filter(last_seen_on__gte=last_day).count(),
            'premium': Profile.objects.filter(is_premium=True).count(),
            'queued': RNewUserQueue.user_count(),
        }

if __name__ == '__main__':
    NBMuninGraph().run()
