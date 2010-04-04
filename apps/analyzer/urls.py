from django.conf.urls.defaults import *
from apps.analyzer import views

urlpatterns = patterns('',
    (r'^$', views.index),
    (r'^save/story/?', views.save_classifier),
    (r'^save/publisher/?', views.save_classifier),
    (r'^get/publisher/?', views.get_classifiers_feed),
)
