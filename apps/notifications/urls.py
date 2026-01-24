from django.urls import re_path
from oauth2_provider import views as op_views

from apps.notifications import views

urlpatterns = [
    re_path(r"^$", views.notifications_by_feed, name="notifications-by-feed"),
    re_path(r"^feed/?$", views.set_notifications_for_feed, name="set-notifications-for-feed"),
    re_path(r"^apns_token/?$", views.set_apns_token, name="set-apns-token"),
    re_path(r"^android_token/?$", views.set_android_token, name="set-android-token"),
    re_path(r"^force_push/?$", views.force_push, name="force-push-notification"),
]
