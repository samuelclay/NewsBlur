from django.conf.urls.defaults import *
from apps.recommendations import views

urlpatterns = patterns('',
    url(r'^load_recommended_feed', views.load_recommended_feed, name='load-recommended-feed'),
    url(r'^save_recommended_feed', views.save_recommended_feed, name='save-recommended-feed'),
    url(r'^load_feed_info',        views.load_feed_info,        name='load-recommended-feed-info'),
)
