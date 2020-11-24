from django.conf.urls import url
from apps.newsletters import views

urlpatterns = [
    url(r'^receive/?$', views.newsletter_receive, name='newsletter-receive'),
    url(r'^story/(?P<story_hash>[\w:]+)/?$', views.newsletter_story, name='newsletter-story'),
]
