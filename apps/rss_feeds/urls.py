from django.conf.urls.defaults import *
from apps.rss_feeds import views

urlpatterns = patterns('',
    url(r'^statistics', views.load_feed_statistics, name='statistics'),
    url(r'^exception_retry', views.exception_retry, name='exception-retry'),
)
