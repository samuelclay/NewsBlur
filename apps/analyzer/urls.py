from django.conf.urls import url
from apps.analyzer import views

urlpatterns = [
    url(r'^$', views.index),
    url(r'^save/?', views.save_classifier),
    url(r'^popularity/?', views.popularity_query),
    url(r'^(?P<feed_id>\d+)', views.get_classifiers_feed),
]
