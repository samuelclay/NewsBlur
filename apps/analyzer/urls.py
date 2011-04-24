from django.conf.urls.defaults import *
from apps.analyzer import views

urlpatterns = patterns('',
    (r'^$', views.index),
    (r'^save/?', views.save_classifier),
    (r'^(?P<feed_id>\d+)', views.get_classifiers_feed),
)
