from django.conf.urls import *
from apps.analyzer import views

urlpatterns = patterns('',
    (r'^$', views.index),
    (r'^save/?', views.save_classifier),
    (r'^popularity/?', views.popularity_query),
    (r'^(?P<feed_id>\d+)', views.get_classifiers_feed),
)
