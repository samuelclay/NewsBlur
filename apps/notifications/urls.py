from django.conf.urls import url, patterns
from apps.notifications import views
from oauth2_provider import views as op_views

urlpatterns = patterns('',
    url(r'^/?$', views.notifications_by_feed, name='notifications-by-feed'),
)