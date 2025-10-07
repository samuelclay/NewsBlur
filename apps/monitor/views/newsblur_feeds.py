from django.shortcuts import render
from django.views import View

from apps.reader.models import UserSubscription
from apps.rss_feeds.models import Feed
from apps.social.models import MSocialProfile, MSocialSubscription
from apps.statistics.models import MStatistics


class Feeds(View):
    def get(self, request):
        feeds_count = MStatistics.get("munin:feeds_count")
        if not feeds_count:
            feeds_count = Feed.objects.all().count()
            MStatistics.set("munin:feeds_count", feeds_count, 60 * 60 * 12)

        subscriptions_count = MStatistics.get("munin:subscriptions_count")
        if not subscriptions_count:
            subscriptions_count = UserSubscription.objects.all().count()
            MStatistics.set("munin:subscriptions_count", subscriptions_count, 60 * 60 * 12)

        pro_subscriptions_count = MStatistics.get("munin:pro_subscriptions_count")
        if not pro_subscriptions_count:
            pro_subscriptions_count = UserSubscription.objects.filter(user__profile__is_pro=True).count()
            MStatistics.set("munin:pro_subscriptions_count", pro_subscriptions_count, 60 * 60 * 12)

        data = {
            "feeds": feeds_count,
            "subscriptions": subscriptions_count,
            "pro_subscriptions": pro_subscriptions_count,
            "profiles": MSocialProfile.objects._collection.count(),
            "social_subscriptions": MSocialSubscription.objects._collection.count(),
        }
        chart_name = "feeds"
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
