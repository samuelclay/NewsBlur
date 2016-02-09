from django.conf.urls import *
from apps.newsletters import views

urlpatterns = patterns('',
    url(r'^/?$', views.newsletter_receive, name='newsletter-receive'),
)
