import datetime

from django.contrib.auth.models import User
from django.shortcuts import render
from django.views import View

from apps.notifications.models import MUserClassifierNotification, MUserFeedNotification


class Notifications(View):
    def get(self, request):
        data = {}

        feed_coll = MUserFeedNotification.objects._collection
        classifier_coll = MUserClassifierNotification.objects._collection

        # -- Notification type counts --
        data["feed"] = feed_coll.estimated_document_count()

        classifier_types = ["author", "tag", "title", "text", "url"]
        for ct in classifier_types:
            data[f"classifier_{ct}"] = classifier_coll.count_documents(
                {"classifier_type": ct}
            )

        # -- Delivery method breakdown (feed notifications) --
        for channel in ["is_email", "is_web", "is_ios", "is_android"]:
            data[f"feed_{channel}"] = feed_coll.count_documents({channel: True})

        # -- Delivery method breakdown (classifier notifications) --
        for channel in ["is_email", "is_web", "is_ios", "is_android"]:
            data[f"classifier_{channel}"] = classifier_coll.count_documents(
                {channel: True}
            )

        # -- Unique users: active (last seen within 90 days) vs stale --
        feed_user_ids = set(feed_coll.distinct("user_id"))
        classifier_user_ids = set(classifier_coll.distinct("user_id"))
        all_user_ids = feed_user_ids | classifier_user_ids

        stale_cutoff = datetime.datetime.now() - datetime.timedelta(days=90)
        stale_user_ids = set(
            User.objects.filter(
                pk__in=all_user_ids,
                profile__last_seen_on__lt=stale_cutoff,
            ).values_list("pk", flat=True)
        )

        active_feed = len(feed_user_ids - stale_user_ids)
        stale_feed = len(feed_user_ids & stale_user_ids)
        active_classifier = len(classifier_user_ids - stale_user_ids)
        stale_classifier = len(classifier_user_ids & stale_user_ids)
        active_total = len(all_user_ids - stale_user_ids)
        stale_total = len(all_user_ids & stale_user_ids)

        data["active_feed"] = active_feed
        data["stale_feed"] = stale_feed
        data["active_classifier"] = active_classifier
        data["stale_classifier"] = stale_classifier
        data["active_total"] = active_total
        data["stale_total"] = stale_total

        # -- Format for Prometheus --
        chart_name = "notifications"
        chart_type = "gauge"
        formatted_data = {}

        # Notification type counts
        formatted_data["feed"] = (
            f'{chart_name}{{type="feed"}} {data["feed"]}'
        )
        for ct in classifier_types:
            formatted_data[f"classifier_{ct}"] = (
                f'{chart_name}{{type="classifier_{ct}"}} {data[f"classifier_{ct}"]}'
            )

        # Delivery method breakdown - feed
        for channel in ["email", "web", "ios", "android"]:
            key = f"feed_is_{channel}"
            formatted_data[key] = (
                f'{chart_name}{{metric="delivery",source="feed",channel="{channel}"}} {data[key]}'
            )

        # Delivery method breakdown - classifier
        for channel in ["email", "web", "ios", "android"]:
            key = f"classifier_is_{channel}"
            formatted_data[key] = (
                f'{chart_name}{{metric="delivery",source="classifier",channel="{channel}"}} {data[key]}'
            )

        # Active vs stale notification users
        for status in ["active", "stale"]:
            for source in ["feed", "classifier", "total"]:
                key = f"{status}_{source}"
                formatted_data[key] = (
                    f'{chart_name}{{metric="unique_users",status="{status}",source="{source}"}} {data[key]}'
                )

        context = {
            "data": formatted_data,
            "chart_name": chart_name,
            "chart_type": chart_type,
        }
        return render(
            request, "monitor/prometheus_data.html", context, content_type="text/plain"
        )
