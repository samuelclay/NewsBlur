from django.conf.urls.defaults import url, patterns
from apps.social import views

urlpatterns = patterns('',
    url(r'^share_story/?$', views.mark_story_as_shared, name='mark-story-as-shared'),
    url(r'^(?P<user_id>\d+)/(?P<username>\w+)/?$', views.shared_story_feed, name='shared-story-feed'),
    url(r'^(?P<username>\w+)/?$', views.shared_stories_public, name='shared-stories-public'),
)
