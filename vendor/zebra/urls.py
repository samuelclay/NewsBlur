from django.conf.urls import *

from zebra import views

urlpatterns = patterns('',
    url(r'webhooks/$',     views.webhooks,          name='webhooks'),
    url(r'webhooks/v2/$',     views.webhooks_v2,          name='webhooks_v2'),
)
