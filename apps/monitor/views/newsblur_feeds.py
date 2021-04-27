from django.views import View
from django.http import JsonResponse

from apps.rss_feeds.models import Feed
from apps.reader.models import UserSubscription
from apps.social.models import MSocialProfile, MSocialSubscription
from apps.statistics.models import MStatistics

class Feeds(View):

    def get(self, request):

        feeds_count = MStatistics.get('munin:feeds_count')
        if not feeds_count:
            feeds_count = Feed.objects.all().count()
            MStatistics.set('munin:feeds_count', feeds_count, 60*60*12)

        subscriptions_count = MStatistics.get('munin:subscriptions_count')
        if not subscriptions_count:
            subscriptions_count = UserSubscription.objects.all().count()
            MStatistics.set('munin:subscriptions_count', subscriptions_count, 60*60*12)

        return JsonResponse({
            'feeds': feeds_count,
            'subscriptions': subscriptions_count,
            'profiles': MSocialProfile.objects.count(),
            'social_subscriptions': MSocialSubscription.objects.count(),
        })

