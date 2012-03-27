from django.conf.urls.defaults import *
from apps.push import views

urlpatterns = patterns('',
    url(r'^(\d+)/?$', views.pubsubhubbub_callback),
)
