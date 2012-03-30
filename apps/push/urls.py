from django.conf.urls.defaults import *
from apps.push import views

urlpatterns = patterns('',
    url(r'^(?P<push_id>\d+)/?$', views.push_callback, name='push-callback'),
)
