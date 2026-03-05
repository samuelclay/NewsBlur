from django.urls import re_path

from apps.recommendations import views

urlpatterns = [
    re_path(r"^load_recommended_feed", views.load_recommended_feed, name="load-recommended-feed"),
    re_path(r"^save_recommended_feed", views.save_recommended_feed, name="save-recommended-feed"),
    re_path(r"^approve_feed", views.approve_feed, name="approve-recommended-feed"),
    re_path(r"^decline_feed", views.decline_feed, name="decline-recommended-feed"),
    re_path(r"^load_feed_info/(?P<feed_id>\d+)", views.load_feed_info, name="load-recommended-feed-info"),
]
