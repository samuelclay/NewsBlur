from django.conf.urls.defaults import *
from apps.recommendations import views

urlpatterns = patterns('',
    url(r'^load_recommended_feed', views.load_recommended_feed, name='load-recommended-feed'),
)
