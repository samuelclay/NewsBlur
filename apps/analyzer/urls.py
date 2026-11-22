from django.conf.urls import url

from apps.analyzer import views

urlpatterns = [
    url(r"^$", views.index),
    url(r"^save/?$", views.save_classifier),
    url(r"^save_all/?$", views.save_all_classifiers),
    url(r"^save_prompt/?$", views.save_prompt_classifier),
    url(r"^test_prompt/?$", views.test_prompt_classifier),
    url(r"^ai_classifier_usage/?$", views.get_ai_classifier_usage),
    url(r"^popularity/?", views.popularity_query),
    url(r"^(?P<feed_id>\d+)", views.get_classifiers_feed),
]
