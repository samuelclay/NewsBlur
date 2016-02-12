from django.conf.urls import *
from apps.newsletters import views

urlpatterns = patterns('',
    url(r'^receive/?$', views.newsletter_receive, name='newsletter-receive'),
    url(r'^story/(?P<story_hash>[\w:]+)/?$', views.newsletter_story, name='newsletter-story'),
)
