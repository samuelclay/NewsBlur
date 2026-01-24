from django.urls import re_path

from apps.newsletters import views

urlpatterns = [
    re_path(r"^receive/?$", views.newsletter_receive, name="newsletter-receive"),
    re_path(r"^story/(?P<story_hash>[\w:]+)/?$", views.newsletter_story, name="newsletter-story"),
]
