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

        # -- Unique users --
        feed_users = set(feed_coll.distinct("user_id"))
        classifier_users = set(classifier_coll.distinct("user_id"))
        data["unique_users_feed"] = len(feed_users)
        data["unique_users_classifier"] = len(classifier_users)
        data["unique_users_total"] = len(feed_users | classifier_users)

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

        # Unique users
        formatted_data["unique_users_feed"] = (
            f'{chart_name}{{metric="unique_users",source="feed"}} {data["unique_users_feed"]}'
        )
        formatted_data["unique_users_classifier"] = (
            f'{chart_name}{{metric="unique_users",source="classifier"}} {data["unique_users_classifier"]}'
        )
        formatted_data["unique_users_total"] = (
            f'{chart_name}{{metric="unique_users",source="total"}} {data["unique_users_total"]}'
        )

        context = {
            "data": formatted_data,
            "chart_name": chart_name,
            "chart_type": chart_type,
        }
        return render(
            request, "monitor/prometheus_data.html", context, content_type="text/plain"
        )
