from django.urls import re_path

from apps.analyzer import views

urlpatterns = [
    re_path(r"^$", views.index),
    re_path(r"^save/?$", views.save_classifier),
    re_path(r"^save_all/?$", views.save_all_classifiers),
    re_path(r"^save_prompt/?$", views.save_prompt_classifier),
    re_path(r"^test_prompt/?$", views.test_prompt_classifier),
    re_path(r"^ai_classifier_usage/?$", views.get_ai_classifier_usage),
    re_path(r"^popularity/?", views.popularity_query),
    re_path(r"^(?P<feed_id>\d+)", views.get_classifiers_feed),
]
