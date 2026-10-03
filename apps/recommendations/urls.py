from django.conf.urls import *

from apps.recommendations import taste, views
from apps.recommendations.feedback import story_feedback_history

urlpatterns = [
    url(r"^taste_profile/?$", taste.taste_profile, name="discovery-taste-profile"),
    url(r"^learn_taste/?$", taste.learn_taste, name="discovery-learn-taste"),
    url(r"^edit_taste/?$", taste.edit_taste, name="discovery-edit-taste"),
    url(r"^preview_taste/?$", taste.preview_taste, name="discovery-preview-taste"),
    url(r"^feedback_history/?$", story_feedback_history, name="story-feedback-history"),
    url(r"^story_feedback/?$", views.save_story_feedback, name="save-story-feedback"),
    url(r"^load_recommended_feed", views.load_recommended_feed, name="load-recommended-feed"),
    url(r"^save_recommended_feed", views.save_recommended_feed, name="save-recommended-feed"),
    url(r"^approve_feed", views.approve_feed, name="approve-recommended-feed"),
    url(r"^decline_feed", views.decline_feed, name="decline-recommended-feed"),
    url(r"^load_feed_info/(?P<feed_id>\d+)", views.load_feed_info, name="load-recommended-feed-info"),
]
